# scenes/player/AnimationController.gd - ANIMACIONES CON FRAMES CORRECTOS Y SIN ROTACIÓN
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
		"walk_Down.png",
		"walk_Right_Down.png", 
		"walk_Right_Up.png",
		"walk_Left_Up.png",
		"walk_Left_Down.png",
		"walk_Up.png"
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
		"walk_Right_Down.png",
		"walk_Right_Up.png", 
		"walk_Left_Up.png",
		"walk_Left_Down.png",
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
	"""Crear SpriteFrames desde texturas cargadas - EXTRAER 8 FRAMES DE 128x128"""
	var frames = SpriteFrames.new()
	
	# Crear animación idle usando walk_Down como base
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 4.0)
	frames.set_animation_loop("idle", true)
	
	var idle_texture = textures.get("walk_Down", get_first_available_texture(textures))
	if idle_texture:
		var first_frame = extract_frame_from_atlas(idle_texture, 0)
		frames.add_frame("idle", first_frame)
	
	# Crear animaciones direccionales EXACTAS - EXTRAER TODOS LOS 8 FRAMES
	for texture_key in textures.keys():
		var texture = textures[texture_key]
		var anim_name = texture_key
		
		# Crear animación específica
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, 12.0)  # Velocidad de animación
		frames.set_animation_loop(anim_name, true)
		
		# EXTRAER TODOS LOS 8 FRAMES DEL ATLAS 1024x128
		for i in range(8):
			var frame = extract_frame_from_atlas(texture, i)
			frames.add_frame(anim_name, frame)
	
	return frames

func extract_frame_from_atlas(atlas_texture: Texture2D, frame_index: int) -> Texture2D:
	"""Extraer un frame específico del atlas 1024x128 (8 frames de 128x128)"""
	if not atlas_texture:
		return null
	
	var frame_width = 128.0  # Cada frame es 128x128
	var frame_height = 128.0
	var x = float(frame_index) * frame_width
	
	var atlas_frame = AtlasTexture.new()
	atlas_frame.atlas = atlas_texture
	atlas_frame.region = Rect2(x, 0, frame_width, frame_height)
	
	return atlas_frame

func get_first_available_texture(textures: Dictionary) -> Texture2D:
	"""Obtener la primera textura disponible"""
	var priority_order = ["walk_Down", "walk_Right_Down", "walk_Up", "walk_Left_Down", "walk_Left_Up", "walk_Right_Up"]
	
	for key in priority_order:
		if key in textures:
			return textures[key]
	
	for key in textures.keys():
		return textures[key]
	
	return null

func create_default_sprite_frames() -> SpriteFrames:
	"""Crear SpriteFrames por defecto"""
	var frames = SpriteFrames.new()
	var default_texture = create_default_character_texture()
	
	var animations = ["idle", "walk_Down", "walk_Right_Down", "walk_Right_Up", "walk_Left_Up", "walk_Left_Down", "walk_Up"]
	
	for anim in animations:
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 4.0 if anim == "idle" else 12.0)
		frames.set_animation_loop(anim, true)
		frames.add_frame(anim, default_texture)
	
	return frames

func create_default_character_texture() -> Texture2D:
	"""Crear textura por defecto para el personaje"""
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	
	var name_hash = character_name.hash()
	var hue = float(abs(name_hash) % 360) / 360.0
	var character_color = Color.from_hsv(hue, 0.7, 0.9)
	
	image.fill(character_color)
	
	# Detalles básicos
	var center = Vector2(64, 64)
	for x in range(128):
		for y in range(128):
			var dist = Vector2(x, y).distance_to(center)
			if dist < 20:
				image.set_pixel(x, y, Color.WHITE)
			elif dist < 30:
				image.set_pixel(x, y, character_color.darkened(0.3))
			elif dist < 40:
				image.set_pixel(x, y, character_color.darkened(0.1))
	
	# Ojos
	for x in range(54, 62):
		for y in range(54, 62):
			image.set_pixel(x, y, Color.BLACK)
	for x in range(66, 74):
		for y in range(54, 62):
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
	"""SISTEMA PRINCIPAL: Actualizar animación basada en dirección - SIN ROTACIÓN"""
	if not animated_sprite or not sprite_frames:
		return
	
	current_movement_direction = movement_direction
	current_aim_direction = aim_direction
	is_moving = movement_direction.length() > 0.1
	
	# PRIORIDAD 1: Dirección de apuntado
	var direction_to_use = aim_direction if aim_direction.length() > 0.1 else movement_direction
	
	if direction_to_use.length() > 0.1:
		# Obtener animación EXACTA según dirección - SEGÚN TUS ESPECIFICACIONES
		var target_animation = get_exact_animation_from_direction(direction_to_use)
		
		# Aplicar animación direccional ESPECÍFICA - SIN ROTACIÓN
		if target_animation != "" and available_animations.has(target_animation):
			if animated_sprite.animation != target_animation:
				animated_sprite.play(target_animation)
		elif available_animations.has("walk_Down") and is_moving:
			if animated_sprite.animation != "walk_Down":
				animated_sprite.play("walk_Down")
		
		# NO APLICAR ROTACIÓN - SOLO ANIMACIONES DIRECCIONALES
		animated_sprite.rotation = 0.0
	else:
		# Sin movimiento ni apuntado - usar idle
		if available_animations.has("idle"):
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
		
		# Sin rotación
		animated_sprite.rotation = 0.0

func get_exact_animation_from_direction(direction: Vector2) -> String:
	"""Obtener animación EXACTA según dirección - SEGÚN TUS ESPECIFICACIONES"""
	var angle = direction.angle()
	var degrees = rad_to_deg(angle)
	
	# Normalizar ángulo a 0-360
	if degrees < 0:
		degrees += 360
	
	# MAPEO EXACTO SEGÚN TUS ESPECIFICACIONES
	if (degrees >= 330 and degrees <= 360) or (degrees >= 0 and degrees < 30):
		# 330° - 30°: walk_Down
		return "walk_Down"
	elif degrees >= 30 and degrees < 90:
		# 30° - 90°: walk_Right_Down  
		return "walk_Right_Down"
	elif degrees >= 90 and degrees < 150:
		# 90° - 150°: walk_Right_Up
		return "walk_Right_Up"
	elif degrees >= 150 and degrees < 210:
		# 150° - 210°: walk_Left_Up
		return "walk_Left_Up"
	elif degrees >= 210 and degrees < 270:
		# 210° - 270°: walk_Left_Down
		return "walk_Left_Down"
	elif degrees >= 270 and degrees < 330:
		# 270° - 330°: walk_Up
		return "walk_Up"
	
	return "walk_Down"  # Fallback

func scale_sprite_to_128px():
	"""Escalar sprite a 128px de alto"""
	if not animated_sprite or not sprite_frames:
		return
	
	# Como los frames ya son 128x128, no necesitamos escalar
	animated_sprite.scale = Vector2(1.0, 1.0)

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
