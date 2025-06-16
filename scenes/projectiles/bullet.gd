# scenes/projectiles/bullet.gd - BALAS CORREGIDAS CON SISTEMA DE PUNTUACIÓN BO1
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
	collision_layer = 4
	collision_mask = 2  # SOLO ENEMIGOS - NO JUGADOR
	
	add_to_group("bullets")
	
	lifetime_timer = Timer.new()
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_timeout)
	add_child(lifetime_timer)
	
	# CREAR SPRITE SIEMPRE - NO DEJAR INVISIBLE
	setup_sprite()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	lifetime_timer.start()
	
	# OBTENER REFERENCIA AL SCORE SYSTEM
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		game_manager = get_node_or_null("/root/Main/GameManager")
	
	if game_manager and game_manager.has_method("get") and game_manager.get("score_system"):
		score_system = game_manager.score_system

func setup_sprite():
	"""Configurar sprite de la bala estilo COD Black Ops - SIEMPRE VISIBLE"""
	if not sprite:
		return
		
	# CREAR TEXTURA SIEMPRE, NO DEPENDER DE SPRITE EXISTENTE
	var image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var base_color = Color.YELLOW
	if has_piercing:
		base_color = Color.CYAN
	elif has_explosive:
		base_color = Color.ORANGE
	
	# Crear bala más visible estilo COD
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
	sprite.visible = true  # FORZAR VISIBILIDAD

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
	if area != self and not is_being_destroyed:
		# VERIFICAR QUE SEA ÁREA DE ENEMIGO VÁLIDA
		var enemy_parent = area.get_parent()
		if not enemy_parent or not (enemy_parent is Enemy):
			return
			
		if area.name == "HeadArea":
			handle_headshot_hit(enemy_parent)
		else:
			handle_hit(enemy_parent)

func _on_body_entered(body: Node2D):
	if is_being_destroyed:
		return
	
	# SOLO PROCESAR ENEMIGOS - NO JUGADOR
	if body is Player:
		return
		
	if body is Enemy:
		handle_hit(body)

func handle_headshot_hit(enemy: Node2D):
	"""Manejar impacto headshot estilo COD Black Ops 1"""
	if is_being_destroyed or not (enemy is Enemy):
		return
	
	if has_piercing and enemy in targets_hit:
		return
	
	var enemy_ref = enemy as Enemy
	var enemy_initial_health = enemy_ref.current_health
	
	# CALCULAR DAÑO DE HEADSHOT CORRECTAMENTE
	var headshot_damage = int(float(damage) * headshot_multiplier)
	apply_damage_to_target(enemy, headshot_damage, true)
	apply_knockback_to_target(enemy)
	
	# SISTEMA DE PUNTUACIÓN BLACK OPS 1
	if score_system:
		if enemy_ref.current_health <= 0:
			# KILL CON HEADSHOT = 50 + 50 = 100 puntos (más multiplicador de ronda)
			score_system.add_kill_points(global_position, true, false)
		else:
			# DAÑO SIN KILL CON HEADSHOT = 20 puntos (más multiplicador de ronda)
			score_system.add_damage_points(global_position, headshot_damage, true)
	
	# Crear efecto de headshot
	SpriteEffectsHandler.create_headshot_effect(global_position, get_tree().current_scene)
	
	if has_piercing and pierce_count < max_pierce:
		targets_hit.append(enemy)
		pierce_count += 1
		
		if pierce_count >= max_pierce:
			destroy_bullet("piercing_limit")
	else:
		destroy_bullet("headshot")

func handle_hit(target: Node2D):
	"""Manejar impacto normal estilo Black Ops 1"""
	if is_being_destroyed or not (target is Enemy):
		return
	
	if has_piercing and target in targets_hit:
		return
	
	var enemy_ref = target as Enemy
	var enemy_initial_health = enemy_ref.current_health
	
	apply_damage_to_target(target, damage, false)
	apply_knockback_to_target(target)
	
	# SISTEMA DE PUNTUACIÓN BLACK OPS 1
	if score_system:
		if enemy_ref.current_health <= 0:
			# KILL NORMAL = 50 puntos (más multiplicador de ronda)
			score_system.add_kill_points(global_position, false, false)
		else:
			# DAÑO SIN KILL = 10 puntos (más multiplicador de ronda)
			score_system.add_damage_points(global_position, damage, false)
	
	# Crear efecto de impacto
	if has_piercing:
		SpriteEffectsHandler.create_piercing_effect(global_position, get_tree().current_scene)
	else:
		SpriteEffectsHandler.create_damage_effect(global_position, get_tree().current_scene)
	
	if has_piercing and pierce_count < max_pierce:
		targets_hit.append(target)
		pierce_count += 1
		
		if pierce_count >= max_pierce:
			destroy_bullet("piercing_limit")
	else:
		destroy_bullet("impact")

func destroy_bullet(reason: String):
	"""Destruir bala de forma segura"""
	if is_being_destroyed:
		return
	
	is_being_destroyed = true
	
	set_physics_process(false)
	set_process(false)
	
	if collision and is_instance_valid(collision):
		collision.set_deferred("disabled", true)
	
	if sprite and is_instance_valid(sprite):
		sprite.visible = false
	
	if lifetime_timer and is_instance_valid(lifetime_timer):
		lifetime_timer.stop()
	
	# Crear efectos según el tipo de destrucción
	match reason:
		"impact":
			if has_explosive:
				SpriteEffectsHandler.create_explosion_effect(global_position, get_tree().current_scene)
		"headshot":
			if has_explosive:
				SpriteEffectsHandler.create_explosion_effect(global_position, get_tree().current_scene)
		"range", "lifetime", "piercing_limit":
			pass # Sin efectos especiales
	
	call_deferred("queue_free")

func apply_damage_to_target(target: Node2D, damage_amount: int, is_headshot: bool = false):
	"""Aplicar daño al objetivo - CORREGIDO PARA HEADSHOTS"""
	if target is Enemy:
		# LLAMAR CON PARÁMETROS CORRECTOS
		target.take_damage(damage_amount, is_headshot)
		return
	
	if target.has_method("take_damage"):
		var method_info = target.get_method_list()
		var take_damage_method = null
		for method in method_info:
			if method.name == "take_damage":
				take_damage_method = method
				break
		
		if take_damage_method and take_damage_method.args.size() >= 2:
			target.take_damage(damage_amount, is_headshot)
		else:
			target.take_damage(damage_amount)
		return

func apply_knockback_to_target(target: Node2D):
	"""Aplicar knockback al objetivo estilo COD Black Ops"""
	if knockback_force <= 0:
		return
	
	if target is RigidBody2D:
		var knockback_direction = direction.normalized()
		var impulse = knockback_direction * knockback_force
		target.apply_impulse(impulse)
	elif target is CharacterBody2D:
		if target.has_method("apply_knockback"):
			var knockback_direction = direction.normalized()
			target.apply_knockback(knockback_direction, knockback_force)
