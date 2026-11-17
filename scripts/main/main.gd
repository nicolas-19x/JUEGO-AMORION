extends Control
## Punto de entrada: monta el escenario pixel-perfect con la isla y la interfaz.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

var stage: PixelStage
var world: World
var hud: Hud


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	stage = PixelStage.new()
	stage.name = "Stage"
	add_child(stage)
	world = WORLD_SCENE.instantiate()
	stage.mount(world)
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup(world, stage)
	AudioDirector.start_world_audio()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if world:
			world.save_player_position()
