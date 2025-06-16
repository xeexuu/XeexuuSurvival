# scenes/weapons/WeaponStats.gd
extends Resource
class_name WeaponStats

@export var weapon_name: String = "Pistola"
@export var weapon_type: String = "ranged"
@export var damage: int = 25
@export var attack_speed: float = 0.3  # 0.3 balas por segundo (cada 3.33 segundos)
@export var attack_range: int = 300
@export var projectile_speed: int = 600
@export var ammo_capacity: int = 30  # Capacidad del cargador
@export var reload_time: float = 2.0  # Tiempo de recarga en segundos
@export var accuracy: float = 1.0
@export var spread_angle: float = 0.0
@export var bullets_per_shot: int = 1

# MULTIPLICADOR DE DAÑO POR HEADSHOT
@export var headshot_multiplier: float = 1.4  # Para pistola

# SPRITES Y ANIMACIONES DEL ARMA
@export var weapon_sprite: Texture2D
@export var weapon_shooting_sprite: Texture2D
@export var muzzle_flash_sprite: Texture2D
@export var attack_sound: AudioStream

# POSICIONAMIENTO DEL ARMA EN LAS MANOS - CENTRO DERECHA DEL JUGADOR
@export var weapon_offset: Vector2 = Vector2(32, 0)  # A la derecha del centro del jugador
@export var weapon_rotation_offset: float = 0.0
@export var muzzle_offset: Vector2 = Vector2(20, 0)  # Desde donde salen las balas

# Efectos especiales
@export var has_piercing: bool = false
@export var has_explosive: bool = false
@export var knockback_force: float = 0.0

# ANIMACIÓN DE DISPARO
@export var shooting_animation_duration: float = 0.2  # Duración de la animación de disparo
@export var recoil_distance: float = 2.0

# Estados del arma (no exportados)
var current_ammo: int
var is_reloading: bool = false
var is_shooting: bool = false
var reload_timer: Timer

func _init():
	current_ammo = ammo_capacity
	
	# CONFIGURAR CADENCIA CORRECTA COD WORLD AT WAR
	# M1911 en COD WaW: 1200 RPM = 20 balas por segundo
	attack_speed = 20.0  # CORREGIDO: era 0.3, ahora 20 balas/segundo como COD WaW
	
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
	var image = Image.create(24, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# Crear sprite básico de pistola horizontal
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
	
	weapon_sprite = ImageTexture.create_from_image(image)

func create_muzzle_flash_sprite():
	"""Crear sprite de flash del cañón si no existe"""
	if muzzle_flash_sprite:
		return
	
	var image = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# Crear flash circular
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
	
	muzzle_flash_sprite = ImageTexture.create_from_image(image)

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
	weapon.attack_speed = 0.3  # 0.3 balas por segundo
	weapon.attack_range = 500
	weapon.projectile_speed = 600
	weapon.ammo_capacity = 30
	weapon.reload_time = 2.0
	weapon.accuracy = 0.95
	weapon.headshot_multiplier = 1.4
	weapon.weapon_offset = Vector2(32, 0)  # Centro derecha
	weapon.muzzle_offset = Vector2(20, 0)
	weapon.shooting_animation_duration = 0.2
	weapon.recoil_distance = 3.0
	
	return weapon

static func create_juancar_rifle() -> WeaponStats:
	var weapon = WeaponStats.new()
	weapon.weapon_name = "Rifle de Juancar"
	weapon.damage = 35
	weapon.attack_speed = 0.5  # Más lento que la pistola
	weapon.attack_range = 600
	weapon.projectile_speed = 800
	weapon.ammo_capacity = 25
	weapon.reload_time = 2.5
	weapon.accuracy = 0.98
	weapon.headshot_multiplier = 1.6
	weapon.weapon_offset = Vector2(35, 0)  # Centro derecha
	weapon.muzzle_offset = Vector2(24, 0)
	weapon.shooting_animation_duration = 0.15
	weapon.recoil_distance = 4.0
	
	return weapon

static func create_basic_pistol() -> WeaponStats:
	var weapon = WeaponStats.new()
	weapon.weapon_name = "Pistola Básica"
	weapon.damage = 20
	weapon.attack_speed = 0.3  # 0.3 balas por segundo
	weapon.attack_range = 400
	weapon.projectile_speed = 500
	weapon.ammo_capacity = 25
	weapon.reload_time = 1.8
	weapon.accuracy = 0.90
	weapon.headshot_multiplier = 1.3
	weapon.weapon_offset = Vector2(32, 0)  # Centro derecha
	weapon.muzzle_offset = Vector2(18, 0)
	weapon.shooting_animation_duration = 0.2
	weapon.recoil_distance = 2.5
	
	return weapon
