---
name: add-ability-ball
description: Design, implement, refine, and verify modular balls in the Ability Ball Lab Godot project. Use when Codex is asked to add or redesign an ability ball, weapon, summon, projectile, attachment, status effect, growth form, cast animation, combat VFX, one-shot or continuous combat audio, or related ball-owned behavior while preserving high cohesion, low coupling, persistent per-ball settings, deterministic battles, and generic cross-entity interactions.
---

# Add Ability Ball

Deliver one production-ready ball or ball-owned refinement without teaching the shared core about that ball.

For skill-maintenance requests, reconcile the instructions with current source and focused tests; edit the skill, not game behavior. Validate the skill and its references without launching unrelated battles.

## Establish current truth

1. Locate the `ability-ball-godot` directory containing `project.godot`.
2. Read the nearest `AGENTS.md` files and the project `README.md` completely before editing.
3. Inspect the changed implementation, `scripts/balls/core/`, the relevant shared audio/view lifecycle, and two closest ball-local patterns. Reuse a contract, not another ball.
4. Treat the current core signatures and tests as executable truth. If this skill differs, follow the code and update the skill reference when the task includes skill maintenance.
5. Preserve unrelated and uncommitted work. Use `apply_patch` for source edits.
6. Prefer Godot MCP for structured inspection, runtime control, screenshots, and GDScript validation. Prefer Godot CLI for imports and headless tests. Use GUI interaction only when MCP and CLI cannot make the required judgment.

## Define the ball before coding

Write a compact implementation brief covering:

- stable lowercase-snake-case ID, public name, combat loop, trigger, cadence, cooldown, and failure conditions;
- damage, healing, movement, defense, control, target priority, and ordinary body-collision policy;
- each produced object and whether it is terrain, damageable, entity-collidable, fighter-collidable, capturable, absorbable, ownership-transferable, or collectible;
- ball-owned progression or forms, with no global phase;
- the full lifecycle: anticipation, release, travel or sustained action, impact, linger, pause, resolution, replacement, and cleanup;
- primary color, accent, silhouette, target-facing attachments, cast/status symbols, draw layers, particles, and audio events;
- a reader-facing public ability description that explains the rule, valid targets, results, restrictions, counterplay, and important failure cases; omit every Schema-bound value and all visual, animation, subtitle, color, particle, audio, or voice narration because the audience learns presentation from the battle itself;
- every gameplay numeric setting with Chinese label, default, minimum, maximum, step, group, order, and optional unit.

For a refinement, describe only the changed rules and affected contracts. Use 100 as default main-ball HP and 10 as default HP for an independently damageable attachment unless the user specifies otherwise; terrain durability need not equal creature HP. Make reasonable numeric assumptions when identity is clear; balance is not a completion gate. Ask only when a missing choice changes the identity or requires a materially new shared contract.

## Choose the smallest extension surface

Read [references/ball-contracts.md](references/ball-contracts.md) for current hooks, execution order, entity capabilities, target resolution, movement ownership, and lifecycle contracts. For visible, animated, status, growth, or audio work, also read [references/visual-and-audio-design.md](references/visual-and-audio-design.md).

For material drops, placement, collectibles, equipment slots, destructible terrain, or armor, read [references/resources-equipment-and-terrain.md](references/resources-equipment-and-terrain.md). It covers weighted randomness, spawn-safe pickup, per-fighter ownership, and the distinction between durability and drainable life.

- Put instant actions and ball-owned timers in the ball-local ability script. Use `ability.gd` for a new ball; when refining an existing ball, treat the `AbilityScript` preload declared by `module.gd` as authoritative instead of renaming a working implementation mechanically.
- Use `battle.add_projectile()` for a standard straight, non-piercing projectile.
- Use a ball-local `BallEntity` for weapons, summons, zones, anchors, tethers, cast icons, piercing projectiles, or other world objects.
- Use a ball-local `BallStatusEffect` for shields, forced movement, buffs, debuffs, and persistent overlays.
- Reuse a core status only when its semantics are shared; inject caller-owned values and identity.
- Use `visual.gd` for the main body and constant identity.
- Give the ball exactly one configuration, ability implementation, and visual entry across all opponents.
- Extend a shared contract only when it is generic, type-free, and useful to multiple balls. Add a shared regression test and keep ball IDs out of the contract.

## Implement one self-contained module

Create at minimum:

```text
scripts/balls/<id>/
├── module.gd
├── ability.gd
└── visual.gd
```

`ability.gd` is the standard name for new work. Existing modules may use another ball-local filename; verification must follow the module's declared `AbilityScript` preload and reject only missing or cross-directory implementations.

Keep ball-specific preloads, entities, statuses, assets, and attribution inside that directory. Bind ability and visual from `module.gd`; let `BallRegistry` auto-discover the module. Never add the ID to the registry, simulation, view, UI, or a manual ball list.

