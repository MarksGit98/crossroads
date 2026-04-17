# Gameplay Architecture — Living Overview

> **Purpose:** A single always-current page that describes how gameplay code
> is organized, how data flows through it, and where to look when debugging.
> This is *not* a design doc — it documents the **current state** of the code,
> not the game's rules. Update it when architecture shifts.
>
> **Last structural change:** Pass 1 of DuelContext migration — single source
> of truth for duel-wide state, partitioned sub-registries planned.

---

## 1. System Map

```
                         ┌─────────────────────┐
                         │   DuelTestScene     │   (duel root)
                         │  owns DuelContext   │
                         └──────────┬──────────┘
                                    │ builds & injects
                                    ▼
                         ┌─────────────────────┐
                         │    DuelContext      │
                         │  (single src of     │
                         │   truth, RefCounted)│
                         └──────────┬──────────┘
       ┌───────────────┬────────────┼────────────┬─────────────────┐
       │               │            │            │                 │
       ▼               ▼            ▼            ▼                 ▼
    Player          HexGrid       Hand       TurnManager    BoardInteraction-
 (mana/health)   (tile state,   (cards,    (phases, enemy        Manager
 play_restrict.   creatures)    targeting,    AI loop)      (creature select,
   registry)                   drag/drop)                    move/attack UI)
       │               │                                          │
       └── spawns ──► Creature ◄── can_use_active(ctx) ───────────┘
                         │
                         └── applies effects via Card._apply_effect(ctx)

                    ┌─── Sub-registries (planned Pass 2+) ───┐
                    │   creatures / spell_effects / traps    │
                    │   equipment / tile_effects             │
                    └────────────────────────────────────────┘
```

**Key principle:** systems never reach for each other directly. Anything a
subsystem needs about the duel lives on `DuelContext`. When a new capability
is added (new gamemode, new AI decision, new UI panel), it consumes the
context; it doesn't thread a new parameter through five `setup()` calls.

---

## 2. The DuelContext — what's on it, why it's there

| Field | Type | Purpose |
|---|---|---|
| `player` | `Player` | The human side — mana, health, hand, play restrictions |
| `enemy_player` | `Player` | AI side. Null until 2-sided duels wired |
| `board` | `HexGrid` | Hex tiles, occupancy, pathfinding, highlights |
| `turn_manager` | `TurnManager` | Current phase, turn number, enemy AI loop |
| `hand` | `Node2D` (Hand) | Card drag/drop, targeting UI |
| `creatures_node` | `Node2D` | Parent of all spawned `Creature` nodes |
| `gamemode` | `GamemodeTypes.Mode` | TDM / CTF / Destroy-Point / Escort / Defend |
| `target_hexes` | `Array[Vector2i]` | Transient — current action's hex target(s) |
| `target_units` | `Array` | Transient — current action's unit target(s) |
| `caster` | `Creature` | Transient — creature initiating the current action (null for hand-played cards) |

**Live-state helpers** (always reflect current truth, no push-updates needed):
`current_phase()`, `turn_number()`, `is_player_turn()`, `active_side()`.

**Cross-cutting queries** (aggregate over sub-systems):
`play_restrictions_all()` — pools restrictions from both players.

**Transient management:** `set_targets(hexes, units, caster)` stamps action
data; `clear_transient()` wipes it afterwards. The caller (Hand,
BoardInteractionManager) owns this lifecycle — cards and creatures never
mutate the context, they only read it.

---

## 3. Life of a Spell Card (Frost Bolt example)

