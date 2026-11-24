# Diseño y decisiones

## 1. Qué aprendemos de las referencias (principios, no recursos)

| Referencia | Principio que adoptamos | Cómo aparece aquí |
|---|---|---|
| Sifu | Cada golpe tiene preparación, contacto y recuperación legibles; las reacciones dependen de dónde y cómo te golpean; el desequilibrio es un estado jugable. | Reacciones por altura, lado y fuerza reales del contacto; aturdimiento tras rotura de guardia o pared; parada que deja al atacante abierto. |
| Absolver | Maniquíes enmascarados: silueta clara y estética estilizada sin producción hiperrealista. | Personajes-maniquí con máscara, visor luminoso, faja y cinta de tela. |
| Hi-Fi Rush | Ritmo y expresividad: poses claras, colores con intención. | Paleta complementaria (marfil/verde azulado vs. grafito/carmesí), poses de contacto marcadas, curvas de aceleración hacia el impacto. |
| Sleeping Dogs | Cámara cercana que acompaña; el entorno participa (paredes). | Golpe contra la pared con reacción propia, polvo y objetos que salen despedidos. |
| GTA V | Tercera persona que nunca pierde al personaje. | Cámara detrás y a un lado del jugador; el control siempre es del jugador. |
| Spider-Verse | Poses fuertes en momentos selectos, no animación "flotante". | Congelación de impacto (hit-stop) que sostiene la pose de contacto; estelas cortas solo durante los fotogramas activos. |

No se copia ningún personaje, escenario ni diseño. El escenario (azotea con
fachada de papel al atardecer) y los personajes son propios.

## 2. Motor: Godot 4.6 (frente a Unity URP)

- **Lo decisivo para este prototipo**: el sistema de animación es *procedural
  con poses escritas a mano + IK* (ver §4). No dependemos de Mecanim ni de un
  paquete de animaciones comerciales, que es la gran ventaja de Unity.
- Godot permite construir y **probar todo desde la línea de comandos** (pruebas
  sin pantalla, capturas reales con el renderizador de móvil). Iterar sin editor
  gráfico es imprescindible en este entorno y rápido en cualquiera.
- Exportación Android directa con plantillas precompiladas (sin Gradle), APK
  pequeño, sin licencias por ingresos.
- Renderizador **GL Compatibility** (OpenGL ES 3): el más compatible en Android
  de gama media/baja. Mobile (Vulkan) daría mejores sombras pero con más riesgo
  de fallos de driver; se puede probar después cambiando una línea.
- Unity sería preferible si el proyecto pasa a usar mucha captura de movimiento
  comercial y retargeting; para eso dejamos la arquitectura preparada (las poses
  son datos; una capa de clips importados podría sustituir a `FighterMoves`).

## 3. Dirección visual

Estilizado semi-realista: proporciones atléticas (1,8 m), formas limpias de
maniquí lacado, sin rasgos caricaturescos. Material propio con luz envolvente,
borde de luz cálido (fresnel) y contorno fino por casco invertido para que la
silueta se lea en una pantalla de 6". Atardecer con contraluz cálido, sombras
frías del cielo, niebla atmosférica que funde la ciudad lejana, linternas.
Todo generado por código: cero texturas externas.

## 4. Sistema de animación

Capas (de abajo arriba), en `scripts/fighter/fighter.gd`:

1. **Base**: guardia ↔ bloqueo como mezcla continua; postura de cansancio con
   poca vida (guardia más baja, respiración más agitada).
2. **Acción**: golpes, esquivas y reacciones como poses clave con curvas de
   llegada por segmento (acelerar hacia el contacto, frenar en la recuperación).
3. **Inercialización**: al cambiar de acción no se mezclan dos animaciones; se
   guarda la diferencia con la pose anterior y se desvanece (técnica de
   Gears of War / Bungie). Transiciones sin saltos y sin el retraso de un
   *crossfade*: el golpe empieza en el fotograma en que se pulsa.
