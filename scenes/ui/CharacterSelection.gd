# scenes/ui/CharacterSelection.gd - ANDROID COMPATIBLE CON ORDEN CORREGIDO
extends Control
class_name CharacterSelection

signal character_selected(character_stats: CharacterStats)

func _ready():
	setup_selection_ui()

func setup_selection_ui():
	"""LISTA HORIZONTAL CON SOPORTE COMPLETO PARA ANDROID"""
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Fondo oscuro
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.1, 0.95)
	add_child(bg)
	
	var is_mobile = OS.has_feature("mobile") or OS.get_name() == "Android"
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Scroll horizontal para múltiples personajes
	var scroll_container = ScrollContainer.new()
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll_container)
	
	# Contenedor horizontal
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll_container.add_child(hbox)
	
	# CARGAR PERSONAJES EN ORDEN ESPECÍFICO
	var characters = load_characters_in_correct_order()
	
	# Crear tarjetas ocupando todo el alto
	for character in characters:
		var character_card = create_android_compatible_character_card(character, viewport_size, is_mobile)
		hbox.add_child(character_card)

func load_characters_in_correct_order() -> Array[CharacterStats]:
	"""CARGAR PERSONAJES EN ORDEN ESPECÍFICO: PELAO, JUANCAR, CHICA"""
	var characters: Array[CharacterStats] = []
	
	# ORDEN ESPECÍFICO PARA EVITAR CONFUSIÓN
	var character_paths_ordered = [
		"res://scenes/characters/pelao_stats.tres",     # PELAO PRIMERO
		"res://scenes/characters/juancar_stats.tres",   # JUANCAR SEGUNDO
		"res://scenes/characters/chica_stats.tres"      # CHICA TERCERO
	]
	
	for path in character_paths_ordered:
		var character = load_character_preserving_tres_values(path)
		if character:
			characters.append(character)
			print("✅ Personaje cargado: ", character.character_name, " desde ", path)
		else:
			print("❌ Error cargando personaje desde: ", path)
	
	if characters.is_empty():
		characters = create_manual_fallback_characters()
	
	return characters

