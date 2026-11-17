# Plan del estudio — Nuestro pequeño universo

Análisis de dirección técnica y creativa (punto 31 del prompt maestro). Este
documento recoge las decisiones de base; el estado real del trabajo está en
[ESTADO.md](ESTADO.md).

## 1. Lectura del encargo

Un mundo 2D privado para **dos personas**, en **Android**, que debe poder crecer
durante años. La prioridad es la belleza y la sensación de lugar vivo; la
infraestructura debe ser mínima. Tres ideas guían todas las decisiones:

1. **Pequeño y precioso antes que grande y vacío.** Una isla de 56×40 celdas,
   densa en detalles, en lugar de un mapa enorme.
2. **Todo es dato.** El terreno es una cuadrícula de materiales, cada objeto es
   una entrada de catálogo con posición. Esto hace posible a la vez el
   guardado, la edición libre (Fase 2) y la sincronización por cambios (Fase 4).
3. **El romanticismo sale de lo personal.** Nada de corazones genéricos: la isla
   se llenará de fotos, cartas y plantas que significan algo para vosotros.

## 2. Decisiones técnicas fundamentales

| Decisión | Elección | Motivo |
|---|---|---|
| Motor | Godot 4.6, GDScript | Requisito. Ligero, exporta APK sin Android Studio. |
| Renderizador | GL Compatibility | El más estable en móviles de gama media; soporta luces 2D. |
| Píxeles | Mundo en SubViewport de baja resolución × **factor entero** | Píxeles idénticos en cualquier pantalla, sin desenfoque. |
| Interfaz | A resolución nativa (no pixelada), tipografía Nunito | Texto legible en cartas y menús; estética «indie + app moderna». |
| Orientación | Horizontal (sensor) fija | Explorar y construir lo aprovechan; evita cambios bruscos. Las pantallas de lectura se diseñarán para horizontal. |
| Terreno | Dual-grid propio sobre `TileMapLayer` | Transiciones siempre limpias; pintar una celda solo toca 4 tiles. |
| Agua | Shader con campo de distancia a la costa | Profundidad, espuma y oleaje animados sin dibujar cientos de tiles. |
| Objetos | Catálogo JSON (`data/items/`) | Añadir un mueble = una entrada + un sprite. |
| Personajes | Capas con intercambio de paleta (shader) | Personalización ilimitada de colores sin multiplicar imágenes. |
| Hora | Hora real del teléfono (configurable) | Si jugáis de noche, en la isla también es de noche. |
| Guardado local | JSON atómico + copia `.bak` | Nunca un archivo a medio escribir. |
| Backend (Fase 4) | Supabase (Auth + Postgres + Storage + RLS) | Estándar, suficiente para 2 personas, sin servidores propios. |

## 3. Arquitectura en Godot

Ver [ARQUITECTURA.md](ARQUITECTURA.md). Resumen de capas:

- **Motor del mundo** — `scripts/world`, `scripts/player`, `scripts/camera`
- **Sistemas de juego** — interacciones (ya), construcción e inventario (Fase 2)
- **Información** — `autoload/catalog.gd`, `data/`, `scripts/storage`
- **Interfaz** — `scripts/interface`
- **Servicios externos** — `scripts/sync` (Fase 4, todavía no existe)

## 4. Universo compartido sin complejidad innecesaria

Diseño completo en [UNIVERSO_COMPARTIDO.md](UNIVERSO_COMPARTIDO.md). La clave:

- Nada de «un archivo con todo el mundo». Cada objeto, celda de terreno
  modificada, foto o carta es **una fila** con id estable, autor, fecha y versión.
- El juego guarda primero en local y mantiene una **cola de operaciones**
  pendientes; al haber conexión las envía y recibe las del otro.
- Conflictos: si ambos tocan el mismo elemento gana el cambio más reciente,
  pero la versión perdedora se conserva en un historial; nada se pierde en silencio.
- No hace falta multijugador en tiempo real: cada uno entra cuando quiere.

## 5. Limitaciones de Android a tener en cuenta

- **Firma del APK:** para actualizar sin borrar datos, todas las versiones deben
  firmarse con **la misma clave**. Hay que crearla una vez y guardarla bien
  (ver [ANDROID.md](ANDROID.md)).
- **Ciclo de vida:** Android puede cerrar la app en segundo plano. Se guarda al
  pausar (`NOTIFICATION_APPLICATION_PAUSED`) y el guardado es atómico.
- **Multitáctil:** Godot solo convierte el primer dedo en ratón. Por eso los
  botones del HUD leen toques directamente (`TouchButton`), para poder moverse
  y pulsar a la vez.
- **Pantallas:** proporciones de 16:9 a 21:9 y muescas. El mundo se expande
  horizontalmente y la interfaz respeta el área segura.
- **Rendimiento:** gama media → GL Compatibility, partículas por CPU, pocas
  luces, texturas pequeñas, sin post-procesado caro.
- **Fotos:** las cámaras actuales producen fotos de 3–8 MB. Habrá que reducirlas
  (≈1600 px, JPEG) antes de guardarlas y subirlas.
- **Selector de fotos:** Godot no trae un selector nativo de galería en
  Android; en la Fase 3/5 habrá que usar `DisplayServer.file_dialog_show`
  (Android 4.3+) o un plugin pequeño. Es un riesgo a validar pronto.

## 6. Riesgos y cómo se mitigan

| Riesgo | Mitigación |
|---|---|
| Arte inconsistente al crecer el catálogo | Arte generado por código con una sola paleta y reglas ([DIRECCION_ARTISTICA.md](DIRECCION_ARTISTICA.md)). |
| Supabase gratis **pausa el proyecto tras 1 semana sin actividad** | Tarea programada semanal (GitHub Actions) que hace una consulta ligera; o plan Pro si se prefiere. Además el juego funciona sin conexión. |
| 1 GB de almacenamiento gratuito | Compresión de fotos (≈300 KB → ~3000 fotos) y exportación periódica. |
| Pérdida de datos al actualizar | Misma clave de firma; datos en `user://`; pruebas de actualización. |
| Conflictos al editar a la vez | Filas por elemento + versión + historial. |
| Selector de fotos en Android | Prototipo temprano en Fase 3. |
| No poder probar en teléfonos desde aquí | Capturas reales con Godot, pruebas automáticas y lista de pruebas manuales. |

## 7. Fases

1. **Fundamentos y prototipo artístico** ← *en curso, casi completa*
2. Construcción y personalización (selección, catálogo, inventario, mover/rotar,
   validación, pintar terreno, guardado local del mundo, deshacer/rehacer)
3. Personajes y hogar (dos personajes, editor de apariencia, interiores, cuadros
   con fotos reales)
4. Cuentas y universo compartido (Supabase, invitación privada, sincronización)
5. Recuerdos y experiencias (archivo, buzón, jardín simbólico, línea de tiempo,
   misiones, actividades, «¿Qué hacemos hoy?»)
6. Expansión y pulido (zonas nuevas, clima, cápsula del tiempo)
7. Pruebas y distribución en los dos teléfonos

## 8. Primera versión realmente buena (punto 30)

Entra en la v1: todo lo de las Fases 1–5 en su forma básica. Queda para después:
multijugador visual en tiempo real, islas adicionales, clima avanzado, cápsula
del tiempo, juegos de dibujo, grandes cantidades de objetos.
