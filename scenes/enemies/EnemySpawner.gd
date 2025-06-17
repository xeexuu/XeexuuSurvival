# scenes/enemies/EnemySpawner.gd - CON GRUPO DE ENEMIGOS PARA LA IA
extends Node2D
class_name EnemySpawner

signal enemy_spawned(enemy: Enemy)
signal enemy_killed(enemy: Enemy)
signal round_complete()

@export var spawn_radius_min: float = 500.0  
@export var spawn_radius_max: float = 800.0
@export var despawn_distance: float = 1200.0
@export var min_spawn_distance: float = 400.0  

var player: Player
var active_enemies: Array[Enemy] = []
var rounds_manager: RoundsManager

# Pool simplificado
var enemy_pool: Array[Enemy] = []
var max_pool_size: int = 20

# Variables de spawn
var enemies_to_spawn: int = 0
var enemies_spawned_this_round: int = 0
var spawn_delay: float = 2.0
var spawn_timer: Timer
var can_spawn: bool = false

# Control de tipos por ronda
var current_round_number: int = 1

func _ready():
	setup_spawn_timer()
	initialize_enemy_pool()

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
			
			# AÑADIR AL GRUPO DE ENEMIGOS
			enemy.add_to_group("enemies")
			
			enemy_pool.append(enemy)
			add_child(enemy)

func create_unified_enemy() -> Enemy:
	"""Crear enemigo usando la escena unificada"""
	var enemy_scene = preload("res://scenes/enemies/BasicEnemy.tscn")
	var enemy = enemy_scene.instantiate() as Enemy
	
	if not enemy:
		# Crear manualmente si no existe la escena
		enemy = Enemy.new()
		enemy.name = "Enemy"
		
		# Sprite
		var sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		enemy.add_child(sprite)
		
		# Colisión
		var collision = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var shape = RectangleShape2D.new()
		shape.size = Vector2(48, 48)
		collision.shape = shape
		enemy.add_child(collision)
		
		# Timer de ataque
		var attack_timer = Timer.new()
		attack_timer.name = "AttackTimer"
		attack_timer.wait_time = 2.0
		attack_timer.one_shot = true
		enemy.add_child(attack_timer)
		
		# Barra de vida
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
	"""Iniciar nueva ronda"""
	current_round_number = rounds_manager.get_current_round() if rounds_manager else 1
	enemies_to_spawn = enemies_count
	enemies_spawned_this_round = 0
	can_spawn = true
	
	# Ajustar velocidad de spawn
	spawn_delay = max(0.5, 2.5 - (current_round_number * 0.1))
	
	# Iniciar spawn
	_try_spawn_enemy()

func _try_spawn_enemy():
	"""Intentar spawnear enemigo"""
	if not can_spawn or not player or not is_instance_valid(player):
		return
	
	# Verificar si ya spawneamos todos
	if enemies_spawned_this_round >= enemies_to_spawn:
		can_spawn = false
		return
	
	# Verificar límite de enemigos simultáneos
	var max_simultaneous = min(25, enemies_to_spawn)
	if active_enemies.size() >= max_simultaneous:
		spawn_timer.wait_time = 0.5
		spawn_timer.start()
		return
	
	# Spawnear enemigo
	if spawn_enemy():
		enemies_spawned_this_round += 1
		
		# Programar siguiente spawn
		if enemies_spawned_this_round < enemies_to_spawn:
			spawn_timer.wait_time = spawn_delay
			spawn_timer.start()

