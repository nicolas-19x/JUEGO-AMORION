class_name WorldCamera
extends Camera2D
## Cámara que sigue al personaje con suavidad, limitada a la isla,
## y con un modo «cinemático» para lugares especiales como el mirador.

var target: Node2D
var cinematic := false
var follow_offset := Vector2(0, -14)
var _cine_goal := Vector2.ZERO
## Modo construcción: la cámara se mueve con el dedo en lugar de seguir al personaje.
var free_mode := false
var free_goal := Vector2.ZERO


func _ready() -> void:
	position_smoothing_enabled = false  # el suavizado se hace a mano (más estable con píxeles)
	process_callback = Camera2D.CAMERA2D_PROCESS_IDLE


func set_bounds(rect: Rect2) -> void:
	limit_left = int(rect.position.x)
	limit_top = int(rect.position.y)
	limit_right = int(rect.end.x)
	limit_bottom = int(rect.end.y)


func snap_to_target() -> void:
	if target:
		global_position = target.global_position + follow_offset


func _process(delta: float) -> void:
	var goal := _cine_goal if cinematic else (target.global_position + follow_offset if target else global_position)
	if free_mode and not cinematic:
		goal = free_goal
	var speed := 1.6 if cinematic else (14.0 if free_mode else 7.0)
	global_position = global_position.lerp(goal, 1.0 - exp(-delta * speed))


func start_cinematic(goal: Vector2) -> void:
	cinematic = true
	_cine_goal = goal


func end_cinematic() -> void:
	cinematic = false


## Desplaza la vista libre (modo construcción), sin salir de la isla.
func pan(world_delta: Vector2, view_size: Vector2) -> void:
	var half := view_size / 2.0
	free_goal += world_delta
	free_goal.x = clampf(free_goal.x, limit_left + half.x, maxf(limit_left + half.x, limit_right - half.x))
	free_goal.y = clampf(free_goal.y, limit_top + half.y, maxf(limit_top + half.y, limit_bottom - half.y))
