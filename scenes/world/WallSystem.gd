# scenes/world/WallSystem.gd - CORREGIDO: tablones penetrables + habitación gigante + bocadillos mejorados
extends Node2D
class_name WallSystem

var solid_walls: Array[StaticBody2D] = []
var penetrable_walls: Array[Area2D] = []
var barricades: Array[Node2D] = []
var doors: Array[Node2D] = []

# Referencias a jugador para bocadillos MEJORADOS
var player_ref: Player
var current_door_prompt: Control
var current_interaction_prompt: Control

# Texturas de paredes
var brick_texture: Texture2D
var wood_texture: Texture2D
var door_texture: Texture2D

func _ready():
	create_wall_textures()
	create_giant_room_with_penetrable_barricades()  # NUEVA FUNCIÓN
	call_deferred("get_player_reference")

func get_player_reference():
	"""Obtener referencia al jugador"""
	await get_tree().create_timer(1.0).timeout
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.player:
		player_ref = game_manager.player
		print("✅ Player reference obtenida en WallSystem")

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

func create_giant_room_with_penetrable_barricades():
	"""Crear HABITACIÓN GIGANTE sin paredes sólidas donde hay tablones"""
	var room_center = Vector2(0, 0)
	var room_size = Vector2(1600, 1200)  # HABITACIÓN GIGANTE (antes 800x600)
	var wall_thickness = 60  # PAREDES MÁS GRUESAS
	
	print("🏠 Creando habitación gigante de ", room_size, " con centro en ", room_center)
	
	# PAREDES EXTERIORES SÓLIDAS (sin huecos donde van las barricadas)
	create_walls_with_barricade_gaps(room_center, room_size, wall_thickness)
	
	# BARRICADAS PENETRABLES EN VENTANAS (sin paredes sólidas debajo)
	create_penetrable_barricades_only(room_center, room_size, wall_thickness)
	
	# PUERTA CARA EN LA PARED OESTE
	create_expensive_door(Vector2(room_center.x - room_size.x/2 - wall_thickness/2, room_center.y), Vector2(120, 150))

func create_walls_with_barricade_gaps(room_center: Vector2, room_size: Vector2, wall_thickness: float):
	"""Crear paredes sólidas CON HUECOS donde van las barricadas"""
	
	# POSICIONES DE LAS BARRICADAS (para crear huecos)
	var barricade_positions = [
		# Pared Norte
		Vector2(room_center.x - 400, room_center.y - room_size.y/2 - wall_thickness/2),
		Vector2(room_center.x, room_center.y - room_size.y/2 - wall_thickness/2),
		Vector2(room_center.x + 400, room_center.y - room_size.y/2 - wall_thickness/2),
		
		# Pared Sur
		Vector2(room_center.x - 400, room_center.y + room_size.y/2 + wall_thickness/2),
		Vector2(room_center.x, room_center.y + room_size.y/2 + wall_thickness/2),
		Vector2(room_center.x + 400, room_center.y + room_size.y/2 + wall_thickness/2),
		
		# Pared Este
		Vector2(room_center.x + room_size.x/2 + wall_thickness/2, room_center.y - 300),
		Vector2(room_center.x + room_size.x/2 + wall_thickness/2, room_center.y + 300),
		
		# Pared Oeste (evitando la puerta)
		Vector2(room_center.x - room_size.x/2 - wall_thickness/2, room_center.y - 400),
		Vector2(room_center.x - room_size.x/2 - wall_thickness/2, room_center.y + 400)
	]
	
	var barricade_size = 160  # Tamaño del hueco para barricada
	
	# PARED NORTE - CON HUECOS
	create_wall_segments_with_gaps(
		Vector2(room_center.x, room_center.y - room_size.y/2 - wall_thickness/2),
		Vector2(room_size.x + wall_thickness*2, wall_thickness),
		barricade_positions.slice(0, 3),
		barricade_size,
		true  # horizontal
	)
	
	# PARED SUR - CON HUECOS
	create_wall_segments_with_gaps(
		Vector2(room_center.x, room_center.y + room_size.y/2 + wall_thickness/2),
		Vector2(room_size.x + wall_thickness*2, wall_thickness),
		barricade_positions.slice(3, 6),
		barricade_size,
		true  # horizontal
	)
	
	# PARED ESTE - CON HUECOS
	create_wall_segments_with_gaps(
		Vector2(room_center.x + room_size.x/2 + wall_thickness/2, room_center.y),
		Vector2(wall_thickness, room_size.y + wall_thickness*2),
		barricade_positions.slice(6, 8),
		barricade_size,
		false  # vertical
	)
	
	# PARED OESTE - CON HUECOS Y HUECO PARA PUERTA
	var west_barricades = barricade_positions.slice(8, 10)
	create_wall_segments_with_gaps_and_door(
		Vector2(room_center.x - room_size.x/2 - wall_thickness/2, room_center.y),
		Vector2(wall_thickness, room_size.y + wall_thickness*2),
		west_barricades,
		barricade_size,
		Vector2(room_center.x - room_size.x/2 - wall_thickness/2, room_center.y),  # posición puerta
		150,  # tamaño hueco puerta
		false  # vertical
	)

