#!/usr/bin/env bash
#
# Scan git worktrees and classify them as safe-to-remove or keep.
# Outputs JSON to stdout.
#
# Usage: scan-worktrees.sh [main-branch]
#   main-branch: defaults to "main", falls back to "master" if "main" doesn't exist

set -euo pipefail

MAIN_BRANCH="${1:-}"

if [ -z "$MAIN_BRANCH" ]; then
  if git show-ref --verify --quiet refs/remotes/origin/main 2>/dev/null; then
    MAIN_BRANCH="main"
  elif git show-ref --verify --quiet refs/remotes/origin/master 2>/dev/null; then
    MAIN_BRANCH="master"
  else
    echo '{"error": "Could not determine main branch. Pass it as an argument."}' >&2
    exit 1
  fi
fi

git fetch --prune origin 2>/dev/null

# Patterns for files whose changes don't represent meaningful work.
is_insignificant() {
  local file="$1"
  case "$file" in
    package-lock.json|pnpm-lock.yaml|yarn.lock) return 0 ;;
    next-env.d.ts) return 0 ;;
    .next/*) return 0 ;;
    node_modules/*) return 0 ;;
    */generated/*|*/gen/*) return 0 ;;
    *.generated.*) return 0 ;;
    *) return 1 ;;
  esac
}

safe_to_remove='[]'
to_keep='[]'
skipped='[]'

while IFS= read -r field; do
  # git worktree list --porcelain gives blocks separated by blank lines:
  #   worktree /path
  #   HEAD <sha>
  #   branch refs/heads/<name>
  #   (or "detached" instead of branch)

  # Skip blank lines between blocks.
  [ -z "$field" ] && continue

  # Each block starts with "worktree ..." — begin a new entry.
  case "$field" in "worktree "*) ;; *) continue ;; esac

  wt_path="${field#worktree }"
  wt_branch=""
  is_detached=false
  is_bare=false

  while IFS= read -r field; do
    [ -z "$field" ] && break
    case "$field" in
      "branch "*)    wt_branch="${field#branch refs/heads/}" ;;
      "detached")    is_detached=true ;;
      "bare")        is_bare=true ;;
    esac
  done

  # Skip bare repos and main worktree.
  if $is_bare; then
    continue
  fi
  if [ "$wt_branch" = "$MAIN_BRANCH" ]; then
    continue
  fi

  # Skip detached HEAD worktrees — report them.
  if $is_detached; then
    skipped=$(printf '%s' "$skipped" | jq -c --arg p "$wt_path" '. + [{"path": $p, "reason": "detached HEAD"}]')
    continue
  fi

  # A merged PR is the most reliable merge signal (and the one that drives the
  # removal proposal even when leftover uncommitted drift remains). Look it up
  # once up front and reuse it for both merge detection and the safety check.
  pr_merged=false
  pr_number=""
  if command -v gh >/dev/null 2>&1; then
    pr_number=$(gh pr list --head "$wt_branch" --state merged --json number --jq '.[0].number' 2>/dev/null || true)
    if [ -n "$pr_number" ]; then
      pr_merged=true
    fi
  fi

  # Check if branch is merged: PR merged, remote tracking branch gone, or all
  # commits in origin/main.
  is_merged=false
  remote_gone=false

  if ! git show-ref --verify --quiet "refs/remotes/origin/$wt_branch" 2>/dev/null; then
    remote_gone=true
  fi

  if $pr_merged; then
    is_merged=true
  else
    unpushed_to_main_count=$(git rev-list --count "origin/$MAIN_BRANCH..$wt_branch" -- 2>/dev/null || echo 0)
    if [ "$unpushed_to_main_count" -eq 0 ]; then
      is_merged=true
    elif $remote_gone; then
      # Remote branch deleted but there are commits not in main — could be
      # a squash merge. Check if the tree diff against origin/main is empty,
      # meaning the net effect of the branch is already in main.
      if git diff --quiet "origin/$MAIN_BRANCH...$wt_branch" -- 2>/dev/null; then
        is_merged=true
      fi
    fi
  fi

  if ! $is_merged; then
    reason="branch not merged into origin/$MAIN_BRANCH"
    to_keep=$(printf '%s' "$to_keep" | jq -c \
      --arg p "$wt_path" --arg b "$wt_branch" --arg r "$reason" \
      '. + [{"path": $p, "branch": $b, "reason": $r}]')
    continue
  fi

  # Branch is merged. Check safety.

  # Genuinely unpushed commits are those on the worktree HEAD that are not on the
  # branch's OWN remote tracking ref — compared against origin/<branch>, never
  # origin/main. A squash-merged branch always sits "ahead of main" via its
  # pre-squash commits even though the squashed result is already in main, so
  # comparing against main produces a false positive on every squash merge. If
  # the remote branch is gone (deleted after merge) there is nothing left to push
  # to, so there is no unpushed work to protect.
  unpushed_note=""
  if git show-ref --verify --quiet "refs/remotes/origin/$wt_branch" 2>/dev/null; then
    unpushed_count=$(git -C "$wt_path" rev-list --count "origin/$wt_branch..HEAD" -- 2>/dev/null || echo 0)
    if [ "$unpushed_count" -gt 0 ]; then
      unpushed_note="$unpushed_count unpushed commit(s)"
    fi
  fi

  # Meaningful uncommitted changes.
  meaningful_changes=""
  while IFS= read -r status_line; do
    [ -z "$status_line" ] && continue
    # Status line format: XY <file> or XY <file> -> <file>
    file="${status_line:3}"
    file="${file%% -> *}"
    if ! is_insignificant "$file"; then
      meaningful_changes="${meaningful_changes}${file}\n"
    fi
  done < <(git -C "$wt_path" status --porcelain 2>/dev/null)

  uncommitted_note=""
  if [ -n "$meaningful_changes" ]; then
    # Truncate to first few files for the reason string.
    file_list=$(printf '%b' "$meaningful_changes" | head -5 | paste -sd ',' -)
    uncommitted_note="uncommitted changes: $file_list"
  fi

  # Unpushed commits are potential lost work regardless of PR status — always
  # keep those. Otherwise, if the PR is merged we propose removal even with
  # leftover uncommitted drift, surfacing it as a caveat so nothing is dropped
  # silently. Without a merged PR, uncommitted changes still force a keep.
  if [ -n "$unpushed_note" ]; then
    reason="$unpushed_note"
    [ -n "$uncommitted_note" ] && reason="$reason; $uncommitted_note"
    to_keep=$(printf '%s' "$to_keep" | jq -c \
      --arg p "$wt_path" --arg b "$wt_branch" --arg r "$reason" \
      '. + [{"path": $p, "branch": $b, "reason": $r}]')
  elif [ -z "$uncommitted_note" ]; then
    safe_to_remove=$(printf '%s' "$safe_to_remove" | jq -c \
      --arg p "$wt_path" --arg b "$wt_branch" --arg pr "$pr_number" \
      '. + [{"path": $p, "branch": $b} + (if $pr == "" then {} else {"pr": ($pr | tonumber)} end)]')
  elif $pr_merged; then
    safe_to_remove=$(printf '%s' "$safe_to_remove" | jq -c \
      --arg p "$wt_path" --arg b "$wt_branch" --arg pr "$pr_number" --arg c "$uncommitted_note" \
      '. + [{"path": $p, "branch": $b, "pr": ($pr | tonumber), "caveat": $c}]')
  else
    to_keep=$(printf '%s' "$to_keep" | jq -c \
      --arg p "$wt_path" --arg b "$wt_branch" --arg r "$uncommitted_note" \
      '. + [{"path": $p, "branch": $b, "reason": $r}]')
  fi

done < <(git worktree list --porcelain)

jq -n \
  --argjson safe "$safe_to_remove" \
  --argjson keep "$to_keep" \
  --argjson skipped "$skipped" \
  --arg main "$MAIN_BRANCH" \
  '{main_branch: $main, safe_to_remove: $safe, to_keep: $keep, skipped: $skipped}'
