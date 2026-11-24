extends Node
## Sonido: grupo de reproductores, variantes sin repetición inmediata y tono variable.

const DIR := "res://assets/audio/"
var _banks := {}
var _last := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var ambience: AudioStreamPlayer
var drums: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bank in [["hit_l", 4], ["hit_m", 3], ["hit_h", 3], ["block", 3], ["whoosh", 3], ["step", 4], ["wet", 3]]:
		var arr := []
		for i in bank[1]:
			arr.append(load(DIR + "%s_%d.wav" % [bank[0], i]))
		_banks[bank[0]] = arr
	for one in ["parry", "fall", "wall", "ko", "prop", "ui_tap", "ui_go"]:
		_banks[one] = [load(DIR + one + ".wav")]
	for i in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	ambience = _loop_player("ambience", -14.0)
	drums = _loop_player("drums", -80.0)


func _loop_player(id: String, db: float) -> AudioStreamPlayer:
	var s: AudioStreamWAV = load(DIR + id + ".wav")
	s = s.duplicate()
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate)
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = db
	add_child(p)
	return p


## Reproduce una variante del banco, nunca la misma dos veces seguidas.
func play(bank: String, db := 0.0, pitch := 1.0, pitch_var := 0.06) -> void:
	var arr: Array = _banks.get(bank, [])
	if arr.is_empty():
		return
	var i := randi() % arr.size()
	if arr.size() > 1 and i == _last.get(bank, -1):
		i = (i + 1 + randi() % (arr.size() - 1)) % arr.size()
	_last[bank] = i
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = arr[i]
	p.volume_db = db
	p.pitch_scale = pitch * randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	p.play()


func start_music() -> void:
	if not ambience.playing:
		ambience.play()
	if not drums.playing:
		drums.play()


func set_drums(target_db: float, time := 1.5) -> void:
	var tw := create_tween()
	tw.tween_property(drums, "volume_db", target_db, time)