Treat the module's `ability` field as the actual explanation shown to a viewer choosing or watching a ball, not as a slogan, tag list, configuration reference, or substitute for the picture. It may contain multiple sentences and should answer: what rule activates, what it can affect, what combat result it produces, what restriction or counterplay applies, and which important edge cases behave differently. Never include cooldowns, damage amounts, durations, ranges, probabilities, counts, speeds, percentages, or any other Schema-bound value. Never narrate colors, shapes, particles, animation, cast icons, subtitles, sound effects, or voice lines. Do not compress a multi-step mechanic into phrases such as `追踪 · 贴墙 · 冲撞`.

Declare every result-, quantity-, duration-, probability-, range-, HP-, and gameplay-motion-affecting value in the ball's Schema. Read settings through `setting()`, `settingf()`, or `settingi()` and inject resolved values into entities and statuses at creation time. Keep pure geometry, colors, audio sample rates, numerical tolerances, and decorative counts local unless the user asks to configure them. Configure presentation timing when it changes action readability.

Do not make the settings store or dialog recognize a ball ID or setting key. Saved values remain active across matchups, seeds, restarts, and application launches.

## Build mechanics and presentation together

- Establish a recognizable still-frame silhouette before spectacle.
- Orient directional attacks and attachments from their current owner toward the chosen target.
- Keep cracks and terrain below bodies, strikes and beams above bodies, and must-cover shields or cast icons in the topmost layer.
- Show a centered finite cast icon only after a cast succeeds when that presentation is appropriate; follow the caster and animate scale or brightness. A requested localized equipment badge takes precedence over an additional face-covering icon or ring.
- Animate growth and consumption instead of replacing states in one frame.
- Keep status motion semantic: fire rises, snow falls and rotates, suction converges, shields pulse.
- Keep decorative protrusions visually socketed without expanding collision unless their geometry is the attack.
- Keep effects readable at 540 px preview and 1080×1200/2K production scale without hiding health or identity.
- Use only damage and healing floating numbers; replace explanations with symbols, motion, particles, and sound.

## Preserve object and status lifecycles

For every entity, explicitly decide owner, position, radius, tags, draw layer, lifetime, HP, contact behavior, capture, absorption, and ownership transfer. Do not assume one opt-in enables every collision pipeline:

- fighter-to-entity contact is core-resolved for entities that implement its complete capability set;
- entity-to-entity contact requires a ball-local scanner/resolver to use the generic capability set unless a type-free shared resolver is deliberately added;
- attack reception is separate from physical collision;
- terrain is an explicit `is_terrain()` capability, not an inference from HP or zero inverse mass; targeting restrictions must be checked at acquisition, maintenance, and effect resolution;
- captured objects preserve owner and color while all autonomous behavior is disabled;
- ownership transfer is permanent, updates owner-relative anchors, and may recolor only through the entity's generic visual-color hook;
- projectiles may be captured and absorbed but remain non-transferable.

For every status, use a stable key, deterministic refresh/expiration, and only the required hooks. Treat `preserves_external_velocity()` as speed-normalization control, not conflict priority. Before writing or restoring velocity, compare `battle.movement_control_priority(fighter)` and yield to higher-priority forced movement. Restore only velocity that the ability still owns; never leave a pending restore that can freeze or overwrite a later status.

Remove or expire all gameplay sources deterministically. Verify no captured entity, expired status, finished beam, resolved battle, or restarted match leaves invisible damage, stale motion ownership, or a playing loop.

Use `modify_incoming_damage()` for partial mitigation or vulnerability. Leave health mutation, actual-damage reporting, and kill handling to the shared damage pipeline; do not simulate armor by damaging then healing or recursively calling damage from an immunity hook.

## Preserve combat interaction rules

- Keep ordinary main-body collision non-damaging. Override `contact_damage()` only when body impact is an advertised ability.
- For a contact-triggered area ability, let `contact_damage()` own the direct target's advertised impact, then use `after_contact()` and `after_entity_contact()` for the follow-up. Exclude that primary target from repeated direct area damage while still applying intended statuses or secondary effects; discover all other victims through hostile-fighter and damageable-entity capabilities rather than concrete types.
- Prefer the hostile main ball when both it and an attachment are valid for the same targeted strike. Still hit a qualifying attachment when the main ball is outside the attack geometry.
- Make standard non-piercing projectiles choose the earliest swept main-ball or damageable-entity hit, apply once, and disappear.
- Let piercing attacks continue through attachments according to their own remaining-damage rule.
- Make transferred entities immediately obey their new hostility, orbit/follow, collision, and firing relationships.
- Keep capture, absorption, ownership transfer, attack reception, fighter collision, and entity collision as separate capabilities.
- Keep gameplay randomness on `battle.random_*()` and visual randomness on the presentation stream.

## Preserve architecture boundaries

Do not:

