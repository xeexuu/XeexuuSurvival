# scenes/weapons/WeaponRenderer.gd - POSICIÓN CORREGIDA PARA TODAS LAS DIRECCIONES
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
	setup_shooting_timer()

func setup_shooting_timer():
	"""Configurar timer para la animación de disparo"""
	shooting_timer = Timer.new()
	shooting_timer.name = "ShootingTimer"
	shooting_timer.one_shot = true
	shooting_timer.timeout.connect(_on_shooting_finished)
	add_child(shooting_timer)

func setup_weapon_sprites():
	"""Configurar los sprites del arma SOLO cuando el arma esté asignada"""
	if not weapon_stats:
		return
	
	# Sprite principal del arma
	weapon_sprite = Sprite2D.new()
	weapon_sprite.name = "WeaponSprite"
	weapon_sprite.visible = false
	add_child(weapon_sprite)
	
	# Sprite del flash del cañón
	muzzle_flash_sprite = Sprite2D.new()
	muzzle_flash_sprite.name = "MuzzleFlash"
	muzzle_flash_sprite.visible = false
	add_child(muzzle_flash_sprite)

func set_weapon_stats(stats: WeaponStats):
	"""Asignar estadísticas del arma"""
	weapon_stats = stats
	if weapon_stats:
		setup_weapon_sprites()
		update_weapon_sprites()

func set_player_reference(player: Node2D):
	"""Asignar referencia al jugador"""
	player_ref = player

func update_weapon_sprites():
	"""Actualizar los sprites basándose en las estadísticas del arma"""
	if not weapon_stats or not weapon_sprite:
		return
	
	weapon_stats.ensure_sprites_exist()
	
	# Configurar sprite principal
	if weapon_stats.weapon_sprite:
		weapon_sprite.texture = weapon_stats.weapon_sprite
		weapon_sprite.visible = true
	else:
		weapon_stats.create_default_weapon_sprite()
		weapon_sprite.texture = weapon_stats.weapon_sprite
		weapon_sprite.visible = true
	
	# Configurar flash del cañón
	if not weapon_stats.muzzle_flash_sprite:
		weapon_stats.create_muzzle_flash_sprite()
	
	if muzzle_flash_sprite:
		muzzle_flash_sprite.texture = weapon_stats.muzzle_flash_sprite
		muzzle_flash_sprite.position = weapon_stats.muzzle_offset

func update_weapon_position_and_rotation(aim_direction: Vector2):
	"""Actualizar posición y rotación del arma - CORREGIDO PARA TODAS LAS DIRECCIONES"""
	if not weapon_stats or not player_ref or not weapon_sprite:
		return
	
	if not weapon_sprite.visible:
		return
	
	current_aim_direction = aim_direction.normalized()
	
	# POSICIÓN CONSISTENTE DEL ARMA SEGÚN DIRECCIÓN
	var weapon_world_pos = get_consistent_weapon_position(current_aim_direction)
	global_position = weapon_world_pos
	
	# ROTACIÓN DEL ARMA
	var weapon_rotation = current_aim_direction.angle()
	rotation = weapon_rotation
	
	# VOLTEAR ARMA SEGÚN DIRECCIÓN
	if current_aim_direction.x < 0:
		weapon_sprite.flip_v = true
		if muzzle_flash_sprite:
			muzzle_flash_sprite.flip_v = true
			muzzle_flash_sprite.position = Vector2(weapon_stats.muzzle_offset.x, -weapon_stats.muzzle_offset.y)
	else:
		weapon_sprite.flip_v = false
		if muzzle_flash_sprite:
			muzzle_flash_sprite.flip_v = false
			muzzle_flash_sprite.position = weapon_stats.muzzle_offset

