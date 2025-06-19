# scenes/ui/MobileMenuButton.gd - BOTÓN SIEMPRE VISIBLE EN ANDROID
extends Control
class_name MobileMenuButton

signal menu_pressed

var menu_button: Button
var is_mobile: bool = false

func _ready():
	is_mobile = OS.has_feature("mobile") or OS.get_name() == "Android"
	
	# SOLO MOSTRAR EN MÓVIL
	visible = is_mobile
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	z_index = 1000
	
	if is_mobile:
		setup_enhanced_button()
		print("🎮 MobileMenuButton inicializado para Android")
	else:
		print("🎮 MobileMenuButton deshabilitado (no es móvil)")

func setup_enhanced_button():
	"""Configurar botón mejorado para Android"""
	# POSICIONAMIENTO FIJO EN ESQUINA SUPERIOR DERECHA
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	size = Vector2(140, 140)  # MÁS GRANDE
	position = Vector2(-160, 20)  # MÁS SEPARADO DEL BORDE
	
	menu_button = Button.new()
	menu_button.text = "⏸"  # Símbolo de pausa más claro
	menu_button.size = Vector2(140, 140)
	menu_button.position = Vector2.ZERO
	menu_button.add_theme_font_size_override("font_size", 60)  # FUENTE MÁS GRANDE
	
	# ESTILO NORMAL MÁS VISIBLE
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.1, 0.1, 0.3, 0.95)  # MÁS OPACO
	style_normal.border_color = Color(1.0, 1.0, 1.0, 1.0)
	style_normal.border_width_left = 8  # BORDES MÁS GRUESOS
	style_normal.border_width_right = 8
	style_normal.border_width_top = 8
	style_normal.border_width_bottom = 8
	style_normal.corner_radius_top_left = 70
	style_normal.corner_radius_top_right = 70
	style_normal.corner_radius_bottom_left = 70
	style_normal.corner_radius_bottom_right = 70
	menu_button.add_theme_stylebox_override("normal", style_normal)
	
	# ESTILO PRESIONADO MÁS VISIBLE
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.4, 0.4, 0.7, 1.0)
	style_pressed.border_color = Color(1.0, 1.0, 0.0, 1.0)  # BORDE AMARILLO
	style_pressed.border_width_left = 10
	style_pressed.border_width_right = 10
	style_pressed.border_width_top = 10
	style_pressed.border_width_bottom = 10
	style_pressed.corner_radius_top_left = 70
	style_pressed.corner_radius_top_right = 70
	style_pressed.corner_radius_bottom_left = 70
	style_pressed.corner_radius_bottom_right = 70
	menu_button.add_theme_stylebox_override("pressed", style_pressed)
	
	# ESTILO HOVER
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.2, 0.2, 0.5, 1.0)
	style_hover.border_color = Color(0.8, 0.8, 1.0, 1.0)
	style_hover.border_width_left = 8
	style_hover.border_width_right = 8
	style_hover.border_width_top = 8
	style_hover.border_width_bottom = 8
	style_hover.corner_radius_top_left = 70
	style_hover.corner_radius_top_right = 70
	style_hover.corner_radius_bottom_left = 70
	style_hover.corner_radius_bottom_right = 70
	menu_button.add_theme_stylebox_override("hover", style_hover)
	
	# COLORES DE FUENTE MÁS VISIBLES
	menu_button.add_theme_color_override("font_color", Color.WHITE)
	menu_button.add_theme_color_override("font_pressed_color", Color.YELLOW)
	menu_button.add_theme_color_override("font_hover_color", Color.CYAN)
	
	# SOMBRA PRONUNCIADA
	menu_button.add_theme_color_override("font_shadow_color", Color.BLACK)
	menu_button.add_theme_constant_override("shadow_offset_x", 5)
	menu_button.add_theme_constant_override("shadow_offset_y", 5)
	
	add_child(menu_button)
	
	# CONECTAR SEÑALES
	menu_button.pressed.connect(_on_button_pressed)
	menu_button.button_down.connect(_on_button_down)
	menu_button.button_up.connect(_on_button_up)
	
	# CONFIGURAR MOUSE FILTER
	menu_button.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_button.focus_mode = Control.FOCUS_ALL
	
	# SOPORTE TÁCTIL ADICIONAL PARA ANDROID
	var touch_button = TouchScreenButton.new()
	touch_button.shape = RectangleShape2D.new()
	touch_button.shape.size = Vector2(140, 140)
	touch_button.position = Vector2.ZERO
	touch_button.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
	touch_button.pressed.connect(_on_touch_pressed)
	add_child(touch_button)
	
	print("🎮 MobileMenuButton configurado - Tamaño: ", size, " - Posición: ", position)
	print("🎮 Botón interno - Tamaño: ", menu_button.size, " - Visible: ", menu_button.visible)

