# scenes/world/WallSystem.gd - SISTEMA DE PAREDES Y BARRICADAS COD ZOMBIES
extends Node2D
class_name WallSystem

var solid_walls: Array[StaticBody2D] = []
var penetrable_walls: Array[Area2D] = []
var barricades: Array[Node2D] = []
var doors: Array[Node2D] = []

# Texturas de paredes
var brick_texture: Texture2D
var wood_texture: Texture2D
var door_texture: Texture2D

func _ready():
	create_wall_textures()
	create_level_layout()

func create_wall_textures():
	"""Crear texturas de paredes con sprites distintivos"""
	brick_texture = create_brick_texture()
	wood_texture = create_wood_texture()
	door_texture = create_door_texture()

func create_brick_texture() -> Texture2D:
	"""Crear textura de ladrillo realista"""
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	
	# Color base de ladrillo
	var brick_color = Color(0.7, 0.4, 0.2, 1.0)
	var mortar_color = Color(0.8, 0.8, 0.7, 1.0)
	
	image.fill(brick_color)
	
	# Patrón de ladrillos
	for row in range(4):  # 4 filas de ladrillos
		var y_start = row * 16
		var y_end = y_start + 16
		var offset = 0 if row % 2 == 0 else 16  # Alternar offset
		
		# Líneas horizontales (mortero)
		for x in range(64):
			for y in range(y_start, min(y_start + 2, 64)):
				image.set_pixel(x, y, mortar_color)
			for y in range(max(y_end - 2, 0), min(y_end, 64)):
				image.set_pixel(x, y, mortar_color)
		
		# Líneas verticales (mortero entre ladrillos)
		for brick in range(3):  # 3 ladrillos por fila
			var x_pos = (brick * 21 + offset) % 64
			for x in range(max(x_pos - 1, 0), min(x_pos + 1, 64)):
				for y in range(y_start, min(y_end, 64)):
					image.set_pixel(x, y, mortar_color)
	
	# Añadir variación de color a los ladrillos
	for x in range(64):
		for y in range(64):
			if image.get_pixel(x, y).is_equal_approx(brick_color):
				var variation = randf_range(-0.1, 0.1)
				var varied_color = Color(
					brick_color.r + variation,
					brick_color.g + variation,
					brick_color.b + variation,
					1.0
				)
				image.set_pixel(x, y, varied_color)
	
	return ImageTexture.create_from_image(image)

func create_wood_texture() -> Texture2D:
	"""Crear textura de madera para barricadas"""
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	
	var wood_color = Color(0.6, 0.4, 0.2, 1.0)
	var dark_wood = Color(0.4, 0.2, 0.1, 1.0)
	
	image.fill(wood_color)
	
	# Vetas de madera horizontales
	for y in range(64):
		if y % 8 == 0 or y % 8 == 1:
			for x in range(64):
				image.set_pixel(x, y, dark_wood)
	
	# Nudos de madera
	var knot_positions = [Vector2(20, 15), Vector2(45, 35), Vector2(15, 50)]
	for knot_pos in knot_positions:
		for x in range(knot_pos.x - 3, knot_pos.x + 3):
			for y in range(knot_pos.y - 2, knot_pos.y + 2):
				if x >= 0 and x < 64 and y >= 0 and y < 64:
					image.set_pixel(x, y, dark_wood)
	
	return ImageTexture.create_from_image(image)

func create_door_texture() -> Texture2D:
	"""Crear textura de puerta metálica"""
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	
	var metal_color = Color(0.6, 0.6, 0.7, 1.0)
	var dark_metal = Color(0.3, 0.3, 0.4, 1.0)
	var rust_color = Color(0.8, 0.4, 0.2, 1.0)
	
	image.fill(metal_color)
	
	# Paneles de la puerta
	for panel in range(3):
		var y_start = panel * 20 + 2
		var y_end = y_start + 16
		
		# Bordes del panel
		for x in range(4, 60):
			image.set_pixel(x, y_start, dark_metal)
			image.set_pixel(x, y_end, dark_metal)
		
		for y in range(y_start, y_end):
			image.set_pixel(4, y, dark_metal)
			image.set_pixel(59, y, dark_metal)
	
	# Manilla de la puerta
	for x in range(50, 56):
		for y in range(28, 34):
			image.set_pixel(x, y, Color.GOLD)
	
	# Manchas de óxido
	var rust_spots = [Vector2(10, 45), Vector2(35, 15), Vector2(55, 50)]
	for rust_pos in rust_spots:
		for x in range(rust_pos.x - 2, rust_pos.x + 2):
			for y in range(rust_pos.y - 2, rust_pos.y + 2):
				if x >= 0 and x < 64 and y >= 0 and y < 64:
					image.set_pixel(x, y, rust_color)
	
	return ImageTexture.create_from_image(image)

