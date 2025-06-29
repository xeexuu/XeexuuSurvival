# AnimationController.gd - SISTEMA CORREGIDO CON ATLAS Y FLIP ESPECÍFICOS
extends Node
class_name AnimationController
var animated_sprite: AnimatedSprite2D
var sprite_frames: SpriteFrames
var character_name: String
var is_system_ready: bool = false
# Atlas específicos
var walk_right_down_atlas: Texture2D
var walk_right_up_atlas: Texture2D
var walk_left_up_atlas: Texture2D
var walk_left_down_atlas: Texture2D
# Estado de animación
var current_animation: String = "idle"
var is_melee_attacking: bool = false
var last_direction: Vector2 = Vector2.RIGHT  # NUEVA: dirección actual para idle
var last_movement_direction: Vector2 = Vector2.ZERO
func setup(sprite: AnimatedSprite2D, char_name: String):
	animated_sprite = sprite
	character_name = char_name
	load_atlases()
	create_directional_animations()
func load_atlases():
	"""Cargar los cuatro atlas principales"""
	var folder = get_character_folder_name()
	walk_right_down_atlas = load_texture_safe("res://sprites/player/" + folder + "/walk_Right_Down.png")
	walk_right_up_atlas = load_texture_safe("res://sprites/player/" + folder + "/walk_Right_Up.png")
	walk_left_up_atlas = load_texture_safe("res://sprites/player/" + folder + "/walk_Left_Up.png")
	walk_left_down_atlas = load_texture_safe("res://sprites/player/" + folder + "/walk_Left_Down.png")
	# Fallback a chica si no encuentra
	if not walk_right_down_atlas:
		walk_right_down_atlas = load_texture_safe("res://sprites/player/chica/walk_Right_Down.png")
	if not walk_right_up_atlas:
		walk_right_up_atlas = load_texture_safe("res://sprites/player/chica/walk_Right_Up.png")
	if not walk_left_up_atlas:
		walk_left_up_atlas = load_texture_safe("res://sprites/player/chica/walk_Left_Up.png")
	if not walk_left_down_atlas:
		walk_left_down_atlas = load_texture_safe("res://sprites/player/chica/walk_Left_Down.png")
