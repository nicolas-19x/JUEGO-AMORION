---
name: combate-verificar
description: Verificar el prototipo de combate (combate/) tras cualquier cambio de animación, golpes, IA, cámara o escenario - pruebas automáticas sin pantalla y capturas reales de poses y de un combate guionizado.
---

# Verificar el prototipo de combate

Todo se ejecuta desde `combate/`. Godot 4.6.2 debe estar en el PATH como `godot`.

1. Importar (tras añadir recursos): `godot --headless --import`
2. Pruebas: `godot --headless -s res://tests/run_tests.gd`
   - Deben terminar con `0 fallos`. Las líneas `nivel ...` resumen tres combates
     completos: impactos, bloqueos, vida final, distancia mínima y deslizamiento
     de pies (debe ser 0).
3. Capturas (necesitan display; usar `xvfb-run -a`, renderizador `opengl3`):
   - Pose congelada en un instante de un movimiento, vista desde un ángulo:
     `godot --rendering-driver opengl3 --resolution 640x480 -s res://tests/capture.gd -- <dir> pose <movimiento> <t> <grados>`
     Movimientos y tiempos de contacto: jab 0.115, cross 0.15, roundhouse 0.225,
     push_kick 0.265, clinch_knee 0.42; reacciones: hit_head 0.045,
     hit_body 0.05, stagger 0.05, launch 0.75, wall_splat 0.045.
   - Combate guionizado (captura cada 30 fotogramas):
     `... -s res://tests/capture.gd -- <dir> fight <0|1|2>`
   - Menú: `... -- <dir> menu`
4. Mirar las capturas antes de dar nada por bueno: silueta legible, rival en
   cuadro, manos y pies donde deben, sin cuadrados de efectos.

Reglas: no declarar un sistema terminado sin pruebas y capturas; no decir que
algo funciona en Android si no se ha probado en un teléfono.
