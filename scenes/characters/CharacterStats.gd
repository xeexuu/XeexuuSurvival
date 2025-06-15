# scenes/characters/CharacterStats.gd - ARMA CON SPRITE DE PISTOLA ESPECÍFICO
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

func _init():
	call_deferred("ensure_weapon_exists")

func ensure_weapon_exists():
	"""Crear arma por defecto si no existe"""
	if not equipped_weapon:
		equipped_weapon = WeaponStats.new()
		equipped_weapon.weapon_name = "Pistola Básica"
		equipped_weapon.damage = 25
		equipped_weapon.attack_speed = 0.3  # 0.3 balas por segundo
		equipped_weapon.attack_range = 400
		equipped_weapon.projectile_speed = 600
		equipped_weapon.ammo_capacity = 30
		equipped_weapon.reload_time = 2.0
		equipped_weapon.accuracy = 0.95
		equipped_weapon.headshot_multiplier = 1.4
		
		# CARGAR SPRITE ESPECÍFICO DE LA PISTOLA
		load_pistol_sprite_for_weapon()
		
		# POSICIONAMIENTO EN EL CENTRO DERECHA DEL JUGADOR
		equipped_weapon.weapon_offset = Vector2(32, 0)  # Centro derecha
		equipped_weapon.muzzle_offset = Vector2(20, 0)   # Desde donde salen las balas

func load_pistol_sprite_for_weapon():
	"""Cargar sprite específico de la pistola desde sprites/weapons/pistola.png"""
	if not equipped_weapon:
		return
	
	var pistol_path = "res://sprites/weapons/pistola.png"
	
	if ResourceLoader.exists(pistol_path):
		equipped_weapon.weapon_sprite = load(pistol_path) as Texture2D
		print("✅ Sprite de pistola cargado para ", character_name, " desde: ", pistol_path)
	else:
		print("❌ No se encontró sprite en: ", pistol_path, " - Usando sprite por defecto para ", character_name)
		# El WeaponStats se encargará de crear el sprite por defecto

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

# Función para obtener el folder de sprites
func get_sprite_folder() -> String:
	"""Obtener carpeta de sprites basada en el nombre del personaje"""
	var char_name_lower = character_name.to_lower().replace(" ", "")
	
	var name_mappings = {
		"pelao": "pelao",
		"juancar": "juancar",
		"chica": "chica"
	}
	
	return name_mappings.get(char_name_lower, char_name_lower)

# Función para obtener textura idle usando el sistema separado
func get_idle_texture() -> Texture2D:
	"""Obtener textura idle del personaje"""
	var sprite_frames = SpriteEffectsHandler.load_character_sprite_atlas(character_name)
	if sprite_frames and sprite_frames.has_animation("idle"):
		return sprite_frames.get_frame_texture("idle", 0)
	return null

# Función para obtener textura escalada a 128px
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
	return SpriteEffectsHandler.create_default_character_texture(character_name)

# Función para validar el personaje
func is_valid() -> bool:
	"""Verificar si el personaje es válido"""
	return (character_name != "" and 
			character_name != "Personaje" and
			max_health > 0 and
			movement_speed > 0)

# Funciones de información
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
