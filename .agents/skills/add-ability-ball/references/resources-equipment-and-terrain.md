# Resources, equipment, and terrain

Use for collectible resources, material progression, equipment slots, or durable placed obstacles. These are conditional patterns, not a requirement that every ball mine resources or use the same material roster.

## Define separate decisions

Specify placement location, material selection, pickup eligibility, consumption, slot selection and upgrade acceptance independently. "Random material" does not imply random map coordinates. A pickup may consume a full-durability object even when its equipment cannot replace a higher tier; decide that rule explicitly rather than deriving consumption from whether stats changed.

Keep material definitions, art, audio mapping, equipment state and produced entities in the owning ball directory. Do not import a material catalog from another ball. Runtime slot levels belong to each ability instance and reset with that fighter's battle lifecycle; persistent configuration belongs to the module, not to the current matchup or equipment save state.

## Weighted material selection

- Expose each material's nonnegative weight through the module Schema. If higher tiers should be rarer, make the default weights descend in the declared tier order; do not reinterpret material rank from an external game's balance rules.
- Draw from `battle.random_*()` only after placement/resource checks succeed. A failed attempt must not advance a sequence, consume the material-selection RNG, or present a successful placement.
- Select using the cumulative positive weights. A zero weight must never win, including when the RNG returns an endpoint. Define the all-zero fallback deliberately; do not silently switch to uniform rare drops.
- Use seeded tests for repeatability, each material enabled alone, zero weights, all-zero behavior, and a sufficiently large fixed-seed frequency sample. Do not assert an exact small-sample distribution.

Current Steve uses descending defaults and falls back to wood when all weights are zero. Those material names, weights and fallback are local product rules, not defaults for unrelated balls. Consult `scripts/balls/steve/module.gd`, `ability.gd` and `tests/test_steve_ball.gd` for the maintained implementation.

## Placement and protected pickup

For a place-at-feet mechanic, moving an invalid spawn toward the arena center can put it in front of the moving owner. A distance check can then wrongly count the owner as having already left the new object. Validate the intended position against the real rectangular arena, clearance and occupancy; when invalid, wait for a valid position instead of silently relocating it into the travel path.

Use the owning ability's activation predicate for temporary placement/capacity constraints and recheck inside `activate()`. Keep checks free of side effects. The simulation records a called activation even if its body returns early, so unchecked failure can produce misleading counters or generic cast audio.

For grid-based placement, specify whether locations are cells, centers, or line intersections. Use separate X/Y spacing from `arena_size()`, and share the coordinate mapping between drawing, snapping, occupancy and collisions. A square-field test alone cannot establish rectangular-field correctness; the Go board places pieces on its rendered line intersections rather than between them.

When immediate reacquisition must be prevented, use an explicit pickup state machine:

1. **Protected:** a configured initial interval prevents collection and does not retain an early leave flag.
2. **Waiting for separation:** after protection, observe the owner fully outside `owner.radius + resource.radius + release_margin`.
3. **Armed:** only a subsequent contact is accepted.
4. **Consumed:** remove the object once and release its capacity; consumption need not reduce durability to zero.

Waiting on the resource when protection expires must not count as a new entry. Test spawn overlap, rapid exit/re-entry during protection, protection expiring under the owner, genuine later re-entry, near-wall placement and immediate capacity release. Keep protection separate from the growth animation; specify whether its clock follows entity action time or world lifetime. Current entity `process_step()` scales delta through statuses, and capture freezes normal processing.

Bind personal pickups and capacity to `owner_fighter_uid`, not merely `owner_side`. Same-team same-kind fighters are distinct owners. If sharing is requested, define that eligibility explicitly. Recheck owner existence, ownership transfer, capture and removal before awarding an item; invalidate the original collection callback when a transfer makes it ineligible.

## Independent equipment slots

Keep a tier for each slot and a separate next-slot policy. Distinguish:

- random initial selection;
- filling a missing slot;
- the policy when all slots exist;
- whether a rejected downgrade still consumes the pickup and advances alternation.

For a no-downgrade rule, compare material rank against the selected slot, not against one global equipment level or current damage values. Tunable damage can be non-monotonic without redefining tier identity. Initialize and test each fighter's state independently; reset neither another slot nor another fighter when one slot upgrades.

A held sword can use ball-local geometry and contact episodes to hit hostile fighters and damageable attachments. Do not also add body-collision damage unless explicitly requested. A persistent armor effect should use the shared incoming-damage modifier described in [ball-contracts.md](ball-contracts.md#incoming-damage-modifiers), not post-hit healing.

## Terrain is not a living target

Declare durable terrain with `BallEntity.is_terrain()`. Having HP, accepting damage, being stationary, or having zero inverse mass does not establish biological/drain eligibility. In particular, stationary plants can remain combat units.

Consumers such as a latch/drain ability must query semantic capabilities, not the terrain provider's ID, script, or class. Check restrictions at initial contact, ongoing maintenance, actual damage/healing, and release/cleanup; an invalidated target must not receive a final forced movement or stale velocity restore.

Keep the other capabilities independent. Terrain classification alone does not make an object indestructible or decide whether a different ability can capture, absorb or transfer it. Do not expand a request to change unrelated interactions. Ordinary impact may still deduct configured durability without causing lifesteal, drag, blood-tether VFX or caster invulnerability.

Useful tests are the real terrain, a different terrain fixture without provider-specific tags, a stationary non-terrain positive control, and a target that becomes ineligible during a latch. `tests/test_vampire_terrain.gd` exercises these distinctions.

## Ownership and combat reporting

Use `combat_category()` to distinguish independently reportable resource/material types. Attribute wear to the actual collider using `combat_contact_source` and its `fighter_uid`; copy that identity for deferred wear instead of resolving an arbitrary team representative later. Keep leave/re-enter gates per target, so same-team attackers each get their own contact episode. Controlled entities retain their event-time history while new events use their new owner.

Validate both denial and preservation: forbidden terrain drain stays absent, ordinary durability loss still works, and living-unit drain still works. Include same-team multiple owners, hostile attachments, incidental projectiles, capture, transfer, rectangular arenas, persistent settings and deterministic replay in the applicable test subset.
