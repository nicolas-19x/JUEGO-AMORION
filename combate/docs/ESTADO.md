# Estado del prototipo

Versión 0.2.0 · 24 de noviembre de 2026

## Novedades de la 0.2.0 (segundo prototipo)

**Visual y violencia (contenida, sin gore):**
- Personajes rediseñados como peleadores callejeros: piel, cara (nariz, cejas,
  ojos, boca, orejas, pelo, moño o barba), camiseta de tirantes o torso desnudo,
  pantalón, vendas en las manos (ya no parecen guantes de boxeo).
- Daño por zona con un shader propio: cada impacto deja marca en el punto real
  de contacto (rojo → moretón morado; en ropa, mancha de sangre). La cara
  acumula nariz sangrando, labio partido, ceja abierta en el lado golpeado y ojo
  que se hincha y se cierra. Torso castigado = postura encorvada. Sudor con el
  cansancio. Todo se limpia en la revancha.
- Sangre: salpicadura corta en impactos fuertes, gotas que caen de la nariz o la
  ceja mientras sangra y manchas que se quedan en suelo y pared (máx. 40).
- Capa de sonido "húmeda" en golpes fuertes. Opción Sangre: Normal / Reducida /
  Apagada.

**Dinámica:**
- Barra de equilibrio bajo la vida: bloquear la llena; llena = guardia rota y
  aturdido (remate disponible). Se recupera sola sin presión.
- El mismo botón elige el golpe: pegado al rival sale un gancho corto; atrás +
  golpe es un empujón sin daño que rompe el equilibrio y estampa contra la pared.
- Esquiva lateral de cintura: si un golpe pasa rozando, se abre una ventana de
  contraataque (el botón brilla y dice CONTRA) y sale un uppercut a cámara lenta
  que derriba.
- La IA usa todo lo anterior: esquiva lateral y contraataca, empuja para abrir
  guardias o salir de las esquinas, y entra en distancia cuando quiere golpear.

**Verificado (0.2.0):** 0 fallos en ~1800 comprobaciones, incluidas pruebas de
gancho/empujón por contexto, empujón contra la pared, esquiva → uppercut de
contragolpe, rotura de guardia por equilibrio, lesiones visibles y revancha
limpia. Capturas reales de heridas (`docs/capturas/heridas.jpg`). APK exportado
y firma verificada. **Sin probar en teléfono.**

**Pendiente de ajustar con manos reales:** el jugador que aporrea el botón
todavía gana a menudo en Aprendiz y Duelo; los combos encadenados no dejan
escapar a la víctima (es intencionado, pero puede necesitar más huecos).


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
