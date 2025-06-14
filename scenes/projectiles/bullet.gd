# scenes/projectiles/bullet.gd
extends Area2D
class_name Bullet

@export var damage: int = 1
@export var max_range: float = 300.0
@export var lifetime: float = 5.0

# Nuevas propiedades de armas
var has_piercing: bool = false
var has_explosive: bool = false
var knockback_force: float = 0.0
var headshot_multiplier: float = 1.4  # NUEVO: Multiplicador de headshot
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
	# Configurar grupos y capas para detectar enemigos
	collision_layer = 4  # Capa de proyectiles
	collision_mask = 2   # Detectar enemigos (capa 2)
	
	# Añadir a grupo de balas
	add_to_group("bullets")
	
	# Configurar timer de vida máxima
	lifetime_timer = Timer.new()
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_timeout)
	add_child(lifetime_timer)
	
	setup_sprite()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	# Iniciar timer de vida
	lifetime_timer.start()

func setup_sprite():
	if not sprite.texture:
		var image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		
		# Color base dependiendo del tipo de bala
		var base_color = Color.YELLOW
		if has_piercing:
			base_color = Color.CYAN
		elif has_explosive:
			base_color = Color.ORANGE
		
		for x in range(8):
			for y in range(8):
				var dist = Vector2(x - 4, y - 4).length()
				if dist <= 3:
					image.set_pixel(x, y, base_color)
				elif dist <= 4:
					image.set_pixel(x, y, base_color.darkened(0.3))
		
		sprite.texture = ImageTexture.create_from_image(image)

func setup(new_direction: Vector2, new_speed: float, weapon_range: float = 300.0):
	direction = new_direction.normalized()
	speed = new_speed
	max_range = weapon_range
	start_position = global_position
	distance_traveled = 0.0
	rotation = direction.angle()

func _physics_process(delta):
	if is_being_destroyed:
		return
	
	# Mover la bala
	var movement = direction * speed * delta
	global_position += movement
	distance_traveled += movement.length()
	
	# VERIFICAR RANGO
	var current_distance = start_position.distance_to(global_position)
	
	# Si la bala ha recorrido la distancia máxima, destruirla INMEDIATAMENTE
	if current_distance >= max_range:
		destroy_bullet("range")
		return

func _on_lifetime_timeout():
	if not is_being_destroyed:
		destroy_bullet("lifetime")

func _on_area_entered(area: Area2D):
	if area != self and not is_being_destroyed:
		# Verificar si es el área de la cabeza
		if area.name == "HeadArea":
			handle_headshot_hit(area.get_parent())
		else:
			handle_hit(area)

func _on_body_entered(body: Node2D):
	if body is Player or is_being_destroyed:
		return
	
	# Verificar si es un enemigo
	if body is Enemy or body.has_method("take_damage"):
		handle_hit(body)

func handle_headshot_hit(enemy: Node2D):
	"""Manejar impacto en la cabeza del enemigo"""
	if is_being_destroyed:
		return
	
	# Para piercing, verificar si ya golpeamos este objetivo
	if has_piercing and enemy in targets_hit:
		return
	
	# Aplicar daño con multiplicador de headshot
	var headshot_damage = int(float(damage) * headshot_multiplier)
	apply_damage_to_target(enemy, headshot_damage, true)  # true = headshot
	
	# Aplicar knockback si está configurado
	apply_knockback_to_target(enemy)
	
	# Manejar piercing
	if has_piercing and pierce_count < max_pierce:
		targets_hit.append(enemy)
		pierce_count += 1
		
		# Crear efecto de headshot
		create_headshot_effect()
		
		# Solo destruir si alcanzamos el máximo de piercing
		if pierce_count >= max_pierce:
			destroy_bullet("piercing_limit")
	else:
		# Bala normal o piercing que alcanzó el máximo
		destroy_bullet("headshot")

func handle_hit(target: Node2D):
	"""Manejar impacto normal en el cuerpo"""
	if is_being_destroyed:
		return
	
	# Para piercing, verificar si ya golpeamos este objetivo
	if has_piercing and target in targets_hit:
		return
	
	# Aplicar daño normal
	apply_damage_to_target(target, damage, false)  # false = no headshot
	
	# Aplicar knockback si está configurado
	apply_knockback_to_target(target)
	
	# Manejar piercing
	if has_piercing and pierce_count < max_pierce:
		targets_hit.append(target)
		pierce_count += 1
		
		# Crear efecto de hit pero no destruir
		create_hit_effect()
		
		# Solo destruir si alcanzamos el máximo de piercing
		if pierce_count >= max_pierce:
			destroy_bullet("piercing_limit")
	else:
		# Bala normal o piercing que alcanzó el máximo
		destroy_bullet("impact")

func destroy_bullet(reason: String):
	"""Función unificada de destrucción"""
	if is_being_destroyed:
		return
	
	is_being_destroyed = true
	
	# 1. DETENER INMEDIATAMENTE toda la funcionalidad
	set_physics_process(false)
	set_process(false)
	
	# 2. DESACTIVAR colisiones INMEDIATAMENTE
	if collision and is_instance_valid(collision):
		collision.set_deferred("disabled", true)
	
	# 3. OCULTAR sprite INMEDIATAMENTE
	if sprite and is_instance_valid(sprite):
		sprite.visible = false
	
	# 4. DETENER timer si existe
	if lifetime_timer and is_instance_valid(lifetime_timer):
		lifetime_timer.stop()
	
	# 5. CREAR efectos antes de destruir
	match reason:
		"impact":
			if has_explosive:
				create_explosion_effect()
			else:
				create_hit_effect()
		"headshot":
			if has_explosive:
				create_explosion_effect()
			else:
				create_headshot_effect()
		"range":
			create_fade_effect()
		"lifetime":
			create_fade_effect()
		"piercing_limit":
			create_hit_effect()
	
	# 6. DESTRUIR INMEDIATAMENTE
	call_deferred("queue_free")

