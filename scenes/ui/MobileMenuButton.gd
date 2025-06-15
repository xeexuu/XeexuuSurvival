# scenes/ui/MobileMenuButton.gd - BOTÓN VISIBLE Y FUNCIONAL EN ANDROID
extends Control
class_name MobileMenuButton

signal menu_pressed

var menu_button: Button

func _ready():
	# MOSTRAR SIEMPRE EL BOTÓN PARA TESTING Y ANDROID
	visible = true
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	z_index = 1000  # Z-INDEX MUY ALTO PARA ESTAR ENCIMA DE TODO
	
	setup_enhanced_button()

func setup_enhanced_button():
	# POSICIÓN FIJA EN ESQUINA SUPERIOR DERECHA
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	size = Vector2(120, 120)  # MÁS GRANDE PARA ANDROID
	position = Vector2(-140, 20)  # MÁS MARGEN DEL BORDE
	
	# CREAR BOTÓN MÁS GRANDE Y MÁS VISIBLE
	menu_button = Button.new()
	menu_button.text = "☰"  # Icono de menú hamburguesa
	menu_button.size = Vector2(120, 120)  # TAMAÑO COMPLETO
	menu_button.add_theme_font_size_override("font_size", 50)  # ICONO MÁS GRANDE
	
	# ESTILO MÁS VISIBLE Y CONTRASTANTE
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.1, 0.1, 0.2, 0.98)  # MÁS OPACO Y OSCURO
	style_normal.border_color = Color(1.0, 1.0, 1.0, 1.0)  # BORDE BLANCO
	style_normal.border_width_left = 6
	style_normal.border_width_right = 6
	style_normal.border_width_top = 6
	style_normal.border_width_bottom = 6
	style_normal.corner_radius_top_left = 60
	style_normal.corner_radius_top_right = 60
	style_normal.corner_radius_bottom_left = 60
	style_normal.corner_radius_bottom_right = 60
	menu_button.add_theme_stylebox_override("normal", style_normal)
	
	# ESTILO CUANDO SE PRESIONA - MÁS VISIBLE
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.3, 0.3, 0.6, 1.0)  # AZUL CUANDO SE PRESIONA
	style_pressed.border_color = Color(1.0, 1.0, 0.0, 1.0)  # BORDE AMARILLO
	style_pressed.border_width_left = 8
	style_pressed.border_width_right = 8
	style_pressed.border_width_top = 8
	style_pressed.border_width_bottom = 8
	style_pressed.corner_radius_top_left = 60
	style_pressed.corner_radius_top_right = 60
	style_pressed.corner_radius_bottom_left = 60
	style_pressed.corner_radius_bottom_right = 60
	menu_button.add_theme_stylebox_override("pressed", style_pressed)
	
	# ESTILO HOVER PARA ESCRITORIO
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
	
	# COLOR DEL TEXTO MÁS VISIBLE CON MEJOR CONTRASTE
	menu_button.add_theme_color_override("font_color", Color.WHITE)
	menu_button.add_theme_color_override("font_pressed_color", Color.YELLOW)
	menu_button.add_theme_color_override("font_hover_color", Color.CYAN)
	
	# SOMBRA AL TEXTO PARA MEJOR LEGIBILIDAD
	menu_button.add_theme_color_override("font_shadow_color", Color.BLACK)
	menu_button.add_theme_constant_override("shadow_offset_x", 4)
	menu_button.add_theme_constant_override("shadow_offset_y", 4)
	
	add_child(menu_button)
	
	# CONECTAR SEÑALES
	menu_button.pressed.connect(_on_button_pressed)
	menu_button.button_down.connect(_on_button_down)
	menu_button.button_up.connect(_on_button_up)
	
	# ASEGURAR QUE EL BOTÓN SEA TOTALMENTE FUNCIONAL EN ANDROID
	menu_button.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_button.focus_mode = Control.FOCUS_ALL
	
	# DEBUG: Confirmar creación
	print("🎮 MobileMenuButton creado - Tamaño: ", size, " - Posición: ", position)
	print("🎮 Botón interno - Tamaño: ", menu_button.size, " - Visible: ", menu_button.visible)

func _on_button_down():
	# ANIMACIÓN VISUAL CUANDO SE PRESIONA
	if menu_button:
		var tween = create_tween()
		tween.tween_property(menu_button, "scale", Vector2(0.9, 0.9), 0.1)
		
		# FEEDBACK VISUAL ADICIONAL
		menu_button.modulate = Color(1.2, 1.2, 1.0, 1.0)  # LIGERAMENTE AMARILLO

func _on_button_up():
	# VOLVER AL TAMAÑO Y COLOR NORMAL
	if menu_button:
		var tween = create_tween()
		tween.tween_property(menu_button, "scale", Vector2(1.0, 1.0), 0.1)
		tween.tween_property(menu_button, "modulate", Color.WHITE, 0.1)

func _on_button_pressed():
	print("🎮 ¡Botón de menú móvil PRESIONADO!")
	
	# EMITIR SEÑAL
	menu_pressed.emit()
	
	# EFECTO VISUAL ADICIONAL DE CONFIRMACIÓN
	if menu_button:
		var tween = create_tween()
		tween.tween_property(menu_button, "modulate", Color(0.5, 1.0, 0.5, 1.0), 0.1)  # VERDE
		tween.tween_property(menu_button, "modulate", Color.WHITE, 0.2)

# FORZAR VISIBILIDAD Y FUNCIONALIDAD
func _process(_delta):
	# ASEGURAR QUE EL BOTÓN PERMANEZCA VISIBLE Y FUNCIONAL
	if not visible:
		visible = true
	
	if menu_button and not menu_button.visible:
		menu_button.visible = true

# MANEJO DE INPUT DIRECTO EN CASO DE QUE EL BOTÓN NO RESPONDA
func _input(event):
	# BACKUP: Si el botón no funciona, detectar toques en la esquina superior derecha
	if event is InputEventScreenTouch and event.pressed:
		var viewport_size = get_viewport().get_visible_rect().size
		var touch_pos = event.position
		
		# ÁREA DE LA ESQUINA SUPERIOR DERECHA (donde está el botón)
		var button_area = Rect2(
			viewport_size.x - 160,  # 160px desde la derecha
			0,                      # Desde arriba
			160,                    # 160px de ancho
			140                     # 140px de alto
		)
		
		if button_area.has_point(touch_pos):
			print("🎮 BACKUP: Toque detectado en área del menú")
			_on_button_pressed()
			get_viewport().set_input_as_handled()

func set_button_visible(is_visible: bool):
	"""Función para controlar visibilidad del botón"""
	visible = is_visible
	if menu_button:
		menu_button.visible = is_visible
	
	print("🎮 MobileMenuButton visibilidad cambiada a: ", is_visible)
