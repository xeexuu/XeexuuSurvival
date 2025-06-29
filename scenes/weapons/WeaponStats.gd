# scenes/weapons/WeaponStats.gd - SPRITE DEL ARMA DOBLE DE GRANDE
extends Resource
class_name WeaponStats

@export var weapon_name: String = "Pistola"
@export var weapon_type: String = "ranged"
@export var damage: int = 25
@export var attack_speed: float = 3.0  # 3 balas por segundo
@export var attack_range: int = 300
@export var projectile_speed: int = 600
@export var ammo_capacity: int = 30
@export var reload_time: float = 2.0
@export var accuracy: float = 1.0
@export var spread_angle: float = 0.0
@export var bullets_per_shot: int = 1

@export var headshot_multiplier: float = 1.4

@export var weapon_sprite: Texture2D
@export var weapon_shooting_sprite: Texture2D
@export var muzzle_flash_sprite: Texture2D
@export var attack_sound: AudioStream

@export var weapon_offset: Vector2 = Vector2(32, 0)
@export var weapon_rotation_offset: float = 0.0
@export var muzzle_offset: Vector2 = Vector2(20, 0)

@export var has_piercing: bool = false
@export var has_explosive: bool = false
@export var knockback_force: float = 0.0

@export var shooting_animation_duration: float = 0.2
@export var recoil_distance: float = 2.0

var current_ammo: int
var is_reloading: bool = false
var is_shooting: bool = false
var reload_timer: Timer

func _init():
	current_ammo = ammo_capacity
	call_deferred("ensure_sprites_exist")
	call_deferred("setup_reload_timer")

func setup_reload_timer():
	"""Configurar el timer de recarga"""
	reload_timer = Timer.new()
	reload_timer.name = "ReloadTimer"
	reload_timer.one_shot = true
	reload_timer.timeout.connect(_on_reload_finished)

func _on_reload_finished():
	"""Cuando termina la recarga"""
	finish_reload()

func ensure_sprites_exist():
	# CARGAR SPRITE ESPECÍFICO DE LA PISTOLA
	if not weapon_sprite:
		load_pistol_sprite()

func load_pistol_sprite():
	"""Cargar sprite específico de la pistola desde sprites/weapons/pistola.png"""
	var pistol_path = "res://sprites/weapons/pistola.png"
	
	if ResourceLoader.exists(pistol_path):
		weapon_sprite = load(pistol_path) as Texture2D
		print("✅ Sprite de pistola cargado desde: ", pistol_path)
	else:
		print("❌ No se encontró sprite en: ", pistol_path, " - Creando sprite por defecto")
		create_default_weapon_sprite()

func create_default_weapon_sprite():
	"""Crear sprite por defecto DOBLE DE GRANDE"""
	var image = Image.create(96, 32, false, Image.FORMAT_RGBA8)  # DOBLE DE TAMAÑO (antes 48x16)
	image.fill(Color.TRANSPARENT)
	
	# Crear sprite básico de pistola horizontal MÁS GRANDE
	for x in range(96):
		for y in range(32):
			# Cañón - DOBLE DE GRANDE
			if x >= 48 and x < 88 and y >= 12 and y < 20:
				image.set_pixel(x, y, Color.DARK_GRAY)
			# Cuerpo del arma - DOBLE DE GRANDE
			elif x >= 8 and x < 48 and y >= 8 and y < 24:
				image.set_pixel(x, y, Color.GRAY)
			# Empuñadura - DOBLE DE GRANDE
			elif x >= 0 and x < 16 and y >= 16 and y < 32:
				image.set_pixel(x, y, Color.DIM_GRAY)
			# Mira - DOBLE DE GRANDE
			elif x >= 72 and x < 80 and y >= 4 and y < 12:
				image.set_pixel(x, y, Color.BLACK)
	
	weapon_sprite = ImageTexture.create_from_image(image)
	print("✅ Sprite de arma por defecto creado DOBLE DE GRANDE (96x32)")

func create_muzzle_flash_sprite():
	"""Crear sprite de flash del cañón si no existe - TAMBIÉN MÁS GRANDE"""
	if muzzle_flash_sprite:
		return
	
	var image = Image.create(24, 24, false, Image.FORMAT_RGBA8)  # DOBLE DE TAMAÑO (antes 12x12)
	image.fill(Color.TRANSPARENT)
	
	# Crear flash circular MÁS GRANDE
	var center = Vector2(12, 12)  # DOBLE DE TAMAÑO
	for x in range(24):
		for y in range(24):
			var dist = Vector2(x, y).distance_to(center)
			if dist < 6:  # DOBLE DE TAMAÑO
				image.set_pixel(x, y, Color.YELLOW)
			elif dist < 8:  # DOBLE DE TAMAÑO
				image.set_pixel(x, y, Color.ORANGE)
			elif dist < 10:  # DOBLE DE TAMAÑO
				image.set_pixel(x, y, Color(1.0, 0.5, 0.0, 0.7))
	
	muzzle_flash_sprite = ImageTexture.create_from_image(image)
	print("✅ Muzzle flash creado DOBLE DE GRANDE (24x24)")

func can_shoot() -> bool:
	"""Verificar si el arma puede disparar"""
	if is_reloading or is_shooting:
		return false
	if current_ammo <= 0:
		# Auto-recarga cuando se queda sin munición
		start_reload()
		return false
	return true

func consume_ammo():
	"""Consumir munición"""
	current_ammo = max(0, current_ammo - 1)

