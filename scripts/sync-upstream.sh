#!/bin/sh
# Fetch upstream Go and rebase this fork onto it.
# After a successful rebase, re-applies overlays to catch any drift.
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

log() { echo "[sync-upstream] $*" >&2; }

if ! git remote | grep -qx upstream; then
    log "Adding upstream remote..."
    git remote add upstream https://go.googlesource.com/go
fi

git fetch upstream

STASHED=0
if ! git diff-index --quiet HEAD -- 2>/dev/null || [ -n "$(git ls-files --others --exclude-standard)" ]; then
    log "Stashing local changes..."
    git stash push -u -m "sync-upstream-$(date +%Y%m%d%H%M%S)"
    STASHED=1
fi

BEHIND=$(git rev-list --count HEAD..upstream/master 2>/dev/null || echo 0)
if [ "$BEHIND" = "0" ]; then
    log "Already up to date with upstream/master"
    "$ROOT/scripts/apply-fork.sh"
    [ "$STASHED" = 1 ] && git stash pop || true
    exit 0
fi

log "Rebasing onto upstream/master ($BEHIND commits behind)..."
if ! git rebase upstream/master; then
    log ""
    log "Rebase failed. To recover with a clean overlay apply:"
    log "  git rebase --abort"
    log "  git reset --hard upstream/master"
    log "  ./scripts/apply-fork.sh"
    log "  git add -A"
    log "  git commit -m \"Strip telemetry from Go fork\""
    log "  # Re-commit fork/ and scripts/ if needed"
    exit 1
fi

log "Refreshing fork overlays..."
"$ROOT/scripts/apply-fork.sh"

if ! git diff-index --quiet HEAD --; then
    log "Overlay refresh changed files. Review with: git diff"
    log "Commit when ready: git add -A && git commit -m \"Refresh no-telemetry overlays\""
fi

if command -v go >/dev/null 2>&1; then
    "$ROOT/scripts/verify-fork.sh"
else
    log "Skipping verify (go not installed)"
fi

if [ "$STASHED" = 1 ]; then
    if git stash pop; then
        :
    else
        log "Stash pop had conflicts; resolve manually with: git stash list"
    fi
fi

log "Sync complete."
