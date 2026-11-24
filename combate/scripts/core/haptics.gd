extends Node
## Vibración con matices: cada tipo de impacto tiene su patrón de pulsos
## (instante en ms, duración en ms, intensidad 0..1). Se reproduce en tiempo real
## aunque el juego esté a cámara lenta. Recibir golpes vibra algo más fuerte que darlos.

const PATTERNS := {
	"light": [[0, 14, 0.35]],
	"medium": [[0, 22, 0.55], [45, 10, 0.25]],
	"heavy": [[0, 36, 0.9], [60, 18, 0.45], [110, 10, 0.2]],
	"counter": [[0, 30, 1.0], [55, 28, 0.75], [125, 45, 0.45]],
	"block": [[0, 10, 0.22]],
	"parry": [[0, 8, 1.0], [42, 8, 0.7]],
	"guard_break": [[0, 26, 0.8], [75, 26, 0.8]],
	"wall": [[0, 55, 1.0], [85, 25, 0.5], [150, 40, 0.35]],
	"fall": [[0, 30, 0.6], [95, 14, 0.3]],
	"ko": [[0, 80, 1.0], [160, 50, 0.6], [320, 130, 0.35]],
	"evade": [[0, 6, 0.5]],
}

var intensity := 1.0
var _queue: Array = []
var _start := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Lanza un patrón. received = el jugador lo recibe (un poco más fuerte).
func play(name: String, received := false) -> void:
	if intensity <= 0.0 or not PATTERNS.has(name):
		return
	last = name
	var now := Time.get_ticks_msec()
	var k := intensity * (1.15 if received else 1.0)
	for p in PATTERNS[name]:
		_queue.append([now + int(p[0]), int(p[1]), clampf(float(p[2]) * k, 0.05, 1.0)])
	_queue.sort_custom(func(a, b): return a[0] < b[0])


## Último patrón pedido (para las pruebas).
var last := ""


func _process(_delta: float) -> void:
	if _queue.is_empty():
		return
	var now := Time.get_ticks_msec()
	while not _queue.is_empty() and int(_queue[0][0]) <= now:
		var p: Array = _queue.pop_front()
		if OS.has_feature("mobile"):
			Input.vibrate_handheld(int(p[1]), float(p[2]))