func create_level_layout():
	"""Crear diseño de nivel estilo COD Zombies"""
	create_main_room()
	create_side_rooms()
	create_barricades()
	create_doors_between_rooms()

func create_main_room():
	"""Crear sala principal en el centro"""
	var room_center = Vector2(0, 0)
	var room_size = Vector2(400, 300)
	
	# Paredes exteriores de la sala principal
	create_solid_wall(Vector2(room_center.x, room_center.y - room_size.y/2 - 25), Vector2(room_size.x, 50))  # Norte
	create_solid_wall(Vector2(room_center.x, room_center.y + room_size.y/2 + 25), Vector2(room_size.x, 50))  # Sur
	create_solid_wall(Vector2(room_center.x - room_size.x/2 - 25, room_center.y), Vector2(50, room_size.y))  # Oeste
	create_solid_wall(Vector2(room_center.x + room_size.x/2 + 25, room_center.y), Vector2(50, room_size.y))  # Este

func create_side_rooms():
	"""Crear salas laterales"""
	# Sala norte
	create_room_at_position(Vector2(0, -400), Vector2(300, 200), "north_room")
	
	# Sala sur
	create_room_at_position(Vector2(0, 400), Vector2(300, 200), "south_room")
	
	# Sala este
	create_room_at_position(Vector2(500, 0), Vector2(200, 250), "east_room")
	
	# Sala oeste
	create_room_at_position(Vector2(-500, 0), Vector2(200, 250), "west_room")

func create_room_at_position(center: Vector2, size: Vector2, room_name: String):
	"""Crear una sala en una posición específica"""
	# Paredes de la sala
	create_solid_wall(Vector2(center.x, center.y - size.y/2 - 25), Vector2(size.x, 50))  # Norte
	create_solid_wall(Vector2(center.x, center.y + size.y/2 + 25), Vector2(size.x, 50))  # Sur
	create_solid_wall(Vector2(center.x - size.x/2 - 25, center.y), Vector2(50, size.y))  # Oeste
	create_solid_wall(Vector2(center.x + size.x/2 + 25, center.y), Vector2(50, size.y))  # Este
	
	# Paredes penetrables internas (decorativas)
	if room_name != "main_room":
		create_penetrable_wall(Vector2(center.x + size.x/4, center.y), Vector2(20, size.y/2))

func create_barricades():
	"""Crear barricadas estilo COD Zombies"""
	# Barricadas en la sala principal (ventanas)
	create_barricade(Vector2(-150, -175), Vector2(100, 30), 3)  # Norte-oeste
	create_barricade(Vector2(150, -175), Vector2(100, 30), 3)   # Norte-este
	create_barricade(Vector2(-150, 175), Vector2(100, 30), 3)   # Sur-oeste
	create_barricade(Vector2(150, 175), Vector2(100, 30), 3)    # Sur-este
	
	# Barricadas en salas laterales
	create_barricade(Vector2(-100, -400), Vector2(80, 25), 2)   # Sala norte
	create_barricade(Vector2(100, 400), Vector2(80, 25), 2)     # Sala sur
	create_barricade(Vector2(500, -80), Vector2(25, 80), 2)     # Sala este
	create_barricade(Vector2(-500, 80), Vector2(25, 80), 2)     # Sala oeste

func create_doors_between_rooms():
	"""Crear puertas entre salas que se pueden comprar"""
	# Puerta hacia sala norte
	create_purchasable_door(Vector2(0, -200), Vector2(80, 50), 750, "north_room")
	
	# Puerta hacia sala sur  
	create_purchasable_door(Vector2(0, 200), Vector2(80, 50), 750, "south_room")
	
	# Puerta hacia sala este
	create_purchasable_door(Vector2(275, 0), Vector2(50, 80), 1000, "east_room")
	
	# Puerta hacia sala oeste
	create_purchasable_door(Vector2(-275, 0), Vector2(50, 80), 1000, "west_room")

