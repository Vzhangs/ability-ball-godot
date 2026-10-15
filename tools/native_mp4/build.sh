#!/usr/bin/env bash
set -euo pipefail
[[ "$(uname -s)" == Linux ]] || { echo 'Native recording build requires Linux' >&2; exit 2; }
root="$(cd "$(dirname "$0")/../.." && pwd)"
runtime="${ABILITY_RUNTIME:-$HOME/.local/share/ability-ball-runtime}"
native_hash="$(cat "$root/tools/native_mp4/writer.cpp" "$root/tools/native_mp4/build_profile.json" | sha256sum | cut -c1-16)"
build_dir="$runtime/native-build-$native_hash"
if [[ ! -f "$build_dir/libability_mp4.so" ]]; then
cmake -S "$root/tools/native_mp4" -B "$build_dir" \
  -DGODOT_CPP_PATH="$runtime/godot-cpp-master" \
  -DGODOTCPP_CUSTOM_API_FILE="$runtime/extension_api.json" -DCMAKE_BUILD_TYPE=Release
cmake --build "$build_dir" -j 4
fi
mkdir -p "$root/addons/ability_mp4"
cp "$build_dir/libability_mp4.so" "$root/addons/ability_mp4/"
cat > "$root/addons/ability_mp4/ability_mp4.gdextension" <<'MANIFEST'
[configuration]
entry_symbol = "ability_mp4_init"
compatibility_minimum = "4.7"
[libraries]
linux.debug.x86_64 = "res://addons/ability_mp4/libability_mp4.so"
linux.release.x86_64 = "res://addons/ability_mp4/libability_mp4.so"
MANIFEST
