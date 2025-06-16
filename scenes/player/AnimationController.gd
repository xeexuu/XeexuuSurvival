# scenes/player/AnimationController.gd - SISTEMA DE ANIMACIONES REDISEÑADO PARA MOVIMIENTO
extends Node
class_name AnimationController

var animated_sprite: AnimatedSprite2D
var sprite_frames: SpriteFrames
var character_name: String

# Atlas cargados
var walk_right_down_atlas: Texture2D
var walk_right_up_atlas: Texture2D

# Estado actual
var current_animation: String = ""
var current_flip: bool = false
var is_system_ready: bool = false

# Variables para control de animación
var is_moving: bool = false
var last_movement_direction: Vector2 = Vector2.ZERO

func setup(sprite: AnimatedSprite2D, char_name: String):
	"""Configurar controlador de animaciones"""
	animated_sprite = sprite
	character_name = char_name
	
	# Resetear estado
	is_system_ready = false
	is_moving = false
	last_movement_direction = Vector2.ZERO
	
	load_required_atlases_universal()
	create_animations_safely()

func load_required_atlases_universal():
	"""SISTEMA UNIVERSAL: Cargar atlas con fallback automático a chica"""
	var folder_name = get_character_folder_name()
	
	print("🎭 [ANIMACION] Cargando atlas para: ", character_name, " (folder: ", folder_name, ")")
	
	# CARGAR walk_Right_Down con fallback universal
	walk_right_down_atlas = load_atlas_with_universal_fallback(folder_name, "walk_Right_Down")
	
	# CARGAR walk_Right_Up con fallback universal
	walk_right_up_atlas = load_atlas_with_universal_fallback(folder_name, "walk_Right_Up")
	
	print("✅ [ANIMACION] Atlas cargados - Down: ", walk_right_down_atlas != null, " Up: ", walk_right_up_atlas != null)

func load_atlas_with_universal_fallback(folder_name: String, atlas_name: String) -> Texture2D:
	"""FALLBACK UNIVERSAL: Intentar cargar atlas, fallback a chica si falla"""
	
	# PASO 1: Intentar cargar del personaje específico
	var primary_path = "res://sprites/player/" + folder_name + "/" + atlas_name + ".png"
	var texture = try_load_texture(primary_path)
	if texture:
		print("✅ [ANIMACION] Cargado directo: ", primary_path)
		return texture
	
	# PASO 2: FALLBACK AUTOMÁTICO A CHICA si no es chica
	if folder_name != "chica":
		var chica_path = "res://sprites/player/chica/" + atlas_name + ".png"
		texture = try_load_texture(chica_path)
		if texture:
			print("⚠️ [ANIMACION] Fallback a chica para ", folder_name, ": ", chica_path)
			return texture
	
	# PASO 3: Intentar variantes del nombre del atlas
	var atlas_variants = [
		atlas_name.to_lower(),
		atlas_name.replace("_", ""),
		atlas_name.replace("Right", "right"),
		atlas_name.replace("Down", "down"),
		atlas_name.replace("Up", "up")
	]
	
	# Probar variantes en el personaje específico
	for variant in atlas_variants:
		var variant_path = "res://sprites/player/" + folder_name + "/" + variant + ".png"
		texture = try_load_texture(variant_path)
		if texture:
			print("✅ [ANIMACION] Variante encontrada para ", folder_name, ": ", variant_path)
			return texture
	
	# Probar variantes en chica si no es chica
	if folder_name != "chica":
		for variant in atlas_variants:
			var chica_variant_path = "res://sprites/player/chica/" + variant + ".png"
			texture = try_load_texture(chica_variant_path)
			if texture:
				print("⚠️ [ANIMACION] Variante de chica para ", folder_name, ": ", chica_variant_path)
				return texture
	
	# PASO 4: Crear textura por defecto
	print("❌ [ANIMACION] No se encontró ningún atlas para ", folder_name, " - ", atlas_name)
	return null

