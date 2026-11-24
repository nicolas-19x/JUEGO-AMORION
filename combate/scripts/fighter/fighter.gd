class_name Fighter
extends CharacterBody3D
## Luchador: estados, capas de animación, pasos, golpes y reacciones.
##
## Capas de la pose final (de abajo arriba):
##  1. Base: guardia de combate ↔ bloqueo (mezcla continua), con postura de cansancio.
##  2. Acción: golpe, esquiva o reacción muestreada de FighterMoves.
##  3. Inercialización: al cambiar de acción, la diferencia con la pose anterior se
##     desvanece en lugar de mezclar dos animaciones (sin saltos, sin retraso).
##  4. Aditivos: muelles de impacto (pecho, cabeza, caderas), inclinación por
##     velocidad, respiración, rebote de los pasos y mirada hacia el rival.
## Los pies los coloca un planificador de pasos: apoyados en el mundo, solo se
## mueven dando pasos, así que nunca patinan.

signal hit_landed(info: Dictionary)
signal knocked_out(who: Fighter)
signal footstep(who: Fighter, strength: float)
signal whoosh(who: Fighter, kind: int)
signal wall_impact(who: Fighter, point: Vector3, strength: float)
signal evaded_attack(who: Fighter, attacker: Fighter)
signal guard_crushed(who: Fighter)

const PARRY_WINDOW := 0.16
static var BUFFER_TIME := 0.3          # ventana para encadenar (ajustable)
static var hitstop_scale := 1.0
const SEPARATION := 0.62
const ESCAPE_HITS := 9      # al noveno golpe seguido la víctima sale despedida

var display_name := "Luchador"
var opponent: Fighter
var rig: FighterRig
var max_hp := 100.0
var hp := 100.0
var is_player := false

# entrada (la rellena un "cerebro": el jugador o la IA)
var ctrl := {"move": Vector3.ZERO, "punch": false, "kick": false, "light": false, "heavy": false,
	"attack_held": false, "guard": false, "guard_pressed": false, "dodge": Vector3.ZERO,
	"dodge_pressed": false, "special": false}

var state := "free"          # free, block, attack, dodge, react, ko
var move: Dictionary = {}
var move_t := 0.0
var move_amp := 1.0
var move_speed := 1.0
var move_basis := Basis.IDENTITY
var root_dir := Vector2(0, 1)
var root_k := 1.0
var root_prev := 0.0
var hit_done := false
var queued := ""
var buffer := ""
var buffer_t := 0.0
var charge_t := 0.0
var charging := false

var freeze := 0.0
var freeze_dir := Vector3.ZERO
var guard_w := 0.0
var guard_age := 9.0
var combo_taken := 0
var last_hit_t := -9.0
var time := 0.0
var vel := Vector3.ZERO
var yaw := 0.0
var sync_target: Fighter = null

# equilibrio (postura): bloquear y encajar lo llena; lleno = guardia rota
var posture := 0.0
var posture_idle := 0.0
# ventana de contraataque tras esquivar en el último momento
var counter_t := 0.0
var evaded := false
var was_counter := false
var string_n := 0          # golpes en la serie actual
var spin_base := 0.0
var _slip_side := 1.0
# lesiones
var head_dmg := 0.0
var leg_dmg := 0.0
var _last_react := ""
var last_apply: Array = []   # pose dibujada este fotograma (para la repetición)
var body_dmg := 0.0
var bleed := 0.0
var _face_t := 0.0

# planificador de pasos
var feet := []

# capas de animación
var last_out: Dictionary = {}
var inert_off: Dictionary = {}
var inert_t := 1.0
var inert_dur := 0.1
var _pending_inert := -1.0
# capa física parcial: un muelle amortiguado por articulación (grados o metros)
const PHYS := {
	"hips_rot": {"k": 260.0, "gain": 25.0, "lim": 22.0},
	"spine_rot": {"k": 220.0, "gain": 60.0, "lim": 30.0},
	"chest_rot": {"k": 190.0, "gain": 160.0, "lim": 40.0},
	"head_rot": {"k": 230.0, "gain": 900.0, "lim": 50.0},
	"hips_pos": {"k": 320.0, "gain": 0.0, "lim": 0.12},
	"hand_l": {"k": 150.0, "gain": 0.0, "lim": 0.18},
	"hand_r": {"k": 150.0, "gain": 0.0, "lim": 0.18},
}
var phys := {}
var tone := 1.0              # tono muscular: 1 firme, ~0.15 suelto
var _prev_vel := Vector3.ZERO
var _prev_chest := Vector3.ZERO
var _prev_chest_w := Vector3.ZERO
var prev_points := {}
var limb_vel := {}
var _moves: Dictionary


func setup(p_name: String, palette: Dictionary, pos: Vector3, face_to: Vector3) -> void:
	display_name = p_name
	_moves = FighterMoves.all()
	collision_layer = 2
	collision_mask = 1 | 4
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.26
	cap.height = 1.7
	shape.shape = cap
	shape.position.y = 0.88
	add_child(shape)
	rig = FighterRig.new()
	rig.name = "Rig"
	add_child(rig)
	rig.setup(palette)
	reset(pos, face_to)