func apply_damage_to_target(target: Node2D, damage_amount: int, is_headshot: bool = false):
	"""Aplicar daño al objetivo"""
	
	# Buscar directamente en el objetivo si es un enemigo
	if target is Enemy:
		target.take_damage(damage_amount, is_headshot)
		return
	
	# Buscar directamente en el objetivo
	if target.has_method("take_damage"):
		# Verificar si el método acepta parámetro de headshot
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
	"""Aplicar knockback al objetivo si está configurado"""
	if knockback_force <= 0:
		return
	
	# Solo aplicar knockback a cuerpos físicos
	if target is RigidBody2D:
		var knockback_direction = direction.normalized()
		var impulse = knockback_direction * knockback_force
		target.apply_impulse(impulse)
	elif target is CharacterBody2D:
		if target.has_method("apply_knockback"):
			var knockback_direction = direction.normalized()
			target.apply_knockback(knockback_direction * knockback_force)

func create_headshot_effect():
	"""Crear efecto especial para headshots"""
	var main_scene = get_tree().current_scene
	if not main_scene:
		return
	
	var effect = Node2D.new()
	effect.position = global_position
	
	# Más partículas y colores diferentes para headshots
	for i in range(8):
		var particle = Sprite2D.new()
		var particle_image = Image.create(6, 6, false, Image.FORMAT_RGBA8)
		particle_image.fill(Color.YELLOW)  # Color dorado para headshots
		particle.texture = ImageTexture.create_from_image(particle_image)
		
		var offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
		particle.position = offset
		effect.add_child(particle)
		
		# Animar partícula con más movimiento
		var tween = effect.create_tween()
		tween.parallel().tween_property(particle, "position", offset * 3, 0.5)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.parallel().tween_property(particle, "scale", Vector2(1.5, 1.5), 0.3)
	
	main_scene.add_child(effect)
	
	var effect_timer = Timer.new()
	effect_timer.wait_time = 0.6
	effect_timer.one_shot = true
	effect_timer.timeout.connect(func(): effect.queue_free())
	effect.add_child(effect_timer)
	effect_timer.start()

func create_explosion_effect():
	"""Crear efecto de explosión para balas explosivas"""
	var main_scene = get_tree().current_scene
	if not main_scene:
		return
	
	var explosion = Node2D.new()
	explosion.position = global_position
	
	# Crear múltiples partículas para la explosión
	for i in range(8):
		var particle = Sprite2D.new()
		var particle_image = Image.create(6, 6, false, Image.FORMAT_RGBA8)
		particle_image.fill(Color.ORANGE)
		particle.texture = ImageTexture.create_from_image(particle_image)
		
		var angle = (float(i) * PI * 2.0) / 8.0
		var offset = Vector2.from_angle(angle) * randf_range(10, 25)
		particle.position = offset
		explosion.add_child(particle)
		
		# Animar la partícula
		var tween = explosion.create_tween()
		tween.parallel().tween_property(particle, "position", offset * 2, 0.5)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.parallel().tween_property(particle, "scale", Vector2.ZERO, 0.5)
	
	main_scene.add_child(explosion)
	
	# Limpiar el efecto
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 0.6
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(func(): explosion.queue_free())
	explosion.add_child(cleanup_timer)
	cleanup_timer.start()

func create_hit_effect():
	"""Crear efecto de impacto normal"""
	var main_scene = get_tree().current_scene
	if not main_scene:
		return
	
	var effect = Node2D.new()
	effect.position = global_position
	
	var particle_count = 3 if not has_piercing else 5
	for i in range(particle_count):
		var particle = Sprite2D.new()
		var particle_image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		
		var particle_color = Color.WHITE
		if has_piercing:
			particle_color = Color.CYAN
		
		particle_image.fill(particle_color)
		particle.texture = ImageTexture.create_from_image(particle_image)
		
		var offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
		particle.position = offset
		effect.add_child(particle)
		
		# Animar partícula
		var tween = effect.create_tween()
		tween.parallel().tween_property(particle, "position", offset * 2, 0.3)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.3)
	
	main_scene.add_child(effect)
	
	var effect_timer = Timer.new()
	effect_timer.wait_time = 0.4
	effect_timer.one_shot = true
	effect_timer.timeout.connect(func(): effect.queue_free())
	effect.add_child(effect_timer)
	effect_timer.start()

func create_fade_effect():
	"""Efecto visual cuando la bala se desvanece por alcanzar el rango máximo"""
	var main_scene = get_tree().current_scene
	if not main_scene:
		return
	
	var fade_effect = Node2D.new()
	fade_effect.position = global_position
	
	var fade_sprite = Sprite2D.new()
	if sprite and sprite.texture:
		fade_sprite.texture = sprite.texture
		fade_sprite.modulate = sprite.modulate
	else:
		# Crear sprite temporal si no hay texture
		var temp_image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		temp_image.fill(Color.YELLOW)
		fade_sprite.texture = ImageTexture.create_from_image(temp_image)
	
	fade_effect.add_child(fade_sprite)
	main_scene.add_child(fade_effect)
	
	# Tween para desvanecer
	var tween = fade_effect.create_tween()
	tween.tween_property(fade_sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): fade_effect.queue_free())
