#!/usr/bin/env python3
"""Create Rover dev-fixture users and print the links QA needs.

One invocation covers the whole flow: build the SPA "Create" URL, POST the
fixture to the API, pull the person PK out of the impersonate redirect and
print the admin impersonation link. The API response body is never printed --
it embeds API-key material for every created person and is large.

Examples
--------
    # one fixture, create it, print both links
    create_fixture.py --base-url staging-qa-testing \
        --requester-country US --requester-city Auburn \
        --requester-region WA --requester-postal-code 98001

    # extra overrides beyond the CLI flags
    create_fixture.py --base-url local --extra '{"bookingStatus":"completed"}'

    # several fixtures in one call (POSTed concurrently)
    create_fixture.py --base-url staging-qa-testing \
        --scenario '{"label":"AK","requesterRegion":"AK"}' \
        --scenario '{"label":"CH","requesterCountry":"CH"}'

    # link only, no user created
    create_fixture.py --base-url local --url-only

    # field reference / drift check against the serializer
    create_fixture.py --list-fields Requester
    create_fixture.py --check-defaults

Query-string encoding: each value is JSON-encoded then URL-encoded, mirroring
the frontend encoder generateRunUrl.tsx
(src/frontend/pages/src/fixtures/utils/generateRunUrl.tsx) -- strings become
double-quoted ("US" -> %22US%22), numbers and booleans stay bare. If that file's
encoding changes, update encode_value().
"""

import argparse
import ast
import json
import os
import re
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib import error, request
from urllib.parse import quote

TEMPLATE_SLUG = "1-standard-scenario"
SPA_PATH = "/dev/fixtures/templates/{}/run/"
API_PATH = "/api/v7/fixtures/templates/{}/run"
ADMIN_PATH = "/admin/people/person/?id={}"
CAMEL_CONTENT_TYPE = "application/vnd.rover.api.camel+json"
PK_RE = re.compile(r"become_user/(\d+)")

# Where the fixture option serializers live, relative to the web repo root.
SERIALIZER_PATH = "src/aplaceforrover/fixtures/standard_options.py"
SERIALIZER_CLASSES = {
    "provider": "ProviderOptions",
    "requester": "RequesterOptions",
    "booking": "BookingOptions",
    "standard": "StandardOptions",
    "applicant": "ApplicantOptions",
}

# Serializer defaults for the fields the SPA form needs pre-filled. Run
# --check-defaults to detect drift from standard_options.py.
DEFAULTS = {
    "requesterCountry": "US",
    "requesterCity": "Seattle",
    "requesterRegion": "WA",
    "requesterPostalCode": "98104",
    "dogCount": 1,
    "catCount": 0,
    "puppyCount": 0,
    "requesterCreateLocation": True,
    "requesterCreditCard": True,
    "requester3dsCard": False,
    "requesterEmailVerified": True,
    "requesterShadowBanned": False,
    "requesterPhoneNumber": True,
    "requesterHasInvalidAddressForSalesTax": False,
    "entrypoint": "login_as_requester",
    "impersonate": True,
    "useTask": False,
}

# Fields that configure the fixture run itself rather than the created objects,
# so they are not serializer fields and are excluded from drift checks.
RUN_CONTROL_FIELDS = {"entrypoint", "impersonate", "useTask"}

# argparse dest (snake) -> camelCase param name.
CLI_FIELDS = {
    "requester_country": "requesterCountry",
    "requester_city": "requesterCity",
    "requester_region": "requesterRegion",
    "requester_postal_code": "requesterPostalCode",
    "dog_count": "dogCount",
    "cat_count": "catCount",
    "puppy_count": "puppyCount",
}


def resolve_base_url(value):
    """Turn an environment shorthand into a base URL."""
    if value.startswith(("http://", "https://")):
        return value.rstrip("/")
    if value == "local":
        return "http://localhost:8000"
    if value.startswith("staging-"):
        return "https://{}.webapp.roverstaging.com".format(value)
    raise SystemExit(
        "Unrecognized environment {!r}: expected 'local', "
        "'staging-<name>' or a full URL".format(value)
    )