func reset(pos: Vector3, face_to: Vector3) -> void:
	global_position = Vector3(pos.x, 0, pos.z)
	var d := face_to - pos
	yaw = atan2(-d.x, -d.z)
	rotation = Vector3(0, yaw, 0)
	hp = max_hp
	state = "free"
	move = {}
	vel = Vector3.ZERO
	freeze = 0.0
	combo_taken = 0
	posture = 0.0
	counter_t = 0.0
	head_dmg = 0.0
	body_dmg = 0.0
	leg_dmg = 0.0
	bleed = 0.0
	evaded = false
	queued = ""
	buffer = ""
	feet = []
	for s in ["l", "r"]:
		var local: Vector3 = FighterMoves.FOOT_L if s == "l" else FighterMoves.FOOT_R
		var w := global_transform * local
		feet.append({"pos": Vector3(w.x, local.y, w.z), "yaw": yaw + FighterMoves.FOOT_YAW, "stepping": false,
			"t": 0.0, "dur": 0.2, "from": Vector3.ZERO, "from_yaw": 0.0, "air": false})
	last_out = FighterMoves.stance()
	inert_off.clear()
	rig.reset_chains()
	rig.clear_damage()
	_update_rig(0.016)


# ---------------------------------------------------------------------------
# Paso de simulación (lo llama el combate, en orden fijo)
# ---------------------------------------------------------------------------

func step(delta: float) -> void:
	time += delta
	guard_age += delta
	counter_t = maxf(0.0, counter_t - delta)
	posture_idle += delta
	if posture_idle > 1.1 and state != "ko":
		posture = maxf(0.0, posture - delta * (12.0 if state == "block" else 20.0))
	bleed = maxf(0.0, bleed - delta * 0.04)
	_face_t -= delta
	if _face_t <= 0.0:
		_face_t = 0.5
		rig.update_face(clampf(1.0 - hp / max_hp, 0.0, 1.0) * 0.8 + 0.1)
	_read_input(delta)
	if freeze > 0.0:
		freeze -= delta
		var s := 0.025 * clampf(freeze * 14.0, 0.0, 1.0)
		rig.shake_offset = freeze_dir * s * (1.0 if int(time * 60.0) % 2 == 0 else -1.0)
		_update_rig(0.0)
		return
	rig.shake_offset = Vector3.ZERO
	# agarre interrumpido o fallado: la víctima se suelta
	if sync_target and (sync_target.state != "attack" or not sync_target.move.has("sync")):
		sync_target = null
		if move.get("name", "") == "clinched":
			start_reaction("dazed", null, 1.0, 1.0)
	match state:
		"free", "block":
			_free_update(delta)
		"attack", "dodge", "react", "ko":
			_action_update(delta)
	_update_springs(delta)
	_update_rig(delta)


func _read_input(delta: float) -> void:
	if ctrl.light or ctrl.punch:
		buffer = "punch"
		buffer_t = BUFFER_TIME
	if ctrl.kick:
		buffer = "kick"
		buffer_t = BUFFER_TIME
	if ctrl.heavy:
		buffer = "heavy"
		buffer_t = BUFFER_TIME
	if ctrl.special:
		buffer = "special"
		buffer_t = BUFFER_TIME
	if ctrl.dodge != Vector3.ZERO or ctrl.dodge_pressed:
		buffer = "dodge"
		buffer_t = BUFFER_TIME * 0.6
		ctrl.dodge_pressed = false
	if ctrl.guard_pressed:
		guard_age = 0.0
	buffer_t -= delta
	if buffer_t <= 0.0:
		buffer = ""
	ctrl.light = false
	ctrl.punch = false
	ctrl.kick = false
	ctrl.heavy = false
	ctrl.special = false
	ctrl.guard_pressed = false


func can_act() -> bool:
	return state == "free" or state == "block"


func is_vulnerable_to_special() -> bool:
	return state == "react" and move.get("name", "") in ["dazed", "parried", "guard_break", "wall_splat"]


func _free_update(delta: float) -> void:
	# acciones con buffer
	if buffer != "" and _try_start_buffered():
		_action_update(0.0)
		return
	state = "block" if ctrl.guard else "free"
	var target_w := 1.0 if state == "block" else 0.0
	guard_w = move_toward(guard_w, target_w, delta * 9.0)

	# encarar al rival
	_face_opponent(delta, 11.0)

	# locomoción relativa al rival
	var dir: Vector3 = ctrl.move
	dir.y = 0
	var amount := minf(dir.length(), 1.0)
	var target_vel := Vector3.ZERO
	if amount > 0.08:
		dir = dir.normalized()
		var fwd := -global_transform.basis.z
		var f := dir.dot(fwd)
		var spd := 2.15 if f > 0.3 else (1.65 if f < -0.3 else 1.85)
		if opponent and global_position.distance_to(opponent.global_position) > 4.5 and f > 0.5:
			spd = 3.4
		if state == "block":
			spd *= 0.45
		spd *= 1.0 - clampf(leg_dmg / 60.0, 0.0, 0.3)  # cojera
		target_vel = dir * spd * amount
	var accel := 16.0 if target_vel.length() > vel.length() else 20.0
	vel = vel.move_toward(target_vel, accel * delta)
	velocity = vel
	move_and_slide()
	_keep_on_floor()
	_update_feet(delta)


func _try_start_buffered() -> bool:
	var b := buffer
	match b:
		"punch", "kick":
			buffer = ""
			string_n = 0
			start_move(_choose(b, false))
			return true
		"heavy":
			buffer = ""
			string_n = 0
			start_move("push_kick")
			return true
		"special":
			buffer = ""
			if opponent and opponent.is_vulnerable_to_special() and _dist() < 2.2:
				start_move("clinch_knee")
				return true
			return false
		"dodge":
			buffer = ""
			var d: Vector3 = ctrl.dodge
			ctrl.dodge = Vector3.ZERO
			if d == Vector3.ZERO:
				# sin dirección: quiebro lateral, alternando lado
				_slip_side = -_slip_side
				d = global_transform.basis.x * _slip_side
			start_dodge(d)
			return true
	return false


