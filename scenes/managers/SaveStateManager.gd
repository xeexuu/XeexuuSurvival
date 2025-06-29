# SaveStateManager.gd - SISTEMA DE GUARDADO COMPLETO PARA ANDROID
extends Node
class_name SaveStateManager

var save_file_path: String = "user://complete_game_save.dat"
var quick_save_path: String = "user://quick_save.dat"

func save_complete_game_state(game_manager: Node) -> bool:
	"""Guardar estado COMPLETO del juego para Android"""
	if not game_manager:
		return false
	
	var save_data = {
		"version": "2.0",
		"timestamp": Time.get_unix_time_from_system(),
		"game_started": true,
		"game_state": "playing",
		"was_paused": true,  # IMPORTANTE: Marcar que estaba pausado
		
		# DATOS DEL JUGADOR
		"player_data": get_player_save_data(game_manager),
		
		# DATOS DE RONDA
		"round_data": get_round_save_data(game_manager),
		
		# DATOS DE PUNTUACIÓN
		"score_data": get_score_save_data(game_manager),
		
		# DATOS DE ENEMIGOS ACTIVOS
		"enemies_data": get_enemies_save_data(game_manager),
		
		# DATOS DE BARRICADAS
		"barricades_data": get_barricades_save_data(game_manager),
		
		# DATOS DE PUERTAS
		"doors_data": get_doors_save_data(game_manager),
		
		# DATOS DEL SISTEMA DE SPAWN
		"spawner_data": get_spawner_save_data(game_manager)
	}
	
	var file = FileAccess.open(save_file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("✅ Estado completo guardado para Android")
		return true
	else:
		print("❌ Error al guardar estado completo")
		return false

func get_player_save_data(game_manager: Node) -> Dictionary:
	"""Obtener datos completos del jugador"""
	var player_data = {}
	
	if game_manager.player:
		var player = game_manager.player
		player_data = {
			"current_health": player.get_current_health() if player.has_method("get_current_health") else 4,
			"max_health": player.get_max_health() if player.has_method("get_max_health") else 4,
			"global_position": player.global_position,
			"move_speed": player.move_speed if player.has_method("get") else 300.0,
			"ammo_info": player.get_ammo_info() if player.has_method("get_ammo_info") else {},
			"character_name": "",
			"weapon_stats": {}
		}
		
		# Datos del personaje
		if player.character_stats:
			player_data["character_name"] = player.character_stats.character_name
			if player.character_stats.equipped_weapon:
				player_data["weapon_stats"] = {
					"current_ammo": player.character_stats.equipped_weapon.current_ammo,
					"is_reloading": player.character_stats.equipped_weapon.is_reloading
				}
	
	return player_data

func get_round_save_data(game_manager: Node) -> Dictionary:
	"""Obtener datos de la ronda actual"""
	var round_data = {}
	
	if game_manager.rounds_manager:
		var rounds_manager = game_manager.rounds_manager
		round_data = {
			"current_round": rounds_manager.get_current_round(),
			"enemies_remaining": rounds_manager.get_enemies_remaining(),
			"total_enemies_this_round": rounds_manager.total_enemies_this_round if rounds_manager.has_method("get") else 0,
			"enemies_spawned_this_round": rounds_manager.enemies_spawned_this_round if rounds_manager.has_method("get") else 0,
			"enemies_killed_this_round": rounds_manager.enemies_killed_this_round if rounds_manager.has_method("get") else 0
		}
	
	return round_data

func get_score_save_data(game_manager: Node) -> Dictionary:
	"""Obtener datos de puntuación"""
	var score_data = {}
	
	if game_manager.score_system:
		var score_system = game_manager.score_system
		score_data = {
			"current_score": score_system.get_current_score(),
			"total_kills": score_system.get_total_kills(),
			"headshot_kills": score_system.get_headshot_kills(),
			"current_kill_streak": score_system.get_current_kill_streak(),
			"best_kill_streak": score_system.get_best_kill_streak(),
			"current_round_multiplier": score_system.current_round_multiplier if score_system.has_method("get") else 1
		}
	
	return score_data

func get_enemies_save_data(game_manager: Node) -> Array:
	"""Obtener datos de todos los enemigos activos"""
	var enemies_data = []
	
	if game_manager.enemy_spawner:
		var spawner = game_manager.enemy_spawner
		if spawner.has_method("get") and spawner.get("active_enemies"):
			var active_enemies = spawner.get("active_enemies")
			
			for enemy in active_enemies:
				if is_instance_valid(enemy) and enemy.has_method("get_save_data"):
					enemies_data.append(enemy.get_save_data())
	
	return enemies_data

func get_barricades_save_data(game_manager: Node) -> Array:
	"""Obtener estado de todas las barricadas"""
	var barricades_data = []
	
	if game_manager.wall_system:
		var wall_system = game_manager.wall_system
		if wall_system.has_method("get_all_barricades"):
			var barricades = wall_system.get_all_barricades()
			
			for barricade in barricades:
				if is_instance_valid(barricade):
					barricades_data.append({
						"name": barricade.name,
						"position": barricade.global_position,
						"current_planks": barricade.get_meta("current_planks", 0),
						"max_planks": barricade.get_meta("max_planks", 8),
						"size": barricade.get_meta("size", Vector2(200, 60)),
						"repair_cost": barricade.get_meta("repair_cost", 10)
					})
	
	return barricades_data

func get_doors_save_data(game_manager: Node) -> Array:
	"""Obtener estado de todas las puertas"""
	var doors_data = []
	
	if game_manager.wall_system:
		var wall_system = game_manager.wall_system
		if wall_system.has_method("get_all_doors"):
			var doors = wall_system.get_all_doors()
			
			for door in doors:
				if is_instance_valid(door):
					doors_data.append({
						"name": door.name,
						"position": door.global_position,
						"is_open": door.get_meta("is_open", false),
						"cost": door.get_meta("cost", 3000),
						"target_room": door.get_meta("target_room", "area_exterior"),
						"size": door.get_meta("size", Vector2(180, 180))
					})
	
	return doors_data

func get_spawner_save_data(game_manager: Node) -> Dictionary:
	"""Obtener datos del spawner de enemigos"""
	var spawner_data = {}
	
	if game_manager.enemy_spawner:
		var spawner = game_manager.enemy_spawner
		spawner_data = {
			"enemies_to_spawn": spawner.get("enemies_to_spawn") if spawner.has_method("get") else 0,
			"enemies_spawned_this_round": spawner.get("enemies_spawned_this_round") if spawner.has_method("get") else 0,
			"can_spawn": spawner.get("can_spawn") if spawner.has_method("get") else false,
			"current_round_number": spawner.get("current_round_number") if spawner.has_method("get") else 1,
			"spawn_delay": spawner.get("spawn_delay") if spawner.has_method("get") else 2.0
		}
	
	return spawner_data

func load_complete_game_state(game_manager: Node) -> bool:
	"""Cargar estado completo del juego"""
	if not FileAccess.file_exists(save_file_path):
		print("📂 No hay archivo de guardado completo")
		return false
	
	var file = FileAccess.open(save_file_path, FileAccess.READ)
	if not file:
		print("❌ Error al leer archivo de guardado")
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("❌ Error al parsear JSON de guardado")
		return false
	
	var save_data = json.data
	
	if not save_data.has("version") or not save_data.has("game_started"):
		print("❌ Formato de guardado inválido")
		return false
	
	print("📥 Cargando estado completo del juego...")
	
	# Cargar datos del jugador
	if save_data.has("player_data"):
		restore_player_data(game_manager, save_data.player_data)
	
	# Cargar datos de ronda
	if save_data.has("round_data"):
		restore_round_data(game_manager, save_data.round_data)
	
	# Cargar datos de puntuación
	if save_data.has("score_data"):
		restore_score_data(game_manager, save_data.score_data)
	
	# Cargar datos de barricadas
	if save_data.has("barricades_data"):
		restore_barricades_data(game_manager, save_data.barricades_data)
	
	# Cargar datos de puertas
	if save_data.has("doors_data"):
		restore_doors_data(game_manager, save_data.doors_data)
	
	# Cargar datos del spawner
	if save_data.has("spawner_data"):
		restore_spawner_data(game_manager, save_data.spawner_data)
	
	# Cargar enemigos (después de todo lo demás)
	if save_data.has("enemies_data"):
		restore_enemies_data(game_manager, save_data.enemies_data)
	
	print("✅ Estado completo cargado exitosamente")
	return true

func restore_player_data(game_manager: Node, player_data: Dictionary):
	"""Restaurar datos del jugador"""
	if not game_manager.player:
		return
	
	var player = game_manager.player
	
	# Restaurar salud
	if player_data.has("current_health"):
		player.current_health = player_data.current_health
	if player_data.has("max_health"):
		player.max_health = player_data.max_health
	
	# Restaurar posición
	if player_data.has("global_position"):
		player.global_position = player_data.global_position
	
	# Restaurar munición si está disponible
	if player_data.has("weapon_stats") and player.character_stats and player.character_stats.equipped_weapon:
		var weapon_stats = player_data.weapon_stats
		if weapon_stats.has("current_ammo"):
			player.character_stats.equipped_weapon.current_ammo = weapon_stats.current_ammo
		if weapon_stats.has("is_reloading"):
			player.character_stats.equipped_weapon.is_reloading = weapon_stats.is_reloading
	
	print("✅ Datos del jugador restaurados")

func restore_round_data(game_manager: Node, round_data: Dictionary):
	"""Restaurar datos de ronda"""
	if not game_manager.rounds_manager:
		return
	
	var rounds_manager = game_manager.rounds_manager
	
	if round_data.has("current_round"):
		rounds_manager.current_round = round_data.current_round
	
	if round_data.has("enemies_remaining"):
		rounds_manager.enemies_remaining_in_round = round_data.enemies_remaining
	
	if round_data.has("total_enemies_this_round"):
		rounds_manager.total_enemies_this_round = round_data.total_enemies_this_round
	
	if round_data.has("enemies_spawned_this_round"):
		rounds_manager.enemies_spawned_this_round = round_data.enemies_spawned_this_round
	
	if round_data.has("enemies_killed_this_round"):
		rounds_manager.enemies_killed_this_round = round_data.enemies_killed_this_round
	
	print("✅ Datos de ronda restaurados - Ronda: ", rounds_manager.current_round)

func restore_score_data(game_manager: Node, score_data: Dictionary):
	"""Restaurar datos de puntuación"""
	if not game_manager.score_system:
		return
	
	var score_system = game_manager.score_system
	
	if score_data.has("current_score"):
		score_system.current_score = score_data.current_score
	
	if score_data.has("total_kills"):
		score_system.total_kills = score_data.total_kills
	
	if score_data.has("headshot_kills"):
		score_system.headshot_kills = score_data.headshot_kills
	
	if score_data.has("current_kill_streak"):
		score_system.current_kill_streak = score_data.current_kill_streak
	
	if score_data.has("best_kill_streak"):
		score_system.best_kill_streak = score_data.best_kill_streak
	
	if score_data.has("current_round_multiplier"):
		score_system.current_round_multiplier = score_data.current_round_multiplier
	
	print("✅ Datos de puntuación restaurados - Score: ", score_system.current_score)

func restore_barricades_data(game_manager: Node, barricades_data: Array):
	"""Restaurar estado de barricadas"""
	if not game_manager.wall_system:
		return
	
	var wall_system = game_manager.wall_system
	if not wall_system.has_method("get_all_barricades"):
		return
	
	var barricades = wall_system.get_all_barricades()
	
	for barricade_data in barricades_data:
		var barricade_name = barricade_data.get("name", "")
		
		# Buscar barricada por nombre
		for barricade in barricades:
			if is_instance_valid(barricade) and barricade.name == barricade_name:
				# Restaurar estado
				barricade.set_meta("current_planks", barricade_data.get("current_planks", 0))
				barricade.set_meta("max_planks", barricade_data.get("max_planks", 8))
				
				# Actualizar visibilidad de tablones
				var current_planks = barricade_data.get("current_planks", 0)
				var max_planks = barricade_data.get("max_planks", 8)
				
				for i in range(max_planks):
					var plank = barricade.get_node_or_null("Plank_" + str(i))
					if plank:
						plank.visible = i < current_planks
				
				break
	
	print("✅ Estado de barricadas restaurado")

func restore_doors_data(game_manager: Node, doors_data: Array):
	"""Restaurar estado de puertas"""
	if not game_manager.wall_system:
		return
	
	var wall_system = game_manager.wall_system
	if not wall_system.has_method("get_all_doors"):
		return
	
	var doors = wall_system.get_all_doors()
	
	for door_data in doors_data:
		var door_name = door_data.get("name", "")
		
		# Buscar puerta por nombre
		for door in doors:
			if is_instance_valid(door) and door.name == door_name:
				# Restaurar estado
				var is_open = door_data.get("is_open", false)
				door.set_meta("is_open", is_open)
				
				# Actualizar colisión y visibilidad
				if is_open:
					var collision = door.get_node_or_null("DoorBody/DoorCollision")
					if collision:
						collision.disabled = true
					
					var sprite = door.get_node_or_null("DoorSprite")
					if sprite:
						sprite.modulate.a = 0.0
						sprite.scale = Vector2.ZERO
				
				break
	
	print("✅ Estado de puertas restaurado")

func restore_spawner_data(game_manager: Node, spawner_data: Dictionary):
	"""Restaurar datos del spawner"""
	if not game_manager.enemy_spawner:
		return
	
	var spawner = game_manager.enemy_spawner
	
	# Restaurar variables del spawner
	if spawner_data.has("enemies_to_spawn"):
		spawner.enemies_to_spawn = spawner_data.enemies_to_spawn
	
	if spawner_data.has("enemies_spawned_this_round"):
		spawner.enemies_spawned_this_round = spawner_data.enemies_spawned_this_round
	
	if spawner_data.has("can_spawn"):
		spawner.can_spawn = spawner_data.can_spawn
	
	if spawner_data.has("current_round_number"):
		spawner.current_round_number = spawner_data.current_round_number
	
	if spawner_data.has("spawn_delay"):
		spawner.spawn_delay = spawner_data.spawn_delay
	
	print("✅ Datos del spawner restaurados")

func restore_enemies_data(game_manager: Node, enemies_data: Array):
	"""Restaurar enemigos activos"""
	if not game_manager.enemy_spawner or enemies_data.is_empty():
		return
	
	var spawner = game_manager.enemy_spawner
	
	# Limpiar enemigos actuales
	if spawner.has_method("clear_all_enemies"):
		spawner.clear_all_enemies()
	
	# Recrear enemigos desde datos guardados
	for enemy_data in enemies_data:
		var enemy = spawner.get_enemy_from_pool() if spawner.has_method("get_enemy_from_pool") else null
		
		if enemy and enemy.has_method("load_save_data"):
			enemy.load_save_data(enemy_data)
			
			# Configurar enemigo para que esté activo
			enemy.visible = true
			enemy.set_physics_process(true)
			enemy.set_process(true)
			
			# Añadir a la lista de enemigos activos
			if spawner.has_method("get") and spawner.has_method("set"):
				var active_enemies = spawner.get("active_enemies")
				if active_enemies:
					active_enemies.append(enemy)
	
	print("✅ Enemigos restaurados: ", enemies_data.size())

func has_complete_save() -> bool:
	"""Verificar si existe un guardado completo"""
	return FileAccess.file_exists(save_file_path)

func delete_save():
	"""Eliminar archivo de guardado"""
	if FileAccess.file_exists(save_file_path):
		DirAccess.remove_absolute(save_file_path)
		print("🗑️ Archivo de guardado eliminado")

func create_quick_save(game_manager: Node):
	"""Crear guardado rápido (solo datos esenciales)"""
	var quick_data = {
		"timestamp": Time.get_unix_time_from_system(),
		"current_round": game_manager.rounds_manager.get_current_round() if game_manager.rounds_manager else 1,
		"current_score": game_manager.score_system.get_current_score() if game_manager.score_system else 0,
		"player_health": game_manager.player.get_current_health() if game_manager.player else 4,
		"was_paused": true
	}
	
	var file = FileAccess.open(quick_save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(quick_data))
		file.close()

func should_show_pause_menu_on_start() -> bool:
	"""Verificar si debe mostrar el menú de pausa al iniciar"""
	if not has_complete_save():
		return false
	
	var file = FileAccess.open(save_file_path, FileAccess.READ)
	if not file:
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		return false
	
	var save_data = json.data
	return save_data.get("was_paused", false)
