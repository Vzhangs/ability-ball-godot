#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "Usage: bash render_short_voice.sh <blue|red|purple|domain> <clean source> <output.ogg>" >&2
    exit 2
fi

voice_kind="$1"
voice_source="$2"
voice_output="$3"
ffmpeg_bin="${FFMPEG_BIN:-ffmpeg}"
ffprobe_bin="${FFPROBE_BIN:-ffprobe}"

case "$voice_kind" in
    blue)
        expected_sha='873cdb55fd8f6f5ed1a4bf83c714aa312e9cc921ce072d109879d01514e1aae1'
        voice_start=9.97 voice_end=11.49 voice_tempo=1.65
        ;;
    red)
        expected_sha='708045d77449dbc7d4433d63c34b08df8fe93bf43cd8d231dbd584bccd61d6fc'
        voice_start=1.66 voice_end=3.42 voice_tempo=1.90
        ;;
    purple)
        expected_sha='43adc9eb85830ddfa1bdf80ee7862f680acf55d9da16be5c7296d0888aee6e43'
        voice_start=1.29 voice_end=2.34 voice_tempo=1.15
        ;;
    domain)
        expected_sha='d93ac1685ff55aa3118b3839b8046282b621044de68e8004b85f4eb308d140f2'
        voice_start=3.03 voice_end=4.47 voice_tempo=1.55
        ;;
    *) echo "Unknown voice: $voice_kind" >&2; exit 2 ;;
esac

voice_sha="$(shasum -a 256 "$voice_source" | awk '{print $1}')"
if [[ "$voice_sha" != "$expected_sha" ]]; then
    echo "Expected the original clean source; refusing an unknown or already shortened voice." >&2
    exit 2
fi

# Keep only the complete move name / signature phrase, without its incantation.
# Speed is baked into the sample while pitch and formants remain unchanged.
"$ffmpeg_bin" -hide_banner -loglevel error -n -i "$voice_source" \
    -af "atrim=start=${voice_start}:end=${voice_end},asetpts=PTS-STARTPTS,rubberband=tempo=${voice_tempo}:pitch=1:formant=preserved:transients=mixed:pitchq=quality,highpass=f=70,lowpass=f=15000,afade=t=in:d=0.003,areverse,afade=t=in:d=0.015,areverse,loudnorm=I=-17:LRA=7:TP=-1.5,aresample=192000,alimiter=limit=0.794328:attack=5:release=50:level=false:latency=true" \
    -ar 48000 -ac 1 -c:a libvorbis -q:a 6 "$voice_output"

voice_duration="$("$ffprobe_bin" -v error -show_entries format=duration -of csv=p=0 "$voice_output")"
if ! awk -v duration="$voice_duration" 'BEGIN { exit !(duration > 0 && duration <= 1.0) }'; then
    echo "Rendered voice exceeds the one-second limit: $voice_duration" >&2
    exit 1
fi
echo "$voice_kind: ${voice_duration}s"