## Elige el golpe según el botón, la serie en curso, la distancia y la dirección.
func _choose(input: String, chaining: bool) -> String:
	if counter_t > 0.0:
		counter_t = 0.0
		was_counter = true
		return "uppercut" if input == "punch" else "spin_kick"
	was_counter = false
	var cur: String = move.get("name", "") if chaining else ""
	var dir := _stick_relative()   # x: lateral, y: hacia el rival
	var close := _dist() < 0.9
	if input == "punch":
		if not chaining:
			if dir.y < -0.6 and _dist() < 1.6:
				return "shove"
			if opponent and opponent.state == "react" and opponent.move.get("name", "") in ["stagger", "dazed", "wall_splat"]:
				return "uppercut"
			return "hook" if close else "jab"
		match cur:
			"jab":
				return "cross"
			"cross":
				return "hook"
			"hook":
				return "body_hook"
			"body_hook", "low_kick", "roundhouse":
				return "cross"
			"uppercut", "knee":
				return "hook"
		return "jab"
	# patada
	if not chaining:
		if dir.y > 0.7:
			return "push_kick"
		return "knee" if close else "low_kick"
	if string_n >= 4 or cur == "roundhouse":
		return "spin_kick"
	return "roundhouse"


## Dirección del joystick relativa al rival (y > 0: hacia él).
func _stick_relative() -> Vector2:
	var mv: Vector3 = ctrl.move
	mv.y = 0
	if mv.length() < 0.5 or not opponent:
		return Vector2.ZERO
	var to := opponent.global_position - global_position
	to.y = 0
	to = to.normalized()
	var right := to.cross(Vector3.UP)
	var n := mv.normalized()
	return Vector2(n.dot(right), n.dot(to))


func add_posture(v: float) -> void:
	posture = clampf(posture + v, 0.0, 100.0)
	posture_idle = 0.0


func _face_opponent(delta: float, rate: float) -> void:
	if not opponent:
		return
	var d := opponent.global_position - global_position
	if d.length() < 0.05:
		return
	var target := atan2(-d.x, -d.z)
	yaw = rotate_toward(yaw, target, rate * delta)
	rotation.y = yaw


func _dist() -> float:
	return global_position.distance_to(opponent.global_position) if opponent else 99.0


func _keep_on_floor() -> void:
	global_position.y = 0.0
	velocity.y = 0.0


# ---------------------------------------------------------------------------
# Acciones
# ---------------------------------------------------------------------------

func start_move(mv: String) -> void:
	var m: Dictionary = _moves[mv]
	_begin(m, "attack", 0.05 if string_n > 0 else 0.07)
	string_n += 1
	spin_base = yaw
	charge_t = 0.0
	charging = m.has("charge_at")
	# deformación del desplazamiento raíz: llegar al contacto a la distancia justa
	root_k = 1.0
	if opponent and m.has("hit"):
		var contact_t: float = float(m.hit.from) + 0.02
		var nominal := FighterMoves.root_at(m, contact_t)
		# nunca recular para "encajar" la distancia: si está más cerca, conecta antes
		var desired := clampf(_dist() - float(m.reach), 0.0, nominal + float(m.lunge))
		root_k = desired / nominal if nominal > 0.01 else 1.0
		root_k = clampf(root_k, 0.0, 3.5)
	if m.has("sync") and opponent:
		# el atacante cubre la mitad de la distancia y atrae a la víctima la otra mitad
		var nom := FighterMoves.root_at(m, float(m.hit.from))
		root_k = clampf((_dist() - float(m.sync)) * 0.5 / nom, 0.0, 3.0)
		opponent.start_reaction("clinched", self, 1.0, 1.0)
		opponent.sync_target = self


func start_dodge(dir_world: Vector3) -> void:
	var m: Dictionary = _moves["dodge"]
	_begin(m, "dodge", 0.05)
	var local := global_transform.basis.inverse() * dir_world
	var v := Vector2(local.x, -local.z)
	if v.length() < 0.2:
		v = Vector2(0, -1)  # paso atrás
	root_dir = v.normalized()
	# esquiva lateral o hacia delante = desplazamiento corto de cintura (slip)
	root_k = 0.45 if root_dir.y > -0.5 else 0.85
	vel = Vector3.ZERO


func start_reaction(rn: String, from: Fighter, side: float, amp: float, push := 1.0) -> void:
	var key := rn + ("@m" if side < 0.0 else "")
	var m: Dictionary = _moves[key]
	_begin(m, "ko" if rn == "ko" else "react", 0.035)
	move_amp = amp
	root_k = push
	move_speed = 1.0
	if from:
		var d := from.global_position - global_position
		if d.length() > 0.01:
			yaw = atan2(-d.x, -d.z)
			rotation.y = yaw
			move_basis = global_transform.basis
	if rn != "clinched":
		sync_target = null


func _begin(m: Dictionary, st: String, blend: float) -> void:
	evaded = false
	move = m
	move_t = 0.0
	move_amp = 1.0
	move_speed = 1.0
	state = st
	hit_done = false
	queued = ""
	root_prev = 0.0
	root_dir = Vector2(0, 1)
	move_basis = global_transform.basis
	_pending_inert = blend
	vel *= 0.3


