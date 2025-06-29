# scenes/world/WallSystem.gd - CORREGIDO: MURO INVISIBLE SOLO PARA JUGADOR + BARRICADAS MEJORADAS
extends Node2D
class_name WallSystem

var solid_walls: Array[StaticBody2D] = []
var barricades: Array[Node2D] = []
var doors: Array[Node2D] = []
var player_ref: Player
var current_door_prompt: Control
var current_interaction_prompt: Control
var barricade_attack_timer: Timer
var barricades_under_attack: Dictionary = {}

func _ready():
	create_giant_room_without_left_barricade()
	call_deferred("get_player_reference")
	setup_barricade_attack_system()

func setup_barricade_attack_system():
	"""Sistema de ataque a barricadas"""
	barricade_attack_timer = Timer.new()
	barricade_attack_timer.wait_time = 0.2
	barricade_attack_timer.autostart = true
	barricade_attack_timer.timeout.connect(_process_barricade_attacks_improved)
	add_child(barricade_attack_timer)

func _process_barricade_attacks_improved():
	"""Procesar ataques a barricadas"""
	var current_time = Time.get_ticks_msec() / 1000.0
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	# Limpiar ataques antiguos
	var barricades_to_remove = []
	for barricade in barricades_under_attack:
		if current_time - barricades_under_attack[barricade] > 3.0:
			barricades_to_remove.append(barricade)
	
	for barricade in barricades_to_remove:
		barricades_under_attack.erase(barricade)
	
	# Procesar enemigos atacando barricadas
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		var is_dead = false
		if "is_dead" in enemy:
			is_dead = enemy.is_dead
		
		if is_dead:
			continue
		
		var is_jumping = false
		if "is_jumping" in enemy:
			is_jumping = enemy.is_jumping
		
		if is_jumping:
			continue
		
		var is_attacking_barricade = false
		var target_barricade = null
		
		if "is_attacking_barricade" in enemy:
			is_attacking_barricade = enemy.is_attacking_barricade
		
		if "target_barricade" in enemy:
			target_barricade = enemy.target_barricade
		
		if is_attacking_barricade and target_barricade and is_instance_valid(target_barricade):
			process_enemy_barricade_attack_improved(enemy, target_barricade, current_time)

func process_enemy_barricade_attack_improved(enemy: Node, barricade: Node2D, current_time: float):
	"""Procesar ataque de enemigo a barricada"""
	var distance_to_barricade = enemy.global_position.distance_to(barricade.global_position)
	
	var attack_range = 90.0
	if "attack_range" in enemy:
		attack_range = enemy.attack_range
	
	if distance_to_barricade > attack_range * 1.2:
		return
	
	var enemy_attack_cooldown = 1.5
	if "attack_cooldown" in enemy:
		enemy_attack_cooldown = enemy.attack_cooldown
	
	var enemy_last_attack = 0.0
	if "last_attack_time" in enemy:
		enemy_last_attack = enemy.last_attack_time
	
	if current_time - enemy_last_attack < enemy_attack_cooldown:
		return
	
	var barricade_last_attack = barricades_under_attack.get(barricade, 0.0)
	if current_time - barricade_last_attack < 0.3:
		return
	
	var current_planks = barricade.get_meta("current_planks", 0)
	if current_planks > 0:
		var damage_amount = 1
		
		if "enemy_type" in enemy:
			match enemy.enemy_type:
				"zombie_dog":
					damage_amount = 2
				"zombie_crawler":
					damage_amount = 1
				_:
					damage_amount = 1
		
		damage_barricade(barricade, damage_amount)
		
		if "last_attack_time" in enemy:
			enemy.last_attack_time = current_time
		barricades_under_attack[barricade] = current_time
		
		create_barricade_attack_effect(barricade.global_position, enemy)

func create_barricade_attack_effect(pos: Vector2, enemy: Node):
	"""Crear efecto visual de ataque a barricada"""
	var particle_count = 4
	var effect_color = Color.ORANGE
	
	if "enemy_type" in enemy:
		match enemy.enemy_type:
			"zombie_dog":
				effect_color = Color.RED
				particle_count = 6
			"zombie_crawler":
				effect_color = Color.LIME
				particle_count = 5
			_:
				effect_color = Color.ORANGE
				particle_count = 4
	
	for i in range(particle_count):
		var particle = Sprite2D.new()
		var particle_size = randi_range(8, 12)
		var particle_image = Image.create(particle_size, particle_size, false, Image.FORMAT_RGBA8)
		particle_image.fill(effect_color)
		particle.texture = ImageTexture.create_from_image(particle_image)
		particle.global_position = pos + Vector2(randf_range(-25, 25), randf_range(-25, 25))
		get_tree().current_scene.add_child(particle)
		
		var tween = create_tween()
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.8)
		tween.parallel().tween_property(particle, "global_position", 
			particle.global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40)), 0.8)
		tween.tween_callback(func():
			if is_instance_valid(particle):
				particle.queue_free()
		)

