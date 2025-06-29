# scenes/enemies/Enemy.gd - ATAQUE GARANTIZADO SIN INTERFERENCIAS + VERIFICACIÓN PRE-SALTO
extends CharacterBody2D
class_name Enemy
signal died(enemy: Enemy)
signal damaged(enemy: Enemy, damage: int)

@export var enemy_type: String = "zombie_basic"
@export var max_health: int = 150
@export var current_health: int = 150
@export var base_move_speed: float = 120.0
@export var damage: int = 1
@export var attack_range: float = 80.0  # Rango ligeramente aumentado para mejor detección
@export var barricade_attack_range: float = 150.0
@export var detection_range: float = 1400.0
@export var attack_cooldown: float = 1.0  # Ataque cada segundo

@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D
@onready var attack_timer = $AttackTimer
@onready var health_bar = $HealthBar

var player: Player = null
var is_dead: bool = false
var last_attack_time: float = 0.0
var current_move_speed: float = 120.0

# SISTEMA DE ANIMACIONES
var animated_sprite: AnimatedSprite2D
var sprite_frames: SpriteFrames
var zombie_atlas: Texture2D
var current_direction: Vector2 = Vector2.RIGHT
var last_movement_direction: Vector2 = Vector2.RIGHT

# SISTEMA DE HITBOX COMPLETO
var head_area: Area2D
var body_area: Area2D
var legs_area: Area2D

# SISTEMA DE IA CON BARRICADAS ESTRICTO
var wall_system: WallSystem
var target_barricade: Node2D = null
var is_attacking_barricade: bool = false

# SISTEMA DE NAVEGACIÓN MEJORADO
var stuck_timer: float = 0.0
var last_position: Vector2
var jump_cooldown: float = 0.0
var is_jumping: bool = false
var path_blocked_timer: float = 0.0

# Estados de pathfinding
var is_searching_alternate_route: bool = false
var alternate_route_attempts: int = 0
var max_route_attempts: int = 3

# MECÁNICAS ESPECÍFICAS POR TIPO
var crawler_jump_timer: float = 0.0
var crawler_last_jump_time: float = 0.0
var dog_movement_timer: float = 0.0
var dog_derrap_offset: Vector2 = Vector2.ZERO

# ESTADOS SIMPLES
enum EnemyState { 
	MOVING_TO_PLAYER,           
	SEARCHING_BARRICADE,        
	ATTACKING_BARRICADE,        
	JUMPING                     
}
var current_state: EnemyState = EnemyState.MOVING_TO_PLAYER

# VARIABLES PARA BÚSQUEDA Y DESTRUCCIÓN DE BARRICADAS
var search_timer: float = 0.0
var barricade_destruction_timer: float = 0.0
var barricade_check_timer: float = 0.0
var path_verification_timer: float = 0.0

func _ready():
	add_to_group("enemies")
	setup_enemy()
	call_deferred("_setup_variant")
	call_deferred("setup_animation_system")
	call_deferred("setup_hitbox_areas_full_sprite_corrected")
	last_position = global_position

func setup_hitbox_areas_full_sprite_corrected():
	"""Configurar hitboxes QUE OCUPEN TODO EL ALTO DEL SPRITE (128px)"""
	var sprite_height = 128.0
	var sprite_width = 60.0
	
	# ÁREA DE CABEZA
	head_area = Area2D.new()
	head_area.name = "HeadArea"
	head_area.collision_layer = 8
	head_area.collision_mask = 0
	
	var head_shape = CollisionShape2D.new()
	var head_rect = RectangleShape2D.new()
	head_rect.size = Vector2(sprite_width, sprite_height / 3.0)
	head_shape.position = Vector2(0, -sprite_height / 3.0)
	head_shape.shape = head_rect
	head_area.add_child(head_shape)
	add_child(head_area)
	
	# ÁREA DE CUERPO
	body_area = Area2D.new()
	body_area.name = "BodyArea"
	body_area.collision_layer = 8
	body_area.collision_mask = 0
	
	var body_shape = CollisionShape2D.new()
	var body_rect = RectangleShape2D.new()
	body_rect.size = Vector2(sprite_width, sprite_height / 3.0)
	body_shape.position = Vector2(0, 0)
	body_shape.shape = body_rect
	body_area.add_child(body_shape)
	add_child(body_area)
	
	# ÁREA DE PIERNAS
	legs_area = Area2D.new()
	legs_area.name = "LegsArea"
	legs_area.collision_layer = 8
	legs_area.collision_mask = 0
	
	var legs_shape = CollisionShape2D.new()
	var legs_rect = RectangleShape2D.new()
	legs_rect.size = Vector2(sprite_width, sprite_height / 3.0)
	legs_shape.position = Vector2(0, sprite_height / 3.0)
	legs_shape.shape = legs_rect
	legs_area.add_child(legs_shape)
	add_child(legs_area)
	
	# AJUSTAR COLISIÓN PRINCIPAL
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var main_shape = collision_shape.shape as RectangleShape2D
		main_shape.size = Vector2(sprite_width - 10, sprite_height - 10)
		collision_shape.position = Vector2(0, 0)

