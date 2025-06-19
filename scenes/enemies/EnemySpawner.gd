# scenes/enemies/EnemySpawner.gd - SPAWN FUERA DE PAREDES + GARANTÍAS ABSOLUTAS + ROOMS
extends Node2D
class_name EnemySpawner

signal enemy_spawned(enemy: Enemy)
signal enemy_killed(enemy: Enemy)
signal round_complete()

@export var spawn_radius_min: float = 600.0  
@export var spawn_radius_max: float = 1000.0
@export var despawn_distance: float = 1500.0
@export var min_spawn_distance: float = 500.0  

var player: Player
var active_enemies: Array[Enemy] = []
var rounds_manager: RoundsManager
var wall_system: WallSystem

# Pool simplificado
var enemy_pool: Array[Enemy] = []
var max_pool_size: int = 30

# Variables de spawn
var enemies_to_spawn: int = 0
var enemies_spawned_this_round: int = 0
var spawn_delay: float = 2.0
var spawn_timer: Timer
var can_spawn: bool = false

# Control de tipos por ronda
var current_round_number: int = 1

# SISTEMA DE GARANTÍAS ABSOLUTO
var guaranteed_spawns_queue: Array[String] = []
var guaranteed_spawns_completed: Dictionary = {}

# ÁREAS DE SPAWN FUERA DE HABITACIONES
var spawn_areas: Array[Rect2] = []

func _ready():
	setup_spawn_timer()
	initialize_enemy_pool()
	get_wall_system_reference()
	setup_spawn_areas()

func setup_spawn_areas():
	"""Configurar áreas de spawn fuera de las habitaciones"""
	spawn_areas = [
		# Área norte (fuera de habitación norte)
		Rect2(-400, -800, 800, 200),
		# Área sur (fuera de habitación sur)
		Rect2(-400, 600, 800, 200),
		# Área este (fuera de habitación este)
		Rect2(700, -400, 200, 800),
		# Área oeste (fuera de habitación oeste)
		Rect2(-900, -400, 200, 800),
		# Esquinas lejanas
		Rect2(-900, -800, 200, 200),  # Noroeste
		Rect2(700, -800, 200, 200),   # Noreste
		Rect2(-900, 600, 200, 200),   # Suroeste
		Rect2(700, 600, 200, 200)     # Sureste
	]

func get_wall_system_reference():
	"""Obtener referencia al sistema de paredes"""
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_node("WallSystem"):
		wall_system = game_manager.get_node("WallSystem")
		print("✅ WallSystem encontrado para spawning")
	else:
		print("⚠️ WallSystem no encontrado")

func setup_spawn_timer():
	"""Configurar timer de spawn"""
	spawn_timer = Timer.new()
	spawn_timer.timeout.connect(_try_spawn_enemy)
	spawn_timer.autostart = false
	add_child(spawn_timer)

func initialize_enemy_pool():
	"""Crear pool de enemigos unificados"""
	for i in range(max_pool_size):
		var enemy = create_unified_enemy()
		if enemy:
			enemy.visible = false
			enemy.set_physics_process(false)
			enemy.set_process(false)
			enemy.global_position = Vector2(10000 + i * 100, 10000)
			
			enemy.add_to_group("enemies")
			
			enemy_pool.append(enemy)
			add_child(enemy)

func create_unified_enemy() -> Enemy:
	"""Crear enemigo usando la escena unificada"""
	var enemy_scene = preload("res://scenes/enemies/BasicEnemy.tscn")
	var enemy = enemy_scene.instantiate() as Enemy
	
	if not enemy:
		enemy = Enemy.new()
		enemy.name = "Enemy"
		
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
		attack_timer.wait_time = 2.0
		attack_timer.one_shot = true
		enemy.add_child(attack_timer)
		
		var health_bar = ProgressBar.new()
		health_bar.name = "HealthBar"
		health_bar.position = Vector2(-30, -50)
		health_bar.size = Vector2(60, 8)
		health_bar.show_percentage = false
		enemy.add_child(health_bar)
	
	return enemy

func setup(player_ref: Player, rounds_manager_ref: RoundsManager):
	"""Configurar spawner"""
	player = player_ref
	rounds_manager = rounds_manager_ref

func start_round(enemies_count: int, _enemy_health: int):
	"""Iniciar nueva ronda CON GARANTÍAS ABSOLUTAS"""
	current_round_number = rounds_manager.get_current_round() if rounds_manager else 1
	enemies_to_spawn = enemies_count
	enemies_spawned_this_round = 0
	can_spawn = true
	
	# SISTEMA DE GARANTÍAS ABSOLUTO - 1 DE CADA TIPO DISPONIBLE
	setup_absolute_guaranteed_spawns()
	
	spawn_delay = max(0.5, 2.5 - (current_round_number * 0.1))
	
	_try_spawn_enemy()

