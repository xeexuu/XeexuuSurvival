# scenes/ui/CharacterSelection.gd - OPTIMIZADO PARA INICIO RÁPIDO
extends Control
class_name CharacterSelection

signal character_selected(character_stats: CharacterStats)

# CACHE de recursos para evitar cargas repetidas
var cached_characters: Array[CharacterStats] = []
var cached_sprites: Dictionary = {}
var is_loading: bool = false

func _ready():
	# INICIALIZACIÓN INMEDIATA sin delays
	call_deferred("setup_selection_ui_optimized")

func setup_selection_ui_optimized():
	"""CONFIGURACIÓN ULTRA RÁPIDA sin esperas innecesarias"""
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Fondo oscuro simple
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.1, 0.95)
	add_child(bg)
	
	var is_mobile = OS.has_feature("mobile") or OS.get_name() == "Android"
	var viewport_size = get_viewport().get_visible_rect().size
	
	# CARGAR PERSONAJES EN PARALELO (más rápido)
	if cached_characters.is_empty():
		cached_characters = load_characters_cached()
	
	# Scroll horizontal optimizado
	var scroll_container = ScrollContainer.new()
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll_container)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll_container.add_child(hbox)
	
	# CREAR TARJETAS DE FORMA INMEDIATA
	for character in cached_characters:
		var character_card = create_optimized_character_card(character, viewport_size, is_mobile)
		hbox.add_child(character_card)
	
	print("✅ CharacterSelection optimizado - Carga instantánea")

func load_characters_cached() -> Array[CharacterStats]:
	"""CARGAR PERSONAJES CON CACHE para evitar recargas"""
	if not cached_characters.is_empty():
		return cached_characters
	
	var characters: Array[CharacterStats] = []
	
	# ORDEN ESPECÍFICO Y CARGA DIRECTA
	var character_configs = [
		{"name": "pelao", "path": "res://scenes/characters/pelao_stats.tres"},
		{"name": "juancar", "path": "res://scenes/characters/juancar_stats.tres"},
		{"name": "chica", "path": "res://scenes/characters/chica_stats.tres"}
	]
	
	for config in character_configs:
		var character = load_character_direct(config.path, config.name)
		if character:
			characters.append(character)
			print("⚡ Personaje cargado rápido: ", character.character_name)
	
	# CACHE para futuras cargas
	cached_characters = characters
	return characters

func load_character_direct(file_path: String, char_name: String) -> CharacterStats:
	"""CARGA DIRECTA sin verificaciones lentas"""
	var character: CharacterStats = null
	
	if ResourceLoader.exists(file_path):
		character = load(file_path) as CharacterStats
	
	if not character:
		# FALLBACK INMEDIATO
		character = create_fallback_character(char_name)
	
	# CONFIGURACIÓN INMEDIATA del arma
	ensure_character_has_weapon_fast(character)
	return character

func create_fallback_character(char_name: String) -> CharacterStats:
	"""Crear personaje fallback de forma inmediata"""
	var character = CharacterStats.new()
	character.character_name = char_name
	
	match char_name:
		"pelao":
			character.max_health = 4
			character.movement_speed = 300
		"juancar":
			character.max_health = 4
			character.movement_speed = 450
		"chica":
			character.max_health = 4
			character.movement_speed = 300
	
	character.current_health = character.max_health
	character.luck = 5
	
	return character

func ensure_character_has_weapon_fast(character: CharacterStats):
	"""CONFIGURACIÓN RÁPIDA del arma sin delays"""
	if character.equipped_weapon:
		return  # Ya tiene arma
	
	# CREAR ARMA INMEDIATAMENTE
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
	
	# CARGAR SONIDO ESPECÍFICO INMEDIATAMENTE
	var character_name_lower = character.character_name.to_lower()
	var sound_path = "res://audio/" + character_name_lower + "_shoot.ogg"
	if ResourceLoader.exists(sound_path):
		character.equipped_weapon.attack_sound = load(sound_path)

