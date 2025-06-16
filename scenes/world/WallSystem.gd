# scenes/world/WallSystem.gd - SOLO PAREDES DEL PERÍMETRO
extends Node2D
class_name WallSystem

var walls: Array[StaticBody2D] = []

func _ready():
	create_boundary_walls()
	# ELIMINADO: create_interior_walls() - No más muros interiores

func create_boundary_walls():
	"""Crear SOLO paredes del perímetro del mapa"""
	var map_size = 1600
	var wall_thickness = 50
	var half_size = map_size / 2
	
	# Pared superior
	create_wall(Vector2(0, -half_size - wall_thickness/2), Vector2(map_size, wall_thickness))
	
	# Pared inferior
	create_wall(Vector2(0, half_size + wall_thickness/2), Vector2(map_size, wall_thickness))
	
	# Pared izquierda
	create_wall(Vector2(-half_size - wall_thickness/2, 0), Vector2(wall_thickness, map_size))
	
	# Pared derecha
	create_wall(Vector2(half_size + wall_thickness/2, 0), Vector2(wall_thickness, map_size))

func create_wall(position: Vector2, size: Vector2) -> StaticBody2D:
	"""Crear una pared individual"""
	var wall = StaticBody2D.new()
	wall.name = "Wall_" + str(walls.size())
	wall.position = position
	
	# Configurar capas de colisión
	wall.collision_layer = 3  # Capa para paredes
	wall.collision_mask = 0   # Las paredes no necesitan detectar nada
	
	# Crear forma de colisión
	var collision_shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = size
	collision_shape.shape = rect_shape
	wall.add_child(collision_shape)
	
	# Crear sprite visual - MÁS SUTIL
	var sprite = ColorRect.new()
	sprite.size = size
	sprite.position = Vector2(-size.x/2, -size.y/2)
	sprite.color = Color(0.3, 0.2, 0.1, 0.6)  # Color marrón más sutil
	
	# Agregar borde más sutil
	var border_style = StyleBoxFlat.new()
	border_style.bg_color = Color(0.3, 0.2, 0.1, 0.6)
	border_style.border_color = Color(0.1, 0.05, 0.0, 0.8)
	border_style.border_width_left = 1
	border_style.border_width_right = 1
	border_style.border_width_top = 1
	border_style.border_width_bottom = 1
	sprite.add_theme_stylebox_override("panel", border_style)
	
	wall.add_child(sprite)
	add_child(wall)
	walls.append(wall)
	
	return wall

func add_custom_wall(position: Vector2, size: Vector2) -> StaticBody2D:
	"""Agregar una pared personalizada en tiempo de ejecución"""
	return create_wall(position, size)

func remove_wall(wall: StaticBody2D):
	"""Remover una pared"""
	if wall in walls:
		walls.erase(wall)
		wall.queue_free()

func get_all_walls() -> Array[StaticBody2D]:
	"""Obtener todas las paredes"""
	return walls
