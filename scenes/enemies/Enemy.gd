# scenes/enemies/Enemy.gd - ATAQUES LENTOS + PERROS MENOS AGRESIVOS + HEALTH BAR MEJORADA
extends CharacterBody2D
class_name Enemy
signal died(enemy: Enemy)
signal damaged(enemy: Enemy, damage: int)

@export var enemy_type: String = "zombie_basic"
@export var max_health: int = 150
@export var current_health: int = 150
@export var base_move_speed: float = 120.0
@export var damage: int = 1
@export var attack_range: float = 180.0
@export var barricade_attack_range: float = 200.0
@export var detection_range: float = 1400.0
@export var attack_cooldown: float = 1.0

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

# 🎯 HITBOXES COMPLETAS QUE CUBREN TODO EL SPRITE
var head_area: Area2D
var body_area: Area2D
var legs_area: Area2D
var full_sprite_height: float = 128.0
var full_sprite_width: float = 64.0

# SISTEMA DE IA CON BARRICADAS MEJORADO
var wall_system: WallSystem
var target_barricade: Node2D = null
var is_attacking_barricade: bool = false

# 🚀 SISTEMA DE NAVEGACIÓN ANTI-SOLAPAMIENTO
var stuck_timer: float = 0.0
var last_position: Vector2
var jump_cooldown: float = 0.0
var is_jumping: bool = false
var path_blocked_timer: float = 0.0
var collision_avoidance_range: float = 80.0

# Estados de pathfinding mejorado
var is_searching_alternate_route: bool = false
var alternate_route_attempts: int = 0
var max_route_attempts: int = 3

# MECÁNICAS ESPECÍFICAS POR TIPO - PERROS MENOS AGRESIVOS
var crawler_jump_timer: float = 0.0
var crawler_last_jump_time: float = 0.0
var dog_movement_timer: float = 0.0
var dog_derrap_offset: Vector2 = Vector2.ZERO
var dog_aggression_cooldown: float = 0.0  # NUEVO: Cooldown para perros

# ESTADOS SIMPLES
enum EnemyState { 
	MOVING_TO_PLAYER,           
	SEARCHING_BARRICADE,        
	ATTACKING_BARRICADE,        
	JUMPING                     
}
var current_state: EnemyState = EnemyState.MOVING_TO_PLAYER

# 🔍 VARIABLES PARA BÚSQUEDA MEJORADA DE BARRICADAS
var search_timer: float = 0.0
var barricade_destruction_timer: float = 0.0
var barricade_check_timer: float = 0.0
var path_verification_timer: float = 0.0
var barricade_search_range: float = 500.0

# 🆕 SISTEMA DE ATAQUES LENTOS QUE VIAJAN
var is_launching_attack: bool = false
var attack_projectiles: Array = []

# 📊 HEALTH BAR MEJORADA
var health_label: Label

func _ready():
	add_to_group("enemies")
	setup_enemy()
	call_deferred("_setup_variant")
	call_deferred("setup_animation_system")
	call_deferred("setup_complete_hitboxes")
	call_deferred("setup_improved_health_bar")
	last_position = global_position

func setup_improved_health_bar():
	"""📊 CONFIGURAR HEALTH BAR MÁS GRANDE CON NÚMEROS"""
	if health_bar:
		# Hacer barra más grande
		health_bar.size = Vector2(80, 16)  # Más ancha y alta
		health_bar.position = Vector2(-40, -60)  # Más arriba
		
		# Configurar colores
		health_bar.show_percentage = false
		
		# Estilo personalizado
		var style_bg = StyleBoxFlat.new()
		style_bg.bg_color = Color(0.2, 0.0, 0.0, 0.8)  # Fondo rojo oscuro
		style_bg.border_color = Color.BLACK
		style_bg.border_width_left = 2
		style_bg.border_width_right = 2
		style_bg.border_width_top = 2
		style_bg.border_width_bottom = 2
		health_bar.add_theme_stylebox_override("background", style_bg)
		
		var style_fill = StyleBoxFlat.new()
		style_fill.bg_color = Color.RED
		health_bar.add_theme_stylebox_override("fill", style_fill)
		
		# Añadir label con números
		health_label = Label.new()
		health_label.name = "HealthLabel"
		health_label.size = Vector2(80, 16)
		health_label.position = Vector2(-40, -60)
		health_label.add_theme_font_size_override("font_size", 12)
		health_label.add_theme_color_override("font_color", Color.WHITE)
		health_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		health_label.add_theme_constant_override("shadow_offset_x", 1)
		health_label.add_theme_constant_override("shadow_offset_y", 1)
		health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		health_label.text = str(current_health) + "/" + str(max_health)
		add_child(health_label)
	
	update_health_display()

