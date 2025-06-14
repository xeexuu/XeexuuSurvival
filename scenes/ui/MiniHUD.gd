# scenes/ui/MiniHUD.gd
extends Control
class_name MiniHUD

var name_label: Label
var health_label: Label
var speed_label: Label
var luck_label: Label

# Nuevas etiquetas para armas
var weapon_name_label: Label
var weapon_damage_label: Label
var weapon_range_label: Label
var weapon_attack_speed_label: Label

var current_character: CharacterStats
var is_mobile: bool = false

# ❌ NUEVO: Timer para actualización automática
var update_timer: Timer

func _ready():
	is_mobile = OS.has_feature("mobile")
	setup_hud()
	setup_auto_update_timer()

func setup_auto_update_timer():
	"""❌ NUEVO: Configurar timer para actualización automática de la UI"""
	update_timer = Timer.new()
	update_timer.wait_time = 0.5  # Actualizar cada 0.5 segundos
	update_timer.autostart = true
	update_timer.timeout.connect(_on_update_timer_timeout)
	add_child(update_timer)

func _on_update_timer_timeout():
	"""❌ NUEVO: Actualizar UI automáticamente"""
	if current_character:
		# Buscar el jugador actual para obtener vida actual
		var game_manager = get_tree().get_first_node_in_group("game_manager")
		if not game_manager:
			# Buscar por nombre si no está en grupo
			game_manager = get_node("/root/Main/GameManager") if get_node_or_null("/root/Main/GameManager") else null
		
		if game_manager and game_manager.has_method("get") and game_manager.get("player"):
			var player = game_manager.player
			if player and player.has_method("get_current_health"):
				update_health(player.get_current_health(), player.get_max_health())

func setup_hud():
	# Tamaño más grande, especialmente para móvil
	var hud_width = 320 if not is_mobile else 380
	var hud_height = 400 if not is_mobile else 450
	
	size = Vector2(hud_width, hud_height)
	position = Vector2(15, 15)
	
	# Fondo semi-transparente más visible
	var bg = ColorRect.new()
	bg.size = size
	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	add_child(bg)
	
	# Contenedor vertical para las etiquetas con más espacio
	var vbox = VBoxContainer.new()
	var padding = 15 if not is_mobile else 18
	vbox.size = Vector2(hud_width - padding * 2, hud_height - padding * 2)
	vbox.position = Vector2(padding, padding)
	vbox.add_theme_constant_override("separation", 8 if not is_mobile else 10)
	add_child(vbox)
	
	# Título del HUD
	var title_label = create_title_label("ESTADÍSTICAS")
	vbox.add_child(title_label)
	
	# Separador
	var separator1 = create_separator()
	vbox.add_child(separator1)
	
	# Crear etiquetas de personaje con fuentes más grandes
	name_label = create_stat_label("Personaje: ---", Color.CYAN)
	health_label = create_stat_label("❤ Vida: ---", Color.LIGHT_GREEN)
	speed_label = create_stat_label("⚡ Velocidad: ---", Color.YELLOW)
	luck_label = create_stat_label("🍀 Suerte: ---", Color.MAGENTA)
	
	vbox.add_child(name_label)
	vbox.add_child(health_label)
	vbox.add_child(speed_label)
	vbox.add_child(luck_label)
	
	# Separador para armas
	var separator2 = create_separator()
	vbox.add_child(separator2)
	
	# Título de arma
	var weapon_title = create_title_label("ARMA EQUIPADA")
	vbox.add_child(weapon_title)
	
	# Crear etiquetas de arma
	weapon_name_label = create_stat_label("🔫 Arma: ---", Color.ORANGE)
	weapon_damage_label = create_stat_label("⚔ Daño: ---", Color.RED)
	weapon_range_label = create_stat_label("🎯 Rango: ---", Color.CYAN)
	weapon_attack_speed_label = create_stat_label("⏱ Vel.Ataque: ---", Color.LIME)
	
	vbox.add_child(weapon_name_label)
	vbox.add_child(weapon_damage_label)
	vbox.add_child(weapon_range_label)
	vbox.add_child(weapon_attack_speed_label)

func create_title_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	var title_size = 20 if not is_mobile else 24
	
	# Usar métodos compatibles con todas las versiones de Godot
	if label.has_method("add_theme_font_size_override"):
		label.add_theme_font_size_override("font_size", title_size)
	
	if label.has_method("add_theme_color_override"):
		label.add_theme_color_override("font_color", Color.WHITE)
	
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	return label

