# scenes/enemies/EnemySpawner.gd - SIN ENEMIGOS INVISIBLES + MÚLTIPLES TIPOS
extends Node2D
class_name EnemySpawner

signal enemy_spawned(enemy: BaseEnemy)
signal enemy_killed(enemy: BaseEnemy)
signal round_complete()

@export var spawn_radius_min: float = 400.0
@export var spawn_radius_max: float = 800.0
@export var despawn_distance: float = 1200.0

var player: Player
var active_enemies: Array[BaseEnemy] = []
var rounds_manager: RoundsManager

# Pool de enemigos por tipo
var enemy_pools: Dictionary = {
	"zombie_basic": [],
	"zombie_dog": [],
	"zombie_crawler": []
}
var max_pool_size_per_type: int = 15

# Variables de spawn COD Zombies
var enemies_to_spawn: int = 0
var enemies_spawned_this_round: int = 0
var spawn_delay: float = 2.0
var spawn_timer: Timer
var can_spawn: bool = false

# Control de tipos de enemigos por ronda
var current_round: int = 1
var special_wave: Array[String] = []
var special_wave_index: int = 0

# Debug y limpieza
var cleanup_timer: Timer

func _ready():
	setup_spawn_timer()
	setup_cleanup_timer()
	initialize_enemy_pools()

func setup_spawn_timer():
	"""Configurar timer de spawn"""
	spawn_timer = Timer.new()
	spawn_timer.timeout.connect(_try_spawn_enemy)
	spawn_timer.autostart = false
	add_child(spawn_timer)

func setup_cleanup_timer():
	"""Timer para limpiar enemigos problemáticos"""
	cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 5.0
	cleanup_timer.autostart = true
	cleanup_timer.timeout.connect(_cleanup_problematic_enemies)
	add_child(cleanup_timer)

func _cleanup_problematic_enemies():
	"""Limpiar enemigos invisibles o problemáticos"""
	var enemies_to_remove: Array[BaseEnemy] = []
	
	for enemy in active_enemies:
		if not is_instance_valid(enemy):
			enemies_to_remove.append(enemy)
			continue
		
		# Verificar si el enemigo está en el centro del mapa (0,0) sin sprite visible
		if enemy.global_position.distance_to(Vector2.ZERO) < 50.0:
			if not enemy.sprite or not enemy.sprite.visible:
				enemies_to_remove.append(enemy)
				continue
		
		# Verificar si el enemigo no tiene sprite válido
		if not enemy.sprite:
			enemies_to_remove.append(enemy)
			continue
		
		# Verificar si está muy lejos del jugador y no es visible
		if player and enemy.global_position.distance_to(player.global_position) > despawn_distance * 2:
			enemies_to_remove.append(enemy)
			continue
	
	# Remover enemigos problemáticos
	for enemy in enemies_to_remove:
		if enemy in active_enemies:
			active_enemies.erase(enemy)
		
		if is_instance_valid(enemy):
			enemy.queue_free()

func initialize_enemy_pools():
	"""Crear pools iniciales de enemigos"""
	for enemy_type in enemy_pools.keys():
		for i in range(max_pool_size_per_type):
			var enemy = create_enemy_of_type(enemy_type)
			if enemy:
				enemy.visible = false
				enemy.set_physics_process(false)
				enemy.set_process(false)
				
				# ASEGURAR QUE EL ENEMIGO ESTÉ FUERA DEL CENTRO
				enemy.global_position = Vector2(10000 + i * 100, 10000)
				
				enemy_pools[enemy_type].append(enemy)
				add_child(enemy)

func create_enemy_of_type(enemy_type: String) -> BaseEnemy:
	"""Crear enemigo del tipo específico"""
	return EnemyFactory.create_enemy(enemy_type)

func setup(player_ref: Player, rounds_manager_ref: RoundsManager):
	"""Configurar spawner"""
	player = player_ref
	rounds_manager = rounds_manager_ref

func start_round(enemies_count: int, enemy_health: int):
	"""Iniciar nueva ronda"""
	current_round = rounds_manager.get_current_round() if rounds_manager else 1
	enemies_to_spawn = enemies_count
	enemies_spawned_this_round = 0
	can_spawn = true
	special_wave_index = 0
	
	# Verificar si es ronda especial
	if EnemyFactory.is_special_round(current_round):
		special_wave = EnemyFactory.create_special_wave(current_round)
	else:
		special_wave.clear()
	
	# Ajustar velocidad de spawn
	spawn_delay = max(0.3, 2.5 - (current_round * 0.08))
	
	# Configurar salud de enemigos
	for enemy_type in enemy_pools.keys():
		for enemy in enemy_pools[enemy_type]:
			if enemy:
				enemy.max_health = enemy_health
	
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
	var max_simultaneous = min(28, enemies_to_spawn)
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
	"""Spawnear nuevo enemigo"""
	if not player:
		return false
	
	var spawn_position = get_random_spawn_position()
	if spawn_position == Vector2.ZERO:
		return false
	
	# Determinar tipo de enemigo a spawnear
	var enemy_type = get_enemy_type_for_spawn()
	var enemy = get_enemy_from_pool(enemy_type)
	if not enemy:
		return false
	
	# VERIFICAR QUE LA POSICIÓN NO SEA EL CENTRO
	if spawn_position.distance_to(Vector2.ZERO) < 100.0:
		# Forzar spawn fuera del centro
		var angle = randf() * TAU
		spawn_position = player.global_position + Vector2.from_angle(angle) * spawn_radius_min
	
	# Configurar enemigo
	var round_health = rounds_manager.get_enemy_health_for_current_round() if rounds_manager else 150
	enemy.setup_for_spawn(player, round_health)
	
	# POSICIONAR ENEMIGO CORRECTAMENTE
	enemy.global_position = spawn_position
	enemy.visible = true
	enemy.set_physics_process(true)
	enemy.set_process(true)
	
	# VERIFICAR QUE EL SPRITE SEA VISIBLE
	if enemy.sprite:
		enemy.sprite.visible = true
	
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)
	
	active_enemies.append(enemy)
	enemy_spawned.emit(enemy)
	
	return true