func update_health_display():
	"""Actualizar display de salud"""
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	
	if health_label:
		health_label.text = str(current_health) + "/" + str(max_health)
		
		# Cambiar color según salud
		var health_percentage = float(current_health) / float(max_health)
		if health_percentage > 0.6:
			health_label.add_theme_color_override("font_color", Color.GREEN)
		elif health_percentage > 0.3:
			health_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			health_label.add_theme_color_override("font_color", Color.RED)

func setup_complete_hitboxes():
	"""🎯 CONFIGURAR HITBOXES QUE CUBREN COMPLETAMENTE TODO EL ALTO DEL SPRITE"""
	
	# CALCULAR POSICIONES CORRECTAS PARA CUBRIR TODO EL SPRITE
	# Si el sprite es 128 de alto y está centrado, va de -64 a +64
	var sprite_top = -full_sprite_height / 2.0    # -64
	var sprite_bottom = full_sprite_height / 2.0  # +64
	var area_height = full_sprite_height / 3.0    # 42.67 cada área
	
	# ÁREA DE CABEZA - 1/3 SUPERIOR (de -64 a -21.33)
	head_area = Area2D.new()
	head_area.name = "HeadArea"
	head_area.collision_layer = 8
	head_area.collision_mask = 0
	
	var head_shape = CollisionShape2D.new()
	var head_rect = RectangleShape2D.new()
	head_rect.size = Vector2(full_sprite_width, area_height)
	head_shape.position = Vector2(0, sprite_top + area_height / 2.0)  # -42.67
	head_shape.shape = head_rect
	head_area.add_child(head_shape)
	add_child(head_area)
	
	# ÁREA DE CUERPO - 1/3 CENTRAL (de -21.33 a +21.33)
	body_area = Area2D.new()
	body_area.name = "BodyArea"
	body_area.collision_layer = 8
	body_area.collision_mask = 0
	
	var body_shape = CollisionShape2D.new()
	var body_rect = RectangleShape2D.new()
	body_rect.size = Vector2(full_sprite_width, area_height)
	body_shape.position = Vector2(0, 0)  # Centro exacto
	body_shape.shape = body_rect
	body_area.add_child(body_shape)
	add_child(body_area)
	
	# ÁREA DE PIERNAS - 1/3 INFERIOR (de +21.33 a +64)
	legs_area = Area2D.new()
	legs_area.name = "LegsArea"
	legs_area.collision_layer = 8
	legs_area.collision_mask = 0
	
	var legs_shape = CollisionShape2D.new()
	var legs_rect = RectangleShape2D.new()
	legs_rect.size = Vector2(full_sprite_width, area_height)
	legs_shape.position = Vector2(0, sprite_bottom - area_height / 2.0)  # +42.67
	legs_shape.shape = legs_rect
	legs_area.add_child(legs_shape)
	add_child(legs_area)
	
	# 🔧 AJUSTAR COLISIÓN PRINCIPAL PARA EVITAR SOLAPAMIENTO
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var main_shape = collision_shape.shape as RectangleShape2D
		main_shape.size = Vector2(full_sprite_width - 5, full_sprite_height - 5)
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
	dog_aggression_cooldown -= delta  # NUEVO: Cooldown para perros
	path_verification_timer += delta
	
	# 🎯 **ATAQUE CON PROYECTIL LENTO HACIA EL JUGADOR**
	execute_slow_traveling_attack()
	
	# 🚀 SISTEMA ANTI-SOLAPAMIENTO MEJORADO
	update_collision_avoidance_system(delta)
	
	# DETECCIÓN INSTANTÁNEA DE BARRICADAS SIN TABLONES
	check_barricades_instant_jump()
	
	# 🔍 VERIFICAR SI NECESITA IR A BARRICADAS (MEJORADO PARA BÁSICOS)
	check_if_barricades_needed_improved()
	
	# PATHFINDING INTELIGENTE
	update_intelligent_pathfinding(delta)
	
	# SISTEMA DE IA MEJORADO
	update_improved_ai(delta)
	
	# MECÁNICAS ESPECÍFICAS POR TIPO - PERROS MENOS AGRESIVOS
	update_type_specific_mechanics_balanced(delta)
	
	# Actualizar animaciones
	update_animations_with_flip()
	
	# Procesar proyectiles de ataque
	update_attack_projectiles(delta)
	
	# Mover SIN TELEPORT
	move_and_slide()