func load_texture_safe(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
func create_directional_animations():
	"""Crear animaciones direccionales corregidas"""
	if not animated_sprite:
		return
	sprite_frames = SpriteFrames.new()
	# IDLE (primer frame de walk_right_down)
	sprite_frames.add_animation("idle")
	sprite_frames.set_animation_speed("idle", 1.0)
	sprite_frames.set_animation_loop("idle", false)
	if walk_right_down_atlas:
		var first_frame = extract_frame(walk_right_down_atlas, 0)
		sprite_frames.add_frame("idle", first_frame)
	# WALK_RIGHT_DOWN - Abajo derecha (315° a 44°)
	sprite_frames.add_animation("walk_right_down")
	sprite_frames.set_animation_speed("walk_right_down", 12.0)
	sprite_frames.set_animation_loop("walk_right_down", true)
	if walk_right_down_atlas:
		for i in range(8):
			var frame = extract_frame(walk_right_down_atlas, i)
			sprite_frames.add_frame("walk_right_down", frame)
	# WALK_RIGHT_UP - Arriba derecha (45° a 134°)
	sprite_frames.add_animation("walk_right_up")
	sprite_frames.set_animation_speed("walk_right_up", 12.0)
	sprite_frames.set_animation_loop("walk_right_up", true)
	if walk_right_up_atlas:
		for i in range(8):
			var frame = extract_frame(walk_right_up_atlas, i)
			sprite_frames.add_frame("walk_right_up", frame)
	# WALK_LEFT_UP - Arriba izquierda (135° a 224°)
	sprite_frames.add_animation("walk_left_up")
	sprite_frames.set_animation_speed("walk_left_up", 12.0)
	sprite_frames.set_animation_loop("walk_left_up", true)
	if walk_left_up_atlas:
		for i in range(8):
			var frame = extract_frame(walk_left_up_atlas, i)
			sprite_frames.add_frame("walk_left_up", frame)
	# WALK_LEFT_DOWN - Abajo izquierda (225° a 314°)
	sprite_frames.add_animation("walk_left_down")
	sprite_frames.set_animation_speed("walk_left_down", 12.0)
	sprite_frames.set_animation_loop("walk_left_down", true)
	if walk_left_down_atlas:
		for i in range(8):
			var frame = extract_frame(walk_left_down_atlas, i)
			sprite_frames.add_frame("walk_left_down", frame)
	# NUEVAS ANIMACIONES CORREGIDAS CON FLIP
	create_flipped_animations()
	# Asignar y configurar
	animated_sprite.sprite_frames = sprite_frames
	animated_sprite.play("idle")
	animated_sprite.pause()
	is_system_ready = true
func create_flipped_animations():
	"""Crear animaciones con flip horizontal según especificaciones"""
	# ABAJO IZQUIERDA = walk_Right_Down volteado horizontalmente
	sprite_frames.add_animation("walk_down_left_flipped")
	sprite_frames.set_animation_speed("walk_down_left_flipped", 12.0)
	sprite_frames.set_animation_loop("walk_down_left_flipped", true)
	if walk_right_down_atlas:
		for i in range(8):
			var frame = extract_frame(walk_right_down_atlas, i)
			sprite_frames.add_frame("walk_down_left_flipped", frame)
	# ARRIBA DERECHA = walk_Right_Up (sin flip)
	# Ya creado como walk_right_up
	# ARRIBA IZQUIERDA = walk_Right_Up volteado horizontalmente
	sprite_frames.add_animation("walk_up_left_flipped")
	sprite_frames.set_animation_speed("walk_up_left_flipped", 12.0)
	sprite_frames.set_animation_loop("walk_up_left_flipped", true)
	if walk_right_up_atlas:
		for i in range(8):
			var frame = extract_frame(walk_right_up_atlas, i)
			sprite_frames.add_frame("walk_up_left_flipped", frame)
func extract_frame(atlas: Texture2D, frame_index: int) -> Texture2D:
	var frame_width = 128.0
	var x_offset = float(frame_index) * frame_width
	var atlas_frame = AtlasTexture.new()
	atlas_frame.atlas = atlas
	atlas_frame.region = Rect2(x_offset, 0, frame_width, 128.0)
	return atlas_frame
func update_animation_combined(movement: Vector2, aim_direction: Vector2):
	"""SISTEMA CORREGIDO con atlas específicos y flip"""
	if not is_system_ready:
		return
	# Si está en melee, no cambiar animación hasta que termine
	if is_melee_attacking:
		return
	var is_moving = movement.length() > 0.1
	var is_aiming = aim_direction.length() > 0.1
	# DETERMINAR DIRECCIÓN PRINCIPAL
	var primary_direction = Vector2.ZERO
	if is_moving:
		# PRIORIDAD 1: Dirección de movimiento cuando se mueve
		primary_direction = movement.normalized()
		last_movement_direction = primary_direction
	elif is_aiming:
		# PRIORIDAD 2: Dirección de aim cuando no se mueve pero está apuntando
		primary_direction = aim_direction.normalized()
	else:
		# PRIORIDAD 3: Mantener última dirección de movimiento para idle
		primary_direction = last_movement_direction if last_movement_direction.length() > 0.1 else Vector2.RIGHT
	# ACTUALIZAR DIRECCIÓN ACTUAL
	last_direction = primary_direction
	# APLICAR ANIMACIÓN
	if is_moving:
		var animation_info = determine_animation_and_flip(primary_direction)
		play_animation(animation_info.animation)
		animated_sprite.flip_h = animation_info.flip
	else:
		# IDLE: usar primer frame de la dirección actual
		show_idle_frame_for_direction(primary_direction)
func determine_animation_and_flip(direction: Vector2) -> Dictionary:
	"""Determinar animación y flip según las especificaciones CORREGIDAS"""
	var angle = direction.angle()
	var angle_degrees = rad_to_deg(angle)
	# Normalizar ángulo a 0-360
	if angle_degrees < 0:
		angle_degrees += 360
	# RANGOS CORREGIDOS:
	# 0° = derecha, 90° = abajo, 180° = izquierda, 270° = arriba
	if (angle_degrees >= 0) and (angle_degrees <= 90):
		# DERECHA y DERECHA-ABAJO (315° a 44°)
		return {"animation": "walk_right_down", "flip": false}
	elif angle_degrees > 90 and angle_degrees < 180:
		# ARRIBA y ARRIBA-IZQUIERDA (225° a 314°)
		# Usar walk_right_up CON flip (espejo horizontal)
		return {"animation": "walk_down_left_flipped", "flip": true}
	elif angle_degrees >= 180 and angle_degrees < 269:
		# IZQUIERDA y IZQUIERDA-ABAJO (135° a 224°)
		# Usar walk_right_down CON flip (espejo horizontal)
		return {"animation": "walk_up_left_flipped", "flip": true}
	elif angle_degrees >= 269 and angle_degrees <= 360:
		# ABAJO y ABAJO-DERECHA (45° a 134°)
		# Usar walk_right_down sin flip (porque es hacia abajo-derecha)
		return {"animation": "walk_right_up", "flip": false}
	else:
		# Fallback
		return {"animation": "walk_right_down", "flip": false}
func show_idle_frame_for_direction(direction: Vector2):
	"""Mostrar primer frame de la dirección para idle"""
	var animation_info = determine_animation_and_flip(direction)
	# Cambiar a la animación correcta y pausar en el primer frame
	if animated_sprite.animation != animation_info.animation:
		animated_sprite.play(animation_info.animation)
		animated_sprite.pause()
		animated_sprite.frame = 0
	animated_sprite.flip_h = animation_info.flip
func start_melee_animation():
	"""Iniciar animación de melee"""
	if not is_system_ready or is_melee_attacking:
		return
	is_melee_attacking = true
	current_animation = "melee_attack"
	# Cambiar sprite a versión más agresiva
	if animated_sprite:
		animated_sprite.modulate = Color(1.3, 0.8, 0.8, 1.0)
	# Timer para finalizar animación de melee
	var melee_timer = Timer.new()
	melee_timer.wait_time = 0.5
	melee_timer.one_shot = true
	melee_timer.timeout.connect(_finish_melee_animation)
	add_child(melee_timer)
	melee_timer.start()
func _finish_melee_animation():
	"""Finalizar animación de melee"""
	is_melee_attacking = false
	# Restaurar color normal
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE
	# Volver a idle en la dirección actual
	show_idle_frame_for_direction(last_direction)
	# Limpiar timer
	var melee_timer = get_node_or_null("Timer")
	if melee_timer:
		melee_timer.queue_free()
func play_animation(anim_name: String):
	"""Reproducir animación con verificaciones"""
	if not is_system_ready:
		return
	# No interrumpir melee
	if is_melee_attacking and anim_name != "melee_attack":
		return
	if animated_sprite.animation != anim_name:
		current_animation = anim_name
		animated_sprite.play(anim_name)
func force_animation(anim_name: String):
	"""Forzar animación específica"""
	if not is_system_ready:
		return
	is_melee_attacking = false
	current_animation = anim_name
	animated_sprite.play(anim_name)
func reset_animation_state():
	"""Resetear estado de animación"""
	is_melee_attacking = false
	current_animation = "idle"
	last_direction = Vector2.RIGHT
	last_movement_direction = Vector2.ZERO
	if is_system_ready:
		animated_sprite.play("idle")
		animated_sprite.pause()
		animated_sprite.flip_h = false
		animated_sprite.modulate = Color.WHITE
func get_character_folder_name() -> String:
	var char_name_lower = character_name.to_lower()
	match char_name_lower:
		"pelao": return "pelao"
		"juancar": return "juancar" 
		"chica": return "chica"
		_: return "chica"
func is_playing_melee() -> bool:
	return is_melee_attacking
func get_current_animation() -> String:
	return current_animation
# FUNCIONES DE COMPATIBILIDAD
func update_animation_by_shooting_direction(movement: Vector2, shooting: Vector2):
	update_animation_combined(movement, shooting)
func update_animation_for_movement(movement_direction: Vector2, aim_direction: Vector2):
	update_animation_combined(movement_direction, aim_direction)
func update_animation_for_movement_with_melee(movement_direction: Vector2, aim_direction: Vector2, is_melee: bool):
	if is_melee and not is_melee_attacking:
		start_melee_animation()
		return
	update_animation_combined(movement_direction, aim_direction)
func set_character_direction(direction: Vector2):
	if direction.length() > 0.1:
		last_direction = direction.normalized()
func get_current_facing_direction() -> Vector2:
	return last_direction
func is_facing_left() -> bool:
	return animated_sprite.flip_h if animated_sprite else false
func is_facing_right() -> bool:
	return not animated_sprite.flip_h if animated_sprite else true
func _exit_tree():
	"""Limpiar al salir"""
	is_system_ready = false
	is_melee_attacking = false
	var melee_timer = get_node_or_null("Timer")
	if melee_timer:
		melee_timer.queue_free()