```
Player drags Frost Bolt above play threshold
        │
        ▼
Hand._try_play_card(card)
        │ clears ctx.transient
        ▼
card.can_play(ctx)  ──► Card.can_play()
        │                 ├── player.can_afford(cost_value, cost_type)
        │                 └── player.play_restrictions.can_play_card(data)
        │              ──► SpellCard.can_play() (super + valid-target check)
        │ passes
        ▼
card.needs_targeting() == true
        │
        ▼
Hand._enter_targeting(card, valid_targets)
        │ highlights hexes, shows preview
        ▼
Player clicks enemy hex
        │
        ▼
Hand._on_target_hex_clicked  →  _confirm_targeting
        │ ctx.set_targets([hex])
        ▼
card.play(ctx)  ──► Card.play()
        │            ├── player.pay_cost(cost_value, cost_type)
        │            ├── player.play_restrictions.record_card_played(data)
        │            └── resolve_effects(ctx)
        │                   └── for each effect: _apply_effect(effect, ctx)
        │                           └── _resolve_effect_targets → Creatures
        │                           └── match effect.type → creature.take_damage / apply_status / …
        ▼
Hand._finalize_play: PLAYED state, discard, queue_free, re-fan
```

**Where mana is spent:** exactly once, inside `Card.play()`, *after* targeting
confirmation. Cancelled targeting (right-click / ESC) never reaches `play()`.

**Where effects resolve:** `Card._apply_effect()` is the single dispatcher for
all effect types (`DEAL_DAMAGE`, `HEAL`, `MODIFY_STAT`, `APPLY_STATUS`,
`REMOVE_STATUS`, `SHIELD`, `STUN`, `SILENCE`, `DRAW_CARD`, `MARK_SPAWN`,
`DESTROY`, `EXECUTE`, …). Add a new effect type → add a new case there.

---

## 4. Life of a Creature Active Ability (Wizard's Arcane Anchor)

```
Player clicks Wizard creature
        │
        ▼
BoardInteractionManager._on_creature_clicked
        │
        ▼
action_menu.show_for_creature(creature, screen_pos, has_attack, ctx)
        │ menu builds one button per ability, each gated by
        │ creature.can_use_active(i, ctx)
        ▼
Player clicks "Arcane Anchor" button
        │
        ▼
BoardInteractionManager._enter_active_targeting(ability_index)
        │ SELF-target rule → skips hex selection
        ▼
BoardInteractionManager._execute_active_on_target(coord)
        │ ctx.set_targets([coord], [], selected_creature)
        ▼
creature.use_active(idx, ctx)  ──► Creature.use_active()
        │   ├── player.pay_cost(ability.cost, ability.cost_type)
        │   ├── ctx.caster = self
        │   └── for each effect: _apply_active_effect(effect, ctx)
        │           └── MARK_SPAWN → ctx.board.mark_spawn(hex_position)
        ▼
ctx.clear_transient()
interaction returns to IDLE
```

---

## 5. Life of a Turn

```
TurnManager.begin_combat()
        │
        ▼
_start_player_turn()
        ├── turn_number++
        ├── player.start_turn()   (mana reset, turn counter)
        ├── _reset_friendly_creatures()  (clear has_moved/attacked/used_active)
        ├── phase = DRAW_PHASE
        ├── hand.draw_cards(N)    (INITIAL_DRAW first turn, TURN_DRAW after)
        ▼
_enter_action_phase()
        ├── phase = ACTION_PHASE
        └── interaction_manager.set_enabled(true)
        ▼
[player plays cards / moves / attacks / uses actives]
        ▼
_end_player_turn()  (End Turn button)
        ├── interaction_manager.set_enabled(false)
        ├── phase = END_TURN_PHASE
        ├── _end_turn_friendly_creatures()  (tick status effects)
        ├── player.end_turn()
        │     └── play_restrictions.on_turn_ended()  (clear per-turn caps,
        │                                             remove expiring rules)
        ▼
_start_enemy_turn()
        ├── phase = ENEMY_TURN
        ├── _reset_enemy_creatures()
        ├── for each living enemy: _resolve_enemy_action()
        │     └── simple AI: attack if in range, else move toward nearest
        ▼
_start_player_turn()   (loops)
```

---

