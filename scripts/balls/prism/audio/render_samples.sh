#!/usr/bin/env bash
set -euo pipefail
audio_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ffmpeg_bin="${FFMPEG_BIN:-ffmpeg}"
decoded_dir="$(mktemp -d "${TMPDIR:-/tmp}/prism-audio.XXXXXX")"
trap 'rm -f "$decoded_dir/vprisea.wav" "$decoded_dir/prisfire.wav" "$decoded_dir/bpripow.wav"; rmdir "$decoded_dir"' EXIT
FFMPEG_BIN="$ffmpeg_bin" "${PYTHON_BIN:-python3}" "$audio_dir/decode_sources.py" "$audio_dir/source" "$decoded_dir"

render() {
    local source_name="$1" output_name="$2" clip_start="$3" clip_duration="$4" loudness="$5"
    "$ffmpeg_bin" -hide_banner -loglevel warning -y \
        -i "$decoded_dir/$source_name.wav" \
        -af "atrim=start=$clip_start:duration=$clip_duration,asetpts=PTS-STARTPTS,aformat=sample_fmts=fltp,highpass=f=60,lowpass=f=10500,afade=t=in:d=0.003,areverse,afade=t=in:d=0.025,areverse,loudnorm=I=$loudness:LRA=7:TP=-3,aresample=192000,alimiter=limit=0.707946:attack=5:release=50:level=false:latency=true" \
        -ar 48000 -ac 1 -c:a libvorbis -q:a 6 "$audio_dir/$output_name.ogg"
}

# Keep the recorded voice and discharge timbre; no synthesis or pitch shifting.
render vprisea prism_spawn 0.0 1.337551 -18
render bpripow prism_charge 0.02 0.32 -22
render prisfire prism_fire 0.0 1.843084 -18
render prisfire prism_hit 0.20 0.22 -22
