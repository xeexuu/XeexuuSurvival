# scenes/player/AnimationController.gd - SISTEMA UNIVERSAL DE SPRITES CON FALLBACK A CHICA
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

func setup(sprite: AnimatedSprite2D, char_name: String):
	"""Configurar controlador de animaciones"""
	animated_sprite = sprite
	character_name = char_name
	
	# Resetear estado
	is_system_ready = false
	
	load_required_atlases_universal()
	create_animations_safely()

func load_required_atlases_universal():
	"""SISTEMA UNIVERSAL: Cargar atlas con fallback automático a chica para TODOS los personajes"""
	var folder_name = get_character_folder_name()
	
	print("🎭 [UNIVERSAL] Cargando atlas para: ", character_name, " (folder: ", folder_name, ")")
	
	# CARGAR walk_Right_Down con fallback universal
	walk_right_down_atlas = load_atlas_with_universal_fallback(folder_name, "walk_Right_Down")
	
	# CARGAR walk_Right_Up con fallback universal
	walk_right_up_atlas = load_atlas_with_universal_fallback(folder_name, "walk_Right_Up")
	
	print("✅ [UNIVERSAL] Atlas cargados - Down: ", walk_right_down_atlas != null, " Up: ", walk_right_up_atlas != null)

func load_atlas_with_universal_fallback(folder_name: String, atlas_name: String) -> Texture2D:
	"""FALLBACK UNIVERSAL: Intentar cargar atlas, fallback a chica si falla"""
	
	# PASO 1: Intentar cargar del personaje específico
	var primary_path = "res://sprites/player/" + folder_name + "/" + atlas_name + ".png"
	var texture = try_load_texture(primary_path)
	if texture:
		print("✅ [UNIVERSAL] Cargado directo: ", primary_path)
		return texture
	
	# PASO 2: FALLBACK AUTOMÁTICO A CHICA si no es chica
	if folder_name != "chica":
		var chica_path = "res://sprites/player/chica/" + atlas_name + ".png"
		texture = try_load_texture(chica_path)
		if texture:
			print("⚠️ [UNIVERSAL] Fallback a chica para ", folder_name, ": ", chica_path)
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
			print("✅ [UNIVERSAL] Variante encontrada para ", folder_name, ": ", variant_path)
			return texture
	
	# Probar variantes en chica si no es chica
	if folder_name != "chica":
		for variant in atlas_variants:
			var chica_variant_path = "res://sprites/player/chica/" + variant + ".png"
			texture = try_load_texture(chica_variant_path)
			if texture:
				print("⚠️ [UNIVERSAL] Variante de chica para ", folder_name, ": ", chica_variant_path)
				return texture
	
	# PASO 4: Buscar cualquier archivo de imagen en la carpeta del personaje
	texture = find_any_image_in_folder(folder_name)
	if texture:
		print("⚠️ [UNIVERSAL] Imagen genérica encontrada para ", folder_name)
		return texture
	
	# PASO 5: Buscar cualquier archivo en la carpeta de chica
	if folder_name != "chica":
		texture = find_any_image_in_folder("chica")
		if texture:
			print("⚠️ [UNIVERSAL] Imagen genérica de chica para ", folder_name)
			return texture
	
	# PASO 6: Crear textura por defecto
	print("❌ [UNIVERSAL] No se encontró ningún atlas para ", folder_name, " - ", atlas_name)
	return null