func execute_slow_traveling_attack():
	"""🎯 ATAQUE QUE VIAJA LENTAMENTE HACIA EL JUGADOR"""
	if not player or not is_instance_valid(player):
		return
	
	if is_dead or is_launching_attack:
		return
	
	# 🎯 VERIFICAR DISTANCIA Y COLISIÓN DIRECTA
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player > attack_range:
		return
	
	# VERIFICAR COOLDOWN
	var current_time = Time.get_ticks_msec() / 1000.0
	if (current_time - last_attack_time) < attack_cooldown:
		return
	
	# ⚡ ATAQUE POR PROXIMIDAD
	if distance_to_player <= 100.0:
		launch_slow_attack_projectile()
		return
	
	# Para distancias medias, verificar línea de vista básica
	if has_basic_line_of_sight():
		launch_slow_attack_projectile()

func launch_slow_attack_projectile():
	"""🚀 LANZAR PROYECTIL DE ATAQUE LENTO"""
	if is_launching_attack:
		return
	
	is_launching_attack = true
	last_attack_time = Time.get_ticks_msec() / 1000.0
	
	# Crear proyectil que viaja hacia el jugador
	var attack_projectile = create_attack_projectile()
	attack_projectiles.append(attack_projectile)
	
	# Timer para permitir siguiente ataque
	var attack_reset_timer = Timer.new()
	attack_reset_timer.wait_time = 0.5  # Medio segundo para el próximo ataque
	attack_reset_timer.one_shot = true
	attack_reset_timer.timeout.connect(func():
		is_launching_attack = false
		attack_reset_timer.queue_free()
	)
	add_child(attack_reset_timer)
	attack_reset_timer.start()

func create_attack_projectile() -> Dictionary:
	"""Crear proyectil de ataque visual"""
	var attack_direction = (player.global_position - global_position).normalized()
	var attack_color = get_attack_color()
	
	# Crear efecto visual del ataque
	var attack_visual = Sprite2D.new()
	var attack_image = Image.create(20, 20, false, Image.FORMAT_RGBA8)
	
	# Crear círculo de ataque
	var center = Vector2(10, 10)
	for x in range(20):
		for y in range(20):
			var dist = Vector2(x, y).distance_to(center)
			if dist < 8:
				attack_image.set_pixel(x, y, attack_color)
			elif dist < 10:
				attack_image.set_pixel(x, y, attack_color.darkened(0.3))
	
	attack_visual.texture = ImageTexture.create_from_image(attack_image)
	attack_visual.global_position = global_position
	attack_visual.z_index = 60
	get_tree().current_scene.add_child(attack_visual)
	
	return {
		"visual": attack_visual,
		"direction": attack_direction,
		"speed": 150.0,  # VELOCIDAD LENTA
		"start_time": Time.get_ticks_msec() / 1000.0,
		"lifetime": 3.0,
		"damage": damage,
		"has_hit": false
	}

