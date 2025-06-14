# scenes/characters/CharacterStats.gd
extends Resource
class_name CharacterStats

@export var character_name: String = "Personaje"
@export var max_health: int = 100
@export var current_health: int = 100
@export var movement_speed: int = 300
@export var luck: int = 5

# YA NO HAY SPRITES DEL PERSONAJE - SE USAN LOS ATLAS
# @export var sprite_normal: Texture2D  # ELIMINADO
# @export var sprite_shooting: Texture2D  # ELIMINADO

# Arma equipada - NUEVO SISTEMA
@export var equipped_weapon: WeaponStats

# Habilidades
@export var ability1_name: String = "Habilidad 1"
@export var ability1_cooldown: float = 5.0
@export var ability2_name: String = "Habilidad 2"
@export var ability2_cooldown: float = 8.0

# Estados de las habilidades (no exportados)
var ability1_ready: bool = true
var ability2_ready: bool = true

func _init():
	# Solo crear arma por defecto si no existe
	call_deferred("ensure_weapon_exists")

func ensure_weapon_exists():
	if not equipped_weapon:
		# Crear pistola básica por defecto
		equipped_weapon = WeaponStats.new()
		equipped_weapon.weapon_name = "Pistola Básica"
		equipped_weapon.damage = 25
		equipped_weapon.attack_speed = 1.5
		equipped_weapon.attack_range = 400
		equipped_weapon.projectile_speed = 600
		equipped_weapon.ammo_capacity = -1
		
		# Intentar cargar sonido de disparo si existe
		if ResourceLoader.exists("res://audio/pelao_shoot.ogg"):
			equipped_weapon.attack_sound = load("res://audio/pelao_shoot.ogg")
		
		print("🔫 Arma por defecto creada para: ", character_name)

# Funciones de conveniencia para acceder a estadísticas del arma
func get_damage() -> int:
	return equipped_weapon.damage if equipped_weapon else 1

func get_attack_speed() -> float:
	return equipped_weapon.attack_speed if equipped_weapon else 1.0

func get_attack_range() -> int:
	return equipped_weapon.attack_range if equipped_weapon else 300

func get_projectile_speed() -> int:
	return equipped_weapon.projectile_speed if equipped_weapon else 600

func get_attack_sound() -> AudioStream:
	return equipped_weapon.attack_sound if equipped_weapon else null

# Función para obtener el folder de sprites basado en el nombre
func get_sprite_folder() -> String:
	var char_name_lower = character_name.to_lower().replace(" ", "")
	
	# Mapeo de nombres a carpetas
	var name_mappings = {
		"pelao": "pelao",
		"juancar": "juancar",
		"chica": "chica"
	}
	
	return name_mappings.get(char_name_lower, char_name_lower)

# Función para obtener el sprite idle desde el atlas
func get_idle_texture() -> Texture2D:
	var folder = get_sprite_folder()
	var atlas_path = "res://sprites/player/" + folder + "/walk_Right_Down.png"
	
	if ResourceLoader.exists(atlas_path):
		var atlas = load(atlas_path) as Texture2D
		if atlas:
			# Extraer primer frame del atlas (8 frames horizontales)
			var atlas_texture = AtlasTexture.new()
			atlas_texture.atlas = atlas
			var frame_width = atlas.get_size().x / 8.0
			var frame_height = atlas.get_size().y
			atlas_texture.region = Rect2(0, 0, frame_width, frame_height)
			return atlas_texture
	
	return null

# Función para validar el personaje
func is_valid() -> bool:
	return (character_name != "" and 
			character_name != "Personaje" and
			max_health > 0 and
			movement_speed > 0)

# Función para debug
func print_character_info():
	print("=== INFORMACIÓN DEL PERSONAJE ===")
	print("Nombre: ", character_name)
	print("Vida: ", current_health, "/", max_health)
	print("Velocidad: ", movement_speed)
	print("Suerte: ", luck)
	print("Folder de sprites: ", get_sprite_folder())
	print("Tiene idle desde atlas: ", "Sí" if get_idle_texture() else "No")
	if equipped_weapon:
		print("Arma: ", equipped_weapon.weapon_name)
		print("  - Daño: ", equipped_weapon.damage)
		print("  - Velocidad de ataque: ", equipped_weapon.attack_speed)
		print("  - Rango: ", equipped_weapon.attack_range)
		print("  - Sprite del arma: ", "Sí" if equipped_weapon.weapon_sprite else "No")
		print("  - Sonido: ", "Sí" if equipped_weapon.attack_sound else "No")
	else:
		print("Arma: Ninguna")
	print("==================================")

# Función para obtener el sprite idle escalado dinámicamente a 128px
func get_idle_texture_scaled_128px() -> Texture2D:
	var base_texture = get_idle_texture()
	if not base_texture:
		return create_default_character_texture_128px()
	
	return scale_texture_to_128px(base_texture)

func scale_texture_to_128px(original_texture: Texture2D) -> Texture2D:
	"""Escalar cualquier textura a 128px de alto manteniendo proporción"""
	if not original_texture:
		return create_default_character_texture_128px()
	
	var original_size = original_texture.get_size()
	
	# Si ya tiene 128px de alto, retornar original
	if original_size.y == 128:
		return original_texture
	
	# Calcular nueva escala manteniendo proporción
	var scale_factor = 128.0 / original_size.y
	var new_width = int(original_size.x * scale_factor)
	var new_height = 128
	
	# Crear nueva imagen escalada
	var original_image = original_texture.get_image()
	var scaled_image = original_image.duplicate()
	scaled_image.resize(new_width, new_height, Image.INTERPOLATE_NEAREST)
	
	var scaled_texture = ImageTexture.create_from_image(scaled_image)
	
	print("📏 Personaje '", character_name, "' escalado de ", original_size, " a ", Vector2(new_width, new_height))
	return scaled_texture

func create_default_character_texture_128px() -> Texture2D:
	"""Crear textura por defecto de 128px para personajes"""
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	
	# Color único basado en el hash del nombre
	var name_hash = character_name.hash()
	var hue = float(abs(name_hash) % 360) / 360.0
	var character_color = Color.from_hsv(hue, 0.7, 0.9)
	
	image.fill(character_color)
	
	# Agregar detalles básicos
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
	var eye_size = 8
	for x in range(64 - 15, 64 - 15 + eye_size):
		for y in range(64 - 15, 64 - 15 + eye_size):
			if x >= 0 and x < 128 and y >= 0 and y < 128:
				image.set_pixel(x, y, Color.BLACK)
	
	for x in range(64 + 7, 64 + 7 + eye_size):
		for y in range(64 - 15, 64 - 15 + eye_size):
			if x >= 0 and x < 128 and y >= 0 and y < 128:
				image.set_pixel(x, y, Color.BLACK)
	
	return ImageTexture.create_from_image(image)
