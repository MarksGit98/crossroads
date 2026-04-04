## Skeleton — enemy striker.
## Bones held together by dark magic. Fragile but relentless.
class_name EnemyData_Skeleton
extends RefCounted


static func data() -> EnemyData:
	var enemy := EnemyData.new()

	# Identity
	enemy.id = "enemy_skeleton"
	enemy.display_name = "Skeleton"
	enemy.is_elite = false

	# Stats
	enemy.atk = 2
	enemy.hp = 3
	enemy.armor = 0
	enemy.move_range = 1
	enemy.move_pattern = CardTypes.MovePattern.STANDARD
	enemy.attack_range = 1
	enemy.attack_pattern = CardTypes.AttackPattern.MELEE
	enemy.damage_type = CardTypes.DamageType.PHYSICAL

	# Role & Keywords
	enemy.role = CardTypes.CreatureRole.STRIKER
	enemy.keywords = []

	# Spawning
	enemy.can_spawn_enemies = false
	enemy.creature_scene_path = "res://scenes/creatures/enemy/skeleton.tscn"

	return enemy
