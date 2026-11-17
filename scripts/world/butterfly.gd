class_name Butterfly
extends Node2D
## Mariposa que revolotea cerca de su flor durante el día.

var home := Vector2.ZERO
var _t := 0.0
var _seed := 0.0
var _sprite: Sprite2D


func _ready() -> void:
	_seed = randf() * 100.0
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/fx/butterfly.png")
	_sprite.hframes = 2
	add_child(_sprite)
	z_index = 4


func _process(delta: float) -> void:
	_t += delta
	var night := WorldClock.night_factor()
	visible = night < 0.5
	if not visible:
		return
	var p := Vector2(sin(_t * 0.7 + _seed) * 22.0 + sin(_t * 1.9 + _seed) * 6.0,
			cos(_t * 0.5 + _seed) * 12.0 - 14.0 + sin(_t * 3.1) * 3.0)
	position = (home + p).round()
	_sprite.frame = int(_t * 9.0) % 2
	_sprite.flip_h = cos(_t * 0.7 + _seed) < 0.0
