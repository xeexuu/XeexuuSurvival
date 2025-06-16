# scenes/enemies/EnemyFactory.gd - FACTORY PARA CREAR ENEMIGOS
extends Node
class_name EnemyFactory

# Tipos de enemigos disponibles
enum EnemyType {
	ZOMBIE_BASIC,
	ZOMBIE_DOG,
	ZOMBIE_CRAWLER
}

# Probabilidades por ronda
var spawn_probabilities: Dictionary = {
	1: {"zombie_basic": 1.0, "zombie_dog": 0.0, "zombie_crawler": 0.0},
	2: {"zombie_basic": 0.9, "zombie_dog": 0.1, "zombie_crawler": 0.0},
	3: {"zombie_basic": 0.8, "zombie_dog": 0.15, "zombie_crawler": 0.05},
	4: {"zombie_basic": 0.7, "zombie_dog": 0.2, "zombie_crawler": 0.1},
	5: {"zombie_basic": 0.6, "zombie_dog": 0.25, "zombie_crawler": 0.15},
	6: {"zombie_basic": 0.5, "zombie_dog": 0.3, "zombie_crawler": 0.2},
	7: {"zombie_basic": 0.4, "zombie_dog": 0.35, "zombie_crawler": 0.25},
	8: {"zombie_basic": 0.35, "zombie_dog": 0.4, "zombie_crawler": 0.25},
	9: {"zombie_basic": 0.3, "zombie_dog": 0.45, "zombie_crawler": 0.25},
	10: {"zombie_basic": 0.25, "zombie_dog": 0.5, "zombie_crawler": 0.25}
}

static func create_enemy(enemy_type: String) -> BaseEnemy:
	"""Crear enemigo según el tipo"""
	match enemy_type:
		"zombie_basic":
			return create_zombie_basic()
		"zombie_dog":
			return create_zombie_dog()
		"zombie_crawler":
			return create_zombie_crawler()
		_:
			return create_zombie_basic()  # Fallback

static func create_zombie_basic() -> BaseEnemy:
	"""Crear zombie básico"""
	var zombie = CharacterBody2D.new()
	zombie.set_script(preload("res://scenes/enemies/ZombieBasic.gd"))
	
	# Sprite
	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	zombie.add_child(sprite)
	
	# Colisión
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape = RectangleShape2D.new()
	shape.size = Vector2(48, 48)
	collision.shape = shape
	zombie.add_child(collision)
	
	# Timer de ataque
	var attack_timer = Timer.new()
	attack_timer.name = "AttackTimer"
	attack_timer.wait_time = 2.0
	attack_timer.one_shot = true
	zombie.add_child(attack_timer)
	
	# Barra de vida
	var health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.position = Vector2(-30, -50)
	health_bar.size = Vector2(60, 8)
	health_bar.show_percentage = false
	zombie.add_child(health_bar)
	
	return zombie as BaseEnemy

static func create_zombie_dog() -> BaseEnemy:
	"""Crear perro zombie"""
	var dog = CharacterBody2D.new()
	dog.set_script(preload("res://scenes/enemies/ZombieDog.gd"))
	
	# Sprite
	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	dog.add_child(sprite)
	
	# Colisión más pequeña
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape = RectangleShape2D.new()
	shape.size = Vector2(32, 20)
	collision.shape = shape
	dog.add_child(collision)
	
	# Timer de ataque
	var attack_timer = Timer.new()
	attack_timer.name = "AttackTimer"
	attack_timer.wait_time = 0.8
	attack_timer.one_shot = true
	dog.add_child(attack_timer)
	
	# Barra de vida
	var health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.position = Vector2(-20, -35)
	health_bar.size = Vector2(40, 6)
	health_bar.show_percentage = false
	dog.add_child(health_bar)
	
	return dog as BaseEnemy

