---
name: worktree-cleanup
description: >
  Clean up merged git worktrees and their local branches. Use this skill whenever
  the user wants to clean up worktrees, prune stale worktrees, remove merged
  worktrees, tidy up their worktree list, or asks anything about cleaning up
  after merged branches in a worktree-based workflow. Also trigger when the user
  says things like "clean up worktrees", "remove old worktrees", "which worktrees
  can I delete", "prune merged branches", or "tidy up my git worktrees". If the
  user works with git worktrees and mentions cleanup or pruning, this skill applies.
---

# Worktree Cleanup

Identify merged git worktrees that are safe to remove, present them for review,
and clean up after user confirmation. The goal is to keep the worktree list tidy
without losing any unpushed or uncommitted work.

## Workflow

### Step 1: Scan worktrees

Run the bundled scan script from the repo's main worktree (or bare repo root):

```bash
bash <skill-path>/scripts/scan-worktrees.sh [main-branch]
```

The main-branch argument is optional — the script auto-detects `main` or `master`.
It requires `jq` to be available.

The script handles everything: fetches with `--prune`, lists worktrees, classifies
each as merged or not, and checks for unpushed commits and meaningful uncommitted
changes. It outputs JSON:

```json
{
  "main_branch": "main",
  "safe_to_remove": [
    {"path": "/path/to/worktree", "branch": "feature-foo", "pr": 123},
    {"path": "/path/to/other", "branch": "feature-bar", "pr": 124, "caveat": "uncommitted changes: core-platform/package.json"}
  ],
  "to_keep": [
    {"path": "/path/to/worktree", "branch": "wip-thing", "reason": "3 unpushed commit(s)"}
  ],
  "skipped": [
    {"path": "/path/to/worktree", "reason": "detached HEAD"}
  ]
}
```

#### How the script classifies worktrees

A branch is **merged** if its PR is merged (checked first via `gh pr list
--state merged`, the most reliable signal), or its remote tracking branch is gone
(deleted after merge), or all its commits are reachable from `origin/<main>`, or
for squash merges the tree diff against `origin/<main>` is empty (the net effect
of the branch is already in main).

A merged worktree is proposed for removal (in `safe_to_remove`) when it has no
genuinely unpushed commits. There are two cases:
- **Clean** — no meaningful uncommitted changes: proposed with no caveat.
- **Merged PR with leftover drift** — the branch's PR is merged but the worktree
  still has meaningful uncommitted changes (e.g. dependency-bump drift on
  `package.json` that lingers after merge). It is still proposed for removal, but
  carries a `caveat` field naming the uncommitted files so nothing is dropped
  silently. A worktree merged only by the git heuristics (no merged PR) with such
  drift stays in `to_keep` — the merged PR is what justifies overriding the drift.

Unpushed commits are potential lost work and always force `to_keep`, regardless
of PR status. They are counted against the branch's OWN remote
(`origin/<branch>..HEAD`), never against `origin/<main>` — a squash-merged branch
always looks "ahead of main" via its pre-squash commits, which would otherwise
flag every squash merge as unsafe. If the branch's remote is gone (deleted after
merge) there is nothing left to push to, so unpushed commits are not a concern.
The script filters out insignificant drift from `git status --porcelain`:
- Lock files: `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`
- Generated files: paths containing `/generated/` or `/gen/`, `*.generated.*`
- Next.js artifacts: `next-env.d.ts`, `.next/*`
- `node_modules/*`

### Step 2: Present results

Show two clearly separated lists:

**Safe to remove** — merged, no unpushed commits. Include the PR number when
present, and surface any `caveat` so the user knows uncommitted drift will be
discarded along with the worktree:
```
Safe to remove:
  /path/to/worktree (branch: feature-foo, PR #123)
  /path/to/worktree (branch: fix-bar, PR #124) — caveat: uncommitted changes: core-platform/package.json
```

**Keep** — has unpushed commits or meaningful uncommitted work (with no merged
PR to justify discarding it), with the reason:
```
Keep:
  /path/to/worktree (branch: wip-thing) — 3 unpushed commits
  /path/to/worktree (branch: experiment) — uncommitted changes: src/app.tsx
```

If `skipped` is non-empty, mention those too (e.g. detached HEAD worktrees).

If there's nothing safe to remove, say so and stop.

### Step 3: Confirm and clean up

Ask the user to confirm before removing anything. Worktree removal and branch
deletion cannot be undone easily — always wait for explicit confirmation.

After confirmation, remove each safe worktree and delete its branch. Run these as
plain sequential commands — do NOT pipe a list into a `while read` loop, as the
subshell can drop `git` from `PATH`.

```bash
git worktree remove --force <worktree-path> || { rm -rf <worktree-path> && git worktree prune; }
git branch -d <branch-name> || git branch -D <branch-name>
```

Use `--force` on worktree remove because the worktree may have untracked files
(build artifacts, etc.) that aren't meaningful. `worktree remove` can still fail
with "Directory not empty" (e.g. a nested `.git` in a sub-package) — fall back to
`rm -rf <path>` followed by `git worktree prune`.

Try `git branch -d` first as a safety net, but expect it to fail on squash-merged
branches: git can't see the squashed commits as merged, so it reports the branch
as "not fully merged". Since everything in `safe_to_remove` has already been
verified merged by the scan (via tree diff or a merged PR), fall back to
`git branch -D` when `-d` refuses. If you skipped the scan or are unsure a branch
is really merged, stop and confirm with the user before using `-D`.

Finally, run `git worktree prune` to clean up any stale worktree metadata.