func create_wall_segments_with_gaps(center_pos: Vector2, total_size: Vector2, gap_positions: Array, gap_size: float, is_horizontal: bool):
	"""Crear segmentos de pared con huecos para barricadas"""
	
	if is_horizontal:
		# Pared horizontal
		var start_x = center_pos.x - total_size.x/2
		var end_x = center_pos.x + total_size.x/2
		var current_x = start_x
		
		for gap_pos in gap_positions:
			var gap_start = gap_pos.x - gap_size/2
			var gap_end = gap_pos.x + gap_size/2
			
			# Crear segmento antes del hueco
			if current_x < gap_start:
				var segment_width = gap_start - current_x
				var segment_center = Vector2(current_x + segment_width/2, center_pos.y)
				create_solid_wall(segment_center, Vector2(segment_width, total_size.y))
			
			current_x = gap_end
		
		# Crear segmento final
		if current_x < end_x:
			var segment_width = end_x - current_x
			var segment_center = Vector2(current_x + segment_width/2, center_pos.y)
			create_solid_wall(segment_center, Vector2(segment_width, total_size.y))
	
	else:
		# Pared vertical
		var start_y = center_pos.y - total_size.y/2
		var end_y = center_pos.y + total_size.y/2
		var current_y = start_y
		
		for gap_pos in gap_positions:
			var gap_start = gap_pos.y - gap_size/2
			var gap_end = gap_pos.y + gap_size/2
			
			# Crear segmento antes del hueco
			if current_y < gap_start:
				var segment_height = gap_start - current_y
				var segment_center = Vector2(center_pos.x, current_y + segment_height/2)
				create_solid_wall(segment_center, Vector2(total_size.x, segment_height))
			
			current_y = gap_end
		
		# Crear segmento final
		if current_y < end_y:
			var segment_height = end_y - current_y
			var segment_center = Vector2(center_pos.x, current_y + segment_height/2)
			create_solid_wall(segment_center, Vector2(total_size.x, segment_height))

func create_wall_segments_with_gaps_and_door(center_pos: Vector2, total_size: Vector2, gap_positions: Array, gap_size: float, door_pos: Vector2, door_gap_size: float, is_horizontal: bool):
	"""Crear segmentos de pared con huecos para barricadas Y hueco para puerta"""
	
	# Añadir la posición de la puerta a los huecos
	var all_gaps = gap_positions.duplicate()
	all_gaps.append(door_pos)
	
	# Ordenar los huecos por posición
	if is_horizontal:
		all_gaps.sort_custom(func(a, b): return a.x < b.x)
	else:
		all_gaps.sort_custom(func(a, b): return a.y < b.y)
	
	if is_horizontal:
		# Pared horizontal
		var start_x = center_pos.x - total_size.x/2
		var end_x = center_pos.x + total_size.x/2
		var current_x = start_x
		
		for gap_pos in all_gaps:
			var gap_size_to_use = door_gap_size if gap_pos == door_pos else gap_size
			var gap_start = gap_pos.x - gap_size_to_use/2
			var gap_end = gap_pos.x + gap_size_to_use/2
			
			# Crear segmento antes del hueco
			if current_x < gap_start:
				var segment_width = gap_start - current_x
				var segment_center = Vector2(current_x + segment_width/2, center_pos.y)
				create_solid_wall(segment_center, Vector2(segment_width, total_size.y))
			
			current_x = gap_end
		
		# Crear segmento final
		if current_x < end_x:
			var segment_width = end_x - current_x
			var segment_center = Vector2(current_x + segment_width/2, center_pos.y)
			create_solid_wall(segment_center, Vector2(segment_width, total_size.y))
	
	else:
		# Pared vertical
		var start_y = center_pos.y - total_size.y/2
		var end_y = center_pos.y + total_size.y/2
		var current_y = start_y
		
		for gap_pos in all_gaps:
			var gap_size_to_use = door_gap_size if gap_pos == door_pos else gap_size
			var gap_start = gap_pos.y - gap_size_to_use/2
			var gap_end = gap_pos.y + gap_size_to_use/2
			
			# Crear segmento antes del hueco
			if current_y < gap_start:
				var segment_height = gap_start - current_y
				var segment_center = Vector2(center_pos.x, current_y + segment_height/2)
				create_solid_wall(segment_center, Vector2(total_size.x, segment_height))
			
			current_y = gap_end
		
		# Crear segmento final
		if current_y < end_y:
			var segment_height = end_y - current_y
			var segment_center = Vector2(center_pos.x, current_y + segment_height/2)
			create_solid_wall(segment_center, Vector2(total_size.x, segment_height))

