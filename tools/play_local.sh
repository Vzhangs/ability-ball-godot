#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(dirname -- "$SCRIPT_DIR")
GODOT_APP=${GODOT_APP:-/Applications/Godot.app}

if [ "$(uname -s)" != "Darwin" ]; then
    printf '%s\n' 'play_local.sh is intended for macOS.' >&2
    exit 1
fi
if [ ! -f "$PROJECT_DIR/project.godot" ]; then
    printf '%s\n' "Godot project not found: $PROJECT_DIR/project.godot" >&2
    exit 1
fi

if [ -n "${GODOT_BIN:-}" ]; then
    godot_bin=$(command -v "$GODOT_BIN")
elif [ -x "$GODOT_APP/Contents/MacOS/Godot" ]; then
    godot_bin="$GODOT_APP/Contents/MacOS/Godot"
elif command -v godot >/dev/null 2>&1; then
    godot_bin=$(command -v godot)
elif [ -x "$HOME/Applications/Godot.app/Contents/MacOS/Godot" ]; then
    godot_bin="$HOME/Applications/Godot.app/Contents/MacOS/Godot"
else
    printf '%s\n' 'Godot not found. Install Godot 4 or set GODOT_BIN.' >&2
    exit 1
fi

if [ "${1:-}" = "--foreground" ]; then
    shift
    exec "$godot_bin" --path "$PROJECT_DIR" "$@"
fi
for argument in "$@"; do
    [ "$argument" != "--" ] || break
    if [ "$argument" = "--headless" ]; then
        exec "$godot_bin" --path "$PROJECT_DIR" "$@"
    fi
done

source_file="$SCRIPT_DIR/macos/background_launch.m"
source_hash=$(LC_ALL=C /usr/bin/shasum -a 256 "$source_file" | /usr/bin/cut -d ' ' -f 1)
cache_dir="$PROJECT_DIR/artifacts/local-launch"
library="$cache_dir/background-$source_hash.dylib"
mkdir -p "$cache_dir"
if [ ! -f "$library" ]; then
    temporary=$(/usr/bin/mktemp "$cache_dir/background.XXXXXX")
    trap 'rm -f "$temporary"' EXIT HUP INT TERM
    /usr/bin/xcrun clang -dynamiclib -fobjc-arc -arch arm64 -arch x86_64 \
        -framework AppKit "$source_file" -o "$temporary"
    mv "$temporary" "$library"
    trap - EXIT HUP INT TERM
fi

# exec preserves Godot's exit status, signals, stdout and stderr for test runners.
export DYLD_INSERT_LIBRARIES="$library"
exec "$godot_bin" --path "$PROJECT_DIR" "$@"
