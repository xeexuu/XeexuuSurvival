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

func _ready():
	is_mobile = OS.has_feature("mobile")
	setup_hud()

func setup_hud():
	# Tamaño más grande, especialmente para móvil
	var hud_width = 320 if not is_mobile else 380  # Más ancho para móvil
	var hud_height = 400 if not is_mobile else 450  # Más alto para móvil
	
	size = Vector2(hud_width, hud_height)
	position = Vector2(15, 15)  # Más separado del borde
	
	# Fondo semi-transparente más visible
	var bg = ColorRect.new()
	bg.size = size
	bg.color = Color(0.0, 0.0, 0.0, 0.75)  # Más opaco para mejor legibilidad
	add_child(bg)
	
	# Contenedor vertical para las etiquetas con más espacio
	var vbox = VBoxContainer.new()
	var padding = 15 if not is_mobile else 18
	vbox.size = Vector2(hud_width - padding * 2, hud_height - padding * 2)
	vbox.position = Vector2(padding, padding)
	vbox.add_theme_constant_override("separation", 8 if not is_mobile else 10)  # Más espacio entre elementos
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
	var title_size = 20 if not is_mobile else 24  # Más grande para móvil
	
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
	var stat_size = 16 if not is_mobile else 20  # Mucho más grande para móvil
	
	# Usar métodos compatibles
	if label.has_method("add_theme_font_size_override"):
		label.add_theme_font_size_override("font_size", stat_size)
	
	if label.has_method("add_theme_color_override"):
		label.add_theme_color_override("font_color", color)
		# Añadir sombra para mejor legibilidad si está disponible
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
	
	if label.has_method("add_theme_constant_override"):
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
	
	return label

func update_character_stats(character: CharacterStats):
	current_character = character
	if character and name_label:  # Verificar que las etiquetas existan
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
	elif name_label:  # Solo resetear si las etiquetas existen
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
	"""Función para actualizar solo la vida sin cambiar el resto"""
	if health_label:
		health_label.text = "❤ Vida: " + str(current_health) + "/" + str(max_health)

func update_weapon_ammo(current_ammo: int, max_ammo: int):
	"""Función para actualizar munición si el arma la tiene"""
	if current_character and current_character.equipped_weapon and weapon_name_label:
		var weapon = current_character.equipped_weapon
		if weapon.ammo_capacity > 0:
			# Añadir info de munición al nombre del arma
			weapon_name_label.text = "🔫 " + weapon.weapon_name + " (" + str(current_ammo) + "/" + str(max_ammo) + ")"
