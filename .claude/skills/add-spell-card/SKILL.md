---
name: add-spell-card
description: "Add a new spell card to the game. Spell cards resolve a list of effects when played and discard themselves. Covers CardData factory, targeting rules, multi-target support, and the no-range convention (spells can target anything on the board subject to card-text conditions). Use whenever the user says 'add a spell', 'create a spell card', or similar."
argument-hint: "[spell name]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Bash
---

# Adding a new spell card

Spell cards are one-shot: play them, their `effects[]` resolve, the card goes to the discard pile. No scene file, no creature node — just data + the shared SpellCard class handles resolution.

## Project conventions (hard rules)

1. **No code references to `sample images/`.** All art lives under `assets/`.
2. **Spell cards use the shared spell template** at `res://assets/cards/spells/spell_template.png`. Each spell gets unique card art later; for now they share one frame.
3. **No range restriction.** Spells can target any hex on the board. The card's text/conditions determine what's valid — not a numeric range. Leave `card.spell_range` unset (or 0); `SpellCard.get_valid_targets()` filters only by `target_rule`.
4. **Rarity required.** Every card must set `card.rarity`. The meaning of each tier is design-TBD; just pick one that feels proportional to power.
5. **Variant-grouped isn't applicable to spells** (they don't have persistent `actives` / `passives`). Spell upgrades live in the future via `card.is_upgraded` + a `card_data_upgraded.effects` mirror — not needed for first-pass authoring.
6. **Mana is the default cost type** but cards can use other `CostType` values as they land. Today: `MANA`, `HEALTH`. Future: `SACRIFICE`, `DISCARD`, `EXHAUST`.

## File location

**`assets/data/cards/class_cards/<class>/spells/<snake_name>.gd`**

Same `<class>/` structure as creatures (currently everything in `viking/`). If a spell is class-agnostic, still put under `viking/` for now — class reorganization is a future pass.

## The template

```gdscript
## <Spell Name> — one-line pitch.
## Two-line description of what the spell does mechanically.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "<class>_<snake_name>"              # must start with <class>_
	card.card_name = "<Display Name>"
	card.card_type = CardTypes.CardType.SPELL
	card.card_class = CardTypes.Class.VIKING
	card.rarity = CardTypes.Rarity.COMMON          # required — meaning TBD
	card.flavor = "Flavor quote."

	# Cost — default MANA. Future cards may use CostType.HEALTH /
	# SACRIFICE / DISCARD / EXHAUST; each routes through Player.pay_cost.
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 2

	# Targeting — no range. Spells can target anything on the board subject
	# to card-text conditions. target_rule filters what counts as a valid
	# target hex; target_count determines how many the player must click.
	card.target_rule = CardTypes.TargetRule.ANY_ENEMY
	card.target_count = 1                          # default 1; >=2 for multi-target

	# Effects list — resolves in array order via Creature.apply_effect_list.
	card.effects = [
		{
			"type": CardTypes.EffectType.DEAL_DAMAGE,
			"target": CardTypes.EffectTarget.SELECTED,
			"damage_type": CardTypes.DamageType.FIRE,
			"value": 3,
		},
	]

	# Keywords displayed on the card face. Spell cards don't propagate
	# keywords to anything — purely cosmetic/tooltip text for now.
	card.keywords = []

	return card
```

## Targeting rule reference

The most common `target_rule` values for spells:

| `TargetRule` | Player interaction | Good for |
|---|---|---|
| `ANY_ENEMY` | Click any enemy unit on board | Single-target damage / debuff |
| `ANY_ALLY` | Click any friendly unit | Heal / buff |
| `ANY_UNIT` | Click any creature (friend or foe) | Utility that works on either side |
| `ANY_HEX` | Click any hex (occupied or empty) | AoE damage at a location, terrain mods |
| `EMPTY_HEX` | Click any unoccupied hex | Place a zone / summon something |
| `SELF` | Auto-targets hero (no click) | Pure self-buffs |
| `ALL_ENEMIES` | Auto-fires on every enemy | Mass damage, no aiming |
| `ALL_ALLIES` | Auto-fires on every ally | Mass buff (e.g. Shield Wall) |
| `ALL_UNITS` | Auto-fires on everyone | Indiscriminate effect |
| `ADJACENT_ENEMY` / `ADJACENT_ALLY` | Creature-origin only | Rarely useful for spells |
| `SELECT_DIRECTION` | Pick a cardinal direction | Line/cone spells |
| `LINE_HEX` | Pick a hex in a cardinal line from origin | Projectile-style (rare for spells) |

For auto-target rules (ALL_*, SELF), `SpellCard.needs_targeting()` returns false and the spell fires immediately on drag-above-threshold — no hex click needed.

## Effect dictionary schema

Each entry in `card.effects` is a dict the dispatcher parses. The `type` field dispatches to a branch in `Creature.apply_effect`. Standard fields:

| Field | Purpose |
|---|---|
| `"type"` | `EffectType` enum value (required) |
| `"target"` | `EffectTarget` — who resolves (SELECTED / CASTER / ALL_IN_AREA / ALL_ENEMIES_IN_AREA / ALL_ALLIES_IN_AREA) |
| `"value"` | int — damage / heal / stat delta |
| `"damage_type"` | `DamageType` — PHYSICAL / MAGICAL / FIRE / ICE / LIGHTNING / POISON / TRUE |
| `"status"` | `StatusEffect` — for APPLY_STATUS / REMOVE_STATUS |
| `"duration"` / `"duration_turns"` | status duration |
| `"stat"` | `Stat` — for MODIFY_STAT (ATK/HP/ARMOR/MOVE_RANGE/ATTACK_RANGE) |
| `"aoe_radius"` | int — limits ALL_*_IN_AREA to N hexes from center |
| `"aoe_center"` | "caster" → center on caster; default = target_hexes[0] |
| `"max_targets"` | caps AoE result size |
| `"exclude_primary_target"` | drop target_hexes[0] (splash-on-others) |

