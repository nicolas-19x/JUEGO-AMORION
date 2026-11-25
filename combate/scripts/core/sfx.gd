extends Node
## Sonido del juego.
##
## · Bancos de variantes: nunca suena la misma dos veces seguidas y el tono varía un poco.
## · Los efectos y voces son de ElevenLabs (assets/audio/eleven, ver docs/AUDIO.md);
##   los golpes llevan debajo una capa grave sintetizada (assets/audio, syn_*) para dar peso.
## · Voces por hablante: cada luchador tiene su tono y no se pisa a sí mismo.
## · Música: menú y combate, con fundido entre ellas; el ambiente suena siempre.

const DIR := "res://assets/audio/eleven/"
const SYN := "res://assets/audio/"
const BANKS := {
	"hit_l": 4, "hit_m": 4, "hit_h": 4, "hit_b": 3, "hit_k": 3, "block": 3, "step": 4, "parry": 2,
	"fall": 3, "wall": 3, "ko": 2, "ui_tap": 2, "gong": 2, "win": 2, "lose": 2,
	"whoosh_p": 3, "whoosh_k": 3,
	"effort": 4, "pain": 4, "winded": 3, "scream": 3, "breath": 2, "spit": 3,
	"vo_combate": 2, "vo_victoria": 2, "vo_derrota": 2,
}
# capa grave sintetizada (nombre del banco → [archivo, variantes])
const SYN_BANKS := {
	"syn_hit_l": ["hit_l", 4], "syn_hit_m": ["hit_m", 3], "syn_hit_h": ["hit_h", 3],
	"syn_block": ["block", 3], "syn_wet": ["wet", 3],
}
const SYN_ONE := {"syn_parry": "parry", "syn_fall": "fall", "syn_wall": "wall", "syn_ko": "ko"}

var _banks := {}
var _last := {}
var _players: Array[AudioStreamPlayer] = []
var _voice_players: Array[AudioStreamPlayer] = []
var _next := 0
var _next_voice := 0
var _voice_t := {}           # hablante → último instante de voz (s)
var ambience: AudioStreamPlayer
var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var _music_mode := ""
var _music_db := -11.0
var _duck := 0.0
var _duck_tween: Tween
var master_music := 1.0      # multiplicador 0..1 (ajustes)
var master_voice := 1.0
var last_played := ""        # para pruebas


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bank in BANKS:
		var arr := []
		for i in int(BANKS[bank]):
			var s: AudioStream = load(DIR + "%s_%d.ogg" % [bank, i])
			if s:
				arr.append(s)
		_banks[bank] = arr
	for bank in SYN_BANKS:
		var arr := []
		for i in int(SYN_BANKS[bank][1]):
			arr.append(load(SYN + "%s_%d.wav" % [SYN_BANKS[bank][0], i]))
		_banks[bank] = arr
	for bank in SYN_ONE:
		_banks[bank] = [load(SYN + SYN_ONE[bank] + ".wav")]
	for i in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for i in 5:
		var v := AudioStreamPlayer.new()
		add_child(v)
		_voice_players.append(v)
	ambience = _loop_player(DIR + "amb_0.ogg", -19.0)
	music_a = _loop_player(DIR + "music_menu_0.ogg", -80.0)
	music_b = _loop_player(DIR + "music_combat_1.ogg", -80.0)


func _loop_player(path: String, db: float) -> AudioStreamPlayer:
	var s: AudioStream = load(path)
	var p := AudioStreamPlayer.new()
	if s is AudioStreamOggVorbis:
		s = s.duplicate()
		(s as AudioStreamOggVorbis).loop = true
	p.stream = s
	p.volume_db = db
	add_child(p)
	return p


func bank_size(bank: String) -> int:
	return (_banks.get(bank, []) as Array).size()