func create_solid_wall(wall_position: Vector2, wall_size: Vector2) -> StaticBody2D:
	"""Crear pared sólida con sprite de ladrillo"""
	var wall = StaticBody2D.new()
	wall.name = "SolidWall_" + str(solid_walls.size())
	wall.position = wall_position
	
	wall.collision_layer = 3
	wall.collision_mask = 0
	
	var collision_shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = wall_size
	collision_shape.shape = rect_shape
	wall.add_child(collision_shape)
	
	# Sprite visual con textura de ladrillo
	var sprite = Sprite2D.new()
	sprite.texture = brick_texture
	sprite.scale = Vector2(wall_size.x / 64.0, wall_size.y / 64.0)
	wall.add_child(sprite)
	
	add_child(wall)
	solid_walls.append(wall)
	
	return wall

func create_penetrable_wall(wall_position: Vector2, wall_size: Vector2) -> Area2D:
	"""Crear pared que enemigos pueden atravesar pero jugador no"""
	var wall = Area2D.new()
	wall.name = "PenetrableWall_" + str(penetrable_walls.size())
	wall.position = wall_position
	
	# Solo colisiona con el jugador (capa 1)
	wall.collision_layer = 8  # Nueva capa para paredes penetrables
	wall.collision_mask = 1   # Solo detecta al jugador
	
	var collision_shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = wall_size
	collision_shape.shape = rect_shape
	wall.add_child(collision_shape)
	
	# Sprite visual diferente (madera vieja)
	var sprite = Sprite2D.new()
	sprite.texture = wood_texture
	sprite.modulate = Color(0.8, 0.8, 0.8, 0.7)  # Semi-transparente
	sprite.scale = Vector2(wall_size.x / 64.0, wall_size.y / 64.0)
	wall.add_child(sprite)
	
	# Conectar señal para bloquear al jugador
	wall.body_entered.connect(_on_penetrable_wall_entered)
	
	add_child(wall)
	penetrable_walls.append(wall)
	
	return wall

func create_barricade(barricade_position: Vector2, barricade_size: Vector2, max_planks: int) -> Node2D:
	"""Crear barricada estilo COD Zombies con tablones"""
	var barricade = Node2D.new()
	barricade.name = "Barricade_" + str(barricades.size())
	barricade.position = barricade_position
	
	# Propiedades de la barricada
	barricade.set_meta("max_planks", max_planks)
	barricade.set_meta("current_planks", max_planks)
	barricade.set_meta("size", barricade_size)
	barricade.set_meta("repair_cost", 10)  # Puntos por reparar
	
	# Crear collision dinámico
	var static_body = StaticBody2D.new()
	static_body.name = "BarricadeBody"
	static_body.collision_layer = 3
	static_body.collision_mask = 0
	
	var collision_shape = CollisionShape2D.new()
	collision_shape.name = "BarricadeCollision"
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = barricade_size
	collision_shape.shape = rect_shape
	static_body.add_child(collision_shape)
	barricade.add_child(static_body)
	
	# Crear tablones visuales
	for i in range(max_planks):
		create_plank_sprite(barricade, i, barricade_size)
	
	# Área de interacción para reparar
	var interaction_area = Area2D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 16  # Capa de interacción
	interaction_area.collision_mask = 1    # Detecta al jugador
	
	var interaction_shape = CollisionShape2D.new()
	var interaction_rect = RectangleShape2D.new()
	interaction_rect.size = barricade_size * 1.5  # Área más grande para interactuar
	interaction_shape.shape = interaction_rect
	interaction_area.add_child(interaction_shape)
	barricade.add_child(interaction_area)
	
	# Conectar señales
	interaction_area.body_entered.connect(_on_barricade_interaction_entered.bind(barricade))
	interaction_area.body_exited.connect(_on_barricade_interaction_exited.bind(barricade))
	
	add_child(barricade)
	barricades.append(barricade)
	
	return barricade

