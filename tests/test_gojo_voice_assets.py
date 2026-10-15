#!/usr/bin/env python3
"""Check the shipped voice files, including dead air inside each clip."""

import json
from pathlib import Path
import re
import subprocess


AUDIO_DIR = Path(__file__).resolve().parents[1] / "scripts/balls/gojo/audio"
# All four combat voice cues have a hard one-second ceiling, including silence.
LIMITS = {
    "blue": (0.80, 1.00, 0.10),
    "red": (0.80, 1.00, 0.10),
    "purple": (0.80, 1.00, 0.10),
    "domain": (0.80, 1.00, 0.10),
}


def inspect_voice(kind: str, limits: tuple[float, float, float]) -> dict:
    path = AUDIO_DIR / f"gojo_{kind}.ogg"
    probe = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_streams", "-show_format",
        "-of", "json", str(path),
    ], text=True))
    duration = float(probe["format"]["duration"])
    stream = probe["streams"][0]
    assert stream["codec_name"] == "vorbis", kind
    assert int(stream["sample_rate"]) == 48000 and stream["channels"] == 1, kind
    assert limits[0] <= duration <= limits[1], (kind, "duration", duration)
    result = subprocess.run([
        "ffmpeg", "-hide_banner", "-nostats", "-i", str(path),
        "-af", "silencedetect=n=-38dB:d=0.02", "-f", "null", "-",
    ], check=True, capture_output=True, text=True)
    start = None
    inner = []
    outer = []
    for line in result.stderr.splitlines():
        match = re.search(r"silence_start: ([\d.]+)", line)
        if match:
            start = float(match[1])
        match = re.search(r"silence_end: ([\d.]+)", line)
        if match and start is not None:
            end = float(match[1])
            target = outer if start <= 0.02 or end >= duration - 0.02 else inner
            target.append(end - start)
            start = None
    longest = max(inner, default=0.0)
    assert longest <= limits[2], (kind, "inner silence", longest)
    assert max(outer, default=0.0) <= 0.10, (kind, "outer silence", outer)
    return {"voice": kind, "duration": duration, "longest_inner_silence": longest}


if __name__ == "__main__":
    print(json.dumps([inspect_voice(kind, limits) for kind, limits in LIMITS.items()], indent=2))
    print("ABILITY_BALL_GOJO_VOICE_ASSETS_OK")
