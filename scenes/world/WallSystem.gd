# scenes/world/WallSystem.gd - SISTEMA COD ZOMBIES CON HABITACIONES GRANDES
extends Node2D
class_name WallSystem

var solid_walls: Array[StaticBody2D] = []
var penetrable_walls: Array[Area2D] = []
var barricades: Array[Node2D] = []
var doors: Array[Node2D] = []

# Referencias a jugador para bocadillos
var player_ref: Player
var current_door_prompt: Control

# Texturas de paredes
var brick_texture: Texture2D
var wood_texture: Texture2D
var door_texture: Texture2D

func _ready():
	create_wall_textures()
	create_cod_level_layout()
	get_player_reference()

func get_player_reference():
	"""Obtener referencia al jugador"""
	await get_tree().create_timer(1.0).timeout
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.player:
		player_ref = game_manager.player

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
	
	return ImageTexture.create_from_image(image)

func create_door_texture() -> Texture2D:
	"""Crear textura de puerta metálica"""
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	
	var metal_color = Color(0.6, 0.6, 0.7, 1.0)
	var dark_metal = Color(0.3, 0.3, 0.4, 1.0)
	
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
	
	return ImageTexture.create_from_image(image)

func create_cod_level_layout():
	"""Crear diseño de nivel estilo COD Zombies CON HABITACIONES GRANDES"""
	create_main_spawn_room()
	create_large_side_rooms()
	create_window_barricades()
	create_large_connecting_doors()

func create_main_spawn_room():
	"""Crear sala principal de spawn GRANDE"""
	var room_center = Vector2(0, 0)
	var room_size = Vector2(600, 450)  # MÁS GRANDE
	
	# Paredes exteriores de la sala principal
	create_solid_wall(Vector2(room_center.x, room_center.y - room_size.y/2 - 30), Vector2(room_size.x + 60, 60))  # Norte
	create_solid_wall(Vector2(room_center.x, room_center.y + room_size.y/2 + 30), Vector2(room_size.x + 60, 60))  # Sur
	create_solid_wall(Vector2(room_center.x - room_size.x/2 - 30, room_center.y), Vector2(60, room_size.y))  # Oeste
	create_solid_wall(Vector2(room_center.x + room_size.x/2 + 30, room_center.y), Vector2(60, room_size.y))  # Este

func create_large_side_rooms():
	"""Crear salas laterales GRANDES estilo COD"""
	# Sala norte GRANDE
	create_large_room_at_position(Vector2(0, -550), Vector2(500, 350), "north_room")
	
	# Sala sur GRANDE
	create_large_room_at_position(Vector2(0, 550), Vector2(500, 350), "south_room")
	
	# Sala este GRANDE
	create_large_room_at_position(Vector2(700, 0), Vector2(400, 450), "east_room")
	
	# Sala oeste GRANDE
	create_large_room_at_position(Vector2(-700, 0), Vector2(400, 450), "west_room")
	
	# Habitación secreta superior derecha
	create_large_room_at_position(Vector2(700, -550), Vector2(300, 250), "secret_room")

func create_large_room_at_position(center: Vector2, size: Vector2, room_name: String):
	"""Crear una sala GRANDE en una posición específica"""
	# Paredes de la sala
	create_solid_wall(Vector2(center.x, center.y - size.y/2 - 30), Vector2(size.x + 60, 60))  # Norte
	create_solid_wall(Vector2(center.x, center.y + size.y/2 + 30), Vector2(size.x + 60, 60))  # Sur
	create_solid_wall(Vector2(center.x - size.x/2 - 30, center.y), Vector2(60, size.y + 60))  # Oeste
	create_solid_wall(Vector2(center.x + size.x/2 + 30, center.y), Vector2(60, size.y + 60))  # Este
	
	# Elementos decorativos internos
	if room_name != "main_room":
		# Pilar central en habitaciones grandes
		create_penetrable_wall(Vector2(center.x, center.y), Vector2(40, 40))