func find_any_image_in_folder(folder_name: String) -> Texture2D:
	"""Buscar cualquier imagen válida en una carpeta de personaje"""
	var possible_files = [
		"walk_Right_Down.png",
		"walk_right_down.png", 
		"walk.png",
		"idle.png",
		"sprite.png",
		"character.png",
		folder_name + ".png"
	]
	
	for file in possible_files:
		var path = "res://sprites/player/" + folder_name + "/" + file
		var texture = try_load_texture(path)
		if texture:
			print("✅ [UNIVERSAL] Imagen alternativa encontrada: ", path)
			return texture
	
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
	
	# Crear animación walk_Right_Down (OBLIGATORIA)
	if walk_right_down_atlas:
		create_animation_from_atlas("walk_Right_Down", walk_right_down_atlas)
	else:
		create_fallback_animation("walk_Right_Down")
	
	# Crear animación walk_Right_Up (OPCIONAL)
	if walk_right_up_atlas:
		create_animation_from_atlas("walk_Right_Up", walk_right_up_atlas)
	else:
		# Si no hay walk_Right_Up, duplicar walk_Right_Down
		duplicate_animation("walk_Right_Down", "walk_Right_Up")
	
	# Asignar al sprite DE UNA SOLA VEZ
	if animated_sprite:
		animated_sprite.sprite_frames = sprite_frames
		animated_sprite.play("walk_Right_Down")
		current_animation = "walk_Right_Down"
		current_flip = false
		is_system_ready = true

func create_animation_from_atlas(anim_name: String, atlas: Texture2D):
	"""Crear animación desde atlas 1024x128"""
	if not atlas or not sprite_frames:
		return
	
	sprite_frames.add_animation(anim_name)
	sprite_frames.set_animation_speed(anim_name, 12.0)
	sprite_frames.set_animation_loop(anim_name, true)
	
	# Extraer 8 frames de 128x128 cada uno
	for i in range(8):
		var frame = extract_frame_from_atlas(atlas, i)
		if frame:
			sprite_frames.add_frame(anim_name, frame)

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

func create_fallback_animation(anim_name: String):
	"""Crear animación por defecto"""
	if not sprite_frames:
		return
	
	sprite_frames.add_animation(anim_name)
	sprite_frames.set_animation_speed(anim_name, 1.0)
	sprite_frames.set_animation_loop(anim_name, true)
	
	var default_texture = create_default_texture()
	sprite_frames.add_frame(anim_name, default_texture)

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

func update_animation(movement_direction: Vector2, aim_direction: Vector2):
	"""SISTEMA EXACTO: Usa atlas según dirección de disparo O dirección de movimiento"""
	if not is_system_ready or not animated_sprite or not sprite_frames:
		return
	
	var direction_to_use = Vector2.ZERO
	
	# PRIORIDAD 1: Si está disparando, usar dirección de disparo
	if aim_direction.length() > 0.1:
		direction_to_use = aim_direction
	# PRIORIDAD 2: Si no dispara pero se mueve, usar dirección de movimiento
	elif movement_direction.length() > 0.1:
		direction_to_use = movement_direction
	# PRIORIDAD 3: Si no hay nada, mantener última animación
	else:
		return
	
	# APLICAR EXACTAMENTE EL MISMO SISTEMA QUE PARA DISPARO:
	# Determinar qué atlas usar según la dirección (Up o Down)
	var target_animation: String
	var target_flip: bool
	
	# Sistema idéntico al de disparo: Y negativo = Up, Y positivo = Down
	if direction_to_use.y < 0:  # Hacia arriba -> usar atlas Up
		target_animation = "walk_Right_Up"
		target_flip = direction_to_use.x < 0  # Flip horizontal si va izquierda
	else:  # Hacia abajo o horizontal -> usar atlas Down
		target_animation = "walk_Right_Down"
		target_flip = direction_to_use.x < 0  # Flip horizontal si va izquierda
	
	# Verificar que la animación existe
	if not sprite_frames.has_animation(target_animation):
		target_animation = "walk_Right_Down"  # Fallback seguro
	
	# Aplicar cambios solo si son diferentes (evitar parpadeos)
	if target_animation != current_animation:
		animated_sprite.play(target_animation)
		current_animation = target_animation
	
	if target_flip != current_flip:
		animated_sprite.flip_h = target_flip
		current_flip = target_flip

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

func get_available_animations() -> Array[String]:
	"""Obtener animaciones disponibles"""
	if sprite_frames:
		return sprite_frames.get_animation_names()
	return []
