# scenes/enemies/EnemySpawner.gd - SIN SHADOWING + GARANTÍAS CORREGIDAS DE TODOS LOS TIPOS
extends Node2D
class_name EnemySpawner

signal enemy_spawned(enemy: Enemy)
signal enemy_killed(enemy: Enemy)
signal round_complete()

@export var spawn_radius_min: float = 700.0
@export var spawn_radius_max: float = 1200.0
@export var despawn_distance: float = 1800.0
@export var min_spawn_distance: float = 600.0  

var player: Player
var active_enemies: Array[Enemy] = []
var rounds_manager: RoundsManager
var wall_system: WallSystem

# Pool simplificado
var enemy_pool: Array[Enemy] = []
var max_pool_size: int = 50  # AUMENTADO PARA MÁS TIPOS

# Variables de spawn
var enemies_to_spawn: int = 0
var enemies_spawned_this_round: int = 0
var spawn_delay: float = 2.0
var spawn_timer: Timer
var can_spawn: bool = false

# Control de tipos por ronda
var current_round_number: int = 1

# SISTEMA DE GARANTÍAS MEJORADO - ASEGURA TODOS LOS TIPOS
var guaranteed_spawns_queue: Array[String] = []
var guaranteed_spawns_completed: Dictionary = {}
var types_spawned_this_round: Dictionary = {}

# ÁREAS DE SPAWN SEGURAS (FUERA DE LA HABITACIÓN)
var safe_spawn_areas: Array[Rect2] = []

func _ready():
	setup_spawn_timer()
	initialize_enemy_pool()
	get_wall_system_reference()
	setup_safe_spawn_areas()

func setup_safe_spawn_areas():
	"""Configurar áreas de spawn completamente FUERA de la habitación AMPLIADAS"""
	safe_spawn_areas = [
		# ÁREA NORTE (muy lejos de la habitación)
		Rect2(-1000, -1500, 2000, 200),
		# ÁREA SUR (muy lejos de la habitación)
		Rect2(-1000, 1300, 2000, 200),
		# ÁREA ESTE (muy lejos de la habitación)
		Rect2(1300, -1000, 200, 2000),
		# ÁREA OESTE (muy lejos de la habitación, evitando la puerta)
		Rect2(-1500, -1000, 200, 2000),
		# ESQUINAS LEJANAS MÁS GRANDES (muy seguras)
		Rect2(-1500, -1500, 300, 300),  # Noroeste
		Rect2(1200, -1500, 300, 300),   # Noreste
		Rect2(-1500, 1200, 300, 300),   # Suroeste
		Rect2(1200, 1200, 300, 300)     # Sureste
	]

func get_wall_system_reference():
	"""Obtener referencia al sistema de paredes"""
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_node("WallSystem"):
		wall_system = game_manager.get_node("WallSystem")

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
			enemy.global_position = Vector2(20000 + i * 100, 20000)  # MUY LEJOS
			
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
		
		var attack_timer_node = Timer.new()  # CORREGIDO: nuevo nombre
		attack_timer_node.name = "AttackTimer"
		attack_timer_node.wait_time = 2.0
		attack_timer_node.one_shot = true
		enemy.add_child(attack_timer_node)
		
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
	"""Iniciar nueva ronda CON GARANTÍAS ESTRICTAS DE TODOS LOS TIPOS"""
	current_round_number = rounds_manager.get_current_round() if rounds_manager else 1
	enemies_to_spawn = enemies_count
	enemies_spawned_this_round = 0
	can_spawn = true
	
	# RESETEAR CONTADORES DE TIPOS
	types_spawned_this_round.clear()
	
	# SISTEMA DE GARANTÍAS ESTRICTO - GARANTIZA TODOS LOS TIPOS DISPONIBLES
	setup_strict_guaranteed_spawns()
	
	spawn_delay = max(0.5, 2.5 - (current_round_number * 0.1))
	
	_try_spawn_enemy()

