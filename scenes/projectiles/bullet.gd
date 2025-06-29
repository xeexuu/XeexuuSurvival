# scenes/projectiles/bullet.gd - SISTEMA MEJORADO PARA NUEVAS HITBOXES COMPLETAS
extends Area2D
class_name Bullet

@export var damage: int = 1
@export var max_range: float = 300.0
@export var lifetime: float = 5.0

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

var score_system: ScoreSystem

@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D

func _ready():
	collision_layer = 4
	collision_mask = 2 | 3 | 8  # Enemigos, paredes Y áreas de enemigos
	
	add_to_group("bullets")
	
	lifetime_timer = Timer.new()
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_timeout)
	add_child(lifetime_timer)
	
	setup_sprite()
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	lifetime_timer.start()
	
	get_score_system_reference()

func get_score_system_reference():
	"""Obtener referencia al sistema de puntuación"""
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		game_manager = get_node_or_null("/root/Main/GameManager")
	
	if game_manager and game_manager.has_method("get_current_score"):
		score_system = game_manager.score_system

func setup_sprite():
	"""Configurar sprite visible de la bala"""
	if not sprite:
		return
		
	var image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var base_color = Color.YELLOW
	if has_piercing:
		base_color = Color.CYAN
	elif has_explosive:
		base_color = Color.ORANGE
	
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
	sprite.z_index = 50

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
	"""DETECTAR ÁREAS ESPECÍFICAS DE ENEMIGOS para hitbox precisa MEJORADA"""
	if area == self or is_being_destroyed:
		return
	
	# Verificar si es un área de hitbox de enemigo
	if area.collision_layer & 8:  # Capa 8 = áreas de enemigos
		var enemy_parent = area.get_parent()
		if not enemy_parent or not (enemy_parent is Enemy):
			return
		
		if has_piercing and enemy_parent in targets_hit:
			return
		
		# DETERMINAR TIPO DE HIT SEGÚN EL ÁREA CON SISTEMA MEJORADO
		var hit_info = determine_hit_type_improved(area, enemy_parent)
		
		# Calcular daño final
		var final_damage = int(float(damage) * hit_info.damage_multiplier)
		
		# Aplicar daño al enemigo
		enemy_parent.take_damage(final_damage, hit_info.is_headshot, hit_info.hit_height)
		apply_knockback_to_target(enemy_parent)
		
		# Sistema de puntuación
		if score_system:
			var enemy_ref = enemy_parent as Enemy
			if enemy_ref.current_health <= 0:
				score_system.add_kill_points(global_position, hit_info.is_headshot, false)
			else:
				score_system.add_damage_points(global_position, final_damage, hit_info.is_headshot)
		
		# Crear efecto de impacto mejorado
		create_hit_effect_improved(global_position, hit_info)
		
		handle_piercing_logic(enemy_parent)

func determine_hit_type_improved(area: Area2D, enemy: Enemy) -> Dictionary:
	"""Determinar tipo de hit con sistema mejorado que considera tipo de enemigo"""
	var hit_info = {
		"is_headshot": false,
		"hit_height": 0.5,
		"damage_multiplier": 1.0,
		"area_name": area.name,
		"effect_type": "normal"
	}
	
	match area.name:
		"HeadArea":
			hit_info.is_headshot = true
			hit_info.hit_height = 0.9
			hit_info.effect_type = "headshot"
			
			# Multiplicador específico por tipo de enemigo
			match enemy.enemy_type:
				"zombie_crawler":
					hit_info.damage_multiplier = headshot_multiplier * 1.2  # Crawlers más vulnerables en cabeza
				"zombie_dog":
					hit_info.damage_multiplier = headshot_multiplier * 1.1  # Perros ligeramente más vulnerables
				_:
					hit_info.damage_multiplier = headshot_multiplier

			
		"BodyArea":
			hit_info.hit_height = 0.6
			hit_info.effect_type = "body"
			
			# Daño normal, pero ligeramente diferente por tipo
			match enemy.enemy_type:
				"zombie_crawler":
					hit_info.damage_multiplier = 1.1  # Crawlers más frágiles en general
				"zombie_dog":
					hit_info.damage_multiplier = 0.9   # Perros más resistentes en cuerpo
				_:
					hit_info.damage_multiplier = 1.0
			

			
		"LegsArea":
			hit_info.hit_height = 0.3
			hit_info.effect_type = "legs"
			
			# Daño reducido en piernas
			match enemy.enemy_type:
				"zombie_crawler":
					hit_info.damage_multiplier = 0.6  # Crawlers muy vulnerables en piernas
				"zombie_dog":
					hit_info.damage_multiplier = 0.7   # Perros algo vulnerables
				_:
					hit_info.damage_multiplier = 0.8   # Básicos resistencia normal
			

			
		_:
			hit_info.hit_height = 0.5
			hit_info.damage_multiplier = 1.0
			hit_info.effect_type = "generic"
	
	return hit_info

