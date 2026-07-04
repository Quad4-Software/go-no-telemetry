#!/bin/sh
# Create a full offline kit: source, bootstrap tarballs, bootstrap binaries,
# and optional prebuilt release archives.
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$ROOT/scripts/platform.sh"

TAG=""
OUTPUT=""
RELEASES_DIR=""
SKIP_BOOTSTRAP_DL=false
RUN_PREFETCH=false
STAGING=""
BOOTSTRAP_GO=go1.24.6
PLATFORMS="linux-amd64 linux-arm64 darwin-amd64 darwin-arm64 windows-amd64"

log() { echo "[make-offline-bundle] $*" >&2; }

usage() {
    cat <<'EOF'
Usage: make-offline-bundle.sh [options]

Create a full offline kit archive for air-gapped environments.

Options:
  --tag TAG           Version label (default: current git tag or HEAD)
  --output FILE       Output archive (default: go-no-telemtry-offline-TAG.zip)
  --releases DIR      Directory with prebuilt go-no-telemtry release archives
  --prefetch          Run bootstrap.sh prefetch before bundling (needs network)
  --skip-bootstrap-dl Skip downloading official Go bootstrap binaries
  -h, --help          Show this help

The kit includes:
  - Fork source tree (git archive)
  - bootstrap-tars/ (go1.4 through go1.24.6 sources)
  - bootstrap-bin/  (official go1.24.6 per platform)
  - releases/       (optional prebuilt fork binaries)
  - install-offline-kit.sh and README-OFFLINE.txt
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --tag) TAG=$2; shift 2 ;;
        --output) OUTPUT=$2; shift 2 ;;
        --releases) RELEASES_DIR=$2; shift 2 ;;
        --prefetch) RUN_PREFETCH=true; shift ;;
        --skip-bootstrap-dl) SKIP_BOOTSTRAP_DL=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) log "unknown option: $1"; usage; exit 1 ;;
    esac
done

if [ -z "$TAG" ]; then
    TAG=$(git -C "$ROOT" describe --tags --exact-match 2>/dev/null || git -C "$ROOT" rev-parse --short HEAD)
fi

if [ -z "$OUTPUT" ]; then
    safe_tag=$(echo "$TAG" | tr '/' '_')
    OUTPUT="$ROOT/go-no-telemtry-offline-${safe_tag}.zip"
fi
OUTPUT="$(cd "$(dirname "$OUTPUT")" && pwd)/$(basename "$OUTPUT")"

STAGING=$(mktemp -d "${TMPDIR:-/tmp}/offline-kit.XXXXXX")
KIT="$STAGING/go-no-telemtry-offline-${TAG}"
mkdir -p "$KIT"

cleanup() { rm -rf "$STAGING"; }
trap cleanup EXIT

if [ "$RUN_PREFETCH" = true ]; then
    log "Prefetching bootstrap source tarballs..."
    "$ROOT/bootstrap.sh" prefetch
fi

if [ ! -d "$ROOT/bootstrap-tars" ] || [ -z "$(ls -A "$ROOT/bootstrap-tars"/*.tar.gz 2>/dev/null)" ]; then
    log "ERROR: bootstrap-tars/ is empty. Run: ./bootstrap.sh prefetch"
    exit 1
fi

log "Exporting fork source..."
mkdir -p "$KIT/source"
ref="$TAG"
if ! git -C "$ROOT" rev-parse "$ref" >/dev/null 2>&1; then
    log "Tag '$TAG' not found; using HEAD"
    ref=HEAD
fi
git -C "$ROOT" archive --format=tar "$ref" | tar -x -C "$KIT/source"

log "Copying bootstrap source tarballs..."
mkdir -p "$KIT/bootstrap-tars"
cp -a "$ROOT/bootstrap-tars/"*.tar.gz "$KIT/bootstrap-tars/"