func _action_update(delta: float) -> void:
	var m := move
	var prev_t := move_t
	# carga del golpe fuerte: la pose se sostiene mientras se mantiene el botón
	if charging and m.has("charge_at") and move_t >= float(m.charge_at):
		if ctrl.attack_held and charge_t < float(m.charge_max):
			charge_t += delta
			_face_opponent(delta, 6.0)
			rig.shake_offset = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 0.006 * (charge_t / float(m.charge_max))
			_update_feet(delta)
			return
		charging = false
	move_t += delta * move_speed
	# al caer al suelo: la cabeza rebota y los brazos se sueltan
	var mn: String = m.get("name", "")
	if (mn == "launch" or mn == "ko") and prev_t < 0.52 and move_t >= 0.52:
		_phys_add("head_rot", Vector3(-170, randf_range(-60, 60), 0))
		_phys_add("chest_rot", Vector3(-60, 0, randf_range(-20, 20)))
		_phys_add("hand_l", Vector3(0, 0.9, 0))
		_phys_add("hand_r", Vector3(0, 0.9, 0))
	# whoosh
	if m.has("whoosh") and prev_t < float(m.whoosh[0]) and move_t >= float(m.whoosh[0]):
		whoosh.emit(self, int(m.whoosh[1]))
	# seguimiento del objetivo durante la anticipación
	if state == "attack" and move_t < float(m.get("track", 0.0)) and not m.has("spin"):
		_face_opponent(delta, 9.0)
		move_basis = global_transform.basis
	# encadenar combos
	if state == "attack":
		# si el golpe conectó, el siguiente puede salir justo después del contacto
		var cancel_at: float = float(m.cancel)
		if hit_done and m.has("hit"):
			cancel_at = minf(cancel_at, float(m.hit.to) + 0.03)
		if (buffer == "punch" or buffer == "kick") and not m.get("ender", false) and move_t >= cancel_at - 0.15:
			queued = _choose(buffer, true)
			buffer = ""
		if queued != "" and move_t >= cancel_at:
			var q := queued
			queued = ""
			start_move(q)
			return
	# giro del cuerpo entero (patada giratoria): el ángulo se aplica a la raíz
	if m.has("spin"):
		yaw = spin_base + deg_to_rad(FighterMoves.curve_at(m.spin, move_t))
		rotation.y = yaw
	# sincronía: la víctima del agarre se coloca frente al atacante
	if state == "attack" and m.has("sync") and opponent and opponent.sync_target == self and move_t < float(m.hit.to):
		var want := global_position - global_transform.basis.z * float(m.sync)
		opponent.global_position = opponent.global_position.lerp(want, minf(1.0, delta * 9.0))
		if global_position.distance_to(opponent.global_position) < float(m.sync) * 0.92:
			opponent.global_position = want
		# si la víctima no cabe (pared, jardinera), el atacante retrocede lo necesario
		var safe := Arena.constrain(opponent.global_position, 0.32)
		if safe.distance_to(opponent.global_position) > 0.001:
			global_position += safe - opponent.global_position
			opponent.global_position = safe
		opponent._face_opponent(delta, 20.0)

	# desplazamiento raíz
	var r := FighterMoves.root_at(m, move_t) * root_k
	var dr := r - root_prev
	root_prev = r
	var local := Vector3(root_dir.x, 0, -root_dir.y) * dr
	var motion := move_basis * local
	if delta > 0.0:
		velocity = motion / delta
		var before := global_position
		move_and_slide()
		_check_collisions(motion, before)
	_keep_on_floor()

	_update_feet(delta)

	if move_t >= float(m.dur):
		if m.get("hold", false):
			move_t = float(m.dur)
			return
		var nxt: String = m.get("next", "")
		if nxt != "" and state == "react":
			start_reaction(nxt, null, 1.0, 1.0)
			return
		_end_action()


func _end_action() -> void:
	state = "free"
	move = {}
	_pending_inert = 0.16
	sync_target = null
	if combo_taken > 0 and time - last_hit_t > 0.6:
		combo_taken = 0


func in_iframes() -> bool:
	if move.is_empty() or not move.has("iframes"):
		return false
	var f: Array = move.iframes
	return move_t >= float(f[0]) and move_t <= float(f[1])


func active_hit() -> Dictionary:
	if state != "attack" or hit_done or freeze > 0.0 or charging:
		return {}
	var h: Dictionary = move.get("hit", {})
	if h.is_empty():
		return {}
	if move_t >= float(h.from) and move_t <= float(h.to):
		return h
	return {}


func _check_collisions(motion: Vector3, _before: Vector3) -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col := c.get_collider()
		if col is RigidBody3D:
			var rb := col as RigidBody3D
			var spd := motion.length() / maxf(get_physics_process_delta_time(), 0.001)
			rb.apply_impulse(-c.get_normal() * spd * rb.mass * 0.55 + Vector3.UP * spd * 0.4, c.get_position() - rb.global_position)
		elif state == "react" and col is StaticBody3D and (col as Node).is_in_group("wall"):
			var spd := motion.length() / maxf(get_physics_process_delta_time(), 0.001)
			var nm: String = move.get("name", "")
			if spd > 2.2 and nm in ["stagger", "launch"] and move_t < 0.5:
				# golpe contra la pared: la víctima queda apoyada de espaldas
				var n := c.get_normal()
				yaw = atan2(n.x, n.z)
				rotation.y = yaw
				start_reaction("wall_splat", null, 1.0, 1.0)
				move_basis = global_transform.basis
				freeze = 0.09
				freeze_dir = -n
				# la cabeza golpea la pared y rebota hacia delante
				_phys_add("head_rot", Vector3(240, 0, randf_range(-40, 40)))
				_phys_add("chest_rot", Vector3(90, 0, 0))
				tone = 0.25
				wall_impact.emit(self, c.get_position() + Vector3.UP * 1.1, spd)
				return