func try_load_texture(path: String) -> Texture2D:
	"""Cargar textura de forma segura"""
	if not ResourceLoader.exists(path):
		return null
	
	var texture = load(path) as Texture2D
	if texture:
		return texture
	else:
		return null

func create_animations_safely():
	"""Crear animaciones de forma segura"""
	if not animated_sprite:
		return
	
	# Crear nuevo SpriteFrames limpio
	sprite_frames = SpriteFrames.new()
	
	# CREAR ANIMACIÓN IDLE (PRIMER FRAME DE WALK_RIGHT_DOWN)
	if walk_right_down_atlas:
		create_idle_animation_from_atlas("idle", walk_right_down_atlas)
	else:
		create_fallback_animation("idle")
	
	# CREAR ANIMACIONES DE MOVIMIENTO
	if walk_right_down_atlas:
		create_animation_from_atlas("walk_right_down", walk_right_down_atlas)
	else:
		create_fallback_animation("walk_right_down")
	
	if walk_right_up_atlas:
		create_animation_from_atlas("walk_right_up", walk_right_up_atlas)
	else:
		# Si no hay walk_Right_Up, duplicar walk_Right_Down
		duplicate_animation("walk_right_down", "walk_right_up")
	
	# Asignar al sprite DE UNA SOLA VEZ
	if animated_sprite:
		animated_sprite.sprite_frames = sprite_frames
		animated_sprite.play("idle")
		current_animation = "idle"
		current_flip = false
		is_system_ready = true
		print("✅ [ANIMACION] Sistema listo - Animación inicial: idle")

func create_idle_animation_from_atlas(anim_name: String, atlas: Texture2D):
	"""Crear animación idle con SOLO EL PRIMER FRAME del atlas"""
	if not atlas or not sprite_frames:
		return
	
	sprite_frames.add_animation(anim_name)
	sprite_frames.set_animation_speed(anim_name, 1.0)  # Velocidad lenta para idle
	sprite_frames.set_animation_loop(anim_name, false)  # No loop para idle estático
	
	# SOLO EL PRIMER FRAME (frame 0)
	var first_frame = extract_frame_from_atlas(atlas, 0)
	if first_frame:
		sprite_frames.add_frame(anim_name, first_frame)
	
	print("✅ [ANIMACION] Animación idle creada con primer frame")

func create_animation_from_atlas(anim_name: String, atlas: Texture2D):
	"""Crear animación de movimiento desde atlas 1024x128"""
	if not atlas or not sprite_frames:
		return
	
	sprite_frames.add_animation(anim_name)
	sprite_frames.set_animation_speed(anim_name, 12.0)
	sprite_frames.set_animation_loop(anim_name, true)
	
	# Extraer TODOS los frames (8 frames de 128x128 cada uno)
	for i in range(8):
		var frame = extract_frame_from_atlas(atlas, i)
		if frame:
			sprite_frames.add_frame(anim_name, frame)
	
	print("✅ [ANIMACION] Animación ", anim_name, " creada con 8 frames")

func extract_frame_from_atlas(atlas: Texture2D, frame_index: int) -> Texture2D:
	"""Extraer frame específico del atlas"""
	if not atlas:
		return null
	
	var atlas_size = atlas.get_size()
	var frame_width = 128.0  # Cada frame es 128x128
	var frame_height = 128.0
	var x_offset = float(frame_index) * frame_width
	
	# Verificar que el frame esté dentro del atlas
	if x_offset + frame_width > atlas_size.x:
		return null
	
	var atlas_frame = AtlasTexture.new()
	atlas_frame.atlas = atlas
	atlas_frame.region = Rect2(x_offset, 0, frame_width, frame_height)
	
	return atlas_frame

