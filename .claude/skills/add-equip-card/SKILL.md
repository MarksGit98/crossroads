---
name: add-equip-card
description: "Add a new equipment card to the game. Equipment attaches to a friendly creature, applying modifiers (stat deltas, granted keywords, applied/removed statuses) while attached. Covers the equip_modifiers + equip_rules schema, the no-range convention (equips can target any friendly creature subject to card-text conditions), and the shared equip template art. Use whenever the user says 'add equipment', 'create an equip card', or similar."
argument-hint: "[equip name]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Bash
---

# Adding a new equipment card

Equipment cards are played on a friendly creature, apply a set of modifiers at attach time, and persist until the creature dies (or later, until explicit destruction). They don't resolve `effects[]` like spells — they have their own `equip_modifiers[]` schema.

## Project conventions (hard rules)

1. **No code references to `sample images/`.** All art lives under `assets/`.
2. **Equips share the template** at `res://assets/cards/equips/equip_template.png`. Per-card art comes later.
3. **No range restriction on equips.** An equip can target any friendly creature on the board. The card's text/conditions determine what's valid — not a numeric range.
4. **Two independent validation gates** must pass for an equip to land:
   - **Card-level (`equip_rules`)**: "my card only attaches to Vikings / tanks / creatures with FLYING / creatures with base_atk ≥ 3".
   - **Creature-level (`can_accept_equip`)**: "this creature has room in `equipment_slots` / isn't refusing equipment right now".
   Both must return true. If either fails, the creature's hex doesn't highlight as a valid target.
5. **Rarity required.** Every card sets `card.rarity`. Tier meaning is design-TBD.
6. **Default cost is MANA** but other `CostType` values work too (HEALTH today; SACRIFICE / DISCARD / EXHAUST later).

## File location

**`assets/data/cards/class_cards/<class>/equips/<snake_name>.gd`**

## The template

```gdscript
## <Equip Name> — one-line pitch of what it buffs / grants.
## Two-line description of the intended feel / use case.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "<class>_<snake_name>"              # must start with <class>_
	card.card_name = "<Display Name>"
	card.card_type = CardTypes.CardType.EQUIPMENT
	card.card_class = CardTypes.Class.VIKING
	card.rarity = CardTypes.Rarity.COMMON          # required
	card.flavor = "Flavor quote."

	# Cost
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 1

	# Targeting — no range. Equips can target any friendly creature subject
	# to equip_rules + the target creature's can_accept_equip gate. The
	# target_rule should always be ANY_ALLY for standard equips.
	card.target_rule = CardTypes.TargetRule.ANY_ALLY
	card.target_count = 1                          # >=2 to attach to N creatures at once (rare)

	# Equip rules — optional card-level gating. Leave empty for "any friendly."
	# card.equip_rules = {
	# 	"allowed_classes":    [CardTypes.Class.VIKING],
	# 	"allowed_roles":      [CardTypes.CreatureRole.TANK, CardTypes.CreatureRole.STRIKER],
	# 	"required_keywords":  [CardTypes.Keyword.FLYING],
	# 	"forbidden_keywords": [CardTypes.Keyword.ETHEREAL],
	# 	"min_atk": 3,
	# 	"max_atk": 99,
	# }

	# Equip modifiers — what the equip DOES to the creature. Parsed by
	# EquipCard._apply_modifiers at attach (BUFF, +1) and detach (DEBUFF, -1).
	# Positive values = buffs, negative = debuffs. Mix freely.
	card.equip_modifiers = [
		{
			"type": CardTypes.EquipModifierType.MODIFY_STAT,
			"stat": CardTypes.Stat.ARMOR,
			"value": 3,
		},
	]

	# Keywords granted to equipped creature. Apply while equipped, revoked
	# on detach. Separate pipeline from equip_modifiers; use this for
	# "persistent traits" like DOUBLE_ATTACK, FLYING, LIFESTEAL.
	# (Status effects with duration go in equip_modifiers instead.)
	card.keywords = []

	return card
```

## The three equip modifier types