4. **Aditivos**: muelles amortiguados en pecho, cabeza y caderas que reciben el
   impulso real del golpe (dirección y fuerza), inclinación por velocidad,
   respiración, rebote de los pasos y mirada al rival.

**IK de dos huesos** para brazos y piernas: las poses dicen *dónde* van manos y
pies; la patada llega exactamente a la altura de la cabeza, la mano exactamente
al frente. **Planificador de pasos**: los pies apoyados son puntos del mundo y
solo cambian dando un paso (arco, duración según velocidad) → no patinan
(comprobado en las pruebas: deslizamiento 0). **Desplazamiento raíz con
deformación (motion warping)**: cada golpe estira o acorta su avance para
contactar a la distancia justa (máximo configurable), sin atravesar ni golpear
al aire por centímetros. **Sincronía entre personajes**: el remate coloca a la
víctima frente al atacante y ambos avanzan con el mismo reloj.

**Variedad por sistemas, no por azar**: el lado de la reacción sale de la
velocidad real del miembro que golpea; la altura, del punto de contacto; la
amplitud, de la fuerza; los contragolpes (golpear durante el ataque rival) suben
un nivel de reacción; el tercer impacto de una serie tambalea; cerca de una
pared el tambaleo se convierte en choque contra la pared. Los sonidos tienen
varias variantes y nunca repiten la anterior; el tono varía ligeramente.

Movimientos (pocos y cuidados): jab, directo, patada circular (combo),
patada frontal cargable (rompe guardias), remate (agarre + rodillazo),
guardia, parada y esquiva. Reacciones: cabeza, cuerpo, tambaleo, derribo con
caída y levantada, contra la pared, aturdido, bloqueo, desequilibrio tras
parada, rotura de guardia, KO.

## 5. Sensación de impacto

Hit-stop por nivel (50–170 ms, más en contragolpes y KO) con temblor de la
víctima en la dirección del golpe; destello breve del material; chispas y anillo
de choque discretos; estela del miembro solo en los fotogramas activos;
sacudida de cámara por "trauma" (cuadrática, decae sola); golpe de zoom en
impactos fuertes; vibración háptica proporcional; cámara lenta y plano
cinematográfico en el KO.

## 6. Cámara

Detrás y a un lado del jugador, mirando al punto medio entre ambos: el rival
siempre en cuadro. Distancia y altura según la separación; ángulo lateral que
crece de cerca para que el protagonista no tape al rival. Giro perezoso (zona
muerta) para no marear. Raycast contra paredes y un volumen "solo cámara" en la
copa del árbol. La cámara nunca mueve al personaje: el joystick es relativo a la
cámara y el personaje encara al rival por sí mismo.

## 7. Escenario e interacción

Dos interacciones, bien hechas: **pared** (reacción propia, polvo, sonido,
sacudida, la víctima queda aturdida = remate disponible) y **objetos físicos**
(cajas y tinajas que los cuerpos empujan y que salen despedidas en el choque
contra la pared).

## 8. IA

Estados implícitos: tanteo a distancia preferida, rodeo, entrar/salir, ataque
con combos de longitud variable, castigo de golpes fallados, contraataque tras
bloquear el final de una serie, guardia bajo presión, remate. Lee la
*preparación* de los golpes del jugador con un retraso humano (120–340 ms según
nivel) y decide bloquear, esquivar o (rara vez) parar; la patada fuerte la
esquiva antes que bloquearla. Comete errores a propósito: no ver un golpe,
atacar desde demasiado lejos. Humor cambiante (prudente/agresivo). Si queda
arrinconada, rodea hacia el centro.

## 9. Android

Horizontal, inmersivo, joystick flotante, zonas táctiles 30 % mayores que el
dibujo, área segura (muescas). Rendimiento previsto desde la arquitectura:
1 luz direccional con sombras (2 cascadas, 22 m), 2 luces puntuales, partículas
CPU de pocas unidades, materiales sin texturas, mallas primitivas de pocos
polígonos, un solo paso de simulación ordenado sin señales costosas.