# ---------------------------------------------------------------------------
# Recibir golpes
# ---------------------------------------------------------------------------

## Resuelve un contacto de self (atacante) sobre victim. Devuelve info del resultado.
func resolve_hit(victim: Fighter, h: Dictionary, point: Vector3, limb_velocity: Vector3) -> Dictionary:
	hit_done = true
	var info := {"attacker": self, "victim": victim, "point": point, "level": int(h.level),
		"result": "hit", "move": move.name, "charge": charge_t}
	var to_att := (global_position - victim.global_position)
	to_att.y = 0
	to_att = to_att.normalized()
	var v_fwd := -victim.global_transform.basis.z
	var facing := v_fwd.dot(to_att) > 0.2
	var unblockable: bool = h.get("unblockable", false)

	# parada: pulsar defensa justo antes del contacto
	if not unblockable and victim.can_act() and victim.guard_age < PARRY_WINDOW and facing:
		info.result = "parry"
		add_posture(25.0)
		start_reaction("parried", victim, 1.0, 1.0)
		victim._begin(victim._moves["parry_deflect"], "dodge", 0.03)
		victim.guard_age = 9.0
		_hitstop(0.11, to_att, victim)
		return info
	# bloqueo
	if not unblockable and (victim.state == "block" or (victim.state == "react" and victim.move.get("guard", false))) and facing:
		victim.add_posture(float(h.dmg) * 2.6 + 6.0 * float(h.level))
		if h.get("guard_break", false) or victim.posture >= 100.0:
			info.result = "guard_break"
			victim.posture = 40.0
			victim.guard_crushed.emit(victim)
			victim.start_reaction("guard_break", self, 1.0, 1.0, 1.0)
			_hitstop(0.1, -to_att, victim)
		else:
			info.result = "block"
			victim.start_reaction("blockstun", self, 1.0, 1.0, float(h.push))
			_hitstop(0.045 + 0.01 * float(h.level), -to_att, victim)
		victim._kick_springs(Vector3(6, 0, 0), Vector3(4, 0, 0), Vector3(0, 0, 0.03))
		return info

	# impacto
	var counter: bool = victim.state == "attack" or (move.name == "uppercut" and was_counter)
	var scaling := maxf(0.55, 1.0 - victim.combo_taken * 0.12)
	var dmg := float(h.dmg) * scaling * (1.25 if counter else 1.0)
	if move.name == "push_kick":
		dmg += 7.0 * clampf(charge_t / float(move.charge_max), 0.0, 1.0)
	victim.hp = maxf(0.0, victim.hp - dmg)
	victim.add_posture(float(h.get("posture", dmg * 0.35)))
	victim.combo_taken += 1
	victim.last_hit_t = victim.time
	info.counter = counter
	info.damage = dmg

	var level := int(h.level) + (1 if counter else 0)
	var right := victim.global_transform.basis.x
	var lv := limb_velocity
	lv.y = 0
	var side := 1.0
	if lv.length() > 0.5:
		side = clampf(lv.normalized().dot(right) * 2.0, -1.0, 1.0)
	if absf(side) < 0.25:
		side = 0.25 * (1.0 if victim.combo_taken % 2 == 0 else -1.0)
	var height := point.y - victim.global_position.y
	var amp := clampf(0.7 + 0.15 * level + absf(side) * 0.1, 0.6, 1.3)
	var push := float(h.push) * (1.0 + 0.6 * clampf(charge_t / 0.6, 0.0, 1.0))

	var region: String = h.get("region", "head" if height > 1.28 else "body")
	var reaction := "hit_head" if region == "head" else "hit_body"
	var forced: String = h.get("react", "")
	if forced != "":
		reaction = forced
	elif victim.posture >= 100.0:
		# empujones acumulados: pierde el equilibrio
		reaction = "stagger"
		victim.posture = 50.0
	elif level >= 3:
		reaction = "stagger"
	# variedad sistémica: golpes laterales fuertes giran más; nunca la misma reacción dos veces
	if forced == "" and reaction in ["hit_head", "hit_body"]:
		var heavy_side := absf(side) > 0.55 and level >= 2
		var alt := reaction + "_b"
		if heavy_side or victim._last_react == reaction:
			reaction = alt
		victim._last_react = reaction
	# serie demasiado larga: la víctima sale despedida y se libera
	if victim.combo_taken >= ESCAPE_HITS and reaction in ["hit_head", "hit_body", "hit_leg", "hit_head_b", "hit_body_b"]:
		reaction = "stagger"
		push = maxf(push, 1.5)
		info.escape = true
	if victim.hp <= 0.0:
		reaction = "ko"
		push = maxf(push, 1.1)
	info.reaction = reaction
	info.region = region
	info.side = side
	if not h.get("clean", false):
		victim._take_injury(point, dmg, level, side, info.region == "head", counter)
	victim.start_reaction(reaction, self, side, amp, push)
	# cada golpe seguido acorta el aturdimiento: la víctima acaba recuperándose
	if reaction in ["hit_head", "hit_body", "hit_leg", "hit_head_b", "hit_body_b"]:
		victim.move_speed = 1.0 + 0.07 * maxf(0.0, victim.combo_taken - 3.0)
	if region == "legs":
		victim.leg_dmg += dmg
	# la sangre del rival mancha las vendas de quien golpea
	if victim.bleed > 0.1 and region == "head":
		rig.add_mark(rig.points.get(String(h.limb), point), 0.35 + victim.bleed * 0.5, true)

	# física parcial: el cuerpo recibe el impulso real (punto + dirección del miembro)
	var fdir := limb_velocity.normalized() if limb_velocity.length() > 0.5 else -to_att
	fdir = (fdir + (-to_att) * 0.6).normalized()
	victim.tone = minf(victim.tone, 0.5)
	victim.phys_impulse(point, fdir * (0.9 + 0.55 * level))

	var stop: float = [0.0, 0.05, 0.075, 0.11, 0.15, 0.17][clampi(level, 0, 5)]
	if reaction == "ko":
		stop = 0.2
	_hitstop(stop, -to_att, victim)
	if reaction == "ko":
		victim.knocked_out.emit(victim)
	return info


