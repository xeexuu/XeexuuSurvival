# scenes/player/AnimationController.gd - SISTEMA DE ANIMACIONES DIRECCIONALES CORREGIDO
extends Node
class_name AnimationController

var animated_sprite: AnimatedSprite2D
var sprite_frames: SpriteFrames
var character_name: String

# Estado de animación
var current_movement_direction: Vector2 = Vector2.ZERO
var current_aim_direction: Vector2 = Vector2.RIGHT
var is_moving: bool = false

# Mapeo de animaciones disponibles
var available_animations: Dictionary = {}

# SISTEMA DE ROTACIÓN SUAVE - REDUCIDO
var target_rotation: float = 0.0
var rotation_speed: float = 8.0
var max_rotation_angle: float = 8.0  # Reducido a 8 grados máximo

func setup(sprite: AnimatedSprite2D, char_name: String):
	"""Configurar el controlador de animaciones"""
	animated_sprite = sprite
	character_name = char_name
	load_character_animations()

func load_character_animations():
	"""Cargar animaciones del personaje con fallback a chica"""
	sprite_frames = load_primary_animations()
	
	if not sprite_frames:
		sprite_frames = load_fallback_animations()
	
	if sprite_frames:
		animated_sprite.sprite_frames = sprite_frames
		detect_available_animations()
		animated_sprite.play("idle")
		scale_sprite_to_128px()

func load_primary_animations() -> SpriteFrames:
	"""Cargar animaciones del personaje principal"""
	var folder_name = get_character_folder_name()
	
	# SPRITES DIRECCIONALES ESPECÍFICOS
	var animation_files = [
		"walk_Down.png",          # Apuntando hacia abajo
		"walk_Left_Down.png",     # Apuntando hacia abajo izquierda
		"walk_Left_Up.png",       # Apuntando hacia arriba izquierda
		"walk_Right_Down.png",    # Apuntando hacia abajo derecha
		"walk_Right_Up.png",      # Apuntando hacia arriba derecha
		"walk_Up.png"             # Apuntando hacia arriba
	]
	
	var loaded_textures: Dictionary = {}
	var base_path = "res://sprites/player/" + folder_name + "/"
	
	# Cargar texturas disponibles
	for file in animation_files:
		var full_path = base_path + file
		if ResourceLoader.exists(full_path):
			var texture = load(full_path) as Texture2D
			if texture:
				var anim_name = file.replace(".png", "")
				loaded_textures[anim_name] = texture
	
	if loaded_textures.size() > 0:
		return create_sprite_frames_from_textures(loaded_textures)
	
	return null

func load_fallback_animations() -> SpriteFrames:
	"""Cargar animaciones de fallback (chica)"""
	var fallback_textures: Dictionary = {}
	var base_path = "res://sprites/player/chica/"
	
	var animation_files = [
		"walk_Down.png",
		"walk_Left_Down.png",
		"walk_Left_Up.png",
		"walk_Right_Down.png",
		"walk_Right_Up.png",
		"walk_Up.png"
	]
	
	for file in animation_files:
		var full_path = base_path + file
		if ResourceLoader.exists(full_path):
			var texture = load(full_path) as Texture2D
			if texture:
				var anim_name = file.replace(".png", "")
				fallback_textures[anim_name] = texture
	
	if fallback_textures.size() > 0:
		return create_sprite_frames_from_textures(fallback_textures)
	
	return create_default_sprite_frames()

func create_sprite_frames_from_textures(textures: Dictionary) -> SpriteFrames:
	"""Crear SpriteFrames desde texturas cargadas"""
	var frames = SpriteFrames.new()
	
	# Crear animación idle usando la primera textura disponible
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 2.0)
	frames.set_animation_loop("idle", true)
	
	var first_texture = get_first_available_texture(textures)
	if first_texture:
		var first_frame = extract_first_frame_from_texture(first_texture)
		frames.add_frame("idle", first_frame)
	
	# Crear animaciones direccionales EXACTAS
	for texture_key in textures.keys():
		var texture = textures[texture_key]
		var anim_name = texture_key
		
		# Crear animación específica
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, 8.0)
		frames.set_animation_loop(anim_name, true)
		
		# Extraer frames del atlas
		var animation_frames = extract_frames_from_texture(texture)
		for frame in animation_frames:
			frames.add_frame(anim_name, frame)
	
	# Crear animación genérica "walk" usando walk_Down como base
	if not frames.has_animation("walk"):
		frames.add_animation("walk")
		frames.set_animation_speed("walk", 8.0)
		frames.set_animation_loop("walk", true)
		
		var walk_texture = textures.get("walk_Down", first_texture)
		if walk_texture:
			var walk_frames = extract_frames_from_texture(walk_texture)
			for frame in walk_frames:
				frames.add_frame("walk", frame)
	
	return frames