func create_hit_effect_improved(hit_position: Vector2, hit_info: Dictionary):
	"""Crear efecto visual mejorado según el tipo de hit y enemigo"""
	var effect_scene = get_tree().current_scene
	if not effect_scene:
		return
	
	var particle_count = 3
	var effect_color = Color.WHITE
	var effect_size = 4
	var special_effect = false
	
	# Determinar efecto según área golpeada
	match hit_info.effect_type:
		"headshot":
			particle_count = 12
			effect_color = Color.GOLD
			effect_size = 10
			special_effect = true
		"body":
			particle_count = 8
			effect_color = Color.ORANGE
			effect_size = 7
		"legs":
			particle_count = 5
			effect_color = Color.LIGHT_CORAL
			effect_size = 5
		_:
			particle_count = 6
			effect_color = Color.RED
			effect_size = 6
	
	# Crear partículas principales
	for i in range(particle_count):
		var particle = Sprite2D.new()
		var particle_image = Image.create(effect_size, effect_size, false, Image.FORMAT_RGBA8)
		particle_image.fill(effect_color)
		
		particle.texture = ImageTexture.create_from_image(particle_image)
		particle.global_position = hit_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		effect_scene.add_child(particle)
		
		var tween = effect_scene.create_tween()
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 1.0)
		tween.parallel().tween_property(particle, "global_position", 
			particle.global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40)), 1.0)
		tween.tween_callback(func(): 
			if is_instance_valid(particle):
				particle.queue_free()
		)
	
	# Efecto especial para headshots
	if special_effect:
		create_headshot_burst_effect_improved(hit_position)

func create_headshot_burst_effect_improved(hit_position: Vector2):
	"""Efecto especial mejorado de explosión para headshots"""
	var effect_scene = get_tree().current_scene
	if not effect_scene:
		return
	
	# Onda de choque circular
	for i in range(12):
		var burst = Sprite2D.new()
		var burst_image = Image.create(6, 6, false, Image.FORMAT_RGBA8)
		burst_image.fill(Color.YELLOW)
		
		burst.texture = ImageTexture.create_from_image(burst_image)
		burst.global_position = hit_position
		effect_scene.add_child(burst)
		
		# Movimiento en círculo perfecto
		var angle = (float(i) * PI * 2.0) / 12.0
		var end_pos = hit_position + Vector2.from_angle(angle) * 60
		
		var tween = effect_scene.create_tween()
		tween.parallel().tween_property(burst, "global_position", end_pos, 0.4)
		tween.parallel().tween_property(burst, "modulate:a", 0.0, 0.4)
		tween.parallel().tween_property(burst, "scale", Vector2(3.0, 3.0), 0.4)
		tween.tween_callback(func(): 
			if is_instance_valid(burst):
				burst.queue_free()
		)
	
	# Estrella central
	var star = Sprite2D.new()
	var star_image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	star_image.fill(Color.TRANSPARENT)
	
	# Crear forma de estrella
	var center = Vector2(8, 8)
	for x in range(16):
		for y in range(16):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			var angle = (pos - center).angle()
			
			# Forma de estrella de 4 puntas
			var star_factor = abs(cos(angle * 2)) + abs(sin(angle * 2))
			if dist <= 6 * star_factor:
				star_image.set_pixel(x, y, Color.WHITE)
	
	star.texture = ImageTexture.create_from_image(star_image)
	star.global_position = hit_position
	effect_scene.add_child(star)
	
	var star_tween = effect_scene.create_tween()
	star_tween.parallel().tween_property(star, "scale", Vector2(2.0, 2.0), 0.2)
	star_tween.parallel().tween_property(star, "rotation_degrees", 360, 0.6)
	star_tween.parallel().tween_property(star, "modulate:a", 0.0, 0.6)
	star_tween.tween_callback(func(): 
		if is_instance_valid(star):
			star.queue_free()
	)

