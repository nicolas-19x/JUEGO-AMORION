extends Node
## Punto único de entrada de movimiento. El joystick táctil escribe aquí;
## el teclado solo existe como ayuda para probar en el editor.

var touch_vector := Vector2.ZERO


func get_move() -> Vector2:
	if touch_vector.length() > 0.05:
		return touch_vector.limit_length(1.0)
	var k := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
			- float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
			- float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	return k.normalized()