func disable_all_hitboxes():
	"""DESACTIVAR TODAS LAS HITBOXES PARA EVITAR PUNTUACIÓN DESPUÉS DE LA MUERTE"""
	if head_area:
		head_area.set_deferred("collision_layer", 0)
		head_area.set_deferred("collision_mask", 0)
		for child in head_area.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)
	
	if body_area:
		body_area.set_deferred("collision_layer", 0)
		body_area.set_deferred("collision_mask", 0)
		for child in body_area.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)
	
	if legs_area:
		legs_area.set_deferred("collision_layer", 0)
		legs_area.set_deferred("collision_mask", 0)
		for child in legs_area.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)

func setup_animation_system():
	"""Configurar sistema de animaciones"""
	if sprite and sprite is Sprite2D:
		sprite.queue_free()
	
	animated_sprite = AnimatedSprite2D.new()
	animated_sprite.name = "AnimatedSprite2D"
	add_child(animated_sprite)
	sprite = animated_sprite
	
	load_zombie_atlas()
	create_enemy_animations()

func load_zombie_atlas():
	"""Cargar atlas de zombie"""
	var atlas_path = "res://sprites/enemies/zombie/walk_Right_Down.png"
	if ResourceLoader.exists(atlas_path):
		zombie_atlas = load(atlas_path) as Texture2D
	else:
		create_fallback_zombie_texture()

func create_fallback_zombie_texture():
	"""Crear textura básica de zombie"""
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var color = get_enemy_base_color()
	image.fill(color)
	
	var center = Vector2(64, 64)
	for x in range(128):
		for y in range(128):
			var dist = Vector2(x, y).distance_to(center)
			if dist < 20: image.set_pixel(x, y, Color.WHITE)
			elif dist < 30: image.set_pixel(x, y, color.darkened(0.3))
	
	zombie_atlas = ImageTexture.create_from_image(image)

func create_enemy_animations():
	"""Crear animaciones específicas por tipo de enemigo"""
	sprite_frames = SpriteFrames.new()
	
	sprite_frames.add_animation("idle")
	sprite_frames.set_animation_speed("idle", 4.0)
	sprite_frames.set_animation_loop("idle", true)
	
	sprite_frames.add_animation("walk")
	sprite_frames.set_animation_speed("walk", get_animation_speed())
	sprite_frames.set_animation_loop("walk", true)
	
	if zombie_atlas:
		for i in range(8):
			var frame = extract_frame_from_atlas(i)
			if i == 0:
				sprite_frames.add_frame("idle", frame)
			sprite_frames.add_frame("walk", frame)
	
	animated_sprite.sprite_frames = sprite_frames
	animated_sprite.play("idle")
	apply_enemy_type_modifications_improved()

func extract_frame_from_atlas(frame_index: int) -> Texture2D:
	"""Extraer frame del atlas"""
	var frame_width = zombie_atlas.get_size().x / 8.0
	var atlas_frame = AtlasTexture.new()
	atlas_frame.atlas = zombie_atlas
	atlas_frame.region = Rect2(frame_index * frame_width, 0, frame_width, zombie_atlas.get_size().y)
	return atlas_frame

func apply_enemy_type_modifications_improved():
	"""Aplicar modificaciones específicas por tipo"""
	if not animated_sprite:
		return
	
	animated_sprite.visible = true
	animated_sprite.modulate.a = 1.0
	
	match enemy_type:
		"zombie_crawler":
			animated_sprite.scale = Vector2(0.7, 0.7)
			animated_sprite.modulate = Color(0.2, 1.0, 0.2, 1.0)
		"zombie_dog":
			animated_sprite.scale = Vector2(1.0, 1.0)
			animated_sprite.modulate = Color(1.0, 0.2, 0.2, 1.0)
			animated_sprite.rotation_degrees = -90
		_:
			animated_sprite.scale = Vector2(1.0, 1.0)
			animated_sprite.modulate = Color(0.8, 0.8, 0.6, 1.0)

func get_animation_speed() -> float:
	match enemy_type:
		"zombie_dog": return 10.0
		"zombie_crawler": return 12.0
		_: return 10.0

func get_enemy_base_color() -> Color:
	match enemy_type:
		"zombie_dog": return Color(1.0, 0.2, 0.2, 1.0)
		"zombie_crawler": return Color(0.2, 1.0, 0.2, 1.0)
		_: return Color(0.8, 0.8, 0.6, 1.0)

