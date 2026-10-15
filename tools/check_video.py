#!/usr/bin/env python3
"""Decode the complete movie and validate image timing and non-silent audio."""
import json
from pathlib import Path
import re
import subprocess
import sys


def check(path: Path):
    probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(path)]))
    video=next(s for s in probe['streams'] if s['codec_type']=='video')
    audio=next(s for s in probe['streams'] if s['codec_type']=='audio')
    if (video['codec_name'],video['width'],video['height'],video['pix_fmt'])!=('h264',1080,1920,'yuv420p'):
        raise RuntimeError('Unexpected video format')
    if audio['codec_name']!='aac' or audio['sample_rate']!='48000' or audio['channels']!=2:
        raise RuntimeError('Unexpected audio format')
    if abs(float(video['duration'])-float(audio['duration']))>0.1:
        raise RuntimeError('Audio/video duration mismatch')
    result=subprocess.run(['ffmpeg','-nostdin','-hide_banner','-v','info','-xerror','-i',str(path),'-af','volumedetect','-f','null','-'],capture_output=True,text=True,check=True)
    peak=re.search(r'max_volume: ([\-\w.]+) dB',result.stderr)
    if not peak or float(peak[1]) < -60:
        raise RuntimeError('No audible soundtrack')
    return {'duration':float(video['duration']),'fps':video['avg_frame_rate'],'frames':int(video['nb_frames']),
            'bytes':path.stat().st_size,'peak_db':float(peak[1]),'complete_decode':'passed'}

if __name__=='__main__': print(json.dumps(check(Path(sys.argv[1])),indent=2))
