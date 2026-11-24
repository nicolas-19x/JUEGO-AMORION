class_name FighterMoves
extends RefCounted
## Biblioteca de poses y movimientos, escrita a mano.
##
## Cada pose es un diccionario de Vector3:
##   hips_pos (m), hips_rot / spine_rot / chest_rot / head_rot (grados, Euler YXZ)
##   hand_l / hand_r: objetivo de la mano en espacio del personaje (m, el suelo es y=0,
##       -Z es hacia delante). Se le suma hips_pos, así agacharse baja las manos.
##   elbow_* / knee_*: dirección del codo/rodilla (pecho / caderas).
##   foot_l / foot_r: objetivo del tobillo en espacio del personaje.
##   fw_l / fw_r: (peso de la sobreescritura del pie, pie en punta, 0).
##       Peso 0 = el pie lo controla el planificador de pasos y queda apoyado.
## Convención de reacciones: se escriben con el empuje hacia la derecha de la
## víctima; se reflejan automáticamente para el otro lado.
##
## Cada movimiento: dur, keys [{t, e (curva de llegada), ...pose parcial}],
## root [[t, avance]] acumulado, hit {...} opcional, y metadatos de combate.

const PARAMS := ["hips_pos", "hips_rot", "spine_rot", "chest_rot", "head_rot",
	"hand_l", "hand_r", "elbow_l", "elbow_r", "knee_l", "knee_r",
	"foot_l", "foot_r", "fw_l", "fw_r"]
const ROT_PARAMS := ["hips_rot", "spine_rot", "chest_rot", "head_rot"]

const FOOT_L := Vector3(-0.14, 0.08, -0.2)
const FOOT_R := Vector3(0.16, 0.08, 0.2)
const FOOT_YAW := -0.38

static var _cache := {}


static func stance() -> Dictionary:
	return {
		"hips_pos": Vector3(0, -0.08, 0),
		"hips_rot": Vector3(0, -22, 0),
		"spine_rot": Vector3(-4, 0, 0),
		"chest_rot": Vector3(-3, -8, 0),
		"head_rot": Vector3(-5, 0, 0),
		"hand_l": Vector3(-0.01, 1.55, -0.32),
		"hand_r": Vector3(0.14, 1.53, -0.15),
		"elbow_l": Vector3(-0.45, -1.0, 0.3),
		"elbow_r": Vector3(0.6, -1.0, 0.25),
		"knee_l": Vector3(-0.25, 0, -1),
		"knee_r": Vector3(0.3, 0, -1),
		"foot_l": FOOT_L,
		"foot_r": FOOT_R,
		"fw_l": Vector3.ZERO,
		"fw_r": Vector3.ZERO,
	}


static func guard() -> Dictionary:
	var p := stance()
	p.hips_pos = Vector3(0, -0.12, 0.02)
	p.spine_rot = Vector3(-8, 0, 0)
	p.chest_rot = Vector3(-6, -4, 0)
	p.head_rot = Vector3(-12, 0, 0)
	p.hand_l = Vector3(-0.07, 1.68, -0.24)
	p.hand_r = Vector3(0.09, 1.68, -0.2)
	p.elbow_l = Vector3(-0.15, -1.0, -0.1)
	p.elbow_r = Vector3(0.2, -1.0, -0.1)
	return p


static func tired(p: Dictionary, k: float) -> Dictionary:
	# postura de cansancio: guardia más baja y pesada (k 0..1)
	var q := p.duplicate()
	q.hand_l = p.hand_l + Vector3(-0.03, -0.12, 0.05) * k
	q.hand_r = p.hand_r + Vector3(0.02, -0.12, 0.03) * k
	q.hips_pos = p.hips_pos + Vector3(0, -0.03, 0) * k
	q.chest_rot = p.chest_rot + Vector3(-7, 0, 0) * k
	q.head_rot = p.head_rot + Vector3(-6, 0, 0) * k
	return q


