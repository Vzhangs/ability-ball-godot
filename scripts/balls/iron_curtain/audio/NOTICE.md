# Iron Curtain and Iron Dragon sounds

`iron_curtain_activation.ogg` is a short excerpt of the Iron Curtain energy sound from *Command & Conquer: Red Alert 2*. `iron_dragon_transformation.ogg` is a lower, layered transformation variant derived only from that local excerpt.

- Source page: https://www.reddit.com/r/commandandconquer/comments/1p6u607/iron_curtain_sound/
- Source media ID: `8gvunkvd3i3g1`
- Retrieved: 2026-08-28
- Source MP4 SHA-256: `7018dff465fa3688a16c4cfbde42eb8ec45bf1189c344d41ea526ac90bea6cac`
- Output Ogg SHA-256: `0bc3c1fcf6f9bcfce8a9171539f986eb026c6a035bc4fb68c7858ffbb4013ada`
- Processing: extracted the first 1.85 seconds, removed sub-35 Hz rumble and frequencies above 10.5 kHz, added a 25 ms fade-in and 270 ms fade-out, and transcoded to mono 22.05 kHz Ogg Vorbis.
- Transformation Ogg SHA-256: `7e91ec503fc501e9aab08404d4d1d9ec6866846873868da1551ddca383fc3f78`
- Transformation processing: mixed 0.86× and 0.63× resampled layers from the activation excerpt, delayed the lower layer by 35 ms, filtered the result, and faded it to a 1.50-second mono 22.05 kHz Ogg Vorbis event.

The original sound recording and *Command & Conquer: Red Alert 2* are owned by Westwood Studios / Electronic Arts. This sample is included for identification in a fan-made demonstration, is not covered by this repository's MIT license, and does not imply endorsement by the rights holders.

`iron_dragon_fire.ogg` is an original procedural particle-cannon sound generated for this project. It combines a descending high-frequency energy tone, a short low-frequency discharge, and a rapidly decaying noise transient; it does not contain the Red Alert sample or any other third-party recording.

- Fire Ogg SHA-256: `dec498db57a7427045931671898015c599442b9c32d00b697167a94668fd082f`
- Fire processing: generated at 48 kHz, high-pass and low-pass filtered, peak-limited, faded to 0.62 seconds, and encoded as stereo Ogg Vorbis.
