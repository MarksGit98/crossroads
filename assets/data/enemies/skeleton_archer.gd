## Skeleton Archer — enemy artillery.
## Dead eyes. Perfect aim.
class_name EnemyData_SkeletonArcher
extends RefCounted


static func data() -> EnemyData:
	var enemy := EnemyData.new()

	# Identity
	enemy.id = "enemy_skeleton_archer"
	enemy.display_name = "Skeleton Archer"
	enemy.is_elite = false

	# Stats
	enemy.atk = 3
	enemy.hp = 2
	enemy.armor = 0
	enemy.move_range = 1
	enemy.move_pattern = CardTypes.MovePattern.STANDARD
	enemy.attack_range = 3
	enemy.attack_pattern = CardTypes.AttackPattern.SINGLE_TARGET
	enemy.damage_type = CardTypes.DamageType.PHYSICAL

	# Role & Keywords
	enemy.role = CardTypes.CreatureRole.ARTILLERY
	enemy.keywords = [CardTypes.Keyword.RANGED]

	# Spawning
	enemy.can_spawn_enemies = false
	enemy.creature_scene_path = "res://scenes/creatures/enemy/skeleton_archer.tscn"

	return enemy
