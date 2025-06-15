# scenes/ui/FixedUIManager.gd - UI FIJA QUE NO TIEMBLE CON LA CÁMARA
extends CanvasLayer
class_name FixedUIManager

var rounds_ui: Control
var score_ui: Control
var round_label: Label
var enemies_label: Label
var score_label: Label

var rounds_manager_ref: RoundsManager
var score_system_ref: ScoreSystem

func _ready():
	# Configurar CanvasLayer para que sea independiente de la cámara
	layer = 100  # Por encima de todo
	follow_viewport_enabled = false  # NO seguir la cámara
	
	setup_fixed_ui()

func setup_fixed_ui():
	"""Configurar UI fija en pantalla"""
	var is_mobile = OS.has_feature("mobile")
	
	# ===== UI DE RONDAS (ESQUINA INFERIOR IZQUIERDA) =====
	rounds_ui = Control.new()
	rounds_ui.name = "RoundsUI"
	rounds_ui.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	var rounds_size = Vector2(200, 90) if not is_mobile else Vector2(240, 110)
	rounds_ui.size = rounds_size
	rounds_ui.position = Vector2(15, -rounds_size.y - 15)
	add_child(rounds_ui)
	
	# Fondo semi-transparente para rondas
	var rounds_bg = ColorRect.new()
	rounds_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rounds_bg.color = Color(0.0, 0.0, 0.1, 0.7)
	rounds_ui.add_child(rounds_bg)
	
	var rounds_vbox = VBoxContainer.new()
	rounds_vbox.add_theme_constant_override("separation", 8)
	rounds_vbox.position = Vector2(15, 15)
	rounds_vbox.size = Vector2(rounds_size.x - 30, rounds_size.y - 30)
	rounds_ui.add_child(rounds_vbox)
	
	round_label = Label.new()
	round_label.name = "RoundLabel"
	round_label.text = "RONDA I"
	var round_font_size = 28 if not is_mobile else 32
	round_label.add_theme_font_size_override("font_size", round_font_size)
	round_label.add_theme_color_override("font_color", Color.GOLD)
	round_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	round_label.add_theme_constant_override("shadow_offset_x", 2)
	round_label.add_theme_constant_override("shadow_offset_y", 2)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rounds_vbox.add_child(round_label)
	
	enemies_label = Label.new()
	enemies_label.name = "EnemiesLabel"
	enemies_label.text = "Zombies: 0"
	var enemies_font_size = 20 if not is_mobile else 24
	enemies_label.add_theme_font_size_override("font_size", enemies_font_size)
	enemies_label.add_theme_color_override("font_color", Color.RED)
	enemies_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	enemies_label.add_theme_constant_override("shadow_offset_x", 1)
	enemies_label.add_theme_constant_override("shadow_offset_y", 1)
	enemies_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rounds_vbox.add_child(enemies_label)
	
	# ===== UI DE PUNTUACIÓN (ESQUINA INFERIOR DERECHA) =====
	score_ui = Control.new()
	score_ui.name = "ScoreUI"
	score_ui.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	var score_size = Vector2(220, 80) if not is_mobile else Vector2(280, 100)
	score_ui.size = score_size
	score_ui.position = Vector2(-score_size.x - 15, -score_size.y - 15)
	add_child(score_ui)
	
	# Fondo para puntuación estilo Black Ops
	var score_bg = Panel.new()
	score_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	bg_style.border_color = Color(0.8, 0.6, 0.0, 0.9)
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.border_width_top = 2
	bg_style.border_width_bottom = 2
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_left = 8
	bg_style.corner_radius_bottom_right = 8
	score_bg.add_theme_stylebox_override("panel", bg_style)
	score_ui.add_child(score_bg)
	
	var score_vbox = VBoxContainer.new()
	score_vbox.add_theme_constant_override("separation", 5)
	score_vbox.position = Vector2(15, 10)
	score_vbox.size = Vector2(score_size.x - 30, score_size.y - 20)
	score_ui.add_child(score_vbox)
	
	# Título "PUNTOS"
	var title_label = Label.new()
	title_label.text = "PUNTOS"
	var title_size = 16 if not is_mobile else 20
	title_label.add_theme_font_size_override("font_size", title_size)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.0, 1.0))
	title_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_vbox.add_child(title_label)
	
	# Etiqueta de puntuación grande
	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = "0"
	var score_font_size = 32 if not is_mobile else 40
	score_label.add_theme_font_size_override("font_size", score_font_size)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	score_label.add_theme_constant_override("shadow_offset_x", 3)
	score_label.add_theme_constant_override("shadow_offset_y", 3)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_vbox.add_child(score_label)

