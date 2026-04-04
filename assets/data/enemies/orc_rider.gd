## Orc Rider — enemy striker.
## Mounted and dangerous. Covers ground fast.
class_name EnemyData_OrcRider
extends RefCounted


static func data() -> EnemyData:
	var enemy := EnemyData.new()

	# Identity
	enemy.id = "enemy_orc_rider"
	enemy.display_name = "Orc Rider"
	enemy.is_elite = false

	# Stats
	enemy.atk = 3
	enemy.hp = 5
	enemy.armor = 1
	enemy.move_range = 3
	enemy.move_pattern = CardTypes.MovePattern.STANDARD
	enemy.attack_range = 1
	enemy.attack_pattern = CardTypes.AttackPattern.MELEE
	enemy.damage_type = CardTypes.DamageType.PHYSICAL

	# Role & Keywords
	enemy.role = CardTypes.CreatureRole.STRIKER
	enemy.keywords = [CardTypes.Keyword.SWIFT]

	# Spawning
	enemy.can_spawn_enemies = false
	enemy.creature_scene_path = "res://scenes/creatures/enemy/orc_rider.tscn"

	return enemy