func create_separator() -> Control:
	var separator = ColorRect.new()
	separator.custom_minimum_size = Vector2(0, 2)
	separator.color = Color(0.5, 0.5, 0.5, 0.6)
	return separator

func create_stat_label(text: String, color: Color = Color.WHITE) -> Label:
	var label = Label.new()
	label.text = text
	var stat_size = 16 if not is_mobile else 20
	
	# Usar métodos compatibles
	if label.has_method("add_theme_font_size_override"):
		label.add_theme_font_size_override("font_size", stat_size)
	
	if label.has_method("add_theme_color_override"):
		label.add_theme_color_override("font_color", color)
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
	
	if label.has_method("add_theme_constant_override"):
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
	
	return label

func update_character_stats(character: CharacterStats):
	"""❌ CORREGIDO: Actualizar estadísticas del personaje CON VERIFICACIÓN"""
	current_character = character
	if character and name_label:
		print("📊 Actualizando MiniHUD con: ", character.character_name)
		print("  - Vida original: ", character.current_health, "/", character.max_health)
		
		# Actualizar estadísticas del personaje
		if name_label:
			name_label.text = "Personaje: " + character.character_name
		if health_label:
			health_label.text = "❤ Vida: " + str(character.current_health) + "/" + str(character.max_health)
		if speed_label:
			speed_label.text = "⚡ Velocidad: " + str(character.movement_speed)
		if luck_label:
			luck_label.text = "🍀 Suerte: " + str(character.luck)
		
		# Actualizar estadísticas del arma
		if character.equipped_weapon:
			var weapon = character.equipped_weapon
			if weapon_name_label:
				weapon_name_label.text = "🔫 Arma: " + weapon.weapon_name
			if weapon_damage_label:
				weapon_damage_label.text = "⚔ Daño: " + str(weapon.damage)
			if weapon_range_label:
				weapon_range_label.text = "🎯 Rango: " + str(weapon.attack_range)
			if weapon_attack_speed_label:
				weapon_attack_speed_label.text = "⏱ Vel.Ataque: " + str(weapon.attack_speed)
		else:
			if weapon_name_label:
				weapon_name_label.text = "🔫 Arma: Sin arma"
			if weapon_damage_label:
				weapon_damage_label.text = "⚔ Daño: ---"
			if weapon_range_label:
				weapon_range_label.text = "🎯 Rango: ---"
			if weapon_attack_speed_label:
				weapon_attack_speed_label.text = "⏱ Vel.Ataque: ---"
		
		print("✅ MiniHUD actualizado correctamente")
	elif name_label:
		# Resetear todo si no hay personaje
		if name_label:
			name_label.text = "Personaje: ---"
		if health_label:
			health_label.text = "❤ Vida: ---"
		if speed_label:
			speed_label.text = "⚡ Velocidad: ---"
		if luck_label:
			luck_label.text = "🍀 Suerte: ---"
		if weapon_name_label:
			weapon_name_label.text = "🔫 Arma: ---"
		if weapon_damage_label:
			weapon_damage_label.text = "⚔ Daño: ---"
		if weapon_range_label:
			weapon_range_label.text = "🎯 Rango: ---"
		if weapon_attack_speed_label:
			weapon_attack_speed_label.text = "⏱ Vel.Ataque: ---"

func update_health(current_health: int, max_health: int):
	"""❌ CORREGIDO: Función para actualizar solo la vida SIN PRINT SPAM"""
	if health_label:
		var new_text = "❤ Vida: " + str(current_health) + "/" + str(max_health)
		
		# Solo actualizar si cambió
		if health_label.text != new_text:
			health_label.text = new_text
			
			# Efecto visual cuando la vida cambia
			if current_health < max_health:
				health_label.add_theme_color_override("font_color", Color.ORANGE)
				var tween = create_tween()
				tween.tween_property(health_label, "modulate", Color.WHITE, 0.3)
				tween.tween_callback(func(): 
					health_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
				)

func update_weapon_ammo(current_ammo: int, max_ammo: int):
	"""Función para actualizar munición si el arma la tiene"""
	if current_character and current_character.equipped_weapon and weapon_name_label:
		var weapon = current_character.equipped_weapon
		if weapon.ammo_capacity > 0:
			# Añadir info de munición al nombre del arma
			weapon_name_label.text = "🔫 " + weapon.weapon_name + " (" + str(current_ammo) + "/" + str(max_ammo) + ")"