## 6. Subsystems — what each file owns

### Core
| File | Responsibility |
|---|---|
| `scripts/duel/duel_context.gd` | Single source of truth — persistent refs, transient action data, live-state helpers |
| `scripts/duel/duel_test_scene.gd` | Duel root: owns ctx, instantiates subsystems, wires signals |
| `scripts/duel/turn_manager.gd` | Phase state machine, draw/reset per turn, enemy AI loop |
| `scripts/duel/board_interaction_manager.gd` | Board-level UI state machine: select creature → menu → move/attack/active targeting |
| `scripts/duel/gamemode_types.gd` | Mode enum + win/loss metadata (TDM, CTF, Destroy, Escort, Defend) |

### Player state
| File | Responsibility |
|---|---|
| `scripts/player/player.gd` | Mana, health, attack, turn counter, max creature cap; generalized `can_afford` / `pay_cost` |
| `scripts/player/play_restriction_registry.gd` | Tracks per-turn play caps & forbidden-card rules from any source (creatures, tiles, persistent cards) |

### Cards
| File | Responsibility |
|---|---|
| `scripts/cards/card.gd` | Base class: bake, state machine, `can_play`/`play`/`resolve_effects`/`_apply_effect` dispatcher |
| `scripts/cards/card_data.gd` | Data container (Resource): id, name, stats, effects[], passives[], actives[], … |
| `scripts/cards/card_types.gd` | All gameplay enums (CardType, EffectType, TargetRule, StatusEffect, Keyword, …) |
| `scripts/cards/creature_card.gd` | Summon logic, creature cap check, hex-based targeting |
| `scripts/cards/spell_card.gd` | One-shot effect resolution, `target_rule` filtering |
| `scripts/cards/equip_card.gd` | Attach to friendly creature, apply/remove stat mods |
| `scripts/cards/trap_card.gd` | Placement on hex(es), trigger on enter |
| `scripts/cards/card_description_builder.gd` | Formats effect/passive/keyword text for card faces |
| `scripts/cards/deck.gd` | Draw/discard piles, shuffle, peek/search, viewer overlay |

### Hand / UI
| File | Responsibility |
|---|---|
| `scripts/hand/hand.gd` | Fan layout, hover/drag, targeting mode, `_try_play_card` gating |
| `scripts/ui/creature_action_menu.gd` | Contextual action menu (Move/Attack + per-ability buttons + tooltip) |

### Board
| File | Responsibility |
|---|---|
| `scripts/hex/hex_grid.gd` | Tile dictionary, terrain, occupancy, highlights, spawn-zone marks |
| `scripts/hex/hex_tile_data.gd` | Per-tile state (terrain, occupant, valid_spawn, highlight) |
| `scripts/hex/hex_tile_renderer.gd` | 2.5D tile rendering, borders, overlays |
| `scripts/hex/hex_helper.gd` | Pure math: hex↔world, distance, neighbors, range, ring |

### Creatures
| File | Responsibility |
|---|---|
| `scripts/creatures/creature.gd` | Movement, combat, status effects, actives/passives, state machine hookup |
| `scripts/creatures/enemy/enemy_creature.gd` | Enemy marker + intent (ATTACK / MOVE) display |
| `scripts/creatures/enemy/enemy_spawner.gd` | Places enemies on the right-hand side at duel start |
| `scripts/creatures/creature_state_machine.gd` | Animation state (idle/walk/attack/hurt) |

---

## 7. Cost & Restriction System

**Two layers gate every play/ability:**

