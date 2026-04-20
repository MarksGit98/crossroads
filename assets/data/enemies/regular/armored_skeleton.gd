## Armored Skeleton — enemy tank.
## Ancient armor fused to ancient bones.
class_name EnemyData_ArmoredSkeleton
extends RefCounted


static func data() -> EnemyData:
	var enemy := EnemyData.new()

	# Identity
	enemy.id = "enemy_armored_skeleton"
	enemy.display_name = "Armored Skeleton"
	enemy.is_elite = false

	# Stats
	enemy.atk = 2
	enemy.hp = 5
	enemy.armor = 1
	enemy.move_range = 1
	enemy.move_pattern = CardTypes.MovePattern.STANDARD
	enemy.attack_range = 1
	enemy.attack_pattern = CardTypes.AttackPattern.MELEE
	enemy.damage_type = CardTypes.DamageType.PHYSICAL

	# Role & Keywords
	enemy.role = CardTypes.CreatureRole.TANK
	enemy.keywords = [CardTypes.Keyword.HEAVY]

	# Spawning
	enemy.can_spawn_enemies = false
	enemy.creature_scene_path = "res://scenes/creatures/enemy/regular/armored_skeleton.tscn"

	return enemy
