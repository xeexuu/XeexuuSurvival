# scenes/weapons/WeaponRenderer.gd - ARMA EN CENTRO DERECHA Y BALAS DESDE ARMA
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
	
	# ASEGURAR QUE EL SPRITE DE LA PISTOLA ESTÉ CARGADO
	weapon_stats.ensure_sprites_exist()
	
	# Configurar sprite principal
	if weapon_stats.weapon_sprite:
		weapon_sprite.texture = weapon_stats.weapon_sprite
		print("🔫 Sprite del arma configurado: ", weapon_stats.weapon_name)
	else:
		print("❌ No se pudo cargar sprite del arma: ", weapon_stats.weapon_name)
		weapon_stats.create_default_weapon_sprite()
		weapon_sprite.texture = weapon_stats.weapon_sprite
	
	# Configurar flash del cañón
	if not weapon_stats.muzzle_flash_sprite:
		weapon_stats.create_muzzle_flash_sprite()
	
	muzzle_flash_sprite.texture = weapon_stats.muzzle_flash_sprite
	
	# POSICIONAR FLASH DEL CAÑÓN RELATIVO AL ARMA (DESDE DONDE SALEN LAS BALAS)
	muzzle_flash_sprite.position = weapon_stats.muzzle_offset
	
	print("🔫 Sprites del arma actualizados: ", weapon_stats.weapon_name)
	print("🎯 Offset del arma: ", weapon_stats.weapon_offset)
	print("🎯 Offset del cañón: ", weapon_stats.muzzle_offset)

func update_weapon_position_and_rotation(aim_direction: Vector2):
	"""Actualizar posición y rotación del arma - CENTRO DERECHA DEL JUGADOR"""
	if not weapon_stats or not player_ref:
		return
	
	current_aim_direction = aim_direction.normalized()
	
	# CALCULAR POSICIÓN DEL ARMA EN EL CENTRO DERECHA DEL JUGADOR
	var weapon_world_pos = weapon_stats.get_weapon_world_position(player_ref.global_position, current_aim_direction)
	global_position = weapon_world_pos
	
	# CALCULAR ROTACIÓN DEL ARMA HACIA LA DIRECCIÓN DE APUNTADO
	var weapon_rotation = weapon_stats.get_weapon_rotation(current_aim_direction)
	rotation = weapon_rotation
	
	# VOLTEAR EL ARMA SI APUNTA HACIA LA IZQUIERDA
	if current_aim_direction.x < 0:
		weapon_sprite.flip_v = true
		muzzle_flash_sprite.flip_v = true
		# AJUSTAR POSICIÓN DEL FLASH CUANDO ESTÁ VOLTEADO
		muzzle_flash_sprite.position = Vector2(weapon_stats.muzzle_offset.x, -weapon_stats.muzzle_offset.y)
	else:
		weapon_sprite.flip_v = false
		muzzle_flash_sprite.flip_v = false
		muzzle_flash_sprite.position = weapon_stats.muzzle_offset
	
	# DEBUG: Mostrar información de posicionamiento
	# print("🎯 Arma - Pos: ", global_position, " | Rot: ", rad_to_deg(rotation), "°")

func start_shooting_animation():
	"""Iniciar animación de disparo"""
	if not weapon_stats or is_shooting:
		return
	
	is_shooting = true
	weapon_stats.start_shooting()
	
	# MOSTRAR FLASH DEL CAÑÓN
	muzzle_flash_sprite.visible = true
	
	# EFECTO DE RETROCESO
	if weapon_stats.recoil_distance > 0:
		animate_recoil()
	
	# CONFIGURAR TIMER PARA DURACIÓN DEL DISPARO
	shooting_timer.wait_time = weapon_stats.shooting_animation_duration
	shooting_timer.start()
	
	# OCULTAR FLASH DESPUÉS DE UN CORTO TIEMPO
	var flash_timer = Timer.new()
	flash_timer.wait_time = 0.05  # Flash muy rápido
	flash_timer.one_shot = true
	flash_timer.timeout.connect(func(): 
		muzzle_flash_sprite.visible = false
		flash_timer.queue_free()
	)
	add_child(flash_timer)
	flash_timer.start()
	
	print("💥 Animación de disparo iniciada - Arma: ", weapon_stats.weapon_name)

func animate_recoil():
	"""Animar el retroceso del arma"""
	if recoil_tween:
		recoil_tween.kill()
	
	recoil_tween = create_tween()
	
	# CALCULAR DIRECCIÓN OPUESTA AL DISPARO PARA EL RETROCESO
	var recoil_direction = -current_aim_direction.normalized()
	var recoil_offset = recoil_direction * weapon_stats.recoil_distance
	
	# ANIMAR RETROCESO Y VUELTA A LA POSICIÓN ORIGINAL
	recoil_tween.tween_property(weapon_sprite, "position", recoil_offset, 0.05)
	recoil_tween.tween_property(weapon_sprite, "position", Vector2.ZERO, 0.15)

func _on_shooting_finished():
	"""Cuando termina la animación de disparo"""
	is_shooting = false
	if weapon_stats:
		weapon_stats.stop_shooting()

func get_muzzle_world_position() -> Vector2:
	"""Obtener la posición mundial del cañón - DESDE DONDE SALEN LAS BALAS"""
	if not weapon_stats or not player_ref:
		return global_position
	
	# USAR LA FUNCIÓN DEL ARMA PARA OBTENER LA POSICIÓN EXACTA DEL CAÑÓN
	var muzzle_world_pos = weapon_stats.get_muzzle_world_position(player_ref.global_position, current_aim_direction)
	
	print("🎯 Posición del cañón (mundo): ", muzzle_world_pos)
	return muzzle_world_pos

func can_shoot() -> bool:
	"""Verificar si el arma puede disparar"""
	return weapon_stats and weapon_stats.can_shoot() and not is_shooting

# Función de debug
func debug_weapon_info():
	"""Mostrar información de debug del arma"""
	if weapon_stats:
		print("=== DEBUG ARMA ===")
		print("Nombre: ", weapon_stats.weapon_name)
		print("Posición del arma: ", global_position)
		print("Rotación: ", rad_to_deg(rotation), "°")
		print("Dirección de apuntado: ", current_aim_direction)
		print("Disparando: ", is_shooting)
		print("Posición del cañón: ", get_muzzle_world_position())
		print("Offset del arma: ", weapon_stats.weapon_offset)
		print("Offset del cañón: ", weapon_stats.muzzle_offset)
		print("==================")

func _input(event):
	"""Debug con tecla F1"""
	if event.is_action_pressed("ui_accept") and Input.is_key_pressed(KEY_F1):
		debug_weapon_info()
