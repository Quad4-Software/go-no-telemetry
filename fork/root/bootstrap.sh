#!/bin/sh
# Go Full Bootstrap and Version Manager
# Builds Go entirely from source starting from clang (C compiler).
# Manages multiple installed versions of the go no telemetry fork.
#
# POSIX compliant. Modular functions. Fully offline after prefetch.
#
# Usage:
#   bootstrap.sh build [--offline] [tag]
#   bootstrap.sh install [--offline] <name> [tag]
#   bootstrap.sh uninstall <name>
#   bootstrap.sh list
#   bootstrap.sh use <name>
#   bootstrap.sh current
#   bootstrap.sh system [--offline] [name]
#   bootstrap.sh update [--offline]
#   bootstrap.sh prefetch
#
# See bootstrap.sh --help for full documentation.

set -e -u

# ---- paths and configuration ----

CC="${CC:-clang}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKDIR="${WORKDIR:-$SCRIPT_DIR/_bootstrap}"
TARDIR="${TARDIR:-$SCRIPT_DIR/bootstrap-tars}"
PARALLEL="${PARALLEL:-$(nproc)}"
FORK_DIR="${FORK_DIR:-$SCRIPT_DIR}"
GONOT_ROOT="${GONOT_ROOT:-$HOME/.gonot}"
GONOT_VERSIONS="$GONOT_ROOT/versions"
GONOT_BIN="$GONOT_ROOT/bin"
GONOT_CURRENT="$GONOT_ROOT/current"
SYSTEM_GO_DIR="/usr/local/go-no-telemetry"

# Bootstrap chain: space separated "version:bootstrap" pairs
CHAIN="go1.4:cc go1.17.13:go1.4 go1.20:go1.17.13 go1.22.6:go1.20 go1.24.6:go1.22.6"

# ---- utility functions ----

log() { echo "[$(date '+%H:%M:%S')] $*" >&2; }

usage() {
    cat <<'USAGE'
Usage: bootstrap.sh <command> [options]

Commands:
  build                   Build the fork (original bootstrap behavior)
    --offline             Use local tarballs only
    [tag]                 Git tag to build (default: current HEAD)

  install <name>          Build and install under ~/.gonot/versions/<name>/
    --offline             Use local tarballs only
    [tag]                 Git tag to build (default: current HEAD)

  uninstall <name>        Remove a version from ~/.gonot

  list                    Show all installed versions

  use <name>              Set the active version (updates PATH symlinks)

  current                 Show which version is active

  system [name]           Install system wide at /usr/local/go-no-telemetry
    --offline             Use local tarballs only (requires sudo)

  update                  Rebuild and reinstall the current active version
    --offline             Use local tarballs only

  prefetch                Download all bootstrap tarballs for offline use

Environment:
  CC              C compiler (default: clang)
  WORKDIR         Build workspace (default: ./_bootstrap)
  TARDIR          Source tarball directory (default: ./bootstrap-tars)
  GONOT_ROOT      Version manager root (default: ~/.gonot)
  FORK_DIR        Fork source path (default: repository root)

Bootstrap chain for build:
  clang -> go1.4 -> go1.17.13 -> go1.20 -> go1.22.6 -> go1.24.6 -> fork

Examples:
  bootstrap.sh build                      # Build fork from source
  bootstrap.sh install my-fork            # Build and register as "my-fork"
  bootstrap.sh use my-fork                # Activate "my-fork"
  bootstrap.sh system                     # Install system wide (sudo)
  bootstrap.sh prefetch                   # Cache all tarballs
  bootstrap.sh --offline install my-fork  # Build from local tarballs only
USAGE
}

# ---- tarball management ----

find_tarball() {
    v="$1"
    n="$v.tar.gz"
    for d in "$TARDIR" "$WORKDIR/tar"; do
        f="$d/$n"
        if [ -f "$f" ]; then
            echo "$f"
            return 0
        fi
    done
    return 1
}