func create_window_barricades():
	"""Crear barricadas de ventanas estilo COD Zombies"""
	# Ventanas en la sala principal (múltiples por pared)
	create_barricade(Vector2(-200, -255), Vector2(150, 40), 6)  # Norte-oeste
	create_barricade(Vector2(0, -255), Vector2(150, 40), 6)     # Norte-centro
	create_barricade(Vector2(200, -255), Vector2(150, 40), 6)   # Norte-este
	
	create_barricade(Vector2(-200, 255), Vector2(150, 40), 6)   # Sur-oeste
	create_barricade(Vector2(200, 255), Vector2(150, 40), 6)    # Sur-este
	
	create_barricade(Vector2(-330, -100), Vector2(40, 120), 6)  # Oeste-norte
	create_barricade(Vector2(-330, 100), Vector2(40, 120), 6)   # Oeste-sur
	
	create_barricade(Vector2(330, -100), Vector2(40, 120), 6)   # Este-norte
	create_barricade(Vector2(330, 100), Vector2(40, 120), 6)    # Este-sur
	
	# Ventanas en salas laterales
	create_barricade(Vector2(-150, -550), Vector2(120, 35), 4)  # Sala norte
	create_barricade(Vector2(150, -550), Vector2(120, 35), 4)   # Sala norte
	
	create_barricade(Vector2(-150, 550), Vector2(120, 35), 4)   # Sala sur
	create_barricade(Vector2(150, 550), Vector2(120, 35), 4)    # Sala sur
	
	create_barricade(Vector2(700, -150), Vector2(35, 120), 4)   # Sala este
	create_barricade(Vector2(700, 150), Vector2(35, 120), 4)    # Sala este

func create_large_connecting_doors():
	"""Crear puertas GRANDES entre habitaciones"""
	# Puerta hacia sala norte - MÁS GRANDE
	create_purchasable_door(Vector2(0, -290), Vector2(120, 80), 750, "north_room")
	
	# Puerta hacia sala sur - MÁS GRANDE
	create_purchasable_door(Vector2(0, 290), Vector2(120, 80), 750, "south_room")
	
	# Puerta hacia sala este - MÁS GRANDE
	create_purchasable_door(Vector2(365, 0), Vector2(80, 120), 1000, "east_room")
	
	# Puerta hacia sala oeste - MÁS GRANDE
	create_purchasable_door(Vector2(-365, 0), Vector2(80, 120), 1000, "west_room")
	
	# Puerta hacia habitación secreta - MÁS CARA
	create_purchasable_door(Vector2(550, -390), Vector2(100, 100), 2500, "secret_room")

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
	"""Crear barricada estilo COD Zombies con MÁS tablones"""
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
	
	# Crear tablones visuales (MÁS tablones)
	for i in range(max_planks):
		create_plank_sprite(barricade, i, barricade_size, max_planks)
	
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

func create_plank_sprite(barricade: Node2D, plank_index: int, barricade_size: Vector2, total_planks: int):
	"""Crear sprite de tablón individual MEJORADO"""
	var plank = Sprite2D.new()
	plank.name = "Plank_" + str(plank_index)
	plank.texture = wood_texture
	
	# Distribución mejor de tablones según orientación
	var is_horizontal = barricade_size.x > barricade_size.y
	
	if is_horizontal:
		# Barricada horizontal - tablones apilados verticalmente
		var plank_height = barricade_size.y / float(total_planks)
		var plank_width = barricade_size.x * 0.9
		
		plank.scale = Vector2(plank_width / 64.0, plank_height / 64.0)
		plank.position.y = (plank_index - (total_planks - 1) * 0.5) * plank_height
	else:
		# Barricada vertical - tablones lado a lado
		var plank_width = barricade_size.x / float(total_planks)
		var plank_height = barricade_size.y * 0.9
		
		plank.scale = Vector2(plank_width / 64.0, plank_height / 64.0)
		plank.position.x = (plank_index - (total_planks - 1) * 0.5) * plank_width
	
	# Rotación ligera para aspecto natural
	plank.rotation = deg_to_rad(randf_range(-3, 3))
	
	# Color variado de madera
	plank.modulate = Color(
		randf_range(0.6, 0.9),
		randf_range(0.4, 0.7),
		randf_range(0.2, 0.5),
		1.0
	)
	
	barricade.add_child(plank)