### Multi-effect spells

A single spell can carry multiple entries in `card.effects` — they resolve in order. Classic "damage + debuff" pattern:

```gdscript
card.effects = [
	{
		"type": CardTypes.EffectType.DEAL_DAMAGE,
		"target": CardTypes.EffectTarget.SELECTED,
		"damage_type": CardTypes.DamageType.ICE,
		"value": 2,
	},
	{
		"type": CardTypes.EffectType.APPLY_STATUS,
		"target": CardTypes.EffectTarget.SELECTED,
		"status": CardTypes.StatusEffect.CHILLED,
		"duration": CardTypes.Duration.N_TURNS,
		"duration_turns": 2,
	},
]
```

## Common spell patterns

### Single-target damage
```gdscript
card.target_rule = CardTypes.TargetRule.ANY_ENEMY
card.effects = [{
	"type": CardTypes.EffectType.DEAL_DAMAGE,
	"target": CardTypes.EffectTarget.SELECTED,
	"damage_type": CardTypes.DamageType.FIRE,
	"value": 4,
}]
```

### Single-target heal
```gdscript
card.target_rule = CardTypes.TargetRule.ANY_ALLY
card.effects = [{
	"type": CardTypes.EffectType.HEAL,
	"target": CardTypes.EffectTarget.SELECTED,
	"value": 4,
}]
```

### AoE damage at a chosen hex
```gdscript
card.target_rule = CardTypes.TargetRule.ANY_HEX
card.effects = [{
	"type": CardTypes.EffectType.DEAL_DAMAGE,
	"target": CardTypes.EffectTarget.ALL_ENEMIES_IN_AREA,
	"damage_type": CardTypes.DamageType.FIRE,
	"value": 3,
	"aoe_radius": 1,
}]
```

### Auto-target mass buff (no hex click)
```gdscript
card.target_rule = CardTypes.TargetRule.ALL_ALLIES
card.effects = [{
	"type": CardTypes.EffectType.MODIFY_STAT,
	"target": CardTypes.EffectTarget.ALL_ALLIES_IN_AREA,
	"stat": CardTypes.Stat.ARMOR,
	"value": 2,
	"duration": CardTypes.Duration.UNTIL_END_OF_TURN,
}]
```

### Multi-target selection (pick 3 enemies)
```gdscript
card.target_rule = CardTypes.TargetRule.ANY_ENEMY
card.target_count = 3
card.effects = [{
	"type": CardTypes.EffectType.DEAL_DAMAGE,
	"target": CardTypes.EffectTarget.SELECTED,   # resolves once per selected hex
	"damage_type": CardTypes.DamageType.LIGHTNING,
	"value": 2,
}]
```
The player clicks 3 enemies; the Hand holds targeting until all 3 are selected; the Nth click commits the play. Already-selected hexes brighten; duplicates ignored.

### Card draw (player-level effect)
```gdscript
card.target_rule = CardTypes.TargetRule.SELF
card.effects = [{
	"type": CardTypes.EffectType.DRAW_CARD,
	"value": 2,
}]
```

## Deck registration

Append the card id to the Spells section of `EXAMPLE_DECK` in `scripts/cards/deck.gd` (alphabetical within the section).

## Verification

1. No `sample images` refs
2. Card id starts with `<class>_` prefix
3. `card_type = SPELL`
4. `rarity` set
5. `cost_value` and `cost_type` both set
6. `target_rule` set
7. `effects` array is non-empty (or the spell does nothing)
8. Deck entry added

## Common pitfalls

- **Forgot `target_count`**: default 1 is fine, but if you *wanted* multi-target and didn't set it, the first click will fire the spell.
- **Using `aoe_radius` at the card level** (instead of on the effect): `card.aoe_radius` is a legacy field that isn't consistently respected. Put AoE params inside the effect dict (`"aoe_radius": N`).
- **Auto-target rule + `target_count > 1`**: doesn't make sense. Auto-target rules (ALL_*, SELF) don't require clicks; `target_count` only matters for click-picked targeting.
- **Forgot `damage_type` on DEAL_DAMAGE**: defaults to PHYSICAL, which bypasses ice / fire immunity interactions. Be explicit.
- **Mixing `SELECTED` with auto-target rules**: if `target_rule` is `ALL_ALLIES`, the player never clicks, so `EffectTarget.SELECTED` has nothing to resolve against. Use `ALL_ALLIES_IN_AREA` instead.
- **Card-text conditions are NOT code yet.** If your spell reads "costs 0 if your HP is below 50%", that's a future `play_conditions` system — document it in the `flavor` / `description` for now and note it in the card comment.

## Need a new effect type?

If the spell's behavior can't be expressed with existing `EffectType` values, run the **add-card-effect-type** skill first. Register the new type + dispatcher branch, then reference it from this spell's `effects[]`.

## Reference files

- `assets/data/cards/class_cards/viking/spells/frost_bolt.gd` — damage + status combo
- `assets/data/cards/class_cards/viking/spells/healing_rune.gd` — single-target heal
- `assets/data/cards/class_cards/viking/spells/shield_wall.gd` — mass auto-buff
- `scripts/cards/spell_card.gd` — implementation of `can_play` / `play` / `get_valid_targets`
- `docs/architecture/gameplay-flow.md` — Section 3 "Life of a Spell Card" trace
