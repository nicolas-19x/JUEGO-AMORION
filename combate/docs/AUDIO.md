# Audio

Todos los efectos, voces y música de la versión 0.5.0 se generaron con **ElevenLabs**
(herramientas de efectos de sonido, música y voz) y se procesaron con
`tools/process_audio.py`. Los originales (mp3) no están en el repositorio; los archivos
del juego son `assets/audio/eleven/*.ogg` (Vorbis, ~8 MB en total).

Debajo de los golpes sigue sonando una capa grave sintetizada (`assets/audio/*.wav`,
generada con `tools/gen_audio.py`) para darles peso en los graves de un altavoz de móvil.

## Qué se generó

| Banco | Variantes | Descripción del prompt (resumen) | Modelo |
|---|---|---|---|
| `hit_l` | 4 | puñetazo ligero a la cara, seco, con un leve chasquido carnoso | eleven_text_to_sound_v3 |
| `hit_m` | 4 | puñetazo a la mandíbula, nudillo contra hueso y carne | idem |
| `hit_h` | 4 | patada circular a la cabeza, golpe grave con un crujido corto | idem |
| `hit_b` | 3 | golpe al estómago, sordo y hondo | idem |
| `hit_k` | 3 | patada baja al muslo, chasquido de cuero y golpe sordo | idem |
| `block` | 3 | antebrazos y vendas absorbiendo un golpe | idem |
| `parry` | 2 | parada perfecta, chasquido brillante de antebrazos | idem |
| `whoosh_p` / `whoosh_k` | 3 + 3 | aire cortado por un puño / por una pierna | idem |
| `step` | 4 | pisada con roce de zapatilla sobre piedra | idem |
| `fall` / `wall` / `ko` | 3 / 3 / 2 | caída sobre piedra / choque contra pared de madera y papel / golpe final con cola de subgraves | idem |
| `effort` | 4 | soplido de esfuerzo al golpear («hah») | idem |
| `pain` | 4 | quejido corto de dolor («ugh») | idem |
| `winded` | 3 | sin aire tras golpe al estómago («oof» y jadeo) | idem |
| `scream` | 3 | grito de furia en golpes pesados | idem |
| `breath` | 2 | respiración agitada de un luchador herido | idem |
| `spit` | 3 | toser y escupir sangre | idem |
| `gong`, `win`, `lose` | 2 + 2 + 2 | gong de inicio / remate de victoria / de derrota | idem |
| `ui_tap` | 2 | clic suave de interfaz | idem |
| `amb_0` | 1 (de 2) | ambiente de azotea al atardecer: viento, ciudad lejana, campanilla | idem |
| `music_combat_1` | 1 (de 2) | música instrumental de pelea, taiko, subgraves, 92 bpm (3 min) | eleven_music_v2_5 |
| `music_menu_0` | 1 (de 2) | música instrumental de menú, drone cálido y flauta (2,5 min) | idem |
| `vo_combate`, `vo_victoria`, `vo_derrota` | 2 cada una | locutor: «¡Combate!», «Victoria.», «Derrota.» | eleven_v4 |

Voz del locutor: **Japa – Narrador Cinematográfico Profundo** (`ifgQptCyquMG1K4fdoT3`,
voz de la biblioteca de ElevenLabs, español latino).

Costo aproximado de la generación: ~5.800 créditos (≈ 1 USD), de los cuales ~1.800
fueron las dos pistas de música que sobraron y ~1.000 una transcripción para comprobar
que la música no llevaba voces (no las llevaba).

## Cómo suena en el juego

- **Golpes**: banco según la zona (cara: ligero/medio/pesado según la fuerza; cuerpo;
  pierna), base grave sintetizada debajo y capa húmeda si hay sangre.
- **Voces**: el rival suena ~16 % más grave que el jugador. Atacar: soplido; golpes
  fuertes (giratoria, patada frontal, uppercut, rodillazo): grito. Recibir: quejido, o
  «sin aire» si es al cuerpo; al estamparse contra la pared y al romperse la guardia
  también. Con menos del 40 % de vida respiran cada 4,5–7,5 s. Un hablante no repite
  voz en menos de ~0,2–0,4 s.
- **Locutor y pistas**: gong + «¡Combate!» al empezar; sting + «Victoria»/«Derrota» al
  acabar. La música del menú pasa a la de combate con un fundido de 2 s y baja de volumen
  un instante (*ducking*) en los golpes grandes y el KO. El ambiente suena siempre.
- **Cámara lenta**: el sonido se ralentiza con el juego (el KO y el contraataque suenan
  más graves, como en el cine).

## Pendiente / a revisar

- **Nadie ha escuchado el audio todavía** (yo solo he podido medir niveles y duraciones).
  Los niveles relativos están pensados y medidos, pero el gusto hay que juzgarlo oyéndolo.
- Los gruñidos y quejidos son efectos de sonido de texto a audio: pueden sonar menos
  «humanos» que una voz grabada. Si no convencen, alternativas: diseñar una voz de
  luchador y generar los esfuerzos como habla, o grabar voces propias.
- **Licencia**: antes de publicar el juego, revisar los términos de uso comercial de
  ElevenLabs para tu plan y para la voz de la biblioteca usada en el locutor.
- La música solo se comprobó (por transcripción) en la pista de combate; las de menú
  se pidieron igual y deberían ser instrumentales.