func create_android_compatible_character_card(character: CharacterStats, viewport_size: Vector2, is_mobile: bool) -> Control:
	"""Crear tarjeta TOTALMENTE COMPATIBLE con Android"""
	var card_width = viewport_size.x / 3.0  # 3 personajes por pantalla
	var card_height = viewport_size.y
	
	# Contenedor principal - TOTALMENTE CLICKEABLE
	var card_container = Control.new()
	card_container.custom_minimum_size = Vector2(card_width, card_height)
	card_container.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# BOTÓN PRINCIPAL INVISIBLE QUE CUBRE TODA LA TARJETA
	var main_button = Button.new()
	main_button.size = Vector2(card_width, card_height)
	main_button.position = Vector2.ZERO
	main_button.text = ""  # Sin texto
	main_button.flat = true  # Botón plano
	main_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Estilo completamente transparente
	var transparent_style = StyleBoxFlat.new()
	transparent_style.bg_color = Color.TRANSPARENT
	main_button.add_theme_stylebox_override("normal", transparent_style)
	main_button.add_theme_stylebox_override("hover", transparent_style)
	main_button.add_theme_stylebox_override("pressed", transparent_style)
	main_button.add_theme_stylebox_override("focus", transparent_style)
	
	card_container.add_child(main_button)
	
	# Panel visual (NO clickeable, solo decorativo)
	var visual_panel = Panel.new()
	visual_panel.size = Vector2(card_width, card_height)
	visual_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # IGNORAR MOUSE
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.2, 0.9)
	panel_style.border_color = Color(0.4, 0.6, 1.0, 0.8)
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	visual_panel.add_theme_stylebox_override("panel", panel_style)
	card_container.add_child(visual_panel)
	
	# Layout vertical (NO clickeable)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("margin_left", 20)
	vbox.add_theme_constant_override("margin_right", 20)
	vbox.add_theme_constant_override("margin_top", 30)
	vbox.add_theme_constant_override("margin_bottom", 30)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE  # IGNORAR MOUSE
	visual_panel.add_child(vbox)
	
	# SPRITE DEL PERSONAJE - GRANDE (NO clickeable)
	var sprite_container = Control.new()
	sprite_container.custom_minimum_size = Vector2(0, card_height * 0.6)
	sprite_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sprite_container)
	
	var character_sprite = get_character_sprite_with_chica_fallback(character)
	if character_sprite:
		var sprite_rect = TextureRect.new()
		sprite_rect.texture = character_sprite
		sprite_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sprite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # IGNORAR MOUSE
		sprite_container.add_child(sprite_rect)
	
	# NOMBRE DEL PERSONAJE (NO clickeable)
	var name_label = Label.new()
	name_label.text = character.character_name.to_upper()
	name_label.add_theme_font_size_override("font_size", 32 if not is_mobile else 40)
	name_label.add_theme_color_override("font_color", Color.CYAN)
	name_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	name_label.add_theme_constant_override("shadow_offset_x", 3)
	name_label.add_theme_constant_override("shadow_offset_y", 3)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)
	
	# ESTADÍSTICAS (NO clickeable)
	var stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 8)
	stats_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(stats_container)
	
	# Vida
	var health_label = Label.new()
	health_label.text = "❤ Vida: " + str(character.max_health)
	health_label.add_theme_font_size_override("font_size", 24)
	health_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_container.add_child(health_label)
	
	# Velocidad
	var speed_label = Label.new()
	speed_label.text = "⚡ Velocidad: " + str(character.movement_speed)
	speed_label.add_theme_font_size_override("font_size", 24)
	speed_label.add_theme_color_override("font_color", Color.YELLOW)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_container.add_child(speed_label)
	
	# Suerte
	var luck_label = Label.new()
	luck_label.text = "🍀 Suerte: " + str(character.luck)
	luck_label.add_theme_font_size_override("font_size", 24)
	luck_label.add_theme_color_override("font_color", Color.MAGENTA)
	luck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	luck_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_container.add_child(luck_label)
	
	# CONEXIÓN DEL BOTÓN PRINCIPAL CON VERIFICACIÓN ADICIONAL
	main_button.pressed.connect(func():
		print("🎮 Personaje seleccionado: ", character.character_name)
		print("🎮 Verificación: Stats objeto -> ", character)
		character_selected.emit(character)
		queue_free()
	)
	
	# SOPORTE TÁCTIL ADICIONAL para Android CON VERIFICACIÓN
	if is_mobile:
		var touch_button = TouchScreenButton.new()
		touch_button.shape = RectangleShape2D.new()
		touch_button.shape.size = Vector2(card_width, card_height)
		touch_button.position = Vector2.ZERO
		touch_button.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
		touch_button.pressed.connect(func():
			print("🎮 TouchScreen - Personaje seleccionado: ", character.character_name)
			print("🎮 TouchScreen - Verificación: Stats objeto -> ", character)
			character_selected.emit(character)
			queue_free()
		)
		card_container.add_child(touch_button)
	
	# EFECTO VISUAL AL PRESIONAR
	main_button.button_down.connect(func():
		var press_tween = create_tween()
		press_tween.tween_property(visual_panel, "modulate", Color(1.2, 1.2, 0.8, 1.0), 0.1)
	)
	
	main_button.button_up.connect(func():
		var release_tween = create_tween()
		release_tween.tween_property(visual_panel, "modulate", Color.WHITE, 0.1)
	)
	
	return card_container

func load_character_preserving_tres_values(file_path: String) -> CharacterStats:
	"""CARGAR PERSONAJE PRESERVANDO EXACTAMENTE LOS VALORES DEL .tres"""
	if not ResourceLoader.exists(file_path):
		print("❌ Archivo no existe: ", file_path)
		return null
	
	var resource = load(file_path)
	if not resource or not resource is CharacterStats:
		print("❌ Recurso no válido: ", file_path)
		return null
	
	var character = resource as CharacterStats
	ensure_character_has_weapon(character)
	print("✅ Personaje cargado correctamente: ", character.character_name)
	return character

func ensure_character_has_weapon(character: CharacterStats):
	"""Asegurar que el personaje tenga un arma"""
	if not character.equipped_weapon:
		character.equipped_weapon = WeaponStats.new()
		character.equipped_weapon.weapon_name = "Pistola de " + character.character_name
		character.equipped_weapon.damage = 25
		character.equipped_weapon.attack_speed = 0.3
		character.equipped_weapon.attack_range = 400
		character.equipped_weapon.projectile_speed = 600
		character.equipped_weapon.ammo_capacity = 30
		character.equipped_weapon.reload_time = 2.0
		character.equipped_weapon.accuracy = 0.9
		character.equipped_weapon.headshot_multiplier = 1.4
		
		var character_name_lower = character.character_name.to_lower()
		var sound_path = "res://audio/" + character_name_lower + "_shoot.ogg"
		if ResourceLoader.exists(sound_path):
			character.equipped_weapon.attack_sound = load(sound_path)

