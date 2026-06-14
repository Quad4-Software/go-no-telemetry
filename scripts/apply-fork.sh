#!/bin/sh
# Idempotently apply no-telemetry fork changes on top of upstream Go.
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
OVERLAYS="$ROOT/fork/overlays"
REMOVE="$ROOT/fork/remove.txt"

log() { echo "[apply-fork] $*" >&2; }

if [ ! -d "$OVERLAYS" ]; then
    log "ERROR: missing $OVERLAYS"
    exit 1
fi

log "Copying overlay files..."
find "$OVERLAYS" -type f | while IFS= read -r src; do
    rel=${src#$OVERLAYS/}
    dest="$ROOT/$rel"
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
done

if [ -f "$REMOVE" ]; then
    log "Removing upstream telemetry files..."
    while IFS= read -r path; do
        case "$path" in ''|'#'*) continue ;; esac
        rm -rf "$ROOT/$path"
    done < "$REMOVE"
fi

"$ROOT/scripts/strip-vendor-telemetry.sh"

if [ -d "$ROOT/fork/root" ]; then
    log "Applying fork root files..."
    cp -a "$ROOT/fork/root/." "$ROOT/"
fi

if [ -d "$ROOT/fork/github" ]; then
    log "Applying GitHub templates..."
    mkdir -p "$ROOT/.github"
    cp -a "$ROOT/fork/github/." "$ROOT/.github/"
fi

log "Done."
