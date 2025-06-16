# scenes/projectiles/bullet.gd - COLISIONES Y PUNTUACIÓN CORREGIDAS
extends Area2D
class_name Bullet

@export var damage: int = 1
@export var max_range: float = 300.0
@export var lifetime: float = 5.0

# Propiedades de armas estilo COD Black Ops
var has_piercing: bool = false
var has_explosive: bool = false
var knockback_force: float = 0.0
var headshot_multiplier: float = 1.4
var targets_hit: Array[Node2D] = []
var pierce_count: int = 0
var max_pierce: int = 3

var direction: Vector2
var speed: float
var start_position: Vector2
var distance_traveled: float = 0.0
var lifetime_timer: Timer
var is_being_destroyed: bool = false

# REFERENCIA AL SCORE SYSTEM PARA PUNTUACIÓN BO1
var score_system: ScoreSystem

@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D

func _ready():
	# CONFIGURAR CAPAS DE COLISIÓN CORRECTAMENTE
	collision_layer = 4  # Capa de proyectiles
	collision_mask = 2   # SOLO DETECTAR ENEMIGOS (capa 2)
	
	add_to_group("bullets")
	
	lifetime_timer = Timer.new()
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_timeout)
	add_child(lifetime_timer)
	
	# CREAR SPRITE SIEMPRE VISIBLE
	setup_sprite()
	
	# CONECTAR SEÑALES CORRECTAMENTE
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	lifetime_timer.start()
	
	# OBTENER SCORE SYSTEM
	get_score_system_reference()

func get_score_system_reference():
	"""Obtener referencia al sistema de puntuación"""
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		game_manager = get_node_or_null("/root/Main/GameManager")
	
	if game_manager and game_manager.has_method("get_current_score"):
		score_system = game_manager.score_system

func setup_sprite():
	"""CONFIGURAR SPRITE VISIBLE DE LA BALA"""
	if not sprite:
		return
		
	# CREAR TEXTURA SIEMPRE VISIBLE
	var image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var base_color = Color.YELLOW
	if has_piercing:
		base_color = Color.CYAN
	elif has_explosive:
		base_color = Color.ORANGE
	
	# Crear bala visible estilo COD
	for x in range(8):
		for y in range(8):
			var dist = Vector2(x - 4, y - 4).length()
			if dist <= 2:
				image.set_pixel(x, y, base_color)
			elif dist <= 3:
				image.set_pixel(x, y, base_color.darkened(0.2))
			elif dist <= 4:
				image.set_pixel(x, y, base_color.darkened(0.5))
	
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.visible = true
	sprite.z_index = 50  # Asegurar que esté visible encima de otros elementos

func setup(new_direction: Vector2, new_speed: float, weapon_range: float = 300.0):
	"""Configurar la bala"""
	direction = new_direction.normalized()
	speed = new_speed
	max_range = weapon_range
	start_position = global_position
	distance_traveled = 0.0
	rotation = direction.angle()

func _physics_process(delta):
	if is_being_destroyed:
		return
	
	var movement = direction * speed * delta
	global_position += movement
	distance_traveled += movement.length()
	
	var current_distance = start_position.distance_to(global_position)
	
	if current_distance >= max_range:
		destroy_bullet("range")
		return

func _on_lifetime_timeout():
	if not is_being_destroyed:
		destroy_bullet("lifetime")

func _on_area_entered(area: Area2D):
	"""DETECTAR ÁREA DE ENEMIGO (para headshots)"""
	if area == self or is_being_destroyed:
		return
	
	# Verificar si es área de headshot
	var enemy_parent = area.get_parent()
	if not enemy_parent or not (enemy_parent is Enemy):
		return
	
	print("🎯 Bala impactó área de enemigo: ", area.name)
	
	if area.name == "HeadArea":
		handle_headshot_hit(enemy_parent)
	else:
		handle_hit(enemy_parent)

func _on_body_entered(body: Node2D):
	"""DETECTAR CUERPO DE ENEMIGO"""
	if is_being_destroyed:
		return
	
	print("💥 Bala impactó cuerpo: ", body.name, " - Tipo: ", type_string(typeof(body)))
	
	# SOLO PROCESAR ENEMIGOS
	if body is Player:
		print("❌ Ignorando jugador")
		return
		
	if body is Enemy:
		print("✅ Procesando impacto en enemigo")
		handle_hit(body)
	else:
		print("❓ Cuerpo no reconocido como enemigo")

