extends SceneTree
## Convierte el binario de tools/model_prep.py en un ArrayMesh con huesos y pesos.
## godot --headless -s res://tools/build_model.gd -- entrada.bin res://assets/characters/nico/nico.res

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var f := FileAccess.open(args[0], FileAccess.READ)
	var jl := f.get_32()
	var meta: Dictionary = JSON.parse_string(f.get_buffer(jl).get_string_from_utf8())
	var n: int = int(meta.count)
	var tris: int = int(meta.tris)
	var pos := f.get_buffer(n * 12).to_float32_array()
	var nor := f.get_buffer(n * 12).to_float32_array()
	var col := f.get_buffer(n * 16).to_float32_array()
	var bones := f.get_buffer(n * 16).to_int32_array()
	var weights := f.get_buffer(n * 16).to_float32_array()
	var idx := f.get_buffer(tris * 12).to_int32_array()

	var v := PackedVector3Array()
	var nn := PackedVector3Array()
	var cc := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	v.resize(n); nn.resize(n); cc.resize(n); uv.resize(n); uv2.resize(n)
	for i in n:
		var p := Vector3(pos[i * 3], pos[i * 3 + 1], pos[i * 3 + 2])
		v[i] = p
		nn[i] = Vector3(nor[i * 3], nor[i * 3 + 1], nor[i * 3 + 2])
		cc[i] = Color(col[i * 4], col[i * 4 + 1], col[i * 4 + 2], col[i * 4 + 3])
		# posición de reposo para el daño (el shader la recibe sin deformar)
		uv[i] = Vector2(p.x, p.y)
		uv2[i] = Vector2(p.z, 0.0)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nn
	arr[Mesh.ARRAY_COLOR] = cc
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_BONES] = bones
	arr[Mesh.ARRAY_WEIGHTS] = weights
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.set_meta("bones", meta.bones)
	mesh.set_meta("face", meta.face)
	mesh.set_meta("joints", meta.joints)
	DirAccess.make_dir_recursive_absolute(args[1].get_base_dir())
	var err := ResourceSaver.save(mesh, args[1], ResourceSaver.FLAG_COMPRESS)
	print("guardado ", args[1], " err=", err, " vértices=", n, " triángulos=", tris)
	quit()