def encode_value(value):
    """Encode one query-string value per the SPA's quoting rule."""
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "null"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, (dict, list)):
        return quote(json.dumps(value, separators=(",", ":")), safe="")
    return quote('"{}"'.format(value), safe="")


def build_params(overrides):
    params = dict(DEFAULTS)
    params.update(overrides)
    return params


def build_url(base_url, params):
    query = "&".join(
        "{}={}".format(key, encode_value(val)) for key, val in params.items()
    )
    return "{}{}?{}".format(base_url, SPA_PATH.format(TEMPLATE_SLUG), query)


def post_fixture(base_url, params):
    """POST the fixture and return the created person PK.

    Raises RuntimeError with a short message on failure. The response body is
    parsed but never returned or printed -- it carries API keys.
    """
    url = base_url + API_PATH.format(TEMPLATE_SLUG)
    body = json.dumps(params).encode("utf-8")
    req = request.Request(
        url,
        data=body,
        method="POST",
        headers={"Content-Type": CAMEL_CONTENT_TYPE, "Accept": CAMEL_CONTENT_TYPE},
    )
    try:
        with request.urlopen(req, timeout=180) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except error.HTTPError as exc:
        raise RuntimeError(
            "HTTP {} from {}: {}".format(exc.code, url, _short_error(exc.read()))
        ) from exc
    except (error.URLError, OSError) as exc:
        raise RuntimeError("could not reach {}: {}".format(url, exc)) from exc
    except json.JSONDecodeError as exc:
        raise RuntimeError("non-JSON response from {}".format(url)) from exc

    return _extract_pk(
        base_url, payload, params.get("entrypoint", DEFAULTS["entrypoint"])
    )


def _short_error(raw):
    try:
        text = raw.decode("utf-8", "replace")
    except AttributeError:
        text = str(raw)
    text = " ".join(text.split())
    return text[:200]


def _extract_pk(base_url, payload, entrypoint_name):
    if isinstance(payload, dict) and payload.get("error"):
        raise RuntimeError(
            "fixture build failed: {}".format(_short_error(payload["error"]))
        )

    entry_points = _find_entry_points(payload)
    if entry_points is None:
        raise RuntimeError("response contained no entrypoints")

    for entry in entry_points:
        if entry.get("name") != entrypoint_name:
            continue
        impersonate = (
            entry.get("impersonateURL")
            or entry.get("impersonateUrl")
            or entry.get("impersonate_url")
        )
        if not impersonate:
            raise RuntimeError(
                "entrypoint {!r} has no impersonate URL".format(entrypoint_name)
            )
        return _resolve_pk(base_url, impersonate)

    raise RuntimeError(
        "no entrypoint named {!r} in the response".format(entrypoint_name)
    )


def _resolve_pk(base_url, impersonate_url):
    """Pull the person PK out of the impersonate URL, following it if needed.

    The API returns an entry-point URL like
    /f/fixture-sets/<id>/entry_point/login_as_requester/impersonate/, which 302s
    (no auth required for the redirect itself) to
    /admin/people/person/become_user/<pk>/. Only the Location header is read.
    """
    match = PK_RE.search(impersonate_url)
    if match:
        return int(match.group(1))

    url = impersonate_url
    if url.startswith("/"):
        url = base_url + url
    if not url.startswith(("http://", "https://")):
        raise RuntimeError("impersonate URL is not resolvable: {}".format(url[:60]))

    opener = request.build_opener(_NoRedirect)
    try:
        with opener.open(url, timeout=60) as response:
            raise RuntimeError(
                "impersonate URL returned {} instead of a become_user redirect".format(
                    response.status
                )
            )
    except error.HTTPError as exc:
        location = exc.headers.get("Location", "") if exc.headers else ""
        match = PK_RE.search(location)
        if not match:
            raise RuntimeError(
                "could not parse a person PK out of the impersonate redirect"
            ) from exc
        return int(match.group(1))
    except (error.URLError, OSError) as exc:
        raise RuntimeError(
            "could not follow the impersonate URL: {}".format(exc)
        ) from exc


class _NoRedirect(request.HTTPRedirectHandler):
    """Surface the 302 as an HTTPError so the Location header can be read."""

    def redirect_request(self, *args, **kwargs):
        return None


