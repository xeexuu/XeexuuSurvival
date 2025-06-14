# scenes/ui/MobileMenuButton.gd
extends Control
class_name MobileMenuButton

signal menu_pressed

func _ready():
	# MOSTRAR SIEMPRE EL BOTÓN PARA TESTING, INDEPENDIENTE DE LA PLATAFORMA
	visible = true
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	setup_enhanced_button()

func setup_enhanced_button():
	# Posición en esquina superior derecha con mejor margen
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	size = Vector2(100, 100)  # Más grande para mejor visibilidad
	position = Vector2(-120, 25)  # Más margen del borde
	
	# Crear botón más grande y visible
	var button = Button.new()
	button.text = "☰"  # Icono de menú hamburguesa
	button.size = Vector2(100, 100)
	button.add_theme_font_size_override("font_size", 40)  # Icono más grande
	
	# Estilo mejorado y más visible
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.2, 0.2, 0.3, 0.95)  # Más opaco
	style_normal.border_color = Color(0.6, 0.8, 1.0, 1.0)
	style_normal.border_width_left = 4
	style_normal.border_width_right = 4
	style_normal.border_width_top = 4
	style_normal.border_width_bottom = 4
	style_normal.corner_radius_top_left = 50
	style_normal.corner_radius_top_right = 50
	style_normal.corner_radius_bottom_left = 50
	style_normal.corner_radius_bottom_right = 50
	button.add_theme_stylebox_override("normal", style_normal)
	
	# Estilo cuando se presiona
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.4, 0.4, 0.5, 1.0)
	style_pressed.border_color = Color(0.8, 1.0, 1.0, 1.0)
	style_pressed.border_width_left = 4
	style_pressed.border_width_right = 4
	style_pressed.border_width_top = 4
	style_pressed.border_width_bottom = 4
	style_pressed.corner_radius_top_left = 50
	style_pressed.corner_radius_top_right = 50
	style_pressed.corner_radius_bottom_left = 50
	style_pressed.corner_radius_bottom_right = 50
	button.add_theme_stylebox_override("pressed", style_pressed)
	
	# Estilo hover
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.3, 0.3, 0.4, 0.98)
	style_hover.border_color = Color(0.7, 0.9, 1.0, 1.0)
	style_hover.border_width_left = 4
	style_hover.border_width_right = 4
	style_hover.border_width_top = 4
	style_hover.border_width_bottom = 4
	style_hover.corner_radius_top_left = 50
	style_hover.corner_radius_top_right = 50
	style_hover.corner_radius_bottom_left = 50
	style_hover.corner_radius_bottom_right = 50
	button.add_theme_stylebox_override("hover", style_hover)
	
	# Color del texto más visible
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.CYAN)
	button.add_theme_color_override("font_hover_color", Color.LIGHT_GRAY)
	
	# Añadir sombra al texto para mejor legibilidad
	button.add_theme_color_override("font_shadow_color", Color.BLACK)
	button.add_theme_constant_override("shadow_offset_x", 3)
	button.add_theme_constant_override("shadow_offset_y", 3)
	
	add_child(button)
	button.pressed.connect(_on_button_pressed)
	
	# Efecto visual de feedback táctil
	button.button_down.connect(_on_button_down)
	button.button_up.connect(_on_button_up)
	
	# DEBUG: Imprimir para verificar que se crea
	print("🎮 MobileMenuButton creado y configurado")

func _on_button_down():
	# Pequeña animación cuando se presiona
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.1)

func _on_button_up():
	# Volver al tamaño normal
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

func _on_button_pressed():
	print("🎮 Botón de menú móvil presionado")
	menu_pressed.emit()
	
	# Efecto visual adicional cuando se presiona
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
