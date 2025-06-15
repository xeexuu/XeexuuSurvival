# scenes/utils/SpriteEffectsHandler.gd - ERRORES CORREGIDOS
extends Node
class_name SpriteEffectsHandler

# Sistema unificado para manejar sprites y efectos visuales

# ===== SPRITES =====

static func load_character_sprite_atlas(character_name: String) -> SpriteFrames:
	"""Cargar atlas de sprites para personaje"""
	var folder_name = get_character_folder_name(character_name)
	var atlas_path = "res://sprites/player/" + folder_name + "/walk_Right_Down.png"
	var atlas_texture = load_texture_safe(atlas_path)
	
	if not atlas_texture:
		# Fallback a chica
		atlas_path = "res://sprites/player/chica/walk_Right_Down.png"
		atlas_texture = load_texture_safe(atlas_path)
	
	if atlas_texture:
		return create_sprite_frames_from_atlas(atlas_texture, "player")
	else:
		return create_default_character_sprite_frames(character_name)

static func load_enemy_sprite_atlas(enemy_type: String) -> SpriteFrames:
	"""Cargar atlas de sprites para enemigo"""
	var atlas_path = "res://sprites/enemies/" + enemy_type + "/walk_Right_Down.png"
	var atlas_texture = load_texture_safe(atlas_path)
	
	if atlas_texture:
		return create_sprite_frames_from_atlas(atlas_texture, "enemy")
	else:
		return create_default_enemy_sprite_frames(enemy_type)

static func create_sprite_frames_from_atlas(atlas_texture: Texture2D, _entity_type: String) -> SpriteFrames:
	"""Crear SpriteFrames desde un atlas"""
	var sprite_frames = SpriteFrames.new()
	
	# Animación idle
	sprite_frames.add_animation("idle")
	sprite_frames.set_animation_speed("idle", 2.0)
	sprite_frames.set_animation_loop("idle", true)
	
	var first_frame = extract_frame_from_atlas(atlas_texture, 0, 8, 1)
	sprite_frames.add_frame("idle", first_frame)
	
	# Animación de caminar
	sprite_frames.add_animation("walk")
	sprite_frames.set_animation_speed("walk", 8.0)
	sprite_frames.set_animation_loop("walk", true)
	
	# Cargar todos los frames
	for i in range(8):
		var frame = extract_frame_from_atlas(atlas_texture, i, 8, 1)
		sprite_frames.add_frame("walk", frame)
	
	# Animaciones adicionales usando los mismos frames
	var additional_anims = ["walk_Up", "walk_Down", "walk_Left", "walk_Right"]
	for anim_name in additional_anims:
		sprite_frames.add_animation(anim_name)
		sprite_frames.set_animation_speed(anim_name, 8.0)
		sprite_frames.set_animation_loop(anim_name, true)
		
		for i in range(8):
			var frame = sprite_frames.get_frame_texture("walk", i)
			sprite_frames.add_frame(anim_name, frame)
	
	return sprite_frames

static func extract_frame_from_atlas(atlas_texture: Texture2D, frame_index: int, total_h_frames: int, total_v_frames: int) -> Texture2D:
	"""Extraer un frame específico de un atlas"""
	var texture_size = atlas_texture.get_size()
	var frame_width = float(texture_size.x) / float(total_h_frames)
	var frame_height = float(texture_size.y) / float(total_v_frames)
	
	var x = float(frame_index % total_h_frames) * frame_width
	var y = float(frame_index / total_h_frames) * frame_height  # CORREGIDO: float division
	
	var atlas_frame = AtlasTexture.new()
	atlas_frame.atlas = atlas_texture
	atlas_frame.region = Rect2(x, y, frame_width, frame_height)
	
	return atlas_frame

static func create_default_character_sprite_frames(character_name: String) -> SpriteFrames:
	"""Crear SpriteFrames por defecto para personaje"""
	var sprite_frames = SpriteFrames.new()
	var default_texture = create_default_character_texture(character_name)
	
	sprite_frames.add_animation("idle")
	sprite_frames.add_frame("idle", default_texture)
	
	sprite_frames.add_animation("walk")
	sprite_frames.add_frame("walk", default_texture)
	
	return sprite_frames

static func create_default_enemy_sprite_frames(enemy_type: String) -> SpriteFrames:
	"""Crear SpriteFrames por defecto para enemigo"""
	var sprite_frames = SpriteFrames.new()
	var default_texture = create_default_enemy_texture(enemy_type)
	
	sprite_frames.add_animation("idle")
	sprite_frames.add_frame("idle", default_texture)
	
	sprite_frames.add_animation("walk")
	sprite_frames.add_frame("walk", default_texture)
	
	return sprite_frames

