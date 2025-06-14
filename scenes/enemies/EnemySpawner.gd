# scenes/enemies/EnemySpawner.gd
extends Node2D
class_name EnemySpawner

signal enemy_spawned(enemy: Enemy)
signal enemy_killed(enemy: Enemy)
signal round_complete()

@export var spawn_radius_min: float = 400.0
@export var spawn_radius_max: float = 800.0
@export var despawn_distance: float = 1200.0

var player: Player
var active_enemies: Array[Enemy] = []
var enemy_scene: PackedScene
var rounds_manager: RoundsManager

# Pool de enemigos para optimización
var enemy_pool: Array[Enemy] = []
var max_pool_size: int = 30

# SISTEMA COD ZOMBIES - Variables de spawn
var enemies_to_spawn: int = 0
var enemies_spawned_this_round: int = 0
var spawn_delay: float = 2.0
var spawn_timer: Timer
var can_spawn: bool = false

# NUEVO: Tipos de enemigos
var enemy_types: Array[String] = ["zombie"]

func _ready():
	if ResourceLoader.exists("res://scenes/enemies/BasicEnemy.tscn"):
		enemy_scene = preload("res://scenes/enemies/BasicEnemy.tscn")
	
	setup_spawn_timer()
	initialize_enemy_pool()

func setup_spawn_timer():
	"""Configurar timer de spawn controlado por rondas"""
	spawn_timer = Timer.new()
	spawn_timer.timeout.connect(_try_spawn_enemy)
	spawn_timer.autostart = false
	add_child(spawn_timer)

func initialize_enemy_pool():
	"""Crear pool inicial de enemigos para optimización"""
	for i in range(max_pool_size):
		var enemy = create_enemy_instance()
		if enemy:
			enemy.visible = false
			enemy.set_physics_process(false)
			enemy.set_process(false)
			enemy_pool.append(enemy)
			add_child(enemy)

func create_enemy_instance() -> Enemy:
	"""Crear una instancia de enemigo"""
	if enemy_scene:
		return enemy_scene.instantiate() as Enemy
	else:
		return create_manual_enemy()

func create_manual_enemy() -> Enemy:
	"""Crear enemigo manualmente sin escena .tscn"""
	var enemy = CharacterBody2D.new()
	enemy.set_script(preload("res://scenes/enemies/BasicEnemy.gd"))
	
	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	enemy.add_child(sprite)
	
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape = RectangleShape2D.new()
	shape.size = Vector2(48, 48)
	collision.shape = shape
	enemy.add_child(collision)
	
	var attack_timer = Timer.new()
	attack_timer.name = "AttackTimer"
	attack_timer.wait_time = 1.5
	attack_timer.one_shot = true
	enemy.add_child(attack_timer)
	
	var health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.position = Vector2(-30, -40)
	health_bar.size = Vector2(60, 8)
	health_bar.show_percentage = false
	enemy.add_child(health_bar)
	
	var detection_area = Area2D.new()
	detection_area.name = "DetectionArea"
	detection_area.collision_layer = 0
	detection_area.collision_mask = 4
	
	var detection_shape = CollisionShape2D.new()
	detection_shape.name = "DetectionShape"
	var detection_rect = RectangleShape2D.new()
	detection_rect.size = Vector2(52, 52)
	detection_shape.shape = detection_rect
	detection_area.add_child(detection_shape)
	enemy.add_child(detection_area)
	
	return enemy as Enemy

func setup(player_ref: Player, rounds_manager_ref: RoundsManager):
	"""Configurar el spawner con referencias necesarias"""
	player = player_ref
	rounds_manager = rounds_manager_ref

func start_round(enemies_count: int, enemy_health: int):
	"""Iniciar una nueva ronda estilo COD"""
	enemies_to_spawn = enemies_count
	enemies_spawned_this_round = 0
	can_spawn = true
	
	# Ajustar velocidad de spawn según la ronda
	var round_num = rounds_manager.get_current_round() if rounds_manager else 1
	spawn_delay = max(0.5, 3.0 - (round_num * 0.1))
	
	# Configurar salud de enemigos para esta ronda
	for enemy in enemy_pool:
		if enemy:
			enemy.max_health = enemy_health
	
	# Iniciar spawn
	_try_spawn_enemy()

func _try_spawn_enemy():
	"""Intentar spawnear un enemigo según las reglas COD"""
	if not can_spawn or not player or not is_instance_valid(player):
		return
	
	# Verificar si ya spawneamos todos los enemigos de la ronda
	if enemies_spawned_this_round >= enemies_to_spawn:
		can_spawn = false
		return
	
	# Verificar límite de enemigos simultáneos
	var max_simultaneous = min(24, enemies_to_spawn)
	if active_enemies.size() >= max_simultaneous:
		# Reintentaré en un momento
		spawn_timer.wait_time = 0.5
		spawn_timer.start()
		return
	
	# Spawnear enemigo
	if spawn_enemy():
		enemies_spawned_this_round += 1
		
		# Programar siguiente spawn si quedan enemigos
		if enemies_spawned_this_round < enemies_to_spawn:
			spawn_timer.wait_time = spawn_delay
			spawn_timer.start()