func _physics_process(delta):
	if is_dead or not player or not is_instance_valid(player):
		return
	
	ensure_sprite_visible()
	
	# Actualizar timers
	search_timer += delta
	barricade_destruction_timer += delta
	barricade_check_timer += delta
	crawler_jump_timer -= delta
	dog_movement_timer += delta
	path_verification_timer += delta
	
	# **SISTEMA DE ATAQUE PRIORITARIO - SE EJECUTA SIEMPRE PRIMERO**
	execute_continuous_attack_system()
	
	# SISTEMA ANTI-STUCK MEJORADO
	update_smart_anti_stuck_system_improved(delta)
	
	# DETECCIÓN INSTANTÁNEA DE BARRICADAS SIN TABLONES
	check_barricades_instant_jump()
	
	# VERIFICAR SOLO SI NECESITA IR A BARRICADAS
	check_if_barricades_needed()
	
	# PATHFINDING INTELIGENTE
	update_intelligent_pathfinding(delta)
	
	# SISTEMA DE IA MEJORADO
	update_improved_ai(delta)
	
	# MECÁNICAS ESPECÍFICAS POR TIPO
	update_type_specific_mechanics(delta)
	
	# Actualizar animaciones
	update_animations_with_flip()
	
	# Mover SIN TELEPORT
	move_and_slide()

func execute_continuous_attack_system():
	"""**SISTEMA DE ATAQUE CONTINUO - MÁXIMA PRIORIDAD - SIN INTERFERENCIAS**"""
	# NO VERIFICAR ESTADOS - SOLO CONDICIONES BÁSICAS
	if not player or not is_instance_valid(player):
		return
	
	if is_dead:
		return
	
	# VERIFICAR DISTANCIA
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player > attack_range:
		return
	
	# VERIFICAR COOLDOWN INDIVIDUAL
	var current_time = Time.get_ticks_msec() / 1000.0
	if (current_time - last_attack_time) < attack_cooldown:
		return
	
	# VERIFICAR LÍNEA DE VISTA SIMPLE
	if not has_clear_line_of_sight_simple():
		return
	
	# EJECUTAR ATAQUE INMEDIATO
	execute_immediate_attack()

func has_clear_line_of_sight_simple() -> bool:
	"""Verificación de línea de vista ultra-simple"""
	if not player:
		return false
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		player.global_position
	)
	query.collision_mask = 3  # Solo paredes y barricadas sólidas
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
	# Si no hay obstáculos, puede atacar
	if result.is_empty():
		return true
	
	# Si hay obstáculo, verificar si es barricada sin tablones
	var collider = result.get("collider")
	if collider and collider is StaticBody2D:
		var parent = collider.get_parent()
		if parent and parent.name.begins_with("Barricade_"):
			var planks = get_safe_barricade_planks(parent)
			return planks == 0
	
	return false

func execute_immediate_attack():
	"""Ejecutar ataque inmediato y garantizado"""
	# ACTUALIZAR TIEMPO INMEDIATAMENTE PARA EVITAR SOLAPAMIENTO
	last_attack_time = Time.get_ticks_msec() / 1000.0
	
	# APLICAR DAÑO DIRECTO
	if player and player.has_method("take_damage"):
		player.take_damage(damage)
	# EFECTO VISUAL MÍNIMO Y AUTOLIMPIANTE
	create_minimal_attack_effect()

func create_minimal_attack_effect():
	"""Crear efecto visual mínimo que se autolimpia"""
	if not player:
		return
	
	# Solo una línea simple
	var attack_line = Line2D.new()
	attack_line.width = 4.0
	attack_line.default_color = get_attack_color()
	attack_line.z_index = 60
	attack_line.add_point(global_position)
	attack_line.add_point(player.global_position)
	get_tree().current_scene.add_child(attack_line)
	
	# AUTOLIMPIEZA INMEDIATA
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 0.15  # MUY RÁPIDO
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(func():
		if is_instance_valid(attack_line):
			attack_line.queue_free()
		cleanup_timer.queue_free()
	)
	get_tree().current_scene.add_child(cleanup_timer)
	cleanup_timer.start()

func get_attack_color() -> Color:
	"""Obtener color de ataque según tipo"""
	match enemy_type:
		"zombie_dog": return Color.RED
		"zombie_crawler": return Color.GREEN
		_: return Color.ORANGE

func check_barricades_instant_jump():
	"""Verificar barricadas sin tablones para salto instantáneo"""
	if not wall_system or is_jumping:
		return
	
	for barricade in wall_system.get_all_barricades():
		if not is_instance_valid(barricade):
			continue
		
		var distance = global_position.distance_to(barricade.global_position)
		if distance > 200.0:
			continue
		
		var current_planks = get_safe_barricade_planks(barricade)
		if current_planks == 0:
			current_state = EnemyState.JUMPING
			reset_barricade_attack_state()
			return