static func create_default_character_texture(character_name: String) -> Texture2D:
	"""Crear textura por defecto para personaje escalada a 128px"""
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	
	var name_hash = character_name.hash()
	var hue = float(abs(name_hash) % 360) / 360.0
	var character_color = Color.from_hsv(hue, 0.7, 0.9)
	
	image.fill(character_color)
	
	# Detalles básicos
	var _center = Vector2(64, 64)  # CORREGIDO: variable prefijada con _
	for x in range(128):
		for y in range(128):
			var dist = Vector2(x, y).distance_to(Vector2(64, 64))
			if dist < 15:
				image.set_pixel(x, y, Color.WHITE)
			elif dist < 25:
				image.set_pixel(x, y, character_color.darkened(0.3))
			elif dist < 35:
				image.set_pixel(x, y, character_color.darkened(0.1))
	
	# Ojos
	add_eyes_to_image(image, 64, 64, 6)
	
	return ImageTexture.create_from_image(image)

static func create_default_enemy_texture(_enemy_type: String) -> Texture2D:
	"""Crear textura por defecto para enemigo escalada a 128px"""
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color.DARK_RED)
	
	var _center = Vector2(64, 64)  # CORREGIDO: variable prefijada con _
	for x in range(128):
		for y in range(128):
			var dist = Vector2(x - 64, y - 64).length()
			if dist < 20:
				image.set_pixel(x, y, Color.DARK_RED.darkened(0.3))
			elif dist < 30:
				image.set_pixel(x, y, Color.RED.darkened(0.2))
	
	# Ojos rojos
	add_eyes_to_image(image, 64, 64, 8, Color.RED)
	
	return ImageTexture.create_from_image(image)

static func add_eyes_to_image(image: Image, center_x: int, center_y: int, eye_size: int, eye_color: Color = Color.BLACK):
	"""Añadir ojos a una imagen"""
	var eye_offset = 15
	
	# Ojo izquierdo
	for x in range(center_x - eye_offset, center_x - eye_offset + eye_size):
		for y in range(center_y - eye_offset, center_y - eye_offset + eye_size):
			if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
				image.set_pixel(x, y, eye_color)
	
	# Ojo derecho
	for x in range(center_x + eye_offset - eye_size, center_x + eye_offset):
		for y in range(center_y - eye_offset, center_y - eye_offset + eye_size):
			if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
				image.set_pixel(x, y, eye_color)

static func scale_sprite_to_128px(sprite: Node2D, reference_texture: Texture2D):
	"""Escalar sprite a 128px de alto"""
	if not reference_texture or not sprite:
		return
	
	var current_height = reference_texture.get_size().y
	var target_height = 128.0
	
	if current_height == target_height:
		sprite.scale = Vector2(1.0, 1.0)
		return
	
	var scale_factor = target_height / float(current_height)
	sprite.scale = Vector2(scale_factor, scale_factor)

static func get_character_folder_name(character_name: String) -> String:
	"""Obtener nombre de carpeta para personaje"""
	var char_name_lower = character_name.to_lower().replace(" ", "")
	
	var name_mappings = {
		"pelao": "pelao",
		"juancar": "juancar",
		"juan_car": "juancar",
		"chica": "chica"
	}
	
	return name_mappings.get(char_name_lower, char_name_lower)

static func load_texture_safe(path: String) -> Texture2D:
	"""Cargar textura de forma segura"""
	if not ResourceLoader.exists(path):
		return null
	
	var resource = load(path)
	if resource is Texture2D:
		return resource as Texture2D
	else:
		return null

# ===== EFECTOS VISUALES =====

static func create_headshot_effect(position: Vector2, scene: Node) -> void:
	"""Crear efecto especial para headshots"""
	if not scene:
		return
	
	var effect = Node2D.new()
	effect.position = position
	
	# Más partículas y colores diferentes para headshots
	for i in range(8):
		var particle = create_effect_particle(Color.YELLOW, 6)
		
		var offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
		particle.position = offset
		effect.add_child(particle)
		
		# Animar partícula con más movimiento
		var tween = effect.create_tween()
		tween.parallel().tween_property(particle, "position", offset * 3, 0.5)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.parallel().tween_property(particle, "scale", Vector2(1.5, 1.5), 0.3)
	
	scene.add_child(effect)
	cleanup_effect_after_delay(effect, 0.6)

static func create_damage_effect(position: Vector2, scene: Node) -> void:
	"""Crear efecto de daño normal"""
	if not scene:
		return
	
	var effect = Node2D.new()
	effect.position = position
	
	for i in range(4):
		var particle = create_effect_particle(Color.WHITE, 4)
		
		var offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
		particle.position = offset
		effect.add_child(particle)
		
		var tween = effect.create_tween()
		tween.parallel().tween_property(particle, "position", offset * 2, 0.3)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.3)
	
	scene.add_child(effect)
	cleanup_effect_after_delay(effect, 0.4)

static func create_grab_effect(position: Vector2, scene: Node) -> void:
	"""Crear efecto de agarre estilo COD Black Ops"""
	if not scene:
		return
	
	var effect = Node2D.new()
	effect.position = position
	
	for i in range(6):
		var particle = create_effect_particle(Color.PURPLE, 6)
		
		var angle = (float(i) * PI * 2.0) / 6.0
		var offset = Vector2.from_angle(angle) * randf_range(15, 30)
		particle.position = offset
		
		effect.add_child(particle)
		
		var tween = effect.create_tween()
		tween.parallel().tween_property(particle, "position", offset * 2, 0.5)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.parallel().tween_property(particle, "scale", Vector2.ZERO, 0.5)
	
	scene.add_child(effect)
	cleanup_effect_after_delay(effect, 1.0)