func spawn_enemy() -> bool:
	"""Spawnear un nuevo enemigo"""
	if not player:
		return false
	
	var spawn_position = get_random_spawn_position()
	if spawn_position == Vector2.ZERO:
		return false
	
	var enemy = get_enemy_from_pool()
	if not enemy:
		return false
	
	# Asignar tipo de enemigo aleatorio
	if enemy_types.size() > 0:
		var random_type = enemy_types[randi() % enemy_types.size()]
		enemy.set_enemy_type(random_type)
	
	# Configurar enemigo con salud de ronda actual
	var round_health = rounds_manager.get_enemy_health_for_current_round() if rounds_manager else 150
	enemy.setup_for_spawn(player, round_health)
	
	enemy.global_position = spawn_position
	enemy.visible = true
	enemy.set_physics_process(true)
	enemy.set_process(true)
	
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)
	
	active_enemies.append(enemy)
	enemy_spawned.emit(enemy)
	
	return true

func get_enemy_from_pool() -> Enemy:
	"""Obtener un enemigo del pool disponible"""
	for enemy in enemy_pool:
		if not enemy.visible and enemy in get_children():
			return enemy
	
	if enemy_pool.size() < max_pool_size:
		var new_enemy = create_enemy_instance()
		if new_enemy:
			enemy_pool.append(new_enemy)
			add_child(new_enemy)
			return new_enemy
	
	return null

func get_random_spawn_position() -> Vector2:
	"""Obtener una posición aleatoria de spawn alrededor del jugador"""
	if not player:
		return Vector2.ZERO
	
	var player_pos = player.global_position
	var attempts = 10
	
	for attempt in range(attempts):
		var angle = randf() * 2 * PI
		var distance = randf_range(spawn_radius_min, spawn_radius_max)
		var spawn_pos = player_pos + Vector2.from_angle(angle) * distance
		
		if is_position_valid(spawn_pos):
			return spawn_pos
	
	return Vector2.ZERO

func is_position_valid(pos: Vector2) -> bool:
	"""Verificar si una posición es válida para spawn"""
	var map_bounds = Rect2(-800, -800, 1600, 1600)
	if not map_bounds.has_point(pos):
		return false
	
	var min_distance_between_enemies = 100.0
	for enemy in active_enemies:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(pos) < min_distance_between_enemies:
			return false
	
	return true

func _on_enemy_died(enemy: Enemy):
	"""Manejar cuando un enemigo muere"""
	if enemy in active_enemies:
		active_enemies.erase(enemy)
	
	enemy_killed.emit(enemy)
	
	# Verificar si la ronda está completa
	check_round_completion()
	
	await get_tree().create_timer(1.0).timeout
	despawn_enemy(enemy)

func check_round_completion():
	"""Verificar si la ronda está completa estilo COD"""
	if enemies_spawned_this_round >= enemies_to_spawn and active_enemies.size() == 0:
		can_spawn = false
		round_complete.emit()

func despawn_enemy(enemy: Enemy):
	"""Despawnear un enemigo específico"""
	enemy.visible = false
	enemy.set_physics_process(false)
	enemy.set_process(false)
	enemy.reset_for_pool()

func despawn_distant_enemies():
	"""Despawnear enemigos que estén muy lejos del jugador"""
	if not player:
		return
	
	var player_pos = player.global_position
	var enemies_to_despawn: Array[Enemy] = []
	
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			var distance = enemy.global_position.distance_to(player_pos)
			if distance > despawn_distance:
				enemies_to_despawn.append(enemy)
	
	for enemy in enemies_to_despawn:
		despawn_enemy(enemy)
		if enemy in active_enemies:
			active_enemies.erase(enemy)

func _physics_process(_delta):
	"""Limpiar enemigos muertos y lejanos"""
	clean_dead_enemies()
	despawn_distant_enemies()

func clean_dead_enemies():
	"""Limpiar enemigos muertos o inválidos de la lista"""
	var new_active_enemies: Array[Enemy] = []
	
	for enemy in active_enemies:
		if is_instance_valid(enemy) and enemy.visible and not enemy.is_dead:
			new_active_enemies.append(enemy)
	
	active_enemies = new_active_enemies

func pause_spawning():
	"""Pausar el spawn de enemigos"""
	can_spawn = false
	if spawn_timer:
		spawn_timer.paused = true

func resume_spawning():
	"""Reanudar el spawn de enemigos"""
	can_spawn = true
	if spawn_timer:
		spawn_timer.paused = false

func clear_all_enemies():
	"""Limpiar todos los enemigos activos"""
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			despawn_enemy(enemy)
	
	active_enemies.clear()
	enemies_spawned_this_round = 0
	can_spawn = false

func get_active_enemy_count() -> int:
	"""Obtener el número de enemigos activos"""
	return active_enemies.size()

func get_enemies_remaining_to_spawn() -> int:
	"""Obtener enemigos restantes por spawnear en la ronda"""
	return max(0, enemies_to_spawn - enemies_spawned_this_round)

func add_enemy_type(new_type: String):
	"""Agregar un nuevo tipo de enemigo"""
	if new_type not in enemy_types:
		enemy_types.append(new_type)

func remove_enemy_type(type_to_remove: String):
	"""Remover un tipo de enemigo"""
	if type_to_remove in enemy_types:
		enemy_types.erase(type_to_remove)

func set_enemy_types(new_types: Array[String]):
	"""Establecer los tipos de enemigos disponibles"""
	enemy_types = new_types

func _exit_tree():
	"""Limpiar al salir"""
	clear_all_enemies()
	
	for enemy in enemy_pool:
		if is_instance_valid(enemy):
			enemy.queue_free()
