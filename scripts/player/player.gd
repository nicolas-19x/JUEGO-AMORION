class_name Player
extends CharacterBody2D
## Personaje jugable. Movimiento analógico con el joystick, animación en cuatro
## direcciones (caminar, reposo, sentado) y pasos con sonido según el suelo.

signal stepped(world_pos: Vector2)

const SPEED := 70.0
const ACCEL := 600.0
const WALK_FPS := 8.0
const WALK_COLS := [2, 3, 4, 5]

enum State { FREE, SITTING, LOCKED }

var state := State.FREE
var facing := "down"
var appearance: CharacterAppearance
var _anim_time := 0.0
var _last_col := -1


func _ready() -> void:
	var shadow := Sprite2D.new()
	shadow.texture = load("res://assets/fx/player_shadow.png")
	shadow.position = Vector2(0, -1)
	add_child(shadow)
	appearance = CharacterAppearance.new()
	add_child(appearance)
	appearance.apply(Settings.character_preset())
	appearance.set_frame(facing, 0)


func _physics_process(delta: float) -> void:
	var move := InputHub.get_move()
	match state:
		State.LOCKED:
			velocity = Vector2.ZERO
			_animate_idle(delta)
			return
		State.SITTING:
			if move.length() > 0.5:
				stand_up()
			else:
				appearance.set_frame(facing, 6)
				return
	var target := move * SPEED
	velocity = velocity.move_toward(target, ACCEL * delta)
	move_and_slide()
	if move.length() > 0.15:
		_update_facing(move)
		_animate_walk(delta, velocity.length() / SPEED)
	else:
		_animate_idle(delta)


func sit_at(seat_pos: Vector2) -> void:
	state = State.SITTING
	velocity = Vector2.ZERO
	global_position = seat_pos
	facing = "down"
	appearance.set_frame(facing, 6)
	AudioDirector.play("click", -12.0, 0.8)


func stand_up() -> void:
	state = State.FREE
	global_position += Vector2(0, 8)


func lock(locked: bool) -> void:
	if locked:
		state = State.LOCKED
	elif state == State.LOCKED:
		state = State.FREE


func facing_vector() -> Vector2:
	match facing:
		"up":
			return Vector2.UP
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
	return Vector2.DOWN


func _update_facing(move: Vector2) -> void:
	# histéresis: cambiar de eje solo cuando el nuevo domina claramente
	var horizontal := facing == "left" or facing == "right"
	var bias := 1.25
	if horizontal:
		if absf(move.y) > absf(move.x) * bias:
			facing = "down" if move.y > 0 else "up"
		else:
			facing = "right" if move.x > 0 else "left"
	else:
		if absf(move.x) > absf(move.y) * bias:
			facing = "right" if move.x > 0 else "left"
		else:
			facing = "down" if move.y > 0 else "up"


func _animate_walk(delta: float, speed_ratio: float) -> void:
	_anim_time += delta * WALK_FPS * clampf(speed_ratio, 0.5, 1.2)
	var col: int = WALK_COLS[int(_anim_time) % 4]
	appearance.set_frame(facing, col)
	if col != _last_col and (col == 3 or col == 5):
		stepped.emit(global_position)
	_last_col = col


func _animate_idle(delta: float) -> void:
	_anim_time += delta
	var col := 1 if fmod(_anim_time, 1.6) > 1.1 else 0
	appearance.set_frame(facing, col)
	_last_col = -1