func handle_headshot_hit(enemy: Node2D):
	"""Manejar impacto headshot estilo COD Black Ops 1"""
	if is_being_destroyed or not (enemy is Enemy):
		return
	
	if has_piercing and enemy in targets_hit:
		return
	
	var enemy_ref = enemy as Enemy
	var enemy_initial_health = enemy_ref.current_health
	
	print("🎯 HEADSHOT en enemigo con ", enemy_initial_health, " de vida")
	
	# CALCULAR DAÑO DE HEADSHOT
	var headshot_damage = int(float(damage) * headshot_multiplier)
	apply_damage_to_target(enemy, headshot_damage, true)
	apply_knockback_to_target(enemy)
	
	# SISTEMA DE PUNTUACIÓN BLACK OPS 1
	if score_system:
		if enemy_ref.current_health <= 0:
			score_system.add_kill_points(global_position, true, false)
		else:
			score_system.add_damage_points(global_position, headshot_damage, true)
	
	# Crear efecto de headshot
	create_hit_effect(global_position, true)
	
	handle_piercing_logic(enemy)

func handle_hit(target: Node2D):
	"""Manejar impacto normal estilo Black Ops 1"""
	if is_being_destroyed or not (target is Enemy):
		return
	
	if has_piercing and target in targets_hit:
		return
	
	var enemy_ref = target as Enemy
	var enemy_initial_health = enemy_ref.current_health
	
	print("💥 IMPACTO NORMAL en enemigo con ", enemy_initial_health, " de vida")
	
	apply_damage_to_target(target, damage, false)
	apply_knockback_to_target(target)
	
	# SISTEMA DE PUNTUACIÓN BLACK OPS 1
	if score_system:
		if enemy_ref.current_health <= 0:
			score_system.add_kill_points(global_position, false, false)
		else:
			score_system.add_damage_points(global_position, damage, false)
	
	# Crear efecto de impacto
	create_hit_effect(global_position, false)
	
	handle_piercing_logic(target)

func handle_piercing_logic(target: Node2D):
	"""Manejar lógica de perforación"""
	if has_piercing and pierce_count < max_pierce:
		targets_hit.append(target)
		pierce_count += 1
		
		if pierce_count >= max_pierce:
			destroy_bullet("piercing_limit")
	else:
		destroy_bullet("impact")

func create_hit_effect(position: Vector2, is_headshot: bool):
	"""Crear efecto visual de impacto"""
	var effect_scene = get_tree().current_scene
	if not effect_scene:
		return
	
	# Crear partículas simples de impacto
	for i in range(3 if not is_headshot else 6):
		var particle = Sprite2D.new()
		var particle_image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		
		if is_headshot:
			particle_image.fill(Color.YELLOW)
		else:
			particle_image.fill(Color.RED)
		
		particle.texture = ImageTexture.create_from_image(particle_image)
		particle.global_position = position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		effect_scene.add_child(particle)
		
		# Animar partícula
		var tween = effect_scene.create_tween()
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.parallel().tween_property(particle, "global_position", particle.global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20)), 0.5)
		tween.tween_callback(func(): particle.queue_free())

func apply_damage_to_target(target: Node2D, damage_amount: int, is_headshot: bool = false):
	"""Aplicar daño al objetivo"""
	if not target or not target.has_method("take_damage"):
		print("❌ Target no tiene método take_damage")
		return
	
	print("⚔️ Aplicando ", damage_amount, " de daño (headshot: ", is_headshot, ")")
	target.take_damage(damage_amount, is_headshot)

func apply_knockback_to_target(target: Node2D):
	"""Aplicar knockback al objetivo"""
	if knockback_force <= 0:
		return
	
	if target is CharacterBody2D:
		if target.has_method("apply_knockback"):
			var knockback_direction = direction.normalized()
			target.apply_knockback(knockback_direction, knockback_force)

func destroy_bullet(reason: String):
	"""Destruir bala de forma segura"""
	if is_being_destroyed:
		return
	
	print("💨 Destruyendo bala por: ", reason)
	is_being_destroyed = true
	
	set_physics_process(false)
	set_process(false)
	
	if collision and is_instance_valid(collision):
		collision.set_deferred("disabled", true)
	
	if sprite and is_instance_valid(sprite):
		sprite.visible = false
	
	if lifetime_timer and is_instance_valid(lifetime_timer):
		lifetime_timer.stop()
	
	call_deferred("queue_free")
