# scenes/ui/CharacterSelection.gd - CARGAR STATS REALES DEL .tres
extends Control
class_name CharacterSelection

signal character_selected(character_stats: CharacterStats)

func _ready():
	setup_selection_ui()

func setup_selection_ui():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Fondo
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.15, 0.95)
	add_child(bg)
	
	var is_mobile = OS.has_feature("mobile")
	var viewport_size = get_viewport().get_visible_rect().size
	
	# ScrollContainer principal
	var main_scroll = ScrollContainer.new()
	main_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if is_mobile:
		main_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		main_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	else:
		main_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		main_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(main_scroll)
	
	# Contenedor principal
	var main_container = VBoxContainer.new()
	main_container.add_theme_constant_override("separation", 50 if is_mobile else 30)
	
	if is_mobile:
		main_container.custom_minimum_size = Vector2(max(viewport_size.x, 1200), viewport_size.y - 20)
	else:
		main_container.custom_minimum_size = Vector2(viewport_size.x - 40, viewport_size.y - 40)
		main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	main_scroll.add_child(main_container)
	
	# Espaciador superior
	var top_spacer = Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_spacer.custom_minimum_size = Vector2(0, 60 if is_mobile else 50)
	main_container.add_child(top_spacer)
	
	# Título
	var title_container = Control.new()
	title_container.custom_minimum_size = Vector2(0, 120 if is_mobile else 100)
	main_container.add_child(title_container)
	
	var title = Label.new()
	title.text = "⚔ SELECCIONA TU GUERRERO ⚔"
	var title_size = 64 if is_mobile else 48
	title.add_theme_font_size_override("font_size", title_size)
	title.add_theme_color_override("font_color", Color.GOLD)
	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_container.add_child(title)
	
	# Área de personajes
	var characters_area = Control.new()
	characters_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	characters_area.custom_minimum_size = Vector2(0, 550 if is_mobile else 500)
	main_container.add_child(characters_area)
	
	# CARGAR PERSONAJES CON VALORES ORIGINALES DEL .tres
	var characters = load_all_characters_with_original_values()
	
	# Contenedor de personajes - SIEMPRE HORIZONTAL PARA MÓVIL
	var characters_container
	if is_mobile:
		characters_container = HBoxContainer.new()
		characters_container.add_theme_constant_override("separation", 40)
		characters_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		characters_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		characters_container.alignment = BoxContainer.ALIGNMENT_CENTER
	else:
		characters_container = HBoxContainer.new()
		characters_container.add_theme_constant_override("separation", 60)
		characters_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		characters_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		characters_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	characters_area.add_child(characters_container)
	
	# Crear tarjetas
	for character in characters:
		var character_card = create_character_card_horizontal(character, is_mobile)
		characters_container.add_child(character_card)
	
	# Espaciador inferior
	var bottom_spacer = Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_spacer.custom_minimum_size = Vector2(0, 60 if is_mobile else 40)
	main_container.add_child(bottom_spacer)
	
	# INSTRUCCIONES PARA MÓVIL
	if is_mobile:
		var instructions = Label.new()
		instructions.text = "← Desliza horizontalmente para ver más personajes →"
		instructions.add_theme_font_size_override("font_size", 20)
		instructions.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.8))
		instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		instructions.custom_minimum_size = Vector2(0, 30)
		main_container.add_child(instructions)

func load_all_characters_with_original_values() -> Array[CharacterStats]:
	"""CARGAR PERSONAJES MANTENIENDO VALORES EXACTOS DEL .tres"""
	var characters: Array[CharacterStats] = []
	
	# CARGAR PERSONAJES ESPECÍFICOS CON VALORES ORIGINALES
	var character_paths = [
		"res://scenes/characters/pelao_stats.tres",
		"res://scenes/characters/juancar_stats.tres", 
		"res://scenes/characters/chica_stats.tres"
	]
	
	for path in character_paths:
		var character = load_character_preserving_tres_values(path)
		if character:
			print("📄 Cargado desde .tres: ", character.character_name, " - Vida: ", character.max_health, "/", character.current_health, " - Velocidad: ", character.movement_speed)
			characters.append(character)
	
	# Solo crear fallback si NO hay ningún personaje
	if characters.is_empty():
		print("⚠️ No se pudieron cargar archivos .tres, creando fallbacks")
		characters = create_manual_fallback_characters()
	
	return characters

