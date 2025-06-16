# scenes/player/AnimationController.gd - SISTEMA DE SPRITES MEJORADO
extends Node
class_name AnimationController

var animated_sprite: AnimatedSprite2D
var sprite_frames: SpriteFrames
var character_name: String

# Estado de animación
var current_aim_direction: Vector2 = Vector2.RIGHT
var last_animation: String = ""

# Atlas disponibles para cada dirección
var available_atlases: Dictionary = {}

func setup(sprite: AnimatedSprite2D, char_name: String):
	"""Configurar controlador de animaciones"""
	animated_sprite = sprite
	character_name = char_name
	load_character_animations()

func load_character_animations():
	"""Cargar todas las animaciones direccionales del personaje"""
	sprite_frames = SpriteFrames.new()
	
	# Cargar todos los atlas direccionales
	load_directional_atlases()
	
	if available_atlases.size() > 0:
		create_animations_from_atlases()
		animated_sprite.sprite_frames = sprite_frames
		animated_sprite.play("walk_Right_Down")  # Animación por defecto
		scale_sprite()
	else:
		create_fallback_animation()

func load_directional_atlases():
	"""Cargar todos los atlas direccionales disponibles"""
	var folder_name = get_character_folder_name()
	var base_path = "res://sprites/player/" + folder_name + "/"
	
	# Lista de direcciones disponibles
	var directions = [
		"walk_Right_Down",
		"walk_Right_Up", 
		"walk_Left_Down",
		"walk_Left_Up",
		"walk_Down",
		"walk_Up"
	]
	
	# Cargar cada atlas direccional
	for direction in directions:
		var atlas_path = base_path + direction + ".png"
		if ResourceLoader.exists(atlas_path):
			var texture = load(atlas_path) as Texture2D
			if texture:
				available_atlases[direction] = texture
	
	# Si no encontramos nada para este personaje, usar chica como fallback
	if available_atlases.is_empty() and folder_name != "chica":
		load_fallback_atlases()

func load_fallback_atlases():
	"""Cargar atlas de chica como fallback"""
	var base_path = "res://sprites/player/chica/"
	var directions = [
		"walk_Right_Down",
		"walk_Right_Up", 
		"walk_Left_Down",
		"walk_Left_Up",
		"walk_Down",
		"walk_Up"
	]
	
	for direction in directions:
		var atlas_path = base_path + direction + ".png"
		if ResourceLoader.exists(atlas_path):
			var texture = load(atlas_path) as Texture2D
			if texture:
				available_atlases[direction] = texture

func create_animations_from_atlases():
	"""Crear animaciones desde los atlas cargados"""
	for direction in available_atlases.keys():
		var atlas = available_atlases[direction]
		create_animation_from_atlas(direction, atlas)
	
	# Crear animación idle usando walk_Right_Down si está disponible
	if available_atlases.has("walk_Right_Down"):
		create_idle_animation()

func create_animation_from_atlas(anim_name: String, atlas: Texture2D):
	"""Crear animación completa desde un atlas de 8 frames"""
	sprite_frames.add_animation(anim_name)
	sprite_frames.set_animation_speed(anim_name, 12.0)
	sprite_frames.set_animation_loop(anim_name, true)
	
	# Extraer los 8 frames del atlas (1024x128 = 8 frames de 128x128)
	for i in range(8):
		var frame = extract_frame_from_atlas(atlas, i)
		sprite_frames.add_frame(anim_name, frame)

func create_idle_animation():
	"""Crear animación idle usando el primer frame de walk_Right_Down"""
	if not available_atlases.has("walk_Right_Down"):
		return
	
	sprite_frames.add_animation("idle")
	sprite_frames.set_animation_speed("idle", 4.0)
	sprite_frames.set_animation_loop("idle", true)
	
	var atlas = available_atlases["walk_Right_Down"]
	var first_frame = extract_frame_from_atlas(atlas, 0)
	sprite_frames.add_frame("idle", first_frame)

func extract_frame_from_atlas(atlas: Texture2D, frame_index: int) -> Texture2D:
	"""Extraer frame específico del atlas 1024x128"""
	var frame_width = 128.0  # Cada frame es 128x128
	var x_offset = float(frame_index) * frame_width
	
	var atlas_frame = AtlasTexture.new()
	atlas_frame.atlas = atlas
	atlas_frame.region = Rect2(x_offset, 0, frame_width, 128.0)
	
	return atlas_frame

