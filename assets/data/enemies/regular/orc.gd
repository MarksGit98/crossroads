## Orc — enemy striker.
## A common orc grunt. Aggressive but predictable.
class_name EnemyData_Orc
extends RefCounted


static func data() -> EnemyData:
	var enemy := EnemyData.new()

	# Identity
	enemy.id = "enemy_orc"
	enemy.display_name = "Orc"
	enemy.is_elite = false

	# Stats
	enemy.atk = 2
	enemy.hp = 4
	enemy.armor = 0
	enemy.move_range = 2
	enemy.move_pattern = CardTypes.MovePattern.STANDARD
	enemy.attack_range = 1
	enemy.attack_pattern = CardTypes.AttackPattern.MELEE
	enemy.damage_type = CardTypes.DamageType.PHYSICAL

	# Role & Keywords
	enemy.role = CardTypes.CreatureRole.STRIKER
	enemy.keywords = []

	# Spawning
	enemy.can_spawn_enemies = false
	enemy.creature_scene_path = "res://scenes/creatures/enemy/regular/orc.tscn"

	return enemy