func get_player_reference():
	await get_tree().create_timer(1.0).timeout
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.player:
		player_ref = game_manager.player

func create_giant_room_without_left_barricade():
	"""Crear habitación SIN barricada en la pared izquierda"""
	var room_center = Vector2(0, 0)
	var room_size = Vector2(1600, 1200)
	var wall_thickness = 60

	create_walls_with_vertical_door_gap(room_center, room_size, wall_thickness)
	create_strategic_barricades_without_left(room_center, room_size, wall_thickness)
	create_large_door_1x3(Vector2(room_center.x - room_size.x/2 - wall_thickness/2, room_center.y))

func create_strategic_barricades_without_left(room_center: Vector2, room_size: Vector2, wall_thickness: float):
	"""Crear barricadas estratégicas SIN la de la izquierda"""
	var barricade_positions = [
		# PARED NORTE
		Vector2(room_center.x - 250, room_center.y - room_size.y/2 - wall_thickness/2),
		Vector2(room_center.x + 250, room_center.y - room_size.y/2 - wall_thickness/2),
		# PARED SUR
		Vector2(room_center.x - 250, room_center.y + room_size.y/2 + wall_thickness/2),
		Vector2(room_center.x + 250, room_center.y + room_size.y/2 + wall_thickness/2),
		# PARED ESTE
		Vector2(room_center.x + room_size.x/2 + wall_thickness/2, room_center.y),
		# SIN BARRICADA EN PARED IZQUIERDA
	]
	
	var barricade_sizes = [
		Vector2(300, wall_thickness), Vector2(300, wall_thickness),
		Vector2(300, wall_thickness), Vector2(300, wall_thickness),
		Vector2(wall_thickness, 300)
	]
	
	for i in range(barricade_positions.size()):
		create_enhanced_barricade_with_player_wall(barricade_positions[i], barricade_sizes[i], 8)

func create_enhanced_barricade_with_player_wall(barricade_pos: Vector2, barricade_size: Vector2, max_planks: int) -> Node2D:
	"""Crear barricada con MURO INVISIBLE SOLO PARA JUGADOR + sprites mejorados"""
	var barricade = Node2D.new()
	barricade.name = "Barricade_" + str(barricades.size())
	barricade.position = barricade_pos
	
	barricade.set_meta("max_planks", max_planks)
	barricade.set_meta("current_planks", max_planks)
	barricade.set_meta("size", barricade_size)
	barricade.set_meta("repair_cost", 10)
	barricade.set_meta("is_blocking", true)
	barricade.set_meta("last_damage_time", 0.0)
	
	# === CUERPO PRINCIPAL - AFECTA JUGADOR Y ENEMIGOS (DINÁMICO) ===
	var static_body = StaticBody2D.new()
	static_body.name = "BarricadeBody"
	# INICIALMENTE: Bloquea jugador Y enemigos
	static_body.collision_layer = 3  # Capa 1 (jugador) + Capa 2 (enemigos)
	static_body.collision_mask = 1 | 2  # Detecta jugador y enemigos
	
	var collision_shape = CollisionShape2D.new()
	collision_shape.name = "BarricadeCollision"
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = barricade_size * 0.9
	collision_shape.shape = rect_shape
	static_body.add_child(collision_shape)
	barricade.add_child(static_body)
	
	# === NUEVO: MURO INVISIBLE SOLO PARA JUGADOR (SIEMPRE ACTIVO) ===
	var player_wall = StaticBody2D.new()
	player_wall.name = "PlayerWall"
	player_wall.collision_layer = 1  # SOLO capa 1 (jugador)
	player_wall.collision_mask = 0    # No detecta nada
	
	var player_collision = CollisionShape2D.new()
	player_collision.name = "PlayerWallCollision"
	var player_rect_shape = RectangleShape2D.new()
	player_rect_shape.size = barricade_size * 0.95  # Ligeramente más grande
	player_collision.shape = player_rect_shape
	player_wall.add_child(player_collision)
	barricade.add_child(player_wall)
	
	
	# FONDO DE BARRICADA MEJORADO (suelo/base)
	var background = create_enhanced_barricade_background(barricade_size)
	barricade.add_child(background)
	
	# Crear tablones visuales MEJORADOS
	for i in range(max_planks):
		var plank = create_enhanced_plank(i, max_planks, barricade_size)
		barricade.add_child(plank)
	
	# Área de interacción
	var interaction_area = Area2D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 16
	interaction_area.collision_mask = 1
	
	var interaction_shape = CollisionShape2D.new()
	var interaction_rect = RectangleShape2D.new()
	interaction_rect.size = barricade_size * 2.0
	interaction_shape.shape = interaction_rect
	interaction_area.add_child(interaction_shape)
	barricade.add_child(interaction_area)
	
	interaction_area.body_entered.connect(_on_barricade_interaction_entered.bind(barricade))
	interaction_area.body_exited.connect(_on_barricade_interaction_exited.bind(barricade))
	
	add_child(barricade)
	barricades.append(barricade)
	
	return barricade