func create_penetrable_barricades_only(room_center: Vector2, room_size: Vector2, wall_thickness: float):
	"""Crear SOLO barricadas penetrables en las ventanas - SIN PAREDES SÓLIDAS DEBAJO"""
	
	print("🪟 Creando barricadas penetrables en ventanas...")
	
	# BARRICADAS EN PARED NORTE (3 ventanas)
	create_penetrable_barricade(Vector2(room_center.x - 400, room_center.y - room_size.y/2 - wall_thickness/2), Vector2(140, wall_thickness), 8)
	create_penetrable_barricade(Vector2(room_center.x, room_center.y - room_size.y/2 - wall_thickness/2), Vector2(140, wall_thickness), 8)
	create_penetrable_barricade(Vector2(room_center.x + 400, room_center.y - room_size.y/2 - wall_thickness/2), Vector2(140, wall_thickness), 8)
	
	# BARRICADAS EN PARED SUR (3 ventanas)
	create_penetrable_barricade(Vector2(room_center.x - 400, room_center.y + room_size.y/2 + wall_thickness/2), Vector2(140, wall_thickness), 8)
	create_penetrable_barricade(Vector2(room_center.x, room_center.y + room_size.y/2 + wall_thickness/2), Vector2(140, wall_thickness), 8)
	create_penetrable_barricade(Vector2(room_center.x + 400, room_center.y + room_size.y/2 + wall_thickness/2), Vector2(140, wall_thickness), 8)
	
	# BARRICADAS EN PARED ESTE (2 ventanas)
	create_penetrable_barricade(Vector2(room_center.x + room_size.x/2 + wall_thickness/2, room_center.y - 300), Vector2(wall_thickness, 140), 8)
	create_penetrable_barricade(Vector2(room_center.x + room_size.x/2 + wall_thickness/2, room_center.y + 300), Vector2(wall_thickness, 140), 8)
	
	# BARRICADAS EN PARED OESTE (2 ventanas, evitando la puerta)
	create_penetrable_barricade(Vector2(room_center.x - room_size.x/2 - wall_thickness/2, room_center.y - 400), Vector2(wall_thickness, 120), 8)
	create_penetrable_barricade(Vector2(room_center.x - room_size.x/2 - wall_thickness/2, room_center.y + 400), Vector2(wall_thickness, 120), 8)

func create_penetrable_barricade(barricade_pos: Vector2, barricade_size: Vector2, max_planks: int) -> Node2D:
	"""Crear barricada COMPLETAMENTE PENETRABLE - las balas SIEMPRE pasan"""
	var barricade = Node2D.new()
	barricade.name = "Barricade_" + str(barricades.size())
	barricade.position = barricade_pos
	
	# Propiedades de la barricada
	barricade.set_meta("max_planks", max_planks)
	barricade.set_meta("current_planks", max_planks)
	barricade.set_meta("size", barricade_size)
	barricade.set_meta("repair_cost", 10)
	barricade.set_meta("is_penetrable", true)  # SIEMPRE PENETRABLE
	
	# NOTA: NO hay StaticBody2D aquí - las barricadas son SIEMPRE penetrables
	# Los enemigos pueden ser bloqueados por otras mecánicas, pero las balas siempre pasan
	
	# Crear tablones visuales
	for i in range(max_planks):
		create_plank_sprite(barricade, i, barricade_size, max_planks)
	
	# Área de interacción para reparar
	var interaction_area = Area2D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 16  # Capa de interacción
	interaction_area.collision_mask = 1    # Detecta al jugador
	
	var interaction_shape = CollisionShape2D.new()
	var interaction_rect = RectangleShape2D.new()
	interaction_rect.size = barricade_size * 2.0  # Área más grande para interactuar
	interaction_shape.shape = interaction_rect
	interaction_area.add_child(interaction_shape)
	barricade.add_child(interaction_area)
	
	# Conectar señales
	interaction_area.body_entered.connect(_on_barricade_interaction_entered.bind(barricade))
	interaction_area.body_exited.connect(_on_barricade_interaction_exited.bind(barricade))
	
	add_child(barricade)
	barricades.append(barricade)
	
	print("🪟 Barricada penetrable creada en ", barricade_pos, " con ", max_planks, " tablones")
	
	return barricade