func load_character_preserving_tres_values(file_path: String) -> CharacterStats:
	"""CARGAR PERSONAJE PRESERVANDO EXACTAMENTE LOS VALORES DEL .tres"""
	if not ResourceLoader.exists(file_path):
		print("❌ Archivo no existe: ", file_path)
		return null
	
	var resource = load(file_path)
	if not resource or not resource is CharacterStats:
		print("❌ Recurso inválido: ", file_path)
		return null
	
	var character = resource as CharacterStats
	
	# VERIFICAR QUE LOS VALORES DEL .tres SEAN CORRECTOS
	print("🔍 Valores leídos del .tres ", file_path, ":")
	print("   Nombre: ", character.character_name)
	print("   Vida máxima: ", character.max_health)
	print("   Vida actual: ", character.current_health)
	print("   Velocidad: ", character.movement_speed)
	print("   Suerte: ", character.luck)
	
	# NO SOBRESCRIBIR - USAR VALORES EXACTOS DEL .tres
	# Los archivos .tres ya tienen los valores correctos
	
	# Asegurar arma
	ensure_character_has_weapon(character)
	
	return character

func ensure_character_has_weapon(character: CharacterStats):
	"""Asegurar que el personaje tenga un arma"""
	if not character.equipped_weapon:
		character.equipped_weapon = WeaponStats.new()
		character.equipped_weapon.weapon_name = "Pistola de " + character.character_name
		character.equipped_weapon.damage = 25
		character.equipped_weapon.attack_speed = 0.3  # 0.3 balas por segundo
		character.equipped_weapon.attack_range = 400
		character.equipped_weapon.projectile_speed = 600
		character.equipped_weapon.ammo_capacity = 30
		character.equipped_weapon.reload_time = 2.0
		character.equipped_weapon.accuracy = 0.9
		character.equipped_weapon.headshot_multiplier = 1.4
		
		# Cargar sonido específico según personaje
		var character_name_lower = character.character_name.to_lower()
		var sound_path = "res://audio/" + character_name_lower + "_shoot.ogg"
		if ResourceLoader.exists(sound_path):
			character.equipped_weapon.attack_sound = load(sound_path)
		
		print("🔫 Arma creada para ", character.character_name)

