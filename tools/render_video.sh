#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
ffmpeg_bin="${FFMPEG_BIN:-ffmpeg}"
seed="${1:-20260815}"
left_ball="${2:-vampire}"
right_ball="${3:-wdc}"
time_limit="${4:-120}"
recording_fps="${5:-60}"

if [[ ! "$seed" =~ ^-?[0-9]+$ ]] || [[ "$seed" == "0" ]]; then
  echo "种子必须是非零整数。" >&2
  exit 2
fi

if [[ ! "$time_limit" =~ ^[0-9]+$ ]] || (( time_limit < 15 || time_limit > 600 )); then
	echo "对局时限必须是 15 到 600 秒之间的整数。" >&2
	exit 2
fi

if [[ ! "$recording_fps" =~ ^[0-9]+$ ]] || (( recording_fps < 24 || recording_fps > 120 )); then
	echo "录制帧率必须是 24 到 120 之间的整数。" >&2
	exit 2
fi

command -v "$godot_bin" >/dev/null || { echo "找不到 Godot：$godot_bin" >&2; exit 1; }
command -v "$ffmpeg_bin" >/dev/null || { echo "找不到 FFmpeg：$ffmpeg_bin" >&2; exit 1; }

"$godot_bin" --headless --path "$project_dir" --script res://tools/validate_ball_ids.gd -- \
  "--left=$left_ball" \
  "--right=$right_ball"

mkdir -p "$project_dir/builds"
output_slug="ability-ball-seed-${seed}"
if [[ "$left_ball" != "vampire" ]] || [[ "$right_ball" != "wdc" ]]; then
  output_slug="ability-ball-${left_ball}-vs-${right_ball}-seed-${seed}"
fi
master_file="$project_dir/builds/${output_slug}-master.avi"
output_file="$project_dir/builds/${output_slug}.mp4"
cover_frame=$(( recording_fps * 6 ))
cover_title_y=605

"$godot_bin" \
  --path "$project_dir" \
  --resolution 1080x1920 \
  --disable-vsync \
  --fixed-fps "$recording_fps" \
  --write-movie "$master_file" \
  -- \
  --render-video \
  "--seed=$seed" \
  "--left=$left_ball" \
  "--right=$right_ball" \
  "--time-limit=$time_limit" \
  "--recording-fps=$recording_fps"

"$ffmpeg_bin" -y -hide_banner \
  -i "$master_file" \
  -filter_complex "[0:v]crop=1080:1200:0:0,split=3[normal][cover_base_source][cover_title_source];[cover_base_source]select='eq(n,${cover_frame})',setpts=PTS-STARTPTS,drawbox=x=0:y=0:w=1080:h=120:color=0x030405:t=fill[cover_base];[cover_title_source]select='eq(n,${cover_frame})',setpts=PTS-STARTPTS,crop=1080:120:0:0,format=rgba,colorkey=0x030405:0.12:0.08[cover_title];[cover_base][cover_title]overlay=0:${cover_title_y}:format=auto[cover];[normal][cover]overlay=enable='eq(n,0)':eof_action=pass[content];[content]pad=1080:1920:0:360:color=black[video]" \
  -map "[video]" -map '0:a?' \
  -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p \
  -c:a aac -b:a 192k \
  -movflags +faststart \
  "$output_file"

echo "视频已生成（第 1 帧为自动封面）：$output_file"