static func create_explosion_effect(position: Vector2, scene: Node) -> void:
	"""Crear efecto de explosión"""
	if not scene:
		return
	
	var effect = Node2D.new()
	effect.position = position
	
	for i in range(8):
		var particle = create_effect_particle(Color.ORANGE, 6)
		
		var angle = (float(i) * PI * 2.0) / 8.0
		var offset = Vector2.from_angle(angle) * randf_range(10, 25)
		particle.position = offset
		effect.add_child(particle)
		
		var tween = effect.create_tween()
		tween.parallel().tween_property(particle, "position", offset * 2, 0.5)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.parallel().tween_property(particle, "scale", Vector2.ZERO, 0.5)
	
	scene.add_child(effect)
	cleanup_effect_after_delay(effect, 0.6)

static func create_piercing_effect(position: Vector2, scene: Node) -> void:
	"""Crear efecto de bala perforante"""
	if not scene:
		return
	
	var effect = Node2D.new()
	effect.position = position
	
	for i in range(5):
		var particle = create_effect_particle(Color.CYAN, 4)
		
		var offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
		particle.position = offset
		effect.add_child(particle)
		
		var tween = effect.create_tween()
		tween.parallel().tween_property(particle, "position", offset * 2, 0.3)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.3)
	
	scene.add_child(effect)
	cleanup_effect_after_delay(effect, 0.4)

static func create_score_popup_effect(points: int, position: Vector2, popup_type: String, scene: Node) -> void:
	"""Crear popup de puntuación estilo COD Black Ops"""
	if not scene:
		return
	
	var popup = Control.new()
	popup.size = Vector2(150, 50)
	popup.z_index = 100
	
	var label = Label.new()
	label.text = "+" + str(points)
	
	var color = Color.WHITE
	var font_size = 28
	
	match popup_type:
		"headshot":
			color = Color(1.0, 0.8, 0.0, 1.0)
			font_size = 32
			label.text = "HEADSHOT! +" + str(points)
		"grab":
			color = Color(1.0, 0.2, 0.2, 1.0)
			font_size = 32
			label.text = "GRAB! +" + str(points)
		"bonus":
			color = Color(0.2, 1.0, 0.2, 1.0)
			font_size = 26
		_:
			color = Color.WHITE
			font_size = 28
	
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	popup.add_child(label)
	scene.add_child(popup)
	popup.global_position = position
	
	animate_score_popup(popup)

static func animate_score_popup(popup: Control) -> void:
	"""Animar popup de puntuación estilo COD Black Ops"""
	var tween = popup.create_tween()
	
	var end_position = popup.global_position + Vector2(randf_range(-20, 20), -100)
	tween.parallel().tween_property(popup, "global_position", end_position, 1.8)
	
	popup.scale = Vector2.ZERO
	tween.parallel().tween_property(popup, "scale", Vector2(1.4, 1.4), 0.3)
	tween.parallel().tween_property(popup, "scale", Vector2(1.0, 1.0), 0.4)
	
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 1.2)
	
	tween.tween_callback(func(): popup.queue_free())

static func create_effect_particle(color: Color, size: int) -> Sprite2D:
	"""Crear partícula de efecto"""
	var particle = Sprite2D.new()
	var particle_image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	particle_image.fill(color)
	particle.texture = ImageTexture.create_from_image(particle_image)
	return particle

static func cleanup_effect_after_delay(effect: Node, delay: float) -> void:
	"""Limpiar efecto después de un delay"""
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = delay
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(func(): 
		if is_instance_valid(effect):
			effect.queue_free()
	)
	effect.add_child(cleanup_timer)
	cleanup_timer.start()

# ===== MUZZLE FLASH =====

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
			elif dist < 5:
				image.set_pixel(x, y, Color(1.0, 0.5, 0.0, 0.7))
	
	return ImageTexture.create_from_image(image)

static func create_weapon_sprite(_weapon_name: String) -> Texture2D:
	"""Crear sprite básico de arma"""
	var image = Image.create(24, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# Sprite básico de pistola horizontal
	for x in range(24):
		for y in range(8):
			# Cañón
			if x >= 12 and x < 22 and y >= 3 and y < 5:
				image.set_pixel(x, y, Color.DARK_GRAY)
			# Cuerpo del arma
			elif x >= 2 and x < 12 and y >= 2 and y < 6:
				image.set_pixel(x, y, Color.GRAY)
			# Empuñadura
			elif x >= 0 and x < 4 and y >= 4 and y < 8:
				image.set_pixel(x, y, Color.DIM_GRAY)
			# Mira
			elif x >= 18 and x < 20 and y >= 1 and y < 3:
				image.set_pixel(x, y, Color.BLACK)
	
	return ImageTexture.create_from_image(image)
