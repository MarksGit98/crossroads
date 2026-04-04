## Greatsword Skeleton — enemy elite striker.
## A towering undead wielding a blade as tall as a man.
class_name EnemyData_GreatswordSkeleton
extends RefCounted


static func data() -> EnemyData:
	var enemy := EnemyData.new()

	# Identity
	enemy.id = "enemy_greatsword_skeleton"
	enemy.display_name = "Greatsword Skeleton"
	enemy.is_elite = true

	# Stats
	enemy.atk = 5
	enemy.hp = 8
	enemy.armor = 1
	enemy.move_range = 1
	enemy.move_pattern = CardTypes.MovePattern.STANDARD
	enemy.attack_range = 1
	enemy.attack_pattern = CardTypes.AttackPattern.CLEAVE
	enemy.damage_type = CardTypes.DamageType.PHYSICAL

	# Role & Keywords
	enemy.role = CardTypes.CreatureRole.STRIKER
	enemy.keywords = [CardTypes.Keyword.HEAVY, CardTypes.Keyword.REACH]

	# Spawning
	enemy.can_spawn_enemies = false
	enemy.creature_scene_path = "res://scenes/creatures/enemy/greatsword_skeleton.tscn"

	return enemy