func _on_button_down():
	"""Animación al presionar"""
	if menu_button:
		var tween = create_tween()
		tween.tween_property(menu_button, "scale", Vector2(0.9, 0.9), 0.1)
		menu_button.modulate = Color(1.2, 1.2, 1.0, 1.0)

func _on_button_up():
	"""Animación al soltar"""
	if menu_button:
		var tween = create_tween()
		tween.tween_property(menu_button, "scale", Vector2(1.0, 1.0), 0.1)
		tween.tween_property(menu_button, "modulate", Color.WHITE, 0.1)

func _on_button_pressed():
	"""Botón presionado"""
	print("🎮 ¡Botón de menú móvil PRESIONADO!")
	menu_pressed.emit()
	
	if menu_button:
		var tween = create_tween()
		tween.tween_property(menu_button, "modulate", Color(0.5, 1.0, 0.5, 1.0), 0.1)
		tween.tween_property(menu_button, "modulate", Color.WHITE, 0.2)

func _on_touch_pressed():
	"""Touch específico presionado"""
	print("🎮 TOUCH: Botón de menú presionado via TouchScreenButton")
	_on_button_pressed()

func _process(_delta):
	"""Asegurar que el botón esté siempre visible en móvil"""
	if is_mobile:
		if not visible:
			visible = true
		
		if menu_button and not menu_button.visible:
			menu_button.visible = true

func _input(event):
	"""Input adicional para capturar toques en el área"""
	if not is_mobile or not visible:
		return
	
	if event is InputEventScreenTouch and event.pressed:
		var viewport_size = get_viewport().get_visible_rect().size
		var touch_pos = event.position
		
		# ÁREA EXPANDIDA DEL BOTÓN (esquina superior derecha)
		var button_area = Rect2(
			viewport_size.x - 180,  # MÁS ÁREA
			0,
			180,
			160
		)
		
		if button_area.has_point(touch_pos):
			print("🎮 INPUT: Toque detectado en área del menú")
			_on_button_pressed()
			get_viewport().set_input_as_handled()

func set_button_visibility(show_button: bool):
	"""Función para controlar visibilidad del botón"""
	if is_mobile:
		visible = show_button
		if menu_button:
			menu_button.visible = show_button
		
		print("🎮 MobileMenuButton visibilidad cambiada a: ", show_button)
	else:
		visible = false

func force_show():
	"""Forzar mostrar el botón (para debug)"""
	if is_mobile:
		visible = true
		if menu_button:
			menu_button.visible = true
			menu_button.modulate = Color.WHITE
		print("🎮 MobileMenuButton forzado a visible")

func _notification(what):
	"""Manejar notificaciones del sistema"""
	match what:
		NOTIFICATION_RESIZED:
			# Reposicionar cuando cambie el tamaño de la pantalla
			if is_mobile and menu_button:
				call_deferred("_reposition_button")

func _reposition_button():
	"""Reposicionar botón cuando cambie el tamaño de pantalla"""
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	position = Vector2(-160, 20)