func set_rounds_manager(rounds_manager: RoundsManager):
	"""Establecer referencia al rounds manager"""
	rounds_manager_ref = rounds_manager
	if rounds_manager_ref:
		rounds_manager_ref.round_changed.connect(_on_round_changed)
		rounds_manager_ref.enemies_remaining_changed.connect(_on_enemies_remaining_changed)

func set_score_system(score_system: ScoreSystem):
	"""Establecer referencia al score system"""
	score_system_ref = score_system
	if score_system_ref:
		score_system_ref.score_changed.connect(_on_score_changed)

func _on_round_changed(new_round: int):
	"""Actualizar UI cuando cambia la ronda"""
	if round_label and rounds_manager_ref:
		var roman_round = rounds_manager_ref.int_to_roman(new_round)
		round_label.text = "RONDA " + roman_round
		update_enemies_ui()

func _on_enemies_remaining_changed(_remaining: int):
	"""Actualizar UI de enemigos restantes"""
	update_enemies_ui()

func _on_score_changed(new_score: int):
	"""Actualizar UI de puntuación"""
	if score_label:
		var formatted_score = format_score(new_score)
		score_label.text = formatted_score
		
		# Efecto de parpadeo dorado
		var flash_tween = create_tween()
		score_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0, 1.0))
		flash_tween.tween_property(score_label, "modulate", Color.WHITE, 0.15)
		flash_tween.tween_callback(func(): 
			score_label.add_theme_color_override("font_color", Color.WHITE)
		)

func update_enemies_ui():
	"""Actualizar UI de enemigos restantes"""
	if not enemies_label or not rounds_manager_ref:
		return
	
	var total_remaining = rounds_manager_ref.get_enemies_remaining()
	enemies_label.text = "Zombies: " + str(total_remaining)
	
	if total_remaining <= 1:
		enemies_label.add_theme_color_override("font_color", Color.GREEN)
	elif total_remaining <= 5:
		enemies_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		enemies_label.add_theme_color_override("font_color", Color.RED)

func format_score(score: int) -> String:
	"""Formatear puntuación con separadores de miles"""
	var score_str = str(score)
	var formatted = ""
	var count = 0
	
	for i in range(score_str.length() - 1, -1, -1):
		if count == 3:
			formatted = "," + formatted
			count = 0
		formatted = score_str[i] + formatted
		count += 1
	
	return formatted

func show_round_start_message(round_number: int):
	"""Mostrar mensaje de inicio de ronda"""
	var roman_round = rounds_manager_ref.int_to_roman(round_number) if rounds_manager_ref else str(round_number)
	var message = create_centered_message("RONDA " + roman_round, Color.ORANGE, 3.0)
	add_child(message)

func show_round_complete_message(round_number: int):
	"""Mostrar mensaje de ronda completada"""
	var roman_round = rounds_manager_ref.int_to_roman(round_number) if rounds_manager_ref else str(round_number)
	var message = create_centered_message("RONDA " + roman_round + " COMPLETADA", Color.GREEN, 2.0)
	add_child(message)

func create_centered_message(text: String, color: Color, duration: float) -> Control:
	"""Crear mensaje centrado en pantalla"""
	var message_container = Control.new()
	message_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	message_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var message_label = Label.new()
	message_label.text = text
	message_label.add_theme_font_size_override("font_size", 48 if not OS.has_feature("mobile") else 64)
	message_label.add_theme_color_override("font_color", color)
	message_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	message_label.add_theme_constant_override("shadow_offset_x", 4)
	message_label.add_theme_constant_override("shadow_offset_y", 4)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	message_container.add_child(message_label)
	
	message_label.modulate = Color.TRANSPARENT
	var tween = message_container.create_tween()
	tween.tween_property(message_label, "modulate", Color.WHITE, 0.5)
	tween.tween_interval(duration - 1.0)
	tween.tween_property(message_label, "modulate", Color.TRANSPARENT, 0.5)
	tween.tween_callback(func(): message_container.queue_free())
	
	return message_container