func create_enhanced_barricade_background(barricade_size: Vector2) -> Control:
	"""Crear fondo mejorado para barricada (suelo/base)"""
	var background = Control.new()
	background.name = "BarricadeBackground"
	background.size = barricade_size
	background.position = Vector2(-barricade_size.x/2, -barricade_size.y/2)
	
	# Crear imagen de fondo tipo suelo/cemento
	var bg_image = Image.create(int(barricade_size.x), int(barricade_size.y), false, Image.FORMAT_RGBA8)
	
	# Color base gris cemento
	var base_color = Color(0.4, 0.4, 0.45, 1.0)
	bg_image.fill(base_color)
	
	# Añadir textura de cemento/piedra
	for x in range(int(barricade_size.x)):
		for y in range(int(barricade_size.y)):
			# Ruido para textura
			var noise_factor = sin(x * 0.1) * cos(y * 0.1) * 0.1
			var color_variation = base_color.lightened(noise_factor)
			
			# Grietas ocasionales
			if (x + y) % 23 == 0:
				color_variation = base_color.darkened(0.3)
			
			bg_image.set_pixel(x, y, color_variation)
	
	var bg_texture = ImageTexture.create_from_image(bg_image)
	
	var bg_rect = TextureRect.new()
	bg_rect.texture = bg_texture
	bg_rect.size = barricade_size
	background.add_child(bg_rect)
	
	return background

func create_enhanced_plank(plank_index: int, max_planks: int, barricade_size: Vector2) -> Control:
	"""Crear tablón mejorado con mejor textura"""
	var plank = Control.new()
	plank.name = "Plank_" + str(plank_index)
	
	var is_horizontal = barricade_size.x > barricade_size.y
	var plank_size: Vector2
	var plank_pos: Vector2
	
	if is_horizontal:
		var plank_height = barricade_size.y / float(max_planks)
		var plank_width = barricade_size.x * 0.95
		plank_size = Vector2(plank_width, plank_height * 0.9)
		plank_pos = Vector2(-plank_width/2, (plank_index - (max_planks - 1) * 0.5) * plank_height - plank_size.y/2)
	else:
		var plank_width = barricade_size.x / float(max_planks)
		var plank_height = barricade_size.y * 0.95
		plank_size = Vector2(plank_width * 0.9, plank_height)
		plank_pos = Vector2((plank_index - (max_planks - 1) * 0.5) * plank_width - plank_size.x/2, -plank_height/2)
	
	plank.size = plank_size
	plank.position = plank_pos
	
	# Crear imagen de tablón mejorada
	var plank_image = Image.create(int(plank_size.x), int(plank_size.y), false, Image.FORMAT_RGBA8)
	
	# Color base de madera con variación
	var wood_hue = 0.08 + randf_range(-0.02, 0.02)  # Marrón
	var wood_saturation = 0.6 + randf_range(-0.1, 0.1)
	var wood_value = 0.5 + randf_range(-0.1, 0.1)
	var base_wood_color = Color.from_hsv(wood_hue, wood_saturation, wood_value)
	
	plank_image.fill(base_wood_color)
	
	# Añadir vetas de madera
	var grain_direction = Vector2(1, 0) if is_horizontal else Vector2(0, 1)
	
	for x in range(int(plank_size.x)):
		for y in range(int(plank_size.y)):
			# Vetas de madera
			var grain_position = Vector2(x, y).dot(grain_direction)
			var grain_factor = sin(grain_position * 0.2) * 0.1
			
			# Desgaste y daños
			var damage_factor = 0.0
			if randf() < 0.05:  # 5% de píxeles dañados
				damage_factor = randf_range(-0.2, -0.1)
			
			# Aplicar efectos
			var final_color = base_wood_color.lightened(grain_factor + damage_factor)
			
			# Añadir clavos ocasionales
			if x % int(plank_size.x / 3) < 3 and y % int(plank_size.y / 3) < 3:
				final_color = Color.DARK_GRAY  # Clavo
			
			plank_image.set_pixel(x, y, final_color)
	
	var plank_texture = ImageTexture.create_from_image(plank_image)
	
	var plank_rect = TextureRect.new()
	plank_rect.texture = plank_texture
	plank_rect.size = plank_size
	plank.add_child(plank_rect)
	
	return plank