func update_intelligent_pathfinding(delta):
	"""Sistema de pathfinding inteligente"""
	if is_on_wall() or is_stuck_against_wall():
		path_blocked_timer += delta
		
		if path_blocked_timer >= 2.0:
			path_blocked_timer = 0.0
			handle_wall_blockage()
	else:
		path_blocked_timer = 0.0
		is_searching_alternate_route = false
		alternate_route_attempts = 0

func is_stuck_against_wall() -> bool:
	"""Verificar si está atascado contra una pared"""
	var space_state = get_world_2d().direct_space_state
	var direction_to_player = (player.global_position - global_position).normalized()
	
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + direction_to_player * 100.0
	)
	query.collision_mask = 3
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
	if not result.is_empty():
		var collider = result.get("collider")
		if collider and collider is StaticBody2D:
			var parent = collider.get_parent()
			if not (parent and parent.name.begins_with("Barricade_")):
				return true
	
	return false

func handle_wall_blockage():
	"""Manejar bloqueo por paredes"""
	if not is_searching_alternate_route:
		is_searching_alternate_route = true
		alternate_route_attempts = 0
	
	alternate_route_attempts += 1
	
	if alternate_route_attempts <= max_route_attempts:
		attempt_alternate_route()
	else:
		# **VERIFICACIÓN PRE-SALTO PARA ENEMIGOS BÁSICOS**
		if enemy_type == "zombie_basic":
			check_barricades_before_jumping()
		else:
			current_state = EnemyState.JUMPING
		
		is_searching_alternate_route = false
		alternate_route_attempts = 0

func check_barricades_before_jumping():
	"""**VERIFICACIÓN PRE-SALTO - ENEMIGOS BÁSICOS VERIFICAN BARRICADAS PRIMERO**"""
	# PRIORIDAD 1: Buscar barricadas vacías para ir hacia ellas
	var empty_barricade = find_nearby_empty_barricade()
	if empty_barricade:
		target_barricade = empty_barricade
		current_state = EnemyState.MOVING_TO_PLAYER  # Se dirige hacia la barricada vacía
		return
	
	# PRIORIDAD 2: Buscar barricadas con tablones para destruir
	var blocking_barricade = find_blocking_barricade()
	if blocking_barricade:
		target_barricade = blocking_barricade
		current_state = EnemyState.ATTACKING_BARRICADE
		is_attacking_barricade = true
		return
	
	# PRIORIDAD 3: Solo saltar si no hay barricadas cercanas
	current_state = EnemyState.JUMPING

func find_nearby_empty_barricade() -> Node2D:
	"""Buscar barricadas vacías (0 tablones) cercanas"""
	if not wall_system:
		return null
	
	var nearest_empty_barricade = null
	var nearest_distance = INF
	var search_distance = 300.0  # Radio de búsqueda ampliado
	
	for barricade in wall_system.get_all_barricades():
		if not is_instance_valid(barricade):
			continue
		
		var distance = global_position.distance_to(barricade.global_position)
		if distance > search_distance:
			continue
		
		var current_planks = get_safe_barricade_planks(barricade)
		if current_planks == 0 and distance < nearest_distance:
			nearest_distance = distance
			nearest_empty_barricade = barricade
	
	return nearest_empty_barricade

func attempt_alternate_route():
	"""Intentar ruta alternativa"""
	var alternative_directions = [
		Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN,
		Vector2.LEFT + Vector2.UP, Vector2.RIGHT + Vector2.UP,
		Vector2.LEFT + Vector2.DOWN, Vector2.RIGHT + Vector2.DOWN
	]
	
	for direction in alternative_directions:
		if can_move_in_direction(direction):
			velocity = direction.normalized() * get_normal_speed()
			return
	
	# Si no puede moverse en ninguna dirección alternativa
	if enemy_type == "zombie_basic":
		check_barricades_before_jumping()
	else:
		current_state = EnemyState.JUMPING

func can_move_in_direction(direction: Vector2) -> bool:
	"""Verificar si puede moverse en una dirección específica"""
	var space_state = get_world_2d().direct_space_state
	
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + direction.normalized() * 150.0
	)
	query.collision_mask = 3
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func update_smart_anti_stuck_system_improved(delta):
	"""SISTEMA ANTI-STUCK MEJORADO con mejor detección"""
	var movement_threshold = 15.0
	var current_distance = global_position.distance_to(last_position)
	
	if current_distance < movement_threshold:
		stuck_timer += delta
	else:
		stuck_timer = 0.0
		last_position = global_position
	
	if stuck_timer > 3.0:
		handle_advanced_stuck_situation()
		stuck_timer = 0.0

func handle_advanced_stuck_situation():
	"""Manejar situación de atasco avanzada"""
	if enemy_type == "zombie_basic":
		check_barricades_before_jumping()
	else:
		current_state = EnemyState.JUMPING

