class_name AiBrain
extends RefCounted
## Rival controlado por la IA. Sencilla pero con carácter:
##  · Mantiene una distancia de tanteo, entra y sale, rodea al jugador.
##  · Lee la preparación de los golpes del jugador y reacciona con un retraso
##    humano: bloquea, esquiva o (a veces) para. También se equivoca.
##  · Castiga golpes fallados, encadena combos de longitud variable y cambia de
##    humor (agresivo / prudente) según cómo va el combate.
##  · Si queda arrinconado, rodea hacia el centro en lugar de atascarse.

var me: Fighter
var foe: Fighter
var level := 1  # 0 aprendiz, 1 duelo, 2 maestro

var mood := "neutral"
var mood_t := 0.0
var strafe := 1.0
var strafe_t := 0.0
var pref_range := 1.8
var think_t := 0.0
var attack_cd := 1.0
var combo_left := 0
var _seen_attack := {}
var _react_at := -1.0
var _react_kind := ""
var _guard_until := 0.0
var _guard_pending := 0.0
var _t := 0.0
var _last_hp := 100.0


func _init(p_me: Fighter, p_foe: Fighter, p_level: int) -> void:
	me = p_me
	foe = p_foe
	level = p_level
	_last_hp = me.hp


func _p(easy: float, mid: float, hard: float) -> float:
	return [easy, mid, hard][level]


func update(delta: float) -> void:
	_t += delta
	var c := me.ctrl
	c.move = Vector3.ZERO
	c.attack_held = false
	if me.state == "ko" or foe.state == "ko":
		c.guard = false
		return
	var to_foe := foe.global_position - me.global_position
	to_foe.y = 0
	var dist := to_foe.length()
	var fwd := to_foe.normalized() if dist > 0.01 else Vector3.FORWARD
	var right := fwd.cross(Vector3.UP)

	# humor: tras recibir daño se vuelve prudente un momento, luego contraataca
	if me.hp < _last_hp - 0.1:
		# bajo presión: subir la guardia en cuanto pueda (como haría una persona)
		if randf() < _p(0.35, 0.6, 0.85):
			_guard_pending = randf_range(0.5, 1.0)
		mood = "cautious" if randf() < _p(0.7, 0.5, 0.35) else "aggressive"
		mood_t = randf_range(0.8, 1.8)
		attack_cd = maxf(attack_cd, _p(0.9, 0.5, 0.3))
	_last_hp = me.hp
	mood_t -= delta
	# acorralada y presionada: cambia a agresiva para salir intercambiando
	if me.combo_taken >= 2 and mood == "cautious" and randf() < _p(0.002, 0.01, 0.02):
		mood = "aggressive"
		mood_t = 1.5
	if mood_t <= 0.0:
		var r := randf()
		mood = "aggressive" if r < _p(0.25, 0.4, 0.5) else ("cautious" if r < 0.6 else "neutral")
		mood_t = randf_range(1.5, 3.5)
		pref_range = randf_range(1.55, 2.2)

	# --- defensa: leer la preparación del golpe del jugador ---------------------
	if foe.state == "attack" and foe.move.has("hit"):
		var id := "%s@%d" % [foe.move.name, int(foe.time * 10.0 - foe.move_t * 10.0)]
		if not _seen_attack.has(id):
			_seen_attack[id] = true
			if _seen_attack.size() > 40:
				_seen_attack.clear()
			_plan_defense(dist)
	if _react_at >= 0.0 and _t >= _react_at and me.can_act():
		match _react_kind:
			"block":
				_guard_until = _t + randf_range(0.35, 0.6)
			"parry":
				c.guard_pressed = true
				_guard_until = _t + 0.3
			"dodge":
				var side := strafe if randf() < 0.6 else -strafe
				# esquiva lateral (abre contraataque); a veces solo un paso atrás
				c.dodge = right * side if randf() < _p(0.4, 0.7, 0.9) else (right * side - fwd).normalized()
		_react_at = -1.0
	if _guard_pending > 0.0 and me.can_act():
		_guard_until = _t + _guard_pending
		_guard_pending = 0.0
	# tras bloquear el final de una serie, contraataca en el hueco
	if me.state == "block" and foe.state == "attack" and foe.move.get("chain", "") == "" and foe.move.has("hit") \
			and foe.move_t > float(foe.move.hit.to) and dist < 1.7 and randf() < _p(0.2, 0.45, 0.7):
		_guard_until = 0.0
		_attack(dist, true)
		return
	# si el jugador presiona de cerca, a veces se cubre sin esperar a verlo
	if foe.state == "attack" and dist < 1.6 and me.can_act() and _t > _guard_until and randf() < _p(0.01, 0.03, 0.06):
		_guard_until = _t + randf_range(0.3, 0.6)
	c.guard = _t < _guard_until and me.can_act()
	if c.guard:
		# bajo la guardia se mueve poco
		c.move = -fwd * 0.3 if dist < 1.2 else Vector3.ZERO
		return

	# tras esquivar un golpe: contraataque (más a menudo cuanto mejor es)
	if me.counter_t > 0.0 and me.can_act() and randf() < _p(0.04, 0.12, 0.3):
		c.light = true
		return
	if not me.can_act():
		# durante un combo propio: decidir si lo continúa
		if me.state == "attack" and combo_left > 0 and me.move_t > float(me.move.get("cancel", 99.0)) - 0.1:
			if not me.move.get("ender", false):
				if combo_left == 1 and randf() < 0.5:
					c.kick = true
				else:
					c.punch = true
				combo_left -= 1
		return

	attack_cd -= delta
	strafe_t -= delta
	if strafe_t <= 0.0:
		strafe = -strafe if randf() < 0.6 else strafe
		strafe_t = randf_range(0.9, 2.4)

	# remate si el jugador está aturdido
	if foe.is_vulnerable_to_special() and dist < 2.0 and randf() < _p(0.02, 0.05, 0.12):
		c.special = true
		return

	# castigar un golpe fallado del jugador
	var foe_recovering := foe.state == "attack" and foe.move.has("hit") and foe.move_t > float(foe.move.hit.to) + 0.04 and not foe.hit_done
	if foe_recovering and dist < 1.6 and randf() < _p(0.03, 0.12, 0.3):
		_attack(dist, true)
		return

	# espaciado
	var want := pref_range
	if mood == "aggressive":
		want = 1.25
	elif mood == "cautious":
		want = pref_range + 0.5
	if attack_cd <= 0.0:
		want = 1.15  # lista para golpear: entra en distancia
	var mv := Vector3.ZERO
	if dist > want + 0.25:
		mv += fwd
	elif dist < want - 0.25:
		mv -= fwd * 0.8
	mv += right * strafe * (0.55 if mood != "aggressive" else 0.3)
	# evitar quedar arrinconado: rodear hacia el centro
	var from_center := Vector3(me.global_position.x, 0, me.global_position.z)
	if from_center.length() > 3.2:
		var inward := -from_center.normalized()
		mv += inward * 0.9
		if right.dot(inward) * strafe < 0.0:
			strafe = -strafe
	c.move = mv.limit_length(1.0)

	# atacar
	if attack_cd <= 0.0:
		var reach := 1.45 + (0.45 if randf() < _p(0.25, 0.12, 0.05) else 0.0)  # error: atacar desde lejos
		var eager := 2.0 if mood == "aggressive" else 1.0
		if dist < 1.2:
			eager *= 2.5  # con el rival encima no se queda quieta
		if dist < reach and randf() < _p(0.025, 0.05, 0.08) * eager:
			_attack(dist, false)