- load another ball directory or branch on an opponent ID or concrete type;
- add ball-private fields to `FighterState` or expose `BattleSimulation` through render context;
- add ball-specific rendering to `BattleView`;
- duplicate the shared fighter-death effect, death sound, immediate resolution signal, or delayed winner reveal inside a ball;
- add global phase, matchup profile, special scene, second simulation/view, or opponent-specific override;
- hardcode gameplay values outside the owning Schema;
- reset settings when a match, seed, or opponent changes;
- use system time or global randomness for gameplay;
- retain obsolete IDs, fields, adapters, or fallback loaders during development-stage refactors.

## Design audio by event and lifetime

Register ball-owned samples in `module.gd` with globally unique event names. Use `sound_kind` for the automatic successful activation sound; it may name either a procedural event or a custom sampled event registered by that module. Emit other semantic events from ability/entity logic and never operate the audio device from a ball.

For continuous sampled audio, declare `loop: true`, start it with one positive-strength event, and stop it with the same event at strength `0.0` exactly when the owning gameplay state ends. Do not infer effect duration from sample length. Ensure shared presentation lifecycle pauses/resumes the loop and stops it on immediate battle resolution, replacement, restart, and shutdown. Read the audio reference before adding or changing a sample.

## Add focused verification

Cover the relevant subset:

- registry metadata, Schema normalization, persistence, and per-ball isolation;
- activation/cooldown, action timeline, cleanup, and ball-owned progression;
- damage/heal, target priority, ordinary zero-damage contact or explicit asymmetric impact;
- entity attack reception, both collision modes, capture, absorption, ownership transfer, and post-transfer behavior;
- terrain exclusion with a stationary non-terrain positive control; pickup protection, consume-on-contact, weighted outcomes, independent slots, and no downgrades where applicable;
- status refresh/expiration, invulnerability, movement priority, and no stale velocity restoration;
- earliest-hit non-piercing projectiles and explicit piercing depletion;
- deterministic replay and one meaningful counterplay case;
- real body/entity/overlay/topmost drawing paths at multiple animation ages;
- procedural geometry at its first, peak, and final frames, with zero-area polygons skipped and the live Godot error stream clean;
- one-shot audio isolation and continuous audio start, play-past-one-sample, pause/resume, exact stop, and resolution cleanup.

Do not encode a ball ID in shared architecture tests unless adding a genuinely generic invariant.

## Validate the affected behavior

1. After each GDScript patch, immediately run Godot MCP `validate_script` or `validate_scripts` on every changed script. When a script newly preloads an added or replaced audio asset, first run the headless editor import so Godot creates current import metadata, then validate the script.
2. Run focused tests for the changed contracts. For a new ball, gameplay change, or shared-contract change, also run `scripts/verify_ball.sh <project-path> <id>` from this skill. This helper runs import, architecture, default battle, all-pairs roster, visual smoke, logging, and startup checks; it does not automatically discover every ball-specific test. For isolated audio/visual edits, select relevant import, focused, renderer/playback and architecture checks; do not claim an all-pairs run that was not performed.
3. For gameplay work, confirm representative melee, ranged, and entity-heavy matches finish or reach hard-time adjudication and the ability activates naturally. Keep staged visual fixtures separate from evidence of natural gameplay.
4. Run the real project through Godot MCP, or a CLI-driven graphical fixture when MCP is unavailable or would interfere with another session. Pause before `game_eval` or screenshots; inspect changed animation states at representative ages. For static equipment, compare unequipped and equipped states at preview and production scale.
5. Read the live Godot error stream after constructing exact states. Headless rendering and source assertions do not catch every invalid first- or last-frame polygon.
6. Check silhouette, target direction, layers, health readability, effect density, cleanup, and sound timing at preview and production scale.
7. For loops, observe playback beyond one source-sample duration, pause/resume, exact configured effect end, and immediate `battle_resolved` cleanup rather than waiting for the winner popup.
8. Distinguish changed-script failures from pre-existing warnings.
9. Stop only the test runtime owned by this task, remove its empty `[autoload]` residue, and run `git diff --check`. Never interrupt a user's battle or recording merely to obtain a clean test window.
10. Update the README ball table only when public identity or rules changed.

Do not overlap an MCP-injected runtime with CLI suites against the same project configuration: injected autoloads and the interaction port can contaminate later test processes. Sequence them, or use an isolated validation copy with no MCP autoload. When using a copy, verify that tested scripts/assets match the deliverable; keep scratch copies excluded from Godot discovery and Git staging. Read actual exit status and errors, distinguish environmental conflicts from gameplay failures, and rerun affected checks in a clean environment. An already-running game can retain preloaded scripts/audio; report which instance and resource path were checked instead of assuming it hot-reloaded.

## Deliver

Report the combat loop or refinement in enough detail that a reader can predict the behavior without opening the source. Include relevant changed files, configurable values, generic contract changes, checks actually performed, real-window evidence, and remaining limitations. Do not claim completion while a required check is failing or pending. For instruction-only maintenance, report the skill changes and validation rather than claiming game behavior was retested.