func setup_strict_guaranteed_spawns():
	"""SISTEMA ESTRICTO: GARANTIZA AL MENOS 1 DE CADA TIPO DISPONIBLE EN LA RONDA"""
	guaranteed_spawns_queue.clear()
	guaranteed_spawns_completed.clear()
	
	# OBTENER TIPOS DISPONIBLES PARA ESTA RONDA
	var available_types = get_available_enemy_types_for_round(current_round_number)
	
	# GARANTIZAR 1 DE CADA TIPO DISPONIBLE
	for enemy_type in available_types:
		guaranteed_spawns_queue.append(enemy_type)
		types_spawned_this_round[enemy_type] = 0
	
	# AGREGAR MÁS ENEMIGOS SEGÚN LA CANTIDAD TOTAL A SPAWNEAR
	var remaining_spawns = max(0, enemies_to_spawn - guaranteed_spawns_queue.size())
	
	# LLENAR EL RESTO CON TIPOS ALEATORIOS PERO BALANCEADOS
	for i in range(remaining_spawns):
		var random_type = get_weighted_random_type(available_types)
		guaranteed_spawns_queue.append(random_type)
	
	# MEZCLAR PARA ORDEN ALEATORIO
	guaranteed_spawns_queue.shuffle()

func get_available_enemy_types_for_round(round_num: int) -> Array[String]:
	"""Obtener tipos de enemigos disponibles para la ronda"""
	var types: Array[String] = []
	
	# BÁSICO SIEMPRE DISPONIBLE
	types.append("zombie_basic")
	
	# PERRO DESDE RONDA 1
	types.append("zombie_dog")
	
	# CRAWLER DESDE RONDA 1  
	types.append("zombie_crawler")
	
	# RUNNER DESDE RONDA 3
	if round_num >= 3:
		types.append("zombie_runner")
	
	# CHARGER DESDE RONDA 6
	if round_num >= 6:
		types.append("zombie_charger")
	
	return types

func get_weighted_random_type(available_types: Array[String]) -> String:
	"""Obtener tipo aleatorio con peso balanceado"""
	# CONTAR CUÁNTOS DE CADA TIPO YA HEMOS SPAWNEADO
	var least_spawned_count = 999999
	var least_spawned_types: Array[String] = []
	
	for enemy_type in available_types:
		var count = types_spawned_this_round.get(enemy_type, 0)
		if count < least_spawned_count:
			least_spawned_count = count
			least_spawned_types.clear()
			least_spawned_types.append(enemy_type)
		elif count == least_spawned_count:
			least_spawned_types.append(enemy_type)
	
	# ELEGIR ENTRE LOS TIPOS MENOS SPAWNEADOS
	if not least_spawned_types.is_empty():
		return least_spawned_types[randi() % least_spawned_types.size()]
	
	# FALLBACK
	return available_types[randi() % available_types.size()]

func _try_spawn_enemy():
	"""Intentar spawnear enemigo"""
	if not can_spawn or not player or not is_instance_valid(player):
		return
	
	if enemies_spawned_this_round >= enemies_to_spawn:
		can_spawn = false
		return
	
	var max_simultaneous = min(35, enemies_to_spawn)  # AUMENTADO
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
	"""Spawnear nuevo enemigo GARANTIZANDO QUE NO ESTÉ EN MUROS"""
	if not player:
		return false
	
	var spawn_pos = get_guaranteed_safe_spawn_position()  # CORREGIDO: nuevo nombre
	if spawn_pos == Vector2.ZERO:
		return false
	
	var enemy = get_enemy_from_pool()
	if not enemy:
		return false
	
	# DETERMINAR TIPO CON GARANTÍAS ESTRICTAS
	var enemy_type = determine_enemy_type_with_guarantees()
	enemy.enemy_type = enemy_type
	
	# ACTUALIZAR CONTADOR DE TIPOS
	types_spawned_this_round[enemy_type] = types_spawned_this_round.get(enemy_type, 0) + 1
	
	# CONFIGURAR ESTADÍSTICAS ESPECÍFICAS POR TIPO
	var round_health = rounds_manager.get_enemy_health_for_current_round() if rounds_manager else 150
	configure_enemy_stats_by_type(enemy, enemy_type, round_health)
	
	# CONFIGURAR PARA SPAWN
	enemy.setup_for_spawn(player, round_health)
	
	# ESTABLECER REFERENCIA AL WALL SYSTEM
	if wall_system:
		enemy.set_wall_system(wall_system)
	
	# POSICIONAR Y ACTIVAR EN POSICIÓN SEGURA
	enemy.global_position = spawn_pos
	enemy.visible = true
	enemy.set_physics_process(true)
	enemy.set_process(true)
	
	if enemy.sprite:
		enemy.sprite.visible = true
	
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)
	
	active_enemies.append(enemy)
	enemy_spawned.emit(enemy)
	
	return true

