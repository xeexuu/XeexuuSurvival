# scenes/enemies/EnemySpawner.gd - CORREGIDO: TIPOS ESPECÍFICOS Y CONFIGURACIÓN MEJORADA
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

# Pool optimizado
var enemy_pool: Array[Enemy] = []
var max_pool_size: int = 60

# Variables de spawn
var enemies_to_spawn: int = 0
var enemies_spawned_this_round: int = 0
var spawn_delay: float = 2.0
var spawn_timer: Timer
var can_spawn: bool = false

# Control de tipos por ronda
var current_round_number: int = 1

# SISTEMA DE GARANTÍAS MEJORADO CON TIPOS ESPECÍFICOS
var guaranteed_spawns_queue: Array[String] = []
var guaranteed_spawns_completed: Dictionary = {}
var types_spawned_this_round: Dictionary = {}

# CONFIGURACIÓN DE ENEMIGOS POR RONDA BALANCEADA
var base_dogs_per_round: int = 1
var base_crawlers_per_round: int = 1

# ÁREAS DE SPAWN SEGURAS
var safe_spawn_areas: Array[Rect2] = []

func _ready():
	setup_spawn_timer()
	initialize_enemy_pool()
	get_wall_system_reference()
	setup_safe_spawn_areas()

func setup_safe_spawn_areas():
	"""Configurar áreas de spawn seguras fuera de la habitación"""
	safe_spawn_areas = [
		# ÁREA NORTE
		Rect2(-1200, -1800, 2400, 300),
		# ÁREA SUR
		Rect2(-1200, 1500, 2400, 300),
		# ÁREA ESTE
		Rect2(1500, -1200, 300, 2400),
		# ÁREA OESTE (evitando la puerta)
		Rect2(-1800, -1200, 300, 2400),
		# ESQUINAS LEJANAS
		Rect2(-1800, -1800, 400, 400),   # Noroeste
		Rect2(1400, -1800, 400, 400),    # Noreste
		Rect2(-1800, 1400, 400, 400),    # Suroeste
		Rect2(1400, 1400, 400, 400)      # Sureste
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
			enemy.global_position = Vector2(20000 + i * 100, 20000)
			
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
		
		var attack_timer_node = Timer.new()
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
	"""Iniciar nueva ronda con tipos balanceados y configuración específica"""
	current_round_number = rounds_manager.get_current_round() if rounds_manager else 1
	
	# CALCULAR ENEMIGOS ADICIONALES POR RONDA
	var additional_dogs = calculate_dogs_for_round(current_round_number)
	var additional_crawlers = calculate_crawlers_for_round(current_round_number)
	var total_additional = additional_dogs + additional_crawlers
	
	# AUMENTAR CONTEO TOTAL DE ENEMIGOS
	enemies_to_spawn = enemies_count + total_additional
	enemies_spawned_this_round = 0
	can_spawn = true
	
	# RESETEAR CONTADORES DE TIPOS
	types_spawned_this_round.clear()
	types_spawned_this_round["zombie_basic"] = 0
	types_spawned_this_round["zombie_dog"] = 0
	types_spawned_this_round["zombie_crawler"] = 0
	
	# SISTEMA DE GARANTÍAS CON BALANCE APROPIADO
	setup_balanced_guaranteed_spawns(additional_dogs, additional_crawlers)
	
	spawn_delay = max(0.5, 2.0 - (current_round_number * 0.05))
	
	print("🧟 === CONFIGURANDO RONDA ", current_round_number, " ===")
	print("🐺 Perros programados: ", additional_dogs)
	print("🦎 Crawlers programados: ", additional_crawlers)
	print("🧟 Básicos programados: ", enemies_count - total_additional)
	print("🎯 Total enemigos: ", enemies_to_spawn)
	
	_try_spawn_enemy()

func calculate_dogs_for_round(round_num: int) -> int:
	"""Calcular perros por ronda (gradual)"""
	if round_num < 2:
		return 0
	return min(base_dogs_per_round + (round_num / 3), 6)

func calculate_crawlers_for_round(round_num: int) -> int:
	"""Calcular crawlers por ronda (gradual)"""
	return min(base_crawlers_per_round + (round_num / 4), 5)

func setup_balanced_guaranteed_spawns(extra_dogs: int, extra_crawlers: int):
	"""Sistema garantizado con balance apropiado"""
	guaranteed_spawns_queue.clear()
	guaranteed_spawns_completed.clear()
	
	var available_types = get_available_enemy_types_for_round(current_round_number)
	
	# FASE 1: GARANTIZAR AL MENOS 1 DE CADA TIPO DISPONIBLE
	for enemy_type in available_types:
		guaranteed_spawns_queue.append(enemy_type)
	
	# FASE 2: AGREGAR PERROS ESPECÍFICOS
	for i in range(extra_dogs):
		guaranteed_spawns_queue.append("zombie_dog")
	
	# FASE 3: AGREGAR CRAWLERS ESPECÍFICOS
	for i in range(extra_crawlers):
		guaranteed_spawns_queue.append("zombie_crawler")
	
	# FASE 4: LLENAR EL RESTO CON DISTRIBUCIÓN BALANCEADA
	var remaining_spawns = max(0, enemies_to_spawn - guaranteed_spawns_queue.size())
	
	for i in range(remaining_spawns):
		var random_type = get_balanced_random_type(available_types)
		guaranteed_spawns_queue.append(random_type)
	
	# MEZCLAR PARA ORDEN ALEATORIO
	guaranteed_spawns_queue.shuffle()
	
	print("📋 Cola de spawn configurada: ", guaranteed_spawns_queue.size(), " enemigos")
	print("📋 Distribución garantizada: ", guaranteed_spawns_queue)

func get_available_enemy_types_for_round(round_num: int) -> Array[String]:
	"""Obtener tipos de enemigos disponibles para la ronda"""
	var types: Array[String] = []
	
	# BÁSICO SIEMPRE DISPONIBLE
	types.append("zombie_basic")
	
	# CRAWLER DESDE RONDA 1
	types.append("zombie_crawler")
	
	# PERRO DESDE RONDA 2
	if round_num >= 2:
		types.append("zombie_dog")
	
	return types

func get_balanced_random_type(available_types: Array[String]) -> String:
	"""Obtener tipo aleatorio con balance apropiado"""
	var type_weights = {}
	
	# Pesos base
	for enemy_type in available_types:
		match enemy_type:
			"zombie_basic":
				type_weights[enemy_type] = 50  # 50% básicos
			"zombie_dog":
				type_weights[enemy_type] = 25  # 25% perros
			"zombie_crawler":
				type_weights[enemy_type] = 25  # 25% crawlers
			_:
				type_weights[enemy_type] = 10
	
	# Ajustar pesos según lo que ya se ha spawneado
	for enemy_type in available_types:
		var spawned_count = types_spawned_this_round.get(enemy_type, 0)
		var target_percentage = type_weights[enemy_type] / 100.0
		var current_percentage = float(spawned_count) / max(float(enemies_spawned_this_round), 1.0)
		
		if current_percentage > target_percentage * 1.5:
			type_weights[enemy_type] *= 0.3
	
	return weighted_random_selection(type_weights)

func weighted_random_selection(weights: Dictionary) -> String:
	"""Selección aleatoria ponderada"""
	var total_weight = 0
	for weight in weights.values():
		total_weight += weight
	
	var random_value = randf() * total_weight
	var current_weight = 0
	
	for enemy_type in weights:
		current_weight += weights[enemy_type]
		if random_value <= current_weight:
			return enemy_type
	
	return weights.keys()[0]

func _try_spawn_enemy():
	"""Intentar spawnear enemigo"""
	if not can_spawn or not player or not is_instance_valid(player):
		return
	
	if enemies_spawned_this_round >= enemies_to_spawn:
		can_spawn = false
		return
	
	var max_simultaneous = min(40, enemies_to_spawn)
	if active_enemies.size() >= max_simultaneous:
		spawn_timer.wait_time = 0.3
		spawn_timer.start()
		return
	
	if spawn_enemy():
		enemies_spawned_this_round += 1
		
		if enemies_spawned_this_round < enemies_to_spawn:
			spawn_timer.wait_time = spawn_delay
			spawn_timer.start()

func spawn_enemy() -> bool:
	"""Spawnear nuevo enemigo con tipo específico Y CONFIGURACIÓN CORRECTA"""
	if not player:
		return false
	
	var spawn_pos = get_guaranteed_safe_spawn_position()
	if spawn_pos == Vector2.ZERO:
		return false
	
	var enemy = get_enemy_from_pool()
	if not enemy:
		return false
	
	# DETERMINAR TIPO CON GARANTÍAS
	var enemy_type = determine_enemy_type_with_guarantees()
	
	# === CONFIGURACIÓN CRÍTICA ===
	# 1. CONFIGURAR TIPO ANTES DE TODO LO DEMÁS
	enemy.enemy_type = enemy_type
	
	# 2. APLICAR _setup_variant() MANUALMENTE PARA FORZAR EL TIPO
	force_enemy_type_configuration(enemy, enemy_type)
	
	# 3. ACTUALIZAR CONTADOR DE TIPOS
	types_spawned_this_round[enemy_type] = types_spawned_this_round.get(enemy_type, 0) + 1
	
	# 4. CONFIGURAR ESTADÍSTICAS DE SALUD
	var round_health = rounds_manager.get_enemy_health_for_current_round() if rounds_manager else 150
	
	# 5. CONFIGURAR PARA SPAWN
	enemy.setup_for_spawn(player, round_health)
	
	# 6. ESTABLECER REFERENCIA AL WALL SYSTEM
	if wall_system:
		enemy.set_wall_system(wall_system)
	
	# 7. POSICIONAR Y ACTIVAR
	enemy.global_position = spawn_pos
	enemy.visible = true
	enemy.set_physics_process(true)
	enemy.set_process(true)
	
	# 8. FORZAR CONFIGURACIÓN VISUAL ESPECÍFICA
	call_deferred("_apply_visual_config_deferred", enemy, enemy_type)
	
	if enemy.sprite:
		enemy.sprite.visible = true
	
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)
	
	active_enemies.append(enemy)
	enemy_spawned.emit(enemy)
	
	return true

