# scenes/ui/MobileMenuButton.gd - CORREGIDO: función renamed para evitar shadowing
extends Control
class_name MobileMenuButton

signal menu_pressed

var menu_button: Button

func _ready():
	visible = true
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	z_index = 1000
	
	setup_enhanced_button()

func setup_enhanced_button():
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	size = Vector2(120, 120)
	position = Vector2(-140, 20)
	
	menu_button = Button.new()
	menu_button.text = "☰"
	menu_button.size = Vector2(120, 120)
	menu_button.add_theme_font_size_override("font_size", 50)
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.1, 0.1, 0.2, 0.98)
	style_normal.border_color = Color(1.0, 1.0, 1.0, 1.0)
	style_normal.border_width_left = 6
	style_normal.border_width_right = 6
	style_normal.border_width_top = 6
	style_normal.border_width_bottom = 6
	style_normal.corner_radius_top_left = 60
	style_normal.corner_radius_top_right = 60
	style_normal.corner_radius_bottom_left = 60
	style_normal.corner_radius_bottom_right = 60
	menu_button.add_theme_stylebox_override("normal", style_normal)
	
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.3, 0.3, 0.6, 1.0)
	style_pressed.border_color = Color(1.0, 1.0, 0.0, 1.0)
	style_pressed.border_width_left = 8
	style_pressed.border_width_right = 8
	style_pressed.border_width_top = 8
	style_pressed.border_width_bottom = 8
	style_pressed.corner_radius_top_left = 60
	style_pressed.corner_radius_top_right = 60
	style_pressed.corner_radius_bottom_left = 60
	style_pressed.corner_radius_bottom_right = 60
	menu_button.add_theme_stylebox_override("pressed", style_pressed)
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.2, 0.2, 0.4, 1.0)
	style_hover.border_color = Color(0.8, 0.8, 1.0, 1.0)
	style_hover.border_width_left = 6
	style_hover.border_width_right = 6
	style_hover.border_width_top = 6
	style_hover.border_width_bottom = 6
	style_hover.corner_radius_top_left = 60
	style_hover.corner_radius_top_right = 60
	style_hover.corner_radius_bottom_left = 60
	style_hover.corner_radius_bottom_right = 60
	menu_button.add_theme_stylebox_override("hover", style_hover)
	
	menu_button.add_theme_color_override("font_color", Color.WHITE)
	menu_button.add_theme_color_override("font_pressed_color", Color.YELLOW)
	menu_button.add_theme_color_override("font_hover_color", Color.CYAN)
	
	menu_button.add_theme_color_override("font_shadow_color", Color.BLACK)
	menu_button.add_theme_constant_override("shadow_offset_x", 4)
	menu_button.add_theme_constant_override("shadow_offset_y", 4)
	
	add_child(menu_button)
	
	menu_button.pressed.connect(_on_button_pressed)
	menu_button.button_down.connect(_on_button_down)
	menu_button.button_up.connect(_on_button_up)
	
	menu_button.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_button.focus_mode = Control.FOCUS_ALL
	
	print("🎮 MobileMenuButton creado - Tamaño: ", size, " - Posición: ", position)
	print("🎮 Botón interno - Tamaño: ", menu_button.size, " - Visible: ", menu_button.visible)

func _on_button_down():
	if menu_button:
		var tween = create_tween()
		tween.tween_property(menu_button, "scale", Vector2(0.9, 0.9), 0.1)
		menu_button.modulate = Color(1.2, 1.2, 1.0, 1.0)

func _on_button_up():
	if menu_button:
		var tween = create_tween()
		tween.tween_property(menu_button, "scale", Vector2(1.0, 1.0), 0.1)
		tween.tween_property(menu_button, "modulate", Color.WHITE, 0.1)

func _on_button_pressed():
	print("🎮 ¡Botón de menú móvil PRESIONADO!")
	menu_pressed.emit()
	
	if menu_button:
		var tween = create_tween()
		tween.tween_property(menu_button, "modulate", Color(0.5, 1.0, 0.5, 1.0), 0.1)
		tween.tween_property(menu_button, "modulate", Color.WHITE, 0.2)

func _process(_delta):
	if not visible:
		visible = true
	
	if menu_button and not menu_button.visible:
		menu_button.visible = true

func _input(event):
	if event is InputEventScreenTouch and event.pressed:
		var viewport_size = get_viewport().get_visible_rect().size
		var touch_pos = event.position
		
		var button_area = Rect2(
			viewport_size.x - 160,
			0,
			160,
			140
		)
		
		if button_area.has_point(touch_pos):
			print("🎮 BACKUP: Toque detectado en área del menú")
			_on_button_pressed()
			get_viewport().set_input_as_handled()

func set_button_visibility(show_button: bool):  # CORREGIDO: renamed para evitar shadowing
	"""Función para controlar visibilidad del botón"""
	visible = show_button
	if menu_button:
		menu_button.visible = show_button
	
	print("🎮 MobileMenuButton visibilidad cambiada a: ", show_button)
