# Minecraft short sound effects

These 19 short sound recordings are original Minecraft Java Edition 1.21.1
assets distributed by Mojang. Copyright belongs to Mojang / Microsoft and
the respective audio rights holders. They are excluded from this project's
MIT license. Their presence does not imply endorsement or sponsorship.

Retrieved on 2026-09-17 from the official Mojang asset CDN. `sources.json`
records the version metadata, asset index, original resource paths, source
URLs, SHA-1 and SHA-256 hashes. `fetch_assets.py` reproduces the download and
checks the official size and SHA-1 before writing each file.

The OGG files retain the original bytes: no synthesis, resampling, pitch
shift, trimming, or added music. Playback gain is set in `audio_catalog.gd`,
including compensation for the shared mixer's output gain.

Wood uses wood block sounds, stone/iron/gold/diamond use the classic stone
block family, and netherite uses its own family. Placement, surviving damage
and destruction use different samples. Wood and stone armor use leather and
generic equipment sounds respectively; the four higher armor tiers use their
matching equipment sounds. Sword upgrades use the experience-orb chime;
non-upgrading collections use the item-pickup pop. Sword contacts use weak
or strong player-attack sounds according to equipment tier.