func create_fallback_animation():
	"""Crear animación por defecto si no hay atlas"""
	sprite_frames.add_animation("idle")
	sprite_frames.set_animation_speed("idle", 1.0)
	sprite_frames.set_animation_loop("idle", true)
	
	var default_texture = create_default_texture()
	sprite_frames.add_frame("idle", default_texture)
	
	animated_sprite.sprite_frames = sprite_frames
	animated_sprite.play("idle")

func create_default_texture() -> Texture2D:
	"""Crear textura por defecto"""
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	
	var name_hash = character_name.hash()
	var hue = float(abs(name_hash) % 360) / 360.0
	var character_color = Color.from_hsv(hue, 0.7, 0.9)
	
	image.fill(character_color)
	
	# Forma básica de personaje
	var center = Vector2(64, 64)
	for x in range(128):
		for y in range(128):
			var dist = Vector2(x, y).distance_to(center)
			if dist < 20:
				image.set_pixel(x, y, Color.WHITE)
			elif dist < 30:
				image.set_pixel(x, y, character_color.darkened(0.3))
	
	# Ojos
	for eye_x in [54, 74]:
		for x in range(eye_x, eye_x + 8):
			for y in range(54, 62):
				if x >= 0 and x < 128 and y >= 0 and y < 128:
					image.set_pixel(x, y, Color.BLACK)
	
	return ImageTexture.create_from_image(image)

func update_animation(movement_direction: Vector2, aim_direction: Vector2):
	"""Sistema principal de animaciones con orientación correcta"""
	if not animated_sprite or not sprite_frames:
		return
	
	# Priorizar dirección de disparo, luego movimiento
	var direction_to_use = aim_direction if aim_direction.length() > 0.1 else movement_direction
	current_aim_direction = direction_to_use
	
	if direction_to_use.length() > 0.1:
		var target_animation = get_animation_for_direction(direction_to_use)
		
		if target_animation != last_animation:
			if sprite_frames.has_animation(target_animation):
				animated_sprite.play(target_animation)
				last_animation = target_animation
			else:
				# Fallback a la primera animación disponible
				var available_anims = sprite_frames.get_animation_names()
				if available_anims.size() > 0:
					animated_sprite.play(available_anims[0])
					last_animation = available_anims[0]
	else:
		# Sin dirección, usar idle
		if sprite_frames.has_animation("idle") and last_animation != "idle":
			animated_sprite.play("idle")
			last_animation = "idle"

func get_animation_for_direction(direction: Vector2) -> String:
	"""Obtener animación correcta según la dirección especificada"""
	var angle = direction.angle()
	var degrees = rad_to_deg(angle)
	
	# Normalizar a 0-360
	if degrees < 0:
		degrees += 360
	
	# Según tus especificaciones exactas:
	if degrees >= 1 and degrees <= 90:
		# 1º-90º: walk_Right_Down.png
		return "walk_Right_Down"
	elif degrees >= 91 and degrees <= 179:
		# 91º-179º: walk_Right_Up.png
		return "walk_Right_Up"
	elif degrees >= 180 and degrees <= 269:
		# 180º-269º: walk_Right_Up.png invertido horizontalmente
		set_sprite_flip(true)
		return "walk_Right_Up"
	elif degrees >= 270 and degrees <= 360:
		# 270º-360º: walk_Right_Down.png invertido horizontalmente
		set_sprite_flip(true)
		return "walk_Right_Down"
	else:
		# 0º y casos edge: walk_Right_Down.png
		set_sprite_flip(false)
		return "walk_Right_Down"

func set_sprite_flip(flip_h: bool):
	"""Configurar flip horizontal del sprite"""
	if animated_sprite:
		animated_sprite.flip_h = flip_h

func scale_sprite():
	"""Escalar sprite a tamaño apropiado"""
	if animated_sprite:
		animated_sprite.scale = Vector2(1.0, 1.0)  # Mantener tamaño original de 128px

func get_character_folder_name() -> String:
	"""Obtener nombre de carpeta del personaje"""
	var char_name_lower = character_name.to_lower().replace(" ", "")
	
	var name_mappings = {
		"pelao": "pelao",
		"juancar": "juancar",
		"juan_car": "juancar", 
		"chica": "chica"
	}
	
	return name_mappings.get(char_name_lower, char_name_lower)

func get_available_animations() -> Array[String]:
	"""Obtener lista de animaciones disponibles"""
	if sprite_frames:
		return sprite_frames.get_animation_names()
	return []

func force_animation(anim_name: String):
	"""Forzar una animación específica"""
	if animated_sprite and sprite_frames and sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
		last_animation = anim_name