## Lesiones visibles según zona, fuerza y lado del golpe.
func _take_injury(point: Vector3, dmg: float, level: int, side: float, head: bool, counter: bool) -> void:
	var struck := -signf(side) if absf(side) > 0.05 else 1.0  # lado de la cara que recibe
	if head:
		head_dmg += dmg
		rig.add_mark(point, 0.28 + 0.2 * level)
		var f := rig.face
		if head_dmg > 6.0:
			f.nose = minf(1.0, f.nose + 0.14 * level)
			bleed = minf(1.0, bleed + 0.15 * level)
		if level >= 2 and head_dmg > 14.0:
			f.lip = minf(1.0, f.lip + 0.3)
		f.smear = minf(1.0, float(f.get("smear", 0.0)) + 0.04 * level * (1.0 if head_dmg > 12.0 else 0.0))
		if (level >= 3 and (head_dmg > 16.0 or counter)) or head_dmg > 34.0:
			if f.cut < 0.05:
				f.cut_side = struck
			f.cut = minf(1.0, f.cut + 0.45)
			bleed = minf(1.0, bleed + 0.4)
		var sk := "swell_l" if struck < 0.0 else "swell_r"
		if head_dmg > 16.0:
			f[sk] = minf(1.0, float(f[sk]) + dmg / 38.0)
	elif not (point.y - global_position.y < 0.7):
		body_dmg += dmg
		rig.add_mark(point, 0.32 + 0.22 * level)
	rig.update_face(clampf(1.0 - hp / max_hp, 0.0, 1.0) * 0.8 + 0.1)


func _hitstop(t: float, dir_to_victim: Vector3, victim: Fighter) -> void:
	t *= hitstop_scale
	freeze = t * 0.85
	freeze_dir = Vector3.ZERO
	victim.freeze = t
	victim.freeze_dir = victim.global_transform.basis.inverse() * dir_to_victim


func _kick_springs(chest: Vector3, head: Vector3, hips: Vector3) -> void:
	_phys_add("chest_rot", chest * 14.0)
	_phys_add("head_rot", head * 14.0)
	_phys_add("hips_pos", hips * 14.0)


func _phys_add(key: String, dv) -> void:
	if not phys.has(key):
		phys[key] = {"x": Vector3.ZERO, "v": Vector3.ZERO}
	phys[key].v = (phys[key].v as Vector3) + (dv as Vector3)


func phys_value(key: String) -> Vector3:
	return phys[key].x if phys.has(key) else Vector3.ZERO


## Impulso físico de un golpe: cada articulación recibe el par de giro que le
## corresponde según dónde cayó el golpe (r) y hacia dónde empujaba (F).
func phys_impulse(point: Vector3, force: Vector3) -> void:
	var inv := global_transform.basis.inverse()
	var pivots := {
		"hips_rot": rig.points.get("hips", global_position),
		"spine_rot": rig.points.get("spine", global_position),
		"chest_rot": rig.points.get("chest_base", global_position),
		"head_rot": rig.points.get("neck", global_position),
	}
	for key in pivots:
		var r: Vector3 = point - (pivots[key] as Vector3)
		if key == "head_rot":
			# la cabeza gira sobre el cuello con su masa por encima: palanca mínima
			var up := global_transform.basis.y
			var along := r.dot(up)
			if along < 0.11:
				r += up * (0.11 - along)
		# cuanto más lejos del impacto, menos le llega
		var w := exp(-maxf(0.0, r.length() - 0.15) / 0.35)
		var tau := inv * r.cross(force)
		_phys_add(key, Vector3(rad_to_deg(tau.x), rad_to_deg(tau.y), rad_to_deg(tau.z)) * float(PHYS[key].gain) * 0.02 * w)
	var fl := inv * force
	_phys_add("hips_pos", fl * 0.25)
	# los brazos se sueltan con el golpe
	_phys_add("hand_l", (fl + Vector3(randf_range(-1, 1), 0.6, 0)) * 0.5 * (1.2 - tone))
	_phys_add("hand_r", (fl + Vector3(randf_range(-1, 1), 0.6, 0)) * 0.5 * (1.2 - tone))


func _target_tone() -> float:
	var n: String = move.get("name", "")
	match state:
		"ko":
			return 0.15
		"react":
			if n == "launch":
				return 0.2 if move_t > 0.3 and move_t < 1.2 else 0.5
			if n in ["dazed", "wall_splat"]:
				return 0.3
			if n in ["stagger", "guard_break", "parried"]:
				return 0.42
			if n == "blockstun":
				return 0.85
			return 0.55
	return 1.0