func duplicate_animation(source_anim: String, target_anim: String):
	"""Duplicar una animación existente"""
	if not sprite_frames or not sprite_frames.has_animation(source_anim):
		return
	
	sprite_frames.add_animation(target_anim)
	sprite_frames.set_animation_speed(target_anim, sprite_frames.get_animation_speed(source_anim))
	sprite_frames.set_animation_loop(target_anim, sprite_frames.get_animation_loop(source_anim))
	
	var frame_count = sprite_frames.get_frame_count(source_anim)
	for i in range(frame_count):
		var frame_texture = sprite_frames.get_frame_texture(source_anim, i)
		sprite_frames.add_frame(target_anim, frame_texture)
	
	print("✅ [ANIMACION] Animación ", target_anim, " duplicada desde ", source_anim)

func create_fallback_animation(anim_name: String):
	"""Crear animación por defecto"""
	if not sprite_frames:
		return
	
	sprite_frames.add_animation(anim_name)
	sprite_frames.set_animation_speed(anim_name, 1.0)
	sprite_frames.set_animation_loop(anim_name, true)
	
	var default_texture = create_default_texture()
	sprite_frames.add_frame(anim_name, default_texture)
	
	print("⚠️ [ANIMACION] Animación fallback creada: ", anim_name)

func create_default_texture() -> Texture2D:
	"""Crear textura por defecto"""
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	
	var name_hash = character_name.hash()
	var hue = float(abs(name_hash) % 360) / 360.0
	var character_color = Color.from_hsv(hue, 0.7, 0.9)
	
	image.fill(character_color)
	
	# Forma básica
	for x in range(128):
		for y in range(128):
			var dist = Vector2(x - 64, y - 64).length()
			if dist < 20:
				image.set_pixel(x, y, Color.WHITE)
			elif dist < 30:
				image.set_pixel(x, y, character_color.darkened(0.3))
	
	return ImageTexture.create_from_image(image)

# ===== SISTEMA PRINCIPAL DE ANIMACIONES =====

func update_animation_for_movement(movement_direction: Vector2, aim_direction: Vector2):
	"""SISTEMA PRINCIPAL: PREDOMINA DIRECCIÓN DE DISPARO sobre movimiento"""
	if not is_system_ready or not animated_sprite or not sprite_frames:
		return
	
	# DETERMINAR SI SE ESTÁ MOVIENDO
	var current_is_moving = movement_direction.length() > 0.1
	var is_aiming = aim_direction.length() > 0.1
	
	# DETERMINAR DIRECCIÓN A USAR - PRIORIDAD AL DISPARO
	var direction_for_animation = Vector2.ZERO
	
	if is_aiming:
		# PRIORIDAD 1: Si está disparando/apuntando, usar dirección de disparo
		direction_for_animation = aim_direction.normalized()
		last_movement_direction = direction_for_animation
		print("🎯 [ANIMACION] Usando dirección de DISPARO: ", direction_for_animation)
	elif current_is_moving:
		# PRIORIDAD 2: Si se mueve pero no dispara, usar dirección de movimiento
		direction_for_animation = movement_direction.normalized()
		last_movement_direction = direction_for_animation
		print("🚶 [ANIMACION] Usando dirección de MOVIMIENTO: ", direction_for_animation)
	else:
		# PRIORIDAD 3: Si no hace nada, mantener última dirección para orientación
		direction_for_animation = last_movement_direction
		print("⏸️ [ANIMACION] Manteniendo última dirección: ", direction_for_animation)
	
	# ACTUALIZAR ESTADO
	is_moving = current_is_moving
	
	# APLICAR ANIMACIÓN
	if is_moving or is_aiming:
		apply_movement_animation(direction_for_animation)
	else:
		apply_idle_animation()