func create_purchasable_door(door_position: Vector2, door_size: Vector2, cost: int, target_room: String) -> Node2D:
	"""Crear puerta GRANDE que se puede comprar para abrir"""
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
	
	# Sprite de puerta MÁS GRANDE
	var sprite = Sprite2D.new()
	sprite.name = "DoorSprite"
	sprite.texture = door_texture
	sprite.scale = Vector2(door_size.x / 64.0, door_size.y / 64.0)
	door.add_child(sprite)
	
	# Área de interacción MÁS GRANDE
	var interaction_area = Area2D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 16
	interaction_area.collision_mask = 1
	
	var interaction_shape = CollisionShape2D.new()
	var interaction_rect = RectangleShape2D.new()
	interaction_rect.size = door_size * 2.0  # ÁREA MÁS GRANDE
	interaction_shape.shape = interaction_rect
	interaction_area.add_child(interaction_shape)
	door.add_child(interaction_area)
	
	# Conectar señales
	interaction_area.body_entered.connect(_on_door_interaction_entered.bind(door))
	interaction_area.body_exited.connect(_on_door_interaction_exited.bind(door))
	
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
		var max_planks = barricade.get_meta("max_planks", 6)
		
		if current_planks < max_planks:
			show_repair_prompt(barricade)

func _on_barricade_interaction_exited(barricade: Node2D, body: Node2D):
	"""Jugador se aleja de barricada"""
	if body.name == "Player":
		hide_repair_prompt(barricade)

func _on_door_interaction_entered(door: Node2D, body: Node2D):
	"""Jugador cerca de puerta - MOSTRAR BOCADILLO"""
	if body.name == "Player":
		var is_open = door.get_meta("is_open", false)
		if not is_open:
			show_door_speech_bubble(door)

func _on_door_interaction_exited(door: Node2D, body: Node2D):
	"""Jugador se aleja de puerta - OCULTAR BOCADILLO"""
	if body.name == "Player":
		hide_door_speech_bubble()

func show_door_speech_bubble(door: Node2D):
	"""Mostrar bocadillo de diálogo sobre el jugador"""
	if not player_ref:
		return
	
	hide_door_speech_bubble()  # Ocultar cualquier bocadillo previo
	
	var cost = door.get_meta("cost", 750)
	var target_room = door.get_meta("target_room", "habitación")
	
	# Crear bocadillo
	current_door_prompt = Control.new()
	current_door_prompt.name = "DoorSpeechBubble"
	current_door_prompt.z_index = 1000
	
	# Panel del bocadillo
	var bubble_panel = Panel.new()
	bubble_panel.size = Vector2(200, 80)
	bubble_panel.position = Vector2(-100, -120)  # Sobre el jugador
	
	var bubble_style = StyleBoxFlat.new()
	bubble_style.bg_color = Color(0.1, 0.1, 0.2, 0.9)
	bubble_style.border_color = Color.YELLOW
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
	
	# Texto del bocadillo
	var text_label = Label.new()
	text_label.text = "ABRIR " + target_room.to_upper() + "\n" + str(cost) + " PUNTOS"
	text_label.add_theme_font_size_override("font_size", 16)
	text_label.add_theme_color_override("font_color", Color.YELLOW)
	text_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	text_label.add_theme_constant_override("shadow_offset_x", 2)
	text_label.add_theme_constant_override("shadow_offset_y", 2)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text_label.add_theme_constant_override("margin_left", 10)
	text_label.add_theme_constant_override("margin_right", 10)
	text_label.add_theme_constant_override("margin_top", 5)
	text_label.add_theme_constant_override("margin_bottom", 5)
	bubble_panel.add_child(text_label)
	
	# Punta del bocadillo (triángulo)
	var triangle = Polygon2D.new()
	triangle.polygon = PackedVector2Array([
		Vector2(-10, 0),
		Vector2(10, 0),
		Vector2(0, 15)
	])
	triangle.color = Color(0.1, 0.1, 0.2, 0.9)
	triangle.position = Vector2(0, -40)  # Debajo del panel
	current_door_prompt.add_child(triangle)
	
	# Añadir al jugador
	player_ref.add_child(current_door_prompt)
	
	# Animación de aparición
	current_door_prompt.modulate = Color.TRANSPARENT
	var tween = create_tween()
	tween.tween_property(current_door_prompt, "modulate", Color.WHITE, 0.3)

