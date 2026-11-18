extends Node
## Reloj del mundo. Por defecto sigue la hora real del teléfono: si jugáis de
## noche, en la isla también es de noche. Se puede fijar un momento del día.

signal phase_changed(phase: String)

const FIXED := {"dawn": 6.4, "day": 12.0, "sunset": 18.6, "night": 22.5}
## Colores ambientales por hora (CanvasModulate).
const KEYS := [
	[0.0, Color(0.36, 0.40, 0.66)],
	[4.8, Color(0.40, 0.42, 0.68)],
	[6.0, Color(0.86, 0.70, 0.72)],
	[7.2, Color(1.0, 0.93, 0.86)],
	[9.0, Color(1.0, 0.985, 0.95)],
	[16.5, Color(1.0, 0.965, 0.9)],
	[18.2, Color(1.0, 0.80, 0.66)],
	[19.3, Color(0.78, 0.60, 0.74)],
	[20.4, Color(0.42, 0.44, 0.70)],
	[24.0, Color(0.36, 0.40, 0.66)],
]

var hour := 12.0
var _cycle_hour := 8.0
var _phase := ""


func _process(delta: float) -> void:
	var mode: String = Settings.get_value("time_mode")
	if FIXED.has(mode):
		hour = FIXED[mode]
	elif mode == "cycle":  # un día completo cada 6 minutos (para probar)
		_cycle_hour = fmod(_cycle_hour + delta * 24.0 / 360.0, 24.0)
		hour = _cycle_hour
	else:
		var t := Time.get_time_dict_from_system()
		hour = t["hour"] + t["minute"] / 60.0 + t["second"] / 3600.0
	var p := phase_name()
	if p != _phase:
		_phase = p
		phase_changed.emit(p)


func ambient_color() -> Color:
	for i in range(KEYS.size() - 1):
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if hour >= a[0] and hour <= b[0]:
			var t: float = (hour - a[0]) / max(0.001, b[0] - a[0])
			return (a[1] as Color).lerp(b[1], smoothstep(0.0, 1.0, t))
	return KEYS[0][1]


## 0 = pleno día, 1 = noche cerrada. Controla faroles, ventanas y luciérnagas.
func night_factor() -> float:
	if hour >= 17.8 and hour < 20.6:
		return smoothstep(17.8, 20.6, hour)
	if hour >= 5.2 and hour < 7.4:
		return 1.0 - smoothstep(5.2, 7.4, hour)
	if hour >= 7.4 and hour < 17.8:
		return 0.0
	return 1.0


func phase_name() -> String:
	if hour < 5.2 or hour >= 20.6:
		return "Noche"
	if hour < 7.4:
		return "Amanecer"
	if hour < 17.8:
		return "Día"
	return "Atardecer"


func clock_text() -> String:
	var h := int(hour)
	var m := int((hour - h) * 60.0)
	return "%02d:%02d" % [h, m]