func update_barricade_collision_optimized(barricade: Node2D):
	"""CORREGIDO: Barricadas sin tablones SÍ son atravesables por enemigos"""
	var current_planks = barricade.get_meta("current_planks", 0)
	var collision_body = barricade.get_node_or_null("BarricadeBody/BarricadeCollision")
	var player_wall = barricade.get_node_or_null("PlayerWall/PlayerWallCollision")
	
	# === COLISIÓN PRINCIPAL (DINÂMICA) ===
	if collision_body:
		var parent_body = collision_body.get_parent() as StaticBody2D
		if parent_body:
			if current_planks > 0:
				# CON TABLONES: Bloquea jugador Y enemigos
				parent_body.collision_layer = 3  # Capa 1 (jugador) + Capa 2 (enemigos)
				parent_body.collision_mask = 1 | 2  # Detecta jugador y enemigos
				collision_body.disabled = false
			else:
				# SIN TABLONES: NO BLOQUEA A ENEMIGOS (pero sí al jugador via muro invisible)
				parent_body.collision_layer = 0  # NO bloquea a nadie
				parent_body.collision_mask = 0   # NO detecta a nadie  
				collision_body.disabled = true   # Desactivar completamente
	
	# === MURO INVISIBLE PARA JUGADOR (SIEMPRE ACTIVO) ===
	if player_wall:
		var player_wall_body = player_wall.get_parent() as StaticBody2D
		if player_wall_body:
			# SIEMPRE BLOQUEA AL JUGADOR, independientemente de los tablones
			player_wall_body.collision_layer = 1  # SOLO jugador
			player_wall_body.collision_mask = 0   # No detecta nada
			player_wall.disabled = false          # SIEMPRE ACTIVO

func damage_barricade(barricade: Node2D, damage_amount: int = 1):
	"""Dañar barricada y actualizar colisiones INMEDIATAMENTE"""
	if not is_instance_valid(barricade):
		return
		
	var current_planks = barricade.get_meta("current_planks", 0)
	var max_planks = barricade.get_meta("max_planks", 8)
	
	if current_planks <= 0:
		return
	
	current_planks = max(0, current_planks - damage_amount)
	barricade.set_meta("current_planks", current_planks)
	barricade.set_meta("last_damage_time", Time.get_ticks_msec() / 1000.0)
	
	# Ocultar tablones dañados con animación que se LIMPIA AUTOMÁTICAMENTE
	for i in range(current_planks, max_planks):
		var plank = barricade.get_node_or_null("Plank_" + str(i))
		if plank and plank.visible:
			plank.visible = false
			create_plank_destruction_effect_auto_cleanup(barricade.global_position, Color(0.6, 0.4, 0.2))
	
	# ACTUALIZAR COLISIONES INMEDIATAMENTE
	update_barricade_collision_optimized(barricade)
	
	# NOTIFICAR A TODOS LOS ENEMIGOS
	if current_planks == 0:
		notify_enemies_barricade_destroyed(barricade)
	
	create_barricade_damage_sound_effect()

func repair_barricade(barricade: Node2D) -> bool:
	"""Reparar barricada y actualizar colisiones INMEDIATAMENTE"""
	var current_planks = barricade.get_meta("current_planks", 0)
	var max_planks = barricade.get_meta("max_planks", 8)
	
	if current_planks >= max_planks:
		return false
	
	var was_destroyed = (current_planks == 0)
	
	current_planks += 1
	barricade.set_meta("current_planks", current_planks)
	
	var plank = barricade.get_node_or_null("Plank_" + str(current_planks - 1))
	if plank:
		plank.visible = true
		plank.modulate = Color(1.5, 1.5, 1.5, 1.0)
		var tween = create_tween()
		tween.tween_property(plank, "modulate", Color.WHITE, 0.3)
	
	# ACTUALIZAR COLISIONES INMEDIATAMENTE
	update_barricade_collision_optimized(barricade)
	
	# Si se reparó desde 0, notificar a enemigos
	if was_destroyed:
		notify_enemies_barricade_repaired(barricade)
	
	create_repair_effect_auto_cleanup(barricade.global_position)
	return true

func create_plank_destruction_effect_auto_cleanup(pos: Vector2, plank_color: Color):
	"""Crear efecto de destrucción que se limpia automáticamente"""
	for i in range(3):
		var debris = Sprite2D.new()
		var debris_size = randi_range(4, 8)
		var debris_image = Image.create(debris_size, debris_size, false, Image.FORMAT_RGBA8)
		debris_image.fill(plank_color.darkened(0.3))
		debris.texture = ImageTexture.create_from_image(debris_image)
		debris.global_position = pos + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		get_tree().current_scene.add_child(debris)
		
		# ANIMACIÓN QUE SE LIMPIA AUTOMÁTICAMENTE
		var cleanup_tween = create_tween()
		cleanup_tween.parallel().tween_property(debris, "modulate:a", 0.0, 1.0)  # Más rápido
		cleanup_tween.parallel().tween_property(debris, "global_position", 
			debris.global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40)), 1.0)
		cleanup_tween.parallel().tween_property(debris, "rotation_degrees", randf_range(-180, 180), 1.0)
		# LIMPIEZA AUTOMÁTICA GARANTIZADA
		cleanup_tween.tween_callback(func():
			if is_instance_valid(debris):
				debris.queue_free()
		)