if [ "$SKIP_BOOTSTRAP_DL" = false ]; then
    log "Downloading official $BOOTSTRAP_GO bootstrap binaries..."
    mkdir -p "$KIT/bootstrap-bin"
    for plat in $PLATFORMS; do
        goos=${plat%-*}
        goarch=${plat#*-}
        dest="$KIT/bootstrap-bin/$plat"
        mkdir -p "$dest"
        if [ "$goos" = "windows" ]; then
            url="https://go.dev/dl/${BOOTSTRAP_GO}.${plat}.zip"
            tmp=$(mktemp "${TMPDIR:-/tmp}/gobootstrap.XXXXXX.zip")
            if curl -fSL --retry 3 "$url" -o "$tmp"; then
                unzip -q "$tmp" -d "$dest"
                rm -f "$tmp"
                log "  [OK] $plat"
            else
                log "  [WARN] failed to download $url"
                rm -f "$tmp"
            fi
        else
            url="https://go.dev/dl/${BOOTSTRAP_GO}.${plat}.tar.gz"
            tmp=$(mktemp "${TMPDIR:-/tmp}/gobootstrap.XXXXXX.tar.gz")
            if curl -fSL --retry 3 "$url" -o "$tmp"; then
                tar -xzf "$tmp" -C "$dest"
                rm -f "$tmp"
                log "  [OK] $plat"
            else
                log "  [WARN] failed to download $url"
                rm -f "$tmp"
            fi
        fi
    done
fi

if [ -n "$RELEASES_DIR" ] && [ -d "$RELEASES_DIR" ]; then
    log "Copying prebuilt release archives..."
    mkdir -p "$KIT/releases"
    cp -a "$RELEASES_DIR"/go-no-telemtry-* "$KIT/releases/" 2>/dev/null || true
fi

log "Adding installer scripts..."
cp "$ROOT/scripts/install-offline-kit.sh" "$KIT/install-offline-kit.sh"
cp "$ROOT/scripts/install-offline-kit.ps1" "$KIT/install-offline-kit.ps1"
cp "$ROOT/scripts/install-offline-kit.bat" "$KIT/install-offline-kit.bat"
cp "$ROOT/scripts/install-offline-kit-gui.ps1" "$KIT/install-offline-kit-gui.ps1"
cp "$ROOT/scripts/Setup.bat" "$KIT/Setup.bat"
cp "$ROOT/scripts/platform.sh" "$KIT/platform.sh"
chmod +x "$KIT/install-offline-kit.sh"

cat > "$KIT/README-OFFLINE.txt" <<EOF
go-no-telemtry offline kit ($TAG)
================================

This kit supports fully offline installation and source builds.

Linux / macOS / Git Bash:
  ./install-offline-kit.sh verify
  ./install-offline-kit.sh prebuilt prod
  ./install-offline-kit.sh build prod

Windows (PowerShell or cmd):
  Right-click the .zip -> Extract All, then open the folder
  Setup.bat                    (recommended - graphical wizard)
  install-offline-kit.bat verify
  install-offline-kit.bat prebuilt prod
  install-offline-kit.bat build prod

Optional: build a single Setup.exe installer (on a machine with Inno Setup 6):
  powershell -File scripts\build-windows-installer.ps1 -KitDir path\to\extracted-kit

Requirements:
  - Linux/macOS: POSIX shell, tar, unzip
  - Windows: PowerShell 5.1+ (included in Windows 10/11)
  - gcc/clang only needed for full bootstrap chain on Unix (build-full)

Layout:
  source/          Fork source tree
  bootstrap-tars/  Upstream Go sources for full bootstrap chain
  bootstrap-bin/   Official $BOOTSTRAP_GO binaries per platform
  releases/        Prebuilt go-no-telemtry archives ( .zip on Windows )
EOF

log "Writing manifest..."
commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)
created=$(date -u +%Y-%m-%dT%H:%M:%SZ)

platforms_json=""
for plat in $PLATFORMS; do
    platforms_json="${platforms_json}\"${plat}\","
done
platforms_json="[${platforms_json%,}]"

cat > "$KIT/MANIFEST.json" <<EOF
{
  "name": "go-no-telemtry-offline-kit",
  "tag": "$TAG",
  "commit": "$commit",
  "created": "$created",
  "bootstrap_go": "$BOOTSTRAP_GO",
  "bootstrap_chain": ["go1.4", "go1.17.13", "go1.20", "go1.22.6", "go1.24.6"],
  "platforms": $platforms_json,
  "contents": {
    "source": "Fork source tree",
    "bootstrap-tars": "Upstream Go source tarballs for full bootstrap",
    "bootstrap-bin": "Official Go bootstrap binaries",
    "releases": "Prebuilt go-no-telemtry release archives"
  }
}
EOF

log "Writing checksums..."
(
    cd "$KIT"
    find . -type f ! -name SHA256SUMS | sort | while read -r f; do
        sha256sum "$f"
    done > SHA256SUMS
)

log "Creating archive: $OUTPUT"
mkdir -p "$(dirname "$OUTPUT")"
if ! command -v zip >/dev/null 2>&1; then
    log "ERROR: zip is required to build offline kits"
    exit 1
fi
(
    cd "$STAGING"
    zip -r -q "$OUTPUT" "$(basename "$KIT")"
)

log "Done: $OUTPUT ($(du -h "$OUTPUT" | awk '{print $1}'))"
log "Verify with: ./scripts/verify-offline-bundle.sh $OUTPUT"