func create_manual_fallback_characters() -> Array[CharacterStats]:
	"""Crear personajes manualmente como último recurso"""
	var characters: Array[CharacterStats] = []
	
	# VALORES CORRECTOS SEGÚN LOS .tres ORIGINALES
	var character_configs = [
		{"name": "pelao", "health": 4, "speed": 300},
		{"name": "juancar", "health": 4, "speed": 450},  # MÁS RÁPIDO según juancar_stats.tres
		{"name": "chica", "health": 4, "speed": 300}
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
		
		print("🔧 Personaje manual creado: ", config.name, " - Vida: ", config.health, " - Velocidad: ", config.speed)
	
	return characters

func create_character_card_horizontal(character: CharacterStats, is_mobile: bool) -> Control:
	"""Crear tarjeta de personaje mostrando valores reales del .tres"""
	var _viewport_size = get_viewport().get_visible_rect().size
	
	var card_width = 280 if not is_mobile else 320
	var card_height = 480 if not is_mobile else 520
	
	# Contenedor principal
	var card_container = Control.new()
	card_container.custom_minimum_size = Vector2(card_width, card_height)
	
	# Panel
	var main_panel = Panel.new()
	main_panel.size = Vector2(card_width, card_height)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.25, 0.95)
	panel_style.border_color = Color(0.3, 0.6, 1.0, 0.8)
	panel_style.border_width_left = 4
	panel_style.border_width_right = 4
	panel_style.border_width_top = 4
	panel_style.border_width_bottom = 4
	panel_style.corner_radius_top_left = 20
	panel_style.corner_radius_top_right = 20
	panel_style.corner_radius_bottom_left = 20
	panel_style.corner_radius_bottom_right = 20
	main_panel.add_theme_stylebox_override("panel", panel_style)
	
	card_container.add_child(main_panel)
	
	# Layout
	var card_layout = VBoxContainer.new()
	card_layout.add_theme_constant_override("separation", 20 if not is_mobile else 25)
	var padding = 20 if not is_mobile else 25
	card_layout.position = Vector2(padding, padding)
	card_layout.size = Vector2(card_width - padding * 2, card_height - padding * 2)
	main_panel.add_child(card_layout)
	
	# Nombre del personaje
	var name_label = Label.new()
	name_label.text = character.character_name.capitalize()
	var name_font_size = 32 if not is_mobile else 38
	name_label.add_theme_font_size_override("font_size", name_font_size)
	name_label.add_theme_color_override("font_color", Color.GOLD)
	name_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	name_label.add_theme_constant_override("shadow_offset_x", 3)
	name_label.add_theme_constant_override("shadow_offset_y", 3)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_layout.add_child(name_label)
	
	# Área del sprite
	var sprite_container = Control.new()
	sprite_container.custom_minimum_size = Vector2(0, 140 if not is_mobile else 160)
	card_layout.add_child(sprite_container)
	
	# CARGAR SPRITE CON FALLBACK A CHICA
	var character_sprite = get_character_sprite_with_chica_fallback(character)
	if character_sprite:
		var sprite_rect = TextureRect.new()
		sprite_rect.texture = character_sprite
		sprite_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var display_size = 120 if not is_mobile else 140
		sprite_rect.size = Vector2(display_size, display_size)
		sprite_rect.position = Vector2(
			(card_width - padding * 2 - display_size) / 2.0,
			(sprite_container.custom_minimum_size.y - display_size) / 2.0
		)
		
		sprite_container.add_child(sprite_rect)
	else:
		# Placeholder mejorado
		var placeholder = ColorRect.new()
		placeholder.color = get_character_color(character.character_name)
		var placeholder_size = 100 if not is_mobile else 120
		placeholder.size = Vector2(placeholder_size, placeholder_size)
		placeholder.position = Vector2(
			(card_width - padding * 2 - placeholder_size) / 2.0,
			(sprite_container.custom_minimum_size.y - placeholder_size) / 2.0
		)
		sprite_container.add_child(placeholder)
		
		var initial = Label.new()
		initial.text = get_character_initial(character.character_name)
		initial.add_theme_font_size_override("font_size", 50 if not is_mobile else 60)
		initial.add_theme_color_override("font_color", Color.WHITE)
		initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		initial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		placeholder.add_child(initial)
	
	# ESTADÍSTICAS REALES DEL .tres
	var stats_container = Control.new()
	stats_container.custom_minimum_size = Vector2(0, 120 if not is_mobile else 140)
	card_layout.add_child(stats_container)
	
	var stats_bg = StyleBoxFlat.new()
	stats_bg.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	stats_bg.corner_radius_top_left = 15
	stats_bg.corner_radius_top_right = 15
	stats_bg.corner_radius_bottom_left = 15
	stats_bg.corner_radius_bottom_right = 15
	
	var stats_panel = Panel.new()
	stats_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stats_panel.add_theme_stylebox_override("panel", stats_bg)
	stats_container.add_child(stats_panel)
	
	# Grid de estadísticas con valores REALES
	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 15)
	stats_grid.add_theme_constant_override("v_separation", 12)
	stats_grid.position = Vector2(15, 15)
	stats_grid.size = Vector2(card_width - padding * 2 - 30, stats_container.custom_minimum_size.y - 30)
	stats_panel.add_child(stats_grid)
	
	var stat_font_size = 20 if not is_mobile else 24
	var icon_font_size = 24 if not is_mobile else 28
	
	# MOSTRAR VALORES EXACTOS DEL .tres
	# Vida
	var health_icon = create_stat_icon("❤", Color.LIGHT_GREEN, icon_font_size)
	var health_value = create_stat_value(str(character.max_health), Color.LIGHT_GREEN, stat_font_size)
	stats_grid.add_child(health_icon)
	stats_grid.add_child(health_value)
	
	# Velocidad (MOSTRAR VALOR REAL DEL .tres)
	var speed_icon = create_stat_icon("⚡", Color.CYAN, icon_font_size)
	var speed_value = create_stat_value(str(character.movement_speed), Color.CYAN, stat_font_size)
	stats_grid.add_child(speed_icon)
	stats_grid.add_child(speed_value)
	
	# Daño del arma
	var damage_icon = create_stat_icon("⚔", Color.RED, icon_font_size)
	var damage_value = create_stat_value(
		str(character.equipped_weapon.damage if character.equipped_weapon else 25), 
		Color.RED, 
		stat_font_size
	)
	stats_grid.add_child(damage_icon)
	stats_grid.add_child(damage_value)
	
	# Suerte
	var luck_icon = create_stat_icon("🍀", Color.MAGENTA, icon_font_size)
	var luck_value = create_stat_value(str(character.luck), Color.MAGENTA, stat_font_size)
	stats_grid.add_child(luck_icon)
	stats_grid.add_child(luck_value)
	
	# Botón de selección
	var select_button = Button.new()
	select_button.text = "¡SELECCIONAR!"
	var button_height = 60 if not is_mobile else 70
	select_button.custom_minimum_size = Vector2(card_width - padding * 2, button_height)
	var button_font_size = 24 if not is_mobile else 28
	select_button.add_theme_font_size_override("font_size", button_font_size)
	
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.7, 0.2, 0.9)
	button_style.corner_radius_top_left = 15
	button_style.corner_radius_top_right = 15
	button_style.corner_radius_bottom_left = 15
	button_style.corner_radius_bottom_right = 15
	select_button.add_theme_stylebox_override("normal", button_style)
	
	var button_hover = StyleBoxFlat.new()
	button_hover.bg_color = Color(0.3, 0.8, 0.3, 1.0)
	button_hover.corner_radius_top_left = 15
	button_hover.corner_radius_top_right = 15
	button_hover.corner_radius_bottom_left = 15
	button_hover.corner_radius_bottom_right = 15
	select_button.add_theme_stylebox_override("hover", button_hover)
	
	select_button.add_theme_color_override("font_color", Color.WHITE)
	select_button.add_theme_color_override("font_shadow_color", Color.BLACK)
	select_button.add_theme_constant_override("shadow_offset_x", 2)
	select_button.add_theme_constant_override("shadow_offset_y", 2)
	
	card_layout.add_child(select_button)
	
	# Efectos hover solo en escritorio
	if not is_mobile:
		select_button.mouse_entered.connect(func(): 
			var tween = create_tween()
			tween.tween_property(card_container, "scale", Vector2(1.05, 1.05), 0.15)
		)
		select_button.mouse_exited.connect(func(): 
			var tween = create_tween()
			tween.tween_property(card_container, "scale", Vector2(1.0, 1.0), 0.15)
		)
	
	# ACCIÓN DEL BOTÓN - ENVIAR PERSONAJE CON VALORES ORIGINALES
	select_button.pressed.connect(func(): 
		var tween = create_tween()
		tween.tween_property(card_container, "scale", Vector2(0.95, 0.95), 0.1)
		tween.tween_property(card_container, "scale", Vector2(1.0, 1.0), 0.1)
		
		print("🎮 Personaje seleccionado: ", character.character_name)
		print("   Vida: ", character.current_health, "/", character.max_health)
		print("   Velocidad: ", character.movement_speed)
		
		character_selected.emit(character)
		queue_free()
	)
	
	return card_container

