# scenes/characters/CharacterStats.gd - COMPATIBILIDAD CON SISTEMA DE ANIMACIONES CORREGIDO
extends Resource
class_name CharacterStats

@export var character_name: String = "Personaje"
@export var max_health: int = 4
@export var current_health: int = 4
@export var movement_speed: int = 300
@export var luck: int = 5

# Arma equipada
@export var equipped_weapon: WeaponStats

# Habilidades
@export var ability1_name: String = "Habilidad 1"
@export var ability1_cooldown: float = 5.0
@export var ability2_name: String = "Habilidad 2"
@export var ability2_cooldown: float = 8.0

# Estados de las habilidades (no exportados)
var ability1_ready: bool = true
var ability2_ready: bool = true

# Sistema de frases y sonidos
@export var voice_lines_kill: Array[String] = []
@export var voice_kill_chance: float = 0.3  # 30% probabilidad

func _init():
	call_deferred("ensure_weapon_exists")
	call_deferred("setup_voice_lines")

func setup_voice_lines():
	"""Configurar frases de kill según personaje"""
	match character_name.to_lower():
		"pelao":
			voice_lines_kill = [
				"¡Toma esa!",
				"¡Fuera de aquí!",
				"¡Otro más!",
				"¡Perfecto!"
			]
		"juancar":
			voice_lines_kill = [
				"¡Eliminado!",
				"¡Buen tiro!",
				"¡En el blanco!",
				"¡Siguiente!"
			]
		"chica":
			voice_lines_kill = [
				"¡Muy bien!",
				"¡Excelente!",
				"¡Directo!",
				"¡Listo!"
			]
		_:
			voice_lines_kill = ["¡Eliminado!"]

func get_random_kill_phrase() -> String:
	"""Obtener frase aleatoria de kill"""
	if voice_lines_kill.is_empty():
		return "¡Eliminado!"
	return voice_lines_kill[randi() % voice_lines_kill.size()]

func should_say_kill_phrase() -> bool:
	"""Verificar si debe decir frase (probabilidad)"""
	return randf() < voice_kill_chance

func ensure_weapon_exists():
	"""Crear arma por defecto si no existe"""
	if not equipped_weapon:
		equipped_weapon = WeaponStats.new()
		equipped_weapon.weapon_name = "Pistola Básica"
		equipped_weapon.damage = 25
		equipped_weapon.attack_speed = 0.3
		equipped_weapon.attack_range = 400
		equipped_weapon.projectile_speed = 600
		equipped_weapon.ammo_capacity = 30
		equipped_weapon.reload_time = 2.0
		equipped_weapon.accuracy = 0.95
		equipped_weapon.headshot_multiplier = 1.4
		
		load_pistol_sprite_for_weapon()
		
		equipped_weapon.weapon_offset = Vector2(32, 0)
		equipped_weapon.muzzle_offset = Vector2(20, 0)

func load_pistol_sprite_for_weapon():
	"""Cargar sprite Y sonido específico de la pistola"""
	if not equipped_weapon:
		return
	
	var pistol_path = "res://sprites/weapons/pistola.png"
	if ResourceLoader.exists(pistol_path):
		equipped_weapon.weapon_sprite = load(pistol_path) as Texture2D
	
	# CARGAR SONIDO ESPECÍFICO DEL PERSONAJE
	var sound_path = "res://audio/" + character_name.to_lower() + "_shoot.ogg"
	if ResourceLoader.exists(sound_path):
		equipped_weapon.attack_sound = load(sound_path)
	else:
		# FALLBACK A PELAO
		var pelao_sound_path = "res://audio/pelao_shoot.ogg"
		if ResourceLoader.exists(pelao_sound_path):
			equipped_weapon.attack_sound = load(pelao_sound_path)

func load_character_sound_with_fallback(sound_type: String) -> AudioStream:
	"""Cargar sonido del personaje con fallback a pelao"""
	var char_name = character_name.to_lower()
	var sound_path = "res://audio/" + char_name + "_" + sound_type + ".ogg"
	
	if ResourceLoader.exists(sound_path):
		return load(sound_path)
	else:
		var pelao_path = "res://audio/pelao_" + sound_type + ".ogg"
		if ResourceLoader.exists(pelao_path):
			return load(pelao_path)
		else:
			return null

# Funciones de acceso a estadísticas del arma
func get_damage() -> int:
	return equipped_weapon.damage if equipped_weapon else 25

func get_attack_speed() -> float:
	return equipped_weapon.attack_speed if equipped_weapon else 0.3

func get_attack_range() -> int:
	return equipped_weapon.attack_range if equipped_weapon else 400

func get_projectile_speed() -> int:
	return equipped_weapon.projectile_speed if equipped_weapon else 600

func get_attack_sound() -> AudioStream:
	return equipped_weapon.attack_sound if equipped_weapon else null

func get_sprite_folder() -> String:
	"""Obtener carpeta de sprites basada en el nombre del personaje"""
	var char_name_lower = character_name.to_lower().replace(" ", "")
	
	var name_mappings = {
		"pelao": "pelao",
		"juancar": "juancar",
		"chica": "chica"
	}
	
	return name_mappings.get(char_name_lower, char_name_lower)

