---
name: add-card-effect-type
description: "Add a new gameplay effect type (EffectType enum value) that can be referenced from card data. Covers the enum declaration, the dispatcher branch in Creature.apply_effect, target resolution, and schema documentation. Use when the user asks to add a new card/ability behavior that isn't already covered by DEAL_DAMAGE / HEAL / APPLY_STATUS / MODIFY_STAT / MARK_SPAWN / THROW_AXE / UPGRADE_CREATURE / etc."
argument-hint: "[effect name]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit
---

# Adding a new effect type

Card abilities resolve through a single dispatcher — `Creature.apply_effect(effect, ctx)` — driven by an `EffectType` enum value. Adding a new verb (e.g., `POLYMORPH`, `SUMMON_TERRAIN`, `CHAIN_LIGHTNING`) is a small, surgical change in a predictable set of files.

## Why a new EffectType vs reusing

**Use an existing type** if the new behavior can be expressed as parameter changes (e.g., "DEAL_DAMAGE with a new damage_type" doesn't need a new effect type).

**Create a new type** when:
- It needs dispatch logic the existing types don't express
- It mutates a different part of the game state (tile, deployable registry, deck, player)
- The semantics are fundamentally different (e.g., UPGRADE_CREATURE flips a flag; THROW_AXE spawns a world entity)

## The required edits

### 1. Declare the enum value

`scripts/cards/card_types.gd` — `enum EffectType`:

```gdscript
enum EffectType {
    ...existing entries...
    MY_NEW_TYPE,     ## One-line description of what it does, as a
                     ## continuation comment on the next lines if needed.
                     ## Call out any required fields in the effect dict.
}
```

Pick a name that reads as a **verb** or action: `PURGE`, `SUMMON`, `TELEPORT_TARGET`. Avoid overly specific names unless the behavior is truly one-off (`THROW_AXE` is OK because it's coupled to a specific deployable).

### 2. Add the dispatcher branch

`scripts/creatures/creature.gd` — static function `apply_effect`. Add a `match` branch:

```gdscript
CardTypes.EffectType.MY_NEW_TYPE:
    # 1. Extract params from the effect dict.
    var value: int = effect.get("value", 0)

    # 2. Do the thing — loop `targets` for per-creature effects,
    #    or access ctx.board / ctx.player / ctx.deployables for
    #    non-creature state changes.
    for creature: Creature in targets:
        if creature.is_alive():
            creature.some_mutator(value)
```

### 3. Document the effect dict schema

Leave doc comments where the dispatch branch lives explaining what fields the new effect reads. Future balance tweaks and new cards will rely on this.

Standard fields an effect can pick up (you don't have to use them all):

| Field | Type | Used for |
|---|---|---|
| `"type"` | `EffectType` | Required — dispatches here |
| `"target"` | `EffectTarget` | Who the effect resolves on (SELECTED / CASTER / ALL_*_IN_AREA) |
| `"value"` | `int` | Magnitude — damage, heal amount, delta |
| `"damage_type"` | `DamageType` | For DEAL_DAMAGE variants |
| `"duration"` / `"duration_turns"` | `int` | Status duration |
| `"status"` | `StatusEffect` | For status-related effects |
| `"stat"` | `Stat` | For MODIFY_STAT |
| `"aoe_radius"` | `int` | Limits ALL_*_IN_AREA to N hexes from center |
| `"aoe_center"` | `String` | `"caster"` = AoE centered on caster; default = target_hexes[0] |
| `"max_targets"` | `int` | Caps result size; -1 = unlimited |
| `"exclude_primary_target"` | `bool` | Drop target_hexes[0] from the result (splash-on-others) |

Anything outside this set is effect-specific — document it in the enum's doc comment.

### 4. Extend target resolution (only if needed)

If the new effect needs a novel target set that existing `EffectTarget` enum values don't cover (e.g., "all deployables on the board"), you may need to:

- Add a new `EffectTarget` entry
- Extend `Creature.resolve_effect_targets` with a matching `match` branch

Usually unnecessary — most effects reuse `SELECTED` / `CASTER` / `ALL_ENEMIES_IN_AREA`.

### 5. Extend `TargetRule` (only if needed)

`TargetRule` governs the **ability's targeting rules** (what hexes are clickable), distinct from `EffectTarget` (which creatures a specific effect resolves on). If the new effect requires a novel targeting interaction (like the axe throw's `LINE_HEX` for cardinal-only lines), add the rule and wire it in `Creature.get_active_targets`.

### 6. Wire into the dispatcher for special flows

If your effect is async (awaits animations) or needs DuelContext mutation that can't fit the synchronous dispatcher, follow the THROW_AXE pattern: call a dedicated helper from the branch, implemented as its own function:

```gdscript
CardTypes.EffectType.MY_NEW_TYPE:
    _dispatch_my_new_type(effect, ctx)

# ... elsewhere ...

static func _dispatch_my_new_type(effect: Dictionary, ctx: DuelContext) -> void:
    # Complex logic lives here, not inline in the match branch.
```

## The checklist

1. [ ] `EffectType.MY_NEW_TYPE` added with doc comment in `card_types.gd`
2. [ ] Dispatcher branch added in `Creature.apply_effect` (or a helper for complex cases)
3. [ ] Schema comment documents required/optional fields
4. [ ] If new target rule needed → `TargetRule` entry + `get_active_targets` branch
5. [ ] If new effect target shape needed → `EffectTarget` entry + `resolve_effect_targets` branch
6. [ ] Test by wiring it into at least one card (creature's active, spell card, or equip modifier) and playing through it

## Examples in the repo

- **Simple** — `UPGRADE_CREATURE`: 2 lines of dispatch, iterates targets, calls `creature.upgrade()` on each. See `Creature.apply_effect` match arm.
- **Medium** — `MARK_SPAWN`: reads `ctx.target_hexes[0]`, calls `ctx.board.mark_spawn(hex)`. No per-creature loop.
- **Complex with deployables + async** — `THROW_AXE`: delegates to `_dispatch_axe_throw()` which walks a hex line, applies damage to each enemy, then spawns a `ThrownAxe` deployable via `throw_to()` (fire-and-forget async).
- **AoE with configurable center** — `DEAL_DAMAGE` combined with `EffectTarget.ALL_ENEMIES_IN_AREA` + `"aoe_center": "caster"` (Minotaur Earthquake Slam).

## Common pitfalls

- **Forgetting doc comment on the enum entry.** Every other team member (me in a future session) will have to re-derive the schema by reading dispatch code. Always document.
- **Hardcoding fields that should be parameterized.** If you find yourself typing literal `3` / `"PHYSICAL"` in the dispatch branch, consider pulling those out to effect dict fields (`value`, `damage_type`) so cards can parameterize.
- **Breaking single-responsibility on Creature.apply_effect.** Once a branch exceeds ~10 lines or needs async, extract to `_dispatch_X()` helper.
- **Missing `is_alive()` check** before mutating creatures in the targets loop — dead targets from earlier effects this tick will crash on `.modify_atk()` etc.
- **Modifying `ctx.target_hexes` in the dispatch branch.** Transient fields are cleared by the caller; don't mutate them mid-resolve.

## Reference — files that collectively define the effect system

- `scripts/cards/card_types.gd` — enums (EffectType, EffectTarget, TargetRule, DamageType, etc.)
- `scripts/creatures/creature.gd` — `apply_effect`, `apply_effect_list`, `resolve_effect_targets`, `get_active_targets`
- `scripts/cards/card.gd` — `Card.resolve_effects` delegates to `Creature.apply_effect_list`
- `scripts/duel/duel_context.gd` — ctx fields (player, board, target_hexes, caster, deployables, etc.)
- `docs/architecture/gameplay-flow.md` — Section 3 ("Life of a Spell Card") shows the full resolution path
