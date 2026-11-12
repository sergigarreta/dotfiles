---
name: web-storybook-local
description: "Start the web repo's Storybook in the codespace and hand the user working links: the docker `storybook` container for the main checkout, a separate dev server for a git worktree, and the manual VS Code port forward the user must add. Use when asked to run, open or check Storybook or a story locally, to iterate on UI in Storybook, or when Storybook links are blank or unreachable."
---

# Storybook in the web codespace

## Main checkout (`/workspaces/web`)

The `storybook` container is behind a compose profile, so `dc up` and `dsync` don't start it:

```bash
dc --profile storybook up -d storybook
```

- It mounts `/workspaces/web`, so it serves the **main checkout's** working tree, whatever branch that is.
- Starting it also runs `pnpm_installer` first. The first webpack build takes a few minutes; `dc logs -f storybook` shows progress up to `[webpack.Progress] 100%`.
- Ready check, and the story ids it knows:

  ```bash
  curl -s -o /dev/null -w '%{http_code}\n' http://rover.local:6006/index.json
  curl -s http://rover.local:6006/index.json | python3 -c "import json,sys; print([k for k in json.load(sys.stdin)['entries'] if 'KEYWORD' in k])"
  ```

## A git worktree

The container can't see a worktree. Run a dev server from the worktree on another port, in the background:

```bash
cd <worktree>/src/frontend/storybook
corepack pnpm@10.30.1 run compile-messages   # once: generates i18n/generated, else "Can't resolve './generated'"
NODE_ENV=development corepack pnpm@10.30.1 exec storybook dev -p 6007 --no-open --ci
```

Use `corepack pnpm@<packageManager version>`: plain `pnpm` can pick a newer pnpm and fail with `ERR_PNPM_BAD_PM_VERSION`. Never symlink main's `node_modules` into the worktree. See `web-worktree-checks`.

## Port forwarding: the user has to do it

The codespace doesn't forward 6006 (or 6007). The terminal can't add it: `gh codespace ports visibility 6006:private` returns `404 Not Found` until the port exists. Tell the user, before handing links:

> In VS Code open the **Ports** panel → **Forward a Port** → `6006`.

Check with `gh codespace ports -c "$CODESPACE_NAME"`.

## Links to give

Host is `rover.local`, not `localhost` (see `web-local-urls`). Never `rover.local:8001/storybook/`: its JS assets come back as HTML and the page is blank.

- In Storybook, with controls: `http://rover.local:6006/?path=/story/<story-id>`
- Story alone, full window: `http://rover.local:6006/iframe.html?id=<story-id>&viewMode=story`
- Arg overrides in the URL: `&args=name:value;other:value`
- Inside the Storybook UI: `F` full screen, `S` sidebar, `A` addons panel.