func force_enemy_type_configuration(enemy: Enemy, enemy_type: String):
	"""FORZAR configuración específica del tipo de enemigo"""
	# CONFIGURAR TIPO Y ESTADÍSTICAS
	enemy.enemy_type = enemy_type
	
	match enemy_type:
		"zombie_dog":
			enemy.base_move_speed = 320.0
			enemy.current_move_speed = 320.0
			enemy.damage = 2
			enemy.attack_range = 150.0
			enemy.attack_cooldown = 0.8
			
		"zombie_crawler":
			enemy.base_move_speed = 180.0
			enemy.current_move_speed = 180.0
			enemy.damage = 1
			enemy.attack_range = 120.0
			enemy.attack_cooldown = 1.0
			
		_:  # zombie_basic
			enemy.base_move_speed = 100.0
			enemy.current_move_speed = 100.0
			enemy.damage = 1
			enemy.attack_range = 130.0
			enemy.attack_cooldown = 1.5

func _apply_visual_config_deferred(enemy: Enemy, enemy_type: String):
	"""Aplicar configuración visual después de un frame"""
	if not is_instance_valid(enemy):
		return
	
	# FORZAR CONFIGURACIÓN VISUAL ESPECÍFICA
	if enemy.animated_sprite:
		match enemy_type:
			"zombie_crawler":
				enemy.animated_sprite.scale = Vector2(0.6, 0.6)
				enemy.animated_sprite.modulate = Color(0.2, 1.0, 0.2, 1.0)  # Verde fosforito

				
			"zombie_dog":
				enemy.animated_sprite.scale = Vector2(1.0, 1.0)
				enemy.animated_sprite.modulate = Color(1.0, 0.2, 0.2, 1.0)  # Rojo

				
			_:  # zombie_basic
				enemy.animated_sprite.scale = Vector2(1.0, 1.0)
				enemy.animated_sprite.modulate = Color(0.8, 0.8, 0.6, 1.0)  # Normal

		
		enemy.animated_sprite.visible = true
		enemy.animated_sprite.modulate.a = 1.0

