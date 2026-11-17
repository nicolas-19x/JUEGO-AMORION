extends Node
## Audio: buses separados (Música, Efectos, Ambiente) con volumen y silencio
## independientes. La ambientación cambia entre el día (olas + pájaros) y la noche
## (olas suaves + grillos).

const AUDIO := "res://assets/audio/"
const BUSES := {"Music": "music", "SFX": "sfx", "Ambient": "ambient"}

var _music: AudioStreamPlayer
var _waves: AudioStreamPlayer
var _night: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _bird_timer := 4.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	_music = _make_player("Music")
	_waves = _make_player("Ambient")
	_night = _make_player("Ambient")
	for i in 6:
		_sfx_pool.append(_make_player("SFX"))
	apply_volumes()
	Settings.changed.connect(func(_k: String) -> void: apply_volumes())


func start_world_audio() -> void:
	_play_loop(_music, "music_island", -6.0)
	_play_loop(_waves, "amb_waves", -4.0)
	_play_loop(_night, "amb_night", -60.0)


func _process(delta: float) -> void:
	if _night.playing:
		var n := WorldClock.night_factor()
		_night.volume_db = linear_to_db(maxf(0.0001, n * 0.9))
		_waves.volume_db = linear_to_db(1.0 - n * 0.35) - 4.0
		_bird_timer -= delta
		if _bird_timer <= 0.0:
			_bird_timer = _rng.randf_range(5.0, 14.0)
			if n < 0.4:
				play("bird_%d" % _rng.randi_range(0, 2), -10.0, _rng.randf_range(0.9, 1.15))


func apply_volumes() -> void:
	for bus_name in BUSES:
		var key: String = BUSES[bus_name]
		var idx := AudioServer.get_bus_index(bus_name)
		var vol: float = Settings.get_value("volume_" + key)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.0001, vol)))
		AudioServer.set_bus_mute(idx, Settings.get_value("mute_" + key) or vol <= 0.001)


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var stream := _stream(sound)
	if stream == null:
		return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return


func footstep(surface: String) -> void:
	play("step_%s_%d" % [surface, _rng.randi_range(0, 1)], -14.0, _rng.randf_range(0.92, 1.08))


func _play_loop(player: AudioStreamPlayer, sound: String, volume_db: float) -> void:
	var stream := _stream(sound)
	if stream == null:
		return
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		# en muestras (no en bytes: Godot puede comprimir el WAV al importarlo)
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func _stream(sound: String) -> AudioStream:
	if not _streams.has(sound):
		var path := AUDIO + sound + ".wav"
		_streams[sound] = load(path) if ResourceLoader.exists(path) else null
	return _streams[sound]


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p
