"""Fetch unchanged Minecraft Java 1.21.1 fuse and explosion samples."""
import hashlib
import json
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MANIFEST = "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"


def fetch(url):
    with urllib.request.urlopen(url, timeout=45) as response:
        return response.read()


def main():
    manifest = json.loads(fetch(MANIFEST))
    version_url = next(v["url"] for v in manifest["versions"] if v["id"] == "1.21.1")
    version = json.loads(fetch(version_url))
    index = fetch(version["assetIndex"]["url"])
    assert hashlib.sha1(index).hexdigest() == version["assetIndex"]["sha1"]
    objects = json.loads(index)["objects"]
    records = []
    for name, path in {"fuse": "random/fuse", "explode": "random/explode1"}.items():
        key = f"minecraft/sounds/{path}.ogg"
        entry = objects[key]
        digest = entry["hash"]
        url = f"https://resources.download.minecraft.net/{digest[:2]}/{digest}"
        data = fetch(url)
        assert len(data) == entry["size"] and hashlib.sha1(data).hexdigest() == digest
        (ROOT / f"{name}.ogg").write_bytes(data)
        records.append({"file": f"{name}.ogg", "asset": key, "url": url,
                        "sha1": digest, "sha256": hashlib.sha256(data).hexdigest()})
    (ROOT / "sources.json").write_text(json.dumps({
        "version": "1.21.1", "retrieved": "2026-09-20", "version_url": version_url,
        "asset_index": version["assetIndex"], "processing": "none; original bytes",
        "assets": records}, indent=2) + "\n")
    print("Verified 2 original Minecraft samples")


if __name__ == "__main__":
    main()