func determine_enemy_type_with_guarantees() -> String:
	"""SISTEMA CON GARANTÍAS ESTRICTAS - ASEGURA TODOS LOS TIPOS"""
	
	# PRIORIDAD 1: TIPOS GARANTIZADOS PENDIENTES
	if not guaranteed_spawns_queue.is_empty():
		var guaranteed_type = guaranteed_spawns_queue.pop_front()
		guaranteed_spawns_completed[guaranteed_type] = true
		return guaranteed_type
	
	# PRIORIDAD 2: TIPOS ALEATORIOS BALANCEADOS
	var available_types = get_available_enemy_types_for_round(current_round_number)
	return get_weighted_random_type(available_types)

func get_guaranteed_safe_spawn_position() -> Vector2:  # CORREGIDO: nuevo nombre
	"""Obtener posición 100% SEGURA fuera de muros con múltiples verificaciones"""
	if not player:
		return Vector2.ZERO
	
	var player_pos = player.global_position
	var max_attempts = 300  # MÁS INTENTOS
	
	for attempt in range(max_attempts):
		# SELECCIONAR ÁREA DE SPAWN ALEATORIA
		var spawn_area = safe_spawn_areas[randi() % safe_spawn_areas.size()]
		
		# POSICIÓN ALEATORIA DENTRO DEL ÁREA SEGURA
		var spawn_pos = Vector2(
			randf_range(spawn_area.position.x + 50, spawn_area.position.x + spawn_area.size.x - 50),
			randf_range(spawn_area.position.y + 50, spawn_area.position.y + spawn_area.size.y - 50)
		)
		
		# VERIFICACIÓN 1: DISTANCIA AL JUGADOR
		var distance_to_player = spawn_pos.distance_to(player_pos)
		if distance_to_player < min_spawn_distance or distance_to_player > spawn_radius_max:
			continue
		
		# VERIFICACIÓN 2: NO ESTAR EN PAREDES (MÚLTIPLES PUNTOS)
		if is_position_in_any_wall_comprehensive(spawn_pos):
			continue
		
		# VERIFICACIÓN 3: DISTANCIA A OTROS ENEMIGOS
		var too_close_to_enemy = false
		for enemy in active_enemies:
			if is_instance_valid(enemy) and enemy.global_position.distance_to(spawn_pos) < 120.0:
				too_close_to_enemy = true
				break
		
		if too_close_to_enemy:
			continue
		
		# VERIFICACIÓN 4: ESPACIO LIBRE ALREDEDOR (CÍRCULO DE SEGURIDAD)
		if not has_clear_space_around(spawn_pos, 80.0):
			continue
		
		# TODAS LAS VERIFICACIONES PASADAS - POSICIÓN SEGURA
		return spawn_pos
	
	# POSICIÓN DE EMERGENCIA EN ÁREA MÁS SEGURA (esquina noroeste)
	var emergency_area = safe_spawn_areas[4]  # Esquina noroeste
	var emergency_pos = Vector2(
		emergency_area.position.x + emergency_area.size.x * 0.5,
		emergency_area.position.y + emergency_area.size.y * 0.5
	)
	
	return emergency_pos

func is_position_in_any_wall_comprehensive(pos: Vector2) -> bool:  # CORREGIDO: nuevo nombre
	"""Verificación EXHAUSTIVA si una posición está en cualquier tipo de muro"""
	if not wall_system:
		return false
	
	# VERIFICAR PAREDES SÓLIDAS
	for wall in wall_system.get_all_walls():
		if not is_instance_valid(wall):
			continue
		
		if is_point_inside_wall_body(pos, wall):
			return true
	
	# VERIFICAR BARRICADAS (incluso sin tablones, son obstáculos físicos)
	for barricade in wall_system.get_all_barricades():
		if not is_instance_valid(barricade):
			continue
		
		if is_point_inside_barricade(pos, barricade):
			return true
	
	# VERIFICAR PUERTAS CERRADAS
	for door in wall_system.get_all_doors():
		if not is_instance_valid(door):
			continue
		
		var is_open = door.get_meta("is_open", false)
		if not is_open and is_point_inside_door(pos, door):
			return true
	
	return false