def _find_entry_points(payload):
    """Locate the entrypoints list, whichever nesting/casing the API used."""
    if isinstance(payload, list):
        for item in payload:
            found = _find_entry_points(item)
            if found is not None:
                return found
        return None
    if not isinstance(payload, dict):
        return None
    for key in ("entrypoints", "entryPoints", "entry_points"):
        value = payload.get(key)
        if isinstance(value, list):
            return value
    for value in payload.values():
        found = _find_entry_points(value)
        if found is not None:
            return found
    return None


def find_serializer_file():
    candidates = []
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR")
    if project_dir:
        candidates.append(Path(project_dir))
    candidates.append(Path.cwd())
    candidates.extend(Path.cwd().parents)
    candidates.append(Path("/workspaces/web"))

    for root in candidates:
        path = root / SERIALIZER_PATH
        if path.is_file():
            return path
    raise SystemExit(
        "Could not find {} -- run this from the web repo "
        "or set CLAUDE_PROJECT_DIR".format(SERIALIZER_PATH)
    )


def parse_serializer_fields(class_name):
    """Return [(snake_name, field_type, default_expr, choices_expr)] for a class.

    Fields inherited from base classes declared in the same file are included.
    """
    tree = ast.parse(find_serializer_file().read_text())
    classes = {node.name: node for node in tree.body if isinstance(node, ast.ClassDef)}
    if class_name not in classes:
        raise SystemExit("{} is not defined in {}".format(class_name, SERIALIZER_PATH))

    fields = []
    seen = set()
    for node in _class_mro(classes, class_name):
        for statement in node.body:
            if not isinstance(statement, ast.Assign) or not isinstance(
                statement.value, ast.Call
            ):
                continue
            target = statement.targets[0]
            if not isinstance(target, ast.Name) or target.id in seen:
                continue
            seen.add(target.id)
            fields.append(
                (target.id, _field_type(statement.value)) + _field_args(statement.value)
            )
    return fields


def _class_mro(classes, class_name):
    """The class itself first, then its locally-defined bases, depth first."""
    node = classes[class_name]
    yield node
    for base in node.bases:
        if isinstance(base, ast.Name) and base.id in classes:
            yield from _class_mro(classes, base.id)


def _field_type(call):
    func = call.func
    name = func.attr if isinstance(func, ast.Attribute) else getattr(func, "id", "?")
    return name.removesuffix("Field")


def _field_args(call):
    default = choices = None
    for keyword in call.keywords:
        if keyword.arg == "default":
            default = ast.unparse(keyword.value)
        elif keyword.arg == "choices":
            choices = ast.unparse(keyword.value)
    return default, choices


def to_camel(snake):
    """requester_3ds_card -> requester3dsCard (digits do not start a new word)."""
    head, *rest = snake.split("_")
    return head + "".join(part[:1].upper() + part[1:] for part in rest)


def list_fields(class_key):
    class_name = SERIALIZER_CLASSES[class_key.lower()]
    print("# {} ({})".format(class_name, SERIALIZER_PATH))
    for snake, field_type, default, choices in parse_serializer_fields(class_name):
        line = "{}  {}  default={}".format(
            to_camel(snake), field_type, default if default is not None else "-"
        )
        if choices:
            line += "  choices={}".format(choices)
        print(line)


def check_defaults():
    """Print only the DEFAULTS entries that disagree with the serializer.

    Defaults expressed as constants or enum members (DEFAULT_COUNTRY,
    STAY_STATUS_CHOICES.ongoing) cannot be resolved by static parsing, so they
    are listed as unverified rather than reported as drift.
    """
    serializer_defaults = {
        to_camel(snake): default
        for snake, _, default, _ in parse_serializer_fields("StandardOptions")
    }
    mismatches = []
    unverified = []
    for camel, value in DEFAULTS.items():
        if camel in RUN_CONTROL_FIELDS:
            continue
        if camel not in serializer_defaults:
            mismatches.append("{}: not a StandardOptions field any more".format(camel))
            continue
        expected = serializer_defaults[camel]
        literal = _as_literal(expected)
        if literal is _UNRESOLVED:
            unverified.append(
                "{}: script has {!r}, serializer has {}".format(camel, value, expected)
            )
        elif literal != value:
            mismatches.append(
                "{}: script has {!r}, serializer has {}".format(camel, value, expected)
            )

    if mismatches:
        print("DEFAULTS drift vs {}:".format(SERIALIZER_PATH))
        for line in mismatches:
            print("  " + line)
    else:
        print("DEFAULTS match {}".format(SERIALIZER_PATH))
    if unverified:
        print(
            "Unverified (non-literal serializer default, "
            "check by hand if links look wrong):"
        )
        for line in unverified:
            print("  " + line)
    return 1 if mismatches else 0


