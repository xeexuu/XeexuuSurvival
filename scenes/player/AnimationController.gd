# AnimationController.gd - SISTEMA DE ANIMACIÓN CON ATLAS COMPLETOS Y FLIP
extends Node
class_name AnimationController

var animated_sprite: AnimatedSprite2D
var sprite_frames: SpriteFrames
var character_name: String
var is_system_ready: bool = false

# Atlas completos
var walk_right_down_atlas: Texture2D
var walk_right_up_atlas: Texture2D

# Estado de animación
var current_animation: String = "idle"
var is_melee_attacking: bool = false

func setup(sprite: AnimatedSprite2D, char_name: String):
	animated_sprite = sprite
	character_name = char_name
	
	load_atlases()
	create_directional_animations()

func load_atlases():
	"""Cargar los dos atlas principales"""
	var folder = get_character_folder_name()
	
	walk_right_down_atlas = load_texture_safe("res://sprites/player/" + folder + "/walk_Right_Down.png")
	walk_right_up_atlas = load_texture_safe("res://sprites/player/" + folder + "/walk_Right_Up.png")
	
	# Fallback a chica si no encuentra
	if not walk_right_down_atlas:
		walk_right_down_atlas = load_texture_safe("res://sprites/player/chica/walk_Right_Down.png")
	if not walk_right_up_atlas:
		walk_right_up_atlas = load_texture_safe("res://sprites/player/chica/walk_Right_Up.png")

func load_texture_safe(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func create_directional_animations():
	"""Crear animaciones direccionales completas"""
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
	
	# WALK_RIGHT_DOWN (hacia abajo a la derecha)
	sprite_frames.add_animation("walk_right_down")
	sprite_frames.set_animation_speed("walk_right_down", 12.0)
	sprite_frames.set_animation_loop("walk_right_down", true)
	if walk_right_down_atlas:
		for i in range(8):
			var frame = extract_frame(walk_right_down_atlas, i)
			sprite_frames.add_frame("walk_right_down", frame)
	
	# WALK_RIGHT_UP (hacia arriba a la derecha)
	sprite_frames.add_animation("walk_right_up")
	sprite_frames.set_animation_speed("walk_right_up", 12.0)
	sprite_frames.set_animation_loop("walk_right_up", true)
	if walk_right_up_atlas:
		for i in range(8):
			var frame = extract_frame(walk_right_up_atlas, i)
			sprite_frames.add_frame("walk_right_up", frame)
	else:
		# Si no hay up, copiar down
		for i in range(sprite_frames.get_frame_count("walk_right_down")):
			var frame = sprite_frames.get_frame_texture("walk_right_down", i)
			sprite_frames.add_frame("walk_right_up", frame)
	
	# Asignar y configurar
	animated_sprite.sprite_frames = sprite_frames
	animated_sprite.play("idle")
	animated_sprite.pause()
	is_system_ready = true
	
	print("✅ Sistema de animación direccional listo para: ", character_name)

func extract_frame(atlas: Texture2D, frame_index: int) -> Texture2D:
	var frame_width = 128.0
	var x_offset = float(frame_index) * frame_width
	
	var atlas_frame = AtlasTexture.new()
	atlas_frame.atlas = atlas
	atlas_frame.region = Rect2(x_offset, 0, frame_width, 128.0)
	
	return atlas_frame

# FUNCIÓN PRINCIPAL: ANIMACIÓN POR DIRECCIÓN DE DISPARO
func update_animation_by_shooting_direction(movement: Vector2, shooting: Vector2):
	"""SISTEMA COMPLETO: walk_Right_Down + walk_Right_Up + flip según dirección"""
	if not is_system_ready:
		return
	
	# Si está en melee, no cambiar animación hasta que termine
	if is_melee_attacking:
		return
	
	var is_moving = movement.length() > 0.1
	var is_shooting = shooting.length() > 0.1
	
	# PRIORIDAD: DIRECCIÓN DE DISPARO > DIRECCIÓN DE MOVIMIENTO > IDLE
	var direction = Vector2.ZERO
	if is_shooting:
		direction = shooting   # PRIORIDAD A LA DIRECCIÓN DE DISPARO
	elif is_moving:
		direction = movement   # SI NO DISPARA, USAR MOVIMIENTO
	
	# Aplicar animación basándose en la dirección principal
	if direction.length() > 0.1:
		# DETERMINAR ANIMACIÓN Y FLIP
		var animation_name = "walk_right_down"  # Por defecto
		var should_flip = false
		
		# LÓGICA DE ANIMACIÓN BASADA EN DIRECCIÓN:
		if direction.y < 0:  # DISPARANDO/MOVIENDO HACIA ARRIBA
			animation_name = "walk_right_up"
		else:  # DISPARANDO/MOVIENDO HACIA ABAJO
			animation_name = "walk_right_down"
		
		# LÓGICA DE FLIP HORIZONTAL:
		if direction.x < 0:  # DISPARANDO/MOVIENDO HACIA LA IZQUIERDA
			should_flip = true
		else:  # DISPARANDO/MOVIENDO HACIA LA DERECHA
			should_flip = false
		
		# APLICAR ANIMACIÓN Y FLIP
		play_animation(animation_name)
		animated_sprite.flip_h = should_flip
		
		print("🎯 Dirección: ", direction, " -> Anim: ", animation_name, " Flip: ", should_flip)
		
	else:
		# IDLE
		play_animation("idle")
		animated_sprite.pause()

func start_melee_animation():
	"""Iniciar animación de melee (sin cambios)"""
	if not is_system_ready or is_melee_attacking:
		return
	
	is_melee_attacking = true
	current_animation = "melee_attack"
	
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
	
	# Volver a idle
	play_animation("idle")
	animated_sprite.pause()
	
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
	if is_system_ready:
		animated_sprite.play("idle")
		animated_sprite.pause()
		animated_sprite.flip_h = false  # RESETEAR FLIP

func get_character_folder_name() -> String:
	var char_name_lower = character_name.to_lower()
	match char_name_lower:
		"pelao": return "pelao"
		"juancar": return "juancar" 
		"chica": return "chica"
		_: return "chica"

func is_playing_melee() -> bool:
	"""Verificar si está reproduciendo animación de melee"""
	return is_melee_attacking

func get_current_animation() -> String:
	"""Obtener animación actual"""
	return current_animation

# Alias para compatibilidad (ACTUALIZADO PARA USAR DIRECCIÓN DE DISPARO)
func update_animation_for_movement(movement_direction: Vector2, aim_direction: Vector2):
	update_animation_by_shooting_direction(movement_direction, aim_direction)

# Nueva función que incluye melee pero usa dirección de disparo
func update_animation_for_movement_with_melee(movement_direction: Vector2, aim_direction: Vector2, is_melee: bool):
	if is_melee and not is_melee_attacking:
		start_melee_animation()
		return
	
	update_animation_by_shooting_direction(movement_direction, aim_direction)