func create_repair_effect_auto_cleanup(pos: Vector2):
	"""Crear efecto visual de reparación que se limpia automáticamente"""
	for i in range(4):
		var spark = Sprite2D.new()
		var spark_image = Image.create(6, 6, false, Image.FORMAT_RGBA8)
		spark_image.fill(Color.CYAN)
		spark.texture = ImageTexture.create_from_image(spark_image)
		spark.global_position = pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		get_tree().current_scene.add_child(spark)
		
		# LIMPIEZA AUTOMÁTICA GARANTIZADA
		var cleanup_tween = create_tween()
		cleanup_tween.parallel().tween_property(spark, "modulate:a", 0.0, 0.6)
		cleanup_tween.parallel().tween_property(spark, "global_position", 
			spark.global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30)), 0.6)
		cleanup_tween.tween_callback(func():
			if is_instance_valid(spark):
				spark.queue_free()
		)

func notify_enemies_barricade_destroyed(barricade: Node2D):
	"""Notificar a los enemigos que una barricada fue destruida"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		# Si el enemigo estaba atacando esta barricada, que continúe al jugador
		if "target_barricade" in enemy and enemy.target_barricade == barricade:
			if "current_state" in enemy:
				enemy.current_state = 0  # MOVING_TO_PLAYER
			enemy.target_barricade = null
			if "is_attacking_barricade" in enemy:
				enemy.is_attacking_barricade = false

func notify_enemies_barricade_repaired(barricade: Node2D):
	"""Notificar a los enemigos que una barricada fue reparada"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		# Forzar a los enemigos cercanos a recalcular su ruta
		var distance = enemy.global_position.distance_to(barricade.global_position)
		if distance < 200.0:
			if "path_check_timer" in enemy:
				enemy.path_check_timer = 0.0  # Forzar verificación inmediata

func create_walls_with_vertical_door_gap(room_center: Vector2, room_size: Vector2, wall_thickness: float):
	var north_barricades = [
		Vector2(room_center.x - 250, room_center.y - room_size.y/2 - wall_thickness/2),
		Vector2(room_center.x + 250, room_center.y - room_size.y/2 - wall_thickness/2)
	]
	var south_barricades = [
		Vector2(room_center.x - 250, room_center.y + room_size.y/2 + wall_thickness/2),
		Vector2(room_center.x + 250, room_center.y + room_size.y/2 + wall_thickness/2)
	]
	var east_barricades = [
		Vector2(room_center.x + room_size.x/2 + wall_thickness/2, room_center.y)
	]
	# SIN barricadas en pared oeste (izquierda)
	var west_barricades = []
	
	var barricade_size = 300
	var vertical_door_size = 180
	
	# PARED NORTE
	create_wall_segments_with_gaps(
		Vector2(room_center.x, room_center.y - room_size.y/2 - wall_thickness/2),
		Vector2(room_size.x + wall_thickness*2, wall_thickness),
		north_barricades, barricade_size, true
	)
	
	# PARED SUR
	create_wall_segments_with_gaps(
		Vector2(room_center.x, room_center.y + room_size.y/2 + wall_thickness/2),
		Vector2(room_size.x + wall_thickness*2, wall_thickness),
		south_barricades, barricade_size, true
	)
	
	# PARED ESTE
	create_wall_segments_with_gaps(
		Vector2(room_center.x + room_size.x/2 + wall_thickness/2, room_center.y),
		Vector2(wall_thickness, room_size.y + wall_thickness*2),
		east_barricades, barricade_size, false
	)
	
	# PARED OESTE CON HUECO VERTICAL PARA PUERTA (SIN BARRICADAS)
	create_wall_segments_with_gaps_and_vertical_door_fixed(
		Vector2(room_center.x - room_size.x/2 - wall_thickness/2, room_center.y),
		Vector2(wall_thickness, room_size.y + wall_thickness*2),
		west_barricades, barricade_size,
		Vector2(room_center.x - room_size.x/2 - wall_thickness/2, room_center.y),
		vertical_door_size, false
	)

func create_wall_segments_with_gaps_and_vertical_door_fixed(center_pos: Vector2, total_size: Vector2, _gap_positions: Array, _gap_size: float, door_pos: Vector2, door_gap_size: float, is_horizontal: bool):
	if not is_horizontal:  # Pared vertical (oeste)
		var start_y = center_pos.y - total_size.y/2
		var end_y = center_pos.y + total_size.y/2
		
		# Puerta en el centro
		var door_start = door_pos.y - door_gap_size/2
		var door_end = door_pos.y + door_gap_size/2
		
		# Segmento superior
		if door_start > start_y:
			var segment_height = door_start - start_y
			var segment_center = Vector2(center_pos.x, start_y + segment_height/2)
			create_enhanced_solid_wall(segment_center, Vector2(total_size.x, segment_height))
		
		# Segmento inferior
		if end_y > door_end:
			var segment_height = end_y - door_end
			var segment_center = Vector2(center_pos.x, door_end + segment_height/2)
			create_enhanced_solid_wall(segment_center, Vector2(total_size.x, segment_height))