func setup_absolute_guaranteed_spawns():
	"""SISTEMA DE GARANTÍAS ABSOLUTO - SIEMPRE 1 DE CADA TIPO"""
	guaranteed_spawns_queue.clear()
	guaranteed_spawns_completed.clear()
	
	# TODOS LOS TIPOS DISPONIBLES SEGÚN LA RONDA
	var available_types = get_available_enemy_types_for_round(current_round_number)
	
	# GARANTIZAR 1 DE CADA TIPO DISPONIBLE
	for enemy_type in available_types:
		guaranteed_spawns_queue.append(enemy_type)
	
	# MEZCLAR PARA ORDEN ALEATORIO
	guaranteed_spawns_queue.shuffle()
	
	print("🎯 Garantías para ronda ", current_round_number, ": ", guaranteed_spawns_queue)

func get_available_enemy_types_for_round(round_num: int) -> Array[String]:
	"""Obtener tipos de enemigos disponibles para la ronda"""
	var types: Array[String] = []
	
	# BÁSICO SIEMPRE DISPONIBLE
	types.append("zombie_basic")
	
	# PERRO DESDE RONDA 1
	types.append("zombie_dog")
	
	# CRAWLER DESDE RONDA 1
	types.append("zombie_crawler")
	
	# RUNNER DESDE RONDA 4
	if round_num >= 4:
		types.append("zombie_runner")
	
	# CHARGER DESDE RONDA 8
	if round_num >= 8:
		types.append("zombie_charger")
	
	return types

func _try_spawn_enemy():
	"""Intentar spawnear enemigo"""
	if not can_spawn or not player or not is_instance_valid(player):
		return
	
	if enemies_spawned_this_round >= enemies_to_spawn:
		can_spawn = false
		return
	
	var max_simultaneous = min(25, enemies_to_spawn)
	if active_enemies.size() >= max_simultaneous:
		spawn_timer.wait_time = 0.5
		spawn_timer.start()
		return
	
	if spawn_enemy():
		enemies_spawned_this_round += 1
		
		if enemies_spawned_this_round < enemies_to_spawn:
			spawn_timer.wait_time = spawn_delay
			spawn_timer.start()

func spawn_enemy() -> bool:
	"""Spawnear nuevo enemigo CON SISTEMA ABSOLUTO DE GARANTÍAS"""
	if not player:
		return false
	
	var spawn_position = get_safe_spawn_position_in_areas()
	if spawn_position == Vector2.ZERO:
		return false
	
	var enemy = get_enemy_from_pool()
	if not enemy:
		return false
	
	# DETERMINAR TIPO CON GARANTÍAS ABSOLUTAS
	var enemy_type = determine_enemy_type_absolute_guarantees()
	enemy.enemy_type = enemy_type
	
	# CONFIGURAR ESTADÍSTICAS ESPECÍFICAS POR TIPO
	var round_health = rounds_manager.get_enemy_health_for_current_round() if rounds_manager else 150
	configure_enemy_stats_by_type(enemy, enemy_type, round_health)
	
	# CONFIGURAR PARA SPAWN
	enemy.setup_for_spawn(player, round_health)
	
	# ESTABLECER REFERENCIA AL WALL SYSTEM
	if wall_system:
		enemy.set_wall_system(wall_system)
	
	# POSICIONAR Y ACTIVAR
	enemy.global_position = spawn_position
	enemy.visible = true
	enemy.set_physics_process(true)
	enemy.set_process(true)
	
	if enemy.sprite:
		enemy.sprite.visible = true
	
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)
	
	active_enemies.append(enemy)
	enemy_spawned.emit(enemy)
	
	print("🧟 Spawneado: ", enemy_type, " - Cola restante: ", guaranteed_spawns_queue.size())
	
	return true

func determine_enemy_type_absolute_guarantees() -> String:
	"""SISTEMA ABSOLUTO DE GARANTÍAS - PRIMERO COLA, LUEGO ALEATORIO"""
	
	# PRIORIDAD 1: TIPOS GARANTIZADOS PENDIENTES
	if not guaranteed_spawns_queue.is_empty():
		var guaranteed_type = guaranteed_spawns_queue.pop_front()
		guaranteed_spawns_completed[guaranteed_type] = true
		print("✅ Spawneando tipo garantizado: ", guaranteed_type)
		return guaranteed_type
	
	# PRIORIDAD 2: TIPOS ALEATORIOS DESPUÉS DE GARANTÍAS
	return determine_enemy_type_random_after_guarantees()

