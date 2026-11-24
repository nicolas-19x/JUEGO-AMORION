# CONTACTO — prototipo de combate 3D para Android

Proyecto independiente (no tiene relación con el juego de la isla de este
repositorio). Un enfrentamiento, dos personajes, un escenario: todo el esfuerzo
está puesto en que cada golpe se sienta bien.

![Menú](docs/capturas/menu.jpg)
![Combate](docs/capturas/combate.jpg)
![Heridas](docs/capturas/heridas.jpg)

## Estado

**Versión 0.2.0: segundo prototipo.** Luchadores callejeros con cara, piel y
ropa; daño visible por zona (moretones donde cae el golpe, nariz y labio que
sangran, ceja abierta, ojo hinchado, sangre en la camiseta, el suelo y la pared);
barra de equilibrio, golpes que dependen de la distancia, empujón y
contraataque tras esquiva. **APK exportado** (ver `../apk/`). Las pruebas automáticas pasan (~1800
comprobaciones) y el juego se ha revisado con capturas reales del renderizador
GL Compatibility. **Aún no se ha probado en un teléfono** (ver
[docs/ESTADO.md](docs/ESTADO.md)).

## Jugar en el ordenador

1. Godot 4.6 estándar → abrir `combate/project.godot` → ▶.
2. El ratón simula el dedo. Teclado de ayuda: WASD mover · J golpe · L patada
   fuerte · K defensa (con dirección = esquiva) · I remate · P pausa.

## Controles táctiles (horizontal)

| Control | Acción |
|---|---|
| Joystick flotante (mitad izquierda) | Moverse; el personaje siempre encara al rival. |
| **GOLPE** | Según la situación: a media distancia jab → directo → patada circular; pegado al rival, gancho corto; joystick hacia el rival, patada frontal fuerte (mantener = cargar); joystick hacia atrás, empujón (contra la pared lo estampa). |
| **DEFENSA** | Mantener: guardia (llena la barra de equilibrio; llena = guardia rota). Tocar justo antes del impacto: parada. Con dirección lateral: esquiva de cintura; si un golpe pasa rozando, el botón se vuelve **CONTRA** y sale un uppercut a cámara lenta. Con dirección hacia atrás: paso atrás. |
| **REMATE** | Solo aparece si el rival está aturdido: agarre + rodillazo. |

En el menú: **Sangre: Normal / Reducida / Apagada** (se recuerda).

## Pruebas y capturas

```bash
godot --headless --import
godot --headless -s res://tests/run_tests.gd
xvfb-run -a godot --rendering-driver opengl3 -s res://tests/capture.gd -- /tmp fight 1
xvfb-run -a godot --rendering-driver opengl3 -s res://tests/capture.gd -- /tmp pose roundhouse 0.225 70
```

## Android

Con Android SDK (build-tools 35 y platform-tools), JDK 17+ y las plantillas de
exportación de Godot 4.6.2 configuradas en el editor:

```bash
godot --headless --export-debug "Android" export/contacto.apk
adb install -r export/contacto.apk
```

El preset ya pide el permiso de vibración, pantalla completa inmersiva y
arm64-v8a + armeabi-v7a.

## Sonido

Todo sintetizado y original: `python3 tools/gen_audio.py assets/audio`.

## Documentación

- [Diseño y decisiones](docs/DISENO.md): investigación, motor, dirección
  visual, sistema de animación, cámara, IA, controles y optimización.
- [Estado honesto y siguientes pasos](docs/ESTADO.md)

## Licencias

Todo el código, las formas, los shaders y los sonidos son propios del proyecto.
No se usan recursos externos. Tipografía: la fuente por defecto de Godot.