func get_character_sprite_with_chica_fallback(character: CharacterStats) -> Texture2D:
	"""Obtener sprite del personaje con FALLBACK AUTOMÁTICO A CHICA"""
	var char_name = character.character_name.to_lower()
	
	# MÉTODO 1: Intentar carga directa del personaje
	var character_paths = [
		"res://sprites/player/" + char_name + "/walk_Right_Down.png",
		"res://sprites/player/" + char_name + "/idle.png",
		"res://sprites/player/" + char_name + "_idle.png"
	]
	
	for path in character_paths:
		var texture = try_load_texture_safe(path)
		if texture:
			print("✅ Sprite encontrado para ", char_name, ": ", path)
			return extract_first_frame_if_atlas(texture)
	
	# MÉTODO 2: FALLBACK AUTOMÁTICO A CHICA
	if char_name != "chica":
		print("⚠️ Sprite no encontrado para ", char_name, ", usando chica como fallback")
		var chica_paths = [
			"res://sprites/player/chica/walk_Right_Down.png",
			"res://sprites/player/chica/idle.png"
		]
		
		for path in chica_paths:
			var texture = try_load_texture_safe(path)
			if texture:
				print("✅ Usando sprite de chica para ", char_name, ": ", path)
				return extract_first_frame_if_atlas(texture)
	
	# MÉTODO 3: Intentar desde el sistema de efectos
	var scaled_texture = character.get_idle_texture_scaled_128px()
	if scaled_texture:
		return scaled_texture
	
	# MÉTODO 4: Crear textura por defecto
	print("⚠️ Creando sprite por defecto para ", char_name)
	return create_default_character_preview(character.character_name)

