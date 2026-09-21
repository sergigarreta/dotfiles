---
name: web-backend-test-speed
description: "How to run /workspaces/web's Django backend tests (`t`, `dc run ... ./manage.py test`) so they finish in a reasonable time — pass `--parallel 8` for any app-sized suite, narrow the target for a quick loop, and use `t --watch` while iterating. Use whenever running backend tests in the codespace, when a `t <app>` run is taking minutes, or when deciding how to verify a backend change. Also records which options do not help (APP_DEPENDENCIES, --keepdb, --parallel 16), so they are not re-tried."
allowed-tools: Bash
---

# Running web's backend tests fast

`t <target>` runs `dc run --no-deps --rm -e SQLITE=1 web ./manage.py test -p '*_tests.py'`
and forwards any extra arguments to Django's `DiscoverRunner`, so every runner
flag below can be appended to a normal `t` call.

## The rule

Add `--parallel 8` whenever the target is a whole app or otherwise runs more
than a couple hundred tests.

```bash
t meet_and_greet --parallel 8
```

Measured on `meet_and_greet` (1028 tests, 16-vCPU codespace, 2026-09-21):

| invocation | wall clock | tests |
|---|---|---|
| `t meet_and_greet` | 160s | 133s |
| `t meet_and_greet --parallel 8` | 71s | 43s |
| `t meet_and_greet --parallel 16` | 78s | 50s |

8 workers on 16 vCPUs is the sweet spot; 16 oversubscribes and loses time to
context switching. Below roughly 200 tests the win disappears into the fixed
startup cost, so a narrow target does not need the flag.

Parallel workers report through `RoverParallelTestSuite`, which pickles results
across the process boundary. If a suite passes serially and fails only in
parallel, the tests share state — rerun the failing module without `--parallel`
to get a clean traceback, then fix the isolation bug rather than dropping the
flag for the whole app.

## Every run pays ~28s of startup

The 160s run above spent only 133s in tests. The rest is container start,
Django boot, and building the in-memory SQLite schema. That cost is per
invocation, so a tight edit-run loop is dominated by it.

Narrowing the target beats any flag:

```bash
t meet_and_greet.tests.preconditions_tests
t meet_and_greet.tests.services_tests.CancelTests.test_cancels_pending
t meet_and_greet -k cancellation        # filter by name across the app
t meet_and_greet --failfast             # stop at the first failure
```

`t` also accepts file paths and converts them, so `t src/aplaceforrover/meet_and_greet/tests/preconditions_tests.py` works.

While iterating on one module, `t --watch <target>` keeps the process warm and
reruns on save, paying the startup once instead of per run.

## What does not help

- **`APP_DEPENDENCIES=<app>`** — trimming `INSTALLED_APPS` saved 3s of 160s.
  Migrations are already disabled during test runs, so the schema build is not
  where the time goes.
- **`--keepdb`** — `t` forces `SQLITE=1`, and that database is `:memory:`;
  there is nothing to keep.
- **`--parallel 16`** (or `auto`) — slower than 8, see the table above.