func _update_springs(delta: float) -> void:
	if delta <= 0.0:
		return
	var tt := _target_tone()
	tone = tt if tt < tone else move_toward(tone, tt, delta * 1.6)
	# inercia: el tronco y la cabeza van con retraso cuando el cuerpo acelera
	var a := (velocity - _prev_vel) / delta
	_prev_vel = velocity
	a.y = 0
	a = a.limit_length(40.0)
	var al := global_transform.basis.inverse() * a
	_phys_add("chest_rot", Vector3(-al.z, 0, al.x) * 1.6 * delta * 60.0 * 0.02)
	_phys_add("head_rot", Vector3(-al.z, 0, al.x) * 1.2 * delta * 60.0 * 0.02)
	_phys_add("hips_pos", -al * 0.0006 * delta * 60.0)
	if state != "attack":
		_phys_add("hand_l", -al * 0.0012 * delta * 60.0)
		_phys_add("hand_r", -al * 0.0012 * delta * 60.0)
	for key in PHYS:
		if not phys.has(key):
			phys[key] = {"x": Vector3.ZERO, "v": Vector3.ZERO}
		var j: Dictionary = phys[key]
		var k: float = float(PHYS[key].k) * (0.22 + 0.78 * tone)
		var zeta := 0.42 + 0.3 * tone
		var c := 2.0 * zeta * sqrt(k)
		var x: Vector3 = j.x
		var v: Vector3 = j.v
		v += (-x * k - v * c) * delta
		x += v * delta
		x = x.limit_length(float(PHYS[key].lim))
		j.x = x
		j.v = v


# ---------------------------------------------------------------------------
# Pies
# ---------------------------------------------------------------------------

func _desired_foot(i: int) -> Vector3:
	var local: Vector3 = FighterMoves.FOOT_L if i == 0 else FighterMoves.FOOT_R
	var w := global_transform * local
	var lead := Vector3(velocity.x, 0, velocity.z) * 0.13
	if state == "free" or state == "block":
		lead = vel * 0.16
	return Vector3(w.x + lead.x, local.y, w.z + lead.z)