func determine_enemy_type_random_after_guarantees() -> String:
	"""Determinar tipo aleatorio después de garantías"""
	var available_types = get_available_enemy_types_for_round(current_round_number)
	
	# PROBABILIDADES BALANCEADAS
	var rand_val = randf()
	
	match current_round_number:
		1, 2, 3:
			if rand_val < 0.6:
				return "zombie_basic"
			elif rand_val < 0.8:
				return "zombie_dog"
			else:
				return "zombie_crawler"
		4, 5, 6, 7:
			if rand_val < 0.5:
				return "zombie_basic"
			elif rand_val < 0.65:
				return "zombie_dog"
			elif rand_val < 0.8:
				return "zombie_crawler"
			else:
				return "zombie_runner"
		_:  # 8+
			if rand_val < 0.4:
				return "zombie_basic"
			elif rand_val < 0.55:
				return "zombie_dog"
			elif rand_val < 0.7:
				return "zombie_crawler"
			elif rand_val < 0.85:
				return "zombie_runner"
			else:
				return "zombie_charger"

func get_safe_spawn_position_in_areas() -> Vector2:
	"""Obtener posición SEGURA en áreas de spawn predefinidas"""
	if not player:
		return Vector2.ZERO
	
	var player_pos = player.global_position
	var attempts = 150  # Más intentos
	
	for attempt in range(attempts):
		# SELECCIONAR ÁREA DE SPAWN ALEATORIA
		var spawn_area = spawn_areas[randi() % spawn_areas.size()]
		
		# POSICIÓN ALEATORIA DENTRO DEL ÁREA
		var spawn_pos = Vector2(
			randf_range(spawn_area.position.x, spawn_area.position.x + spawn_area.size.x),
			randf_range(spawn_area.position.y, spawn_area.position.y + spawn_area.size.y)
		)
		
		# VERIFICAR DISTANCIA AL JUGADOR
		var distance_to_player = spawn_pos.distance_to(player_pos)
		if distance_to_player < min_spawn_distance:
			continue
		
		# VERIFICAR QUE NO ESTÉ EN PAREDES
		if is_position_in_walls(spawn_pos):
			continue
		
		# VERIFICAR DISTANCIA A OTROS ENEMIGOS
		var too_close_to_enemy = false
		for enemy in active_enemies:
			if is_instance_valid(enemy) and enemy.global_position.distance_to(spawn_pos) < 100.0:
				too_close_to_enemy = true
				break
		
		if too_close_to_enemy:
			continue
		
		return spawn_pos
	
	# POSICIÓN DE EMERGENCIA EN LA PRIMERA ÁREA DISPONIBLE
	var emergency_area = spawn_areas[0]
	return Vector2(
		emergency_area.position.x + emergency_area.size.x * 0.5,
		emergency_area.position.y + emergency_area.size.y * 0.5
	)

func is_position_in_walls(position: Vector2) -> bool:
	"""Verificar si una posición está dentro de paredes"""
	if not wall_system:
		return false
	
	# VERIFICAR PAREDES SÓLIDAS
	for wall in wall_system.get_all_walls():
		if not is_instance_valid(wall):
			continue
		
		var wall_rect = get_wall_rect(wall)
		if wall_rect.has_point(position):
			return true
	
	# VERIFICAR BARRICADAS INTACTAS
	for barricade in wall_system.get_all_barricades():
		if not is_instance_valid(barricade):
			continue
		
		var current_planks = barricade.get_meta("current_planks", 0)
		if current_planks > 0:  # Solo si tiene tablones
			var barricade_rect = get_barricade_rect(barricade)
			if barricade_rect.has_point(position):
				return true
	
	# VERIFICAR PUERTAS CERRADAS
	for door in wall_system.get_all_doors():
		if not is_instance_valid(door):
			continue
		
		var is_open = door.get_meta("is_open", false)
		if not is_open:  # Solo si está cerrada
			var door_rect = get_door_rect(door)
			if door_rect.has_point(position):
				return true
	
	return false