func check_if_barricades_needed():
	"""VERIFICAR SI NECESITA IR A BARRICADAS"""
	if not wall_system or is_jumping:
		return
	
	if path_verification_timer >= 1.0:
		path_verification_timer = 0.0
		
		if has_clear_path_to_player():
			# Tiene ruta libre - ir al jugador
			if current_state == EnemyState.SEARCHING_BARRICADE or current_state == EnemyState.ATTACKING_BARRICADE:
				current_state = EnemyState.MOVING_TO_PLAYER
				reset_barricade_attack_state()
			return
		else:
			# NO tiene ruta libre - usar lógica específica por tipo
			if current_state == EnemyState.MOVING_TO_PLAYER:
				handle_blocked_path()

func handle_blocked_path():
	"""Manejar cuando el camino está bloqueado - LÓGICA ESPECÍFICA POR TIPO"""
	match enemy_type:
		"zombie_crawler", "zombie_dog":
			# Crawlers y perros saltan directamente
			current_state = EnemyState.JUMPING
		
		"zombie_basic":
			# ENEMIGOS BÁSICOS: VERIFICAR BARRICADAS PRIMERO
			check_barricades_before_jumping()

func has_clear_path_to_player() -> bool:
	"""VERIFICAR SI TIENE RUTA LIBRE AL JUGADOR"""
	if not player:
		return false
	
	var space_state = get_world_2d().direct_space_state
	var direction_to_player = (player.global_position - global_position).normalized()
	var distance_to_player = global_position.distance_to(player.global_position)
	
	var clear_paths = 0
	var total_checks = 3
	
	for i in range(total_checks):
		var angle_offset = deg_to_rad((-10 + i * 10))
		var check_direction = direction_to_player.rotated(angle_offset)
		
		var query = PhysicsRayQueryParameters2D.create(
			global_position, 
			global_position + check_direction * min(distance_to_player, 800.0)
		)
		query.collision_mask = 3
		query.exclude = [self]
		
		var result = space_state.intersect_ray(query)
		
		if result.is_empty():
			clear_paths += 1
		else:
			var collider = result.get("collider")
			if collider and collider is StaticBody2D:
				var parent = collider.get_parent()
				if parent and parent.name.begins_with("Barricade_"):
					var planks = get_safe_barricade_planks(parent)
					if planks == 0:
						clear_paths += 1
	
	return clear_paths >= 2

func find_blocking_barricade() -> Node2D:
	"""ENCONTRAR LA BARRICADA QUE ESTÁ BLOQUEANDO EL CAMINO"""
	if not wall_system:
		return null
	
	var space_state = get_world_2d().direct_space_state
	var direction_to_player = (player.global_position - global_position).normalized()
	
	var query = PhysicsRayQueryParameters2D.create(
		global_position, 
		global_position + direction_to_player * 300.0
	)
	query.collision_mask = 3
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
	if not result.is_empty():
		var collider = result.get("collider")
		if collider and collider is StaticBody2D:
			var parent = collider.get_parent()
			if parent and parent.name.begins_with("Barricade_"):
				var planks = get_safe_barricade_planks(parent)
				if planks > 0:
					return parent
	
	return null

func update_improved_ai(delta):
	"""SISTEMA DE IA MEJORADO"""
	
	match current_state:
		EnemyState.MOVING_TO_PLAYER:
			execute_movement_to_player_with_derrap()
		
		EnemyState.SEARCHING_BARRICADE:
			execute_barricade_search()
			
			if search_timer >= 3.0:
				search_timer = 0.0
				var nearby_barricade = find_nearest_barricade()
				if nearby_barricade:
					target_barricade = nearby_barricade
					current_state = EnemyState.ATTACKING_BARRICADE
					is_attacking_barricade = true
				else:
					if enemy_type == "zombie_basic":
						check_barricades_before_jumping()
					else:
						current_state = EnemyState.JUMPING
		
		EnemyState.ATTACKING_BARRICADE:
			execute_barricade_attack_enhanced(delta)
		
		EnemyState.JUMPING:
			execute_emergency_jump()

func execute_movement_to_player_with_derrap():
	"""Movimiento al jugador CON DERRAPAJE PARA PERROS"""
	var direction = (player.global_position - global_position).normalized()
	
	if enemy_type == "zombie_dog":
		dog_movement_timer += get_physics_process_delta_time()
		if dog_movement_timer >= 1.5:
			dog_movement_timer = 0.0
			var perpendicular = Vector2(-direction.y, direction.x)
			dog_derrap_offset = perpendicular * randf_range(-100, 100)
		
		var target_pos = player.global_position + dog_derrap_offset
		direction = (target_pos - global_position).normalized()
	
	velocity = direction * get_normal_speed()
	current_direction = direction
	last_movement_direction = direction

