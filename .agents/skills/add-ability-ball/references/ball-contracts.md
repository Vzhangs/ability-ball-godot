# Ability Ball contract reference

Use this reference after reading the project's authoritative `README.md` and current core scripts. Prefer current signatures when this reference and code differ.

## Contents

- [Module skeleton](#module-skeleton)
- [Persistent setting contract](#persistent-setting-contract)
- [Ability hooks](#ability-hooks)
- [Execution order and timed ownership](#execution-order-and-timed-ownership)
- [Ball-owned progression](#ball-owned-progression)
- [Battle context capabilities](#battle-context-capabilities)
- [Target resolution contract](#target-resolution-contract)
- [Hit memory and sustained statuses](#hit-memory-and-sustained-statuses)
- [Entity interaction capability matrix](#entity-interaction-capability-matrix)
- [Visual skeleton](#visual-skeleton)
- [Entity skeleton](#entity-skeleton)
- [Status skeleton](#status-skeleton)
- [Incoming damage modifiers](#incoming-damage-modifiers)
- [Sampled audio contract](#sampled-audio-contract)
- [Focused test matrix](#focused-test-matrix)

## Module skeleton

```gdscript
extends BallModule

const AbilityScript := preload("res://scripts/balls/<id>/ability.gd")
const VisualScript := preload("res://scripts/balls/<id>/visual.gd")

func _init() -> void:
	super({
		"id": "<id>",
		"name": "<公开名称>",
		"color": "<RRGGBB>",
		"accent": "<RRGGBB>",
		"title_color": "<RRGGBB>",
		"max_hp": 100.0,
		"speed": 185.0,
		"radius": 27.0,
		"cooldown": 4.0,
		"ability": "<面向观众的规则说明：有效目标、结果、限制、反制与重要例外>",
		"sound_kind": "<activation_event>",
		"sort_order": 100,
		"tuning": {
			"strike_damage": {
				"label": "冲击伤害", "default": 12.0,
				"min": 0.0, "max": 500.0, "step": 0.5, "order": 110,
			},
			"summon_max_hp": {
				"label": "召唤物生命值", "group": "召唤物",
				"default": 10.0, "min": 1.0, "max": 1000.0, "step": 1.0, "order": 210,
			},
		},
	}, AbilityScript, VisualScript)
```

The preload is the runtime source of truth. New balls should use `ability.gd`, while an existing module may retain a different ball-local ability filename; validation must resolve `AbilityScript` from `module.gd` rather than assuming a hardcoded filename.

Keep ID, directory, and CLI value identical. Keep the public Chinese name in `name`. `max_hp`, `speed`, `radius`, and `cooldown` automatically become persistent settings. Put every other gameplay numeric value in `tuning`; pure drawing coordinates, colors, audio sample rates, and floating-point epsilon constants do not belong there.

`ability` is the audience-facing rules explanation rendered in the ball picker, tooltip, copy action, and recording ticker. It is not a terse internal label, configuration reference, or narration of what the picture and sound already communicate. Use complete clauses or multiple sentences so a viewer can understand the rule, valid targets, results, restrictions, counterplay, and important exceptions without reading code. Omit all Schema-bound values, including cooldowns, damage, duration, range, probability, count, speed, and percentages. Omit colors, shapes, particles, animation, icons, subtitles, sound effects, and voice lines. Avoid bare keyword chains.

`BattleView` emits `sound_kind` when it observes an increased activation count. The simulation records a due `activate()` call without inspecting a return value. Gate temporarily impossible activations before that call, and still validate placement/resources inside it. For a fixed sound, use an existing procedural event or a globally unique sampled event and do not emit it twice. For material-dependent sounds, current modules can use `sound_kind: ""` (no procedural profile) and explicitly emit the selected namespaced event only after a successful action; see the audio reference.

## Persistent setting contract

`BallModule` owns the Schema and effective values for exactly one ball:

```gdscript
func activate(battle, fighter, opponent, side: int) -> void:
	var damage := settingf("strike_damage")
	battle.damage(opponent, damage, fighter.accent, fighter)
```

Use `settingf()` for continuous values, `settingi()` for integer counts, and `setting()` only when the native variant is required. Build entity/status constructor dictionaries from these helpers so spawned objects receive the effective values instead of reaching back into the registry.

The generic registry, persistence store, and settings dialog may only understand Schema metadata. They must not contain the ball ID or setting keys. Starting or restarting a battle never reloads defaults. The application loads the full `ball_id -> settings` document once, normalizes each dictionary through its owning module, and saves the normalized document after an explicit UI apply action.

Use the existing `BallSettingsStore.settings_path_for_mode()` selection: BOSS ball parameters are isolated from the common profile. Do not encode mode checks or profile paths inside a ball. Per-mode global settings remain separate from ball parameters. Validate both directions of isolation when a change touches persistence.

## Ability hooks

```gdscript
extends BallAbility

func on_battle_started(_battle, _fighter, _opponent, _side: int) -> void:
	pass

func automatic_activation_enabled() -> bool:
	return true

func before_motion(_battle, _fighter, _opponent, _side: int, _delta: float) -> void:
	pass

func speed_multiplier(_battle, _fighter, _opponent, _side: int) -> float:
	return 1.0

func on_step(_battle, _fighter, _opponent, _side: int, _delta: float) -> void:
	pass

func activate(_battle, _fighter, _opponent, _side: int) -> void:
	pass

func cooldown_duration(_battle, fighter) -> float:
	return fighter.cooldown

func after_entities_step(_battle, _fighter, _opponent, _side: int, _delta: float) -> void:
	pass

func contact_damage(_battle, _fighter, _opponent) -> float:
	return 0.0

func after_contact(_battle, _fighter, _opponent, _damage_dealt: float) -> void:
	pass

func after_wall_hit(
	_battle,
	_fighter,
	_opponent,
	_side: int,
	_contact_position: Vector2
) -> bool:
	return false

func after_entity_contact(
	_battle,
	_fighter,
	_entity: BallEntity,
	_damage_dealt: float
) -> void:
	pass

func after_damage_dealt(_battle, _fighter, _opponent, _amount: float) -> void:
	pass
```

Override only needed hooks. Ordinary body collision is physical-only and the base `contact_damage()` returns zero. Override it with a positive value only when body impact is explicitly one of this ball's advertised abilities; do not put collision damage in `module.gd` or shared fighter state. `automatic_activation_enabled()` may be permanently false for a passive ability or temporarily false for a capacity, placement, or resource constraint. Keep this predicate cheap, deterministic and free of mutations or RNG draws; previews may construct an ability before it has a battle context. Return `true` from `after_wall_hit()` only when that wall contact actually activated the passive, so the core records the activation without knowing the ball type.

## Execution order and timed ownership

Treat the current fixed-step order as part of the contract:

1. advance transient visual and entity lifetimes;
2. call `before_motion()`, tick statuses, resolve speed normalization, move, and resolve walls for each fighter;
3. resolve main-ball contact;
4. call `on_step()` and then any due automatic `activate()` for each fighter;
5. step entities and resolve opted-in fighter-to-entity contacts;
6. call `after_entities_step()`;
7. update trails and decide the winner.

An entity spawned during ability update may step later in the same fixed frame. Do not use event playback, drawing, or wall-clock time as a gameplay timer.

Treat every temporary state as an owner with explicit acquisition and release. A lower-priority ability-local stop or resume must first query `battle.movement_control_priority(fighter)`. If a forced status has higher priority, do not zero velocity, capture a new resume value, or restore a stale one. `preserves_external_velocity()` only tells the core not to normalize speed; `movement_control_priority()` orders competing writers. Test the frame before expiry, the expiry-crossing frame, and the first frame after expiry so a freeze or stale restore cannot latch.

## Ball-owned progression

Do not use or introduce a global battle phase. When progression is part of this ball's identity, keep it private to the ability:

```gdscript
var _form_level := 1

func form_level() -> int:
	return _form_level

func on_step(battle, fighter, opponent, _side: int, _delta: float) -> void:
	var next_level := _form_level
	if _form_level < 2 and opponent.hp_ratio() <= settingf("awakening_hp_ratio"):
		next_level = 2
	if next_level != _form_level:
		_form_level = next_level
		battle.spawn_ring(fighter.pos, fighter.accent, fighter.radius, 120.0, 0.5)
```

Let the ball's `visual.gd` read `ability.form_level()` for local rings, symbols, or form changes. Pass the ability to ball-local entities when their behavior depends on it. Never add this state to `FighterState`, `BattleSimulation`, `BallBattleContext`, `BallRenderContext`, or the shared HUD. The same ability must own this progression against every opponent.

## Battle context capabilities

Use these stable operations instead of reaching into `BattleSimulation`:

- deterministic random: `random_float()`, `random_range()`, `random_int()`;
- fighter access: `fighter_for_uid()`, `active_fighters()`, `hostile_fighters()`, `owner_for_entity()`, `opponent_for_fighter()`; use `fighter_for_side()` / `opponent_for_side()` only when a team-level representative is sufficient;
- combat: `damage()`, `damage_entity()`, `heal()`, `contact_damage_for_side()`; damage APIs accept `source_unit` for the actual producing unit or event-time identity, and `record_entity_health_loss()` records an already-applied loss without deducting HP again;
- movement arbitration: `movement_control_priority()`;
- presentation primitives: `spawn_ring()`, `spawn_particles()`, `add_beam()`, `shake_camera()`;
- world objects: `add_projectile()`, `add_entity()`, `entities()`, `count_entities()`;
- incidental entity-hit queries: `damageable_entities()`, `damageable_entities_in_circle()`, `damageable_entities_on_segment()`;
- statuses: `apply_status()`, `has_status()`, `remove_status()`;
- arena queries: `arena_size()`, `ray_to_arena_edge()`;
- telemetry/audio: `record_stat()`, `emit_combat_event()`.

Do not call `spawn_text()` from a ball module. Damage and healing already produce the permitted numeric feedback.

## Target resolution contract

Resolve targets by geometry and capability, never by concrete entity type.

- If an attack can hit the hostile main ball and an attachment in the same action, prefer the main ball unless the public ability explicitly says otherwise.
- If the main ball is outside the valid segment, arc, or radius, still hit a qualifying attachment through `damageable_entities*()`.
- For non-piercing projectiles, calculate swept hit fractions for the main ball and all damageable attachments, choose the earliest valid hit, apply damage once, then remove the projectile.
- For piercing beams or areas, damage every valid target on the geometry without stopping on the first attachment.
- Do not proactively retarget attachments unless hunting attachments is part of the public ability.
- Let invulnerability and other shared defenses resolve through status hooks; do not bypass them by editing HP directly.
- Use `is_terrain()` for terrain-specific exclusions. Durability, attack reception, immobility and biological life are not equivalent: a rooted plant can remain a valid drain target while a destructible block is not. Check eligibility at acquisition, ongoing movement, effect resolution and cleanup; do not add opponent IDs or import another ball's implementation.

### Contact-triggered area follow-up

When an advertised body impact also creates an area effect, split ownership of the resolution instead of applying the same damage through two hooks:

1. `contact_damage()` supplies the direct fighter or entity impact through the shared collision resolver.
2. `after_contact()` and `after_entity_contact()` start the area follow-up only after an accepted contact.
3. Area victim discovery uses `hostile_fighters()` plus `damageable_entities_in_circle()` (or the matching segment query), never entity classes or ball IDs.
4. Skip the primary contact target when applying the area's direct damage because the collision resolver already hit it. Still apply intended statuses, terrain effects, or other secondary consequences to the primary target when the public rule requires them.
5. Reuse the core contact gate instead of adding a parallel overlap timer.

This keeps one contact equal to one direct hit while allowing the same area rule to cover main balls and eligible attachments.

## Hit memory and sustained statuses

Choose the hit policy explicitly; these mechanisms must not share one generic reset rule:

- **One hit per cast/projectile lifetime:** retain a per-target hit set until that cast/entity is removed. Leaving and re-entering must not clear it. The Gojo technique orbs demonstrate this rule for fighters and attachments.
- **One hit per contact episode:** rearm only after the target leaves the weapon/line geometry, with the appropriate separation margin. A rotating sword or moving web must account for relative geometry, not just victim movement.
- **Continuous exposure:** keep a per-target dwell clock, advance it at most once per simulation step even when zones overlap, and reset it when contact or eligibility is lost. Frost trails demonstrate delayed freeze following immediate slow; contact-triggered freeze is a separate source rule.
- **Periodic damage:** own an explicit tick cadence and source identity; do not derive repeated damage from render frames.

Reuse `BurnStatusEffect` with source-owned values rather than fixing burn damage globally. Shared cold slow uses `IceSlowStatusEffect`: repeated sources refresh duration and retain the strongest multiplier without repeatedly multiplying current speed. A temporary standstill is not a valid unslowed baseline. For attachments, check `entity_step_multiplier()` behavior as well as fighter movement. Test overlapping sources, departure, capture, expiry and resumption.

## Entity interaction capability matrix

Choose each capability independently. Implementing one does not imply the others.

| Interaction | Required hooks | Runtime behavior |
| --- | --- | --- |
| Receive attacks | `can_receive_attack()`, `receive_attack()` | Geometry queries and `damage_entity()` can reduce independent entity HP. |
| Terrain semantics | `is_terrain()` (default `false`) | A durable world obstacle can opt in; consumers decide the relevant restriction. The flag alone does not disable destruction, capture, ownership transfer or collision. |
| Entity-to-entity contact | `participates_in_entity_collision()`, inverse mass, contact damage/color, `can_resolve_entity_contact()`, `begin_entity_contact()` | A ball-local entity or ability scans generic participants and resolves contact. The current core does not run a global entity-pair pass. |
| Fighter-to-entity contact | `participates_in_fighter_collision()`, inverse mass, `can_resolve_fighter_contact()`, `begin_fighter_contact()` | The core separates and impulses the hostile fighter and entity, applies advertised contact damage in both directions, then calls `after_entity_contact()`. |
| Black-hole capture/absorption | `is_absorbable()` plus optional attraction/absorption overrides | `disable_for_capture()` freezes autonomous lifetime, step, collision, damage, and abilities while preserving owner and color; the captor moves it until `absorb()`. |
| Ownership transfer | `can_transfer_ownership()`, optional `on_ownership_transferred()` and visual-color hooks | Transfer is permanent, changes hostility immediately, and moves follow/orbit anchors to the new owner. Captured/removed objects reject transfer; projectiles explicitly opt out. |
| Fixed entity HUD | `draw_hud()` | The entity draws compact status inside its owner's provided top-health region without accessing the simulation or view type. |

For entity-to-entity collision, make at least one participant scan generic candidates (a moving unit or a stationary obstacle). Do not require both sides to maintain duplicate scanners, and do not skip stationary candidates merely because their inverse mass is zero. After ownership transfer, recompute hostility from `owner_side`; verify formerly friendly entities can collide with their former side and no longer attack their new side.

For fighter/entity contacts, the core sets `entity.combat_contact_source` before calling `can_resolve_fighter_contact()`. Its `fighter_uid` distinguishes simultaneous same-team attackers even though the hook's positional argument is a team ID. Use it for per-fighter contact episodes; copy the identity when damage is deferred and pass that snapshot as `source_unit`. Clear a leave/re-enter gate only after genuine separation, not merely when a timer expires. Use `combat_category()` for independently reported attachment/material types; keep categories and ownership history out of a central ball-name table.

Projectiles and periodic statuses retain their producer's event-time identity. Ownership transfer changes subsequent actions, not past damage or an already-launched attack's attribution. Validate actual damage/healing, overkill, immunity and before/after-control category totals through the combat ledger; the report must not reconstruct history from surviving entities.

## Visual skeleton

```gdscript
extends BallVisual

func trail_alpha() -> float:
	return 0.27

func trail_width_multiplier() -> float:
	return 1.0

func draw_underlay(_canvas: CanvasItem, _fighter, _context: Dictionary) -> void:
	pass

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	canvas.draw_circle(position, radius, fighter.color)
	canvas.draw_circle(position, radius, fighter.accent, false, 2.2)
```

The visual may read its configured `ability` for presentation state, but must not mutate gameplay. Use shapes, particles, rings, and trails rather than explanatory labels.

## Entity skeleton

```gdscript
extends BallEntity

var _color := Color.WHITE

func _init(spawn_side: int, spawn_position: Vector2, duration: float, spawn_radius: float, color: Color) -> void:
	owner_side = spawn_side
	pos = spawn_position
	remaining = duration
	radius = spawn_radius
	_color = color
	tags = PackedStringArray(["<unique_tag>"])
	draw_layer = -10

func step(_battle, delta: float) -> void:
	pos += velocity * delta

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	canvas.draw_circle(screen_position(context), radius * context.scale_factor, _color)

func draw_hud(_canvas: CanvasItem, _health_bar_bounds: Rect2) -> void:
	pass

func is_absorbable() -> bool:
	return true

func absorption_visual_color() -> Color:
	return _color
```

`BallEntity` already freezes captured objects, preserves ownership, and provides default absorption position/radius. Override `attraction_position()`, `absorption_radius()`, or `absorb()` only when the object's geometry or cleanup differs.

Ownership transfer is separate from capture. A hostile entity may be tested with `can_transfer_ownership()` and changed with `transfer_ownership(new_owner_side, new_owner_anchor)`. Captured or removed objects reject transfer, and projectiles override the capability to reject transfer entirely. The base transfer is permanent until the entity is removed or another mechanic explicitly changes ownership; distance never reverts it. Owner-relative entities override `on_ownership_transferred()` to adopt the new anchor while preserving their native follow or orbit rules. A controlling ability may call `set_ownership_visual_color()` so the entity resolves its own draw colors through `ownership_visual_color()`. The ball initiating control, hacking, or reflection owns any velocity reversal, backlash damage, visual link, and statistics. Depend only on these capabilities and never inspect the entity's concrete type.

An entity with independent HP opts into incidental attack hits without exposing its concrete type:

```gdscript
func can_receive_attack(source_side: int) -> bool:
	return not removed and not is_captured() and is_hostile_to(source_side)

func receive_attack(battle, amount: float, source_side: int, hit_color: Color) -> float:
	if not can_receive_attack(source_side):
		return 0.0
	var applied := minf(hp, amount)
	hp -= applied
	if hp <= 0.0:
		removed = true
	return applied
```

Standard projectiles already perform swept collision and disappear on the first fighter or damageable-entity hit. Most attacks keep their existing target selection and use these queries only to resolve incidental geometric hits. If actively hunting damageable attachments is an explicit part of one ball's public ability, its ball-local ability may select from `damageable_entities()` using deterministic distance/geometry rules. Prefer the enemy fighter whenever both fighter and attachment are valid targets, unless the public ability says otherwise. Never inspect an entity's concrete type or import its owning ball module.

`participates_in_fighter_collision()` joins the core fighter/entity collision pass. `participates_in_entity_collision()` only exposes generic pair-contact capability; a ball-local entity or its ability must currently drive candidate scanning and pair resolution. Keep the resolver type-free and let zero inverse mass mean stationary rather than non-collidable.

Most entities should leave `draw_hud()` unchanged. Override it only for fixed summon or weapon status that must remain readable independently of world motion. `health_bar_bounds` is the owning side's top-level health-bar rectangle; the entity owns its layout inside the available side margin. Do not load `BattleView`, inspect another ball, or encode the entity type in the public view.

## Status skeleton

```gdscript
extends BallStatusEffect

func _init(duration: float, effect_source_side: int) -> void:
	key = "<id>_<effect>"
	remaining = duration
	source_side = effect_source_side

func tick(battle, target, delta: float) -> void:
	super(battle, target, delta)

func preserves_external_velocity() -> bool:
	return false

func movement_control_priority() -> int:
	return MOVEMENT_CONTROL_PRIORITY_NONE

func blocks_damage(_battle, _target, _amount: float, _source) -> bool:
	return false

func modify_incoming_damage(_battle, _target, amount: float, _source) -> float:
	return amount

func on_damage_blocked(_battle, _target, _source, _show_text: bool) -> void:
	pass

func on_wall_hit(_battle, _target) -> void:
	pass

func draw_overlay(_canvas: CanvasItem, _fighter, _context: Dictionary) -> void:
	pass

func draw_topmost_overlay(_canvas: CanvasItem, _fighter, _context: Dictionary) -> void:
	pass
```

Use `preserves_external_velocity()` for statuses whose external motion must bypass normal minimum/maximum speed correction. Return `MOVEMENT_CONTROL_PRIORITY_FORCED` when a status must suppress lower-priority ability-local velocity writes; ordinary ability-local movement uses `MOVEMENT_CONTROL_PRIORITY_ABILITY`. Use `refresh_from()` when reapplication needs more than the default duration/source refresh. Store a private visual age when an overlay must start at a stable first frame; advance it in `tick()` and keep it unrelated to gameplay randomness.

An entity's `remaining < 0` already means no lifetime expiry. A status does **not** share that convention: base `is_expired()` tests `remaining <= 0`, and base `tick()` clamps to zero. A battle-long equipment status must explicitly own its non-expiring `is_expired()` and `tick()` behavior. Do not use infinity as a duration in serializable battle state.

## Incoming damage modifiers

`BallStatusEffect.modify_incoming_damage(battle, target, amount, source)` is neutral by default and is used for both fighters and damageable entities. Its actual order is:

1. complete blockers (`blocks_damage()` and the blocking callback);
2. non-expired modifiers, in status-array order, with nonnegative clamping after each;
3. the shared damage scale, then the fighter HP cap or entity's `receive_attack()`;
4. statistics, combat ledger and downstream damage callbacks using the actual applied loss.

Keep armor/reduction values in the owning module's Schema and inject them into the status. Return a modified amount; never recursively invoke damage, directly edit HP, or refund damage with healing. Those shortcuts can trigger false kills, healing totals or lifesteal. Tests should cover neutral defaults, mitigation, vulnerability, expired modifiers, blocker priority, actual ledger amounts, and an entity target. The implementation anchors are `scripts/balls/core/ball_status_effect.gd`, the simulation damage methods, and `tests/test_damage_modifiers.gd`.

## Sampled audio contract

Declare ball-owned sampled events in `module.gd`:

```gdscript
const ImpactSound := preload("res://scripts/balls/<id>/audio/impact.ogg")
const SustainSound := preload("res://scripts/balls/<id>/audio/sustain.ogg")

"sound_kind": "<id>_sustain",
"audio_samples": {
	"<id>_impact": {
		"stream": ImpactSound,
		"gain_db": -10.0,
	},
	"<id>_sustain": {
		"stream": SustainSound,
		"gain_db": -10.0,
		"loop": true,
	},
},
```

Every sample specification requires `stream: AudioStream` and numeric `gain_db`; `loop` is an optional boolean. Event keys are global across modules, so namespace custom events by ball/action. The registry rejects duplicates.

An observed activation-count increase causes `BattleView` to emit the module's `sound_kind`; this path aggregates counts by ball ID rather than preserving each simultaneous caster's event. For a loop that starts with that event, let this positive event start playback and emit the same kind with `0.0` exactly when the owning state ends. For a passive, sub-action, or per-material sound that needs its actual event identity, emit explicitly and avoid a second automatic sound. Never emit both paths for the same start.

Keep loop duration in gameplay state, not in the audio stream. The shared audio layer keeps an already-playing loop alive, pauses/resumes it with the battle, and stops all looped samples on immediate `battle_resolved`, replacement, restart, reconfiguration, and shutdown. `battle_finished` is delayed until the winner reveal and is too late for loop cleanup.

After adding or replacing `.ogg`, run `godot --headless --path . --editor --quit` before validating a script that preloads it. Let Godot generate `.ogg.import`; do not hand-author import metadata. Verify that a loop remains audible beyond one source-stream length and stops at the configured effect boundary.

## Focused test matrix

| Behavior | Evidence |
| --- | --- |
| Registration | Registry contains ID; module validation is empty. |
| Persistent settings | One ball's override survives store reload and a new matchup; other balls retain their own values; invalid values normalize to this ball's Schema. |
| Activation | Ability counter/stat increases and expected state appears. |
| Damage/heal | HP and shared statistics change by the expected amount. |
| Contact area follow-up | The primary contact target takes direct damage once; intended statuses still apply; other in-range hostile fighters and damageable entities receive the area result without concrete-type branches. |
| Body collision | Ordinary contact only rebounds; an explicit collision ability damages only from its owning side. |
| Progression | Level/form state lives in the ball's unique ability; shared simulation, contexts, and HUD expose no phase. |
| Resources/equipment | Seeded weighted outcomes, zero-weight exclusion, placement failure without RNG consumption, protected pickup and independent non-downgrading slots; see the resource reference. |
| Terrain | A terrain target cannot start or sustain a forbidden drain/drag, cannot produce healing or latch immunity, but keeps its declared collision/durability behavior. A stationary non-terrain positive control still works. |
| Damage modifiers | Fighters and entities use the same modifier pipeline; immunity wins, expired modifiers stop applying, and only actual loss enters the ledger. |
| Entity/status | Correct owner/tag/key, finite lifetime, and cleanup. |
| Damageable entity | Enemy geometry hit reduces its own HP; friendly and off-shape attacks do not; non-piercing projectiles disappear on hit. |
| Entity collision | Moving-versus-moving and moving-versus-stationary hostile pairs separate and exchange only advertised damage; same-owner pairs do not. |
| Fighter/entity collision | Opted-in hostile entities alter the fighter trajectory and exchange ability/entity contact damage; non-participants do not. |
| Capture versus transfer | Capture preserves owner/color and disables behavior; transfer changes owner/anchor/color permanently; projectiles cannot transfer. |
| Movement priority | Forced movement suppresses lower-priority stops/restores; expiry cannot leave a frozen or stale velocity. |
| Counterplay | At least one defense, distance, timing, or capture case works. |
| Determinism | Same seed and inputs produce equal snapshots. |
| Rendering | Ball, entity, and overlay draw paths execute in visual smoke. |
| Presentation timeline | Cast, travel, impact, linger, and cleanup states can be observed at representative times. |
| Layering | Underlays remain below bodies; strikes and ordinary overlays remain above; must-cover indicators use the topmost hook. |
| Audio isolation | Each custom sample or voice plays only for its owning combat event. |
| Continuous audio | A loop starts once, survives beyond one sample length, pauses/resumes, stops at the configured state end, and is cleared on immediate resolution/restart. |
| Match closure | Representative and all-pairs matches finish or reach configured adjudication; no fixed winner or target win rate is required. |

Mechanism and configuration invariants are the completion gate. Balance review is optional and must not introduce matchup-level damage, recovery, HP, cooldown, ability, or spawn compensation.