func create_plank_sprite(barricade: Node2D, plank_index: int, barricade_size: Vector2):
	"""Crear sprite de tablón individual"""
	var plank = Sprite2D.new()
	plank.name = "Plank_" + str(plank_index)
	plank.texture = wood_texture
	
	# Posición del tablón
	var plank_height = barricade_size.y / 3.0
	var plank_width = barricade_size.x * 0.8
	
	plank.scale = Vector2(plank_width / 64.0, plank_height / 64.0)
	plank.position.y = (plank_index - 1) * (plank_height * 0.8)
	
	# Rotación ligera para aspecto natural
	plank.rotation = deg_to_rad(randf_range(-5, 5))
	
	# Color variado
	plank.modulate = Color(
		randf_range(0.6, 0.8),
		randf_range(0.4, 0.6),
		randf_range(0.2, 0.4),
		1.0
	)
	
	barricade.add_child(plank)

func create_purchasable_door(door_position: Vector2, door_size: Vector2, cost: int, target_room: String) -> Node2D:
	"""Crear puerta que se puede comprar para abrir"""
	var door = Node2D.new()
	door.name = "Door_" + target_room
	door.position = door_position
	
	# Propiedades de la puerta
	door.set_meta("cost", cost)
	door.set_meta("target_room", target_room)
	door.set_meta("is_open", false)
	door.set_meta("size", door_size)
	
	# Collision que se puede quitar
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
	
	# Sprite de puerta
	var sprite = Sprite2D.new()
	sprite.name = "DoorSprite"
	sprite.texture = door_texture
	sprite.scale = Vector2(door_size.x / 64.0, door_size.y / 64.0)
	door.add_child(sprite)
	
	# Área de interacción
	var interaction_area = Area2D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 16
	interaction_area.collision_mask = 1
	
	var interaction_shape = CollisionShape2D.new()
	var interaction_rect = RectangleShape2D.new()
	interaction_rect.size = door_size * 1.5
	interaction_shape.shape = interaction_rect
	interaction_area.add_child(interaction_shape)
	door.add_child(interaction_area)
	
	# Conectar señales
	interaction_area.body_entered.connect(_on_door_interaction_entered.bind(door))
	interaction_area.body_exited.connect(_on_door_interaction_exited.bind(door))
	
	# Texto de costo
	var cost_label = Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = "COMPRAR PUERTA\n" + str(cost) + " PUNTOS"
	cost_label.add_theme_font_size_override("font_size", 20)
	cost_label.add_theme_color_override("font_color", Color.YELLOW)
	cost_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	cost_label.add_theme_constant_override("shadow_offset_x", 2)
	cost_label.add_theme_constant_override("shadow_offset_y", 2)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.position = Vector2(-60, -door_size.y/2 - 40)
	cost_label.size = Vector2(120, 30)
	cost_label.visible = false
	door.add_child(cost_label)
	
	add_child(door)
	doors.append(door)
	
	return door

func _on_penetrable_wall_entered(body: Node2D):
	"""Bloquear al jugador en paredes penetrables"""
	if body.name == "Player":
		# Empujar al jugador fuera
		var wall_area = body.get_overlapping_areas()[0]  # Asumir que es la pared
		var push_direction = (body.global_position - wall_area.global_position).normalized()
		if body.has_method("apply_knockback"):
			body.apply_knockback(push_direction, 200.0)

func _on_barricade_interaction_entered(barricade: Node2D, body: Node2D):
	"""Jugador cerca de barricada - mostrar opción de reparar"""
	if body.name == "Player":
		var current_planks = barricade.get_meta("current_planks", 0)
		var max_planks = barricade.get_meta("max_planks", 3)
		
		if current_planks < max_planks:
			show_repair_prompt(barricade)

func _on_barricade_interaction_exited(barricade: Node2D, body: Node2D):
	"""Jugador se aleja de barricada"""
	if body.name == "Player":
		hide_repair_prompt(barricade)

func _on_door_interaction_entered(door: Node2D, body: Node2D):
	"""Jugador cerca de puerta - mostrar opción de comprar"""
	if body.name == "Player":
		var is_open = door.get_meta("is_open", false)
		if not is_open:
			show_door_prompt(door)

func _on_door_interaction_exited(door: Node2D, body: Node2D):
	"""Jugador se aleja de puerta"""
	if body.name == "Player":
		hide_door_prompt(door)

