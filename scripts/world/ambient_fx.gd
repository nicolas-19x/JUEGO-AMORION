class_name AmbientFx
extends Node2D
## Vida ambiental: sombras de nubes, luciérnagas de noche, mariposas de día,
## pétalos del cerezo y humo de chimenea.

const CLOUDS_SHADER := preload("res://shaders/clouds.gdshader")

var _fireflies: Array[CPUParticles2D] = []


func build(world_size: Vector2, firefly_spots: Array, butterfly_spots: Array) -> void:
	var clouds := ColorRect.new()
	clouds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clouds.position = Vector2(-256, -256)
	clouds.size = world_size + Vector2(512, 512)
	var m := ShaderMaterial.new()
	m.shader = CLOUDS_SHADER
	clouds.material = m
	clouds.z_index = 30
	add_child(clouds)
	for p in firefly_spots:
		var f := _fireflies_at(p)
		_fireflies.append(f)
		add_child(f)
	for p in butterfly_spots:
		var b := Butterfly.new()
		b.home = p
		add_child(b)


func _process(_delta: float) -> void:
	var on := WorldClock.night_factor() > 0.55
	for f in _fireflies:
		if f.emitting != on:
			f.emitting = on


static func petals(at: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = load("res://assets/fx/petal.png")
	p.amount = 5
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.position = at
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(14, 6)
	p.direction = Vector2(1, 0.3)
	p.spread = 30.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.0
	p.gravity = Vector2(2, 5)
	p.z_index = 6
	p.local_coords = false
	p.color_ramp = _grad([0.0, 0.1, 0.85, 1.0], [0.0, 1.0, 1.0, 0.0])
	return p


static func chimney_smoke(at: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = load("res://assets/fx/smoke.png")
	p.amount = 7
	p.lifetime = 4.5
	p.preprocess = 4.5
	p.position = at
	p.direction = Vector2(0, -1)
	p.spread = 12.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 8.0
	p.gravity = Vector2(3.5, -1.5)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.4
	p.z_index = 7
	p.local_coords = false
	p.color_ramp = _grad([0.0, 1.0], [0.75, 0.0])
	return p


## Nubecita de polvo al colocar, mover o quitar un objeto.
static func dust(at: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = load("res://assets/fx/soft_particle.png")
	p.amount = 10
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 0.95
	p.position = at + Vector2(0, -2)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(8, 2)
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.initial_velocity_min = 14.0
	p.initial_velocity_max = 26.0
	p.gravity = Vector2(0, 30)
	p.damping_min = 20.0
	p.damping_max = 30.0
	p.z_index = 9
	p.color = Color(1.0, 0.97, 0.88)
	p.color_ramp = _grad([0.0, 0.5, 1.0], [0.9, 0.6, 0.0])
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


func _fireflies_at(at: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = load("res://assets/fx/soft_particle.png")
	p.amount = 9
	p.lifetime = 5.0
	p.position = at
	p.emitting = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(56, 28)
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector2.ZERO
	p.z_index = 8
	p.color = Color(1.0, 0.95, 0.55)
	p.color_ramp = _grad([0.0, 0.3, 0.6, 0.8, 1.0], [0.0, 1.0, 0.3, 1.0, 0.0])
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.material = mat
	return p


## Degradado blanco con la opacidad indicada en cada punto.
static func _grad(offsets: Array, alphas: Array) -> Gradient:
	var g := Gradient.new()
	var cols := PackedColorArray()
	for a in alphas:
		cols.append(Color(1, 1, 1, a))
	g.offsets = PackedFloat32Array(offsets)
	g.colors = cols
	return g