func create_wall_segments_with_gaps(center_pos: Vector2, total_size: Vector2, gap_positions: Array, gap_size: float, is_horizontal: bool):
	if is_horizontal:
		var start_x = center_pos.x - total_size.x/2
		var end_x = center_pos.x + total_size.x/2
		var current_x = start_x
		
		var sorted_gaps = gap_positions.duplicate()
		sorted_gaps.sort_custom(func(a, b): return a.x < b.x)
		
		for gap_pos in sorted_gaps:
			var gap_start = gap_pos.x - gap_size/2
			var gap_end = gap_pos.x + gap_size/2
			
			if current_x < gap_start:
				var segment_width = gap_start - current_x
				var segment_center = Vector2(current_x + segment_width/2, center_pos.y)
				create_enhanced_solid_wall(segment_center, Vector2(segment_width, total_size.y))
			
			current_x = gap_end
		
		if current_x < end_x:
			var segment_width = end_x - current_x
			var segment_center = Vector2(current_x + segment_width/2, center_pos.y)
			create_enhanced_solid_wall(segment_center, Vector2(segment_width, total_size.y))
	
	else:  # Vertical
		var start_y = center_pos.y - total_size.y/2
		var end_y = center_pos.y + total_size.y/2
		var current_y = start_y
		
		var sorted_gaps = gap_positions.duplicate()
		sorted_gaps.sort_custom(func(a, b): return a.y < b.y)
		
		for gap_pos in sorted_gaps:
			var gap_start = gap_pos.y - gap_size/2
			var gap_end = gap_pos.y + gap_size/2
			
			if current_y < gap_start:
				var segment_height = gap_start - current_y
				var segment_center = Vector2(center_pos.x, current_y + segment_height/2)
				create_enhanced_solid_wall(segment_center, Vector2(total_size.x, segment_height))
			
			current_y = gap_end
		
		if current_y < end_y:
			var segment_height = end_y - current_y
			var segment_center = Vector2(center_pos.x, current_y + segment_height/2)
			create_enhanced_solid_wall(segment_center, Vector2(total_size.x, segment_height))

func create_enhanced_solid_wall(wall_pos: Vector2, wall_size: Vector2) -> StaticBody2D:
	"""Crear pared sólida con sprites mejorados"""
	var wall = StaticBody2D.new()
	wall.name = "SolidWall_" + str(solid_walls.size())
	wall.position = wall_pos
	wall.collision_layer = 3  # Bloquea a jugador Y enemigos SIEMPRE
	wall.collision_mask = 0
	
	var collision_shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = wall_size
	collision_shape.shape = rect_shape
	wall.add_child(collision_shape)
	
	# Sprite mejorado de pared tipo piedra/concreto
	var sprite = create_enhanced_wall_sprite(wall_size)
	wall.add_child(sprite)
	
	add_child(wall)
	solid_walls.append(wall)
	return wall

func create_enhanced_wall_sprite(wall_size: Vector2) -> Control:
	"""Crear sprite mejorado para paredes"""
	var sprite_container = Control.new()
	sprite_container.size = wall_size
	sprite_container.position = Vector2(-wall_size.x/2, -wall_size.y/2)
	
	# Crear imagen de pared tipo piedra
	var wall_image = Image.create(int(wall_size.x), int(wall_size.y), false, Image.FORMAT_RGBA8)
	
	# Color base gris piedra
	var base_color = Color(0.35, 0.35, 0.4, 1.0)
	wall_image.fill(base_color)
	
	# Añadir textura de piedra
	for x in range(int(wall_size.x)):
		for y in range(int(wall_size.y)):
			# Bloques de piedra
			var block_x = int(x / 40) * 40
			var block_y = int(y / 30) * 30
			
			# Variación de color por bloque
			var block_variation = sin(block_x * 0.1) * cos(block_y * 0.1) * 0.1
			var stone_color = base_color.lightened(block_variation)
			
			# Bordes de bloques más oscuros
			if x % 40 < 2 or y % 30 < 2:
				stone_color = base_color.darkened(0.2)
			
			# Musgo ocasional
			if (x + y) % 47 == 0:
				stone_color = Color(0.2, 0.4, 0.2, 1.0)
			
			wall_image.set_pixel(x, y, stone_color)
	
	var wall_texture = ImageTexture.create_from_image(wall_image)
	
	var wall_rect = TextureRect.new()
	wall_rect.texture = wall_texture
	wall_rect.size = wall_size
	sprite_container.add_child(wall_rect)
	
	return sprite_container

func create_large_door_1x3(door_pos: Vector2):
	var door_size_1x3 = Vector2(60, 180)
	create_purchasable_door(door_pos, door_size_1x3, 3000, "área_exterior")

