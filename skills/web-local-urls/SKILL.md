---
name: web-local-urls
description: "Which host and port to put in any local link handed to the user from the web codespace: the site is http://rover.local:8001, never localhost:8000; Storybook is http://rover.local:6006, never localhost:6006 or rover.local:8001/storybook/. Use whenever writing a local URL for the user (a page to check, admin or impersonation links, fixture links, Storybook stories), or when a local link shows no CSS, a blank page, or 'site can't be reached'."
---

# Local URLs in the web codespace

Give the user `rover.local`, not `localhost`. Logins are per host, so after a host switch the user must sign in (and impersonate) again.

| What | Link | Why not the others |
|------|------|--------------------|
| Site, admin, impersonation, fixture links | `http://rover.local:8001` (container `web-miniflare-1`) | `localhost:8000` is Django alone: every `/static/dist/*` bundle 404s, so pages render with no CSS and no React. `:3000` is the webpack dev server; `:8011` is nginx and returns an empty 204 at `/`. |
| Storybook | `http://rover.local:6006` (container `web-storybook-1`) | `rover.local:8001/storybook/` serves the manager HTML but returns every JS asset as HTML (`Failed to load module script ... MIME type of "text/html"`), so the page is blank. |

`rover-fixture-create`'s `local` target already resolves to `rover.local:8001`.

## "Site can't be reached"

The user's browser reaches the codespace only through forwarded ports. Check what is forwarded:

```bash
gh codespace ports -c "$CODESPACE_NAME"
```

`8001` is forwarded by default; `6006` (and any ad-hoc port such as a worktree Storybook on `6007`) is not. A port can't be added from the terminal: `gh codespace ports visibility 6006:private` returns `404 Not Found` until the port exists. The user adds it in VS Code: **Ports** panel → **Forward a Port** → the port number. After that, `rover.local:<port>` works in their browser, and so does `https://$CODESPACE_NAME-<port>.$GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN`.

Starting Storybook itself: see `web-storybook-local`.