func update_attack_projectiles(delta):
	"""Actualizar proyectiles de ataque"""
	var current_time = Time.get_ticks_msec() / 1000.0
	var projectiles_to_remove = []
	
	for i in range(attack_projectiles.size()):
		var projectile = attack_projectiles[i]
		
		# Verificar tiempo de vida
		if current_time - projectile.start_time > projectile.lifetime:
			cleanup_projectile(projectile)
			projectiles_to_remove.append(i)
			continue
		
		# Mover proyectil
		if is_instance_valid(projectile.visual):
			var movement = projectile.direction * projectile.speed * delta
			projectile.visual.global_position += movement
			
			# Verificar colisión con jugador
			if not projectile.has_hit and player and is_instance_valid(player):
				var distance_to_player = projectile.visual.global_position.distance_to(player.global_position)
				if distance_to_player < 40.0:  # Radio de colisión
					# ¡IMPACTO!
					if player.has_method("take_damage"):
						player.take_damage(projectile.damage)
					
					create_player_impact_effect_from_projectile(projectile.visual.global_position)
					projectile.has_hit = true
					cleanup_projectile(projectile)
					projectiles_to_remove.append(i)
		else:
			projectiles_to_remove.append(i)
	
	# Remover proyectiles terminados
	for i in range(projectiles_to_remove.size() - 1, -1, -1):
		var index = projectiles_to_remove[i]
		if index < attack_projectiles.size():
			attack_projectiles.remove_at(index)

func cleanup_projectile(projectile):
	"""Limpiar proyectil"""
	if projectile.has("visual") and is_instance_valid(projectile.visual):
		projectile.visual.queue_free()

func create_player_impact_effect_from_projectile(impact_pos: Vector2):
	"""📳 CREAR EFECTO DE IMPACTO EN EL JUGADOR desde proyectil"""
	if not player or not player.animated_sprite:
		return
	
	# Flash rojo en el jugador
	var original_modulate = player.animated_sprite.modulate
	player.animated_sprite.modulate = Color(2.0, 0.5, 0.5, 1.0)
	
	var tween = create_tween()
	tween.tween_property(player.animated_sprite, "modulate", original_modulate, 0.15)
	
	# Efecto adicional en el punto de impacto
	for i in range(8):
		var particle = Sprite2D.new()
		var particle_size = 6
		var particle_image = Image.create(particle_size, particle_size, false, Image.FORMAT_RGBA8)
		particle_image.fill(Color.ORANGE)
		particle.texture = ImageTexture.create_from_image(particle_image)
		particle.global_position = impact_pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		get_tree().current_scene.add_child(particle)
		
		var particle_tween = create_tween()
		particle_tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.5)
		particle_tween.parallel().tween_property(particle, "global_position", 
			particle.global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30)), 0.5)
		particle_tween.tween_callback(func():
			if is_instance_valid(particle):
				particle.queue_free()
		)

func has_basic_line_of_sight() -> bool:
	"""Verificación básica de línea de vista - MÁS PERMISIVA"""
	if not player:
		return false
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		player.global_position
	)
	query.collision_mask = 3  # Solo paredes sólidas y barricadas
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
	# Si no hay obstáculos, puede atacar
	if result.is_empty():
		return true
	
	# Si hay una barricada sin tablones, también puede atacar
	var collider = result.get("collider")
	if collider and collider is StaticBody2D:
		var parent = collider.get_parent()
		if parent and parent.name.begins_with("Barricade_"):
			var planks = get_safe_barricade_planks(parent)
			return planks == 0
	
	# Si está muy cerca del jugador, ignorar obstáculos menores
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player <= 80.0:
		return true
	
	return false

func get_attack_color() -> Color:
	"""Obtener color de ataque según tipo"""
	match enemy_type:
		"zombie_dog": return Color.RED
		"zombie_crawler": return Color.LIME
		_: return Color.ORANGE

func update_collision_avoidance_system(delta):
	"""🚀 SISTEMA ANTI-SOLAPAMIENTO MEJORADO"""
	var movement_threshold = 15.0
	var current_distance = global_position.distance_to(last_position)
	
	if current_distance < movement_threshold:
		stuck_timer += delta
	else:
		stuck_timer = 0.0
		last_position = global_position
	
	# Evitar solapamiento con otros enemigos
	avoid_enemy_overlap()
	
	if stuck_timer > 3.0:
		handle_advanced_stuck_situation()
		stuck_timer = 0.0