func create_purchasable_door(door_pos: Vector2, door_size: Vector2, cost: int, target_room: String) -> Node2D:
	var door = Node2D.new()
	door.name = "Door_" + target_room
	door.position = door_pos
	
	door.set_meta("cost", cost)
	door.set_meta("target_room", target_room)
	door.set_meta("is_open", false)
	door.set_meta("size", door_size)
	
	var static_body = StaticBody2D.new()
	static_body.name = "DoorBody"
	static_body.collision_layer = 3
	static_body.collision_mask = 0
	
	var collision_shape = CollisionShape2D.new()
	collision_shape.name = "DoorCollision"
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = door_size
	collision_shape.shape = rect_shape
	static_body.add_child(collision_shape)
	door.add_child(static_body)
	
	# Sprite de puerta mejorado
	var sprite = create_enhanced_door_sprite(door_size)
	door.add_child(sprite)
	
	var interaction_area = Area2D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 16
	interaction_area.collision_mask = 1
	
	var interaction_shape = CollisionShape2D.new()
	var interaction_rect = RectangleShape2D.new()
	interaction_rect.size = door_size * 2.5
	interaction_shape.shape = interaction_rect
	interaction_area.add_child(interaction_shape)
	door.add_child(interaction_area)
	
	interaction_area.body_entered.connect(_on_door_interaction_entered.bind(door))
	interaction_area.body_exited.connect(_on_door_interaction_exited.bind(door))
	
	add_child(door)
	doors.append(door)
	return door

func create_enhanced_door_sprite(door_size: Vector2) -> Control:
	"""Crear sprite mejorado para puertas"""
	var sprite_container = Control.new()
	sprite_container.name = "DoorSprite"
	sprite_container.size = door_size
	sprite_container.position = Vector2(-door_size.x/2, -door_size.y/2)
	
	# Crear imagen de puerta metálica
	var door_image = Image.create(int(door_size.x), int(door_size.y), false, Image.FORMAT_RGBA8)
	
	# Color base metálico
	var base_color = Color(0.3, 0.3, 0.35, 1.0)
	door_image.fill(base_color)
	
	# Añadir detalles de puerta metálica
	for x in range(int(door_size.x)):
		for y in range(int(door_size.y)):
			# Paneles metálicos
			var panel_factor = 0.0
			if x % 15 < 2 or y % 20 < 2:
				panel_factor = 0.1  # Líneas de paneles
			
			# Remaches
			if (x - 5) % 20 == 0 and (y - 10) % 30 == 0:
				panel_factor = -0.2  # Remaches oscuros
			
			# Color final
			var final_color = base_color.lightened(panel_factor)
			door_image.set_pixel(x, y, final_color)
	
	var door_texture = ImageTexture.create_from_image(door_image)
	
	var door_rect = TextureRect.new()
	door_rect.texture = door_texture
	door_rect.size = door_size
	sprite_container.add_child(door_rect)
	
	return sprite_container

func purchase_door(door: Node2D) -> bool:
	"""Comprar puerta"""
	var is_open = door.get_meta("is_open", false)
	if is_open:
		return false
	
	door.set_meta("is_open", true)
	
	var collision = door.get_node_or_null("DoorBody/DoorCollision")
	if collision:
		collision.disabled = true
	
	var sprite = door.get_node_or_null("DoorSprite")
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
		tween.tween_property(sprite, "scale", Vector2.ZERO, 0.5)
	
	hide_door_speech_bubble()
	return true

func _on_barricade_interaction_entered(barricade: Node2D, body: Node2D):
	if body.name == "Player" or body is Player:
		var current_planks = barricade.get_meta("current_planks", 0)
		var max_planks = barricade.get_meta("max_planks", 8)
		if current_planks < max_planks:
			show_repair_prompt(barricade)

func _on_barricade_interaction_exited(_barricade: Node2D, body: Node2D):
	if body.name == "Player" or body is Player:
		hide_interaction_prompt()

func _on_door_interaction_entered(door: Node2D, body: Node2D):
	if body.name == "Player" or body is Player:
		var is_open = door.get_meta("is_open", false)
		if not is_open:
			show_door_speech_bubble_improved(door)

func _on_door_interaction_exited(_door: Node2D, body: Node2D):
	if body.name == "Player" or body is Player:
		hide_door_speech_bubble()

func show_door_speech_bubble_improved(door: Node2D):
	if not player_ref:
		return
	
	hide_door_speech_bubble()
	
	var cost = door.get_meta("cost", 3000)
	var target_room = door.get_meta("target_room", "área exterior")
	
	current_door_prompt = Control.new()
	current_door_prompt.name = "DoorSpeechBubble"
	current_door_prompt.z_index = 1000
	
	var bubble_panel = Panel.new()
	bubble_panel.size = Vector2(280, 80)
	bubble_panel.position = Vector2(-140, -120)
	
	var bubble_style = StyleBoxFlat.new()
	bubble_style.bg_color = Color(0.05, 0.05, 0.15, 0.95)
	bubble_style.border_color = Color.GOLD
	bubble_style.border_width_left = 3
	bubble_style.border_width_right = 3
	bubble_style.border_width_top = 3
	bubble_style.border_width_bottom = 3
	bubble_style.corner_radius_top_left = 15
	bubble_style.corner_radius_top_right = 15
	bubble_style.corner_radius_bottom_left = 15
	bubble_style.corner_radius_bottom_right = 15
	bubble_panel.add_theme_stylebox_override("panel", bubble_style)
	current_door_prompt.add_child(bubble_panel)
	
	var text_label = Label.new()
	text_label.text = "💰 ABRIR " + target_room.to_upper() + "\n🪙 " + str(cost) + " PUNTOS"
	text_label.add_theme_font_size_override("font_size", 16)
	text_label.add_theme_color_override("font_color", Color.GOLD)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bubble_panel.add_child(text_label)
	
	player_ref.add_child(current_door_prompt)