func get_consistent_weapon_position(aim_direction: Vector2) -> Vector2:
	"""Obtener posición consistente del arma para todas las direcciones"""
	if not player_ref:
		return global_position
	
	# OFFSET BASE DESDE EL CENTRO DEL JUGADOR
	var base_offset = Vector2(30, -5)  # Ligeramente hacia adelante y arriba
	
	# ROTAR EL OFFSET SEGÚN LA DIRECCIÓN DE AIM
	var rotated_offset = base_offset.rotated(aim_direction.angle())
	
	# AJUSTES ESPECÍFICOS POR CUADRANTE PARA MEJOR APARIENCIA
	var angle = aim_direction.angle()
	var angle_degrees = rad_to_deg(angle)
	
	# Normalizar ángulo a 0-360
	if angle_degrees < 0:
		angle_degrees += 360
	
	# AJUSTES FINOS POR DIRECCIÓN
	var fine_adjustment = Vector2.ZERO
	
	if angle_degrees >= 315 or angle_degrees < 45:  # Derecha (0°)
		fine_adjustment = Vector2(5, -2)
	elif angle_degrees >= 45 and angle_degrees < 135:  # Abajo (90°)
		fine_adjustment = Vector2(2, 8)
	elif angle_degrees >= 135 and angle_degrees < 225:  # Izquierda (180°)
		fine_adjustment = Vector2(-5, -2)
	elif angle_degrees >= 225 and angle_degrees < 315:  # Arriba (270°)
		fine_adjustment = Vector2(2, -12)
	
	return player_ref.global_position + rotated_offset + fine_adjustment

func start_shooting_animation():
	"""Iniciar animación de disparo"""
	if not weapon_stats or is_shooting or not weapon_sprite or not weapon_sprite.visible:
		return
	
	is_shooting = true
	weapon_stats.start_shooting()
	
	# MOSTRAR FLASH DEL CAÑÓN
	if muzzle_flash_sprite:
		muzzle_flash_sprite.visible = true
	
	# EFECTO DE RETROCESO
	if weapon_stats.recoil_distance > 0:
		animate_recoil()
	
	# CONFIGURAR TIMER PARA DURACIÓN DEL DISPARO
	shooting_timer.wait_time = weapon_stats.shooting_animation_duration
	shooting_timer.start()
	
	# OCULTAR FLASH DESPUÉS DE UN CORTO TIEMPO
	var flash_timer = Timer.new()
	flash_timer.wait_time = 0.05
	flash_timer.one_shot = true
	flash_timer.timeout.connect(func(): 
		if muzzle_flash_sprite:
			muzzle_flash_sprite.visible = false
		flash_timer.queue_free()
	)
	add_child(flash_timer)
	flash_timer.start()

func animate_recoil():
	"""Animar el retroceso del arma"""
	if not weapon_sprite:
		return
		
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
	"""Obtener la posición mundial del cañón CORREGIDA"""
	if not weapon_stats or not player_ref:
		return global_position
	
	# USAR POSICIÓN CONSISTENTE DEL ARMA
	var weapon_world_pos = get_consistent_weapon_position(current_aim_direction)
	
	# CALCULAR POSICIÓN DEL MUZZLE DESDE LA POSICIÓN DEL ARMA
	var muzzle_offset = weapon_stats.muzzle_offset
	
	# AJUSTAR OFFSET SI EL ARMA ESTÁ VOLTEADA
	if current_aim_direction.x < 0:
		muzzle_offset = Vector2(muzzle_offset.x, -muzzle_offset.y)
	
	# ROTAR EL OFFSET DEL MUZZLE SEGÚN LA ROTACIÓN DEL ARMA
	var rotated_muzzle_offset = muzzle_offset.rotated(current_aim_direction.angle())
	
	return weapon_world_pos + rotated_muzzle_offset

func can_shoot() -> bool:
	"""Verificar si el arma puede disparar"""
	return weapon_stats and weapon_stats.can_shoot() and not is_shooting and weapon_sprite and weapon_sprite.visible

func hide_weapon():
	"""Ocultar completamente el arma"""
	if weapon_sprite:
		weapon_sprite.visible = false
	if muzzle_flash_sprite:
		muzzle_flash_sprite.visible = false

func show_weapon():
	"""Mostrar el arma si tiene stats asignados"""
	if weapon_stats and weapon_sprite:
		weapon_sprite.visible = true

func _exit_tree():
	"""Limpiar al salir"""
	if recoil_tween:
		recoil_tween.kill()
	
	if shooting_timer:
		shooting_timer.stop()