func start_reload() -> bool:
	"""Iniciar recarga"""
	if is_reloading or current_ammo >= ammo_capacity:
		return false
	
	is_reloading = true
	
	# Iniciar timer de recarga
	if reload_timer and reload_timer.get_parent():
		reload_timer.wait_time = reload_time
		reload_timer.start()
	
	return true

func finish_reload():
	"""Terminar recarga"""
	current_ammo = ammo_capacity
	is_reloading = false

func start_shooting():
	"""Iniciar animación de disparo"""
	is_shooting = true

func stop_shooting():
	"""Terminar animación de disparo"""
	is_shooting = false

func get_weapon_world_position(player_position: Vector2, aim_direction: Vector2) -> Vector2:
	"""Obtener la posición del arma relativa al personaje - CENTRO DERECHA"""
	var rotated_offset = weapon_offset.rotated(aim_direction.angle())
	return player_position + rotated_offset

func get_weapon_rotation(aim_direction: Vector2) -> float:
	"""Obtener la rotación del arma"""
	return aim_direction.angle() + deg_to_rad(weapon_rotation_offset)
	
func get_weapon_world_position_lower(player_position: Vector2, aim_direction: Vector2) -> Vector2:
	"""Obtener la posición del arma MÁS ABAJO en el personaje"""
	# OFFSET MÁS BAJO EN EL PERSONAJE (centro-derecha pero más abajo)
	var lower_offset = Vector2(weapon_offset.x, weapon_offset.y + 20)  # +20 pixels más abajo
	var rotated_offset = lower_offset.rotated(aim_direction.angle())
	return player_position + rotated_offset

func get_muzzle_world_position_lower(player_position: Vector2, aim_direction: Vector2) -> Vector2:
	"""Obtener la posición del cañón desde la posición más alta"""
	var higher_offset = Vector2(weapon_offset.x, weapon_offset.y - 15)  # MÁS ARRIBA
	var weapon_position = player_position + higher_offset.rotated(aim_direction.angle())
	var rotated_muzzle = muzzle_offset.rotated(aim_direction.angle())
	return weapon_position + rotated_muzzle

func get_muzzle_world_position(player_position: Vector2, aim_direction: Vector2) -> Vector2:
	"""Obtener la posición del cañón (de donde salen las balas)"""
	var weapon_position = get_weapon_world_position(player_position, aim_direction)
	var rotated_muzzle = muzzle_offset.rotated(aim_direction.angle())
	return weapon_position + rotated_muzzle

func get_reload_progress() -> float:
	"""Obtener progreso de recarga (0.0 a 1.0)"""
	if not is_reloading or not reload_timer:
		return 1.0
	
	if reload_timer.time_left <= 0:
		return 1.0
	
	return 1.0 - (reload_timer.time_left / reload_time)

func get_ammo_percentage() -> float:
	"""Obtener porcentaje de munición restante"""
	if ammo_capacity <= 0:
		return 1.0
	
	return float(current_ammo) / float(ammo_capacity)

# Crear armas específicas predefinidas
static func create_pelao_pistol() -> WeaponStats:
	var weapon = WeaponStats.new()
	weapon.weapon_name = "Pistola de Pelao"
	weapon.damage = 25
	weapon.attack_speed = 3.0  # 3 balas por segundo
	weapon.attack_range = 500
	weapon.projectile_speed = 600
	weapon.ammo_capacity = 30
	weapon.reload_time = 2.0
	weapon.accuracy = 0.95
	weapon.headshot_multiplier = 1.4
	weapon.weapon_offset = Vector2(32, 0)  # Centro derecha
	weapon.muzzle_offset = Vector2(40, 0)  # DOBLE DE DISTANCIA para el muzzle
	weapon.shooting_animation_duration = 0.2
	weapon.recoil_distance = 3.0
	
	return weapon

static func create_juancar_rifle() -> WeaponStats:
	var weapon = WeaponStats.new()
	weapon.weapon_name = "Rifle de Juancar"
	weapon.damage = 35
	weapon.attack_speed = 2.0  # 2 balas por segundo (más lento que pistola)
	weapon.attack_range = 600
	weapon.projectile_speed = 800
	weapon.ammo_capacity = 25
	weapon.reload_time = 2.5
	weapon.accuracy = 0.98
	weapon.headshot_multiplier = 1.6
	weapon.weapon_offset = Vector2(35, 0)  # Centro derecha
	weapon.muzzle_offset = Vector2(48, 0)  # DOBLE DE DISTANCIA para el muzzle
	weapon.shooting_animation_duration = 0.15
	weapon.recoil_distance = 4.0
	
	return weapon

static func create_basic_pistol() -> WeaponStats:
	var weapon = WeaponStats.new()
	weapon.weapon_name = "Pistola Básica"
	weapon.damage = 20
	weapon.attack_speed = 3.0  # 3 balas por segundo
	weapon.attack_range = 400
	weapon.projectile_speed = 500
	weapon.ammo_capacity = 25
	weapon.reload_time = 1.8
	weapon.accuracy = 0.90
	weapon.headshot_multiplier = 1.3
	weapon.weapon_offset = Vector2(32, 0)  # Centro derecha
	weapon.muzzle_offset = Vector2(36, 0)  # DOBLE DE DISTANCIA para el muzzle
	weapon.shooting_animation_duration = 0.2
	weapon.recoil_distance = 2.5
	
	return weapon
