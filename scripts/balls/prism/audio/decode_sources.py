#!/usr/bin/env python3
"""Decode the bundled mono IMA AUD samples and verify their complete PCM payload."""

import os
from pathlib import Path
import struct
import subprocess
import sys
import wave


def decode(source: Path, output: Path) -> None:
    data = source.read_bytes()
    rate, packed_size, pcm_size, flags, codec = struct.unpack_from("<HIIBB", data)
    if flags != 2 or codec != 99 or packed_size != len(data) - 12:
        raise ValueError(f"Unsupported or incomplete AUD header: {source.name}")
    offset, declared_pcm, padded_pcm = 12, 0, 0
    while offset < len(data):
        size, decoded_size, magic = struct.unpack_from("<HHI", data, offset)
        if magic != 0xDEAF or size == 0 or offset + 8 + size > len(data):
            raise ValueError(f"Invalid AUD chunk: {source.name} at {offset}")
        declared_pcm += decoded_size
        padded_pcm += size * 4
        offset += 8 + size
    if offset != len(data) or declared_pcm != pcm_size:
        raise ValueError(f"Incomplete AUD payload: {source.name}")
    result = subprocess.run(
        [os.environ.get("FFMPEG_BIN", "ffmpeg"), "-hide_banner", "-loglevel", "error",
         "-i", str(source), "-f", "s16le", "-c:a", "pcm_s16le",
         "-ar", str(rate), "-ac", "1", "pipe:1"],
        check=True, capture_output=True,
    )
    # IMA packs two samples per byte; an odd final sample count adds one pad nibble.
    if len(result.stdout) != padded_pcm or padded_pcm - pcm_size != (pcm_size % 4):
        raise ValueError(f"PCM length mismatch: {source.name}: {len(result.stdout)} != {padded_pcm}")
    # The legacy demuxer reports EIO instead of EOF after the final complete chunk.
    # Tolerate only that exact message after both chunk and decoded-length checks.
    for line in result.stderr.decode("utf-8", errors="replace").splitlines():
        if line and "Error during demuxing: Input/output error" not in line:
            raise RuntimeError(f"Unexpected audio decoder diagnostic: {line}")
    with wave.open(str(output), "wb") as stream:
        stream.setparams((1, 2, rate, 0, "NONE", "not compressed"))
        stream.writeframes(result.stdout[:pcm_size])
    print(f"{source.name}: verified {pcm_size // 2} samples at {rate} Hz")


if __name__ == "__main__":
    source_dir, output_dir = map(Path, sys.argv[1:])
    for name in ("vprisea", "prisfire", "bpripow"):
        decode(source_dir / f"{name}.aud", output_dir / f"{name}.wav")
