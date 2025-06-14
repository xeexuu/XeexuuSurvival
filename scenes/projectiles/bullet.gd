# scenes/projectiles/bullet.gd
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

@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D

func _ready():
	collision_layer = 4
	collision_mask = 2
	
	add_to_group("bullets")
	
	lifetime_timer = Timer.new()
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_timeout)
	add_child(lifetime_timer)
	
	setup_sprite()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	lifetime_timer.start()

func setup_sprite():
	"""Configurar sprite de la bala estilo COD Black Ops"""
	if not sprite.texture:
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
		if area.name == "HeadArea":
			handle_headshot_hit(area.get_parent())
		else:
			handle_hit(area)

func _on_body_entered(body: Node2D):
	if body is Player or is_being_destroyed:
		return
	
	if body is Enemy or body.has_method("take_damage"):
		handle_hit(body)

func handle_headshot_hit(enemy: Node2D):
	"""Manejar impacto headshot estilo COD Black Ops"""
	if is_being_destroyed:
		return
	
	if has_piercing and enemy in targets_hit:
		return
	
	var headshot_damage = int(float(damage) * headshot_multiplier)
	apply_damage_to_target(enemy, headshot_damage, true)
	apply_knockback_to_target(enemy)
	
	# Crear efecto de headshot usando el sistema separado
	SpriteEffectsHandler.create_headshot_effect(global_position, get_tree().current_scene)
	
	if has_piercing and pierce_count < max_pierce:
		targets_hit.append(enemy)
		pierce_count += 1
		
		if pierce_count >= max_pierce:
			destroy_bullet("piercing_limit")
	else:
		destroy_bullet("headshot")

func handle_hit(target: Node2D):
	"""Manejar impacto normal"""
	if is_being_destroyed:
		return
	
	if has_piercing and target in targets_hit:
		return
	
	apply_damage_to_target(target, damage, false)
	apply_knockback_to_target(target)
	
	# Crear efecto de impacto usando el sistema separado
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
	"""Aplicar daño al objetivo"""
	if target is Enemy:
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
	
	# Buscar en los hijos
	for child in target.get_children():
		if child.has_method("take_damage") or child.name.to_lower().contains("health"):
			if child.has_method("take_damage"):
				child.take_damage(damage_amount)
			break

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
