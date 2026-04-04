## Elite Orc — enemy elite tank.
## Warchief of the orc warband. Commands lesser orcs.
class_name EnemyData_EliteOrc
extends RefCounted


static func data() -> EnemyData:
	var enemy := EnemyData.new()

	# Identity
	enemy.id = "enemy_elite_orc"
	enemy.display_name = "Elite Orc"
	enemy.is_elite = true

	# Stats
	enemy.atk = 4
	enemy.hp = 10
	enemy.armor = 3
	enemy.move_range = 1
	enemy.move_pattern = CardTypes.MovePattern.STANDARD
	enemy.attack_range = 1
	enemy.attack_pattern = CardTypes.AttackPattern.MELEE
	enemy.damage_type = CardTypes.DamageType.PHYSICAL

	# Role & Keywords
	enemy.role = CardTypes.CreatureRole.TANK
	enemy.keywords = [CardTypes.Keyword.TAUNT, CardTypes.Keyword.HEAVY, CardTypes.Keyword.BULWARK]

	# Spawning
	enemy.can_spawn_enemies = true
	enemy.creature_scene_path = "res://scenes/creatures/enemy/elite_orc.tscn"

	return enemy
