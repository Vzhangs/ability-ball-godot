#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
ffmpeg_bin="${FFMPEG_BIN:-ffmpeg}"
seed="${1:-20260815}"
left_ball="${2:-vampire}"
right_ball="${3:-six_king}"

if [[ ! "$seed" =~ ^-?[0-9]+$ ]] || [[ "$seed" == "0" ]]; then
  echo "种子必须是非零整数。" >&2
  exit 2
fi

command -v "$godot_bin" >/dev/null || { echo "找不到 Godot：$godot_bin" >&2; exit 1; }
command -v "$ffmpeg_bin" >/dev/null || { echo "找不到 FFmpeg：$ffmpeg_bin" >&2; exit 1; }

"$godot_bin" --headless --path "$project_dir" --script res://tools/validate_ball_ids.gd -- \
  "--left=$left_ball" \
  "--right=$right_ball"

mkdir -p "$project_dir/builds"
output_slug="ability-ball-seed-${seed}"
if [[ "$left_ball" != "vampire" ]] || [[ "$right_ball" != "six_king" ]]; then
  output_slug="ability-ball-${left_ball}-vs-${right_ball}-seed-${seed}"
fi
master_file="$project_dir/builds/${output_slug}-master.avi"
output_file="$project_dir/builds/${output_slug}.mp4"

"$godot_bin" \
  --path "$project_dir" \
  --resolution 720x1280 \
  --disable-vsync \
  --fixed-fps 30 \
  --write-movie "$master_file" \
  -- \
  --render-video \
  "--seed=$seed" \
  "--left=$left_ball" \
  "--right=$right_ball"

"$ffmpeg_bin" -y -hide_banner \
  -i "$master_file" \
  -vf "crop=720:960:0:0,scale=1080:1440:flags=lanczos" \
  -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p \
  -c:a aac -b:a 192k \
  -movflags +faststart \
  "$output_file"

echo "视频已生成：$output_file"