_UNRESOLVED = object()


def _as_literal(expr):
    """Evaluate a serializer default expression, or _UNRESOLVED if not a literal."""
    if expr is None:
        return _UNRESOLVED
    try:
        return ast.literal_eval(expr)
    except (ValueError, SyntaxError):
        return _UNRESOLVED


def run_scenario(base_url, scenario, post):
    label = scenario.pop("label", None)
    params = build_params(scenario)
    result = {
        "label": label,
        "create_url": build_url(base_url, params),
        "pk": None,
        "error": None,
    }
    if post:
        try:
            result["pk"] = post_fixture(base_url, params)
        except RuntimeError as exc:
            result["error"] = str(exc)
    return result


def print_result(base_url, result, index, total):
    if total > 1 or result["label"]:
        print("## {}".format(result["label"] or "scenario {}".format(index + 1)))
    print("Create link: {}".format(result["create_url"]))
    if result["pk"]:
        print("Admin link:  {}{}".format(base_url, ADMIN_PATH.format(result["pk"])))
        print("Person PK:   {}".format(result["pk"]))
    elif result["error"]:
        print("Admin link:  unavailable -- {}".format(result["error"]))
    if index < total - 1:
        print()


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--base-url", help="'local', 'staging-<name>' or a full URL")
    parser.add_argument("--requester-country")
    parser.add_argument("--requester-city")
    parser.add_argument("--requester-region")
    parser.add_argument("--requester-postal-code")
    parser.add_argument("--dog-count", type=int)
    parser.add_argument("--cat-count", type=int)
    parser.add_argument("--puppy-count", type=int)
    parser.add_argument(
        "--extra",
        help="JSON object of additional camelCase overrides, "
        'e.g. \'{"bookingStatus":"completed"}\'',
    )
    parser.add_argument(
        "--scenario",
        action="append",
        default=[],
        metavar="JSON",
        help="Repeatable JSON object of camelCase overrides; an optional "
        "'label' key names the scenario. Applied on top of the CLI flags.",
    )
    parser.add_argument(
        "--url-only",
        action="store_true",
        help="Print the Create link(s) without creating anything",
    )
    parser.add_argument(
        "--list-fields",
        metavar="CLASS",
        choices=sorted(SERIALIZER_CLASSES),
        help="Print a serializer class's field reference instead of creating a fixture",
    )
    parser.add_argument(
        "--check-defaults",
        action="store_true",
        help="Report drift between this script's DEFAULTS and the serializer",
    )
    args = parser.parse_args()

    if args.list_fields:
        list_fields(args.list_fields)
        return 0
    if args.check_defaults:
        return check_defaults()
    if not args.base_url:
        parser.error("--base-url is required")

    base_url = resolve_base_url(args.base_url)

    common = {}
    for dest, camel in CLI_FIELDS.items():
        value = getattr(args, dest)
        if value is not None:
            common[camel] = value
    if args.extra:
        common.update(json.loads(args.extra))

    scenarios = [json.loads(raw) for raw in args.scenario] or [{}]
    scenarios = [dict(common, **scenario) for scenario in scenarios]

    post = not args.url_only
    with ThreadPoolExecutor(max_workers=min(8, len(scenarios))) as pool:
        results = list(pool.map(lambda s: run_scenario(base_url, s, post), scenarios))

    for index, result in enumerate(results):
        print_result(base_url, result, index, len(results))

    return 1 if any(result["error"] for result in results) else 0


if __name__ == "__main__":
    sys.exit(main())
