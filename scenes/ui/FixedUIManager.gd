# scenes/ui/FixedUIManager.gd - UI FIJA CON MUNICIÓN
extends CanvasLayer
class_name FixedUIManager

var rounds_ui: Control
var score_ui: Control
var ammo_ui: Control

var round_label: Label
var enemies_label: Label
var score_label: Label
var ammo_label: Label
var reload_label: Label

var rounds_manager_ref: RoundsManager
var score_system_ref: ScoreSystem
var player_ref: Player

var ammo_update_timer: Timer

func _ready():
	layer = 100
	follow_viewport_enabled = false
	setup_fixed_ui()
	setup_ammo_update_timer()

func setup_ammo_update_timer():
	"""Timer para actualizar munición regularmente"""
	ammo_update_timer = Timer.new()
	ammo_update_timer.wait_time = 0.1  # Actualizar cada 0.1 segundos
	ammo_update_timer.autostart = true
	ammo_update_timer.timeout.connect(_update_ammo_display)
	add_child(ammo_update_timer)

func setup_fixed_ui():
	"""Configurar UI fija completa"""
	var is_mobile = OS.has_feature("mobile")
	
	# ===== UI DE RONDAS (ESQUINA INFERIOR IZQUIERDA) =====
	setup_rounds_ui(is_mobile)
	
	# ===== UI DE PUNTUACIÓN (ESQUINA INFERIOR DERECHA) =====
	setup_score_ui(is_mobile)
	
	# ===== UI DE MUNICIÓN (ESQUINA INFERIOR CENTRO) =====
	setup_ammo_ui(is_mobile)

func setup_rounds_ui(is_mobile: bool):
	"""Configurar UI de rondas"""
	rounds_ui = Control.new()
	rounds_ui.name = "RoundsUI"
	rounds_ui.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	var rounds_size = Vector2(200, 90) if not is_mobile else Vector2(240, 110)
	rounds_ui.size = rounds_size
	rounds_ui.position = Vector2(15, -rounds_size.y - 15)
	add_child(rounds_ui)
	
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
	round_label.text = "RONDA I"
	var round_font_size = 28 if not is_mobile else 32
	round_label.add_theme_font_size_override("font_size", round_font_size)
	round_label.add_theme_color_override("font_color", Color.GOLD)
	round_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	round_label.add_theme_constant_override("shadow_offset_x", 2)
	round_label.add_theme_constant_override("shadow_offset_y", 2)
	rounds_vbox.add_child(round_label)
	
	enemies_label = Label.new()
	enemies_label.text = "Zombies: 0"
	var enemies_font_size = 20 if not is_mobile else 24
	enemies_label.add_theme_font_size_override("font_size", enemies_font_size)
	enemies_label.add_theme_color_override("font_color", Color.RED)
	enemies_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	enemies_label.add_theme_constant_override("shadow_offset_x", 1)
	enemies_label.add_theme_constant_override("shadow_offset_y", 1)
	rounds_vbox.add_child(enemies_label)

func setup_score_ui(is_mobile: bool):
	"""Configurar UI de puntuación"""
	score_ui = Control.new()
	score_ui.name = "ScoreUI"
	score_ui.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	var score_size = Vector2(220, 80) if not is_mobile else Vector2(280, 100)
	score_ui.size = score_size
	score_ui.position = Vector2(-score_size.x - 15, -score_size.y - 15)
	add_child(score_ui)
	
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
	
	score_label = Label.new()
	score_label.text = "0"
	var score_font_size = 32 if not is_mobile else 40
	score_label.add_theme_font_size_override("font_size", score_font_size)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	score_label.add_theme_constant_override("shadow_offset_x", 3)
	score_label.add_theme_constant_override("shadow_offset_y", 3)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_vbox.add_child(score_label)

