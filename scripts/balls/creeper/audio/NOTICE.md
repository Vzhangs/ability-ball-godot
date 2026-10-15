# Minecraft sound effects

`fuse.ogg` and `explode.ogg` are unchanged Minecraft Java Edition 1.21.1
recordings from Mojang's official asset CDN, retrieved on 2026-09-20.
The recordings belong to Mojang / Microsoft and their respective audio
rights holders, are excluded from this project's MIT license, and imply no
endorsement or sponsorship.

`sources.json` records official resource names, URLs, SHA-1 and SHA-256 hashes.
`fetch_assets.py` downloads the samples and verifies official hashes and sizes.
No synthesis, trimming, pitch shifting or transcoding is applied. The fuse
sample plays once on ignition and the explosion sample once on detonation.