func _update_feet(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var any_stepping: bool = feet[0].stepping or feet[1].stepping
	for i in 2:
		var f: Dictionary = feet[i]
		if f.air:
			continue
		var want := _desired_foot(i)
		var want_yaw := yaw + FighterMoves.FOOT_YAW
		if f.stepping:
			f.t += delta
			var u := clampf(f.t / f.dur, 0.0, 1.0)
			if u >= 1.0:
				f.stepping = false
				f.pos = want
				f.yaw = want_yaw
				footstep.emit(self, clampf(0.4 + speed * 0.2, 0.3, 1.0))
		else:
			var far := Vector2(f.pos.x - want.x, f.pos.z - want.z).length()
			var turn := absf(angle_difference(f.yaw, want_yaw))
			var other: Dictionary = feet[1 - i]
			var limit := 0.13 if speed > 0.3 else 0.17
			if (far > limit or turn > 0.55) and (not other.stepping or far > 0.55) and not (any_stepping and far < 0.4):
				f.stepping = true
				f.t = 0.0
				f.dur = clampf(0.25 - speed * 0.03, 0.13, 0.25)
				f.from = f.pos
				f.from_yaw = f.yaw
				any_stepping = true


func _foot_world(i: int) -> Vector3:
	var f: Dictionary = feet[i]
	if not f.stepping:
		return f.pos
	var u := clampf(f.t / f.dur, 0.0, 1.0)
	var want := _desired_foot(i)
	var e := u * u * (3.0 - 2.0 * u)
	var p: Vector3 = (f.from as Vector3).lerp(want, e)
	var dist := Vector2(want.x - f.from.x, want.z - f.from.z).length()
	p.y = FighterMoves.FOOT_L.y + sin(u * PI) * clampf(0.03 + dist * 0.2, 0.03, 0.11)
	return p


func _foot_yaw(i: int) -> float:
	var f: Dictionary = feet[i]
	if not f.stepping:
		return f.yaw
	var u := clampf(f.t / f.dur, 0.0, 1.0)
	return lerp_angle(f.from_yaw, yaw + FighterMoves.FOOT_YAW, u)


# ---------------------------------------------------------------------------
# Composición de la pose
# ---------------------------------------------------------------------------

func _base_pose() -> Dictionary:
	var a := FighterMoves.stance()
	var b := FighterMoves.guard()
	var p := {}
	for k in FighterMoves.PARAMS:
		p[k] = (a[k] as Vector3).lerp(b[k], guard_w)
	var tired := clampf(1.0 - hp / (max_hp * 0.4), 0.0, 1.0)
	if tired > 0.0:
		p = FighterMoves.tired(p, tired)
	return p


func _update_rig(delta: float) -> void:
	var base := _base_pose()
	var pose: Dictionary
	if move.is_empty():
		pose = base
	else:
		if move.get("guard", false):
			base = FighterMoves.guard()
		pose = FighterMoves.sample(move, move_t, base, move_amp)

	# inercialización
	if _pending_inert >= 0.0 and not last_out.is_empty():
		for k in FighterMoves.PARAMS:
			inert_off[k] = (last_out[k] as Vector3) - (pose[k] as Vector3)
		inert_dur = maxf(_pending_inert, 0.001)
		inert_t = 0.0
		_pending_inert = -1.0
	if inert_t < inert_dur and not inert_off.is_empty():
		inert_t += delta
		var x := clampf(inert_t / inert_dur, 0.0, 1.0)
		var w := 1.0 - x * x * (3.0 - 2.0 * x)
		for k in FighterMoves.PARAMS:
			pose[k] = (pose[k] as Vector3) + (inert_off[k] as Vector3) * w
	last_out = pose.duplicate()

	# aditivos (no se guardan en last_out: son muelles continuos)
	var out := pose.duplicate()
	var local_v := global_transform.basis.inverse() * Vector3(velocity.x, 0, velocity.z)
	var lean := Vector3(local_v.z * 3.2, 0, -local_v.x * 2.2)
	out.spine_rot = (out.spine_rot as Vector3) + lean
	var breath := sin(time * (2.0 if hp > 40 else 3.2)) * (1.0 if hp > 40 else 2.2)
	# la cabeza va con retraso respecto a los giros bruscos del pecho (látigo)
	if delta > 0.0:
		var cw: Vector3 = ((pose.chest_rot as Vector3) - _prev_chest) / delta
		_phys_add("head_rot", -(cw - _prev_chest_w) * 0.18)
		_prev_chest_w = cw
	_prev_chest = pose.chest_rot
	out.hips_rot = (out.hips_rot as Vector3) + phys_value("hips_rot")
	out.spine_rot = (out.spine_rot as Vector3) + phys_value("spine_rot")
	out.chest_rot = (out.chest_rot as Vector3) + phys_value("chest_rot") + Vector3(breath, 0, 0)
	out.head_rot = (out.head_rot as Vector3) + phys_value("head_rot")
	out.hips_pos = (out.hips_pos as Vector3) + phys_value("hips_pos")
	if state != "attack":
		out.hand_l = (out.hand_l as Vector3) + phys_value("hand_l")
		out.hand_r = (out.hand_r as Vector3) + phys_value("hand_r")
	if state == "dodge" and move.get("name", "") == "dodge" and root_dir.y > -0.5:
		# slip: la cintura se dobla hacia el lado, la cabeza sale de la línea del golpe
		var u := clampf(move_t / 0.3, 0.0, 1.0)
		var k := sin(u * PI)
		out.spine_rot = (out.spine_rot as Vector3) + Vector3(-10, 0, root_dir.x * 20.0) * k
		out.chest_rot = (out.chest_rot as Vector3) + Vector3(-6, 0, root_dir.x * 12.0) * k
		out.hips_pos = (out.hips_pos as Vector3) + Vector3(root_dir.x * 0.06, -0.07, 0) * k
	# cuerpo castigado: más encorvado
	var hunch := clampf(body_dmg / 45.0, 0.0, 1.0)
	out.spine_rot = (out.spine_rot as Vector3) + Vector3(-7, 0, 0) * hunch
	# rebote de los pasos y peso sobre el pie apoyado
	for i in 2:
		if feet[i].stepping:
			var u: float = clampf(feet[i].t / feet[i].dur, 0.0, 1.0)
			out.hips_pos = (out.hips_pos as Vector3) + Vector3((0.015 if i == 0 else -0.015), sin(u * PI) * 0.018, 0)
	# mirada hacia el rival
	if opponent and state != "ko" and not move.get("name", "").begins_with("launch"):
		var d := opponent.rig.points.get("head", opponent.global_position) as Vector3 - global_position
		var target_yaw := atan2(-d.x, -d.z)
		var body_yaw := yaw + deg_to_rad((out.hips_rot as Vector3).y + (out.spine_rot as Vector3).y + (out.chest_rot as Vector3).y)
		var diff := clampf(rad_to_deg(angle_difference(body_yaw, target_yaw)), -60.0, 60.0)
		var w := 0.85 if state != "react" else 0.3
		out.head_rot = (out.head_rot as Vector3) + Vector3(0, diff * w, 0)

	# pies: planificador + sobreescritura del movimiento
	var inv := global_transform.affine_inverse()
	var ft := []
	var fy := []
	var pts := []
	for i in 2:
		var s := "l" if i == 0 else "r"
		var fw: Vector3 = out["fw_" + s]
		var planted := inv * _foot_world(i)
		var py := _foot_yaw(i) - yaw
		var w := clampf(fw.x, 0.0, 1.0)
		var target := planted.lerp(out["foot_" + s], w)
		ft.append(target)
		fy.append(lerp_angle(py, FighterMoves.FOOT_YAW, w))
		pts.append(fw.y)
		# el pie en el aire deja de estar apoyado; al volver, el planificador da un paso
		var f: Dictionary = feet[i]
		if w > 0.02:
			f.air = true
			f.stepping = false
			var g := global_transform * target
			f.pos = Vector3(g.x, FighterMoves.FOOT_L.y, g.z)
			f.yaw = yaw + fy[i]
		elif f.air:
			f.air = false
	last_apply = [out, ft[0], ft[1], fy[0], fy[1], pts[0], pts[1]]
	rig.apply_pose(out, ft[0], ft[1], fy[0], fy[1], pts[0], pts[1], delta)

	if delta > 0.0:
		for k in ["hand_l", "hand_r", "foot_l", "foot_r", "knee_r", "knee_l"]:
			var p: Vector3 = rig.points[k]
			limb_vel[k] = (p - prev_points.get(k, p)) / delta
			prev_points[k] = p


## Dibuja una pose grabada (repetición del KO).
func replay_frame(xf: Transform3D, data: Array, delta: float) -> void:
	global_transform = xf
	if data.size() == 7:
		rig.shake_offset = Vector3.ZERO
		rig.apply_pose(data[0], data[1], data[2], data[3], data[4], data[5], data[6], delta)