static func create_zombie_crawler() -> BaseEnemy:
	"""Crear crawler (cabezón)"""
	var crawler = CharacterBody2D.new()
	crawler.set_script(preload("res://scenes/enemies/ZombieCrawler.gd"))
	
	# Sprite
	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	crawler.add_child(sprite)
	
	# Colisión muy pequeña
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape = RectangleShape2D.new()
	shape.size = Vector2(24, 16)
	collision.shape = shape
	crawler.add_child(collision)
	
	# Timer de ataque
	var attack_timer = Timer.new()
	attack_timer.name = "AttackTimer"
	attack_timer.wait_time = 1.2
	attack_timer.one_shot = true
	crawler.add_child(attack_timer)
	
	# Barra de vida
	var health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.position = Vector2(-15, -25)
	health_bar.size = Vector2(30, 4)
	health_bar.show_percentage = false
	crawler.add_child(health_bar)
	
	return crawler as BaseEnemy

static func get_random_enemy_type(round: int) -> String:
	"""Obtener tipo aleatorio de enemigo según la ronda"""
	var factory = EnemyFactory.new()
	
	# Obtener probabilidades para la ronda
	var probabilities: Dictionary
	if round <= 10:
		probabilities = factory.spawn_probabilities[round]
	else:
		# Para rondas altas, usar probabilidades de ronda 10
		probabilities = factory.spawn_probabilities[10]
	
	# Selección aleatoria basada en probabilidades
	var random_value = randf()
	var cumulative = 0.0
	
	for enemy_type in probabilities.keys():
		cumulative += probabilities[enemy_type]
		if random_value <= cumulative:
			return enemy_type
	
	# Fallback
	return "zombie_basic"

static func get_enemy_types_for_round(round: int) -> Array[String]:
	"""Obtener todos los tipos disponibles para una ronda"""
	var factory = EnemyFactory.new()
	var available_types: Array[String] = []
	
	var probabilities: Dictionary
	if round <= 10:
		probabilities = factory.spawn_probabilities[round]
	else:
		probabilities = factory.spawn_probabilities[10]
	
	for enemy_type in probabilities.keys():
		if probabilities[enemy_type] > 0.0:
			available_types.append(enemy_type)
	
	return available_types

static func get_spawn_probability(round: int, enemy_type: String) -> float:
	"""Obtener probabilidad de spawn para un tipo específico"""
	var factory = EnemyFactory.new()
	
	var probabilities: Dictionary
	if round <= 10:
		probabilities = factory.spawn_probabilities[round]
	else:
		probabilities = factory.spawn_probabilities[10]
	
	return probabilities.get(enemy_type, 0.0)

static func create_special_wave(round: int) -> Array[String]:
	"""Crear oleada especial para ciertas rondas"""
	var wave: Array[String] = []
	
	match round:
		5:
			# Ronda 5: Oleada de perros
			for i in range(8):
				wave.append("zombie_dog")
		
		8:
			# Ronda 8: Oleada de crawlers
			for i in range(12):
				wave.append("zombie_crawler")
		
		10:
			# Ronda 10: Oleada mixta especial
			for i in range(3):
				wave.append("zombie_basic")
			for i in range(5):
				wave.append("zombie_dog")
			for i in range(7):
				wave.append("zombie_crawler")
		
		15:
			# Ronda 15: Boss wave - muchos de cada tipo
			for i in range(5):
				wave.append("zombie_basic")
			for i in range(8):
				wave.append("zombie_dog")
			for i in range(10):
				wave.append("zombie_crawler")
	
	return wave

static func is_special_round(round: int) -> bool:
	"""Verificar si es una ronda especial"""
	return round in [5, 8, 10, 15, 20, 25, 30]

static func get_round_description(round: int) -> String:
	"""Obtener descripción de la ronda"""
	match round:
		1:
			return "Los muertos despiertan..."
		2:
			return "La horda crece..."
		3:
			return "Algo se mueve en las sombras..."
		5:
			return "¡OLEADA DE PERROS ZOMBIES!"
		8:
			return "¡INVASIÓN DE CRAWLERS!"
		10:
			return "¡OLEADA ESPECIAL MIXTA!"
		15:
			return "¡RONDA BOSS!"
		_:
			if round % 5 == 0:
				return "¡RONDA ESPECIAL!"
			else:
				return "La pesadilla continúa..."
