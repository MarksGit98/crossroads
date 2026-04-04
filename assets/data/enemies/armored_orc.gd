## Armored Orc — enemy tank.
## Iron plates bolted to green skin. Slow but sturdy.
class_name EnemyData_ArmoredOrc
extends RefCounted


static func data() -> EnemyData:
	var enemy := EnemyData.new()

	# Identity
	enemy.id = "enemy_armored_orc"
	enemy.display_name = "Armored Orc"
	enemy.is_elite = false

	# Stats
	enemy.atk = 2
	enemy.hp = 6
	enemy.armor = 2
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
	enemy.creature_scene_path = "res://scenes/creatures/enemy/armored_orc.tscn"

	return enemy
