## Minotaur — legendary enemy (boss-tier).
## Heavy tank with an earth-shattering ground slam that hits every enemy
## adjacent to its own hex. Slow to move but punishes clumping.
class_name EnemyData_Minotaur
extends RefCounted


static func data() -> EnemyData:
	var enemy := EnemyData.new()

	# Identity
	enemy.id = "enemy_minotaur"
	enemy.display_name = "Minotaur"
	enemy.is_elite = true  # No dedicated "legendary" flag yet — elite is the top tier.

	# Stats — legendary numbers, tuned for boss presence.
	enemy.atk = 5
	enemy.hp = 22
	enemy.armor = 4
	enemy.move_range = 3
	enemy.move_pattern = CardTypes.MovePattern.STANDARD
	enemy.attack_range = 1
	enemy.attack_pattern = CardTypes.AttackPattern.MELEE
	enemy.damage_type = CardTypes.DamageType.PHYSICAL

	# Role & Keywords
	enemy.role = CardTypes.CreatureRole.TANK
	enemy.keywords = [
		CardTypes.Keyword.HEAVY,       # Cannot be pushed/pulled
		CardTypes.Keyword.TAUNT,       # Draws attacks toward itself
		CardTypes.Keyword.BULWARK,     # Takes 1 less damage from all sources
	]

	# Spawning
	enemy.can_spawn_enemies = false
	enemy.creature_scene_path = "res://scenes/creatures/enemy/legendary/minotaur.tscn"
	# Source art faces right — leave sprite_faces_left at its default (false)
	# so EnemyCreature flips him to face the player's side of the board.

	# Heavy attack — Earthquake Slam: slams the ground, damaging every
	# enemy adjacent to the Minotaur's own hex. Multi-phase animation:
	# wind-up → spin loop → impact. The AI will seek a hex that puts as
	# many player creatures as possible within 1 hex before firing.
	enemy.heavy_attack = {
		"id": "minotaur_earthquake_slam",
		"name": "Earthquake Slam",
		"description": "Slams the ground, dealing 6 physical damage to every enemy within 1 hex of the Minotaur.",
		"animation": &"heavy_attack_start",
		"animation_sequence": [
			&"heavy_attack_start",
			&"heavy_attack_loop",
			&"heavy_attack_end",
		],
		"cooldown": 3,
		"range": 0,  # Cast on self; AoE radiates outward.
		"target_rule": CardTypes.TargetRule.SELF,
		"max_targets": -1,
		"effects": [
			{
				"type": CardTypes.EffectType.DEAL_DAMAGE,
				"target": CardTypes.EffectTarget.ALL_ENEMIES_IN_AREA,
				"damage_type": CardTypes.DamageType.PHYSICAL,
				"value": 6,
				"aoe_radius": 1,
				"aoe_center": "caster",  # Centered on the Minotaur itself.
			},
		],
		"self_effects": [],
		"telegraph_turns": 0,
	}

	return enemy