func create_manual_fallback_characters() -> Array[CharacterStats]:
	"""Crear personajes manualmente como último recurso EN ORDEN CORRECTO"""
	var characters: Array[CharacterStats] = []
	
	var character_configs = [
		{"name": "pelao", "health": 4, "speed": 300},      # PELAO PRIMERO
		{"name": "juancar", "health": 4, "speed": 450},    # JUANCAR SEGUNDO
		{"name": "chica", "health": 4, "speed": 300}       # CHICA TERCERO
	]
	
	for config in character_configs:
		var character = CharacterStats.new()
		character.character_name = config.name
		character.max_health = config.health
		character.current_health = config.health
		character.movement_speed = config.speed
		character.luck = 5
		
		ensure_character_has_weapon(character)
		characters.append(character)
	
	return characters

func get_character_sprite_with_chica_fallback(character: CharacterStats) -> Texture2D:
	"""Obtener sprite del personaje con FALLBACK AUTOMÁTICO A CHICA"""
	var char_name = character.character_name.to_lower()
	
	var character_paths = [
		"res://sprites/player/" + char_name + "/walk_Right_Down.png",
		"res://sprites/player/" + char_name + "/idle.png",
		"res://sprites/player/" + char_name + "_idle.png"
	]
	
	for path in character_paths:
		var texture = try_load_texture_safe(path)
		if texture:
			return extract_first_frame_if_atlas(texture)
	
	if char_name != "chica":
		var chica_paths = [
			"res://sprites/player/chica/walk_Right_Down.png",
			"res://sprites/player/chica/idle.png"
		]
		
		for path in chica_paths:
			var texture = try_load_texture_safe(path)
			if texture:
				return extract_first_frame_if_atlas(texture)
	
	var scaled_texture = character.get_idle_texture_scaled_128px()
	if scaled_texture:
		return scaled_texture
	
	return create_default_character_preview(character.character_name)

func extract_first_frame_if_atlas(texture: Texture2D) -> Texture2D:
	"""Extraer primer frame si es un atlas, o devolver textura normal"""
	if not texture:
		return null
	
	var texture_size = texture.get_size()
	
	if texture_size.x > texture_size.y * 2:
		var frame_width = float(texture_size.x) / 8.0
		var frame_height = float(texture_size.y)
		
		var first_frame = AtlasTexture.new()
		first_frame.atlas = texture
		first_frame.region = Rect2(0, 0, frame_width, frame_height)
		return first_frame
	
	return texture

func try_load_texture_safe(path: String) -> Texture2D:
	"""Cargar textura de forma segura"""
	if not ResourceLoader.exists(path):
		return null
	
	var resource = load(path)
	if resource is Texture2D:
		return resource as Texture2D
	else:
		return null

func create_default_character_preview(char_name: String) -> Texture2D:
	"""Crear preview por defecto del personaje"""
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	
	var name_hash = char_name.hash()
	var hue = float(abs(name_hash) % 360) / 360.0
	var character_color = Color.from_hsv(hue, 0.7, 0.9)
	
	image.fill(character_color)
	
	var center = Vector2(64, 64)
	for x in range(128):
		for y in range(128):
			var dist = Vector2(x, y).distance_to(center)
			if dist < 20:
				image.set_pixel(x, y, Color.WHITE)
			elif dist < 30:
				image.set_pixel(x, y, character_color.darkened(0.3))
			elif dist < 40:
				image.set_pixel(x, y, character_color.darkened(0.1))
	
	var eye_size = 8
	for x in range(64 - 15, 64 - 15 + eye_size):
		for y in range(64 - 15, 64 - 15 + eye_size):
			if x >= 0 and x < 128 and y >= 0 and y < 128:
				image.set_pixel(x, y, Color.BLACK)
	
	for x in range(64 + 7, 64 + 7 + eye_size):
		for y in range(64 - 15, 64 - 15 + eye_size):
			if x >= 0 and x < 128 and y >= 0 and y < 128:
				image.set_pixel(x, y, Color.BLACK)
	
	return ImageTexture.create_from_image(image)