func _attack(dist: float, punish: bool) -> void:
	var c := me.ctrl
	var r := randf()
	var from_center := Vector3(me.global_position.x, 0, me.global_position.z).length()
	# empujón: para abrir una guardia cerrada o salir de una esquina
	if not punish and dist < 1.15 and ((foe.state == "block" and r < 0.35) or (from_center > 3.0 and r < 0.5)):
		var away := me.global_position - foe.global_position
		away.y = 0
		c.move = away.normalized()
		c.light = true
		combo_left = 0
		attack_cd = randf_range(_p(1.4, 0.8, 0.5), _p(2.6, 1.7, 1.1))
		return
	if not punish and foe.state == "block" and dist < 1.9 and r < 0.45:
		c.heavy = true
		combo_left = 0
	elif r < 0.1 and dist < 1.8:
		c.heavy = true
		combo_left = 0
	elif r < 0.3:
		c.kick = true
		combo_left = randi_range(0, 1)
	else:
		c.punch = true
		combo_left = randi_range(1, 4) if not punish else 3
		if level == 0:
			combo_left = mini(combo_left, 1)
	attack_cd = randf_range(_p(1.4, 0.8, 0.5), _p(2.6, 1.7, 1.1))


func _plan_defense(dist: float) -> void:
	if dist > 2.4:
		return
	var roll := randf()
	var chance := _p(0.3, 0.55, 0.75)
	if mood == "aggressive":
		chance *= 0.7
	if roll > chance:
		return  # error: no lo ve venir
	var h: Dictionary = foe.move.hit
	var time_to_hit := float(h.from) - foe.move_t
	var delay := randf_range(_p(0.22, 0.16, 0.12), _p(0.34, 0.26, 0.2))
	var heavy: bool = h.get("guard_break", false)
	var kind := "block"
	var pr := randf()
	if heavy:
		kind = "dodge" if pr < _p(0.4, 0.65, 0.85) else "block"
	elif pr < _p(0.03, 0.1, 0.22):
		kind = "parry"
		delay = maxf(0.0, time_to_hit - 0.08)
	elif pr < 0.25:
		kind = "dodge"
	if kind != "parry" and delay > time_to_hit + 0.02:
		# llega tarde: a veces aún consigue cubrirse en el siguiente golpe del combo
		kind = "block"
	_react_kind = kind
	_react_at = _t + delay
