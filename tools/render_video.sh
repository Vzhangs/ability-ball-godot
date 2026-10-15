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
battle_mode="${6:-duel}"
team_rosters="${7:-${left_ball}|${right_ball}}"
team_names="${8:-}"

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

if [[ "$(uname -s)" == Darwin ]]; then
  exec python3 "$project_dir/tools/production_host.py" "$seed" "$left_ball" "$right_ball" "$time_limit" "$recording_fps" "$battle_mode" "$team_rosters" "$team_names"
fi
[[ "$(uname -s)" == Linux ]] || { echo "录制只支持 Linux 生产主机" >&2; exit 2; }
(( 48000 % recording_fps == 0 )) || { echo "帧率必须能整除 48000 Hz 音频采样率" >&2; exit 2; }
command -v "$godot_bin" >/dev/null || { echo "找不到 Godot：$godot_bin" >&2; exit 1; }
command -v "$ffmpeg_bin" >/dev/null || { echo "找不到 FFmpeg：$ffmpeg_bin" >&2; exit 1; }
ffprobe_bin="${FFPROBE_BIN:-ffprobe}"
command -v "$ffprobe_bin" >/dev/null
[[ -f "$project_dir/addons/ability_mp4/libability_mp4.so" ]] || { echo "请先构建 tools/native_mp4/build.sh" >&2; exit 1; }

"$godot_bin" --headless --path "$project_dir" --script res://tools/validate_ball_ids.gd -- \
  "--left=$left_ball" "--right=$right_ball" "--battle-mode=$battle_mode" \
  "--team-rosters=$team_rosters" "--team-names=$team_names"

mkdir -p "$project_dir/builds"
output_slug="ability-ball-${left_ball}-vs-${right_ball}-seed-${seed}"
if [[ "$left_ball" == vampire && "$right_ball" == wdc ]]; then output_slug="ability-ball-seed-${seed}"; fi
if [[ "$battle_mode" != duel ]]; then
  safe_rosters="${team_rosters//|/-vs-}"
  safe_rosters="${safe_rosters//,/-}"
  output_slug="ability-ball-${battle_mode}-${safe_rosters:0:96}-seed-${seed}"
fi
output_file="${ABILITY_OUTPUT:-$project_dir/builds/${output_slug}.mp4}"
mkdir -p "$(dirname "$output_file")"
pending_file="${output_file%.mp4}.run-$$.mp4"
log_file="${pending_file}.log"
export FFMPEG_BIN="$ffmpeg_bin"
if [[ -z "${DISPLAY:-}" && -r /run/user/$(id -u)/gdm/Xauthority && -S /tmp/.X11-unix/X0 ]]; then
  export DISPLAY=:0
  export XAUTHORITY="/run/user/$(id -u)/gdm/Xauthority"
fi
runner=()
if [[ -z "${DISPLAY:-}" ]]; then runner=(xvfb-run -a -s '-screen 0 1080x1920x24'); fi
"${runner[@]}" "$godot_bin" --path "$project_dir" --resolution 1080x1920 \
  --disable-vsync --fixed-fps "$recording_fps" --write-movie "$pending_file" -- \
  --render-video "--seed=$seed" "--left=$left_ball" "--right=$right_ball" \
  "--battle-mode=$battle_mode" "--team-rosters=$team_rosters" "--team-names=$team_names" \
  "--time-limit=$time_limit" "--recording-fps=$recording_fps" 2>&1 | tee "$log_file"
grep -q 'ABILITY_MP4_COMPLETE' "$log_file"
if grep -Eq 'SCRIPT ERROR|Parse Error|MP4 .* failed' "$log_file"; then exit 1; fi
"$ffprobe_bin" -v error -show_streams -show_format -of json "$pending_file" > "$output_file.probe.json"
python3 - "$output_file.probe.json" "$recording_fps" <<'CHECK'
import json,sys
p=json.load(open(sys.argv[1]));v=next(x for x in p['streams'] if x['codec_type']=='video');a=next(x for x in p['streams'] if x['codec_type']=='audio')
assert (v['codec_name'],v['width'],v['height'],v['pix_fmt'])==('h264',1080,1920,'yuv420p')
assert a['codec_name']=='aac' and a['channels']==2 and a['sample_rate']=='48000'
n,d=map(int,v['avg_frame_rate'].split('/'));assert abs(n/d-int(sys.argv[2]))<0.01
assert float(v['duration'])>6 and abs(float(v['duration'])-float(a['duration']))<0.1
CHECK
"$ffmpeg_bin" -nostdin -y -hide_banner -loglevel error -ss 6 -i "$pending_file" \
  -frames:v 1 -update 1 "$output_file.cover.jpg"
mv "$pending_file" "$output_file"
echo "视频已生成：$output_file；封面：$output_file.cover.jpg"