func create_expensive_door(door_pos: Vector2, door_size: Vector2):
	"""Crear puerta cara de 3000 puntos"""
	create_purchasable_door(door_pos, door_size, 3000, "área_exterior")

func create_solid_wall(wall_pos: Vector2, wall_size: Vector2) -> StaticBody2D:
	"""Crear pared sólida con sprite de ladrillo - LAS BALAS NO PUEDEN ATRAVESAR"""
	var wall = StaticBody2D.new()
	wall.name = "SolidWall_" + str(solid_walls.size())
	wall.position = wall_pos
	
	# CONFIGURACIÓN DE COLISIÓN PARA BLOQUEAR BALAS Y ENTIDADES
	wall.collision_layer = 3  # Capa 3 para paredes sólidas
	wall.collision_mask = 0   # No necesita detectar nada
	
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
	
	print("🧱 Pared sólida creada en ", wall_pos, " de tamaño ", wall_size)
	
	return wall

func create_plank_sprite(barricade: Node2D, plank_index: int, barricade_size: Vector2, total_planks: int):
	"""Crear sprite de tablón individual"""
	var plank = Sprite2D.new()
	plank.name = "Plank_" + str(plank_index)
	plank.texture = wood_texture
	
	# Distribución de tablones según orientación
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

func create_purchasable_door(door_pos: Vector2, door_size: Vector2, cost: int, target_room: String) -> Node2D:
	"""Crear puerta que se puede comprar para abrir"""
	var door = Node2D.new()
	door.name = "Door_" + target_room
	door.position = door_pos
	
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
	
	# Área de interacción MÁS GRANDE
	var interaction_area = Area2D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 16
	interaction_area.collision_mask = 1
	
	var interaction_shape = CollisionShape2D.new()
	var interaction_rect = RectangleShape2D.new()
	interaction_rect.size = door_size * 3.0  # ÁREA MÁS GRANDE
	interaction_shape.shape = interaction_rect
	interaction_area.add_child(interaction_shape)
	door.add_child(interaction_area)
	
	# Conectar señales
	interaction_area.body_entered.connect(_on_door_interaction_entered.bind(door))
	interaction_area.body_exited.connect(_on_door_interaction_exited.bind(door))
	
	add_child(door)
	doors.append(door)
	
	print("🚪 Puerta creada en ", door_pos, " - Costo: ", cost, " puntos")
	
	return door

# RESTO DE FUNCIONES SIN CAMBIOS IMPORTANTES...

func _on_barricade_interaction_entered(barricade: Node2D, body: Node2D):
	"""Jugador cerca de barricada - mostrar opción de reparar"""
	if body.name == "Player" or body is Player:
		var current_planks = barricade.get_meta("current_planks", 0)
		var max_planks = barricade.get_meta("max_planks", 8)
		
		if current_planks < max_planks:
			show_repair_prompt(barricade)

func _on_barricade_interaction_exited(barricade: Node2D, body: Node2D):
	"""Jugador se aleja de barricada"""
	if body.name == "Player" or body is Player:
		hide_interaction_prompt()

func _on_door_interaction_entered(door: Node2D, body: Node2D):
	"""Jugador cerca de puerta - MOSTRAR BOCADILLO MEJORADO"""
	if body.name == "Player" or body is Player:
		var is_open = door.get_meta("is_open", false)
		if not is_open:
			show_door_speech_bubble_improved(door)

func _on_door_interaction_exited(door: Node2D, body: Node2D):
	"""Jugador se aleja de puerta - OCULTAR BOCADILLO"""
	if body.name == "Player" or body is Player:
		hide_door_speech_bubble()

