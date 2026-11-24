# Estado del prototipo

Versión 0.1.0 · 24 de noviembre de 2026

## Verificado

- **Pruebas automáticas** (`tests/run_tests.gd`): ~1700–1750 comprobaciones (varía con la duración de los combates), 0 fallos.
  Datos de movimientos, IK, parada, bloqueo, rotura de guardia, esquiva,
  choque contra la pared (sin atravesarla), remate sincronizado, y tres
  combates completos (uno por dificultad) contra un jugador guionizado que
  ataca sin parar: sin valores inválidos, cuerpos que no se atraviesan
  (distancia mínima ~0,6 m), pies apoyados sin deslizamiento, ambos atacan.
  El resultado varía entre ejecuciones (la IA es aleatoria): en Aprendiz el
  jugador "aporreador" suele ganar; en Duelo y Maestro gana o pierde.
- **Capturas reales** con el renderizador GL Compatibility (`tests/capture.gd`):
  menú, poses de contacto y reacciones, combate guionizado. Ver `docs/capturas/`.

## No verificado todavía

- ❌ **APK no exportado.** En este entorno de desarrollo la red no permite
  descargar el Android SDK (dl.google.com bloqueado); las plantillas de Godot sí
  están. Hay que exportar en un ordenador con el SDK (ver README).
- ❌ **Nada probado en un teléfono**: rendimiento real, tacto de los controles,
  vibración, muescas, temperatura.
- ❌ **El sonido no se ha escuchado**: está sintetizado y medido (niveles), pero
  nadie lo ha oído aún. Es provisional.
- ⚠️ El "game feel" solo se ha juzgado con capturas y datos; necesita manos
  humanas para ajustar tiempos (hit-stop, ventanas de combo, velocidad).

## Lista para la primera prueba en Android

- [ ] Se instala y arranca en horizontal a pantalla completa.
- [ ] ≥ 55 FPS estables durante un combate (mirar con el monitor de Godot).
- [ ] Joystick + GOLPE a la vez; respuesta inmediata del jab.
- [ ] Parada: ¿la ventana de 160 ms es justa o frustrante?
- [ ] Vibración perceptible pero no molesta.
- [ ] Botones no tapados por la muesca; legibles en 6".
- [ ] 10 minutos de juego: temperatura y estabilidad.

## Siguientes pasos (por prioridad, sin añadir contenido por añadirlo)

1. Probar en teléfono y ajustar tiempos con sensaciones reales.
2. Mejorar las formas de los personajes (manos con dedos simplificados, pies
   con talón) y valorar un modelo esculpido con el mismo esqueleto lógico.
3. Pasos laterales de la IA más variados y lectura de patrones del jugador.
4. Segunda interacción de escenario más cinematográfica (barandilla/tinajas que
   se rompen) solo si la primera demuestra valor en el teléfono.
