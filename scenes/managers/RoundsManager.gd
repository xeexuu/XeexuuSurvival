# scenes/managers/RoundsManager.gd - CORREGIDO: ENEMIGOS NO MUEREN SOLOS
extends Node
class_name RoundsManager

signal round_changed(new_round: int)
signal enemies_remaining_changed(remaining: int)

var current_round: int = 1
var enemies_remaining_in_round: int = 0
var total_enemies_this_round: int = 0
var enemies_spawned_this_round: int = 0
var enemies_killed_this_round: int = 0

# Variables de configuración estilo COD zombies
var base_enemies_per_round: int = 8  # AUMENTADO PARA GARANTIZAR SPAWNS
var enemies_multiplier_per_round: float = 1.3  # LIGERAMENTE AUMENTADO

# Sistema de salud de enemigos estilo COD
var base_enemy_health: int = 150

# Referencias
var enemy_spawner: EnemySpawner

# Control del inicio automático
var auto_start_enabled: bool = false

func _ready():
	pass

func int_to_roman(num: int) -> String:
	"""Convertir número entero a números romanos"""
	if num <= 0:
		return "I"
	
	var values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
	var letters = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
	
	var result = ""
	for i in range(values.size()):
		var count = num / values[i]
		if count > 0:
			for j in range(count):
				result += letters[i]
			num = num % values[i]
	
	return result

func set_enemy_spawner(spawner: EnemySpawner):
	"""Establecer referencia al spawner de enemigos"""
	enemy_spawner = spawner
	if enemy_spawner:
		enemy_spawner.round_complete.connect(_on_round_complete)
		enemy_spawner.enemy_killed.connect(_on_enemy_killed_from_spawner)
		enemy_spawner.enemy_spawned.connect(_on_enemy_spawned_from_spawner)

func enable_auto_start():
	"""Habilitar inicio automático de spawning"""
	auto_start_enabled = true

func start_round(round_number: int):
	"""Iniciar una nueva ronda"""
	current_round = round_number
	
	var enemies_this_round = calculate_enemies_for_round(current_round)
	total_enemies_this_round = enemies_this_round
	enemies_remaining_in_round = enemies_this_round
	enemies_spawned_this_round = 0
	enemies_killed_this_round = 0
	
	show_round_start_message()
	round_changed.emit(current_round)
	enemies_remaining_changed.emit(enemies_remaining_in_round)
	
	if auto_start_enabled and enemy_spawner:
		var enemy_health = calculate_enemy_health_for_round(current_round)
		enemy_spawner.start_round(enemies_this_round, enemy_health)

func manually_start_spawning():
	"""Iniciar spawning manualmente"""
	if not enemy_spawner:
		return
	
	var enemies_this_round = calculate_enemies_for_round(current_round)
	var enemy_health = calculate_enemy_health_for_round(current_round)
	
	enemy_spawner.start_round(enemies_this_round, enemy_health)
	auto_start_enabled = true

func calculate_enemies_for_round(round_num: int) -> int:
	"""Calcular número de enemigos para una ronda específica"""
	if round_num == 1:
		return base_enemies_per_round
	
	var enemies = int(float(base_enemies_per_round) * pow(enemies_multiplier_per_round, round_num - 1))
	return min(enemies, 60)  # LÍMITE AUMENTADO

func calculate_enemy_health_for_round(round_num: int) -> int:
	"""SISTEMA DE SALUD BLACK OPS 1 - ESCALADO REAL PERO NO TAN EXTREMO"""
	
	# RONDAS 1-10: Escalado MÁS SUAVE
	if round_num <= 10:
		match round_num:
			1: return 100    # Ronda 1 - MÁS BAJO PARA TESTING
			2: return 150    # Ronda 2  
			3: return 200    # Ronda 3
			4: return 250    # Ronda 4
			5: return 300    # Ronda 5
			6: return 350    # Ronda 6
			7: return 400    # Ronda 7
			8: return 450    # Ronda 8
			9: return 500    # Ronda 9
			10: return 600   # Ronda 10
			_: return 100
	
	# RONDAS 11+: Escalado MODERADO
	else:
		var base_health_round_10 = 600
		var additional_rounds = round_num - 10
		
		# Escalado más suave: cada ronda después de 10 multiplica por 1.05
		var final_health = float(base_health_round_10) * pow(1.05, additional_rounds)
		
		# Límite máximo razonable
		return min(int(final_health), 5000)

func _on_enemy_killed_from_spawner(_enemy: Enemy):
	"""Cuando el spawner reporta un enemigo muerto"""
	enemies_killed_this_round += 1
	enemies_remaining_in_round = max(0, enemies_remaining_in_round - 1)
	
	enemies_remaining_changed.emit(enemies_remaining_in_round)

func _on_enemy_spawned_from_spawner(_enemy: Enemy):
	"""Cuando el spawner reporta un enemigo spawneado"""
	enemies_spawned_this_round += 1

func on_enemy_killed():
	"""FUNCIÓN PÚBLICA: Para llamar desde otros sistemas"""
	enemies_killed_this_round += 1
	enemies_remaining_in_round = max(0, enemies_remaining_in_round - 1)
	
	enemies_remaining_changed.emit(enemies_remaining_in_round)

func on_enemy_spawned():
	"""FUNCIÓN PÚBLICA: Para llamar desde otros sistemas"""
	enemies_spawned_this_round += 1

func _on_round_complete():
	"""Cuando el spawner confirma que la ronda está completa"""
	await get_tree().create_timer(2.0).timeout
	show_round_complete_message()
	await get_tree().create_timer(3.0).timeout
	start_round(current_round + 1)

func show_round_start_message():
	"""Mostrar mensaje de inicio de ronda"""
	var roman_round = int_to_roman(current_round)
	var message = create_round_message("RONDA " + roman_round, Color.ORANGE, 3.0)
	show_message(message)

func show_round_complete_message():
	"""Mostrar mensaje de ronda completada"""
	var roman_round = int_to_roman(current_round)
	var message = create_round_message("RONDA " + roman_round + " COMPLETADA", Color.GREEN, 2.0)
	show_message(message)

func create_round_message(text: String, color: Color, duration: float) -> Control:
	"""Crear mensaje de ronda centrado en pantalla"""
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

func show_message(message: Control):
	"""Mostrar mensaje en pantalla"""
	get_tree().current_scene.add_child(message)

func get_current_round() -> int:
	"""Obtener la ronda actual"""
	return current_round

func get_enemies_remaining() -> int:
	"""FUNCIÓN CORREGIDA: Obtener enemigos restantes REAL"""
	if enemy_spawner:
		var active_count = enemy_spawner.get_active_enemy_count()
		var to_spawn_count = enemy_spawner.get_enemies_remaining_to_spawn()
		return active_count + to_spawn_count
	else:
		# Fallback usando nuestro contador interno
		return enemies_remaining_in_round

func get_enemy_health_for_current_round() -> int:
	"""Obtener la salud de enemigos para la ronda actual"""
	return calculate_enemy_health_for_round(current_round)

func get_round_stats() -> Dictionary:
	"""Obtener estadísticas completas de la ronda"""
	return {
		"current_round": current_round,
		"total_enemies": total_enemies_this_round,
		"enemies_spawned": enemies_spawned_this_round,
		"enemies_killed": enemies_killed_this_round,
		"enemies_remaining": get_enemies_remaining()
	}