func get_enemy_type_for_spawn() -> String:
	"""Determinar qué tipo de enemigo spawnear"""
	# Si es oleada especial, usar el orden predefinido
	if special_wave.size() > 0 and special_wave_index < special_wave.size():
		var enemy_type = special_wave[special_wave_index]
		special_wave_index += 1
		return enemy_type
	
	# Si no, usar probabilidades normales
	return EnemyFactory.get_random_enemy_type(current_round)

func get_enemy_from_pool(enemy_type: String) -> BaseEnemy:
	"""Obtener enemigo del pool específico"""
	if not enemy_pools.has(enemy_type):
		enemy_type = "zombie_basic"  # Fallback
	
	for enemy in enemy_pools[enemy_type]:
		if not enemy.visible and enemy in get_children():
			# VERIFICAR QUE EL ENEMIGO ESTÉ REALMENTE DISPONIBLE
			if enemy.global_position.distance_to(Vector2(10000, 10000)) < 500.0:
				return enemy
	
	# Si no hay disponibles, crear uno nuevo
	if enemy_pools[enemy_type].size() < max_pool_size_per_type:
		var new_enemy = create_enemy_of_type(enemy_type)
		if new_enemy:
			new_enemy.global_position = Vector2(10000, 10000)
			enemy_pools[enemy_type].append(new_enemy)
			add_child(new_enemy)
			return new_enemy
	
	return null

func get_random_spawn_position() -> Vector2:
	"""Obtener posición aleatoria de spawn FUERA DEL CENTRO"""
	if not player:
		return Vector2.ZERO
	
	var player_pos = player.global_position
	var attempts = 25
	
	for attempt in range(attempts):
		var angle = randf() * 2 * PI
		var distance = randf_range(spawn_radius_min, spawn_radius_max)
		var spawn_pos = player_pos + Vector2.from_angle(angle) * distance
		
		# VERIFICAR QUE NO ESTÉ EN EL CENTRO DEL MAPA
		if spawn_pos.distance_to(Vector2.ZERO) < 100.0:
			continue
		
		if is_position_valid(spawn_pos):
			return spawn_pos
	
	# Fallback: forzar spawn en radio mínimo
	var fallback_angle = randf() * TAU
	return player_pos + Vector2.from_angle(fallback_angle) * spawn_radius_min

func is_position_valid(pos: Vector2) -> bool:
	"""Verificar si posición es válida"""
	var map_bounds = Rect2(-800, -800, 1600, 1600)
	if not map_bounds.has_point(pos):
		return false
	
	# VERIFICAR QUE NO ESTÉ EN EL CENTRO
	if pos.distance_to(Vector2.ZERO) < 100.0:
		return false
	
	var min_distance_between_enemies = 80.0
	for enemy in active_enemies:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(pos) < min_distance_between_enemies:
			return false
	
	return true

func _on_enemy_died(enemy: BaseEnemy):
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

func despawn_enemy(enemy: BaseEnemy):
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
	var enemies_to_despawn: Array[BaseEnemy] = []
	
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
	var new_active_enemies: Array[BaseEnemy] = []
	
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

func get_enemy_type_counts() -> Dictionary:
	"""Obtener conteo de enemigos por tipo"""
	var counts = {"zombie_basic": 0, "zombie_dog": 0, "zombie_crawler": 0}
	
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			var enemy_type = enemy.get_enemy_type()
			if counts.has(enemy_type):
				counts[enemy_type] += 1
	
	return counts

func get_round_info() -> String:
	"""Obtener información de la ronda"""
	if EnemyFactory.is_special_round(current_round):
		return EnemyFactory.get_round_description(current_round)
	else:
		return "Ronda " + str(current_round)

func _exit_tree():
	"""Limpiar al salir"""
	clear_all_enemies()
	
	for enemy_type in enemy_pools.keys():
		for enemy in enemy_pools[enemy_type]:
			if is_instance_valid(enemy):
				enemy.queue_free()# scenes/enemies/EnemySpawner.gd - SIN ENEMIGOS INVISIBLES
