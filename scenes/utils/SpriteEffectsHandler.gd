# scenes/utils/SpriteEffectsHandler.gd - SIMPLIFICADO
extends Node
class_name SpriteEffectsHandler

static func load_enemy_sprite_atlas(enemy_type: String) -> SpriteFrames:
	"""Cargar atlas de sprites para enemigo"""
	var atlas_path = "res://sprites/enemies/zombie/walk_Right_Down.png"
	var atlas_texture = load_texture_safe(atlas_path)
	
	if atlas_texture:
		return create_sprite_frames_from_atlas(atlas_texture, enemy_type)
	else:
		return create_basic_enemy_sprite_frames(enemy_type)

static func create_sprite_frames_from_atlas(atlas_texture: Texture2D, enemy_type: String) -> SpriteFrames:
	"""Crear SpriteFrames desde un atlas de enemigo"""
	var sprite_frames = SpriteFrames.new()
	
	# IDLE
	sprite_frames.add_animation("idle")
	sprite_frames.set_animation_speed("idle", 4.0)
	sprite_frames.set_animation_loop("idle", true)
	
	# WALK
	sprite_frames.add_animation("walk")
	sprite_frames.set_animation_speed("walk", get_walk_speed_for_enemy_type(enemy_type))
	sprite_frames.set_animation_loop("walk", true)
	
	for i in range(8):
		var frame = extract_frame_from_atlas(atlas_texture, i, 8, 1)
		if i == 0:
			sprite_frames.add_frame("idle", frame)
		sprite_frames.add_frame("walk", frame)
	
	return sprite_frames

static func create_basic_enemy_sprite_frames(enemy_type: String) -> SpriteFrames:
	"""Crear SpriteFrames básicos para enemigo"""
	var sprite_frames = SpriteFrames.new()
	var basic_texture = create_basic_enemy_texture(enemy_type)
	
	sprite_frames.add_animation("idle")
	sprite_frames.add_frame("idle", basic_texture)
	
	sprite_frames.add_animation("walk")
	sprite_frames.set_animation_speed("walk", get_walk_speed_for_enemy_type(enemy_type))
	sprite_frames.set_animation_loop("walk", true)
	sprite_frames.add_frame("walk", basic_texture)
	
	return sprite_frames

static func create_basic_enemy_texture(enemy_type: String) -> Texture2D:
	"""Crear textura básica de enemigo"""
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var color = get_enemy_color(enemy_type)
	image.fill(color)
	
	# Forma humanoide básica
	var center = Vector2(64, 64)
	for x in range(128):
		for y in range(128):
			var dist = Vector2(x, y).distance_to(center)
			if dist < 20:
				image.set_pixel(x, y, Color.WHITE)
			elif dist < 30:
				image.set_pixel(x, y, color.darkened(0.3))
	
	# Ojos rojos
	for x in range(58, 62):
		for y in range(58, 62):
			image.set_pixel(x, y, Color.RED)
	for x in range(66, 70):
		for y in range(58, 62):
			image.set_pixel(x, y, Color.RED)
	
	return ImageTexture.create_from_image(image)

static func get_enemy_color(enemy_type: String) -> Color:
	"""Obtener color por tipo de enemigo"""
	match enemy_type:
		"zombie_dog": return Color.RED
		"zombie_crawler": return Color.LIME
		_: return Color(0.6, 0.6, 0.5, 1.0)

static func get_walk_speed_for_enemy_type(enemy_type: String) -> float:
	"""Obtener velocidad de animación según tipo"""
	match enemy_type:
		"zombie_dog": return 16.0
		"zombie_crawler": return 14.0
		_: return 10.0

static func extract_frame_from_atlas(atlas_texture: Texture2D, frame_index: int, total_h_frames: int, total_v_frames: int) -> Texture2D:
	"""Extraer un frame específico de un atlas"""
	var texture_size = atlas_texture.get_size()
	var frame_width = float(texture_size.x) / float(total_h_frames)
	var frame_height = float(texture_size.y) / float(total_v_frames)
	
	var x = float(frame_index % total_h_frames) * frame_width
	var y = float(frame_index / total_h_frames) * frame_height
	
	var atlas_frame = AtlasTexture.new()
	atlas_frame.atlas = atlas_texture
	atlas_frame.region = Rect2(x, y, frame_width, frame_height)
	
	return atlas_frame

static func load_texture_safe(path: String) -> Texture2D:
	"""Cargar textura de forma segura"""
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

static func create_muzzle_flash_sprite() -> Texture2D:
	"""Crear sprite de flash del cañón"""
	var image = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var center = Vector2(6, 6)
	for x in range(12):
		for y in range(12):
			var dist = Vector2(x, y).distance_to(center)
			if dist < 3:
				image.set_pixel(x, y, Color.YELLOW)
			elif dist < 4:
				image.set_pixel(x, y, Color.ORANGE)
	
	return ImageTexture.create_from_image(image)

static func create_weapon_sprite(_weapon_name: String) -> Texture2D:
	"""Crear sprite básico de arma"""
	var image = Image.create(24, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# Sprite básico de pistola
	for x in range(24):
		for y in range(8):
			if x >= 12 and x < 22 and y >= 3 and y < 5:
				image.set_pixel(x, y, Color.DARK_GRAY)  # Cañón
			elif x >= 2 and x < 12 and y >= 2 and y < 6:
				image.set_pixel(x, y, Color.GRAY)  # Cuerpo
			elif x >= 0 and x < 4 and y >= 4 and y < 8:
				image.set_pixel(x, y, Color.DIM_GRAY)  # Empuñadura
	
	return ImageTexture.create_from_image(image)