func avoid_enemy_overlap():
	"""🚀 EVITAR SOLAPAMIENTO CON OTROS ENEMIGOS"""
	var nearby_enemies = get_tree().get_nodes_in_group("enemies")
	
	for other_enemy in nearby_enemies:
		if other_enemy == self or not is_instance_valid(other_enemy):
			continue
		
		var distance = global_position.distance_to(other_enemy.global_position)
		if distance < collision_avoidance_range and distance > 0:
			# Calcular dirección de separación
			var separation_direction = (global_position - other_enemy.global_position).normalized()
			var push_force = (collision_avoidance_range - distance) / collision_avoidance_range
			
			# Aplicar separación suave
			velocity += separation_direction * push_force * 100.0

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

func check_if_barricades_needed_improved():
	"""🔍 VERIFICAR BARRICADAS - CORREGIDO PARA TODAS LAS DIRECCIONES"""
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
			# NO tiene ruta libre - VERIFICAR DESDE TODAS LAS DIRECCIONES
			if current_state == EnemyState.MOVING_TO_PLAYER:
				handle_blocked_path_all_directions()

func handle_blocked_path_all_directions():
	"""🔍 MANEJAR CAMINO BLOQUEADO DESDE CUALQUIER DIRECCIÓN"""
	match enemy_type:
		"zombie_crawler", "zombie_dog":
			# Crawlers y perros saltan directamente
			current_state = EnemyState.JUMPING
		
		"zombie_basic":
			# 🎯 ENEMIGOS BÁSICOS: VERIFICAR BARRICADAS O SALTAR
			if not search_for_barricades_actively():
				# Si no encuentra barricadas, saltar inmediatamente
				current_state = EnemyState.JUMPING

func search_for_barricades_actively() -> bool:
	"""🎯 BÚSQUEDA ACTIVA DE BARRICADAS - RETORNA true SI ENCUENTRA ALGO"""
	# PRIORIDAD 1: Buscar barricadas vacías cercanas
	var empty_barricade = find_nearby_empty_barricade_extended()
	if empty_barricade:
		target_barricade = empty_barricade
		current_state = EnemyState.MOVING_TO_PLAYER
		return true
	
	# PRIORIDAD 2: Buscar barricadas con tablones para destruir
	var blocking_barricade = find_blocking_barricade_with_increased_range()
	if blocking_barricade:
		target_barricade = blocking_barricade
		current_state = EnemyState.ATTACKING_BARRICADE
		is_attacking_barricade = true
		return true
	
	# PRIORIDAD 3: Buscar barricadas en rango amplio
	var distant_barricade = find_any_barricade_in_wide_range()
	if distant_barricade:
		target_barricade = distant_barricade
		current_state = EnemyState.SEARCHING_BARRICADE
		return true
	
	# NO ENCONTRÓ NADA - necesita saltar
	return false

func find_nearby_empty_barricade_extended() -> Node2D:
	"""🔍 BUSCAR BARRICADAS VACÍAS EN RANGO EXTENDIDO"""
	if not wall_system:
		return null
	
	var nearest_empty_barricade = null
	var nearest_distance = INF
	
	for barricade in wall_system.get_all_barricades():
		if not is_instance_valid(barricade):
			continue
		
		var distance = global_position.distance_to(barricade.global_position)
		if distance > barricade_search_range:
			continue
		
		var current_planks = get_safe_barricade_planks(barricade)
		if current_planks == 0 and distance < nearest_distance:
			nearest_distance = distance
			nearest_empty_barricade = barricade
	
	return nearest_empty_barricade

