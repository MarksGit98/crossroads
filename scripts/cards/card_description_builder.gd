## Builds human-readable description text for cards from their effect/passive data.
## Used by SpellCard and EquipCard to populate the card's DescriptionLabel
## with all relevant gameplay text (effects, keywords, flavor).
class_name CardDescriptionBuilder
extends RefCounted


# =============================================================================
# Public API
# =============================================================================

## Build the full description text for a spell card.
## Format: effect lines, range, keywords, flavor.
static func build_spell_description(data: CardData) -> String:
	var parts: PackedStringArray = []

	# Effect lines.
	for effect: Dictionary in data.effects:
		var line: String = format_effect(effect)
		if line != "":
			parts.append(line)

	# Range info, if non-zero.
	if data.spell_range > 0:
		parts.append("Range: %d" % data.spell_range)

	# Keywords list.
	var keyword_text: String = format_keywords(data.keywords)
	if keyword_text != "":
		parts.append(keyword_text)

	# Flavor at the bottom (in quotes).
	if data.flavor != "":
		parts.append("\"%s\"" % data.flavor)

	return "\n".join(parts)


## Build the full description text for an equipment card.
## Format: stat modifier lines, granted keywords, flavor.
static func build_equip_description(data: CardData) -> String:
	var parts: PackedStringArray = []

	# Passive lines (stat modifiers from passives).
	for passive: Dictionary in data.passives:
		var line: String = format_passive(passive)
		if line != "":
			parts.append(line)

	# Granted keywords.
	var keyword_text: String = format_keywords(data.keywords, "Grants")
	if keyword_text != "":
		parts.append(keyword_text)

	# Flavor at the bottom (in quotes).
	if data.flavor != "":
		parts.append("\"%s\"" % data.flavor)

	return "\n".join(parts)


# =============================================================================
# Effect Formatting
# =============================================================================

## Convert a single effect dictionary into a readable line.
static func format_effect(effect: Dictionary) -> String:
	var effect_type: int = effect.get("type", -1)
	match effect_type:
		CardTypes.EffectType.DEAL_DAMAGE:
			var value: int = effect.get("value", 0)
			var dmg_type: int = effect.get("damage_type", CardTypes.DamageType.PHYSICAL)
			var dmg_name: String = CardTypes.DamageType.keys()[dmg_type].capitalize()
			var target: String = format_effect_target(effect.get("target", -1))
			return "Deal %d %s damage%s." % [value, dmg_name, target]

		CardTypes.EffectType.HEAL:
			var value: int = effect.get("value", 0)
			var target: String = format_effect_target(effect.get("target", -1))
			return "Restore %d HP%s." % [value, target]

		CardTypes.EffectType.MODIFY_STAT:
			var stat: int = effect.get("stat", -1)
			var value: int = effect.get("value", 0)
			var sign: String = "+" if value >= 0 else ""
			var stat_name: String = _stat_name(stat)
			var target: String = format_effect_target(effect.get("target", -1))
			var duration: String = format_duration(effect)
			return "%s%d %s%s%s." % [sign, value, stat_name, target, duration]

		CardTypes.EffectType.APPLY_STATUS:
			var status: int = effect.get("status", -1)
			var status_name: String = CardTypes.StatusEffect.keys()[status].capitalize() if status >= 0 else "?"
			var target: String = format_effect_target(effect.get("target", -1))
			var duration: String = format_duration(effect)
			return "Apply %s%s%s." % [status_name, target, duration]

		CardTypes.EffectType.REMOVE_STATUS:
			var status: int = effect.get("status", -1)
			var status_name: String = CardTypes.StatusEffect.keys()[status].capitalize() if status >= 0 else "?"
			return "Remove %s." % status_name

		CardTypes.EffectType.CLEANSE:
			return "Cleanse all negative status effects."

		CardTypes.EffectType.PURGE:
			return "Purge all positive status effects."

		CardTypes.EffectType.PUSH:
			return "Push %d hexes away." % effect.get("value", 1)

		CardTypes.EffectType.PULL:
			return "Pull %d hexes closer." % effect.get("value", 1)

		CardTypes.EffectType.SHIELD:
			return "Shield for %d damage." % effect.get("value", 0)

		CardTypes.EffectType.STUN:
			return "Stun the target."

		CardTypes.EffectType.SILENCE:
			return "Silence the target."

		CardTypes.EffectType.DRAW_CARD:
			return "Draw %d card(s)." % effect.get("value", 1)

		CardTypes.EffectType.GAIN_MANA:
			return "Gain %d mana." % effect.get("value", 1)

		CardTypes.EffectType.CREATE_TERRAIN:
			var terrain: String = str(effect.get("terrain", "?")).capitalize()
			var duration: String = format_duration(effect)
			return "Create %s terrain%s." % [terrain, duration]

		CardTypes.EffectType.MARK_SPAWN:
			return "Mark target hex as a valid summon location."

		CardTypes.EffectType.DESTROY:
			return "Destroy the target."

		CardTypes.EffectType.EXECUTE:
			return "Execute targets below %d%% HP." % effect.get("value", 0)

		_:
			# Unknown effect type — return empty so it's skipped.
			return ""