func apply_movement_animation(direction: Vector2):
	"""Aplicar animación de movimiento según dirección - PREDOMINA DISPARO"""
	if direction == Vector2.ZERO:
		apply_idle_animation()
		return
	
	# DETERMINAR QUÉ ATLAS USAR SEGÚN LA DIRECCIÓN Y
	var target_animation: String
	var target_flip: bool
	
	if direction.y < 0:  # DIRECCIÓN HACIA ARRIBA -> usar atlas Up
		target_animation = "walk_right_up"
		target_flip = direction.x < 0  # Flip si va hacia la izquierda
		print("🎭 [ANIMACION] Dirección hacia ARRIBA - Atlas: UP, Flip: ", target_flip)
	else:  # DIRECCIÓN HACIA ABAJO O HORIZONTAL -> usar atlas Down
		target_animation = "walk_right_down"
		target_flip = direction.x < 0  # Flip si va hacia la izquierda
		print("🎭 [ANIMACION] Dirección hacia ABAJO/HORIZONTAL - Atlas: DOWN, Flip: ", target_flip)
	
	# VERIFICAR QUE LA ANIMACIÓN EXISTE
	if not sprite_frames.has_animation(target_animation):
		target_animation = "walk_right_down"  # Fallback seguro
		print("⚠️ [ANIMACION] Fallback a walk_right_down")
	
	# APLICAR CAMBIOS SOLO SI SON DIFERENTES
	if target_animation != current_animation:
		animated_sprite.play(target_animation)
		current_animation = target_animation
		print("✅ [ANIMACION] Cambiando a: ", target_animation)
	
	if target_flip != current_flip:
		animated_sprite.flip_h = target_flip
		current_flip = target_flip
		print("✅ [ANIMACION] Flip horizontal: ", target_flip)

func apply_idle_animation():
	"""Aplicar animación de idle (primer frame de walk_right_down)"""
	var target_animation = "idle"
	
	# VERIFICAR QUE EXISTE LA ANIMACIÓN IDLE
	if not sprite_frames.has_animation(target_animation):
		target_animation = "walk_right_down"  # Fallback
		print("⚠️ [ANIMACION] No hay idle, usando walk_right_down")
	
	# APLICAR SOLO SI ES DIFERENTE
	if target_animation != current_animation:
		animated_sprite.play(target_animation)
		current_animation = target_animation
		print("✅ [ANIMACION] Cambiando a IDLE")
		
		# Si usamos walk_right_down como idle, pausarlo en el primer frame
		if target_animation == "walk_right_down":
			animated_sprite.pause()
			animated_sprite.set_frame(0)

func get_character_folder_name() -> String:
	"""Obtener nombre de carpeta del personaje"""
	var char_name_lower = character_name.to_lower().replace(" ", "")
	
	var name_mappings = {
		"pelao": "pelao",
		"juancar": "juancar", 
		"chica": "chica"
	}
	
	return name_mappings.get(char_name_lower, "chica")  # Default a chica

func force_animation(anim_name: String):
	"""Forzar animación específica"""
	if not is_system_ready or not animated_sprite or not sprite_frames:
		return
	
	if sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
		current_animation = anim_name
		print("🎭 [ANIMACION] Forzando animación: ", anim_name)

func get_available_animations() -> Array[String]:
	"""Obtener animaciones disponibles"""
	if sprite_frames:
		return sprite_frames.get_animation_names()
	return []

# ===== FUNCIONES DE DEPURACIÓN =====

func debug_print_animation_state():
	"""Imprimir estado actual para depuración"""
	print("🎭 [DEBUG] Estado de animación:")
	print("   Sistema listo: ", is_system_ready)
	print("   Animación actual: ", current_animation)
	print("   Flip horizontal: ", current_flip)
	print("   Se está moviendo: ", is_moving)
	print("   Última dirección: ", last_movement_direction)
	print("   Animaciones disponibles: ", get_available_animations())

func reset_animation_state():
	"""Resetear estado de animación"""
	is_moving = false
	last_movement_direction = Vector2.ZERO
	current_animation = ""
	current_flip = false
	
	if animated_sprite and sprite_frames and sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")
		current_animation = "idle"
	
	print("🎭 [ANIMACION] Estado reseteado")