func execute_barricade_search():
	"""Búsqueda de barricadas"""
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * get_search_speed()
	current_direction = direction
	last_movement_direction = direction

func execute_barricade_attack_enhanced(_delta):
	"""ATACAR BARRICADA CON DETECCIÓN MEJORADA"""
	if not target_barricade or not is_instance_valid(target_barricade) or target_barricade == null:
		reset_barricade_attack_state()
		return
	
	if not is_touching_barricade_area_enhanced(target_barricade):
		var direction = (target_barricade.global_position - global_position).normalized()
		velocity = direction * get_normal_speed()
		current_direction = direction
		last_movement_direction = direction
		is_attacking_barricade = false
		return
	
	var current_planks = get_safe_barricade_planks(target_barricade)
	
	if current_planks <= 0:
		current_state = EnemyState.MOVING_TO_PLAYER
		reset_barricade_attack_state()
		return
	
	velocity = Vector2.ZERO
	is_attacking_barricade = true
	
	if barricade_destruction_timer >= 0.6:
		barricade_destruction_timer = 0.0
		damage_barricade_immediate()

func damage_barricade_immediate():
	"""DAÑAR BARRICADA INMEDIATAMENTE CON VERIFICACIONES SEGURAS"""
	if not target_barricade or not is_instance_valid(target_barricade) or target_barricade == null or not wall_system:
		reset_barricade_attack_state()
		return
	
	var damage_amount = get_barricade_damage_per_hit()
	
	if wall_system.has_method("damage_barricade"):
		wall_system.damage_barricade(target_barricade, damage_amount)
	
	last_attack_time = Time.get_ticks_msec() / 1000.0
	
	var current_planks = get_safe_barricade_planks(target_barricade)
	if current_planks <= 0:
		current_state = EnemyState.MOVING_TO_PLAYER
		reset_barricade_attack_state()

func execute_emergency_jump():
	"""Saltar como última opción"""
	if is_jumping:
		return
	
	is_jumping = true
	jump_cooldown = get_jump_cooldown_by_type()
	
	var jump_direction = (player.global_position - global_position).normalized()
	var jump_speed = get_normal_speed() * get_jump_multiplier()
	
	collision_layer = 0
	collision_mask = 0
	
	velocity = jump_direction * jump_speed
	
	var jump_timer = Timer.new()
	jump_timer.wait_time = get_jump_duration()
	jump_timer.one_shot = true
	jump_timer.timeout.connect(finish_jump)
	add_child(jump_timer)
	jump_timer.start()

func finish_jump():
	"""Terminar salto CON LIMPIEZA ROBUSTA"""
	is_jumping = false
	current_state = EnemyState.MOVING_TO_PLAYER
	
	reset_barricade_attack_state()
	
	collision_layer = 2
	collision_mask = 1 | 3 | 16
	
	for child in get_children():
		if child is Timer and child.name.begins_with("@Timer"):
			child.queue_free()

func reset_barricade_attack_state():
	"""Resetear estado de ataque a barricada de forma segura"""
	target_barricade = null
	is_attacking_barricade = false

func get_safe_barricade_planks(barricade: Node2D) -> int:
	"""Obtener tablones de barricada de forma segura"""
	if not barricade or not is_instance_valid(barricade) or barricade == null:
		return 0
	
	if not barricade.has_method("get_meta"):
		return 0
	
	return barricade.get_meta("current_planks", 0)

func get_safe_barricade_size(barricade: Node2D) -> Vector2:
	"""Obtener tamaño de barricada de forma segura"""
	if not barricade or not is_instance_valid(barricade) or barricade == null:
		return Vector2(200, 60)
	
	if not barricade.has_method("get_meta"):
		return Vector2(200, 60)
	
	return barricade.get_meta("size", Vector2(200, 60))

func is_touching_barricade_area_enhanced(barricade: Node2D) -> bool:
	"""DETECCIÓN MEJORADA: Área más grande y más permisiva CON VERIFICACIONES SEGURAS"""
	if not barricade or not is_instance_valid(barricade) or barricade == null:
		return false
	
	var barricade_pos = barricade.global_position
	var barricade_size = get_safe_barricade_size(barricade)
	var enemy_pos = global_position
	
	var expanded_size = barricade_size + Vector2(120, 120)
	var half_size = expanded_size / 2.0
	
	var relative_pos = enemy_pos - barricade_pos
	
	return (abs(relative_pos.x) <= half_size.x and abs(relative_pos.y) <= half_size.y)

func find_nearest_barricade() -> Node2D:
	"""Buscar la barricada más cercana CON VERIFICACIONES SEGURAS"""
	if not wall_system:
		return null
	
	var nearest_barricade = null
	var nearest_distance = INF
	var max_search_distance = 300.0
	
	for barricade in wall_system.get_all_barricades():
		if not is_instance_valid(barricade) or barricade == null:
			continue
		
		var distance = global_position.distance_to(barricade.global_position)
		if distance <= max_search_distance and distance < nearest_distance:
			var current_planks = get_safe_barricade_planks(barricade)
			if current_planks > 0:
				nearest_distance = distance
				nearest_barricade = barricade
	
	return nearest_barricade

