"""Fetch hash-verified Minecraft Java 1.21.1 short sound assets from Mojang."""
import hashlib
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parent
MANIFEST = "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"
SOURCES = {
    "wood_place": "dig/wood1", "wood_break": "dig/wood3", "wood_hit": "step/wood2",
    "stone_place": "dig/stone1", "stone_break": "dig/stone3", "stone_hit": "step/stone2",
    "netherite_place": "block/netherite/break1",
    "netherite_break": "block/netherite/break3", "netherite_hit": "block/netherite/step2",
    "pickup": "random/pop", "upgrade": "random/orb",
    "sword_light": "entity/player/attack/weak1",
    "sword_heavy": "entity/player/attack/strong1",
    "armor_wood": "item/armor/equip_leather1",
    "armor_stone": "item/armor/equip_generic1",
    "armor_iron": "item/armor/equip_iron1",
    "armor_gold": "item/armor/equip_gold1",
    "armor_diamond": "item/armor/equip_diamond1",
    "armor_netherite": "item/armor/equip_netherite1",
}


def fetch(url):
    with urllib.request.urlopen(url, timeout=45) as response:
        return response.read()


def main():
    manifest = json.loads(fetch(MANIFEST))
    version_url = next(v["url"] for v in manifest["versions"] if v["id"] == "1.21.1")
    version = json.loads(fetch(version_url))
    index_bytes = fetch(version["assetIndex"]["url"])
    assert hashlib.sha1(index_bytes).hexdigest() == version["assetIndex"]["sha1"]
    objects = json.loads(index_bytes)["objects"]
    records = []
    for name, source in SOURCES.items():
        key = f"minecraft/sounds/{source}.ogg"
        entry = objects[key]
        digest = entry["hash"]
        url = f"https://resources.download.minecraft.net/{digest[:2]}/{digest}"
        data = fetch(url)
        assert len(data) == entry["size"] and hashlib.sha1(data).hexdigest() == digest
        (ROOT / f"{name}.ogg").write_bytes(data)
        records.append({"file": f"{name}.ogg", "asset": key, "url": url,
                        "sha1": digest, "sha256": hashlib.sha256(data).hexdigest()})
    (ROOT / "sources.json").write_text(json.dumps({
        "version": "1.21.1", "version_url": version_url,
        "asset_index": version["assetIndex"], "processing": "none; original bytes",
        "assets": records}, indent=2) + "\n")
    print(f"Verified {len(records)} original short samples")


if __name__ == "__main__":
    main()