### `MODIFY_STAT` — additive stat delta
```gdscript
{ "type": CardTypes.EquipModifierType.MODIFY_STAT,
  "stat": CardTypes.Stat.ATK,
  "value": 2 }
```

Supported stats:
- `ATK` — `modify_atk(delta)`
- `ARMOR` — `modify_armor(delta)` (also triggers `armor_changed` signal)
- `HP` / `MAX_HP` — `modify_hp(delta)` (adjusts both max and current)
- `MOVE_RANGE` — `modify_move_range(delta)`
- `ATTACK_RANGE` — `modify_attack_range(delta)`

Negative values = debuffs. An equip can mix both — e.g. a heavy weapon:
```gdscript
{"type": ..., "stat": Stat.ATK,        "value":  3},   # buff
{"type": ..., "stat": Stat.MOVE_RANGE, "value": -1},   # debuff
```

### `APPLY_STATUS` — timed status while equipped
```gdscript
{ "type": CardTypes.EquipModifierType.APPLY_STATUS,
  "status": CardTypes.StatusEffect.HASTED,
  "duration": -1 }                        # -1 = permanent-while-equipped
```

On attach: status applied with the given duration. On detach: status removed (even if duration hadn't expired). Duration = -1 is the standard "while equipped" pattern.

Use this for **temporary/stateful** effects that have a duration concept (BURNING, CHILLED, ARMORED, HASTED, SHIELDED). These show up under the **Statuses** section of the creature's inspection display.

### `REMOVE_STATUS` — one-shot cleanse on equip
```gdscript
{ "type": CardTypes.EquipModifierType.REMOVE_STATUS,
  "status": CardTypes.StatusEffect.CHILLED }
```

One-shot: clears the named status on attach. Does **not** re-apply on detach (the player who equipped it accepts the cleanse as a trade).

## Keywords vs statuses — which pipeline?

This is the most common confusion. Two different pipelines, two different UI buckets:

|  | Pipeline | Persistence | UI bucket |
|---|---|---|---|
| **Keyword** (trait) | `card.keywords = [...]` → granted to creature at attach, revoked at detach | Permanent while equipped | **Persists** |
| **Status** (effect) | `equip_modifiers` with `APPLY_STATUS` → creature.apply_status with duration | Has duration; ticks down OR persists until detach | **Statuses** |

Rule of thumb:
- If it's listed in the `Keyword` enum (FLYING, STEALTH, LIFESTEAL, DOUBLE_ATTACK, etc.) → use `card.keywords`
- If it's listed in the `StatusEffect` enum (BURNING, HASTED, ARMORED, etc.) → use `equip_modifiers APPLY_STATUS`

Never mix — a card that lists `HASTED` in `card.keywords` would try to grant HASTED as a keyword, which is the wrong pipeline.

## Common equip patterns

### Single stat bump (Iron Helm, Runic Axe)
```gdscript
card.equip_modifiers = [{
	"type": CardTypes.EquipModifierType.MODIFY_STAT,
	"stat": CardTypes.Stat.ARMOR,
	"value": 3,
}]
```

### Multi-stat equip
```gdscript
card.equip_modifiers = [
	{"type": CardTypes.EquipModifierType.MODIFY_STAT, "stat": CardTypes.Stat.ATK,  "value": 1},
	{"type": CardTypes.EquipModifierType.MODIFY_STAT, "stat": CardTypes.Stat.HP,   "value": 2},
]
```

### Mixed buff + debuff (heavy weapon)
```gdscript
card.equip_modifiers = [
	{"type": CardTypes.EquipModifierType.MODIFY_STAT, "stat": CardTypes.Stat.ATK,        "value":  3},
	{"type": CardTypes.EquipModifierType.MODIFY_STAT, "stat": CardTypes.Stat.MOVE_RANGE, "value": -1},
]
```

### Keyword grant (Wolfskin Cloak)
```gdscript
card.keywords = [CardTypes.Keyword.SCOUT]   # granted while equipped
card.equip_modifiers = [{
	"type": CardTypes.EquipModifierType.MODIFY_STAT,
	"stat": CardTypes.Stat.ARMOR,
	"value": 2,
}]
```

### Timed status grant ("+armor for 3 turns")
```gdscript
card.equip_modifiers = [{
	"type": CardTypes.EquipModifierType.APPLY_STATUS,
	"status": CardTypes.StatusEffect.ARMORED,
	"duration": CardTypes.Duration.N_TURNS,
	"duration_turns": 3,
}]
```

### Cleansing equip
```gdscript
card.equip_modifiers = [{
	"type": CardTypes.EquipModifierType.REMOVE_STATUS,
	"status": CardTypes.StatusEffect.CHILLED,
}]
```

### Class-restricted equip
```gdscript
card.equip_rules = {
	"allowed_classes": [CardTypes.Class.VIKING],
}
card.equip_modifiers = [...]
```

### Keyword-gated equip (e.g. "bow requires RANGED")
```gdscript
card.equip_rules = {
	"required_keywords": [CardTypes.Keyword.RANGED],
}
```

### Forbidden-keyword equip (e.g. "plate armor — ethereal can't wear")
```gdscript
card.equip_rules = {
	"forbidden_keywords": [CardTypes.Keyword.ETHEREAL],
}
```

### Stat-gated equip ("only heavy hitters")
```gdscript
card.equip_rules = {
	"min_atk": 3,
}
```

## Deck registration

Append the card id to the Equipment section of `EXAMPLE_DECK` in `scripts/cards/deck.gd` (alphabetical within section).

## Verification

1. No `sample images` refs
2. Card id starts with `<class>_` prefix
3. `card_type = EQUIPMENT`
4. `rarity` set
5. `target_rule = ANY_ALLY` (standard)
6. `equip_modifiers` is non-empty OR `keywords` is non-empty (otherwise the card does nothing)
7. If using `APPLY_STATUS` modifiers: duration is set (either a turn count or `-1` for permanent-while-equipped)
8. If using `equip_rules`: referenced enum values exist
9. Deck entry added

## Common pitfalls

- **Putting `keywords` inside `equip_modifiers`**: wrong. `equip_modifiers` is for `MODIFY_STAT` / `APPLY_STATUS` / `REMOVE_STATUS`. Keywords go on `card.keywords`.
- **Using a StatusEffect value in `card.keywords`**: wrong pipeline. Keywords are permanent traits; statuses have duration. Verify your intended effect is in the right enum before picking a pipeline.
- **Forgetting `rarity`**: will crash the CardDatabase loader. Every card must have one.
- **`equip_rules` referring to creature properties that don't exist**: e.g., `"min_atk"` checks the creature's `base_atk` — not `current_atk`, and not any other stat. Only the fields documented above are recognized; unknown keys are silently ignored.
- **Setting `card.spell_range`**: meaningless for equips (same as for spells). Ignore the field.
- **`target_count` on equips**: rarely useful. Default 1 = attach to one creature. >=2 = "attach the same equip data to N different creatures" which only works if the equip's effect is non-exclusive. If unsure, leave at 1.
- **Author wrote the equip's effects as `card.effects = [...]`**: wrong. Equips use `card.equip_modifiers`, not `card.effects`. The latter resolves via `Creature.apply_effect_list` and isn't scoped to attach-time.

## Need a new modifier type?

If your equip's behavior can't be expressed with `MODIFY_STAT` / `APPLY_STATUS` / `REMOVE_STATUS`, open `EquipCard._apply_single_modifier` and add a new match branch — plus a new entry in `CardTypes.EquipModifierType`. Document the dict fields your new modifier reads in both places.

## Reference files

- `assets/data/cards/class_cards/viking/equips/iron_helm.gd` — single ARMOR stat bump
- `assets/data/cards/class_cards/viking/equips/runic_axe.gd` — single ATK stat bump
- `assets/data/cards/class_cards/viking/equips/wolfskin_cloak.gd` — multi-field (stat + keyword grant)
- `scripts/cards/equip_card.gd` — implementation of targeting gates, attach/detach, modifier dispatch
- `scripts/creatures/creature.gd` — `matches_equip_rules`, `can_accept_equip`, `equipped_items`