static func all() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var m := {}

	# --- Golpes del jugador y del rival ---------------------------------------
	m["jab"] = {
		"dur": 0.40, "kind": "attack", "cancel": 0.17, "chain": "cross", "track": 0.07,
		"reach": 0.86, "lunge": 0.45, "whoosh": [0.07, 0],
		"kf": [
			{"t": 0.0},
			{"t": 0.06, "e": "io", "hips_pos": Vector3(0, -0.10, -0.02), "chest_rot": Vector3(-5, -13, 0),
				"hand_l": Vector3(-0.02, 1.56, -0.28)},
			{"t": 0.115, "e": "in", "hips_pos": Vector3(0, -0.11, -0.06), "hips_rot": Vector3(0, -30, 0),
				"spine_rot": Vector3(-6, 0, 0), "chest_rot": Vector3(-6, -22, 0), "head_rot": Vector3(-8, 0, 0),
				"hand_l": Vector3(-0.02, 1.56, -0.68), "elbow_l": Vector3(-1, -0.3, 0.2),
				"hand_r": Vector3(0.12, 1.56, -0.12)},
			{"t": 0.16, "e": "out", "hips_pos": Vector3(0, -0.11, -0.06), "hips_rot": Vector3(0, -30, 0),
				"spine_rot": Vector3(-6, 0, 0), "chest_rot": Vector3(-6, -20, 0), "head_rot": Vector3(-8, 0, 0),
				"hand_l": Vector3(-0.02, 1.56, -0.62), "elbow_l": Vector3(-1, -0.4, 0.2),
				"hand_r": Vector3(0.12, 1.56, -0.12)},
			{"t": 0.29, "e": "io", "hand_l": Vector3(-0.02, 1.55, -0.36), "chest_rot": Vector3(-4, -11, 0)},
			{"t": 0.40},
		],
		"root": [[0.0, 0.0], [0.115, 0.16], [0.25, 0.2]],
		"hit": {"from": 0.085, "to": 0.15, "limb": "hand_l", "r": 0.12, "dmg": 5.0, "level": 1, "push": 0.9},
	}
	m["cross"] = {
		"dur": 0.48, "kind": "attack", "cancel": 0.22, "chain": "roundhouse", "track": 0.09,
		"reach": 0.88, "lunge": 0.4, "whoosh": [0.1, 1],
		"kf": [
			{"t": 0.0},
			{"t": 0.075, "e": "io", "hips_pos": Vector3(0, -0.11, 0.01), "hips_rot": Vector3(0, -30, 0),
				"chest_rot": Vector3(-5, -14, 0), "hand_r": Vector3(0.16, 1.5, -0.08), "hand_l": Vector3(-0.04, 1.55, -0.3)},
			{"t": 0.15, "e": "in", "hips_pos": Vector3(0, -0.13, -0.08), "hips_rot": Vector3(0, 6, 0),
				"spine_rot": Vector3(-8, 0, 0), "chest_rot": Vector3(-8, 24, 0), "head_rot": Vector3(-8, -14, 0),
				"hand_r": Vector3(0.0, 1.58, -0.66), "elbow_r": Vector3(1, -0.3, 0.2),
				"hand_l": Vector3(-0.1, 1.57, -0.16)},
			{"t": 0.2, "e": "out", "hips_pos": Vector3(0, -0.13, -0.08), "hips_rot": Vector3(0, 4, 0),
				"spine_rot": Vector3(-8, 0, 0), "chest_rot": Vector3(-8, 22, 0), "head_rot": Vector3(-8, -12, 0),
				"hand_r": Vector3(0.01, 1.58, -0.6), "elbow_r": Vector3(1, -0.4, 0.2),
				"hand_l": Vector3(-0.1, 1.57, -0.16)},
			{"t": 0.35, "e": "io", "hips_rot": Vector3(0, -14, 0), "chest_rot": Vector3(-4, -2, 0),
				"hand_r": Vector3(0.12, 1.54, -0.24)},
			{"t": 0.48},
		],
		"root": [[0.0, 0.0], [0.15, 0.2], [0.27, 0.24]],
		"hit": {"from": 0.12, "to": 0.19, "limb": "hand_r", "r": 0.13, "dmg": 7.0, "level": 2, "push": 1.1},
	}
	m["roundhouse"] = {
		"dur": 0.74, "kind": "attack", "cancel": 0.4, "chain": "", "track": 0.12,
		"reach": 0.84, "lunge": 0.4, "whoosh": [0.15, 2],
		"kf": [
			{"t": 0.0},
			{"t": 0.11, "e": "io", "hips_pos": Vector3(0, -0.07, 0.03), "hips_rot": Vector3(0, -38, 6),
				"chest_rot": Vector3(-2, -10, 0), "foot_r": Vector3(0.14, 0.42, 0.08), "fw_r": Vector3(1, 0.3, 0),
				"knee_r": Vector3(0.6, 0.2, -1), "hand_r": Vector3(0.32, 1.25, 0.1), "hand_l": Vector3(-0.08, 1.62, -0.25)},
			{"t": 0.225, "e": "in", "hips_pos": Vector3(0, -0.03, -0.02), "hips_rot": Vector3(0, 62, 24),
				"spine_rot": Vector3(0, 0, 10), "chest_rot": Vector3(2, 6, 6), "head_rot": Vector3(-4, -40, -14),
				"foot_r": Vector3(-0.08, 1.38, -0.72), "fw_r": Vector3(1, 1, 0), "knee_r": Vector3(1, 0.6, -0.3),
				"hand_r": Vector3(0.45, 1.05, 0.3), "hand_l": Vector3(-0.12, 1.55, -0.3), "elbow_l": Vector3(-0.3, -1, 0)},
			{"t": 0.33, "e": "out", "hips_pos": Vector3(0, -0.05, 0.0), "hips_rot": Vector3(0, 82, 20),
				"spine_rot": Vector3(0, 0, 8), "chest_rot": Vector3(2, 8, 4), "head_rot": Vector3(-4, -55, -10),
				"foot_r": Vector3(-0.42, 1.05, -0.38), "fw_r": Vector3(1, 1, 0), "knee_r": Vector3(1, 0.6, 0.0),
				"hand_r": Vector3(0.4, 1.1, 0.25), "hand_l": Vector3(-0.15, 1.5, -0.25)},
			{"t": 0.5, "e": "io", "hips_pos": Vector3(0, -0.08, 0.0), "hips_rot": Vector3(0, 10, 6),
				"foot_r": Vector3(0.05, 0.4, -0.05), "fw_r": Vector3(1, 0.3, 0), "knee_r": Vector3(0.4, 0.3, -1),
				"hand_r": Vector3(0.2, 1.4, -0.1)},
			{"t": 0.74},
		],
		"root": [[0.0, 0.0], [0.225, 0.24], [0.5, 0.3]],
		"hit": {"from": 0.17, "to": 0.27, "limb": "foot_r", "r": 0.17, "dmg": 11.0, "level": 3, "push": 1.3},
	}
	m["push_kick"] = {
		"dur": 0.82, "kind": "attack", "cancel": 99.0, "chain": "", "track": 0.14,
		"reach": 0.98, "lunge": 0.55, "ender": true, "charge_at": 0.14, "charge_max": 0.6, "whoosh": [0.18, 2],
		"kf": [
			{"t": 0.0},
			{"t": 0.14, "e": "io", "hips_pos": Vector3(0, -0.05, 0.08), "hips_rot": Vector3(6, -6, 0),
				"spine_rot": Vector3(6, 0, 0), "chest_rot": Vector3(2, -4, 0), "head_rot": Vector3(-14, 0, 0),
				"foot_r": Vector3(0.1, 0.62, -0.08), "fw_r": Vector3(1, 0.1, 0), "knee_r": Vector3(0.1, 0.4, -1),
				"hand_l": Vector3(-0.08, 1.62, -0.28), "hand_r": Vector3(0.18, 1.6, -0.12)},
			{"t": 0.265, "e": "in", "hips_pos": Vector3(0, -0.02, -0.14), "hips_rot": Vector3(14, 10, 0),
				"spine_rot": Vector3(10, 0, 0), "chest_rot": Vector3(4, 0, 0), "head_rot": Vector3(-26, 0, 0),
				"foot_r": Vector3(0.04, 1.0, -0.9), "fw_r": Vector3(1, 0.0, 0), "knee_r": Vector3(0, 1, -0.3),
				"hand_l": Vector3(-0.2, 1.5, -0.2), "hand_r": Vector3(0.3, 1.3, 0.15)},
			{"t": 0.4, "e": "out", "hips_pos": Vector3(0, -0.03, -0.12), "hips_rot": Vector3(12, 8, 0),
				"spine_rot": Vector3(8, 0, 0), "head_rot": Vector3(-22, 0, 0),
				"foot_r": Vector3(0.04, 0.95, -0.82), "fw_r": Vector3(1, 0.0, 0), "knee_r": Vector3(0, 1, -0.3),
				"hand_l": Vector3(-0.2, 1.5, -0.2), "hand_r": Vector3(0.3, 1.3, 0.15)},
			{"t": 0.58, "e": "io", "hips_pos": Vector3(0, -0.07, -0.02), "foot_r": Vector3(0.1, 0.45, -0.3),
				"fw_r": Vector3(1, 0, 0), "knee_r": Vector3(0.1, 0.4, -1)},
			{"t": 0.82},
		],
		"root": [[0.0, 0.0], [0.14, -0.04], [0.265, 0.34], [0.5, 0.42]],
		"hit": {"from": 0.22, "to": 0.31, "limb": "foot_r", "r": 0.2, "dmg": 13.0, "level": 3, "push": 1.6,
			"react": "launch", "guard_break": true},
	}
	m["clinch_knee"] = {
		"dur": 1.05, "kind": "attack", "cancel": 99.0, "chain": "", "track": 0.1, "sync": 0.62, "ender": true,
		"reach": 0.62, "lunge": 0.8, "whoosh": [0.36, 1],
		"kf": [
			{"t": 0.0},
			{"t": 0.13, "e": "io", "hand_l": Vector3(-0.1, 1.58, -0.56), "hand_r": Vector3(0.1, 1.58, -0.56),
				"elbow_l": Vector3(-1, -0.5, 0), "elbow_r": Vector3(1, -0.5, 0),
				"hips_rot": Vector3(0, 0, 0), "chest_rot": Vector3(-10, 0, 0), "hips_pos": Vector3(0, -0.08, -0.05)},
			{"t": 0.3, "e": "io", "hand_l": Vector3(-0.1, 1.32, -0.46), "hand_r": Vector3(0.1, 1.32, -0.46),
				"elbow_l": Vector3(-1, -0.5, 0), "elbow_r": Vector3(1, -0.5, 0), "chest_rot": Vector3(-18, 0, 0),
				"hips_rot": Vector3(0, 0, 0), "hips_pos": Vector3(0, -0.06, 0.02),
				"foot_r": Vector3(0.12, 0.32, 0.3), "fw_r": Vector3(1, 0.5, 0)},
			{"t": 0.42, "e": "in", "hand_l": Vector3(-0.1, 1.12, -0.42), "hand_r": Vector3(0.1, 1.12, -0.42),
				"elbow_l": Vector3(-1, -0.5, 0), "elbow_r": Vector3(1, -0.5, 0), "chest_rot": Vector3(-22, 0, 0),
				"hips_rot": Vector3(-6, 12, 0), "hips_pos": Vector3(0, 0.02, -0.1), "head_rot": Vector3(-20, 0, 0),
				"foot_r": Vector3(0.08, 0.66, -0.2), "fw_r": Vector3(1, 0.7, 0), "knee_r": Vector3(0, 1, -0.6)},
			{"t": 0.55, "e": "out", "hand_l": Vector3(-0.1, 1.15, -0.42), "hand_r": Vector3(0.1, 1.15, -0.42),
				"chest_rot": Vector3(-20, 0, 0), "hips_rot": Vector3(-4, 10, 0), "hips_pos": Vector3(0, 0.0, -0.08),
				"foot_r": Vector3(0.08, 0.6, -0.22), "fw_r": Vector3(1, 0.7, 0), "knee_r": Vector3(0, 1, -0.6)},
			{"t": 0.75, "e": "io", "hand_l": Vector3(-0.12, 1.45, -0.62), "hand_r": Vector3(0.12, 1.45, -0.62),
				"chest_rot": Vector3(-4, 0, 0), "foot_r": Vector3(0.14, 0.2, 0.1), "fw_r": Vector3(0.6, 0, 0)},
			{"t": 1.05},
		],
		"root": [[0.0, 0.0], [0.13, 0.12], [0.75, 0.2]],
		"hit": {"from": 0.37, "to": 0.48, "limb": "knee_r", "r": 0.17, "dmg": 18.0, "level": 4, "push": 1.3,
			"react": "launch", "unblockable": true},
	}
	# gancho corto: sale solo cuando el rival está pegado (golpe por contexto)
	m["hook"] = {
		"dur": 0.46, "kind": "attack", "cancel": 0.2, "chain": "cross", "track": 0.08,
		"reach": 0.6, "lunge": 0.5, "whoosh": [0.09, 1],
		"kf": [
			{"t": 0.0},
			{"t": 0.07, "e": "io", "hips_pos": Vector3(0, -0.12, 0.01), "hips_rot": Vector3(0, -36, 0),
				"chest_rot": Vector3(-6, -18, 0), "hand_l": Vector3(-0.22, 1.5, -0.2), "elbow_l": Vector3(-1, -0.2, 0.3)},
			{"t": 0.14, "e": "in", "hips_pos": Vector3(0, -0.13, -0.04), "hips_rot": Vector3(0, 4, 0),
				"spine_rot": Vector3(-6, 0, 0), "chest_rot": Vector3(-8, 28, 0), "head_rot": Vector3(-8, -12, 0),
				"hand_l": Vector3(0.1, 1.55, -0.44), "elbow_l": Vector3(-1, 0.45, 0.1), "hand_r": Vector3(0.1, 1.57, -0.14)},
			{"t": 0.19, "e": "out", "hips_pos": Vector3(0, -0.13, -0.04), "hips_rot": Vector3(0, 8, 0),
				"chest_rot": Vector3(-8, 34, 0), "hand_l": Vector3(0.2, 1.53, -0.32), "elbow_l": Vector3(-1, 0.45, 0.1),
				"hand_r": Vector3(0.1, 1.57, -0.14)},
			{"t": 0.34, "e": "io", "hand_l": Vector3(-0.04, 1.55, -0.3), "chest_rot": Vector3(-4, -6, 0)},
			{"t": 0.46},
		],
		"root": [[0.0, 0.0], [0.14, 0.1], [0.3, 0.12]],
		"hit": {"from": 0.1, "to": 0.19, "limb": "hand_l", "r": 0.15, "dmg": 8.0, "level": 2, "push": 0.9},
	}
	# empujón: sin apenas daño, rompe el equilibrio y manda contra la pared
	m["shove"] = {
		"dur": 0.56, "kind": "attack", "cancel": 99.0, "chain": "", "track": 0.06, "ender": true,
		"reach": 0.55, "lunge": 0.4, "whoosh": [0.12, 0],
		"kf": [
			{"t": 0.0},
			{"t": 0.08, "e": "io", "hips_pos": Vector3(0, -0.15, 0.04), "hips_rot": Vector3(0, -6, 0),
				"chest_rot": Vector3(-10, 0, 0), "hand_l": Vector3(-0.13, 1.32, -0.12), "hand_r": Vector3(0.13, 1.32, -0.12),
				"elbow_l": Vector3(-0.6, -1, 0.3), "elbow_r": Vector3(0.6, -1, 0.3)},
			{"t": 0.17, "e": "in", "hips_pos": Vector3(0, -0.1, -0.13), "hips_rot": Vector3(0, 0, 0),
				"spine_rot": Vector3(-13, 0, 0), "chest_rot": Vector3(-8, 0, 0), "head_rot": Vector3(-6, 0, 0),
				"hand_l": Vector3(-0.15, 1.34, -0.62), "hand_r": Vector3(0.15, 1.34, -0.62),
				"elbow_l": Vector3(-0.6, -1, 0.3), "elbow_r": Vector3(0.6, -1, 0.3)},
			{"t": 0.26, "e": "out", "hips_pos": Vector3(0, -0.1, -0.12), "spine_rot": Vector3(-10, 0, 0),
				"hand_l": Vector3(-0.15, 1.34, -0.56), "hand_r": Vector3(0.15, 1.34, -0.56)},
			{"t": 0.42, "e": "io", "hand_l": Vector3(-0.03, 1.52, -0.3), "hand_r": Vector3(0.13, 1.5, -0.16)},
			{"t": 0.56},
		],
		"root": [[0.0, 0.0], [0.17, 0.26], [0.3, 0.3]],
		"hit": {"from": 0.13, "to": 0.22, "limb": "hand_r", "r": 0.22, "dmg": 1.5, "level": 1, "push": 1.75,
			"react": "stagger", "unblockable": true, "posture": 24.0, "clean": true},
	}
	# uppercut de contraataque: solo tras esquivar un golpe en el último momento
	m["uppercut"] = {
		"dur": 0.62, "kind": "attack", "cancel": 0.34, "chain": "", "track": 0.09,
		"reach": 0.62, "lunge": 0.5, "whoosh": [0.12, 1],
		"kf": [
			{"t": 0.0},
			{"t": 0.1, "e": "io", "hips_pos": Vector3(0, -0.25, 0.02), "hips_rot": Vector3(0, -32, -6),
				"spine_rot": Vector3(-14, 0, 0), "chest_rot": Vector3(-10, -18, 0),
				"hand_r": Vector3(0.17, 1.24, -0.12), "elbow_r": Vector3(0.4, -1, 0.3), "hand_l": Vector3(-0.04, 1.52, -0.28)},
			{"t": 0.19, "e": "in", "hips_pos": Vector3(0, -0.03, -0.07), "hips_rot": Vector3(0, 10, 0),
				"spine_rot": Vector3(6, 0, 0), "chest_rot": Vector3(4, 25, 0), "head_rot": Vector3(-14, -10, 0),
				"hand_r": Vector3(0.03, 1.64, -0.42), "elbow_r": Vector3(0.3, -1, 0.2), "hand_l": Vector3(-0.06, 1.55, -0.2)},
			{"t": 0.27, "e": "out", "hips_pos": Vector3(0, -0.02, -0.07), "hips_rot": Vector3(0, 12, 0),
				"spine_rot": Vector3(8, 0, 0), "chest_rot": Vector3(6, 28, 0),
				"hand_r": Vector3(0.02, 1.78, -0.32), "elbow_r": Vector3(0.3, -1, 0.2), "hand_l": Vector3(-0.06, 1.55, -0.2)},
			{"t": 0.45, "e": "io", "hand_r": Vector3(0.13, 1.52, -0.2), "chest_rot": Vector3(-3, -4, 0)},
			{"t": 0.62},
		],
		"root": [[0.0, 0.0], [0.19, 0.2], [0.35, 0.24]],
		"hit": {"from": 0.15, "to": 0.24, "limb": "hand_r", "r": 0.14, "dmg": 13.0, "level": 3, "push": 1.4,
			"react": "launch", "unblockable": true},
	}
	# gancho al cuerpo con la mano trasera
	m["body_hook"] = {
		"dur": 0.46, "kind": "attack", "cancel": 0.22, "track": 0.08,
		"reach": 0.62, "lunge": 0.5, "whoosh": [0.09, 1],
		"kf": [
			{"t": 0.0},
			{"t": 0.07, "e": "io", "hips_pos": Vector3(0, -0.17, 0.0), "hips_rot": Vector3(0, -30, 0),
				"chest_rot": Vector3(-10, -10, 0), "hand_r": Vector3(0.25, 1.24, -0.04), "elbow_r": Vector3(1, -0.3, 0.4),
				"hand_l": Vector3(-0.05, 1.56, -0.24)},
			{"t": 0.14, "e": "in", "hips_pos": Vector3(0, -0.21, -0.06), "hips_rot": Vector3(0, 14, 0),
				"spine_rot": Vector3(-12, 0, 0), "chest_rot": Vector3(-10, 26, 0), "head_rot": Vector3(-10, -14, 0),
				"hand_r": Vector3(-0.02, 1.17, -0.45), "elbow_r": Vector3(1, 0.1, 0.3), "hand_l": Vector3(-0.08, 1.56, -0.18)},
			{"t": 0.19, "e": "out", "hips_pos": Vector3(0, -0.21, -0.06), "hips_rot": Vector3(0, 18, 0),
				"spine_rot": Vector3(-12, 0, 0), "chest_rot": Vector3(-10, 30, 0),
				"hand_r": Vector3(-0.08, 1.18, -0.38), "elbow_r": Vector3(1, 0.1, 0.3), "hand_l": Vector3(-0.08, 1.56, -0.18)},
			{"t": 0.34, "e": "io", "hand_r": Vector3(0.14, 1.5, -0.18), "chest_rot": Vector3(-4, 0, 0)},
			{"t": 0.46},
		],
		"root": [[0.0, 0.0], [0.14, 0.14], [0.3, 0.16]],
		"hit": {"from": 0.11, "to": 0.18, "limb": "hand_r", "r": 0.14, "dmg": 7.0, "level": 2, "push": 0.7},
	}
	# patada baja al muslo: rápida, dobla la pierna del rival
	m["low_kick"] = {
		"dur": 0.5, "kind": "attack", "cancel": 0.28, "track": 0.07,
		"reach": 0.72, "lunge": 0.4, "whoosh": [0.1, 1],
		"kf": [
			{"t": 0.0},
			{"t": 0.08, "e": "io", "hips_pos": Vector3(0, -0.08, 0.03), "hips_rot": Vector3(0, -32, 0),
				"foot_r": Vector3(0.22, 0.24, 0.14), "fw_r": Vector3(1, 0.3, 0), "knee_r": Vector3(0.8, 0.2, -1),
				"hand_r": Vector3(0.24, 1.38, -0.06), "hand_l": Vector3(-0.04, 1.58, -0.26)},
			{"t": 0.16, "e": "in", "hips_pos": Vector3(0, -0.1, -0.03), "hips_rot": Vector3(0, 52, 8),
				"chest_rot": Vector3(0, 10, 4), "head_rot": Vector3(-6, -34, -6),
				"foot_r": Vector3(-0.12, 0.46, -0.68), "fw_r": Vector3(1, 1, 0), "knee_r": Vector3(1, 0.3, -0.2),
				"hand_r": Vector3(0.42, 1.22, 0.25), "hand_l": Vector3(-0.06, 1.58, -0.22)},
			{"t": 0.22, "e": "out", "hips_pos": Vector3(0, -0.1, -0.02), "hips_rot": Vector3(0, 68, 8),
				"foot_r": Vector3(-0.34, 0.4, -0.45), "fw_r": Vector3(1, 1, 0), "knee_r": Vector3(1, 0.3, 0.0),
				"hand_r": Vector3(0.4, 1.25, 0.2)},
			{"t": 0.36, "e": "io", "foot_r": Vector3(0.12, 0.24, 0.06), "fw_r": Vector3(0.6, 0.2, 0),
				"hips_rot": Vector3(0, -10, 0)},
			{"t": 0.5},
		],
		"root": [[0.0, 0.0], [0.16, 0.14], [0.3, 0.16]],
		"hit": {"from": 0.12, "to": 0.2, "limb": "foot_r", "r": 0.19, "dmg": 6.0, "level": 2, "push": 0.6,
			"react": "hit_leg", "region": "legs"},
	}
	# rodillazo al cuerpo a corta distancia
	m["knee"] = {
		"dur": 0.5, "kind": "attack", "cancel": 0.26, "track": 0.07,
		"reach": 0.5, "lunge": 0.3, "whoosh": [0.09, 1],
		"kf": [
			{"t": 0.0},
			{"t": 0.07, "e": "io", "hand_l": Vector3(-0.1, 1.5, -0.4), "hand_r": Vector3(0.1, 1.5, -0.4),
				"elbow_l": Vector3(-1, -0.4, 0), "elbow_r": Vector3(1, -0.4, 0), "chest_rot": Vector3(-8, 0, 0),
				"hips_rot": Vector3(0, -8, 0), "foot_r": Vector3(0.12, 0.28, 0.26), "fw_r": Vector3(1, 0.5, 0)},
			{"t": 0.15, "e": "in", "hand_l": Vector3(-0.1, 1.32, -0.44), "hand_r": Vector3(0.1, 1.32, -0.44),
				"elbow_l": Vector3(-1, -0.4, 0), "elbow_r": Vector3(1, -0.4, 0), "chest_rot": Vector3(-18, 0, 0),
				"hips_rot": Vector3(-8, 10, 0), "hips_pos": Vector3(0, 0.02, -0.1), "head_rot": Vector3(-18, 0, 0),
				"foot_r": Vector3(0.06, 0.7, -0.24), "fw_r": Vector3(1, 0.7, 0), "knee_r": Vector3(0, 1, -0.6)},
			{"t": 0.21, "e": "out", "hand_l": Vector3(-0.1, 1.35, -0.42), "hand_r": Vector3(0.1, 1.35, -0.42),
				"chest_rot": Vector3(-16, 0, 0), "hips_rot": Vector3(-6, 8, 0), "hips_pos": Vector3(0, 0.0, -0.08),
				"foot_r": Vector3(0.06, 0.64, -0.24), "fw_r": Vector3(1, 0.7, 0), "knee_r": Vector3(0, 1, -0.6)},
			{"t": 0.36, "e": "io", "foot_r": Vector3(0.14, 0.2, 0.12), "fw_r": Vector3(0.5, 0, 0)},
			{"t": 0.5},
		],
		"root": [[0.0, 0.0], [0.15, 0.12], [0.3, 0.14]],
		"hit": {"from": 0.11, "to": 0.2, "limb": "knee_r", "r": 0.17, "dmg": 9.0, "level": 2, "push": 0.8},
	}
	# patada giratoria hacia atrás: el remate de una serie larga
	m["spin_kick"] = {
		"dur": 0.82, "kind": "attack", "cancel": 99.0, "track": 0.06, "ender": true,
		"reach": 1.0, "lunge": 0.6, "whoosh": [0.24, 2],
		"spin": [[0.0, 0.0], [0.1, -25.0], [0.27, -185.0], [0.42, -200.0], [0.7, -360.0]],
		"kf": [
			{"t": 0.0},
			{"t": 0.1, "e": "io", "hips_pos": Vector3(0, -0.13, 0.0), "chest_rot": Vector3(-6, -18, 0),
				"head_rot": Vector3(-6, 25, 0), "hand_l": Vector3(-0.08, 1.55, -0.26), "hand_r": Vector3(0.14, 1.52, -0.12)},
			{"t": 0.24, "e": "io", "hips_pos": Vector3(0, -0.1, 0.0), "spine_rot": Vector3(-14, 0, 0),
				"head_rot": Vector3(0, 150, 0), "foot_r": Vector3(0.05, 0.62, -0.1), "fw_r": Vector3(1, 0.2, 0),
				"knee_r": Vector3(0, 0.5, -1), "hand_l": Vector3(-0.15, 1.5, -0.25), "hand_r": Vector3(0.2, 1.45, -0.1)},
			{"t": 0.32, "e": "in", "hips_pos": Vector3(0, -0.04, -0.12), "spine_rot": Vector3(-28, 0, 0),
				"chest_rot": Vector3(-10, 0, 0), "head_rot": Vector3(8, 160, 0),
				"foot_r": Vector3(0.0, 1.05, 0.92), "fw_r": Vector3(1, 0.0, 0), "knee_r": Vector3(0, -1, 0.2),
				"hand_l": Vector3(-0.3, 1.2, -0.35), "hand_r": Vector3(0.3, 1.25, -0.3)},
			{"t": 0.42, "e": "out", "hips_pos": Vector3(0, -0.05, -0.1), "spine_rot": Vector3(-24, 0, 0),
				"head_rot": Vector3(8, 150, 0), "foot_r": Vector3(0.0, 1.0, 0.86), "fw_r": Vector3(1, 0.0, 0),
				"knee_r": Vector3(0, -1, 0.2), "hand_l": Vector3(-0.3, 1.2, -0.35), "hand_r": Vector3(0.3, 1.25, -0.3)},
			{"t": 0.62, "e": "io", "foot_r": Vector3(0.12, 0.3, 0.1), "fw_r": Vector3(0.7, 0, 0), "spine_rot": Vector3(-6, 0, 0)},
			{"t": 0.82},
		],
		"root": [[0.0, 0.0], [0.32, 0.36], [0.5, 0.42]],
		"hit": {"from": 0.27, "to": 0.37, "limb": "foot_r", "r": 0.21, "dmg": 14.0, "level": 3, "push": 1.7,
			"react": "launch"},
	}
	# reacción: la pierna adelantada cede tras la patada baja
	m["hit_leg"] = {
		"dur": 0.5, "kind": "react",
		"kf": [
			{"t": 0.0},
			{"t": 0.05, "e": "out", "hips_pos": Vector3(0, -0.24, 0.04), "hips_rot": Vector3(0, -32, -10),
				"spine_rot": Vector3(-12, 0, 8), "chest_rot": Vector3(-6, -6, 6), "head_rot": Vector3(-10, 10, 8),
				"foot_l": Vector3(-0.04, 0.14, -0.04), "fw_l": Vector3(0.8, 0.2, 0), "knee_l": Vector3(0.3, -0.2, -1),
				"hand_l": Vector3(-0.2, 1.35, -0.24), "hand_r": Vector3(0.2, 1.38, -0.12)},
			{"t": 0.22, "e": "io", "hips_pos": Vector3(0, -0.19, 0.02), "hips_rot": Vector3(0, -26, -5),
				"spine_rot": Vector3(-8, 0, 4), "foot_l": Vector3(-0.1, 0.1, -0.12), "fw_l": Vector3(0.4, 0, 0),
				"hand_l": Vector3(-0.1, 1.45, -0.28), "hand_r": Vector3(0.16, 1.45, -0.14)},
			{"t": 0.5},
		],
		"root": [[0.0, 0.0], [0.1, -0.07]],
	}
	m["dodge"] = {
		"dur": 0.38, "kind": "dodge", "iframes": [0.02, 0.24],
		"kf": [
			{"t": 0.0},
			{"t": 0.1, "e": "out", "hips_pos": Vector3(0, -0.17, 0.0), "spine_rot": Vector3(-12, 0, 0),
				"chest_rot": Vector3(-8, -10, 0), "hand_l": Vector3(-0.08, 1.45, -0.22), "hand_r": Vector3(0.1, 1.45, -0.15)},
			{"t": 0.24, "e": "io", "hips_pos": Vector3(0, -0.14, 0.0), "spine_rot": Vector3(-8, 0, 0),
				"hand_l": Vector3(-0.08, 1.5, -0.25), "hand_r": Vector3(0.1, 1.5, -0.15)},
			{"t": 0.38},
		],
		"root": [[0.0, 0.0], [0.07, 0.25], [0.24, 1.15], [0.36, 1.25]],
	}
	m["parry_deflect"] = {
		"dur": 0.34, "kind": "dodge",
		"kf": [
			{"t": 0.0},
			{"t": 0.06, "e": "out", "hand_l": Vector3(0.12, 1.72, -0.42), "elbow_l": Vector3(-1, -0.3, 0),
				"chest_rot": Vector3(-4, -30, 0), "hips_rot": Vector3(0, -30, 0), "hips_pos": Vector3(0, -0.1, -0.03)},
			{"t": 0.16, "e": "io", "hand_l": Vector3(0.18, 1.62, -0.3), "chest_rot": Vector3(-4, -26, 0),
				"hips_rot": Vector3(0, -28, 0)},
			{"t": 0.34},
		],
		"root": [[0.0, 0.0], [0.08, 0.05]],
	}

	# --- Reacciones (escritas con empuje hacia la derecha de la víctima) -------
	m["hit_head"] = {
		"dur": 0.4, "kind": "react",
		"kf": [
			{"t": 0.0},
			{"t": 0.045, "e": "out", "head_rot": Vector3(18, -34, -14), "chest_rot": Vector3(9, -16, -7),
				"spine_rot": Vector3(5, 0, -4), "hips_pos": Vector3(0, -0.09, 0.05),
				"hand_l": Vector3(-0.2, 1.48, -0.24), "hand_r": Vector3(0.3, 1.36, -0.02)},
			{"t": 0.17, "e": "io", "head_rot": Vector3(8, -16, -7), "chest_rot": Vector3(5, -10, -3),
				"hips_pos": Vector3(0, -0.1, 0.04), "hand_l": Vector3(-0.1, 1.5, -0.28), "hand_r": Vector3(0.2, 1.45, -0.1)},
			{"t": 0.4},
		],
		"root": [[0.0, 0.0], [0.07, -0.13], [0.25, -0.18]],
	}
	# variante pesada: la cabeza gira con el tronco y el cuerpo da medio paso
	m["hit_head_b"] = {
		"dur": 0.5, "kind": "react",
		"kf": [
			{"t": 0.0},
			{"t": 0.05, "e": "out", "head_rot": Vector3(10, -48, -20), "chest_rot": Vector3(6, -30, -10),
				"spine_rot": Vector3(4, -10, -7), "hips_rot": Vector3(0, -34, -4), "hips_pos": Vector3(0.05, -0.12, 0.06),
				"hand_l": Vector3(-0.3, 1.38, -0.18), "hand_r": Vector3(0.36, 1.3, 0.02),
				"foot_r": Vector3(0.22, 0.08, 0.32), "fw_r": Vector3(0.6, 0, 0)},
			{"t": 0.2, "e": "io", "head_rot": Vector3(4, -20, -8), "chest_rot": Vector3(3, -14, -4),
				"hips_pos": Vector3(0.03, -0.13, 0.04), "hand_l": Vector3(-0.15, 1.45, -0.26), "hand_r": Vector3(0.22, 1.42, -0.08)},
			{"t": 0.5},
		],
		"root": [[0.0, 0.0], [0.08, -0.16], [0.3, -0.22]],
	}
	# variante al hígado: se dobla hacia el lado golpeado y se protege las costillas
	m["hit_body_b"] = {
		"dur": 0.55, "kind": "react",
		"kf": [
			{"t": 0.0},
			{"t": 0.06, "e": "out", "spine_rot": Vector3(-18, -10, -16), "chest_rot": Vector3(-14, -14, -10),
				"head_rot": Vector3(6, -14, -10), "hips_pos": Vector3(0.06, -0.22, 0.08), "hips_rot": Vector3(0, -26, 8),
				"hand_l": Vector3(-0.14, 1.3, -0.28), "hand_r": Vector3(0.2, 1.06, -0.12), "elbow_r": Vector3(1, -0.3, 0.3)},
			{"t": 0.25, "e": "io", "spine_rot": Vector3(-14, -6, -10), "chest_rot": Vector3(-10, -8, -6),
				"hips_pos": Vector3(0.04, -0.2, 0.05), "hand_l": Vector3(-0.1, 1.4, -0.28), "hand_r": Vector3(0.18, 1.12, -0.14)},
			{"t": 0.55},
		],
		"root": [[0.0, 0.0], [0.08, -0.12], [0.3, -0.16]],
	}
	m["hit_body"] = {
		"dur": 0.46, "kind": "react",
		"kf": [
			{"t": 0.0},
			{"t": 0.05, "e": "out", "spine_rot": Vector3(-22, -6, -4), "chest_rot": Vector3(-16, -10, -4),
				"head_rot": Vector3(4, -10, 0), "hips_pos": Vector3(0, -0.17, 0.11),
				"hand_l": Vector3(-0.1, 1.24, -0.3), "hand_r": Vector3(0.13, 1.2, -0.26)},
			{"t": 0.2, "e": "io", "spine_rot": Vector3(-14, -2, -2), "chest_rot": Vector3(-10, -6, 0),
				"hips_pos": Vector3(0, -0.15, 0.07), "hand_l": Vector3(-0.08, 1.35, -0.3), "hand_r": Vector3(0.12, 1.32, -0.24)},
			{"t": 0.46},
		],
		"root": [[0.0, 0.0], [0.08, -0.15], [0.3, -0.2]],
	}
	m["stagger"] = {
		"dur": 0.9, "kind": "react",
		"kf": [
			{"t": 0.0},
			{"t": 0.05, "e": "out", "head_rot": Vector3(24, -36, -18), "chest_rot": Vector3(15, -20, -10),
				"spine_rot": Vector3(9, 0, -7), "hips_pos": Vector3(0, -0.06, 0.12),
				"hand_l": Vector3(-0.48, 1.35, 0.0), "hand_r": Vector3(0.5, 1.6, 0.12)},
			{"t": 0.35, "e": "io", "head_rot": Vector3(4, -12, -4), "chest_rot": Vector3(2, -8, 0),
				"spine_rot": Vector3(-6, 0, 0), "hips_pos": Vector3(0, -0.16, 0.05),
				"hand_l": Vector3(-0.28, 1.35, -0.2), "hand_r": Vector3(0.3, 1.35, -0.08)},
			{"t": 0.62, "e": "io", "hips_pos": Vector3(0, -0.12, 0.02), "hand_l": Vector3(-0.08, 1.5, -0.28),
				"hand_r": Vector3(0.18, 1.48, -0.14)},
			{"t": 0.9},
		],
		"root": [[0.0, 0.0], [0.1, -0.38], [0.5, -0.88], [0.7, -0.95]],
	}
	var lying := {"hips_pos": Vector3(0, -0.8, 0.3), "hips_rot": Vector3(82, 0, 0), "spine_rot": Vector3(4, 0, 0),
		"chest_rot": Vector3(4, 0, 4), "head_rot": Vector3(-22, -20, 0),
		"foot_l": Vector3(-0.22, 0.08, -0.62), "foot_r": Vector3(0.24, 0.08, -0.55),
		"fw_l": Vector3(1, 0.6, 0), "fw_r": Vector3(1, 0.6, 0),
		"knee_l": Vector3(-0.3, 0, -1), "knee_r": Vector3(0.3, 0, -1),
		"hand_l": Vector3(-0.5, 0.95, 0.35), "hand_r": Vector3(0.55, 0.95, 0.45),
		"elbow_l": Vector3(-1, 0, 0), "elbow_r": Vector3(1, 0, 0)}
	var launch_keys := [
		{"t": 0.0},
		{"t": 0.05, "e": "out", "head_rot": Vector3(28, -22, -10), "chest_rot": Vector3(20, -6, -8),
			"spine_rot": Vector3(15, 0, 0), "hips_pos": Vector3(0, -0.04, 0.16), "hips_rot": Vector3(10, 0, 0),
			"hand_l": Vector3(-0.45, 1.75, 0.15), "hand_r": Vector3(0.45, 1.6, 0.2),
			"foot_l": Vector3(-0.15, 0.3, -0.3), "foot_r": Vector3(0.15, 0.22, -0.2),
			"fw_l": Vector3(0.8, 0.5, 0), "fw_r": Vector3(0.8, 0.5, 0)},
		{"t": 0.36, "e": "io", "hips_pos": Vector3(0, -0.5, 0.22), "hips_rot": Vector3(52, 0, 0),
			"spine_rot": Vector3(10, 0, 0), "chest_rot": Vector3(8, 0, 0), "head_rot": Vector3(-28, -10, 0),
			"foot_l": Vector3(-0.16, 0.2, -0.7), "foot_r": Vector3(0.18, 0.3, -0.6),
			"fw_l": Vector3(1, 0.5, 0), "fw_r": Vector3(1, 0.5, 0),
			"hand_l": Vector3(-0.5, 1.5, 0.25), "hand_r": Vector3(0.5, 1.4, 0.3)},
		lying.merged({"t": 0.52, "e": "in"}, true),
		lying.merged({"t": 0.6, "e": "out", "hips_pos": Vector3(0, -0.73, 0.3), "chest_rot": Vector3(-2, 0, 4)}, true),
		lying.merged({"t": 0.75, "e": "io"}, true),
	]
	m["ko"] = {"dur": 99.0, "kind": "react", "hold": true, "kf": launch_keys.duplicate(true),
		"root": [[0.0, 0.0], [0.4, -1.7], [0.62, -2.0], [0.75, -2.05]]}
	var getup_keys := launch_keys.duplicate(true)
	getup_keys.append(lying.merged({"t": 1.15, "e": "io"}, true))
	getup_keys.append({"t": 1.45, "e": "io", "hips_pos": Vector3(0, -0.7, 0.18), "hips_rot": Vector3(32, -10, 0),
		"spine_rot": Vector3(-12, 0, 0), "chest_rot": Vector3(-12, 0, 0), "head_rot": Vector3(-10, 0, 0),
		"foot_l": Vector3(-0.2, 0.08, -0.42), "foot_r": Vector3(0.2, 0.08, -0.32),
		"fw_l": Vector3(1, 0, 0), "fw_r": Vector3(1, 0, 0),
		"knee_l": Vector3(-0.4, 1, -1), "knee_r": Vector3(0.4, 1, -1),
		"hand_l": Vector3(-0.36, 0.85, 0.25), "hand_r": Vector3(0.38, 0.85, 0.3)})
	getup_keys.append({"t": 1.78, "e": "io", "hips_pos": Vector3(0, -0.36, 0.05), "hips_rot": Vector3(-18, -20, 0),
		"spine_rot": Vector3(-10, 0, 0), "chest_rot": Vector3(-8, -6, 0),
		"foot_l": FOOT_L, "foot_r": FOOT_R, "fw_l": Vector3(1, 0, 0), "fw_r": Vector3(1, 0, 0),
		"hand_l": Vector3(-0.08, 1.55, -0.3), "hand_r": Vector3(0.14, 1.5, -0.15)})
	getup_keys.append({"t": 2.1})
	m["launch"] = {"dur": 2.1, "kind": "react", "kf": getup_keys, "iframes": [1.1, 2.0],
		"root": [[0.0, 0.0], [0.4, -1.6], [0.62, -1.9], [0.75, -1.95]]}
	m["wall_splat"] = {
		"dur": 1.0, "kind": "react", "next": "dazed",
		"kf": [
			{"t": 0.0},
			{"t": 0.045, "e": "out", "spine_rot": Vector3(18, 0, -4), "chest_rot": Vector3(14, -6, 0),
				"head_rot": Vector3(24, -10, -6), "hips_pos": Vector3(0, -0.02, 0.12),
				"hand_l": Vector3(-0.55, 1.5, 0.16), "hand_r": Vector3(0.55, 1.45, 0.16),
				"elbow_l": Vector3(-0.3, -1, 0.5), "elbow_r": Vector3(0.3, -1, 0.5)},
			{"t": 0.4, "e": "io", "spine_rot": Vector3(12, 0, -3), "chest_rot": Vector3(8, -4, 0),
				"head_rot": Vector3(-6, -10, -10), "hips_pos": Vector3(0, -0.1, 0.1),
				"hand_l": Vector3(-0.5, 1.3, 0.16), "hand_r": Vector3(0.5, 1.25, 0.16)},
			{"t": 1.0, "e": "io", "spine_rot": Vector3(-14, 0, 0), "chest_rot": Vector3(-10, 0, 0),
				"head_rot": Vector3(-16, 0, 0), "hips_pos": Vector3(0, -0.2, 0.05),
				"hand_l": Vector3(-0.2, 1.1, -0.2), "hand_r": Vector3(0.2, 1.1, -0.15)},
		],
		"root": [[0.0, 0.0], [0.05, -0.05], [0.4, 0.05], [0.9, 0.25]],
	}
	m["dazed"] = {
		"dur": 1.5, "kind": "react",
		"kf": [
			{"t": 0.0, "spine_rot": Vector3(-14, 0, 0), "chest_rot": Vector3(-10, 0, 0),
				"head_rot": Vector3(-16, 0, 0), "hips_pos": Vector3(0, -0.2, 0.05),
				"hand_l": Vector3(-0.2, 1.1, -0.2), "hand_r": Vector3(0.2, 1.1, -0.15)},
			{"t": 0.35, "e": "io", "head_rot": Vector3(-18, 18, 12), "chest_rot": Vector3(-8, 8, 5),
				"hips_pos": Vector3(0, -0.19, 0.03), "hand_l": Vector3(-0.22, 1.08, -0.2), "hand_r": Vector3(0.2, 1.12, -0.18)},
			{"t": 0.8, "e": "io", "head_rot": Vector3(-14, -16, -10), "chest_rot": Vector3(-6, -8, -4),
				"hips_pos": Vector3(0, -0.17, 0.03), "hand_l": Vector3(-0.2, 1.15, -0.2), "hand_r": Vector3(0.22, 1.1, -0.18)},
			{"t": 1.2, "e": "io", "head_rot": Vector3(-10, 8, 4), "hips_pos": Vector3(0, -0.13, 0.02),
				"hand_l": Vector3(-0.1, 1.35, -0.26), "hand_r": Vector3(0.16, 1.32, -0.16)},
			{"t": 1.5},
		],
		"root": [[0.0, 0.0], [0.6, -0.1], [1.2, -0.12]],
	}
	m["blockstun"] = {
		"dur": 0.26, "kind": "react", "guard": true,
		"kf": [
			{"t": 0.0},
			{"t": 0.04, "e": "out", "hips_pos": Vector3(0, -0.15, 0.08), "chest_rot": Vector3(2, -8, -2),
				"head_rot": Vector3(-6, -6, 0), "hand_l": Vector3(-0.06, 1.66, -0.18), "hand_r": Vector3(0.1, 1.66, -0.15)},
			{"t": 0.26},
		],
		"root": [[0.0, 0.0], [0.06, -0.18], [0.2, -0.24]],
	}
	m["parried"] = {
		"dur": 0.85, "kind": "react",
		"kf": [
			{"t": 0.0},
			{"t": 0.06, "e": "out", "spine_rot": Vector3(14, 0, 8), "chest_rot": Vector3(16, 22, 6),
				"head_rot": Vector3(16, 14, 0), "hips_pos": Vector3(0, -0.04, 0.1),
				"hand_l": Vector3(-0.45, 1.85, 0.08), "hand_r": Vector3(0.38, 1.25, 0.25)},
			{"t": 0.45, "e": "io", "spine_rot": Vector3(8, 0, 4), "chest_rot": Vector3(8, 12, 3),
				"head_rot": Vector3(6, 6, 0), "hips_pos": Vector3(0, -0.1, 0.06),
				"hand_l": Vector3(-0.35, 1.5, -0.05), "hand_r": Vector3(0.3, 1.3, 0.1)},
			{"t": 0.85},
		],
		"root": [[0.0, 0.0], [0.08, -0.3], [0.4, -0.45]],
	}
	m["guard_break"] = m["parried"].duplicate(true)
	m["guard_break"]["next"] = "dazed"
	m["guard_break"]["dur"] = 0.85
	m["clinched"] = {
		"dur": 0.5, "kind": "react",
		"kf": [
			{"t": 0.0},
			{"t": 0.14, "e": "io", "spine_rot": Vector3(-26, 0, 0), "chest_rot": Vector3(-16, 0, 0),
				"head_rot": Vector3(-28, 0, 0), "hips_pos": Vector3(0, -0.2, 0.04),
				"hand_l": Vector3(-0.16, 1.2, -0.3), "hand_r": Vector3(0.16, 1.2, -0.3)},
			{"t": 0.5, "e": "io", "spine_rot": Vector3(-34, 0, 0), "chest_rot": Vector3(-18, 0, 0),
				"head_rot": Vector3(-30, 0, 0), "hips_pos": Vector3(0, -0.24, 0.04),
				"hand_l": Vector3(-0.16, 1.1, -0.3), "hand_r": Vector3(0.16, 1.1, -0.3)},
		],
		"root": [[0.0, 0.0]],
		"hold": true,
	}

	for k in m.keys():
		m[k]["name"] = k
		if m[k].kind == "react":
			var mm: Dictionary = m[k].duplicate(true)
			mm.kf = []
			for key in m[k].kf:
				mm.kf.append(mirror(key))
			mm["name"] = k
			m[k + "@m"] = mm
	_cache = m
	return m


