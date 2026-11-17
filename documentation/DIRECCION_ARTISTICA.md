# Dirección artística

Guía de estilo para que cada sprite pertenezca al mismo universo. Todo el arte
actual se genera con los scripts de `tools/art/` a partir de una paleta única,
así que es reproducible y coherente.

## Identidad

Acogedor, cálido, ligeramente mágico (cerezos que siempre florecen, luciérnagas,
el mar que respira). No infantil ni recargado de símbolos románticos. Los
detalles personales llegarán con los recuerdos.

## Estándares técnicos

| Parámetro | Valor |
|---|---|
| Tamaño de tile | **16×16 px** |
| Resolución interna de referencia | **270 px de alto** (zoom medio). Zoom: 360 / 270 / 200 px |
| Escalado | Siempre **entero** (×2, ×3, ×4…), filtro *nearest*, sin interpolación |
| Personajes | Frame 16×32, figura de ~22 px (cabeza grande, proporción acogedora) |
| Árboles | 32–40 px de ancho, 50–56 px de alto |
| Casa | 104×112 px (huella de 6×3 tiles) |
| Perspectiva | Cenital en 3/4: los suelos se ven desde arriba y los objetos muestran su cara frontal |
| Luz | Desde **arriba a la izquierda**. Luces a la izquierda y arriba, sombras abajo a la derecha |
| Contorno | Selectivo: el tono más oscuro de la rampa de cada material, **nunca negro puro** |
| Sombras proyectadas | Elipses violeta semitransparente (`#18122828`-ish), no grises |
| Dithering | Ordenado (Bayer 4×4), solo para transiciones de volumen; nunca ruido aleatorio en superficies grandes |

## Paleta

Definida en `tools/art/palette.py`. Rampas de 4–8 tonos de oscuro a claro para:
césped, hojas (dos verdes), flor de cerezo, otoño, tierra, arena, piedra,
adoquín, agua (8 tonos), madera (dos), tejado, yeso, hierro, pieles, pelos,
telas, calzado, flores y luz cálida. **Ningún sprite debe usar colores fuera
de la paleta**; para un material nuevo, primero se añade su rampa.

## Terreno (dual-grid)

- Cada material tiene un atlas de 20×4 tiles: 16 combinaciones de esquinas,
  4 variantes decoradas del tile lleno y 4 fases del patrón (período de 32 px
  para que no se note la repetición).
- Bordes redondeados (radio 8 px) con ruido periódico: formas orgánicas pero
  continuas entre tiles.
- Cada material tiene su estilo de borde: el césped está **elevado** (briznas
  colgantes y sombra al sur), la tierra **hundida** (sombra al norte), la arena
  tiene borde **húmedo**, el adoquín un **bordillo** y la madera un **canto**
  con sombra sobre el agua.
- Orden de capas: agua → arena → césped → tierra → adoquín → madera.

## Animación

- Caminar: 4 frames a 8 fps, con rebote de 1 px en los pasos.
- Reposo: respiración de 1 px cada 1,6 s.
- Vegetación: balanceo por shader, cuantizado a píxeles enteros, solo en la
  parte superior del sprite.
- Agua: bandas de profundidad, espuma de orilla que respira, trazos de oleaje y
  destellos; todo calculado por píxel del mundo.
- Ambiente: sombras de nubes, pétalos, humo de chimenea, mariposas (día),
  luciérnagas (noche).

## Iluminación

`CanvasModulate` según la hora: noche azul-violeta, amanecer rosado, día neutro,
atardecer anaranjado. De noche se encienden faroles (`PointLight2D`), ventanas de
la casa (capa aditiva) y luciérnagas.

## Composición

- Cada zona tiene un punto focal (casa, fuente, catalejo, muelle).
- Caminos de tierra que conectan las zonas y guían la mirada.
- Bordes de la isla con árboles altos para enmarcar; el centro, más despejado.
- Nada de rellenar por rellenar: el espacio vacío también es parte del diseño
  y se reserva para lo que vosotros construyáis.

## Interfaz

Nítida a resolución nativa. Crema cálido `#fbf3e4`, tinta `#3b2a2e`, acento
terracota `#c8705a`, salvia `#5e8f74`. Esquinas redondeadas y sombras suaves.
Tipografía **Nunito** (OFL). Botones grandes (≥ 80 px lógicos), siempre al
alcance de los pulgares.

## Estado del arte

Todo el arte actual es **definitivo para la Fase 1** salvo lo marcado como
provisional en [ESTADO.md](ESTADO.md) (sonido, valla lateral, buhardilla).