func update_type_specific_mechanics(delta):
	"""MECÁNICAS ESPECÍFICAS BALANCEADAS POR TIPO"""
	match enemy_type:
		"zombie_crawler":
			update_crawler_balanced_jumping(delta)
		"zombie_dog":
			update_dog_balanced_mechanics(delta)

func update_crawler_balanced_jumping(_delta):
	"""CRAWLERS: Salto balanceado MÁS LENTO"""
	var distance_to_player = global_position.distance_to(player.global_position)
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if distance_to_player < 100.0:
		return
	
	if crawler_jump_timer <= 0.0 and current_time - crawler_last_jump_time > 2.0:
		if current_state == EnemyState.MOVING_TO_PLAYER:
			current_state = EnemyState.JUMPING
			crawler_last_jump_time = current_time
			crawler_jump_timer = 2.0

func update_dog_balanced_mechanics(_delta):
	"""PERROS: Mecánicas balanceadas y justas"""
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player > 200.0 and dog_movement_timer >= 4.0:
		dog_movement_timer = 0.0
		if current_state == EnemyState.MOVING_TO_PLAYER:
			current_state = EnemyState.JUMPING

func get_normal_speed() -> float:
	"""Velocidades BALANCEADAS según el tipo"""
	match enemy_type:
		"zombie_crawler":
			return base_move_speed * 1.2
		"zombie_dog":
			return base_move_speed * 1.3
		_:
			return base_move_speed * 1.2

func get_search_speed() -> float:
	"""Velocidad de búsqueda"""
	return get_normal_speed() * 3.0

func get_barricade_damage_per_hit() -> int:
	"""Daño por hit según tipo de enemigo"""
	return 1

func get_jump_cooldown_by_type() -> float:
	"""Cooldown de salto BALANCEADO por tipo"""
	match enemy_type:
		"zombie_dog": return 2.0
		"zombie_crawler": return 1.0
		_: return 1.5

func get_jump_multiplier() -> float:
	"""Multiplicador de velocidad de salto BALANCEADO"""
	match enemy_type:
		"zombie_dog": return 1.8
		"zombie_crawler": return 2.0
		_: return 1.6

func get_jump_duration() -> float:
	"""Duración del salto"""
	match enemy_type:
		"zombie_dog": return 0.5
		"zombie_crawler": return 0.4
		_: return 0.6

func ensure_sprite_visible():
	"""Asegurar que el sprite esté siempre visible"""
	if animated_sprite:
		if not animated_sprite.visible:
			animated_sprite.visible = true
		if animated_sprite.modulate.a < 1.0:
			animated_sprite.modulate.a = 1.0

func update_animations_with_flip():
	"""Actualizar animaciones con flip horizontal"""
	ensure_sprite_visible()
	
	if not animated_sprite:
		return
	
	var is_moving = velocity.length() > 20.0
	var direction_angle = last_movement_direction.angle()
	var angle_degrees = rad_to_deg(direction_angle)
	
	if angle_degrees < 0:
		angle_degrees += 360
	
	var should_flip = angle_degrees >= 91 and angle_degrees <= 269
	
	if animated_sprite.flip_h != should_flip:
		animated_sprite.flip_h = should_flip
		adjust_hitboxes_for_flip(should_flip)
	
	if is_moving and current_state != EnemyState.ATTACKING_BARRICADE:
		if animated_sprite.animation != "walk":
			animated_sprite.play("walk")
	else:
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")

func adjust_hitboxes_for_flip(is_flipped: bool):
	"""Ajustar hitboxes cuando se voltea"""
	var flip_multiplier = -1 if is_flipped else 1
	
	for area in [head_area, body_area, legs_area]:
		if area and area.get_child_count() > 0:
			var shape = area.get_child(0) as CollisionShape2D
			if shape:
				shape.position.x = abs(shape.position.x) * flip_multiplier

# ==========================================
# SISTEMA DE DAÑO Y MUERTE
# ==========================================

func take_damage(amount: int, is_headshot: bool = false, hit_height: float = 0.5):
	"""Sistema de daño CORREGIDO - DESACTIVAR HITBOXES AL MORIR"""
	if is_dead:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	if has_meta("last_damage_time"):
		var last_damage_time = get_meta("last_damage_time", 0.0)
		if current_time - last_damage_time < 0.02:
			return
	
	set_meta("last_damage_time", current_time)
	
	var damage_multiplier = 1.0
	if is_headshot or hit_height > 0.8:
		damage_multiplier = 2.5
	elif hit_height < 0.5:
		damage_multiplier = 0.8
	
	var final_damage = int(float(amount) * damage_multiplier)
	current_health -= final_damage
	current_health = max(current_health, 0)
	
	if animated_sprite:
		var flash_color = Color.YELLOW if is_headshot else Color.RED
		animated_sprite.modulate = flash_color
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", get_enemy_display_color(), 0.15)
	
	damaged.emit(self, final_damage)
	
	if current_health <= 0:
		call_deferred("disable_all_hitboxes")
		die()

