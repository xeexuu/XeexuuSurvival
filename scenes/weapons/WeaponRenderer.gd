# scenes/weapons/WeaponRenderer.gd
extends Node2D
class_name WeaponRenderer

var weapon_stats: WeaponStats
var player_ref: Node2D
var weapon_sprite: Sprite2D
var muzzle_flash_sprite: Sprite2D
var shooting_timer: Timer
var recoil_tween: Tween

# Estado de la animación
var is_shooting: bool = false
var original_position: Vector2
var current_aim_direction: Vector2 = Vector2(1, 0)

func _ready():
	setup_weapon_sprites()
	setup_shooting_timer()

func setup_weapon_sprites():
	"""Configurar los sprites del arma"""
	# Sprite principal del arma
	weapon_sprite = Sprite2D.new()
	weapon_sprite.name = "WeaponSprite"
	add_child(weapon_sprite)
	
	# Sprite del flash del cañón
	muzzle_flash_sprite = Sprite2D.new()
	muzzle_flash_sprite.name = "MuzzleFlash"
	muzzle_flash_sprite.visible = false
	add_child(muzzle_flash_sprite)

func setup_shooting_timer():
	"""Configurar timer para la animación de disparo"""
	shooting_timer = Timer.new()
	shooting_timer.name = "ShootingTimer"
	shooting_timer.one_shot = true
	shooting_timer.timeout.connect(_on_shooting_finished)
	add_child(shooting_timer)

func set_weapon_stats(stats: WeaponStats):
	"""Asignar estadísticas del arma"""
	weapon_stats = stats
	if weapon_stats:
		update_weapon_sprites()

func set_player_reference(player: Node2D):
	"""Asignar referencia al jugador"""
	player_ref = player

func update_weapon_sprites():
	"""Actualizar los sprites basándose en las estadísticas del arma"""
	if not weapon_stats:
		return
	
	# Configurar sprite principal
	if weapon_stats.weapon_sprite:
		weapon_sprite.texture = weapon_stats.weapon_sprite
	else:
		weapon_stats.ensure_sprites_exist()
		weapon_sprite.texture = weapon_stats.weapon_sprite
	
	# Configurar flash del cañón
	if weapon_stats.muzzle_flash_sprite:
		muzzle_flash_sprite.texture = weapon_stats.muzzle_flash_sprite
	else:
		weapon_stats.create_muzzle_flash_sprite()
		muzzle_flash_sprite.texture = weapon_stats.muzzle_flash_sprite
	
	# Posicionar flash del cañón relativo al arma
	muzzle_flash_sprite.position = weapon_stats.muzzle_offset
	
	print("🔫 Sprites del arma actualizados: ", weapon_stats.weapon_name)

func update_weapon_position_and_rotation(aim_direction: Vector2):
	"""Actualizar posición y rotación del arma"""
	if not weapon_stats or not player_ref:
		return
	
	current_aim_direction = aim_direction.normalized()
	
	# Calcular posición del arma
	var weapon_world_pos = weapon_stats.get_weapon_world_position(player_ref.global_position, current_aim_direction)
	global_position = weapon_world_pos
	
	# Calcular rotación del arma
	var weapon_rotation = weapon_stats.get_weapon_rotation(current_aim_direction)
	rotation = weapon_rotation
	
	# Voltear el arma si apunta hacia la izquierda
	if current_aim_direction.x < 0:
		weapon_sprite.flip_v = true
		muzzle_flash_sprite.flip_v = true
		# Ajustar posición del flash cuando está volteado
		muzzle_flash_sprite.position = Vector2(weapon_stats.muzzle_offset.x, -weapon_stats.muzzle_offset.y)
	else:
		weapon_sprite.flip_v = false
		muzzle_flash_sprite.flip_v = false
		muzzle_flash_sprite.position = weapon_stats.muzzle_offset

func start_shooting_animation():
	"""Iniciar animación de disparo"""
	if not weapon_stats or is_shooting:
		return
	
	is_shooting = true
	weapon_stats.start_shooting()
	
	# Mostrar flash del cañón
	muzzle_flash_sprite.visible = true
	
	# Efecto de retroceso
	if weapon_stats.recoil_distance > 0:
		animate_recoil()
	
	# Configurar timer para duración del disparo
	shooting_timer.wait_time = weapon_stats.shooting_animation_duration
	shooting_timer.start()
	
	# Ocultar flash después de un corto tiempo
	var flash_timer = Timer.new()
	flash_timer.wait_time = 0.05  # Flash muy rápido
	flash_timer.one_shot = true
	flash_timer.timeout.connect(func(): 
		muzzle_flash_sprite.visible = false
		flash_timer.queue_free()
	)
	add_child(flash_timer)
	flash_timer.start()

func animate_recoil():
	"""Animar el retroceso del arma"""
	if recoil_tween:
		recoil_tween.kill()
	
	recoil_tween = create_tween()
	
	# Calcular dirección opuesta al disparo para el retroceso
	var recoil_direction = -current_aim_direction.normalized()
	var recoil_offset = recoil_direction * weapon_stats.recoil_distance
	
	# Animar retroceso y vuelta a la posición original
	recoil_tween.tween_property(weapon_sprite, "position", recoil_offset, 0.05)
	recoil_tween.tween_property(weapon_sprite, "position", Vector2.ZERO, 0.15)

func _on_shooting_finished():
	"""Cuando termina la animación de disparo"""
	is_shooting = false
	if weapon_stats:
		weapon_stats.stop_shooting()

func get_muzzle_world_position() -> Vector2:
	"""Obtener la posición mundial del cañón"""
	if not weapon_stats or not player_ref:
		return global_position
	
	return weapon_stats.get_muzzle_world_position(player_ref.global_position, current_aim_direction)

func can_shoot() -> bool:
	"""Verificar si el arma puede disparar"""
	return weapon_stats and weapon_stats.can_shoot() and not is_shooting

# Función de debug
func debug_weapon_info():
	"""Mostrar información de debug del arma"""
	if weapon_stats:
		print("=== DEBUG ARMA ===")
		print("Nombre: ", weapon_stats.weapon_name)
		print("Posición: ", global_position)
		print("Rotación: ", rad_to_deg(rotation))
		print("Dirección: ", current_aim_direction)
		print("Disparando: ", is_shooting)
		print("Posición cañón: ", get_muzzle_world_position())
		print("==================")

func _input(event):
	"""Debug con tecla F1"""
	if event.is_action_pressed("ui_accept") and Input.is_key_pressed(KEY_F1):
		debug_weapon_info()