func get_first_available_texture(textures: Dictionary) -> Texture2D:
	"""Obtener la primera textura disponible con prioridad específica"""
	var priority_order = ["walk_Down", "walk_Right_Down", "walk_Up", "walk_Left_Down", "walk_Left_Up", "walk_Right_Up"]
	
	for key in priority_order:
		if key in textures:
			return textures[key]
	
	# Si no hay prioridades, tomar cualquiera
	for key in textures.keys():
		return textures[key]
	
	return null

func extract_first_frame_from_texture(texture: Texture2D) -> Texture2D:
	"""Extraer el primer frame de una textura (puede ser atlas)"""
	if not texture:
		return null
	
	var texture_size = texture.get_size()
	
	# Si la textura es muy ancha, probablemente es un atlas
	if texture_size.x > texture_size.y * 2:
		var frame_width = float(texture_size.x) / 8.0  # Asumir 8 frames
		var frame_height = float(texture_size.y)
		
		var first_frame = AtlasTexture.new()
		first_frame.atlas = texture
		first_frame.region = Rect2(0, 0, frame_width, frame_height)
		return first_frame
	
	return texture

func extract_frames_from_texture(texture: Texture2D) -> Array[Texture2D]:
	"""Extraer todos los frames de una textura"""
	var frames: Array[Texture2D] = []
	
	if not texture:
		return frames
	
	var texture_size = texture.get_size()
	
	# Detectar si es un atlas
	if texture_size.x > texture_size.y * 2:
		# Es un atlas, extraer frames
		var frame_count = 8  # Asumir 8 frames
		var frame_width = float(texture_size.x) / float(frame_count)
		var frame_height = float(texture_size.y)
		
		for i in range(frame_count):
			var frame = AtlasTexture.new()
			frame.atlas = texture
			frame.region = Rect2(i * frame_width, 0, frame_width, frame_height)
			frames.append(frame)
	else:
		# Es una sola imagen
		frames.append(texture)
	
	return frames

func create_default_sprite_frames() -> SpriteFrames:
	"""Crear SpriteFrames por defecto"""
	var frames = SpriteFrames.new()
	var default_texture = create_default_character_texture()
	
	# Animaciones básicas
	var animations = ["idle", "walk", "walk_Down", "walk_Up", "walk_Left_Down", "walk_Left_Up", "walk_Right_Down", "walk_Right_Up"]
	
	for anim in animations:
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 2.0 if anim == "idle" else 8.0)
		frames.set_animation_loop(anim, true)
		frames.add_frame(anim, default_texture)
	
	return frames

func create_default_character_texture() -> Texture2D:
	"""Crear textura por defecto para el personaje"""
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	
	var name_hash = character_name.hash()
	var hue = float(abs(name_hash) % 360) / 360.0
	var character_color = Color.from_hsv(hue, 0.7, 0.9)
	
	image.fill(character_color)
	
	# Detalles básicos
	var center = Vector2(32, 32)
	for x in range(64):
		for y in range(64):
			var dist = Vector2(x, y).distance_to(center)
			if dist < 8:
				image.set_pixel(x, y, Color.WHITE)
			elif dist < 12:
				image.set_pixel(x, y, character_color.darkened(0.3))
			elif dist < 16:
				image.set_pixel(x, y, character_color.darkened(0.1))
	
	# Ojos
	for x in range(28, 32):
		for y in range(28, 32):
			image.set_pixel(x, y, Color.BLACK)
	for x in range(32, 36):
		for y in range(28, 32):
			image.set_pixel(x, y, Color.BLACK)
	
	return ImageTexture.create_from_image(image)

func detect_available_animations():
	"""Detectar qué animaciones están disponibles"""
	available_animations.clear()
	
	if not sprite_frames:
		return
	
	var animation_list = sprite_frames.get_animation_names()
	for anim_name in animation_list:
		available_animations[anim_name] = true

func update_animation(movement_direction: Vector2, aim_direction: Vector2):
	"""SISTEMA PRINCIPAL: Actualizar animación basada en dirección de apuntado PRIORITARIA"""
	if not animated_sprite or not sprite_frames:
		return
	
	current_movement_direction = movement_direction
	current_aim_direction = aim_direction
	is_moving = movement_direction.length() > 0.1
	
	# PRIORIDAD 1: Dirección de apuntado
	var direction_to_use = aim_direction if aim_direction.length() > 0.1 else movement_direction
	
	if direction_to_use.length() > 0.1:
		# Obtener animación y rotación según dirección de apuntado
		var target_animation = get_animation_from_direction(direction_to_use)
		var target_rot = get_rotation_from_direction(direction_to_use)
		
		# Aplicar animación direccional ESPECÍFICA
		if target_animation != "" and available_animations.has(target_animation):
			if animated_sprite.animation != target_animation:
				animated_sprite.play(target_animation)
		elif available_animations.has("walk") and is_moving:
			if animated_sprite.animation != "walk":
				animated_sprite.play("walk")
		
		# Aplicar rotación suave REDUCIDA
		target_rotation = target_rot
		update_sprite_rotation()
	else:
		# Sin movimiento ni apuntado - usar idle
		if available_animations.has("idle"):
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
		
		# Volver gradualmente a rotación 0
		target_rotation = 0.0
		update_sprite_rotation()