static func mirror(p: Dictionary) -> Dictionary:
	var q := {}
	for k in p:
		var v = p[k]
		var nk: String = k
		if k.ends_with("_l"):
			nk = k.substr(0, k.length() - 2) + "_r"
		elif k.ends_with("_r"):
			nk = k.substr(0, k.length() - 2) + "_l"
		if v is Vector3:
			if k in ROT_PARAMS:
				v = Vector3(v.x, -v.y, -v.z)
			elif k.begins_with("fw_"):
				pass
			else:
				v = Vector3(-v.x, v.y, v.z)
		q[nk] = v
	return q


static func curve(u: float, e: String) -> float:
	match e:
		"in":
			return u * u
		"out":
			return 1.0 - (1.0 - u) * (1.0 - u)
		"lin":
			return u
		_:
			return u * u * (3.0 - 2.0 * u)


## Muestrea un movimiento en el tiempo t, rellenando lo que falte con la pose base.
static func sample(move: Dictionary, t: float, base: Dictionary, amp := 1.0) -> Dictionary:
	var keys: Array = move.kf
	var i := 0
	while i < keys.size() - 2 and t >= float(keys[i + 1].t):
		i += 1
	var k0: Dictionary = keys[i]
	var k1: Dictionary = keys[min(i + 1, keys.size() - 1)]
	var t0 := float(k0.t)
	var t1 := float(k1.t)
	var u := 1.0 if t1 <= t0 else clampf((t - t0) / (t1 - t0), 0.0, 1.0)
	u = curve(u, k1.get("e", "io"))
	var out := {}
	for p in PARAMS:
		var b: Vector3 = base[p]
		var a: Vector3 = k0.get(p, b)
		var c: Vector3 = k1.get(p, b)
		if p == "foot_l" or p == "foot_r":
			# un objetivo de pie ausente conserva el de la otra clave mientras su peso se desvanece
			if not k0.has(p) and k1.has(p):
				a = c
			elif k0.has(p) and not k1.has(p):
				c = a
		var v := a.lerp(c, u)
		if amp != 1.0 and (p in ROT_PARAMS or p == "hips_pos"):
			v = b + (v - b) * amp
		out[p] = v
	return out


static func root_at(move: Dictionary, t: float) -> float:
	return curve_at(move.root, t)


static func curve_at(r: Array, t: float) -> float:
	if r.is_empty():
		return 0.0
	if t <= float(r[0][0]):
		return float(r[0][1])
	for i in range(r.size() - 1):
		var a: Array = r[i]
		var b: Array = r[i + 1]
		if t < float(b[0]):
			var u := (t - float(a[0])) / (float(b[0]) - float(a[0]))
			u = u * u * (3.0 - 2.0 * u)
			return lerpf(float(a[1]), float(b[1]), u)
	return float(r[r.size() - 1][1])