func create_optimized_character_card(character: CharacterStats, viewport_size: Vector2, is_mobile: bool) -> Control:
	"""Crear tarjeta optimizada SIN DELAYS de carga"""
	var card_width = viewport_size.x / 3.0
	var card_height = viewport_size.y
	
	# Contenedor principal clickeable
	var card_container = Control.new()
	card_container.custom_minimum_size = Vector2(card_width, card_height)
	card_container.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# BOTÓN PRINCIPAL optimizado
	var main_button = Button.new()
	main_button.size = Vector2(card_width, card_height)
	main_button.position = Vector2.ZERO
	main_button.text = ""
	main_button.flat = true
	main_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Estilo transparente inmediato
	var transparent_style = StyleBoxFlat.new()
	transparent_style.bg_color = Color.TRANSPARENT
	main_button.add_theme_stylebox_override("normal", transparent_style)
	main_button.add_theme_stylebox_override("hover", transparent_style)
	main_button.add_theme_stylebox_override("pressed", transparent_style)
	main_button.add_theme_stylebox_override("focus", transparent_style)
	
	card_container.add_child(main_button)
	
	# PANEL VISUAL optimizado
	var visual_panel = Panel.new()
	visual_panel.size = Vector2(card_width, card_height)
	visual_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.2, 0.9)
	panel_style.border_color = Color(0.4, 0.6, 1.0, 0.8)
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	visual_panel.add_theme_stylebox_override("panel", panel_style)
	card_container.add_child(visual_panel)
	
	# LAYOUT VERTICAL inmediato
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("margin_left", 20)
	vbox.add_theme_constant_override("margin_right", 20)
	vbox.add_theme_constant_override("margin_top", 30)
	vbox.add_theme_constant_override("margin_bottom", 30)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual_panel.add_child(vbox)
	
	# SPRITE DEL PERSONAJE - CARGA INMEDIATA
	var sprite_container = Control.new()
	sprite_container.custom_minimum_size = Vector2(0, card_height * 0.6)
	sprite_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sprite_container)
	
	var character_sprite = get_character_sprite_cached(character)
	if character_sprite:
		var sprite_rect = TextureRect.new()
		sprite_rect.texture = character_sprite
		sprite_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sprite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite_container.add_child(sprite_rect)
	
	# INFORMACIÓN DEL PERSONAJE - INMEDIATA
	create_character_info_fast(vbox, character, is_mobile)
	
	# CONEXIÓN INMEDIATA del botón
	main_button.pressed.connect(func():
		print("🎮 Personaje seleccionado RÁPIDO: ", character.character_name)
		# EMISIÓN INMEDIATA sin delays
		character_selected.emit(character)
		queue_free()
	)
	
	# SOPORTE TÁCTIL para Android
	if is_mobile:
		var touch_button = TouchScreenButton.new()
		touch_button.shape = RectangleShape2D.new()
		touch_button.shape.size = Vector2(card_width, card_height)
		touch_button.position = Vector2.ZERO
		touch_button.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
		touch_button.pressed.connect(func():
			print("🎮 TouchScreen RÁPIDO: ", character.character_name)
			character_selected.emit(character)
			queue_free()
		)
		card_container.add_child(touch_button)
	
	# EFECTOS VISUALES simples y rápidos
	main_button.button_down.connect(func():
		visual_panel.modulate = Color(1.2, 1.2, 0.8, 1.0)
	)
	
	main_button.button_up.connect(func():
		visual_panel.modulate = Color.WHITE
	)
	
	return card_container

func create_character_info_fast(vbox: VBoxContainer, character: CharacterStats, is_mobile: bool):
	"""Crear información del personaje de forma inmediata"""
	# NOMBRE
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
	
	# ESTADÍSTICAS INMEDIATAS
	var stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 8)
	stats_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(stats_container)
	
	# Vida
	var health_label = create_stat_label("❤ Vida: " + str(character.max_health), Color.LIGHT_GREEN, 24)
	stats_container.add_child(health_label)
	
	# Velocidad
	var speed_label = create_stat_label("⚡ Velocidad: " + str(character.movement_speed), Color.YELLOW, 24)
	stats_container.add_child(speed_label)
	
	# Suerte
	var luck_label = create_stat_label("🍀 Suerte: " + str(character.luck), Color.MAGENTA, 24)
	stats_container.add_child(luck_label)

func create_stat_label(text: String, color: Color, font_size: int) -> Label:
	"""Crear label de estadística inmediato"""
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func get_character_sprite_cached(character: CharacterStats) -> Texture2D:
	"""OBTENER SPRITE con CACHE para evitar cargas repetidas"""
	var char_name = character.character_name.to_lower()
	
	# VERIFICAR CACHE primero
	if cached_sprites.has(char_name):
		return cached_sprites[char_name]
	
	var sprite = get_character_sprite_immediate(character)
	
	# GUARDAR EN CACHE
	cached_sprites[char_name] = sprite
	
	return sprite

func get_character_sprite_immediate(character: CharacterStats) -> Texture2D:
	"""Obtener sprite de forma inmediata sin verificaciones lentas"""
	var char_name = character.character_name.to_lower()
	
	# INTENTAR CARGA DIRECTA de walk_Right_Down
	var atlas_path = "res://sprites/player/" + char_name + "/walk_Right_Down.png"
	var texture = try_load_texture_immediate(atlas_path)
	
	if texture:
		return extract_first_frame_immediate(texture)
	
	# FALLBACK DIRECTO a chica
	var chica_path = "res://sprites/player/chica/walk_Right_Down.png"
	texture = try_load_texture_immediate(chica_path)
	
	if texture:
		return extract_first_frame_immediate(texture)
	
	# CREAR TEXTURE POR DEFECTO inmediatamente
	return create_default_character_preview_immediate(character.character_name)

func try_load_texture_immediate(path: String) -> Texture2D:
	"""Cargar textura de forma inmediata sin verificaciones lentas"""
	if not ResourceLoader.exists(path):
		return null
	
	var resource = load(path)
	if resource is Texture2D:
		return resource as Texture2D
	
	return null

func extract_first_frame_immediate(texture: Texture2D) -> Texture2D:
	"""Extraer primer frame inmediatamente si es atlas"""
	if not texture:
		return null
	
	var texture_size = texture.get_size()
	
	# SI ES ATLAS (ancho > alto), extraer primer frame
	if texture_size.x > texture_size.y * 2:
		var frame_width = float(texture_size.x) / 8.0
		var frame_height = float(texture_size.y)
		
		var first_frame = AtlasTexture.new()
		first_frame.atlas = texture
		first_frame.region = Rect2(0, 0, frame_width, frame_height)
		return first_frame
	
	return texture

func create_default_character_preview_immediate(char_name: String) -> Texture2D:
	"""Crear preview por defecto inmediatamente"""
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	
	# COLOR BASADO EN NOMBRE
	var name_hash = char_name.hash()
	var hue = float(abs(name_hash) % 360) / 360.0
	var character_color = Color.from_hsv(hue, 0.7, 0.9)
	
	image.fill(character_color)
	
	# DETALLES BÁSICOS INMEDIATOS
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
	
	# OJOS SIMPLES
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

func _exit_tree():
	"""Limpiar cache al salir"""
	cached_characters.clear()
	cached_sprites.clear()