1. **Cost** — `Player.can_afford(value, cost_type)` / `Player.pay_cost(value, cost_type)`.
   Cost types: `MANA` (default), `HEALTH`, `SACRIFICE` (todo), `DISCARD` (todo),
   `EXHAUST` (todo). Health costs require strict `current_health > cost`
   (can't kill yourself paying).

2. **Restrictions** — `Player.play_restrictions: PlayRestrictionRegistry`.
   Sources register with a unique id; each restriction filters by
   `card_type_filter` / `card_class_filter` / `card_id_filter` and caps via
   `max_per_turn` (0 = full ban). Restrictions auto-expire at turn end unless
   `expires_at_turn_end: false` is set.

Example — enemy silence aura limiting spells to 1/turn:
```gdscript
ctx.player.play_restrictions.add_restriction("silence#" + str(aura.get_instance_id()), {
    "card_type_filter": CardTypes.CardType.SPELL,
    "max_per_turn": 1,
    "expires_at_turn_end": false,   # stays until source dies
    "description": "Only 1 spell per turn",
})
```

When the source (creature/tile/card) expires:
```gdscript
ctx.player.play_restrictions.remove_restriction("silence#" + str(aura.get_instance_id()))
```

---

## 8. Planned Extensions (not yet implemented)

Kept here so new contributors see the direction.

- **CreatureRegistry** — replace `_get_living_enemies()` / `_get_living_player_creatures()` board scans with a cached O(1) index. Hangs off `DuelContext.creatures`.
- **SpellEffectRegistry** — persistent spell effects (auras, fields, zones) with trigger hooks (ON_CARD_PLAY, ON_MOVE, ON_DAMAGED, …).
- **TrapRegistry** — set-but-not-triggered traps indexed by hex.
- **EquipmentRegistry** — attached equips indexed by owning creature.
- **TileEffectRegistry** — terrain hazards and wards.
- **GamemodeController** — watches `DuelContext` and emits `victory`/`defeat` per the mode's `win_conditions`/`loss_conditions`.

Each one plugs into `DuelContext` and gets targeted query methods (`friendly()`, `at_hex(coord)`, `by_source(id)`, …). Anything currently scanning `board.tiles` or `creatures_node.get_children()` is a candidate to migrate once the relevant registry lands.

---

## 9. Debugging Quick Reference

- **Card does nothing when played?** Check `Card._apply_effect()` — is the `EffectType` in the match statement?
- **Card can't be played?** Three gates in order: `super.can_play()` (cost + restrictions), subclass override (targets exist), `needs_targeting()` + `get_valid_targets()`. Hand shakes card on each failure.
- **Mana not being spent?** Confirm `card.play()` is actually reached — for targeting cards it only runs inside `_confirm_targeting`, not `_enter_targeting`.
- **Creature active disabled?** `Creature.can_use_active()` checks: cooldown, cost affordability, stun/silence, effect-specific rules (e.g. MARK_SPAWN refuses already-valid hexes).
- **Restrictions not clearing?** `Player.end_turn()` calls `play_restrictions.on_turn_ended()`. Only happens on player's End Turn button press, not at enemy turn end.
- **Targeting not resolving the right creature?** `Card._resolve_effect_targets` reads `ctx.target_hexes` → tile → occupant. For `EffectTarget.CASTER`, `ctx.caster` must be set before resolution (hand-played spells leave it null; creature actives set it in `use_active`).

---

## 10. Changelog (abbreviated)

- **2026-04-17** — Introduced `DuelContext` (Pass 1). Migrated `Card.can_play/play`, `Creature.can_use_active/use_active`, `Hand`, `BoardInteractionManager`, `TurnManager`, `CreatureActionMenu` to use it. Old `_play_context: Dictionary` retired.
- **2026-04-17** — Added `PlayRestrictionRegistry` on Player for per-turn play caps and forbidden-card rules.
- **2026-04-17** — Generalized cost system: `Player.can_afford(value, type)` / `Player.pay_cost(value, type)` supporting MANA + HEALTH.
- **2026-04-17** — Implemented `Card._apply_effect` dispatcher (fixed Frost Bolt dealing no damage).
- **2026-04-17** — Added `GamemodeTypes` registry (TDM default + CTF/Destroy/Escort/Defend stubs).
