# Estado del prototipo

Versión 0.5.0 · 25 de noviembre de 2026

## Novedades de la 0.5.0

**Audio completo con ElevenLabs** (detalle en [AUDIO.md](AUDIO.md)): 74 efectos y voces
en bancos con variantes que no se repiten (golpes por zona y fuerza, bloqueo, parada,
whooshes de puño y de patada, pasos, caídas, pared, KO), voces de los luchadores con
tono distinto (esfuerzo, grito, quejido, «sin aire», escupir sangre, respiración agitada
con poca vida), locutor en español («¡Combate!», «Victoria», «Derrota»), gong y stings,
música de menú y de combate con fundido entre ellas y *ducking* en los golpes grandes, y
ambiente de azotea. Los golpes llevan debajo una base grave sintetizada.

**Verificado:** ~2400 comprobaciones, 0 fallos (incluye que todos los bancos de audio
carguen completos, que ninguna variante se repita dos veces seguidas y que un hablante no
se pise). Niveles medidos con LUFS: música ≈ −27 LUFS efectivos, golpes y voces ≈ −22.
**No escuchado por nadie todavía**, y sin probar en teléfono.

## Novedades de la 0.4.0 (anterior)

## Novedades de la 0.4.0

**Arte de los cuerpos (escultura por código, `scripts/fighter/body_meshes.gd`):**
- Cada pieza es una malla propia hecha con anillos de sección superelíptica:
  deltoides, bíceps y tríceps, antebrazo, puño vendado con nudillos, torso en V
  con pectorales y dorsales, abdomen, pelvis con glúteos, cuello con trapecio,
  pantalón holgado, zapatillas con suela.
- Cabeza esculpida: mandíbula, barbilla, pómulos, arco superciliar, cuencas de
  los ojos, nariz con puente y punta, orejas. Pelo y barba son la misma forma
  recortada por el shader (línea del pelo con entradas, patillas, barba con
  bigote): se ajustan al cráneo en vez de ser bolas.
- Shader: musculatura marcada (esternón, pectorales, clavículas, abdominales),
  vendas con bandas y costuras, pliegues de tela con relieve, labios, sombra de
  cuencas, mejillas. La camiseta se rompe donde se acumulan golpes y deja ver la
  piel; la camiseta y la piel de debajo reciben el mismo golpe.
- Sombras a 4096 px con alcance ajustado al patio: menos dientes de sierra.

**Física parcial:** un muelle amortiguado por articulación (cadera, columna,
pecho, cabeza, cadera en posición, manos). Cada golpe aplica el par de giro
real (punto de contacto × dirección del miembro): un directo a la cara lanza la
cabeza hacia atrás, un gancho la gira, uno al cuerpo dobla la columna. Inercia:
el tronco y la cabeza van con retraso al frenar, arrancar o girar (latigazo).
Tono muscular: firme de pie, flojo al recibir, muy suelto aturdido y en el
suelo; la cabeza rebota al caer y contra la pared.

**Puntos de contacto corregidos:** los puñetazos apuntaban ~12 cm bajos (al
cuello); ahora van a la cara, y el punto de impacto se toma de donde está el
puño, no del eje del cuerpo (mejora física, sangre y moretones).

**Vibración con matices:** 11 patrones de varios pulsos (seco, medio, pesado,
contragolpe, bloqueo, parada, guardia rota, pared, caída, KO, esquiva), en
tiempo real aunque haya cámara lenta; recibir vibra algo más que golpear.

**Cámara:** plano de remate (corte lateral bajo + cámara lenta) cuando el
jugador derriba; repetición del KO a cámara lenta, de lado, con bandas de cine
y "toca para saltar".

**Ajustes:** en pausa, deslizadores en vivo para pausa de impacto, velocidad
del juego, sacudida, vibración y ventana de combo (se guardan). En el menú,
Calidad gráfica Alta/Baja (sombras, brillo, partículas, manchas, antialiasing).

**Verificado:** ~2370 comprobaciones, 0 fallos (incluye física que cede y vuelve
a reposo, patrón de vibración, plano de remate, grabación y repetición
completas). Capturas de retrato, primeros planos, secuencias fotograma a
fotograma de directo y patada giratoria, combate y repetición revisadas.
**Sin probar en teléfono**: rendimiento y vibración reales pendientes.



## Novedades de la 0.3.0

**Golpear se siente mejor (prioridad absoluta):**
- Cuatro botones: GOLPE, PATADA, DEFENSA y ESQUIVA (toque propio). Teclado
  equivalente.
- Series largas: los puños encadenan en bucle (jab, directo, gancho, gancho al
  cuerpo). Si el golpe conecta, el siguiente sale justo después del contacto:
  machacar el botón es fluido. La PATADA remata la serie (circular; desde el 4.º
  golpe, patada giratoria que derriba con giro completo del cuerpo).
- Golpes nuevos: gancho al cuerpo, patada baja (dobla la pierna y deja cojera),
  rodillazo corto y patada giratoria. Contraataque tras esquiva con puño
  (uppercut) o patada (giratoria).
- El atacante nunca recula para "encajar" la distancia dentro de una serie: si
  está más cerca, el golpe conecta antes (antes esto hacía fallar el gancho).
- El rival se libera solo: cada golpe seguido acorta su aturdimiento y al
  noveno sale despedido.

**Reacciones:** sin el destello blanco al recibir. Variantes que nunca se
repiten dos veces seguidas (giro de cabeza con medio paso, doblarse hacia el
hígado con la mano en las costillas, pierna que cede), elegidas por la
dirección y la fuerza reales del golpe.

**Colisiones:** nadie sale del patio ni atraviesa paredes o la jardinera, ni de
pie ni tumbado (la cabeza y los pies del cuerpo caído también se comprueban). El
agarre del remate retrocede al atacante si la víctima no cabe. Un agarre fallido
ya no deja a la víctima atrapada. Las patadas bajas ahora tienen dónde golpear
(zona de impacto desde las rodillas).

**Sangre:** chorros de regueros alargados y gotas, escupir sangre en golpes
fuertes a la cara (y al cuerpo muy castigado), cara que se va cubriendo de
sangre, goteo que mancha pecho y camiseta, salpicaduras sobre el cuerpo y las
vendas de quien golpea, charco que crece bajo quien yace sangrando, gran mancha
con regueros que bajan por la pared al estamparse, hasta 90 manchas en el
escenario. Sigue sin gore: nada de miembros ni huesos.

**Verificado:** ~2000 comprobaciones, 0 fallos, con pruebas nuevas de series
largas (≥6 golpes seguidos, mezcla de golpes, liberación al noveno), patada
como remate, patada baja, y derribos y KO junto a paredes y jardinera sin
atravesarlas. Capturas revisadas. **Sin probar en teléfono**: el rendimiento
con mucha sangre en pantalla está por medir.


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
