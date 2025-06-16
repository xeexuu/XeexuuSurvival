# scenes/ui/PauseMenu.gd
extends Control
class_name PauseMenu

signal resume_game
signal restart_game
signal quit_game

var is_paused: bool = false
var is_mobile: bool = false

func _ready():
	is_mobile = OS.has_feature("mobile")
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	setup_responsive_menu()

func setup_responsive_menu():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Fondo semi-transparente más visible
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.8)  # Más opaco para mejor visibilidad
	add_child(bg)
	
	# Panel central del menú - RESPONSIVO
	var panel = Panel.new()
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Tamaño del panel basado en si es móvil o no
	var panel_width = 400 if not is_mobile else min(viewport_size.x * 0.8, 500)
	var panel_height = 350 if not is_mobile else min(viewport_size.y * 0.6, 450)
	
	panel.size = Vector2(panel_width, panel_height)
	panel.position = Vector2(
		(viewport_size.x - panel_width) / 2,
		(viewport_size.y - panel_height) / 2
	)
	
	# Estilo del panel más visible
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.2, 0.95)
	panel_style.border_color = Color(0.4, 0.6, 1.0, 1.0)
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 15
	panel_style.corner_radius_top_right = 15
	panel_style.corner_radius_bottom_left = 15
	panel_style.corner_radius_bottom_right = 15
	panel.add_theme_stylebox_override("panel", panel_style)
	
	add_child(panel)
	
	# Contenedor vertical con mejor espaciado
	var vbox = VBoxContainer.new()
	var separation = 25 if not is_mobile else 35  # Más separación en móvil
	vbox.add_theme_constant_override("separation", separation)
	
	var padding = 30 if not is_mobile else 40
	vbox.position = Vector2(padding, padding)
	vbox.size = Vector2(panel_width - padding * 2, panel_height - padding * 2)
	panel.add_child(vbox)
	
	# Título más grande y visible
	var title = Label.new()
	title.text = "⏸ JUEGO PAUSADO ⏸"
	var title_size = 32 if not is_mobile else 40
	title.add_theme_font_size_override("font_size", title_size)
	title.add_theme_color_override("font_color", Color.CYAN)
	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(0, 60)
	vbox.add_child(title)
	
	# Botón Continuar - MÁS GRANDE PARA MÓVIL
	var resume_btn = create_menu_button("▶ CONTINUAR", Color.LIGHT_GREEN)
	resume_btn.pressed.connect(_on_resume_pressed)
	vbox.add_child(resume_btn)
	
	# Botón Reiniciar
	var restart_btn = create_menu_button("🔄 REINICIAR PARTIDA", Color.YELLOW)
	restart_btn.pressed.connect(_on_restart_pressed)
	vbox.add_child(restart_btn)
	
	# Botón Salir
	var quit_btn = create_menu_button("❌ SALIR DEL JUEGO", Color.LIGHT_CORAL)
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)
	
	# Instrucciones para móvil
	if is_mobile:
		var instructions = Label.new()
		instructions.text = "Toca fuera del menú o el botón de back para continuar"
		instructions.add_theme_font_size_override("font_size", 16)
		instructions.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.8))
		instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		instructions.custom_minimum_size = Vector2(0, 40)
		vbox.add_child(instructions)

func create_menu_button(text: String, color: Color = Color.WHITE) -> Button:
	var button = Button.new()
	button.text = text
	
	# Tamaño responsivo
	var button_width = 300 if not is_mobile else 380
	var button_height = 50 if not is_mobile else 70
	button.custom_minimum_size = Vector2(button_width, button_height)
	
	# Fuente más grande para móvil
	var font_size = 20 if not is_mobile else 28
	button.add_theme_font_size_override("font_size", font_size)
	
	# Estilo del botón
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = color.darkened(0.6)
	button_style.corner_radius_top_left = 8
	button_style.corner_radius_top_right = 8
	button_style.corner_radius_bottom_left = 8
	button_style.corner_radius_bottom_right = 8
	button_style.border_color = color
	button_style.border_width_left = 2
	button_style.border_width_right = 2
	button_style.border_width_top = 2
	button_style.border_width_bottom = 2
	button.add_theme_stylebox_override("normal", button_style)
	
	# Estilo hover
	var button_hover_style = StyleBoxFlat.new()
	button_hover_style.bg_color = color.darkened(0.4)
	button_hover_style.corner_radius_top_left = 8
	button_hover_style.corner_radius_top_right = 8
	button_hover_style.corner_radius_bottom_left = 8
	button_hover_style.corner_radius_bottom_right = 8
	button_hover_style.border_color = color.lightened(0.2)
	button_hover_style.border_width_left = 2
	button_hover_style.border_width_right = 2
	button_hover_style.border_width_top = 2
	button_hover_style.border_width_bottom = 2
	button.add_theme_stylebox_override("hover", button_hover_style)
	
	# Estilo pressed
	var button_pressed_style = StyleBoxFlat.new()
	button_pressed_style.bg_color = color.darkened(0.8)
	button_pressed_style.corner_radius_top_left = 8
	button_pressed_style.corner_radius_top_right = 8
	button_pressed_style.corner_radius_bottom_left = 8
	button_pressed_style.corner_radius_bottom_right = 8
	button_pressed_style.border_color = color.lightened(0.3)
	button_pressed_style.border_width_left = 2
	button_pressed_style.border_width_right = 2
	button_pressed_style.border_width_top = 2
	button_pressed_style.border_width_bottom = 2
	button.add_theme_stylebox_override("pressed", button_pressed_style)
	
	return button

func show_menu():
	if is_paused:
		return
	
	is_paused = true
	visible = true
	get_tree().paused = true
	
	# Actualizar posición para diferentes tamaños de pantalla
	update_menu_position()

func update_menu_position():
	"""Actualizar la posición del menú para diferentes tamaños de pantalla"""
	await get_tree().process_frame
	
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Buscar el panel y reposicionarlo
	for child in get_children():
		if child is Panel:
			var panel = child as Panel
			panel.position = Vector2(
				(viewport_size.x - panel.size.x) / 2,
				(viewport_size.y - panel.size.y) / 2
			)
			break

func hide_menu():
	if not is_paused:
		return
	
	is_paused = false
	visible = false
	get_tree().paused = false

func _input(event):
	"""Manejar input específico del menú de pausa"""
	if not visible:
		return
	
	# En móvil, permitir cerrar tocando fuera del menú
	if is_mobile and event is InputEventScreenTouch and event.pressed:
		var touch_pos = event.position
		
		# Buscar el panel del menú
		for child in get_children():
			if child is Panel:
				var panel = child as Panel
				var panel_rect = Rect2(panel.global_position, panel.size)
				
				# Si el toque está fuera del panel, cerrar el menú
				if not panel_rect.has_point(touch_pos):
					_on_resume_pressed()
					return
				break
	
	# Manejar botón back en Android
	if is_mobile and event is InputEventKey and event.keycode == KEY_BACK and event.pressed:
		_on_resume_pressed()
		get_viewport().set_input_as_handled()

func _on_resume_pressed():
	resume_game.emit()
	hide_menu()

func _on_restart_pressed():
	restart_game.emit()

func _on_quit_pressed():
	quit_game.emit()