func show_door_speech_bubble_improved(door: Node2D):
	"""BOCADILLO MEJORADO sobre la cabeza del jugador con precio más visible"""
	if not player_ref:
		print("❌ No hay player_ref para mostrar bocadillo")
		return
	
	hide_door_speech_bubble()  # Ocultar cualquier bocadillo previo
	
	var cost = door.get_meta("cost", 3000)
	var target_room = door.get_meta("target_room", "área exterior")
	
	# Crear bocadillo MÁS GRANDE
	current_door_prompt = Control.new()
	current_door_prompt.name = "DoorSpeechBubble"
	current_door_prompt.z_index = 1000
	
	# Panel del bocadillo MÁS GRANDE
	var bubble_panel = Panel.new()
	bubble_panel.size = Vector2(320, 120)  # MÁS GRANDE
	bubble_panel.position = Vector2(-160, -160)  # MÁS ARRIBA sobre el jugador
	
	var bubble_style = StyleBoxFlat.new()
	bubble_style.bg_color = Color(0.05, 0.05, 0.15, 0.95)  # MÁS OPACO
	bubble_style.border_color = Color.GOLD  # DORADO para dinero
	bubble_style.border_width_left = 4  # BORDE MÁS GRUESO
	bubble_style.border_width_right = 4
	bubble_style.border_width_top = 4
	bubble_style.border_width_bottom = 4
	bubble_style.corner_radius_top_left = 20
	bubble_style.corner_radius_top_right = 20
	bubble_style.corner_radius_bottom_left = 20
	bubble_style.corner_radius_bottom_right = 20
	bubble_panel.add_theme_stylebox_override("panel", bubble_style)
	current_door_prompt.add_child(bubble_panel)
	
	# Texto del bocadillo MEJORADO
	var text_label = Label.new()
	text_label.text = "💰 ABRIR " + target_room.to_upper() + "\n🪙 " + str(cost) + " PUNTOS\n💲 [E / $ para comprar]"
	text_label.add_theme_font_size_override("font_size", 18)  # FUENTE MÁS GRANDE
	text_label.add_theme_color_override("font_color", Color.GOLD)  # DORADO
	text_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	text_label.add_theme_constant_override("shadow_offset_x", 3)
	text_label.add_theme_constant_override("shadow_offset_y", 3)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text_label.add_theme_constant_override("margin_left", 15)
	text_label.add_theme_constant_override("margin_right", 15)
	text_label.add_theme_constant_override("margin_top", 10)
	text_label.add_theme_constant_override("margin_bottom", 10)
	bubble_panel.add_child(text_label)
	
	# Punta del bocadillo MÁS GRANDE
	var triangle = Polygon2D.new()
	triangle.polygon = PackedVector2Array([
		Vector2(-15, 0),  # MÁS GRANDE
		Vector2(15, 0),
		Vector2(0, 20)
	])
	triangle.color = Color(0.05, 0.05, 0.15, 0.95)
	triangle.position = Vector2(0, -40)  # Debajo del panel
	current_door_prompt.add_child(triangle)
	
	# Añadir al jugador
	player_ref.add_child(current_door_prompt)
	
	# Animación de aparición MÁS LLAMATIVA
	current_door_prompt.modulate = Color.TRANSPARENT
	current_door_prompt.scale = Vector2(0.5, 0.5)
	var tween = create_tween()
	tween.parallel().tween_property(current_door_prompt, "modulate", Color.WHITE, 0.3)
	tween.parallel().tween_property(current_door_prompt, "scale", Vector2(1.0, 1.0), 0.3)
	
	print("✅ Bocadillo de puerta MEJORADO mostrado - Costo: ", cost, " puntos")

func hide_door_speech_bubble():
	"""Ocultar bocadillo de diálogo"""
	if current_door_prompt and is_instance_valid(current_door_prompt):
		var tween = create_tween()
		tween.parallel().tween_property(current_door_prompt, "modulate", Color.TRANSPARENT, 0.2)
		tween.parallel().tween_property(current_door_prompt, "scale", Vector2(0.5, 0.5), 0.2)
		tween.tween_callback(func(): 
			if current_door_prompt and is_instance_valid(current_door_prompt):
				current_door_prompt.queue_free()
		)
		current_door_prompt = null

