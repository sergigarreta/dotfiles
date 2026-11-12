---
name: codespace-disk-cleanup
description: "Free disk space in the web codespace when it warns about low space, or when asked to clean docker images, worktrees or disk. Measure first: the usual culprit is git temp packs (tmp_pack_*) in /workspaces/web/.git left by a fetch that keeps failing, not docker. Covers finding the space, the safe deletions, and repairing the repo so the garbage stops coming back."
---

# Codespace disk cleanup

## 1. Measure before deleting

```bash
df -h /
docker system df
cd /workspaces/web && git worktree list
du -xsh /workspaces/web/* /workspaces/web/.[!.]* 2>/dev/null | sort -h | tail
git -C /workspaces/web count-objects -vH   # look at "garbage" / "size-garbage"
```

For scale, a healthy `.git` here is about 7GB (`size-pack`). A `.git` of tens of GB means step 2.

## 2. Git temp packs (the big one, seen at 51GB)

`count-objects` prints `warning: garbage found: ./objects/pack/tmp_pack_*` and a large `size-garbage`. Every failed `git fetch` leaves a ~120MB `tmp_pack_*` file. VS Code autofetch fetches once per worktree, in bursts of 4 every few minutes, so these files can fill the disk in a day.

Delete them. Skip files modified in the last 2 minutes, because a fetch may still be writing them:

```bash
find /workspaces/web/.git/objects/pack -maxdepth 1 -name 'tmp_pack_*' -mmin +2 -delete
```

The files come back until the fetch is fixed. To find the cause:

```bash
ls -lt --time-style=+%T /workspaces/web/.git/objects/pack/tmp_pack_* | head   # still growing?
git -C /workspaces/web fetch origin        # see the error
```

`fatal: pack has 1 unresolved delta` / `fetch-pack: invalid index-pack output` means the local repo is missing objects. When `git fetch origin master` succeeds but the full fetch fails, that is the case. To confirm (takes about 7 minutes):

```bash
git -C /workspaces/web fsck --connectivity-only --no-dangling   # "missing tree ..." = corrupt
```

In the 2026-11 incident the missing trees belonged to real `master` commits (`git for-each-ref --contains <commit>` listed master-based branches), so deleting local branches does not help. `git gc` then also fails with `fatal: bad tree object <sha>`.

Do not re-download the repo. `git fetch --refetch origin` (~7GB in one pack) ended with `fatal: early EOF`. Only a handful of objects are missing (9 trees in the 2026-11 incident), and GitHub serves them by sha, so fetch just those:

```bash
cd /workspaces/web
git fsck --connectivity-only --no-dangling 2>&1 | awk '/^missing/{print $3}' > /tmp/missing.txt   # ~7 min; full list
bash ~/.claude/skills/codespace-disk-cleanup/heal-missing-objects.sh /workspaces/web /tmp/missing.txt
```

[`heal-missing-objects.sh`](heal-missing-objects.sh) works in rounds. Each round, `rev-list --missing=print` under the listed objects finds what is still missing. The script fetches those shas from GitHub into a temp bare repo, then writes each one into the real repo with `hash-object -w` and checks that the hash matches. Rounds matter: a restored tree can point at sub-trees that are also missing, and fsck lists only the top of each gap. In the incident, 9 trees led to 4, then 1, then 1, then 0. Do not copy the temp repo's packs, because they carry `.promisor` markers. Do not walk the temp repo with `rev-list` either: it stalls trying to lazy-fetch objects its filtered pack left out.

Then check that `git fetch origin` exits 0. A one-off exit 1 can be a ref-lock race with VS Code autofetch, so retry once. Finish with `git fsck --connectivity-only --no-dangling` (expect no `missing`), `git gc --prune=now`, and the temp-pack `find ... -delete` above. When checking exit codes, use `${PIPESTATUS[0]}`: piping into `tail` hides failures.

## 3. Worktrees (~1GB each, more with node_modules)

`.claude/worktrees/<KEY>`. Only remove a worktree that is clean and fully pushed, and whose PR is merged or closed:

```bash
cd /workspaces/web
for p in .claude/worktrees/*; do b=$(basename $p)
  echo "$b dirty=$(git -C $p status --porcelain | wc -l) unpushed=$(git -C $p log --oneline @{u}..HEAD 2>/dev/null | wc -l)"
  gh pr list --head $b --state all --json number,state -q '.[]|"\(.number) \(.state)"'
done
git worktree remove .claude/worktrees/<KEY> && git worktree prune
```

Keep any worktree that has uncommitted changes or no PR yet. `git worktree remove` keeps the branch.

## 4. Docker (usually only 1–3GB)

```bash
docker image prune -f        # untagged images left over from dsync; safe
docker container prune -f    # stopped containers; dsync / dc up recreates them
```

Leave `docker image prune -a` and `docker volume prune` alone: the volumes hold local DB data, and `dsync` would have to re-pull every image.

## Smaller items

`~/.cache` (~850MB), `venv` (~1.8GB, rebuilt by the image), `~/.npm`. Clear these only if the steps above were not enough.