## Reproduce una variante del banco, nunca la misma dos veces seguidas.
func play(bank: String, db := 0.0, pitch := 1.0, pitch_var := 0.06) -> void:
	var arr: Array = _banks.get(bank, [])
	if arr.is_empty():
		return
	last_played = bank
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _pick(bank, arr)
	p.volume_db = db
	p.pitch_scale = pitch * randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	p.play()


## Voz de un luchador. speaker: "player" o "foe" (el rival tiene la voz algo más grave).
## min_gap: segundos mínimos entre dos voces del mismo hablante (evita metralleta).
func voice(speaker: String, bank: String, db := 0.0, min_gap := 0.22, pitch_mul := 1.0) -> bool:
	var arr: Array = _banks.get(bank, [])
	if arr.is_empty() or master_voice <= 0.0:
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_voice_t.get(speaker, -9.0)) < min_gap:
		return false
	_voice_t[speaker] = now
	last_played = bank
	var p := _voice_players[_next_voice]
	_next_voice = (_next_voice + 1) % _voice_players.size()
	p.stream = _pick(bank, arr)
	p.volume_db = db + linear_to_db(master_voice)
	var base := 1.0 if speaker == "player" else 0.84
	p.pitch_scale = base * pitch_mul * randf_range(0.96, 1.04)
	p.play()
	return true


## El locutor y los avisos del juego no dependen de ningún luchador.
func announcer(bank: String, db := 0.0) -> void:
	var arr: Array = _banks.get(bank, [])
	if arr.is_empty() or master_voice <= 0.0:
		return
	last_played = bank
	var p := _voice_players[_next_voice]
	_next_voice = (_next_voice + 1) % _voice_players.size()
	p.stream = _pick(bank, arr)
	p.volume_db = db + linear_to_db(master_voice)
	p.pitch_scale = 1.0
	p.play()


func _pick(bank: String, arr: Array) -> AudioStream:
	var i := randi() % arr.size()
	if arr.size() > 1 and i == _last.get(bank, -1):
		i = (i + 1 + randi() % (arr.size() - 1)) % arr.size()
	_last[bank] = i
	return arr[i]


# ---------------------------------------------------------------------------
# Música y ambiente
# ---------------------------------------------------------------------------

func start_music() -> void:
	if not ambience.playing:
		ambience.play()
	set_music("menu", 0.01)


## modo: "menu", "combat" u "off". Fundido cruzado entre pistas.
func set_music(mode: String, time := 1.6) -> void:
	if mode == _music_mode:
		return
	_music_mode = mode
	var tw := create_tween()
	tw.set_parallel(true)
	var want_a := -80.0
	var want_b := -80.0
	if mode == "menu":
		want_a = _music_db + linear_to_db(master_music)
		if not music_a.playing:
			music_a.play()
	elif mode == "combat":
		want_b = _music_db + 1.0 + linear_to_db(master_music)
		music_b.play()   # el combate arranca siempre desde el principio
	tw.tween_property(music_a, "volume_db", want_a, time)
	tw.tween_property(music_b, "volume_db", want_b, time)
	tw.chain().tween_callback(func():
		if _music_mode != "menu" and music_a.volume_db < -70.0:
			music_a.stop()
		if _music_mode != "combat" and music_b.volume_db < -70.0:
			music_b.stop())


## Baja la música unos instantes (golpes grandes, KO, locutor).
func duck(db: float, hold := 0.5, release := 0.9) -> void:
	if _duck_tween:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_duck, _duck, db, 0.05)
	_duck_tween.tween_interval(hold)
	_duck_tween.tween_method(_set_duck, db, 0.0, release)


func _set_duck(v: float) -> void:
	_duck = v
	ambience.volume_db = -19.0 + v * 0.5
	if _music_mode == "menu":
		music_a.volume_db = _music_db + linear_to_db(master_music) + v
	elif _music_mode == "combat":
		music_b.volume_db = _music_db + 1.0 + linear_to_db(master_music) + v


func set_master_music(v: float) -> void:
	master_music = clampf(v, 0.0, 1.0)
	_set_duck(_duck)