func show_repair_prompt(barricade: Node2D):
	"""Mostrar prompt de reparación con bocadillo"""
	if not player_ref:
		return
	
	hide_interaction_prompt()
	
	var cost = barricade.get_meta("repair_cost", 10)
	
	current_interaction_prompt = Control.new()
	current_interaction_prompt.name = "RepairSpeechBubble"
	current_interaction_prompt.z_index = 1000
	
	# Panel del bocadillo
	var bubble_panel = Panel.new()
	bubble_panel.size = Vector2(240, 100)
	bubble_panel.position = Vector2(-120, -140)
	
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
	
	# Texto del bocadillo
	var text_label = Label.new()
	text_label.text = "🔨 REPARAR TABLONES\n💰 " + str(cost) + " PUNTOS\n[E / $ para reparar]"
	text_label.add_theme_font_size_override("font_size", 16)
	text_label.add_theme_color_override("font_color", Color.GREEN)
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
	
	# Punta del bocadillo
	var triangle = Polygon2D.new()
	triangle.polygon = PackedVector2Array([
		Vector2(-10, 0),
		Vector2(10, 0),
		Vector2(0, 15)
	])
	triangle.color = Color(0.05, 0.15, 0.05, 0.95)
	triangle.position = Vector2(0, -40)
	current_interaction_prompt.add_child(triangle)
	
	# Añadir al jugador
	player_ref.add_child(current_interaction_prompt)
	
	# Animación de aparición
	current_interaction_prompt.modulate = Color.TRANSPARENT
	var tween = create_tween()
	tween.tween_property(current_interaction_prompt, "modulate", Color.WHITE, 0.3)

func hide_interaction_prompt():
	"""Ocultar prompt de interacción"""
	if current_interaction_prompt and is_instance_valid(current_interaction_prompt):
		var tween = create_tween()
		tween.tween_property(current_interaction_prompt, "modulate", Color.TRANSPARENT, 0.2)
		tween.tween_callback(func(): 
			if current_interaction_prompt and is_instance_valid(current_interaction_prompt):
				current_interaction_prompt.queue_free()
		)
		current_interaction_prompt = null

func repair_barricade(barricade: Node2D) -> bool:
	"""Reparar barricada si el jugador tiene puntos"""
	var current_planks = barricade.get_meta("current_planks", 0)
	var max_planks = barricade.get_meta("max_planks", 8)
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
	
	print("🔨 Barricada reparada - Tablones: ", current_planks, "/", max_planks)
	
	return true

func damage_barricade(barricade: Node2D, damage_amount: int = 1):
	"""Dañar barricada (enemigos la rompen) - PENETRABLE SIEMPRE"""
	if not is_instance_valid(barricade):
		return
		
	var current_planks = barricade.get_meta("current_planks", 0)
	var max_planks = barricade.get_meta("max_planks", 8)
	
	current_planks = max(0, current_planks - damage_amount)
	barricade.set_meta("current_planks", current_planks)
	
	# Ocultar tablones dañados
	for i in range(current_planks, max_planks):
		var plank = barricade.get_node_or_null("Plank_" + str(i))
		if plank:
			plank.visible = false
			
			# Efecto de tablón roto
			create_plank_break_effect(barricade.global_position)
	
	print("💥 Barricada dañada - Tablones restantes: ", current_planks, "/", max_planks)

func create_plank_break_effect(effect_pos: Vector2):
	"""Crear efecto visual de tablón roto"""
	for i in range(4):
		var particle = Sprite2D.new()
		var particle_image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		particle_image.fill(Color.BROWN)
		particle.texture = ImageTexture.create_from_image(particle_image)
		particle.global_position = effect_pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		get_tree().current_scene.add_child(particle)
		
		var tween = create_tween()
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 1.0)
		tween.parallel().tween_property(particle, "global_position", 
			particle.global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30)), 1.0)
		tween.tween_callback(func(): particle.queue_free())

func purchase_door(door: Node2D) -> bool:
	"""Comprar y abrir puerta"""
	var cost = door.get_meta("cost", 3000)
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
	
	print("🚪 Puerta abierta: ", door.get_meta("target_room", "área exterior"))
	
	return true

func get_barricades_in_range(pos: Vector2, range_distance: float) -> Array[Node2D]:
	"""Obtener barricadas en rango para que enemigos las ataquen"""
	var nearby_barricades: Array[Node2D] = []
	
	for barricade in barricades:
		if is_instance_valid(barricade):
			var distance = pos.distance_to(barricade.global_position)
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

func can_player_interact() -> Node2D:
	"""Verificar si el jugador puede interactuar con algo"""
	if current_door_prompt:
		# Buscar la puerta asociada
		for door in doors:
			if not door.get_meta("is_open", false):
				return door
	
	if current_interaction_prompt:
		# Buscar la barricada asociada
		for barricade in barricades:
			var current_planks = barricade.get_meta("current_planks", 0)
			var max_planks = barricade.get_meta("max_planks", 8)
			if current_planks < max_planks:
				return barricade
	
	return null