func get_animation_from_direction(direction: Vector2) -> String:
	"""Obtener animación EXACTA según dirección"""
	var angle = direction.angle()
	var degrees = rad_to_deg(angle)
	
	# Normalizar ángulo a 0-360
	if degrees < 0:
		degrees += 360
	
	# MAPEO EXACTO SEGÚN ESPECIFICACIONES DEL USUARIO
	if degrees >= 337.5 or degrees < 22.5:
		# Derecha pura - usar Right_Down
		return "walk_Right_Down"
	elif degrees >= 22.5 and degrees < 67.5:
		# Derecha-Abajo
		return "walk_Right_Down"
	elif degrees >= 67.5 and degrees < 112.5:
		# Abajo
		return "walk_Down"
	elif degrees >= 112.5 and degrees < 157.5:
		# Izquierda-Abajo
		return "walk_Left_Down"
	elif degrees >= 157.5 and degrees < 202.5:
		# Izquierda pura - usar Left_Down
		return "walk_Left_Down"
	elif degrees >= 202.5 and degrees < 247.5:
		# Izquierda-Arriba
		return "walk_Left_Up"
	elif degrees >= 247.5 and degrees < 292.5:
		# Arriba
		return "walk_Up"
	elif degrees >= 292.5 and degrees < 337.5:
		# Derecha-Arriba
		return "walk_Right_Up"
	
	return "walk_Down"  # Fallback

func get_rotation_from_direction(direction: Vector2) -> float:
	"""Obtener rotación LIGERA según dirección"""
	var angle = direction.angle()
	var degrees = rad_to_deg(angle)
	
	# Normalizar ángulo a 0-360
	if degrees < 0:
		degrees += 360
	
	# ROTACIÓN LIGERA (máximo 8 grados) según dirección
	var base_rotation = 0.0
	
	if degrees >= 337.5 or degrees < 22.5:
		# Derecha - rotación ligera hacia la derecha
		base_rotation = deg_to_rad(3.0)
	elif degrees >= 22.5 and degrees < 67.5:
		# Derecha-Abajo
		base_rotation = deg_to_rad(6.0)
	elif degrees >= 67.5 and degrees < 112.5:
		# Abajo
		base_rotation = deg_to_rad(4.0)
	elif degrees >= 112.5 and degrees < 157.5:
		# Izquierda-Abajo
		base_rotation = deg_to_rad(-6.0)
	elif degrees >= 157.5 and degrees < 202.5:
		# Izquierda
		base_rotation = deg_to_rad(-3.0)
	elif degrees >= 202.5 and degrees < 247.5:
		# Izquierda-Arriba
		base_rotation = deg_to_rad(-8.0)
	elif degrees >= 247.5 and degrees < 292.5:
		# Arriba
		base_rotation = deg_to_rad(-4.0)
	elif degrees >= 292.5 and degrees < 337.5:
		# Derecha-Arriba
		base_rotation = deg_to_rad(8.0)
	
	# Limitar la rotación al máximo permitido
	base_rotation = clamp(base_rotation, deg_to_rad(-max_rotation_angle), deg_to_rad(max_rotation_angle))
	
	return base_rotation

func update_sprite_rotation():
	"""Actualizar rotación del sprite de forma suave"""
	if not animated_sprite:
		return
	
	# Interpolación suave hacia la rotación objetivo
	var delta = get_tree().process_frame
	animated_sprite.rotation = lerp_angle(animated_sprite.rotation, target_rotation, rotation_speed * delta)

func scale_sprite_to_128px():
	"""Escalar sprite a 128px de alto"""
	if not animated_sprite or not sprite_frames:
		return
	
	# Obtener primera textura para calcular escala
	var reference_texture: Texture2D = null
	
	if sprite_frames.has_animation("idle") and sprite_frames.get_frame_count("idle") > 0:
		reference_texture = sprite_frames.get_frame_texture("idle", 0)
	
	if not reference_texture:
		return
	
	var current_height = reference_texture.get_size().y
	var target_height = 128.0
	
	if current_height == target_height:
		animated_sprite.scale = Vector2(1.0, 1.0)
		return
	
	var scale_factor = target_height / float(current_height)
	animated_sprite.scale = Vector2(scale_factor, scale_factor)

func get_character_folder_name() -> String:
	"""Obtener nombre de carpeta para el personaje"""
	var char_name_lower = character_name.to_lower().replace(" ", "")
	
	var name_mappings = {
		"pelao": "pelao",
		"juancar": "juancar",
		"juan_car": "juancar",
		"chica": "chica"
	}
	
	return name_mappings.get(char_name_lower, char_name_lower)