func _on_body_entered(body: Node2D):
	"""Detectar cuerpo - ATRAVESAR BARRICADAS, DETENERSE EN PAREDES SÓLIDAS"""
	if is_being_destroyed:
		return
	
	if body is Player:
		return
	
	# Verificar si es una pared sólida o barricada
	if body is StaticBody2D:
		if body.collision_layer & 3:
			var parent_node = body.get_parent()
			
			if parent_node and parent_node.name.begins_with("Barricade_"):
				# ES UNA BARRICADA - ATRAVESAR SIEMPRE (para ataques a través de barricadas)
				return  # NO DESTRUIR LA BALA, continuar
			else:
				# ES UNA PARED SÓLIDA - DETENERSE
				create_wall_impact_effect(global_position)
				destroy_bullet("wall_impact")
				return
	
	# Verificar si es un enemigo (hit directo al cuerpo principal) - LEGACY MEJORADO
	if body is Enemy:
		if has_piercing and body in targets_hit:
			return
		
		var enemy_ref = body as Enemy
		
		# Hit directo al cuerpo (sin áreas específicas) con sistema mejorado
		var hit_info = {
			"is_headshot": false,
			"hit_height": 0.5,
			"damage_multiplier": 1.0,
			"effect_type": "body"
		}
		
		# Aplicar multiplicador por tipo de enemigo para hits directos
		match enemy_ref.enemy_type:
			"zombie_crawler":
				hit_info.damage_multiplier = 1.1
			"zombie_dog":
				hit_info.damage_multiplier = 0.9
			_:
				hit_info.damage_multiplier = 1.0
		
		var final_damage = int(float(damage) * hit_info.damage_multiplier)
		
		enemy_ref.take_damage(final_damage, hit_info.is_headshot, hit_info.hit_height)
		apply_knockback_to_target(body)
		
		if score_system:
			if enemy_ref.current_health <= 0:
				score_system.add_kill_points(global_position, hit_info.is_headshot, false)
			else:
				score_system.add_damage_points(global_position, final_damage, hit_info.is_headshot)
		
		create_hit_effect_improved(global_position, hit_info)
		
		handle_piercing_logic(body)

func handle_piercing_logic(target: Node2D):
	"""Manejar lógica de perforación"""
	if has_piercing and pierce_count < max_pierce:
		targets_hit.append(target)
		pierce_count += 1
		
		if pierce_count >= max_pierce:
			destroy_bullet("piercing_limit")
	else:
		destroy_bullet("impact")

func create_wall_impact_effect(hit_position: Vector2):
	"""Crear efecto visual de impacto en pared"""
	var effect_scene = get_tree().current_scene
	if not effect_scene:
		return
	
	for i in range(4):
		var particle = Sprite2D.new()
		var particle_image = Image.create(3, 3, false, Image.FORMAT_RGBA8)
		particle_image.fill(Color.GRAY)
		particle.texture = ImageTexture.create_from_image(particle_image)
		particle.global_position = hit_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		effect_scene.add_child(particle)
		
		var tween = effect_scene.create_tween()
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.3)
		tween.parallel().tween_property(particle, "global_position", 
			particle.global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15)), 0.3)
		tween.tween_callback(func(): 
			if is_instance_valid(particle):
				particle.queue_free()
		)

func apply_knockback_to_target(target: Node2D):
	"""Aplicar knockback al objetivo"""
	if knockback_force <= 0:
		return
	
	if target is CharacterBody2D:
		if target.has_method("apply_knockback"):
			var knockback_direction = direction.normalized()
			target.apply_knockback(knockback_direction, knockback_force)

func destroy_bullet(_reason: String):
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
	
	call_deferred("queue_free")