func get_wall_rect(wall: StaticBody2D) -> Rect2:
	"""Obtener rectángulo de colisión de una pared"""
	var collision_shape = wall.get_node_or_null("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		return Rect2()
	
	var shape = collision_shape.shape as RectangleShape2D
	if not shape:
		return Rect2()
	
	var size = shape.size
	var position = wall.global_position - size / 2
	return Rect2(position, size)

func get_barricade_rect(barricade: Node2D) -> Rect2:
	"""Obtener rectángulo de colisión de una barricada"""
	var size = barricade.get_meta("size", Vector2(100, 30))
	var position = barricade.global_position - size / 2
	return Rect2(position, size)

func get_door_rect(door: Node2D) -> Rect2:
	"""Obtener rectángulo de colisión de una puerta"""
	var size = door.get_meta("size", Vector2(120, 80))
	var position = door.global_position - size / 2
	return Rect2(position, size)

func configure_enemy_stats_by_type(enemy: Enemy, enemy_type: String, round_health: int):
	"""Configurar estadísticas específicas según tipo de enemigo"""
	match enemy_type:
		"zombie_dog":
			enemy.max_health = int(float(round_health) * 0.4)
			enemy.base_move_speed = 180.0
			enemy.damage = 2
			enemy.attack_range = 50.0
			enemy.detection_range = 1500.0
		"zombie_crawler":
			enemy.max_health = int(float(round_health) * 1.5)
			enemy.base_move_speed = 60.0
			enemy.damage = 1
			enemy.attack_range = 40.0
			enemy.detection_range = 800.0
		"zombie_runner":
			enemy.max_health = int(float(round_health) * 0.6)
			enemy.base_move_speed = 150.0
			enemy.damage = 1
		"zombie_charger":
			enemy.max_health = int(float(round_health) * 0.8)
			enemy.base_move_speed = 120.0
			enemy.damage = 1
			enemy.attack_range = 70.0
		_:  # zombie_basic
			enemy.max_health = round_health
			enemy.base_move_speed = 100.0
			enemy.damage = 1
	
	enemy.current_health = enemy.max_health

func get_enemy_from_pool() -> Enemy:
	"""Obtener enemigo del pool"""
	for enemy in enemy_pool:
		if not enemy.visible and enemy in get_children():
			if enemy.global_position.distance_to(Vector2(10000, 10000)) < 1000.0:
				return enemy
	
	if enemy_pool.size() < max_pool_size:
		var new_enemy = create_unified_enemy()
		if new_enemy:
			new_enemy.global_position = Vector2(10000, 10000)
			new_enemy.add_to_group("enemies")
			enemy_pool.append(new_enemy)
			add_child(new_enemy)
			return new_enemy
	
	return null

func _on_enemy_died(enemy: Enemy):
	"""Manejar muerte de enemigo"""
	if enemy in active_enemies:
		active_enemies.erase(enemy)
	
	enemy_killed.emit(enemy)
	
	check_round_completion()
	
	await get_tree().create_timer(1.0).timeout
	despawn_enemy(enemy)

func check_round_completion():
	"""Verificar si ronda completa"""
	if enemies_spawned_this_round >= enemies_to_spawn and active_enemies.size() == 0:
		can_spawn = false
		round_complete.emit()

func despawn_enemy(enemy: Enemy):
	"""Despawnear enemigo"""
	if not is_instance_valid(enemy):
		return
	
	enemy.visible = false
	enemy.set_physics_process(false)
	enemy.set_process(false)
	enemy.reset_for_pool()
	
	var random_offset = Vector2(randf_range(-1000, 1000), randf_range(-1000, 1000))
	enemy.global_position = Vector2(10000, 10000) + random_offset

func despawn_distant_enemies():
	"""Despawnear enemigos lejanos"""
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
	"""Limpiar enemigos muertos"""
	var new_active_enemies: Array[Enemy] = []
	
	for enemy in active_enemies:
		if is_instance_valid(enemy) and enemy.visible and not enemy.is_dead:
			new_active_enemies.append(enemy)
	
	active_enemies = new_active_enemies

func pause_spawning():
	"""Pausar spawn"""
	can_spawn = false
	if spawn_timer:
		spawn_timer.paused = true

func resume_spawning():
	"""Reanudar spawn"""
	can_spawn = true
	if spawn_timer:
		spawn_timer.paused = false

func clear_all_enemies():
	"""Limpiar todos los enemigos"""
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			despawn_enemy(enemy)
	
	active_enemies.clear()
	enemies_spawned_this_round = 0
	can_spawn = false

func get_active_enemy_count() -> int:
	"""Número de enemigos activos"""
	return active_enemies.size()

func get_enemies_remaining_to_spawn() -> int:
	"""Enemigos restantes por spawnear"""
	return max(0, enemies_to_spawn - enemies_spawned_this_round)

func get_round_info() -> String:
	"""Obtener información de la ronda"""
	return "Ronda " + str(current_round_number)

func _exit_tree():
	"""Limpiar al salir"""
	clear_all_enemies()
	
	for enemy in enemy_pool:
		if is_instance_valid(enemy):
			enemy.queue_free()
