#!/usr/bin/env python3
"""Immutable source/settings snapshots and recording on the approved Linux host."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT/'tools/production-host.local.json'
CONFIG = json.loads(CONFIG_PATH.read_text()) if CONFIG_PATH.exists() else {}
HOST = os.environ.get('ABILITY_PRODUCTION_HOST', CONFIG.get('host', ''))
RUNTIME = os.environ.get('ABILITY_PRODUCTION_RUNTIME', CONFIG.get('runtime', ''))
SSH = ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15']
KEY = os.environ.get('ABILITY_PRODUCTION_SSH_KEY', CONFIG.get('ssh_key', ''))
if KEY: SSH += ['-i', str(Path(KEY).expanduser())]
SSH += [HOST]
SETTINGS = Path.home()/'Library/Application Support/Godot/app_userdata/Ability Ball Lab'


def run(args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def remote(argv, **kwargs):
    if not HOST or not RUNTIME:
        raise RuntimeError('Configure tools/production-host.local.json or ABILITY_PRODUCTION_HOST and ABILITY_PRODUCTION_RUNTIME first.')
    return run(SSH + [shlex.join(str(a) for a in argv)], **kwargs)


def upload(local: Path, remote_path: str):
    if not HOST or not RUNTIME:
        raise RuntimeError('Production host is not configured.')
    with local.open('rb') as f:
        run(SSH + ['cat > ' + shlex.quote(remote_path)], stdin=f)


def download(remote_path: str, local: Path):
    local.parent.mkdir(parents=True, exist_ok=True)
    pending = local.with_name(local.name + '.download')
    with pending.open('wb') as f:
        remote(['cat', remote_path], stdout=f)
    pending.replace(local)


def snapshot(job: Path):
    job.mkdir(parents=True, exist_ok=True)
    manifest_path = job/'snapshot.json'
    if manifest_path.exists():
        return json.loads(manifest_path.read_text())
    files = [ROOT/'project.godot']
    for directory in ['scripts', 'scenes', 'tools', 'operations']:
        files += [p for p in (ROOT/directory).rglob('*') if p.is_file()
                  and '__pycache__' not in p.parts and p.suffix not in ['.pyc']]
    digest = hashlib.sha256()
    for p in sorted(files):
        digest.update(str(p.relative_to(ROOT)).encode()); digest.update(p.read_bytes())
    source_hash = digest.hexdigest()
    with tarfile.open(job/'source.tar.gz', 'w:gz') as archive:
        for p in sorted(files): archive.add(p, arcname=str(p.relative_to(ROOT)), recursive=False)
    settings_hashes = {}
    for name in ['ability_ball_settings.json', 'ability_ball_global_settings.json', 'ability_ball_boss_settings.json']:
        source = SETTINGS/name
        if source.exists():
            data = source.read_bytes(); parsed = json.loads(data)
            required = 2 if 'global' in name else 1
            if parsed.get('version') != required:
                raise RuntimeError(f'Unsupported settings format: {source}')
            (job/name).write_bytes(data)
            settings_hashes[name] = hashlib.sha256(data).hexdigest()
    identity = hashlib.sha256((source_hash+json.dumps(settings_hashes,sort_keys=True)).encode()).hexdigest()[:20]
    manifest = {'source_sha256': source_hash, 'settings': settings_hashes, 'identity': identity,
                'remote_project': f'{RUNTIME}/releases/{source_hash[:20]}',
                'remote_job': f'{RUNTIME}/jobs/{job.name}-{identity}'}
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    return manifest


def prepare(job: Path):
    manifest = snapshot(job)
    project, remote_job = manifest['remote_project'], manifest['remote_job']
    data_dir = remote_job+'/data'
    user_dir = data_dir+'/godot/app_userdata/Ability Ball Lab'
    remote(['mkdir','-p', project, remote_job, user_dir])
    for name in manifest['settings']: upload(job/name, user_dir+'/'+name)
    exists = subprocess.run(SSH+['test -f '+shlex.quote(project+'/.ready')]).returncode == 0
    if not exists:
        upload(job/'source.tar.gz',remote_job+'/source.tar.gz')
        remote(['tar','-xzf',remote_job+'/source.tar.gz','-C',project])
        with (job/'import.log').open('w') as log:
            remote(['bash', project+'/tools/native_mp4/build.sh'],stdout=log,stderr=subprocess.STDOUT)
            remote(['env','XDG_DATA_HOME='+data_dir,RUNTIME+'/godot','--headless','--path',project,'--editor','--import'],stdout=log,stderr=subprocess.STDOUT)
        remote(['touch',project+'/.ready'])
    return manifest


def search(job: Path, requests: list[dict]):
    manifest = prepare(job)
    (job/'requests.json').write_text(json.dumps(requests))
    remote_job = manifest['remote_job']
    upload(job/'requests.json', remote_job+'/requests.json')
    with (job/'search.log').open('w') as log:
        remote(['env','XDG_DATA_HOME='+remote_job+'/data',RUNTIME+'/godot','--headless','--path',manifest['remote_project'],
                '--script','res://tools/search_seeds.gd','--',remote_job+'/requests.json',remote_job+'/results.jsonl'],
               stdout=log,stderr=subprocess.STDOUT,timeout=330)
    download(remote_job+'/results.jsonl', job/'results.jsonl')
    errors = (job/'search.log').read_text()
    if 'SCRIPT ERROR' in errors or 'Parse Error' in errors: raise RuntimeError('Seed search script failed; inspect search.log')
    return [json.loads(line) for line in (job/'results.jsonl').read_text().splitlines() if line]


def record(job: Path, arguments: list[str], output: Path):
    manifest = prepare(job)
    remote_job = manifest['remote_job']
    remote_output = remote_job+'/video.mp4'
    with (job/'render.log').open('w') as log:
        remote(['env','DISPLAY=:0','XAUTHORITY=/run/user/1000/gdm/Xauthority','XDG_DATA_HOME='+remote_job+'/data','GODOT_BIN='+RUNTIME+'/godot',
                'FFMPEG_BIN='+RUNTIME+'/ffmpeg','FFPROBE_BIN='+RUNTIME+'/ffprobe',
                'ABILITY_OUTPUT='+remote_output,'bash',manifest['remote_project']+'/tools/render_video.sh',*arguments],
               stdout=log,stderr=subprocess.STDOUT,timeout=3600)
    download(remote_output, output)
    download(remote_output+'.cover.jpg', output.with_suffix('.cover.jpg'))
    download(remote_output+'.probe.json', job/'probe.json')
    remote(['tar','-czf',remote_job+'/battle-logs.tar.gz','-C',manifest['remote_project'],'builds/logs'])
    download(remote_job+'/battle-logs.tar.gz',job/'battle-logs.tar.gz')
    matched=[]
    with tarfile.open(job/'battle-logs.tar.gz') as archive:
        for entry in archive.getmembers():
            if not entry.isfile(): continue
            events=[json.loads(line) for line in archive.extractfile(entry).read().decode().splitlines() if line]
            if not events: continue
            start,end=events[0],events[-1]
            if start.get('battle',{}).get('seed')==int(arguments[0]) and end.get('outcome')=='completed':
                matched.append(end)
    if not matched: raise RuntimeError('No completed battle readback for recorded seed')
    (job/'recorded-battle.json').write_text(json.dumps(matched[-1],ensure_ascii=False,indent=2)+'\n')
    return output


def output_name(args):
    seed,left,right,_,_,mode,rosters,*_ = args
    if mode != 'duel': return f"ability-ball-{mode}-{rosters.replace('|','-vs-').replace(',','-')[:96]}-seed-{seed}.mp4"
    if (left,right)==('vampire','wdc'): return f'ability-ball-seed-{seed}.mp4'
    return f'ability-ball-{left}-vs-{right}-seed-{seed}.mp4'


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('arguments',nargs='+')
    args=parser.parse_args()
    from datetime import datetime
    job=ROOT.parent/'artifacts/ability-ball-recordings'/datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    destination=ROOT/'builds'/output_name(args.arguments)
    record(job,args.arguments,destination)
    print(destination)