func hide_door_speech_bubble():
	"""Ocultar bocadillo de diálogo"""
	if current_door_prompt and is_instance_valid(current_door_prompt):
		var tween = create_tween()
		tween.tween_property(current_door_prompt, "modulate", Color.TRANSPARENT, 0.2)
		tween.tween_callback(func(): 
			if current_door_prompt and is_instance_valid(current_door_prompt):
				current_door_prompt.queue_free()
		)
		current_door_prompt = null

func show_repair_prompt(barricade: Node2D):
	"""Mostrar prompt de reparación"""
	var cost = barricade.get_meta("repair_cost", 10)
	print("🔨 Presiona F para reparar barricada (", cost, " puntos)")

func hide_repair_prompt(barricade: Node2D):
	"""Ocultar prompt de reparación"""
	pass

func repair_barricade(barricade: Node2D) -> bool:
	"""Reparar barricada si el jugador tiene puntos"""
	var current_planks = barricade.get_meta("current_planks", 0)
	var max_planks = barricade.get_meta("max_planks", 6)
	var cost = barricade.get_meta("repair_cost", 10)
	
	if current_planks >= max_planks:
		return false
	
	# Añadir tablón
	current_planks += 1
	barricade.set_meta("current_planks", current_planks)
	
	# Hacer visible el tablón
	var plank = barricade.get_node_or_null("Plank_" + str(current_planks - 1))
	if plank:
		plank.visible = true
	
	# Actualizar colisión si está completamente reparada
	if current_planks >= max_planks:
		var collision = barricade.get_node_or_null("BarricadeBody/BarricadeCollision")
		if collision:
			collision.disabled = false
	
	return true

func damage_barricade(barricade: Node2D, damage_amount: int = 1):
	"""Dañar barricada (enemigos la rompen) - COD STYLE"""
	if not is_instance_valid(barricade):
		return
		
	var current_planks = barricade.get_meta("current_planks", 0)
	var max_planks = barricade.get_meta("max_planks", 6)
	
	current_planks = max(0, current_planks - damage_amount)
	barricade.set_meta("current_planks", current_planks)
	
	# Ocultar tablones dañados
	for i in range(current_planks, max_planks):
		var plank = barricade.get_node_or_null("Plank_" + str(i))
		if plank:
			plank.visible = false
			
			# Efecto de tablón roto
			create_plank_break_effect(barricade.global_position)
	
	# Deshabilitar colisión si está destruida
	if current_planks <= 0:
		var collision = barricade.get_node_or_null("BarricadeBody/BarricadeCollision")
		if collision:
			collision.disabled = true
		
		print("💥 Barricada destruida!")

func create_plank_break_effect(effect_position: Vector2):
	"""Crear efecto visual de tablón roto"""
	for i in range(4):
		var particle = Sprite2D.new()
		var particle_image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		particle_image.fill(Color.BROWN)
		particle.texture = ImageTexture.create_from_image(particle_image)
		particle.global_position = effect_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		get_tree().current_scene.add_child(particle)
		
		var tween = create_tween()
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 1.0)
		tween.parallel().tween_property(particle, "global_position", 
			particle.global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30)), 1.0)
		tween.tween_callback(func(): particle.queue_free())

func purchase_door(door: Node2D) -> bool:
	"""Comprar y abrir puerta"""
	var cost = door.get_meta("cost", 750)
	var is_open = door.get_meta("is_open", false)
	
	if is_open:
		return false
	
	# Abrir puerta
	door.set_meta("is_open", true)
	
	# Remover colisión
	var collision = door.get_node_or_null("DoorBody/DoorCollision")
	if collision:
		collision.disabled = true
	
	# Animar apertura
	var sprite = door.get_node_or_null("DoorSprite")
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
		tween.tween_property(sprite, "scale", Vector2.ZERO, 0.5)
	
	# Ocultar bocadillo
	hide_door_speech_bubble()
	
	print("🚪 Puerta abierta: ", door.get_meta("target_room", "habitación"))
	
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