func determine_enemy_type_with_guarantees() -> String:
	"""Sistema con garantías de tipos específicos"""
	
	# PRIORIDAD 1: TIPOS GARANTIZADOS PENDIENTES
	if not guaranteed_spawns_queue.is_empty():
		var guaranteed_type = guaranteed_spawns_queue.pop_front()
		guaranteed_spawns_completed[guaranteed_type] = true

		return guaranteed_type
	
	# PRIORIDAD 2: TIPOS ALEATORIOS BALANCEADOS
	var available_types = get_available_enemy_types_for_round(current_round_number)
	var selected_type = get_balanced_random_type(available_types)

	return selected_type

func get_guaranteed_safe_spawn_position() -> Vector2:
	"""Obtener posición 100% segura fuera de muros"""
	if not player:
		return Vector2.ZERO
	
	var player_pos = player.global_position
	var max_attempts = 300
	
	for attempt in range(max_attempts):
		var spawn_area = safe_spawn_areas[randi() % safe_spawn_areas.size()]
		
		var spawn_pos = Vector2(
			randf_range(spawn_area.position.x + 50, spawn_area.position.x + spawn_area.size.x - 50),
			randf_range(spawn_area.position.y + 50, spawn_area.position.y + spawn_area.size.y - 50)
		)
		
		var distance_to_player = spawn_pos.distance_to(player_pos)
		if distance_to_player < min_spawn_distance or distance_to_player > spawn_radius_max:
			continue
		
		if is_position_in_any_wall_comprehensive(spawn_pos):
			continue
		
		var too_close_to_enemy = false
		for enemy in active_enemies:
			if is_instance_valid(enemy) and enemy.global_position.distance_to(spawn_pos) < 100.0:
				too_close_to_enemy = true
				break
		
		if too_close_to_enemy:
			continue
		
		return spawn_pos
	
	# Posición de emergencia
	var emergency_area = safe_spawn_areas[4]
	return Vector2(
		emergency_area.position.x + emergency_area.size.x * 0.5,
		emergency_area.position.y + emergency_area.size.y * 0.5
	)