func hide_door_speech_bubble():
	if current_door_prompt and is_instance_valid(current_door_prompt):
		current_door_prompt.queue_free()
		current_door_prompt = null

func show_repair_prompt(barricade: Node2D):
	if not player_ref:
		return
	
	hide_interaction_prompt()
	
	var cost = barricade.get_meta("repair_cost", 10)
	var current_planks = barricade.get_meta("current_planks", 0)
	var max_planks = barricade.get_meta("max_planks", 8)
	var missing_planks = max_planks - current_planks
	
	current_interaction_prompt = Control.new()
	current_interaction_prompt.name = "RepairSpeechBubble"
	current_interaction_prompt.z_index = 1000
	
	var bubble_panel = Panel.new()
	bubble_panel.size = Vector2(240, 80)
	bubble_panel.position = Vector2(-120, -120)
	
	var bubble_style = StyleBoxFlat.new()
	bubble_style.bg_color = Color(0.05, 0.15, 0.05, 0.95)
	bubble_style.border_color = Color.GREEN
	bubble_style.border_width_left = 3
	bubble_style.border_width_right = 3
	bubble_style.border_width_top = 3
	bubble_style.border_width_bottom = 3
	bubble_style.corner_radius_top_left = 15
	bubble_style.corner_radius_top_right = 15
	bubble_style.corner_radius_bottom_left = 15
	bubble_style.corner_radius_bottom_right = 15
	bubble_panel.add_theme_stylebox_override("panel", bubble_style)
	current_interaction_prompt.add_child(bubble_panel)
	
	var text_label = Label.new()
	text_label.text = "🔨 REPARAR " + str(missing_planks) + " TABLONES\n💰 " + str(cost) + " PUNTOS C/U"
	text_label.add_theme_font_size_override("font_size", 14)
	text_label.add_theme_color_override("font_color", Color.GREEN)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bubble_panel.add_child(text_label)
	
	player_ref.add_child(current_interaction_prompt)

func hide_interaction_prompt():
	if current_interaction_prompt and is_instance_valid(current_interaction_prompt):
		current_interaction_prompt.queue_free()
		current_interaction_prompt = null

func create_barricade_damage_sound_effect():
	"""Crear efecto sonoro de daño a barricada"""
	pass

func get_barricades_in_range(pos: Vector2, range_distance: float) -> Array[Node2D]:
	"""Obtener barricadas en rango"""
	var nearby_barricades: Array[Node2D] = []
	
	for barricade in barricades:
		if is_instance_valid(barricade):
			var distance = pos.distance_to(barricade.global_position)
			if distance <= range_distance:
				var current_planks = barricade.get_meta("current_planks", 0)
				if current_planks > 0:
					nearby_barricades.append(barricade)
	
	return nearby_barricades

func get_all_walls() -> Array[StaticBody2D]:
	return solid_walls

func get_all_barricades() -> Array[Node2D]:
	return barricades

func get_all_doors() -> Array[Node2D]:
	return doors

# === FUNCIONES DE DEBUG ===

func debug_barricade_collisions():
	"""Función de debug para verificar colisiones de barricadas"""
	
	for i in range(barricades.size()):
		var barricade = barricades[i]
		if not is_instance_valid(barricade):
			continue
		
		var _current_planks = barricade.get_meta("current_planks", 0)
		var collision_body = barricade.get_node_or_null("BarricadeBody/BarricadeCollision")
		var player_wall = barricade.get_node_or_null("PlayerWall/PlayerWallCollision")
		
		if collision_body:
			var parent_body = collision_body.get_parent() as StaticBody2D
			var _layer = parent_body.collision_layer if parent_body else 0
			var _disabled = collision_body.disabled
			
		else:
			print("Barricada ", i, ": ❌ SIN COLISIÓN")
		
		if player_wall:
			var player_body = player_wall.get_parent() as StaticBody2D
			var _player_layer = player_body.collision_layer if player_body else 0
			var _player_disabled = player_wall.disabled


func force_update_all_barricades():
	"""Forzar actualización de todas las barricadas"""
	
	for barricade in barricades:
		if is_instance_valid(barricade):
			update_barricade_collision_optimized(barricade)