func get_idle_texture() -> Texture2D:
	"""Obtener textura idle del personaje usando PRIMER FRAME de walk_Right_Down"""
	var sprite_folder = get_sprite_folder()
	var walk_right_down_path = "res://sprites/player/" + sprite_folder + "/walk_Right_Down.png"
	
	if ResourceLoader.exists(walk_right_down_path):
		var atlas_texture = load(walk_right_down_path) as Texture2D
		if atlas_texture:
			# Extraer primer frame del atlas
			var frame_width = 128.0
			var atlas_frame = AtlasTexture.new()
			atlas_frame.atlas = atlas_texture
			atlas_frame.region = Rect2(0, 0, frame_width, 128.0)
			return atlas_frame
	
	# Fallback a chica
	var chica_path = "res://sprites/player/chica/walk_Right_Down.png"
	if ResourceLoader.exists(chica_path):
		var atlas_texture = load(chica_path) as Texture2D
		if atlas_texture:
			var frame_width = 128.0
			var atlas_frame = AtlasTexture.new()
			atlas_frame.atlas = atlas_texture
			atlas_frame.region = Rect2(0, 0, frame_width, 128.0)
			return atlas_frame
	
	return create_default_character_texture_128px()

func get_idle_texture_scaled_128px() -> Texture2D:
	"""Obtener textura idle escalada a 128px"""
	var base_texture = get_idle_texture()
	if not base_texture:
		return create_default_character_texture_128px()
	
	return scale_texture_to_128px(base_texture)

func scale_texture_to_128px(original_texture: Texture2D) -> Texture2D:
	"""Escalar textura a 128px de alto"""
	if not original_texture:
		return create_default_character_texture_128px()
	
	var original_size = original_texture.get_size()
	
	if original_size.y == 128:
		return original_texture
	
	var scale_factor = 128.0 / original_size.y
	var new_width = int(original_size.x * scale_factor)
	var new_height = 128
	
	var original_image = original_texture.get_image()
	var scaled_image = original_image.duplicate()
	scaled_image.resize(new_width, new_height, Image.INTERPOLATE_NEAREST)
	
	return ImageTexture.create_from_image(scaled_image)

func create_default_character_texture_128px() -> Texture2D:
	"""Crear textura por defecto de 128px para personajes"""
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	
	# Color basado en hash del nombre
	var name_hash = character_name.hash()
	var hue = float(abs(name_hash) % 360) / 360.0
	var character_color = Color.from_hsv(hue, 0.7, 0.9)
	
	image.fill(character_color)
	
	# Detalles básicos del personaje
	var center = Vector2(64, 64)
	for x in range(128):
		for y in range(128):
			var dist = Vector2(x, y).distance_to(center)
			if dist < 15:
				image.set_pixel(x, y, Color.WHITE)  # Cara
			elif dist < 25:
				image.set_pixel(x, y, character_color.darkened(0.3))
			elif dist < 35:
				image.set_pixel(x, y, character_color.darkened(0.1))
	
	# Ojos
	for x in range(54, 64):
		for y in range(54, 64):
			image.set_pixel(x, y, Color.BLACK)
	
	for x in range(64, 74):
		for y in range(54, 64):
			image.set_pixel(x, y, Color.BLACK)
	
	return ImageTexture.create_from_image(image)

func is_valid() -> bool:
	"""Verificar si el personaje es válido"""
	return (character_name != "" and 
			character_name != "Personaje" and
			max_health > 0 and
			movement_speed > 0)

func get_stats_summary() -> Dictionary:
	"""Obtener resumen de estadísticas del personaje"""
	var stats = {
		"name": character_name,
		"health": str(current_health) + "/" + str(max_health),
		"speed": movement_speed,
		"luck": luck
	}
	
	if equipped_weapon:
		stats["weapon"] = {
			"name": equipped_weapon.weapon_name,
			"damage": equipped_weapon.damage,
			"attack_speed": equipped_weapon.attack_speed,
			"range": equipped_weapon.attack_range
		}
	
	return stats

func get_available_atlas_paths() -> Dictionary:
	"""Obtener rutas de atlas disponibles para el sistema de animaciones"""
	var sprite_folder = get_sprite_folder()
	
	return {
		"walk_right_down": "res://sprites/player/" + sprite_folder + "/walk_Right_Down.png",
		"walk_right_up": "res://sprites/player/" + sprite_folder + "/walk_Right_Up.png",
		# Fallbacks
		"fallback_walk_right_down": "res://sprites/player/chica/walk_Right_Down.png",
		"fallback_walk_right_up": "res://sprites/player/chica/walk_Right_Up.png"
	}

func verify_atlas_availability() -> Dictionary:
	"""Verificar qué atlas están disponibles"""
	var atlas_paths = get_available_atlas_paths()
	var availability = {}
	
	for atlas_name in atlas_paths:
		var path = atlas_paths[atlas_name]
		availability[atlas_name] = ResourceLoader.exists(path)
	
	return availability