func get_enemy_display_color() -> Color:
	"""Obtener color de display del enemigo"""
	match enemy_type:
		"zombie_dog": return Color(1.0, 0.2, 0.2, 1.0)
		"zombie_crawler": return Color(0.2, 1.0, 0.2, 1.0)
		_: return Color(0.8, 0.8, 0.6, 1.0)

func die():
	"""Muerte del enemigo CON LIMPIEZA ROBUSTA"""
	if is_dead:
		return
	
	is_dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	call_deferred("disable_all_hitboxes")
	
	reset_barricade_attack_state()
	
	if animated_sprite:
		animated_sprite.modulate = Color.GRAY
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate:a", 0.3, 1.5)
	
	died.emit(self)

# ==========================================
# CONFIGURACIÓN Y SETUP
# ==========================================

func setup_enemy():
	"""Configurar enemigo CON LIMPIEZA ROBUSTA"""
	is_dead = false
	current_state = EnemyState.MOVING_TO_PLAYER
	collision_layer = 2
	collision_mask = 1 | 3 | 16
	last_position = global_position
	
	reset_barricade_attack_state()

func _setup_variant():
	"""Configurar variante de enemigo BALANCEADA"""
	var rand_val = randf()
	if rand_val < 0.25:
		enemy_type = "zombie_dog"
		base_move_speed = 140.0
		current_move_speed = 140.0
		damage = 1
		attack_range = 80.0
		barricade_attack_range = 150.0
		attack_cooldown = 1.0
	elif rand_val < 0.50:
		enemy_type = "zombie_crawler"
		base_move_speed = 130.0
		current_move_speed = 130.0
		damage = 1
		attack_range = 80.0
		barricade_attack_range = 130.0
		attack_cooldown = 1.0
	else:
		enemy_type = "zombie_basic"
		base_move_speed = 100.0
		current_move_speed = 100.0
		damage = 1
		attack_range = 80.0
		barricade_attack_range = 150.0
		attack_cooldown = 1.0

func setup_for_spawn(target_player: Player, round_health: int = -1):
	"""Configurar para spawn CON LIMPIEZA ROBUSTA"""
	player = target_player
	if round_health > 0:
		max_health = round_health
		current_health = max_health
	
	is_dead = false
	current_state = EnemyState.MOVING_TO_PLAYER
	is_jumping = false
	jump_cooldown = 0.0
	stuck_timer = 0.0
	velocity = Vector2.ZERO
	
	reset_barricade_attack_state()
	
	# Resetear timers
	search_timer = 0.0
	barricade_destruction_timer = 0.0
	barricade_check_timer = 0.0
	last_attack_time = 0.0
	crawler_jump_timer = 0.0
	crawler_last_jump_time = 0.0
	dog_movement_timer = 0.0
	path_verification_timer = 0.0
	
	collision_layer = 2
	collision_mask = 1 | 3 | 16
	
	if animated_sprite:
		animated_sprite.visible = true
		animated_sprite.modulate = get_enemy_display_color()

func set_wall_system(wall_sys: WallSystem):
	wall_system = wall_sys

func reset_for_pool():
	"""Reset para pool CON LIMPIEZA ROBUSTA"""
	is_dead = false
	current_state = EnemyState.MOVING_TO_PLAYER
	is_jumping = false
	jump_cooldown = 0.0
	stuck_timer = 0.0
	velocity = Vector2.ZERO
	
	reset_barricade_attack_state()
	
	search_timer = 0.0
	barricade_destruction_timer = 0.0
	barricade_check_timer = 0.0
	last_attack_time = 0.0
	crawler_jump_timer = 0.0
	crawler_last_jump_time = 0.0
	dog_movement_timer = 0.0
	path_verification_timer = 0.0
	
	collision_layer = 2
	collision_mask = 1 | 3 | 16
	
	set_physics_process(false)

# ==========================================
# FUNCIONES DE ACCESO
# ==========================================

func get_current_health() -> int:
	return current_health
func get_max_health() -> int:
	return max_health
func is_alive() -> bool:
	return current_health > 0 and not is_dead
func get_damage() -> int:
	return damage
func get_enemy_type() -> String:
	return enemy_type
func get_head_area() -> Area2D:
	return head_area
func get_body_area() -> Area2D:
	return body_area
func get_legs_area() -> Area2D:
	return legs_area