## Convert a passive dictionary into a readable line (for equipment cards).
static func format_passive(passive: Dictionary) -> String:
	var ptype: int = passive.get("type", -1)

	match ptype:
		CardTypes.PassiveType.STAT_AURA:
			# Direct stat/value at top level (e.g. Runic Axe, Iron Helm).
			var stat: int = passive.get("stat", -1)
			var value: int = passive.get("value", 0)
			if stat >= 0:
				var sign: String = "+" if value >= 0 else ""
				return "%s%d %s while equipped." % [sign, value, _stat_name(stat)]

		CardTypes.PassiveType.MODIFY_STATS:
			# Nested effects format (e.g. Wolfskin Cloak).
			var lines: PackedStringArray = []
			for effect: Dictionary in passive.get("effects", []):
				if effect.get("type", -1) == CardTypes.EffectType.MODIFY_STAT:
					var stat: int = effect.get("stat", -1)
					var value: int = effect.get("value", 0)
					if stat >= 0:
						var sign: String = "+" if value >= 0 else ""
						lines.append("%s%d %s while equipped." % [sign, value, _stat_name(stat)])
			return "\n".join(lines)

	# Fallback: use the passive's name field if present.
	var pname: String = passive.get("name", "")
	if pname != "":
		return pname
	return ""


# =============================================================================
# Helpers
# =============================================================================

## Build a "Keywords: A, B, C" string from a keywords array.
## prefix lets equipment use "Grants:" instead of "Keywords:".
static func format_keywords(keywords: Array, prefix: String = "Keywords") -> String:
	if keywords.is_empty():
		return ""
	var names: PackedStringArray = []
	for kw: int in keywords:
		names.append(CardTypes.Keyword.keys()[kw].capitalize())
	return "%s: %s" % [prefix, ", ".join(names)]


## Convert an EffectTarget enum to a parenthetical phrase.
static func format_effect_target(target: int) -> String:
	match target:
		CardTypes.EffectTarget.ALL_IN_AREA:
			return " to all in area"
		CardTypes.EffectTarget.ALL_ENEMIES_IN_AREA:
			return " to all enemies in area"
		CardTypes.EffectTarget.ALL_ALLIES_IN_AREA:
			return " to all allies in area"
		CardTypes.EffectTarget.CASTER:
			return " to self"
		_:
			return ""


## Format a duration suffix (e.g. " for 2 turns", " until end of turn").
static func format_duration(effect: Dictionary) -> String:
	var duration: int = effect.get("duration", -1)
	match duration:
		CardTypes.Duration.UNTIL_END_OF_TURN:
			return " until end of turn"
		CardTypes.Duration.N_TURNS:
			var turns: int = effect.get("duration_turns", 1)
			return " for %d turn%s" % [turns, "s" if turns != 1 else ""]
		CardTypes.Duration.PERMANENT:
			return " permanently"
		CardTypes.Duration.WHILE_ALIVE:
			return ""  # Implicit — already covered by "while equipped" etc.
		_:
			return ""


## Convert a Stat enum to a display name.
static func _stat_name(stat: int) -> String:
	match stat:
		CardTypes.Stat.ATK: return "ATK"
		CardTypes.Stat.HP: return "HP"
		CardTypes.Stat.MAX_HP: return "Max HP"
		CardTypes.Stat.MOVE_RANGE: return "Move"
		CardTypes.Stat.ATTACK_RANGE: return "Range"
		CardTypes.Stat.ARMOR: return "Armor"
		CardTypes.Stat.SPELL_POWER: return "Spell Power"
		_: return "?"
