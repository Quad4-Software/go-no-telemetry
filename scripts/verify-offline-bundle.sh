#!/bin/sh
# Verify checksums inside an offline kit archive or extracted directory.
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
TARGET=${1:?usage: verify-offline-bundle.sh ARCHIVE|DIR}

log() { echo "[verify-offline-bundle] $*" >&2; }

WORK=""
cleanup() { [ -n "$WORK" ] && rm -rf "$WORK"; }
trap cleanup EXIT

if [ -f "$TARGET" ]; then
    WORK=$(mktemp -d "${TMPDIR:-/tmp}/verify-kit.XXXXXX")
    case "$TARGET" in
        *.zip)
            unzip -q "$TARGET" -d "$WORK"
            ;;
        *.tar.gz|*.tgz)
            tar -xzf "$TARGET" -C "$WORK"
            ;;
        *)
            log "ERROR: unsupported archive format (use .zip or .tar.gz): $TARGET"
            exit 1
            ;;
    esac
    KIT=$(find "$WORK" -mindepth 1 -maxdepth 1 -type d | head -1)
elif [ -d "$TARGET" ]; then
    KIT=$TARGET
else
    log "ERROR: not a file or directory: $TARGET"
    exit 1
fi

if [ ! -f "$KIT/SHA256SUMS" ]; then
    log "ERROR: missing SHA256SUMS in $KIT"
    exit 1
fi

(
    cd "$KIT"
    sha256sum -c SHA256SUMS
)

if [ -f "$KIT/MANIFEST.json" ]; then
    log "Manifest:"
    cat "$KIT/MANIFEST.json"
fi

log "OK"