func setup_ammo_ui(is_mobile: bool):
	"""Configurar UI de munición en el centro inferior"""
	ammo_ui = Control.new()
	ammo_ui.name = "AmmoUI"
	ammo_ui.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	
	# Posicionar en el centro inferior
	var viewport_size = get_viewport().get_visible_rect().size
	var ammo_size = Vector2(200, 100) if not is_mobile else Vector2(250, 120)
	ammo_ui.size = ammo_size
	ammo_ui.position = Vector2(
		(viewport_size.x - ammo_size.x) / 2,  # Centrar horizontalmente
		-ammo_size.y - 15  # Inferior con margen
	)
	add_child(ammo_ui)
	
	# Fondo de la UI de munición
	var ammo_bg = Panel.new()
	ammo_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ammo_style = StyleBoxFlat.new()
	ammo_style.bg_color = Color(0.1, 0.05, 0.0, 0.8)
	ammo_style.border_color = Color(0.6, 0.4, 0.0, 0.9)
	ammo_style.border_width_left = 2
	ammo_style.border_width_right = 2
	ammo_style.border_width_top = 2
	ammo_style.border_width_bottom = 2
	ammo_style.corner_radius_top_left = 10
	ammo_style.corner_radius_top_right = 10
	ammo_style.corner_radius_bottom_left = 10
	ammo_style.corner_radius_bottom_right = 10
	ammo_bg.add_theme_stylebox_override("panel", ammo_style)
	ammo_ui.add_child(ammo_bg)
	
	var ammo_vbox = VBoxContainer.new()
	ammo_vbox.add_theme_constant_override("separation", 8)
	ammo_vbox.position = Vector2(15, 15)
	ammo_vbox.size = Vector2(ammo_size.x - 30, ammo_size.y - 30)
	ammo_ui.add_child(ammo_vbox)
	
	# Etiqueta de munición
	ammo_label = Label.new()
	ammo_label.text = "30 / 30"
	var ammo_font_size = 36 if not is_mobile else 42
	ammo_label.add_theme_font_size_override("font_size", ammo_font_size)
	ammo_label.add_theme_color_override("font_color", Color.CYAN)
	ammo_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	ammo_label.add_theme_constant_override("shadow_offset_x", 3)
	ammo_label.add_theme_constant_override("shadow_offset_y", 3)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ammo_vbox.add_child(ammo_label)
	
	# Etiqueta de recarga
	reload_label = Label.new()
	reload_label.text = ""
	var reload_font_size = 20 if not is_mobile else 24
	reload_label.add_theme_font_size_override("font_size", reload_font_size)
	reload_label.add_theme_color_override("font_color", Color.YELLOW)
	reload_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	reload_label.add_theme_constant_override("shadow_offset_x", 2)
	reload_label.add_theme_constant_override("shadow_offset_y", 2)
	reload_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reload_label.visible = false
	ammo_vbox.add_child(reload_label)

func set_player_reference(player: Player):
	"""Establecer referencia al jugador"""
	player_ref = player

func _update_ammo_display():
	"""Actualizar display de munición"""
	if not player_ref or not ammo_label:
		return
	
	var ammo_info = player_ref.get_ammo_info()
	
	if ammo_info.reloading:
		# Mostrar estado de recarga
		ammo_label.text = "-- / --"
		ammo_label.add_theme_color_override("font_color", Color.GRAY)
		
		reload_label.visible = true
		var progress = ammo_info.reload_progress * 100
		reload_label.text = "RECARGANDO... " + str(int(progress)) + "%"
		
		# Animación de parpadeo durante recarga
		var alpha = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)
		reload_label.modulate = Color(1, 1, 1, alpha)
	else:
		# Mostrar munición normal
		reload_label.visible = false
		ammo_label.text = str(ammo_info.current) + " / " + str(ammo_info.max)
		
		# Cambiar color según munición restante
		var ammo_percentage = float(ammo_info.current) / float(ammo_info.max) if ammo_info.max > 0 else 1.0
		
		if ammo_percentage > 0.5:
			ammo_label.add_theme_color_override("font_color", Color.CYAN)
		elif ammo_percentage > 0.2:
			ammo_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			ammo_label.add_theme_color_override("font_color", Color.RED)
			
			# Parpadeo cuando munición baja
			if ammo_info.current <= 5:
				var alpha = 0.3 + 0.7 * sin(Time.get_ticks_msec() * 0.015)
				ammo_label.modulate = Color(1, 1, 1, alpha)
			else:
				ammo_label.modulate = Color.WHITE

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
