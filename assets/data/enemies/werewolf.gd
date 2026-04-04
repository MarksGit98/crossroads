## Werewolf — enemy assassin.
## Moves in a blur of claws and fury.
class_name EnemyData_Werewolf
extends RefCounted


static func data() -> EnemyData:
	var enemy := EnemyData.new()

	# Identity
	enemy.id = "enemy_werewolf"
	enemy.display_name = "Werewolf"
	enemy.is_elite = false

	# Stats
	enemy.atk = 4
	enemy.hp = 5
	enemy.armor = 0
	enemy.move_range = 3
	enemy.move_pattern = CardTypes.MovePattern.STANDARD
	enemy.attack_range = 1
	enemy.attack_pattern = CardTypes.AttackPattern.MELEE
	enemy.damage_type = CardTypes.DamageType.PHYSICAL

	# Role & Keywords
	enemy.role = CardTypes.CreatureRole.ASSASSIN
	enemy.keywords = [CardTypes.Keyword.SWIFT, CardTypes.Keyword.FRENZY]

	# Spawning
	enemy.can_spawn_enemies = false
	enemy.creature_scene_path = "res://scenes/creatures/enemy/werewolf.tscn"

	return enemy
