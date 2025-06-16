# scenes/player/AnimationController.gd - SISTEMA CORREGIDO SIN BUGS
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
	
	load_required_atlases()
	create_animations_safely()

func load_required_atlases():
	"""Cargar atlas necesarios con fallback a chica"""
	var folder_name = get_character_folder_name()
	
	print("🎭 Cargando atlas para: ", character_name, " (folder: ", folder_name, ")")
	
	# Intentar cargar walk_Right_Down
	var right_down_path = "res://sprites/player/" + folder_name + "/walk_Right_Down.png"
	walk_right_down_atlas = try_load_texture(right_down_path)
	
	# Intentar cargar walk_Right_Up
	var right_up_path = "res://sprites/player/" + folder_name + "/walk_Right_Up.png"
	walk_right_up_atlas = try_load_texture(right_up_path)
	
	# Fallback a chica si es necesario
	if not walk_right_down_atlas:
		print("⚠️ walk_Right_Down no encontrado, usando chica")
		walk_right_down_atlas = try_load_texture("res://sprites/player/chica/walk_Right_Down.png")
	
	if not walk_right_up_atlas:
		print("⚠️ walk_Right_Up no encontrado, usando chica")
		walk_right_up_atlas = try_load_texture("res://sprites/player/chica/walk_Right_Up.png")
	
	print("✅ Atlas cargados - Down: ", walk_right_down_atlas != null, " Up: ", walk_right_up_atlas != null)

func try_load_texture(path: String) -> Texture2D:
	"""Cargar textura de forma segura"""
	if not ResourceLoader.exists(path):
		print("❌ No existe: ", path)
		return null
	
	var texture = load(path) as Texture2D
	if texture:
		print("✅ Cargado: ", path, " (", texture.get_size(), ")")
		return texture
	else:
		print("❌ Error cargando: ", path)
		return null

func create_animations_safely():
	"""Crear animaciones de forma segura"""
	if not animated_sprite:
		print("❌ No hay AnimatedSprite2D")
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
		print("✅ Sistema de animación listo")

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
	
	print("✅ Animación creada: ", anim_name, " con ", sprite_frames.get_frame_count(anim_name), " frames")

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
		print("❌ Frame ", frame_index, " fuera de rango en atlas de ", atlas_size.x, "x", atlas_size.y)
		return null
	
	var atlas_frame = AtlasTexture.new()
	atlas_frame.atlas = atlas
	atlas_frame.region = Rect2(x_offset, 0, frame_width, frame_height)
	
	return atlas_frame

func duplicate_animation(source_anim: String, target_anim: String):
	"""Duplicar una animación existente"""
	if not sprite_frames or not sprite_frames.has_animation(source_anim):
		print("❌ No se puede duplicar animación: ", source_anim)
		return
	
	sprite_frames.add_animation(target_anim)
	sprite_frames.set_animation_speed(target_anim, sprite_frames.get_animation_speed(source_anim))
	sprite_frames.set_animation_loop(target_anim, sprite_frames.get_animation_loop(source_anim))
	
	var frame_count = sprite_frames.get_frame_count(source_anim)
	for i in range(frame_count):
		var frame_texture = sprite_frames.get_frame_texture(source_anim, i)
		sprite_frames.add_frame(target_anim, frame_texture)
	
	print("✅ Animación duplicada: ", source_anim, " -> ", target_anim)

func create_fallback_animation(anim_name: String):
	"""Crear animación por defecto"""
	if not sprite_frames:
		return
	
	sprite_frames.add_animation(anim_name)
	sprite_frames.set_animation_speed(anim_name, 1.0)
	sprite_frames.set_animation_loop(anim_name, true)
	
	var default_texture = create_default_texture()
	sprite_frames.add_frame(anim_name, default_texture)
	
	print("⚠️ Animación por defecto creada: ", anim_name)

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
	"""SISTEMA SIMPLIFICADO Y ROBUSTO"""
	if not is_system_ready or not animated_sprite or not sprite_frames:
		return
	
	# Usar dirección de apuntado si existe, sino movimiento
	var direction = aim_direction if aim_direction.length() > 0.1 else movement_direction
	
	if direction.length() < 0.1:
		return  # Sin movimiento, mantener animación actual
	
	# Determinar animación y flip
	var target_animation: String
	var target_flip: bool
	
	if direction.y < 0:  # Apuntando hacia arriba
		target_animation = "walk_Right_Up"
		target_flip = direction.x < 0  # Flip si va hacia la izquierda
	else:  # Apuntando hacia abajo
		target_animation = "walk_Right_Down" 
		target_flip = direction.x < 0  # Flip si va hacia la izquierda
	
	# Verificar que la animación existe
	if not sprite_frames.has_animation(target_animation):
		target_animation = "walk_Right_Down"  # Fallback seguro
	
	# APLICAR CAMBIOS SOLO SI SON DIFERENTES
	var animation_changed = false
	var flip_changed = false
	
	if target_animation != current_animation:
		animated_sprite.play(target_animation)
		current_animation = target_animation
		animation_changed = true
	
	if target_flip != current_flip:
		animated_sprite.flip_h = target_flip
		current_flip = target_flip
		flip_changed = true
	
	# Log solo cuando hay cambios
	if animation_changed or flip_changed:
		print("🎭 Animación actualizada: ", target_animation, " flip: ", target_flip)

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
		print("🎭 Forzada animación: ", anim_name)

func get_available_animations() -> Array[String]:
	"""Obtener animaciones disponibles"""
	if sprite_frames:
		return sprite_frames.get_animation_names()
	return []