func spawn_enemy() -> bool:
	"""Spawnear nuevo enemigo LEJOS del jugador - SALUD COMPLETA"""
	if not player:
		return false
	
	var spawn_position = get_safe_spawn_position()
	if spawn_position == Vector2.ZERO:
		return false
	
	# Obtener enemigo del pool
	var enemy = get_enemy_from_pool()
	if not enemy:
		return false
	
	# Determinar tipo de enemigo según la ronda ANTES de configurar salud
	var enemy_type = determine_enemy_type_by_round(current_round_number)
	enemy.enemy_type = enemy_type
	
	# CONFIGURAR SALUD COMPLETA PARA LA RONDA
	var round_health = rounds_manager.get_enemy_health_for_current_round() if rounds_manager else 150
	
	print("🏥 Configurando enemigo con salud de ronda: ", round_health)
	
	# Configurar enemigo CON SALUD COMPLETA
	enemy.setup_for_spawn(player, round_health)
	
	# VERIFICAR QUE LA SALUD SEA CORRECTA
	if enemy.current_health != enemy.max_health:
		print("⚠️ ERROR: Enemigo spawneado sin salud completa!")
		enemy.current_health = enemy.max_health
		enemy.update_health_bar()
	
	# POSICIONAR ENEMIGO
	enemy.global_position = spawn_position
	enemy.visible = true
	enemy.set_physics_process(true)
	enemy.set_process(true)
	
	# VERIFICAR SPRITE
	if enemy.sprite:
		enemy.sprite.visible = true
	
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)
	
	active_enemies.append(enemy)
	enemy_spawned.emit(enemy)
	
	print("✅ Enemigo spawneado exitosamente - Salud final: ", enemy.current_health, "/", enemy.max_health)
	
	return true

func get_safe_spawn_position() -> Vector2:
	"""Obtener posición SEGURA de spawn - NUNCA en los pies del jugador"""
	if not player:
		return Vector2.ZERO
	
	var player_pos = player.global_position
	var attempts = 50  # Más intentos para encontrar posición segura
	
	for attempt in range(attempts):
		var angle = randf() * TAU
		var distance = randf_range(spawn_radius_min, spawn_radius_max)
		var spawn_pos = player_pos + Vector2.from_angle(angle) * distance
		
		# VERIFICACIONES DE SEGURIDAD MÚLTIPLES
		var distance_to_player = spawn_pos.distance_to(player_pos)
		
		# 1. NUNCA MÁS CERCA QUE LA DISTANCIA MÍNIMA
		if distance_to_player < min_spawn_distance:
			continue
		
		# 2. VERIFICAR QUE NO ESTÉ EN EL CENTRO DEL MAPA
		if spawn_pos.distance_to(Vector2.ZERO) < 150.0:
			continue
		
		# 3. VERIFICAR LÍMITES DEL MAPA
		var map_bounds = Rect2(-750, -750, 1500, 1500)
		if not map_bounds.has_point(spawn_pos):
			continue
		
		# 4. VERIFICAR DISTANCIA A OTROS ENEMIGOS
		var too_close_to_enemy = false
		for enemy in active_enemies:
			if is_instance_valid(enemy) and enemy.global_position.distance_to(spawn_pos) < 80.0:
				too_close_to_enemy = true
				break
		
		if too_close_to_enemy:
			continue
		
		# 5. POSICIÓN VÁLIDA ENCONTRADA
		return spawn_pos
	
	# Fallback: forzar spawn en distancia mínima segura
	var emergency_angle = randf() * TAU
	var emergency_distance = max(min_spawn_distance, spawn_radius_min)
	return player_pos + Vector2.from_angle(emergency_angle) * emergency_distance

func determine_enemy_type_by_round(round_num: int) -> String:
	"""Determinar tipo de enemigo según la ronda"""
	if round_num >= 8 and randf() < 0.2:
		return "zombie_dog"
	elif round_num >= 5 and randf() < 0.15:
		return "zombie_crawler"
	else:
		return "zombie_basic"

func get_enemy_from_pool() -> Enemy:
	"""Obtener enemigo del pool"""
	for enemy in enemy_pool:
		if not enemy.visible and enemy in get_children():
			if enemy.global_position.distance_to(Vector2(10000, 10000)) < 1000.0:
				return enemy
	
	# Si no hay disponibles, crear uno nuevo
	if enemy_pool.size() < max_pool_size:
		var new_enemy = create_unified_enemy()
		if new_enemy:
			new_enemy.global_position = Vector2(10000, 10000)
			new_enemy.add_to_group("enemies")  # AÑADIR AL GRUPO
			enemy_pool.append(new_enemy)
			add_child(new_enemy)
			return new_enemy
	
	return null

func _on_enemy_died(enemy: Enemy):
	"""Manejar muerte de enemigo"""
	if enemy in active_enemies:
		active_enemies.erase(enemy)
	
	enemy_killed.emit(enemy)
	
	# Verificar si ronda completa
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
	
	# MOVER LEJOS DEL CENTRO
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
