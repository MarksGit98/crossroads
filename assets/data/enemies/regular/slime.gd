## Slime — enemy tank.
## A gelatinous blob that absorbs punishment.
class_name EnemyData_Slime
extends RefCounted


static func data() -> EnemyData:
	var enemy := EnemyData.new()

	# Identity
	enemy.id = "enemy_slime"
	enemy.display_name = "Slime"
	enemy.is_elite = false

	# Stats
	enemy.atk = 1
	enemy.hp = 6
	enemy.armor = 0
	enemy.move_range = 1
	enemy.move_pattern = CardTypes.MovePattern.STANDARD
	enemy.attack_range = 1
	enemy.attack_pattern = CardTypes.AttackPattern.MELEE
	enemy.damage_type = CardTypes.DamageType.PHYSICAL

	# Role & Keywords
	enemy.role = CardTypes.CreatureRole.TANK
	enemy.keywords = [CardTypes.Keyword.REGENERATE]

	# Spawning
	enemy.can_spawn_enemies = false
	enemy.creature_scene_path = "res://scenes/creatures/enemy/regular/slime.tscn"

	return enemy
