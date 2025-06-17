# scenes/ui/CharacterSelection.gd - CARGAR STATS REALES DEL .tres
extends Control
class_name CharacterSelection

signal character_selected(character_stats: CharacterStats)

func _ready():
	setup_selection_ui()

func setup_selection_ui():
	"""INTERFAZ MINIMALISTA - SOLO PERSONAJES"""
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Fondo sutil
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.1, 0.9)  # Fondo muy oscuro
	add_child(bg)
	
	var is_mobile = OS.has_feature("mobile")
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Contenedor principal SIN scroll
	var main_container = Control.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main_container)
	
	# CARGAR PERSONAJES
	var characters = load_all_characters_with_original_values()
	
	# Contenedor de personajes CENTRADO
	var characters_container = HBoxContainer.new()
	characters_container.add_theme_constant_override("separation", 60 if not is_mobile else 40)
	characters_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Centrar en pantalla
	var total_width = characters.size() * (320 if is_mobile else 280) + (characters.size() - 1) * (40 if is_mobile else 60)
	var start_x = (viewport_size.x - total_width) / 2.0
	var start_y = (viewport_size.y - (440 if is_mobile else 400)) / 2.0
	
	characters_container.position = Vector2(start_x, start_y)
	main_container.add_child(characters_container)
	
	# Crear tarjetas SIN TEXTO
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
	"""Crear tarjeta de personaje - SOLO VISUAL, SIN TEXTO NI BOTONES"""
	var card_width = 280 if not is_mobile else 320
	var card_height = 400 if not is_mobile else 440  # Más alto sin botón
	
	# Contenedor principal CLICKEABLE
	var card_container = Control.new()
	card_container.custom_minimum_size = Vector2(card_width, card_height)
	
	# Panel principal - ESTE ES EL ELEMENTO CLICKEABLE
	var main_panel = Panel.new()
	main_panel.size = Vector2(card_width, card_height)
	main_panel.mouse_filter = Control.MOUSE_FILTER_STOP  # RECIBIR CLICKS
	
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
	
	# Layout SOLO para el sprite (centrado)
	var sprite_container = Control.new()
	sprite_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sprite_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_panel.add_child(sprite_container)
	
	# CARGAR Y MOSTRAR SOLO EL SPRITE - MÁS GRANDE
	var character_sprite = get_character_sprite_with_chica_fallback(character)
	if character_sprite:
		var sprite_rect = TextureRect.new()
		sprite_rect.texture = character_sprite
		sprite_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# SPRITE MÁS GRANDE OCUPANDO TODA LA TARJETA
		var display_size = min(card_width - 40, card_height - 40)
		sprite_rect.size = Vector2(display_size, display_size)
		sprite_rect.position = Vector2(
			(card_width - display_size) / 2.0,
			(card_height - display_size) / 2.0
		)
		
		sprite_container.add_child(sprite_rect)
	else:
		# Placeholder mejorado MÁS GRANDE
		var placeholder = ColorRect.new()
		placeholder.color = get_character_color(character.character_name)
		var placeholder_size = min(card_width - 60, card_height - 60)
		placeholder.size = Vector2(placeholder_size, placeholder_size)
		placeholder.position = Vector2(
			(card_width - placeholder_size) / 2.0,
			(card_height - placeholder_size) / 2.0
		)
		sprite_container.add_child(placeholder)
		
		# Inicial del personaje en el placeholder
		var initial = Label.new()
		initial.text = get_character_initial(character.character_name)
		initial.add_theme_font_size_override("font_size", 120 if not is_mobile else 140)
		initial.add_theme_color_override("font_color", Color.WHITE)
		initial.add_theme_color_override("font_shadow_color", Color.BLACK)
		initial.add_theme_constant_override("shadow_offset_x", 4)
		initial.add_theme_constant_override("shadow_offset_y", 4)
		initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		initial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		initial.mouse_filter = Control.MOUSE_FILTER_IGNORE
		placeholder.add_child(initial)
	
	# INDICADOR VISUAL DE SELECCIÓN (opcional)
	var selection_indicator = ColorRect.new()
	selection_indicator.color = Color(1, 1, 0, 0)  # Transparente inicialmente
	selection_indicator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	selection_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_panel.add_child(selection_indicator)
	
	# EFECTOS HOVER solo en escritorio
	if not is_mobile:
		main_panel.mouse_entered.connect(func(): 
			# Efecto hover
			var tween = create_tween()
			tween.tween_property(card_container, "scale", Vector2(1.05, 1.05), 0.15)
			selection_indicator.color = Color(1, 1, 0, 0.2)  # Amarillo suave
		)
		main_panel.mouse_exited.connect(func(): 
			var tween = create_tween()
			tween.tween_property(card_container, "scale", Vector2(1.0, 1.0), 0.15)
			selection_indicator.color = Color(1, 1, 0, 0)  # Transparente
		)
	
	# ACCIÓN DE SELECCIÓN - CLICK EN TODO EL PANEL
	main_panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			var mouse_event = event as InputEventMouseButton
			if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
				# Efecto visual de selección
				var tween = create_tween()
				tween.tween_property(card_container, "scale", Vector2(0.95, 0.95), 0.1)
				tween.tween_property(card_container, "scale", Vector2(1.0, 1.0), 0.1)
				
				# Flash de selección
				selection_indicator.color = Color(0, 1, 0, 0.6)  # Verde brillante
				var flash_tween = create_tween()
				flash_tween.tween_property(selection_indicator, "color", Color(0, 1, 0, 0), 0.3)
				
				print("🎮 Personaje seleccionado: ", character.character_name)
				print("   Vida: ", character.current_health, "/", character.max_health)
				print("   Velocidad: ", character.movement_speed)
				
				# EMITIR SEÑAL DE SELECCIÓN
				character_selected.emit(character)
				queue_free()
	)
	
	# SOPORTE TÁCTIL para móviles
	if is_mobile:
		var touch_button = TouchScreenButton.new()
		touch_button.texture = ImageTexture.new()  # Textura invisible
		touch_button.shape = RectangleShape2D.new()
		touch_button.shape.size = Vector2(card_width, card_height)
		touch_button.position = Vector2.ZERO
		touch_button.pressed.connect(func():
			# Misma acción que el click del mouse
			var tween = create_tween()
			tween.tween_property(card_container, "scale", Vector2(0.95, 0.95), 0.1)
			tween.tween_property(card_container, "scale", Vector2(1.0, 1.0), 0.1)
			
			selection_indicator.color = Color(0, 1, 0, 0.6)
			var flash_tween = create_tween()
			flash_tween.tween_property(selection_indicator, "color", Color(0, 1, 0, 0), 0.3)
			
			print("📱 Personaje seleccionado (táctil): ", character.character_name)
			character_selected.emit(character)
			queue_free()
		)
		main_panel.add_child(touch_button)
	
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