func is_position_in_any_wall_comprehensive(pos: Vector2) -> bool:
	"""Verificación si posición está en muro"""
	if not wall_system:
		return false
	
	for wall in wall_system.get_all_walls():
		if not is_instance_valid(wall):
			continue
		
		if is_point_inside_wall_body(pos, wall):
			return true
	
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
	
	var local_point = wall.to_local(point)
	var half_size = shape.size / 2.0
	
	return (abs(local_point.x) <= half_size.x and abs(local_point.y) <= half_size.y)

func is_point_inside_door(point: Vector2, door: Node2D) -> bool:
	"""Verificar si un punto está dentro de una puerta"""
	var size = door.get_meta("size", Vector2(120, 80))
	var local_point = door.to_local(point)
	var half_size = size / 2.0
	
	return (abs(local_point.x) <= half_size.x and abs(local_point.y) <= half_size.y)

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
		
		print("🏁 === RONDA ", current_round_number, " COMPLETADA ===")
		print("  - Enemigos spawneados: ", enemies_spawned_this_round)
		print("  - Tipos spawneados:")
		for enemy_type in types_spawned_this_round:
			print("    * ", enemy_type, ": ", types_spawned_this_round[enemy_type])
		
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

func get_round_stats() -> Dictionary:
	"""Obtener estadísticas de la ronda"""
	var additional_dogs = calculate_dogs_for_round(current_round_number)
	var additional_crawlers = calculate_crawlers_for_round(current_round_number)
	
	return {
		"round": current_round_number,
		"total_enemies": enemies_to_spawn,
		"enemies_spawned": enemies_spawned_this_round,
		"enemies_active": active_enemies.size(),
		"dogs_this_round": additional_dogs,
		"crawlers_this_round": additional_crawlers,
		"types_spawned": types_spawned_this_round.duplicate()
	}

func _exit_tree():
	"""Limpiar al salir"""
	clear_all_enemies()
	
	for enemy in enemy_pool:
		if is_instance_valid(enemy):
			enemy.queue_free()