func show_repair_prompt(barricade: Node2D):
	"""Mostrar prompt de reparación"""
	var cost = barricade.get_meta("repair_cost", 10)
	# TODO: Mostrar UI de interacción
	print("Presiona F para reparar barricada (", cost, " puntos)")

func hide_repair_prompt(barricade: Node2D):
	"""Ocultar prompt de reparación"""
	# TODO: Ocultar UI de interacción
	pass

func show_door_prompt(door: Node2D):
	"""Mostrar prompt de compra de puerta"""
	var cost_label = door.get_node("CostLabel")
	if cost_label:
		cost_label.visible = true

func hide_door_prompt(door: Node2D):
	"""Ocultar prompt de compra de puerta"""
	var cost_label = door.get_node("CostLabel")
	if cost_label:
		cost_label.visible = false

func repair_barricade(barricade: Node2D) -> bool:
	"""Reparar barricada si el jugador tiene puntos"""
	var current_planks = barricade.get_meta("current_planks", 0)
	var max_planks = barricade.get_meta("max_planks", 3)
	var cost = barricade.get_meta("repair_cost", 10)
	
	if current_planks >= max_planks:
		return false
	
	# TODO: Verificar puntos del jugador
	# if player_score < cost: return false
	
	# Añadir tablón
	current_planks += 1
	barricade.set_meta("current_planks", current_planks)
	
	# Hacer visible el tablón
	var plank = barricade.get_node("Plank_" + str(current_planks - 1))
	if plank:
		plank.visible = true
	
	# Actualizar colisión si está completamente reparada
	if current_planks >= max_planks:
		var collision = barricade.get_node("BarricadeBody/BarricadeCollision")
		if collision:
			collision.disabled = false
	
	return true

func damage_barricade(barricade: Node2D, damage_amount: int = 1):
	"""Dañar barricada (enemigos la rompen)"""
	var current_planks = barricade.get_meta("current_planks", 0)
	
	current_planks = max(0, current_planks - damage_amount)
	barricade.set_meta("current_planks", current_planks)
	
	# Ocultar tablones dañados
	for i in range(current_planks, barricade.get_meta("max_planks", 3)):
		var plank = barricade.get_node("Plank_" + str(i))
		if plank:
			plank.visible = false
	
	# Deshabilitar colisión si está destruida
	if current_planks <= 0:
		var collision = barricade.get_node("BarricadeBody/BarricadeCollision")
		if collision:
			collision.disabled = true

func purchase_door(door: Node2D) -> bool:
	"""Comprar y abrir puerta"""
	var cost = door.get_meta("cost", 750)
	var is_open = door.get_meta("is_open", false)
	
	if is_open:
		return false
	
	# TODO: Verificar puntos del jugador
	# if player_score < cost: return false
	
	# Abrir puerta
	door.set_meta("is_open", true)
	
	# Remover colisión
	var collision = door.get_node("DoorBody/DoorCollision")
	if collision:
		collision.disabled = true
	
	# Animar apertura
	var sprite = door.get_node("DoorSprite")
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
		tween.tween_property(sprite, "scale", Vector2.ZERO, 0.5)
	
	# Ocultar texto de costo
	hide_door_prompt(door)
	
	return true

func get_barricades_in_range(position: Vector2, range_distance: float) -> Array[Node2D]:
	"""Obtener barricadas en rango para que enemigos las ataquen"""
	var nearby_barricades: Array[Node2D] = []
	
	for barricade in barricades:
		if is_instance_valid(barricade):
			var distance = position.distance_to(barricade.global_position)
			if distance <= range_distance:
				var current_planks = barricade.get_meta("current_planks", 0)
				if current_planks > 0:  # Solo barricadas con tablones
					nearby_barricades.append(barricade)
	
	return nearby_barricades

func get_all_walls() -> Array[StaticBody2D]:
	"""Obtener todas las paredes sólidas"""
	return solid_walls

func get_all_penetrable_walls() -> Array[Area2D]:
	"""Obtener todas las paredes penetrables"""
	return penetrable_walls

func get_all_barricades() -> Array[Node2D]:
	"""Obtener todas las barricadas"""
	return barricades

func get_all_doors() -> Array[Node2D]:
	"""Obtener todas las puertas"""
	return doors
