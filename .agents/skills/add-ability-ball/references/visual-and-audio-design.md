# Ability Ball visual and audio design

Use this reference for any ball body, attachment, projectile, cast indicator, growth transition, status overlay, skill effect, or custom audio change.

## Contents

- [Build a readable identity](#build-a-readable-identity)
- [Design an action timeline](#design-an-action-timeline)
- [Use the layer stack deliberately](#use-the-layer-stack-deliberately)
- [Signal casts with the right language](#signal-casts-with-the-right-language)
- [Animate growth and form changes](#animate-growth-and-form-changes)
- [Give statuses semantic motion](#give-statuses-semantic-motion)
- [Draw external attachments naturally](#draw-external-attachments-naturally)
- [Keep equipment feedback local](#keep-equipment-feedback-local)
- [Design audio as event ownership](#design-audio-as-event-ownership)
- [Edit short voice cues from the actual source](#edit-short-voice-cues-from-the-actual-source)
- [Run continuous audio as a state machine](#run-continuous-audio-as-a-state-machine)
- [Separate configurable timing from drawing constants](#separate-configurable-timing-from-drawing-constants)
- [Inspect the real result](#inspect-the-real-result)

## Build a readable identity

Design the still frame before the spectacle.

- Keep one dominant body color, one accent, and one central symbol or silhouette cue.
- Preserve the ball's circular body and internal health readability. Do not let translucent overlays erase its defining art.
- Make variants differ by outline and equipment, not only hue. A viewer should distinguish a flower, single-barrel shooter, ice shooter, and multi-barrel shooter in grayscale.
- Use thick primary shapes and restrained secondary detail so the design survives the 540 px preview as well as the higher-resolution recording.
- Treat glow as a support layer. Draw a crisp inner shape above a wider translucent glow so effects remain luminous instead of becoming blurred blobs.
- For a referenced vehicle or character, decide which recognizable features fit the requested ball silhouette and which belong outside it. A tank reference does not automatically require an external chassis/tracks; an explicitly requested rider or protruding barrel may require external geometry. Preserve the chosen boundary rather than copying the whole reference form.

## Design an action timeline

Break every visible ability into the phases it actually owns:

1. anticipation or target acquisition;
2. release or spawn;
3. travel, attachment, orbit, or expansion;
4. impact, damage, control, or consumption;
5. short readable linger;
6. deterministic fade or cleanup.

Do not draw a complete tether, blood line, suction path, or projectile at full length on its first frame when the mechanic implies travel. Grow it from source to target, keep motion along the path, then retract or consume it.

Orient attacks from the caster toward the chosen target. For a slash, transform the slash geometry along the caster-to-target direction rather than using a fixed world vertical. Keep the bright strike above balls and any terrain fracture below balls. Make the two elements overlap spatially so they read as one impact.

Give a fast effect enough lifetime to be recognized in normal playback. Validate the first, peak, and final frames instead of judging only a paused end state.

## Use the layer stack deliberately

| Layer | Put here | Avoid here |
| --- | --- | --- |
| Underlay | shadows, terrain cracks, scorch marks, ground distortion | health, shields, cast icons |
| Ball body | stable identity, face, sockets, embedded equipment | transient world effects |
| Above-ball entity | strikes, projectiles, tethers, beams, impact fragments | must-cover status symbols |
| Status overlay | fire, snow, frost, poison, ordinary buffs/debuffs | effects that must cover health text |
| Topmost overlay/entity | invulnerability shield, centered cast emblem, critical ownership marker | decorative noise |

Use `draw_layer <= 0` for entities below bodies and `draw_layer > 0` for entities above bodies. Use `draw_topmost_overlay()` only when the symbol must remain visible over ball art and health. Do not add a ball-specific draw branch to `BattleView`.

## Signal casts with the right language

For an ordinary major automatic cast, show a short centered emblem that represents the ability.

- Spawn it only after the cast succeeds and resource/target checks pass.
- Follow the caster for the whole animation.
- Draw it in the topmost entity layer when it must cover body art.
- Animate small → large → small, or dim → bright → dim; do not leave it static.
- Give it finite lifetime and deterministic cleanup.
- Keep the icon symbolic: eye for control, sprout for planting, shield for invulnerability. Do not show explanatory sentences.

Use a ball-local `BallEntity` when the emblem has its own lifetime and tracking. Keep its duration in the ball Schema when that duration affects readability or pacing.

Anime and character balls with explicitly named active moves are the narrow exception. When such a move actually fires, show its short move name near the caster and play the matching voice in the same event timeline.

- Use one finite top-layer entity for the name; do not route it through generic damage/healing text or add a character branch to `BattleView`.
- Bind one namespaced voice event to that exact move. Other moves and passive effects remain silent unless they own separate lines.
- Keep the name readable for roughly one action beat, animate it in and out, then remove it deterministically.
- Do not show prose, mechanics, configuration, cooldowns, or passive names. A permanent defense such as an aura must not spam labels or voices on every tick.
- If the requested character voice cannot be licensed or traced safely, prefer an original local synthesis with clear processing and document it beside the asset instead of copying a long audiovisual clip.
- When the user explicitly requires an actual original or viral voice, never substitute TTS, voice cloning, or a sound-alike synthesis. Use a short traceable excerpt of the real recording and apply only the requested editing/processing. Distinguish cleanup, pitch-preserving tempo changes, and an explicitly requested pitch effect. Record source URL, retrieval date, source and derived hashes, exact processing, ownership, license exclusion, and non-endorsement beside the asset.

## Animate growth and form changes

Do not replace a seed, summon, or form with a mature drawing in one frame.

- Keep the animation state in the growing ability/entity.
- Start the new form below normal size and slightly lower than its final center.
- Ease upward and outward, overshoot normal scale briefly, then settle at exactly `1.0`.
- Preserve existing growth rings and particles as secondary support.
- Keep the health bar stable and readable during the transition.
- Treat the animation as presentation-only unless the public rule delays attacks, collision, or vulnerability.

A simple deterministic scale curve is sufficient: cubic ease from about `0.3` to `1.0`, plus a small sine overshoot that returns to zero at the final frame.

When growth or collapse uses `draw_polygon()`, do not submit zero-area or self-overlapping geometry at the first or final animation frame. Skip the polygon below a small geometric threshold, or build it from stable convex pieces or triangles. A headless visual smoke test can execute the draw method without exposing every triangulation failure; inspect the live Godot error stream after constructing those boundary frames.

## Give statuses semantic motion

Make the effect move like the thing it represents.

- Fire: attach flames to the lower body, move tongues and embers upward, and vary their height. Do not rotate sun-like dots around the target.
- Freeze or slow: draw recognizable six-branch snowflakes with crisp centers, let them drift downward, sway sideways, and rotate at different speeds; add a restrained frost wash and broken ice ring.
- Invulnerability: use one centered gold shield in the topmost layer, with glow and repeated scale pulsing. Reuse the shared invulnerability status instead of inventing a new shield per ball.
- Suction or capture: show convergence, orbit, shrinking, and final consumption. Preserve the captured object's original color and owner until a separate ownership-transfer ability acts.
- Damage-over-time: keep tick cadence and damage in status logic; keep decorative particle timing independent so presentation edits cannot alter damage.

Use actual semantic symbols. If a snowflake reads as a generic sparkle at preview size, enlarge the branch geometry and spread before adding more particles.

## Draw external attachments naturally

External fangs, barrels, blades, leaves, and cannons may protrude beyond the body without expanding collision.

- Place the root or socket inside the body so the object looks attached rather than floating.
- Preserve a visible gap between paired attachments without pulling their roots outside the silhouette.
- Rotate directional equipment toward the current target.
- Keep decorative protrusions presentation-only unless their geometry is explicitly an attack or damageable entity.
- For multiple orbiting attachments, use deterministic rings with declared capacity per ring and stable slot ordering.

For continuous sampled trails, overlap direction-aware ragged fills along the motion tangent so the result reads as one flowing strip. Avoid disconnected circular plates, rings, or coin-like stamps when the requested material is a continuous flame, liquid, smoke, or track trail.

## Keep equipment feedback local

Separate character identity from equipment indicators. When the requested change is a lower-body armor badge, keep the face/hair palette stable and enlarge/reposition the badge within the circular silhouette without obscuring HP. Do not generalize that placement to equipment whose brief calls for a different design.

Audit the complete pickup timeline, not just the permanent `draw_ball()` branch: a cast icon, generic upgrade ring or status overlay may still recolor or cover the face after a helmet overlay is removed. A passive equipment pickup need not add the ordinary centered cast emblem when the localized badge already supplies the requested feedback.

Compare unequipped and all relevant material states at preview and production scale. Pixel comparisons can verify an unchanged region, but report the actual region tested and also inspect the full composition. Lightweight card/HUD preview fighters need not expose combat fields such as `fighter.radius`; use the supplied render context and module settings rather than assuming a full simulation fighter.

## Design audio as event ownership

Give each sound one exact combat event.

- Separate launch/cast, projectile hit, body impact, summon/spawn, split, consume, and destruction when the viewer can perceive them as different actions.
- Choose the sound from the requested acoustic cause, not the weapon noun. Continuous air displacement may need a staff-like `huhuhu/fufufu` whoosh even when the visible object is a sword; a hit may use one trimmed `ceng/ca` transient from the same source family.
- Emit events from ability/entity logic; keep device playback and mixing in the shared audio system.
- Register a custom sample in the owning module only. Do not make the shared mixer know the ball ID.
- Namespace sampled event keys by ball and action because the registry merges them globally and rejects duplicates.
- Bind a voice line only to the skill that owns it. A related skill must remain silent unless explicitly designed otherwise.
- Trim accidental trailing syllables and dead air, set a level that does not bury impact sounds, and inspect the mixed result in a real battle.
- Route timing-critical contact, firing, or impact through the existing direct/sample playback path. Do not assume a smaller generator buffer proves low latency; compare the visible event and audible onset in a real run.
- Document third-party sample ownership and processing near the asset when applicable.

Use `sound_kind` for the sound automatically emitted after a successful recorded activation. It may point to a module-owned custom sample. Emit sub-action sounds explicitly. Avoid emitting the activation event both ways.

After adding or replacing an `.ogg`, run a headless editor import before validating any preload. Inspect the generated import result through Godot; never hand-write `.ogg.import` metadata.

For material- or outcome-dependent sounds, use a catalog inside the owning ball directory. Map place, surviving hit, break, pickup-without-upgrade and equipment upgrade separately. A lethal hit should take the destruction path rather than unintentionally stacking hit and break samples. Current Steve registers `Audio.SAMPLES`, sets `sound_kind` to an empty string, and explicitly emits a selected event after success. The shared mixer has no profile for the empty event, so it produces no second generic cast sound. Verify that contract before reusing it; do not teach the mixer material IDs. Account for the shared output gain as well as per-event gain, and do not assume a file's standalone loudness equals its in-game mix.

## Edit short voice cues from the actual source

- Verify the exact input by hash and inspect its full timeline. A previously shortened file may have lost the desired move name; do not repeatedly stretch an already processed derivative when the complete clean source is available.
- Prefer complete move names or recognizable short phrases over aggressively accelerating an entire incantation. Cut long internal gaps and unwanted clauses with deliberate segment boundaries, short fades and enough consonant/vowel handles to keep the line intelligible.
- Preserve pitch/formants for a tempo-only request, for example with FFmpeg Rubber Band. Do not use playback `pitch_scale` or sample-rate changes as a substitute. If a stylized pitch shift is explicitly requested, document it separately.
- Apply a user-specified maximum to the complete decoded/exported file, including leading/trailing silence. Verify the final OGG with FFprobe and Godot's imported `get_length()`, and check internal pauses as well as total duration. Avoid padding every cue to the ceiling. The current Gojo cues have a ball-local one-second ceiling; this is not a universal limit for all balls, voices or loops.
- Keep background-music removal distinct from trimming and level normalization. Use an available clean vocal stem; measure level/peaks after processing and reimport the actual production path.
- Provide the actual revised audio for listening, preferably at a versioned artifact path when comparing revisions. Transcription can help locate words, but ambiguous ASR of a short shout is not proof of correct content or a claim that audio was heard. A waveform or player-start flag does not establish listening quality.
- Verify the owning event triggers once, the correct file/duration is loaded, no unrelated skill plays the cue, and the one-shot ends. Do not alter skill cadence to hide an overly long clip unless changing cadence is itself requested.

Use `scripts/balls/gojo/audio/render_short_voice.sh` and `tests/test_gojo_voice_assets.py` as project-relative processing/check examples, not as cross-ball asset dependencies. Retain traceable sources and distinguish untouched source bytes from derivatives in the asset notice.

## Run continuous audio as a state machine

Tie continuous sound to the exact gameplay state that owns it.

1. Declare the sample with `loop: true` in the owning module.
2. Emit its event once with positive strength when the state begins.
3. Keep repeated positive events from restarting an already-playing loop.
4. Emit the same event with strength `0.0` on the exact transition to inactive.
5. Pause and resume loop playback with battle pause without restarting the sample.
6. Stop every loop on immediate `battle_resolved`, battle replacement, seed restart, sample reconfiguration, and shutdown.

Never derive effect duration from source audio length. A configurable 3.5-second spin may loop a 0.85-second sample and must stop at 3.5 seconds. Validate playback after more than one source length, then validate the exact state boundary and resolution cleanup. Use the immediate resolution signal, not the delayed winner-popup signal.

## Separate configurable timing from drawing constants

Put damage, healing, speed, duration, cooldown, range, probability, count, HP, ownership, and gameplay motion in the owning ball's persistent Schema.

Also configure presentation duration when it changes the perceived timing of a cast, growth, or status. Keep pure polygon coordinates, branch counts, decorative amplitude, color channels, line widths, waveform constants, and numerical tolerances local unless the user explicitly requests controls.

Never let a visual random call consume the gameplay random stream.

## Inspect the real result

Use automated tests for mechanisms and the running renderer for appearance. Select checks relevant to the change; follow the main skill's runtime-ownership and isolation rules. Instruction-only maintenance does not require a game launch.

1. Validate every changed GDScript immediately through Godot MCP.
2. Start a task-owned runtime, wait for its interaction server, then pause it before `game_eval` or screenshots. If MCP would interfere with another session, use an owned CLI-driven graphical fixture or isolated validation copy; do not pause the user's current battle.
3. Construct the exact ability/entity/status state instead of waiting for random gameplay.
4. For changed animations, capture representative ages and confirm travel, drift, orbit, scale, or fade actually changes. For static equipment, compare the relevant equipped/unequipped states.
5. Include the first and final frame for procedural polygons; confirm the live error stream has no triangulation or invalid-polygon failures.
6. Inspect at 540 px preview size for recognition and at production scale for line quality.
7. Check ball identity, internal HP, top health bars, target direction, layer order, and effect density.
8. Confirm the effect ends cleanly and does not leave a static overlay, collision source, sound loop, stale velocity restore, or invisible damage.
9. For a sustained effect, inspect active, paused, resumed, natural-end, and battle-resolution states instead of judging only its initial sound.
10. Read debug output, stop only the task-owned runtime, clean only its MCP-injected metadata, and run `git diff --check`. Preserve unrelated runtimes and autoloads.

Treat a source-code assertion as coverage, not as visual approval. A real screenshot or rendered frame must prove that the intended symbol is recognizable.
