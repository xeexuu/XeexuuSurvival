# scenes/player/shooting_component.gd - SIN AUDIO AL DISPARAR + CORREGIDO
extends Node
class_name ShootingComponent

@export var bullet_scene: PackedScene

var equipped_weapon: WeaponStats
var can_shoot: bool = true
var shoot_timer: Timer
var is_stats_configured: bool = false

signal bullet_fired(bullet: Bullet, direction: Vector2)

func _ready():
	shoot_timer = Timer.new()
	shoot_timer.wait_time = 0.33
	shoot_timer.one_shot = true
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	add_child(shoot_timer)
	
	if not bullet_scene:
		bullet_scene = load("res://scenes/projectiles/Bullet.tscn")

func update_stats_from_player():
	"""CORREGIDO: Configurar cadencia fija SIN PROBLEMAS DE INICIALIZACIÓN"""
	if is_stats_configured:
		return false
	
	var player = get_parent() as Player
	if player and player.character_stats and player.character_stats.equipped_weapon:
		equipped_weapon = player.character_stats.equipped_weapon
		
		# ASEGURAR QUE EL ARMA TENGA UN TIMER DE RECARGA VÁLIDO
		if equipped_weapon.reload_timer and not equipped_weapon.reload_timer.get_parent():
			add_child(equipped_weapon.reload_timer)
		elif not equipped_weapon.reload_timer:
			# CREAR TIMER DE RECARGA SI NO EXISTE
			equipped_weapon.reload_timer = Timer.new()
			equipped_weapon.reload_timer.name = "ReloadTimer"
			equipped_weapon.reload_timer.one_shot = true
			equipped_weapon.reload_timer.timeout.connect(equipped_weapon._on_reload_finished)
			add_child(equipped_weapon.reload_timer)
		
		# CADENCIA FIJA RAZONABLE
		shoot_timer.wait_time = 0.25  # 4 balas por segundo
		
		is_stats_configured = true
		return true
	else:
		return false

func _on_shoot_timer_timeout():
	can_shoot = true

func try_shoot(direction: Vector2, start_position: Vector2) -> bool:
	if not can_shoot or direction == Vector2.ZERO:
		return false
	
	if not shoot_timer or not is_instance_valid(shoot_timer):
		return false
	
	if equipped_weapon and not equipped_weapon.can_shoot():
		return false
	
	if not is_stats_configured:
		update_stats_from_player()
	
	shoot(direction.normalized(), start_position)
	return true

func shoot(direction: Vector2, start_position: Vector2):
	if not bullet_scene:
		return
	
	if not shoot_timer or not is_instance_valid(shoot_timer):
		return
	
	# ❌ COMPLETAMENTE QUITADO: Sistema de audio al disparar
	# El audio ahora solo se reproduce al eliminar enemigos en ScoreSystem
	
	var bullets_to_create = 1
	if equipped_weapon:
		bullets_to_create = equipped_weapon.bullets_per_shot
	
	for i in range(bullets_to_create):
		create_bullet(direction, start_position, i, bullets_to_create)
	
	if equipped_weapon:
		equipped_weapon.consume_ammo()
	
	can_shoot = false
	
	# CADENCIA FIJA ESTABLE
	shoot_timer.wait_time = 0.25
	if shoot_timer and is_instance_valid(shoot_timer) and shoot_timer.is_inside_tree():
		shoot_timer.start()

func create_bullet(base_direction: Vector2, start_position: Vector2, bullet_index: int, total_bullets: int):
	var bullet = bullet_scene.instantiate() as Bullet
	if not bullet:
		return
	
	var final_direction = base_direction
	if equipped_weapon and total_bullets > 1:
		var spread = equipped_weapon.spread_angle
		var angle_offset = 0.0
		
		if total_bullets > 1:
			var spread_step = spread / float(total_bullets - 1)
			angle_offset = (float(bullet_index) * spread_step) - (spread * 0.5)
		
		var base_angle = base_direction.angle()
		var final_angle = base_angle + deg_to_rad(angle_offset)
		final_direction = Vector2.from_angle(final_angle)
	
	if equipped_weapon and equipped_weapon.accuracy < 1.0:
		var accuracy_spread = (1.0 - equipped_weapon.accuracy) * 30.0
		var random_offset = randf_range(-accuracy_spread, accuracy_spread)
		var base_angle = final_direction.angle()
		var final_angle = base_angle + deg_to_rad(random_offset)
		final_direction = Vector2.from_angle(final_angle)
	
	var final_speed = 600.0
	var final_damage = 1
	var final_range = 400.0
	
	if equipped_weapon:
		final_speed = float(equipped_weapon.projectile_speed)
		final_damage = equipped_weapon.damage
		final_range = float(equipped_weapon.attack_range)
		
		if final_range < 300:
			final_range = 400.0
	
	var main_scene = get_tree().current_scene
	if main_scene:
		main_scene.add_child(bullet)
	else:
		get_tree().root.add_child(bullet)
	
	bullet.global_position = start_position
	bullet.setup(final_direction, final_speed, final_range)
	bullet.damage = final_damage
	
	if equipped_weapon:
		bullet.has_piercing = equipped_weapon.has_piercing
		bullet.has_explosive = equipped_weapon.has_explosive
		bullet.knockback_force = equipped_weapon.knockback_force
		bullet.headshot_multiplier = equipped_weapon.headshot_multiplier
	
	bullet_fired.emit(bullet, final_direction)

func start_manual_reload():
	if equipped_weapon:
		return equipped_weapon.start_reload()
	return false

func get_ammo_info() -> Dictionary:
	if not equipped_weapon:
		return {"current": 0, "max": 0, "reloading": false, "reload_progress": 0.0}
	
	return {
		"current": equipped_weapon.current_ammo,
		"max": equipped_weapon.ammo_capacity,
		"reloading": equipped_weapon.is_reloading,
		"reload_progress": equipped_weapon.get_reload_progress()
	}