func is_point_inside_wall_body(point: Vector2, wall: StaticBody2D) -> bool:
	"""Verificar si un punto está dentro del cuerpo de una pared"""
	var collision_shape = wall.get_node_or_null("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		return false
	
	var shape = collision_shape.shape as RectangleShape2D
	if not shape:
		return false
	
	# Convertir punto a espacio local de la pared
	var local_point = wall.to_local(point)
	var half_size = shape.size / 2.0
	
	return (abs(local_point.x) <= half_size.x and abs(local_point.y) <= half_size.y)

func is_point_inside_barricade(point: Vector2, barricade: Node2D) -> bool:
	"""Verificar si un punto está dentro de una barricada"""
	var size = barricade.get_meta("size", Vector2(100, 30))
	var local_point = barricade.to_local(point)
	var half_size = size / 2.0
	
	return (abs(local_point.x) <= half_size.x and abs(local_point.y) <= half_size.y)

func is_point_inside_door(point: Vector2, door: Node2D) -> bool:
	"""Verificar si un punto está dentro de una puerta"""
	var size = door.get_meta("size", Vector2(120, 80))
	var local_point = door.to_local(point)
	var half_size = size / 2.0
	
	return (abs(local_point.x) <= half_size.x and abs(local_point.y) <= half_size.y)

func has_clear_space_around(center: Vector2, radius: float) -> bool:
	"""Verificar que hay espacio libre alrededor de una posición"""
	# Verificar múltiples puntos en un círculo alrededor del centro
	var check_points = 8
	for i in range(check_points):
		var angle = (float(i) * 2.0 * PI) / float(check_points)
		var check_pos = center + Vector2.from_angle(angle) * radius
		
		if is_position_in_any_wall_comprehensive(check_pos):
			return false
	
	return true

func configure_enemy_stats_by_type(enemy: Enemy, enemy_type: String, round_health: int):
	"""Configurar estadísticas específicas según tipo de enemigo"""
	match enemy_type:
		"zombie_dog":
			enemy.max_health = int(float(round_health) * 0.5)
			enemy.base_move_speed = 200.0
			enemy.damage = 2
			enemy.attack_range = 60.0
			enemy.detection_range = 1200.0
			enemy.attack_cooldown = 0.8
		"zombie_crawler":
			enemy.max_health = int(float(round_health) * 1.2)
			enemy.base_move_speed = 80.0
			enemy.damage = 1
			enemy.attack_range = 50.0
			enemy.detection_range = 600.0
			enemy.attack_cooldown = 1.2
		"zombie_runner":
			enemy.max_health = int(float(round_health) * 0.7)
			enemy.base_move_speed = 160.0
			enemy.damage = 1
			enemy.attack_range = 55.0
			enemy.detection_range = 1000.0
			enemy.attack_cooldown = 0.9
		"zombie_charger":
			enemy.max_health = int(float(round_health) * 0.9)
			enemy.base_move_speed = 140.0
			enemy.damage = 2
			enemy.attack_range = 80.0
			enemy.detection_range = 1100.0
			enemy.attack_cooldown = 1.1
		_:  # zombie_basic
			enemy.max_health = round_health
			enemy.base_move_speed = 100.0
			enemy.damage = 1
			enemy.attack_range = 60.0
			enemy.detection_range = 800.0
			enemy.attack_cooldown = 1.0
	
	enemy.current_health = enemy.max_health
	enemy.current_move_speed = enemy.base_move_speed

func get_enemy_from_pool() -> Enemy:
	"""Obtener enemigo del pool"""
	for enemy in enemy_pool:
		if not enemy.visible and enemy in get_children():
			if enemy.global_position.distance_to(Vector2(20000, 20000)) < 5000.0:
				return enemy
	
	if enemy_pool.size() < max_pool_size:
		var new_enemy = create_unified_enemy()
		if new_enemy:
			new_enemy.global_position = Vector2(20000, 20000)
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
	enemy.global_position = Vector2(20000, 20000) + random_offset

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
	"""Obtener información de la ronda con tipos spawneados"""
	var info = "Ronda " + str(current_round_number) + " - Tipos spawneados: "
	for enemy_type in types_spawned_this_round:
		info += enemy_type + ":" + str(types_spawned_this_round[enemy_type]) + " "
	return info

func _exit_tree():
	"""Limpiar al salir"""
	clear_all_enemies()
	
	for enemy in enemy_pool:
		if is_instance_valid(enemy):
			enemy.queue_free()