func find_blocking_barricade_with_increased_range() -> Node2D:
	"""🔍 ENCONTRAR BARRICADA BLOQUEANTE CON RANGO AUMENTADO PARA DESTRUCCIÓN"""
	if not wall_system:
		return null
	
	var space_state = get_world_2d().direct_space_state
	var direction_to_player = (player.global_position - global_position).normalized()
	
	# RANGO AUMENTADO PARA DESTRUIR TABLONES DESDE ARRIBA Y ABAJO
	var extended_search_range = barricade_search_range * 1.5  # 750 en lugar de 500
	
	var query = PhysicsRayQueryParameters2D.create(
		global_position, 
		global_position + direction_to_player * extended_search_range
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

func find_any_barricade_in_wide_range() -> Node2D:
	"""🔍 ENCONTRAR CUALQUIER BARRICADA EN RANGO MUY AMPLIO"""
	if not wall_system:
		return null
	
	var nearest_barricade = null
	var nearest_distance = INF
	var wide_search_range = barricade_search_range * 2.0  # 1000 unidades
	
	for barricade in wall_system.get_all_barricades():
		if not is_instance_valid(barricade):
			continue
		
		var distance = global_position.distance_to(barricade.global_position)
		if distance <= wide_search_range and distance < nearest_distance:
			var current_planks = get_safe_barricade_planks(barricade)
			if current_planks > 0:
				nearest_distance = distance
				nearest_barricade = barricade
	
	return nearest_barricade

func execute_emergency_jump():
	"""🚀 SALTAR EVITANDO SOLAPAMIENTO CON JUGADOR Y OTROS ENEMIGOS"""
	if is_jumping:
		return
	
	is_jumping = true
	jump_cooldown = get_jump_cooldown_by_type()
	
	# 🎯 CALCULAR POSICIÓN DE ATERRIZAJE SEGURA
	var safe_landing_pos = calculate_safe_landing_position()
	var jump_direction = (safe_landing_pos - global_position).normalized()
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

func calculate_safe_landing_position() -> Vector2:
	"""🎯 CALCULAR POSICIÓN DE ATERRIZAJE SEGURA SIN SOLAPAMIENTO"""
	var base_target = player.global_position
	var attempts = 0
	var max_attempts = 8
	
	while attempts < max_attempts:
		# Calcular posición con offset aleatorio
		var offset_distance = randf_range(120, 200)  # Mantener distancia del jugador
		var offset_angle = randf() * PI * 2
		var potential_landing = base_target + Vector2.from_angle(offset_angle) * offset_distance
		
		# Verificar que no esté demasiado cerca del jugador
		if potential_landing.distance_to(player.global_position) < 100.0:
			attempts += 1
			continue
		
		# Verificar que no esté demasiado cerca de otros enemigos
		var too_close_to_enemy = false
		var nearby_enemies = get_tree().get_nodes_in_group("enemies")
		for other_enemy in nearby_enemies:
			if other_enemy == self or not is_instance_valid(other_enemy):
				continue
			if potential_landing.distance_to(other_enemy.global_position) < 80.0:
				too_close_to_enemy = true
				break
		
		if not too_close_to_enemy:
			return potential_landing
		
		attempts += 1
	
	# Fallback: posición hacia el jugador pero con distancia segura
	var direction_to_player = (player.global_position - global_position).normalized()
	return player.global_position - (direction_to_player * 150.0)

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
	"""Manejar bloqueo por paredes - CORREGIDO PARA TODAS LAS DIRECCIONES"""
	if not is_searching_alternate_route:
		is_searching_alternate_route = true
		alternate_route_attempts = 0
	
	alternate_route_attempts += 1
	
	if alternate_route_attempts <= max_route_attempts:
		attempt_alternate_route()
	else:
		# FORZAR SALTO DESDE CUALQUIER DIRECCIÓN
		if enemy_type == "zombie_basic":
			# Intentar barricadas una vez más, si no, saltar
			if not search_for_barricades_actively():
				force_jump_from_any_direction()
		else:
			force_jump_from_any_direction()
		
		is_searching_alternate_route = false
		alternate_route_attempts = 0

func attempt_alternate_route():
	"""Intentar ruta alternativa - MEJORADO PARA FORZAR SALTO"""
	var alternative_directions = [
		Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN,
		Vector2.LEFT + Vector2.UP, Vector2.RIGHT + Vector2.UP,
		Vector2.LEFT + Vector2.DOWN, Vector2.RIGHT + Vector2.DOWN
	]
	
	for direction in alternative_directions:
		if can_move_in_direction(direction):
			velocity = direction.normalized() * get_normal_speed()
			return
	
	# Si no puede moverse en NINGUNA dirección alternativa, FORZAR SALTO
	force_jump_from_any_direction()

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

func force_jump_from_any_direction():
	"""FORZAR SALTO DESDE CUALQUIER DIRECCIÓN - ESPECIALMENTE IZQUIERDA"""
	current_state = EnemyState.JUMPING
	
	# DEBUGGING: Verificar desde qué dirección viene el enemigo
	var direction_to_player = (player.global_position - global_position).normalized()
	var player_is_right = direction_to_player.x > 0
	var player_is_left = direction_to_player.x < 0
	
	# Si el jugador está a la derecha y el enemigo viene de la izquierda, forzar salto
	if player_is_right or player_is_left:
		current_state = EnemyState.JUMPING

func handle_advanced_stuck_situation():
	"""Manejar situación de atasco avanzada - MEJORADO"""
	# SIEMPRE saltar cuando está atascado, independiente del tipo
	current_state = EnemyState.JUMPING

func has_clear_path_to_player() -> bool:
	"""VERIFICAR SI TIENE RUTA LIBRE AL JUGADOR - MEJORADO PARA TODAS LAS DIRECCIONES"""
	if not player:
		return false
	
	var space_state = get_world_2d().direct_space_state
	var direction_to_player = (player.global_position - global_position).normalized()
	var distance_to_player = global_position.distance_to(player.global_position)
	
	var clear_paths = 0
	var total_checks = 5  # Más verificaciones
	
	# Verificar múltiples ángulos hacia el jugador
	for i in range(total_checks):
		var angle_offset = deg_to_rad((-20 + i * 10))  # De -20° a +20°
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
	
	# Ser más permisivo para enemigos de la izquierda
	var required_clear_paths = 2
	if direction_to_player.x > 0:  # Enemigo viene desde la izquierda hacia la derecha
		required_clear_paths = 1  # Más permisivo para enemigos de la izquierda
	
	return clear_paths >= required_clear_paths

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
						if not search_for_barricades_actively():
							current_state = EnemyState.JUMPING
					else:
						current_state = EnemyState.JUMPING
		
		EnemyState.ATTACKING_BARRICADE:
			execute_barricade_attack_enhanced(delta)
		
		EnemyState.JUMPING:
			execute_emergency_jump()

func execute_movement_to_player_with_derrap():
	"""Movimiento al jugador CON DERRAPAJE PARA PERROS (MENOS AGRESIVO)"""
	var direction = (player.global_position - global_position).normalized()
	
	if enemy_type == "zombie_dog":
		dog_movement_timer += get_physics_process_delta_time()
		
		# 🐕 PERROS MENOS AGRESIVOS: Más tiempo entre derrapajes
		if dog_movement_timer >= 3.0 and dog_aggression_cooldown <= 0.0:  # Aumentado de 1.5 a 3.0
			dog_movement_timer = 0.0
			dog_aggression_cooldown = 2.0  # Cooldown adicional
			var perpendicular = Vector2(-direction.y, direction.x)
			dog_derrap_offset = perpendicular * randf_range(-60, 60)  # Reducido de 100 a 60
		
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
	"""ATACAR BARRICADA CON RANGO MEJORADO PARA DESTRUIR DESDE ARRIBA Y ABAJO"""
	if not target_barricade or not is_instance_valid(target_barricade) or target_barricade == null:
		reset_barricade_attack_state()
		return
	
	if not is_touching_barricade_area_enhanced_range(target_barricade):
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

func is_touching_barricade_area_enhanced_range(barricade: Node2D) -> bool:
	"""DETECCIÓN MEJORADA CON RANGO AUMENTADO PARA DESTRUIR DESDE ARRIBA Y ABAJO"""
	if not barricade or not is_instance_valid(barricade) or barricade == null:
		return false
	
	var barricade_pos = barricade.global_position
	var barricade_size = get_safe_barricade_size(barricade)
	var enemy_pos = global_position
	
	# RANGO MUCHO MÁS GRANDE PARA PERMITIR ATAQUE DESDE ARRIBA Y ABAJO
	var expanded_size = barricade_size + Vector2(200, 200)  # AUMENTADO de 120 a 200
	var half_size = expanded_size / 2.0
	
	var relative_pos = enemy_pos - barricade_pos
	
	return (abs(relative_pos.x) <= half_size.x and abs(relative_pos.y) <= half_size.y)

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

func update_type_specific_mechanics_balanced(delta):
	"""🐕 MECÁNICAS ESPECÍFICAS BALANCEADAS POR TIPO - PERROS MENOS AGRESIVOS"""
	match enemy_type:
		"zombie_crawler":
			update_crawler_balanced_jumping(delta)
		"zombie_dog":
			update_dog_less_aggressive_mechanics(delta)  # CAMBIADO

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

func update_dog_less_aggressive_mechanics(_delta):
	"""🐕 PERROS: Mecánicas MENOS AGRESIVAS y más justas"""
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# PERROS MENOS AGRESIVOS: Mayor distancia y más tiempo para saltar
	if distance_to_player > 300.0 and dog_movement_timer >= 6.0:  # Aumentado de 200 a 300 y de 4 a 6
		dog_movement_timer = 0.0
		if current_state == EnemyState.MOVING_TO_PLAYER and dog_aggression_cooldown <= 0.0:
			current_state = EnemyState.JUMPING
			dog_aggression_cooldown = 3.0  # Cooldown adicional

func get_normal_speed() -> float:
	"""Velocidades BALANCEADAS según el tipo"""
	match enemy_type:
		"zombie_crawler":
			return base_move_speed * 1.2
		"zombie_dog":
			return base_move_speed * 1.1  # REDUCIDO de 1.3 a 1.1
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
		"zombie_dog": return 3.0  # AUMENTADO de 2.0 a 3.0
		"zombie_crawler": return 1.0
		_: return 1.5

func get_jump_multiplier() -> float:
	"""Multiplicador de velocidad de salto BALANCEADO"""
	match enemy_type:
		"zombie_dog": return 1.6  # REDUCIDO de 1.8 a 1.6
		"zombie_crawler": return 2.0
		_: return 1.6

func get_jump_duration() -> float:
	"""Duración del salto"""
	match enemy_type:
		"zombie_dog": return 0.6  # AUMENTADO de 0.5 a 0.6
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
	
	# Actualizar health bar
	update_health_display()
	
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
	
	# Limpiar proyectiles de ataque
	for projectile in attack_projectiles:
		cleanup_projectile(projectile)
	attack_projectiles.clear()
	
	if animated_sprite:
		animated_sprite.modulate = Color.GRAY
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate:a", 0.3, 1.5)
	
	# Ocultar health bar
	if health_bar:
		health_bar.visible = false
	if health_label:
		health_label.visible = false
	
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
		base_move_speed = 120.0  # REDUCIDO de 140.0
		current_move_speed = 120.0
		damage = 1
		attack_range = 200.0
		barricade_attack_range = 200.0
		attack_cooldown = 1.2  # AUMENTADO de 1.0
	elif rand_val < 0.50:
		enemy_type = "zombie_crawler"
		base_move_speed = 130.0
		current_move_speed = 130.0
		damage = 1
		attack_range = 160.0
		barricade_attack_range = 180.0
		attack_cooldown = 1.0
	else:
		enemy_type = "zombie_basic"
		base_move_speed = 100.0
		current_move_speed = 100.0
		damage = 1
		attack_range = 180.0
		barricade_attack_range = 200.0
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
	
	# LIMPIAR PROYECTILES
	for projectile in attack_projectiles:
		cleanup_projectile(projectile)
	attack_projectiles.clear()
	is_launching_attack = false
	
	# RESETEAR COOLDOWNS DE PERROS
	dog_aggression_cooldown = 0.0
	
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
	
	# Actualizar health bar
	update_health_display()
	if health_bar:
		health_bar.visible = true
	if health_label:
		health_label.visible = true

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
	
	# LIMPIAR PROYECTILES
	for projectile in attack_projectiles:
		cleanup_projectile(projectile)
	attack_projectiles.clear()
	is_launching_attack = false
	
	# RESETEAR COOLDOWNS
	dog_aggression_cooldown = 0.0
	
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
