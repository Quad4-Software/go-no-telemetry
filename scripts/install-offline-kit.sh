#!/bin/sh
# Install go-no-telemtry from an extracted offline kit (air-gapped).
set -eu

KIT_ROOT=$(CDPATH= cd "$(dirname "$0")" && pwd)
. "$KIT_ROOT/platform.sh"

GONOT_ROOT="${GONOT_ROOT:-$HOME/.gonot}"
GONOT_VERSIONS="$GONOT_ROOT/versions"
GONOT_BIN="$GONOT_ROOT/bin"
GONOT_CURRENT="$GONOT_ROOT/current"
SYSTEM_GO_DIR="/usr/local/go-no-telemtry"

log() { echo "[install-offline-kit] $*" >&2; }

usage() {
    cat <<'EOF'
Usage: install-offline-kit.sh <command> [name]

Commands:
  verify              Verify kit checksums
  prebuilt [name]     Install matching prebuilt release to ~/.gonot
  prebuilt-system     Install matching prebuilt release to /usr/local/go-no-telemtry
  build [name]        Build from source using bundled bootstrap (offline)
  build-full [name]   Full bootstrap chain from gcc (offline, slow)
  help                Show this help

Environment:
  GONOT_ROOT          Version manager root (default: ~/.gonot)
  FULL_BOOTSTRAP=1    Force full clang->go1.4 chain (build-full)
EOF
}

read_manifest_tag() {
    if [ -f "$KIT_ROOT/MANIFEST.json" ]; then
        sed -n 's/.*"tag"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$KIT_ROOT/MANIFEST.json" | head -1
    fi
}

cmd_verify() {
    if [ -f "$KIT_ROOT/SHA256SUMS" ]; then
        (
            cd "$KIT_ROOT"
            sha256sum -c SHA256SUMS
        )
        log "Checksums OK"
    else
        log "ERROR: SHA256SUMS not found"
        exit 1
    fi
}

install_prebuilt_to() {
    dest_root=$1
    name=$2
    plat=$(detect_platform)
    tag=$(read_manifest_tag)
    if [ -z "$tag" ]; then
        log "ERROR: cannot determine release tag from MANIFEST.json"
        exit 1
    fi
    archive=""
    if archive=$(find_release_archive "$KIT_ROOT/releases" "$tag" "$plat"); then
        :
    else
        log "ERROR: no prebuilt release for platform $plat (tag $tag)"
        log "Available:"
        ls -la "$KIT_ROOT/releases" 2>/dev/null || log "  (no releases/ directory)"
        exit 1
    fi
    log "Installing from $archive"
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/gonot-install.XXXXXX")
    case "$archive" in
        *.zip)
            unzip -q "$archive" -d "$tmp"
            ;;
        *.tar.gz)
            tar -xzf "$archive" -C "$tmp"
            ;;
        *)
            log "ERROR: unsupported archive: $archive"
            exit 1
            ;;
    esac
    src=$(find "$tmp" -name go -type d -path '*/bin' 2>/dev/null | head -1 | sed 's|/bin||')
    if [ -z "$src" ] || [ ! -x "$src/bin/go" ]; then
        src=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -1)
    fi
    if [ ! -x "$src/bin/go" ] && [ ! -f "$src/bin/go.exe" ]; then
        log "ERROR: could not find go binary in archive"
        exit 1
    fi
    if [ "$dest_root" = "gonot" ]; then
        mkdir -p "$GONOT_VERSIONS"
        rm -rf "$GONOT_VERSIONS/$name"
        cp -a "$src" "$GONOT_VERSIONS/$name"
        mkdir -p "$GONOT_BIN"
        ln -sf "$GONOT_VERSIONS/$name/bin/go" "$GONOT_BIN/go"
        ln -sf "$GONOT_VERSIONS/$name/bin/gofmt" "$GONOT_BIN/gofmt"
        ln -sfn "$GONOT_VERSIONS/$name" "$GONOT_CURRENT"
        log "Installed to ~/.gonot/versions/$name"
        log "  $($GONOT_BIN/go version)"
        log "  export PATH=\"$GONOT_BIN:\$PATH\""
    else
        log "Installing system-wide to $SYSTEM_GO_DIR (may need sudo)"
        sudo rm -rf "$SYSTEM_GO_DIR"
        sudo cp -a "$src" "$SYSTEM_GO_DIR"
        sudo ln -sf "$SYSTEM_GO_DIR/bin/go" /usr/local/bin/go
        sudo ln -sf "$SYSTEM_GO_DIR/bin/gofmt" /usr/local/bin/gofmt
        log "  $($SYSTEM_GO_DIR/bin/go version)"
    fi
    rm -rf "$tmp"
}

cmd_build() {
    name=${1:-offline}
    full=${2:-0}
    plat=$(detect_platform)
    export BUNDLE_ROOT="$KIT_ROOT"
    export FORK_DIR="$KIT_ROOT/source"
    export TARDIR="$KIT_ROOT/bootstrap-tars"
    export OFFLINE=true
    if [ "$full" = "1" ]; then
        export FULL_BOOTSTRAP=1
    fi
    if bundled=$(bundled_bootstrap_root "$KIT_ROOT" "$plat"); then
        export GOROOT_BOOTSTRAP="$bundled"
        log "Using bundled bootstrap: $GOROOT_BOOTSTRAP"
    else
        log "WARN: no bundled bootstrap for $plat; will use full chain or system Go"
    fi
    "$KIT_ROOT/source/bootstrap.sh" --offline install "$name"
}

CMD=${1:-help}
shift || true

case "$CMD" in
    verify) cmd_verify ;;
    prebuilt) install_prebuilt_to gonot "${1:-offline}" ;;
    prebuilt-system) install_prebuilt_to system "${1:-offline}" ;;
    build) cmd_build "${1:-offline}" 0 ;;
    build-full) cmd_build "${1:-offline}" 1 ;;
    help|-h|--help) usage ;;
    *) log "unknown command: $CMD"; usage; exit 1 ;;
esac
