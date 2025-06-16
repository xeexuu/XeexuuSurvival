# scenes/enemies/BaseEnemy.gd - CLASE BASE PARA TODOS LOS ENEMIGOS
extends CharacterBody2D
class_name BaseEnemy

signal died(enemy: BaseEnemy)
signal damaged(enemy: BaseEnemy, damage: int)

@export var max_health: int = 100
@export var current_health: int = 100
@export var base_move_speed: float = 120.0
@export var damage: int = 50
@export var attack_range: float = 45.0
@export var detection_range: float = 600.0
@export var enemy_type: String = "basic"

@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D
@onready var attack_timer = $AttackTimer
@onready var health_bar = $HealthBar

var player: Player = null
var is_dead: bool = false
var last_attack_time: float = 0.0
var attack_cooldown: float = 2.0
var current_move_speed: float = 120.0

# Estados base
enum EnemyState {
	SPAWNING,
	IDLE,
	PURSUING,
	ATTACKING,
	STUNNED,
	DEAD
}

var current_state: EnemyState = EnemyState.SPAWNING
var state_timer: float = 0.0

# Variables de movimiento
var target_position: Vector2
var stuck_timer: float = 0.0
var last_position: Vector2

# Sprites
var enemy_sprite_frames: SpriteFrames
var is_sprite_loaded: bool = false

func _ready():
	setup_enemy()
	setup_attack_system()

func setup_enemy():
	"""Configurar enemigo base"""
	current_health = max_health
	is_dead = false
	current_state = EnemyState.SPAWNING
	
	collision_layer = 2
	collision_mask = 1 | 3
	
	last_position = global_position
	target_position = global_position
	
	if not is_sprite_loaded:
		create_default_sprite()
	
	setup_health_bar()
	
	if attack_timer:
		attack_timer.wait_time = attack_cooldown
		attack_timer.one_shot = true
		attack_timer.timeout.connect(_on_attack_timer_timeout)

func create_default_sprite():
	"""Crear sprite por defecto - SOBREESCRIBIR EN CLASES HIJAS"""
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	
	var default_texture = ImageTexture.create_from_image(image)
	
	if sprite:
		if sprite is Sprite2D:
			var normal_sprite = sprite as Sprite2D
			normal_sprite.texture = default_texture
			normal_sprite.scale = Vector2(0.75, 0.75)

func setup_health_bar():
	"""Configurar barra de vida"""
	if not health_bar:
		health_bar = ProgressBar.new()
		health_bar.size = Vector2(60, 8)
		health_bar.position = Vector2(-30, -40)
		add_child(health_bar)
	
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_bar.show_percentage = false

func setup_attack_system():
	"""Configurar sistema de ataque"""
	pass

func setup_for_spawn(target_player: Player, round_health: int = -1):
	"""Configurar para spawn"""
	player = target_player
	
	if round_health > 0:
		max_health = round_health
		current_health = max_health
	
	is_dead = false
	current_state = EnemyState.SPAWNING
	
	call_deferred("_reactivate_collision")
	
	if sprite:
		sprite.visible = true
	
	update_health_bar()

func _reactivate_collision():
	"""Reactivar colisión"""
	if collision_shape and is_instance_valid(collision_shape):
		collision_shape.disabled = false

func reset_for_pool():
	"""Reset para pool"""
	is_dead = false
	current_state = EnemyState.SPAWNING
	current_health = max_health
	
	call_deferred("_deactivate_collision")
	
	if sprite:
		sprite.visible = false
	
	set_physics_process(false)
	set_process(false)

func _deactivate_collision():
	"""Desactivar colisión"""
	if collision_shape and is_instance_valid(collision_shape):
		collision_shape.disabled = true

func _physics_process(delta):
	"""Procesamiento de física base"""
	if is_dead or not player or not is_instance_valid(player):
		return
	
	update_state_machine(delta)
	handle_movement(delta)
	handle_combat()
	
	move_and_slide()

func update_state_machine(delta):
	"""Máquina de estados base - SOBREESCRIBIR EN CLASES HIJAS"""
	state_timer += delta
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	match current_state:
		EnemyState.SPAWNING:
			if state_timer > 0.5:
				current_state = EnemyState.IDLE
				state_timer = 0.0
		
		EnemyState.IDLE:
			if distance_to_player <= detection_range:
				current_state = EnemyState.PURSUING
				state_timer = 0.0
		
		EnemyState.PURSUING:
			if distance_to_player <= attack_range:
				current_state = EnemyState.ATTACKING
				state_timer = 0.0
			elif distance_to_player > detection_range * 1.2:
				current_state = EnemyState.IDLE
				state_timer = 0.0

func handle_movement(delta):
	"""Manejo de movimiento base"""
	var movement_direction = Vector2.ZERO
	
	match current_state:
		EnemyState.PURSUING, EnemyState.ATTACKING:
			movement_direction = get_pursuit_direction()
		EnemyState.STUNNED:
			movement_direction = velocity * 0.1
	
	if movement_direction != Vector2.ZERO:
		velocity = movement_direction.normalized() * current_move_speed

func get_pursuit_direction() -> Vector2:
	"""Obtener dirección de persecución"""
	if not player:
		return Vector2.ZERO
	
	return (player.global_position - global_position).normalized()

func handle_combat():
	"""Manejo de combate"""
	if not player or current_state != EnemyState.ATTACKING:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player <= attack_range and can_attack():
		perform_attack()

func can_attack() -> bool:
	"""Verificar si puede atacar"""
	var current_time = Time.get_ticks_msec() / 1000.0
	return current_time - last_attack_time >= attack_cooldown

func perform_attack():
	"""Realizar ataque"""
	if not player or not player.has_method("take_damage"):
		return
	
	last_attack_time = Time.get_ticks_msec() / 1000.0
	
	player.take_damage(damage)
	
	if sprite:
		sprite.modulate = Color.ORANGE_RED
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)

func _on_attack_timer_timeout():
	"""Timeout del timer de ataque"""
	pass

func take_damage(amount: int, is_headshot: bool = false):
	"""Recibir daño"""
	if is_dead:
		return
	
	current_health -= amount
	current_health = max(current_health, 0)
	
	current_state = EnemyState.STUNNED
	state_timer = 0.0
	
	if sprite:
		if is_headshot:
			sprite.modulate = Color.YELLOW
		else:
			sprite.modulate = Color.RED
		
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	
	update_health_bar()
	damaged.emit(self, amount)
	
	if current_health <= 0:
		die()

func die():
	"""Muerte del enemigo"""
	if is_dead:
		return
	
	is_dead = true
	current_state = EnemyState.DEAD
	
	call_deferred("_deactivate_collision")
	
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	if sprite:
		sprite.modulate = Color.GRAY
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 1.5)
	
	if health_bar:
		health_bar.visible = false
	
	died.emit(self)

func update_health_bar():
	"""Actualizar barra de vida"""
	if not health_bar:
		return
	
	health_bar.value = current_health
	health_bar.max_value = max_health

func set_enemy_type(new_type: String):
	"""Establecer tipo de enemigo"""
	enemy_type = new_type

# Funciones de información
func get_current_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func is_alive() -> bool:
	return current_health > 0 and not is_dead

func get_damage() -> int:
	return damage

func get_enemy_type() -> String:
	return enemy_type

func _exit_tree():
	"""Limpiar al salir"""
	set_physics_process(false)
	set_process(false)
