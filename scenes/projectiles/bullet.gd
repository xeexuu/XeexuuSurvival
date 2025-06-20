# scenes/projectiles/bullet.gd - LAS BALAS NO ATRAVIESAN PAREDES SÓLIDAS NI BARRICADAS CON TABLONES
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
	collision_layer = 4  # Capa 4 para balas
	collision_mask = 2 | 3  # Detecta enemigos (2) Y paredes sólidas (3)
	
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
	"""CONFIGURAR SPRITE VISIBLE DE LA BALA"""
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
	"""DETECTAR ÁREA DE ENEMIGO con hitboxes específicas"""
	if area == self or is_being_destroyed:
		return
	
	var enemy_parent = area.get_parent()
	if not enemy_parent or not (enemy_parent is Enemy):
		return
	
	if has_piercing and enemy_parent in targets_hit:
		return
	
	var is_headshot = false
	var damage_multiplier = 1.0
	
	# Determinar tipo de hit según el área
	match area.name:
		"HeadArea":
			is_headshot = true
			damage_multiplier = headshot_multiplier
		"BodyArea":
			damage_multiplier = 1.0
		"LegsArea":
			damage_multiplier = 0.8
		_:
			damage_multiplier = 1.0
	
	# Calcular daño final
	var final_damage = int(float(damage) * damage_multiplier)
	
	# Aplicar daño
	apply_damage_to_target(enemy_parent, final_damage, is_headshot)
	apply_knockback_to_target(enemy_parent)
	
	# Sistema de puntuación
	if score_system:
		var enemy_ref = enemy_parent as Enemy
		if enemy_ref.current_health <= 0:
			score_system.add_kill_points(global_position, is_headshot, false)
		else:
			score_system.add_damage_points(global_position, final_damage, is_headshot)
	
	# Crear efecto de impacto
	create_hit_effect(global_position, is_headshot)
	
	handle_piercing_logic(enemy_parent)

func _on_body_entered(body: Node2D):
	"""DETECTAR CUERPO - INCLUYENDO PAREDES SÓLIDAS Y BARRICADAS CON TABLONES"""
	if is_being_destroyed:
		return
	
	if body is Player:
		return
	
	# VERIFICAR SI ES UNA PARED SÓLIDA
	if body is StaticBody2D:
		# Verificar si es una pared sólida o barricada
		if body.collision_layer & 3:  # Capa 3 = paredes sólidas
			# VERIFICAR SI ES UNA BARRICADA ANTES DE PARAR LA BALA
			var parent_node = body.get_parent()
			if parent_node and parent_node.name.begins_with("Barricade_"):
				# ES UNA BARRICADA - VERIFICAR SI TIENE TABLONES
				var current_planks = parent_node.get_meta("current_planks", 0)
				if current_planks > 0:
					# TIENE TABLONES - LA BALA NO PASA
					create_wall_impact_effect(global_position)
					destroy_bullet("barricade_with_planks")
					return
				else:
					# NO TIENE TABLONES - LA BALA PASA A TRAVÉS
					return
			else:
				# ES UNA PARED SÓLIDA NORMAL - LA BALA NO PASA
				create_wall_impact_effect(global_position)
				destroy_bullet("wall_impact")
				return
	
	# VERIFICAR SI ES UN ENEMIGO
	if body is Enemy:
		handle_hit(body)

func handle_hit(target: Node2D):
	"""Manejar impacto normal"""
	if is_being_destroyed or not (target is Enemy):
		return
	
	if has_piercing and target in targets_hit:
		return
	
	var enemy_ref = target as Enemy
	
	apply_damage_to_target(target, damage, false)
	apply_knockback_to_target(target)
	
	if score_system:
		if enemy_ref.current_health <= 0:
			score_system.add_kill_points(global_position, false, false)
		else:
			score_system.add_damage_points(global_position, damage, false)
	
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

func create_hit_effect(hit_position: Vector2, is_headshot: bool):
	"""Crear efecto visual de impacto"""
	var effect_scene = get_tree().current_scene
	if not effect_scene:
		return
	
	for i in range(3 if not is_headshot else 6):
		var particle = Sprite2D.new()
		var particle_image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		
		if is_headshot:
			particle_image.fill(Color.YELLOW)
		else:
			particle_image.fill(Color.RED)
		
		particle.texture = ImageTexture.create_from_image(particle_image)
		particle.global_position = hit_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		effect_scene.add_child(particle)
		
		var tween = effect_scene.create_tween()
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.parallel().tween_property(particle, "global_position", particle.global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20)), 0.5)
		tween.tween_callback(func(): particle.queue_free())

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
		tween.parallel().tween_property(particle, "global_position", particle.global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15)), 0.3)
		tween.tween_callback(func(): particle.queue_free())

func apply_damage_to_target(target: Node2D, damage_amount: int, is_headshot: bool = false):
	"""Aplicar daño al objetivo"""
	if not target or not target.has_method("take_damage"):
		return
	
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