ensure_tarball() {
    v="$1"
    n="$v.tar.gz"
    if find_tarball "$v" >/dev/null 2>&1; then
        return 0
    fi
    if [ "$OFFLINE" = true ]; then
        log "ERROR: $n not found and --offline is active"
        log "Run 'bootstrap.sh prefetch' first"
        exit 1
    fi
    mkdir -p "$TARDIR"
    log "  Downloading $v..."
    curl -fSL --retry 3 "https://github.com/golang/go/archive/refs/tags/$v.tar.gz" -o "$TARDIR/$n"
}

extract_version() {
    v="$1"
    dir="$WORKDIR/$v"
    if [ -d "$dir/src" ]; then
        return 0
    fi
    ensure_tarball "$v"
    tb=$(find_tarball "$v")
    log "  Extracting $v..."
    mkdir -p "$WORKDIR"
    td=$(mktemp -d "$WORKDIR/extract.XXXXXX")
    tar xzf "$tb" -C "$td"
    ed=""
    for entry in "$td"/*; do
        if [ -d "$entry" ]; then
            ed="$entry"
            break
        fi
    done
    if [ -n "$ed" ] && [ -d "$ed" ]; then
        mv "$ed" "$dir"
        rmdir "$td" 2>/dev/null || true
    else
        log "ERROR: could not find extracted directory"
        ls -la "$td"
        rm -rf "$td"
        exit 1
    fi
}

# ---- build functions ----

build_version() {
    v="$1"
    bootstrap="$2"
    dir="$WORKDIR/$v"
    if [ -x "$dir/bin/go" ]; then
        log "[SKIP] $v already built"
        return 0
    fi
    log "[BUILD] $v (bootstrap: $bootstrap)"
    extract_version "$v"
    (
        cd "$dir/src" || exit 1
        if [ "$bootstrap" = "cc" ]; then
            # go1.4 needs a legacy-friendly C toolchain; gcc links cgo where clang+ld fail.
            bootstrap_cc="gcc"
            if ! command -v "$bootstrap_cc" >/dev/null 2>&1; then
                bootstrap_cc="$CC"
            fi
            # go1.4 make.bash appends -Werror after CFLAGS; wrap CC so -Wno-error wins.
            wrap="$WORKDIR/cc-wrap-$$.sh"
            cat > "$wrap" <<WRAP
#!/bin/sh
exec $bootstrap_cc "\$@" -std=gnu99 -Wno-error
WRAP
            chmod +x "$wrap"
            export CC="$wrap"
        else
            export GOROOT_BOOTSTRAP="$WORKDIR/$bootstrap"
            if [ ! -x "$GOROOT_BOOTSTRAP/bin/go" ]; then
                log "ERROR: bootstrap Go not found at $GOROOT_BOOTSTRAP/bin/go"
                exit 1
            fi
        fi
        export GOFLAGS="-p=$PARALLEL"
        log "  Running make.bash..."
        mkdir -p "$WORKDIR/logs"
        lf="$WORKDIR/logs/$v.log"
        if ./make.bash > "$lf" 2>&1; then
            tail -3 "$lf" | while read line; do log "  $line"; done
        else
            log "ERROR: $v build failed (see $lf)"
            tail -30 "$lf" | while read line; do log "  $line"; done
            exit 1
        fi
    )
    if [ -x "$dir/bin/go" ]; then
        log "[DONE] $v built"
        "$dir/bin/go" version
    else
        log "[FAIL] $v: bin/go not found"
        exit 1
    fi
}

# True when a system Go toolchain can bootstrap this fork (>= Go 1.24.6).
system_bootstrap_ok() {
    if ! command -v go >/dev/null 2>&1; then
        return 1
    fi
    case "$(go env GOVERSION 2>/dev/null)" in
        go1.24.*|go1.25.*|go1.26.*|go1.27.*|go1.28.*|go1.29.*) return 0 ;;
        *) return 1 ;;
    esac
}

# Build the fork tree; GOROOT_BOOTSTRAP must already be set.
build_fork_tree() {
    fork_src="$FORK_DIR"
    if [ -n "${BUILD_TAG:-}" ]; then
        log "=== Checking out tag: $BUILD_TAG ==="
        saved_dir=$(pwd)
        cd "$fork_src"
        git fetch --tags 2>/dev/null || true
        git checkout "$BUILD_TAG" 2>/dev/null || {
            log "ERROR: tag '$BUILD_TAG' not found"
            exit 1
        }
        cd "$saved_dir"
    fi

    log "=== Building go-no-telemetry fork ==="
    log "  GOROOT_BOOTSTRAP=$GOROOT_BOOTSTRAP"
    export GOFLAGS="-p=$PARALLEL"
    lf="$WORKDIR/logs/go-no-telemtry.log"
    mkdir -p "$WORKDIR/logs"
    (
        cd "$fork_src/src" || exit 1
        if ./make.bash > "$lf" 2>&1; then
            tail -3 "$lf" | while read line; do log "  $line"; done
        else
            log "ERROR: fork build failed (see $lf)"
            tail -30 "$lf" | while read line; do log "  $line"; done
            exit 1
        fi
    )
    echo "$fork_src"
}

# Build the full bootstrap chain then our fork.
# Returns the path to the built fork.
build_fork() {
    if [ "${FULL_BOOTSTRAP:-0}" != "1" ] && system_bootstrap_ok; then
        log "=== Using system Go for bootstrap ($(go version)) ==="
        log "  Set FULL_BOOTSTRAP=1 to build the full clang -> go1.4 chain"
        export GOROOT_BOOTSTRAP="$(go env GOROOT)"
        build_fork_tree
        return
    fi

    log "=== Building bootstrap chain ==="
    for entry in $CHAIN; do
        version="${entry%:*}"
        bootstrap="${entry#*:}"
        build_version "$version" "$bootstrap"
    done
    log ""

    export GOROOT_BOOTSTRAP="$WORKDIR/go1.24.6"
    build_fork_tree
}

# ---- version manager functions ----

# Install a built fork to the version manager
install_to_gonot() {
    built_dir="$1"
    name="$2"

    log "=== Installing to ~/.gonot/versions/$name ==="
    mkdir -p "$GONOT_VERSIONS"

    if [ -d "$GONOT_VERSIONS/$name" ]; then
        log "Removing previous installation of '$name'"
        rm -rf "$GONOT_VERSIONS/$name"
    fi

    cp -a "$built_dir" "$GONOT_VERSIONS/$name"

    # Create bin symlinks
    mkdir -p "$GONOT_BIN"
    for tool in go gofmt; do
        if [ -f "$GONOT_VERSIONS/$name/bin/$tool" ]; then
            ln -sf "$GONOT_VERSIONS/$name/bin/$tool" "$GONOT_BIN/$tool"
        fi
    done

    # Update the current symlink
    ln -sfn "$GONOT_VERSIONS/$name" "$GONOT_CURRENT"

    log ""
    log "========================================"
    log " Installed: $name"
    log " Version:   $("$GONOT_BIN/go" version)"
    log " Add to PATH:"
    log "   export PATH=\"$GONOT_BIN:\$PATH\""
    log "========================================"
}

# ---- command implementations ----

cmd_build() {
    log "=== Build mode ==="
    build_fork
    built_fork="$FORK_DIR"
    log ""
    log "========================================"
    log " Fork built at: $built_fork/bin/go"
    log " Version: $("$built_fork/bin/go" version)"
    log "========================================"
}

cmd_install() {
    name="${1:-}"
    if [ -z "$name" ]; then
        log "ERROR: install requires a name argument"
        log "Example: bootstrap.sh install my-fork"
        exit 1
    fi
    shift 1

    built_dir=$(build_fork)
    install_to_gonot "$built_dir" "$name"
}

cmd_uninstall() {
    name="${1:-}"
    if [ -z "$name" ]; then
        log "ERROR: uninstall requires a name argument"
        log "Example: bootstrap.sh uninstall my-fork"
        exit 1
    fi

    target="$GONOT_VERSIONS/$name"
    if [ ! -d "$target" ]; then
        log "ERROR: version '$name' is not installed"
        exit 1
    fi

    log "Uninstalling '$name'..."

    # If this is the current version, remove the symlink
    if [ -L "$GONOT_CURRENT" ]; then
        current_target=$(readlink "$GONOT_CURRENT")
        if [ "$current_target" = "$target" ]; then
            rm -f "$GONOT_CURRENT"
            rm -f "$GONOT_BIN/go" "$GONOT_BIN/gofmt"
            log "Note: '$name' was the active version; current symlink removed"
        fi
    fi

    rm -rf "$target"
    log "Uninstalled '$name'"
}

cmd_list() {
    if [ ! -d "$GONOT_VERSIONS" ]; then
        log "No versions installed"
        exit 0
    fi

    current_name=""
    if [ -L "$GONOT_CURRENT" ]; then
        current_target=$(readlink "$GONOT_CURRENT")
        current_name=$(basename "$current_target")
    fi

    log "Installed versions:"
    for d in "$GONOT_VERSIONS"/*; do
        if [ -d "$d" ]; then
            name=$(basename "$d")
            version_info=""
            if [ -x "$d/bin/go" ]; then
                version_info=$("$d/bin/go" version 2>/dev/null | cut -d' ' -f3)
            fi
            marker=" "
            if [ "$name" = "$current_name" ]; then
                marker="*"
            fi
            log "  $marker $name  ($version_info)"
        fi
    done
}

cmd_use() {
    name="${1:-}"
    if [ -z "$name" ]; then
        log "ERROR: use requires a name argument"
        log "Example: bootstrap.sh use my-fork"
        exit 1
    fi

    target="$GONOT_VERSIONS/$name"
    if [ ! -d "$target" ]; then
        log "ERROR: version '$name' is not installed"
        log "Run 'bootstrap.sh list' to see available versions"
        exit 1
    fi

    if [ ! -x "$target/bin/go" ]; then
        log "ERROR: '$name' is missing bin/go (corrupt installation)"
        exit 1
    fi

    mkdir -p "$GONOT_BIN"
    ln -sfn "$target" "$GONOT_CURRENT"
    for tool in go gofmt; do
        if [ -f "$target/bin/$tool" ]; then
            ln -sf "$target/bin/$tool" "$GONOT_BIN/$tool"
        fi
    done

    log "Now using '$name'"
    log "  $("$GONOT_BIN/go" version)"
    log ""
    log "Add to your shell profile:"
    log "  export PATH=\"$GONOT_BIN:\$PATH\""
}

cmd_current() {
    if [ ! -L "$GONOT_CURRENT" ]; then
        log "No version is currently active"
        log "Run 'bootstrap.sh list' then 'bootstrap.sh use <name>'"
        exit 0
    fi

    target=$(readlink "$GONOT_CURRENT")
    name=$(basename "$target")

    if [ -x "$GONOT_CURRENT/bin/go" ]; then
        log "$name"
        log "  $("$GONOT_CURRENT/bin/go" version)"
    else
        log "Current symlink points to '$name' but bin/go is missing"
        log "Consider: bootstrap.sh uninstall $name"
    fi
}

cmd_system() {
    name="${1:-}"
    install_path="$SYSTEM_GO_DIR"

    if [ -n "$name" ]; then
        # Install from version manager
        if [ ! -d "$GONOT_VERSIONS/$name" ]; then
            log "ERROR: version '$name' is not installed"
            exit 1
        fi
        log "=== Installing '$name' system wide ==="
        if [ "$(id -u)" -ne 0 ]; then
            log "System install requires root. Trying sudo..."
            exec sudo "$0" system "$name"
        fi
        rm -rf "$install_path"
        cp -a "$GONOT_VERSIONS/$name" "$install_path"
    else
        # Build and install system wide
        if [ "$(id -u)" -ne 0 ]; then
            log "System install requires root. Trying sudo..."
            exec sudo "$0" system -- "$@"
        fi
        log "=== Building and installing system wide ==="
        built_dir=$(build_fork)
        log "Installing to $install_path ..."
        rm -rf "$install_path"
        cp -a "$built_dir" "$install_path"
    fi

    # Create /usr/local/bin symlinks
    for tool in go gofmt; do
        if [ -f "$install_path/bin/$tool" ]; then
            ln -sf "$install_path/bin/$tool" "/usr/local/bin/$tool"
        fi
    done

    log ""
    log "========================================"
    log " System installed at: $install_path"
    log " Version: $("$install_path/bin/go" version)"
    log " Symlinks in /usr/local/bin/"
    log "========================================"
}

cmd_update() {
    if [ ! -L "$GONOT_CURRENT" ]; then
        log "ERROR: no active version to update"
        log "Run 'bootstrap.sh use <name>' first"
        exit 1
    fi

    target=$(readlink "$GONOT_CURRENT")
    name=$(basename "$target")

    log "=== Updating '$name' ==="
    built_dir=$(build_fork)

    log "Reinstalling '$name'..."
    rm -rf "$target"
    cp -a "$built_dir" "$target"

    log "Updated '$name'"
    log "  $("$target/bin/go" version)"
}

cmd_prefetch() {
    log "=== Prefetching all bootstrap tarballs ==="
    log "Target: $TARDIR/"
    mkdir -p "$TARDIR"
    for entry in $CHAIN; do
        v="${entry%:*}"
        n="$v.tar.gz"
        if [ -f "$TARDIR/$n" ]; then
            log "  [OK]   $v already cached"
        else
            log "  [GET]  $v..."
            curl -fSL --retry 3 "https://github.com/golang/go/archive/refs/tags/$v.tar.gz" -o "$TARDIR/$n"
            size=$(ls -lh "$TARDIR/$n" | awk '{print $5}')
            log "  [DONE] $v ($size)"
        fi
    done
    log ""
    log "All tarballs cached at: $TARDIR/"
    log "You can now run commands with --offline and no network."
}

# ---- argument parsing and dispatch ----

OFFLINE=false
BUILD_TAG=""

# Extract global flags from the argument list
global_args=""
cmd_args=""
found_cmd=false
for arg do
    case "$arg" in
        --offline)
            OFFLINE=true
            global_args="$global_args --offline"
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        build|install|uninstall|list|use|current|system|update|prefetch)
            found_cmd=true
            cmd_name="$arg"
            ;;
        *)
            if [ "$found_cmd" = false ]; then
                cmd_name="$arg"
                found_cmd=true
            else
                cmd_args="$cmd_args $arg"
            fi
            ;;
    esac
done

# Default command for backward compatibility
if [ "$found_cmd" = false ]; then
    cmd_name="build"
fi

# Validate fork source exists for commands that need it
case "$cmd_name" in
    build|install|update|system)
        if [ ! -f "$FORK_DIR/src/make.bash" ]; then
            echo "ERROR: fork directory not found at $FORK_DIR" >&2
            echo "Set FORK_DIR to your go-no-telemetry clone path." >&2
            exit 1
        fi
        ;;
esac

# Convert cmd_args string to positional parameters
set -- $cmd_args

# Dispatch to command handler
case "$cmd_name" in
    build)
        # Remaining args are treated as a git tag
        BUILD_TAG="${1:-}"
        [ -n "$BUILD_TAG" ] && shift
        cmd_build
        ;;
    install)
        cmd_install "$@"
        ;;
    uninstall)
        cmd_uninstall "$@"
        ;;
    list)
        cmd_list
        ;;
    use)
        cmd_use "$@"
        ;;
    current)
        cmd_current
        ;;
    system)
        cmd_system "$@"
        ;;
    update)
        cmd_update
        ;;
    prefetch)
        cmd_prefetch
        ;;
    *)
        echo "Unknown command: $cmd_name" >&2
        echo "Run 'bootstrap.sh --help' for usage." >&2
        exit 1
        ;;
esac