func extract_first_frame_if_atlas(texture: Texture2D) -> Texture2D:
	"""Extraer primer frame si es un atlas, o devolver textura normal"""
	if not texture:
		return null
	
	var texture_size = texture.get_size()
	
	# Si la textura es muy ancha, probablemente es un atlas
	if texture_size.x > texture_size.y * 2:
		var frame_width = float(texture_size.x) / 8.0  # Asumir 8 frames
		var frame_height = float(texture_size.y)
		
		var first_frame = AtlasTexture.new()
		first_frame.atlas = texture
		first_frame.region = Rect2(0, 0, frame_width, frame_height)
		return first_frame
	
	# Si no, devolver la textura tal como está
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
	
	# Ojos
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

func create_stat_icon(icon_text: String, color: Color, font_size: int) -> Label:
	"""Crear icono de estadística"""
	var icon = Label.new()
	icon.text = icon_text
	icon.add_theme_font_size_override("font_size", font_size)
	icon.add_theme_color_override("font_color", color)
	icon.add_theme_color_override("font_shadow_color", Color.BLACK)
	icon.add_theme_constant_override("shadow_offset_x", 2)
	icon.add_theme_constant_override("shadow_offset_y", 2)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.custom_minimum_size = Vector2(40, 30)
	return icon

func create_stat_value(value_text: String, color: Color, font_size: int) -> Label:
	"""Crear valor de estadística"""
	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", font_size)
	value.add_theme_color_override("font_color", color)
	value.add_theme_color_override("font_shadow_color", Color.BLACK)
	value.add_theme_constant_override("shadow_offset_x", 2)
	value.add_theme_constant_override("shadow_offset_y", 2)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.custom_minimum_size = Vector2(60, 30)
	return value

func get_character_color(char_name: String) -> Color:
	var name_hash = char_name.hash()
	var hue = float(abs(name_hash) % 360) / 360.0
	return Color.from_hsv(hue, 0.7, 0.9)

func get_character_initial(char_name: String) -> String:
	if char_name.length() > 0:
		return char_name.substr(0, 1).to_upper()
	return "?"
