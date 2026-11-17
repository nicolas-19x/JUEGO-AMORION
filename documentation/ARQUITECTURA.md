# Arquitectura

## Estructura de carpetas (`res://`)

```
autoload/        Sistemas globales (solo los imprescindibles)
  catalog.gd       catálogo de objetos, materiales y apariencias (lee data/)
  settings.gd      preferencias del dispositivo (volúmenes, hora, personaje, zoom)
  world_clock.gd   hora del mundo, color ambiental, factor de noche
  input_hub.gd     vector de movimiento (joystick; teclado solo para el editor)
  audio_director.gd buses Música/Efectos/Ambiente, bucles y efectos
scenes/
  main/main.tscn           entrada: escenario pixel-perfect + interfaz
  world/world.tscn         la isla
  characters/player.tscn   personaje jugable
scripts/
  main/       main.gd, pixel_stage.gd (SubViewport con escala entera)
  world/      world.gd, terrain_grid.gd, placed_object.gd, ambient_fx.gd, butterfly.gd
  player/     player.gd
  characters/ character_appearance.gd (capas + intercambio de paleta)
  camera/     world_camera.gd
  interface/  hud.gd, virtual_joystick.gd, touch_button.gd, settings_panel.gd, ui_theme.gd
  storage/    local_store.gd (JSON atómico + .bak)
shaders/      water, sway (vegetación), palette_swap (personajes), clouds
data/
  items/*.json         catálogo de objetos (un archivo por familia)
  world/materials.json materiales de terreno
  world/island_start.json  isla inicial (terreno + objetos)
  characters/appearance.json  capas, opciones y personajes predefinidos
assets/       sprites, terreno, personajes, efectos, audio, tipografía (generados)
tests/        run_tests.gd (pruebas sin pantalla), capture.gd (capturas reales)
tools/        generadores de arte y audio en Python (ignorados por Godot: .gdignore)
documentation/
```

## Flujo de arranque

`main.tscn` → `main.gd` crea un `PixelStage` (SubViewport), monta en él
`world.tscn` y añade el `Hud` encima. El `World` lee
`data/world/island_start.json`, construye el `TerrainGrid`, instancia cada
objeto del mapa como `PlacedObject`, crea al `Player`, la cámara, el
`CanvasModulate` del día/noche y el `AmbientFx`.

## Escenario pixel-perfect

`PixelStage` calcula un factor entero `pixel_scale = round(alto_físico /
alto_objetivo)` (alto objetivo 360/270/200 según el zoom), dimensiona el
SubViewport a `pantalla / pixel_scale` y lo muestra con filtro *nearest* a
exactamente `pixel_scale` píxeles físicos por píxel de arte. La interfaz usa el
modo de estiramiento `canvas_items` sobre una base de 1280×720 lógicos y se
dibuja nítida a resolución nativa.

## Terreno

`TerrainGrid` guarda un `PackedByteArray` de materiales. Cada material con
atlas tiene una `TileMapLayer` desplazada medio tile; cada tile visible mira
sus 4 celdas vecinas (dual-grid). `materials.json` define para cada material
qué capas lleva «debajo» (p. ej. la tierra lleva césped y arena), si es
caminable y qué sonido hacen los pasos. `paint(celda, material)` actualiza
4 tiles por capa, el campo de distancia del agua y las colisiones: es la base de
la herramienta de terreno de la Fase 2.

## Objetos

Un objeto del catálogo (`data/items/*.json`) declara:

```json
{
 "id": "bench", "name": "Banco", "category": "exterior",
 "sprite": "res://assets/furniture/bench.png",
 "anchor": [16, 19],          // píxel del sprite que va en el origen (pies)
 "footprint": [2, 1],         // celdas que ocupa
 "collision": [-15, -6, 30, 6], // rectángulo relativo al origen (opcional)
 "surfaces": ["grass", "dirt", "cobble"],
 "interaction": {"type": "sit", "label": "Sentarse", "seat": [0, -3]},
 "sway": {...}, "light": {...}, "night_overlay": "...", "emitter": "petals"
}
```

Tipos de interacción disponibles: `inspect` (texto), `sit`, `view`
(contemplación con cámara), `toggle_light`. Para añadir un objeto basta con
una entrada JSON y su PNG; no hay que tocar código.

`PlacedObject.to_data()` ya produce el registro serializable (uid, objeto,
celda, metadatos, estado de la luz) que usará el guardado del mundo.

## Interfaz

`Hud` (CanvasLayer) contiene el joystick flotante, el botón contextual, el
menú, el reloj, los textos y la cinemática. Los botones del HUD son
`TouchButton`, que leen `InputEventScreenTouch` de cualquier dedo; así se puede
pulsar mientras se mueve el joystick. El botón «atrás» de Android cierra lo que
esté abierto o abre los ajustes.

## Señales principales

- `World.interactable_changed(target)` → Hud muestra/oculta el botón de acción.
- `World.caption_requested(text)` → Hud muestra el texto del objeto.
- `World.cinematic_started / cinematic_finished` → franjas y zoom temporal.
- `Settings.changed(key)` → AudioDirector reaplica volúmenes.
- `Player.stepped(pos)` → World reproduce el paso según el suelo.

## Pruebas

- `godot --headless -s res://tests/run_tests.gd` — catálogo, mapa, guardado
  (incluida recuperación de copia dañada), arranque del mundo, pintado de
  terreno e interacciones.
- `xvfb-run godot --rendering-driver opengl3 --resolution 2400x1080 -s res://tests/capture.gd -- salida.png [day|night|sunset|dawn] [x y] [zoom] [title] [settings|interact]`
  — captura real del juego.

## Añadir cosas sin romper nada

| Quiero… | Toco… |
|---|---|
| un mueble/planta | `tools/art/props.py` (sprite) + `data/items/*.json` |
| un material de terreno | `tools/art/terrain.py` + `data/world/materials.json` |
| un color de pelo o ropa | `tools/art/palette.py` (rampa) + `data/characters/appearance.json` |
| un peinado | `tools/art/character.py` (plantilla `HAIR`) |
| una interacción nueva | `World.interact()` + tipo en el JSON |
