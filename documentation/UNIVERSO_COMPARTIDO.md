# Universo compartido (diseño para la Fase 4)

> Estado: **solo diseño**. No hay sincronización implementada todavía; el juego
> actual es totalmente local.

## Servicio: Supabase

Auth (cuentas con correo), Postgres con Row Level Security, Storage privado
para fotos. Desde Godot se usa la API REST/HTTP con la clave pública (*anon* o
*publishable*); **la clave de servicio nunca va dentro del juego**.

Límites del plan gratuito (consultados en noviembre de 2026; revisar antes de
empezar la fase): 500 MB de base de datos, **1 GB** de archivos, y **el proyecto
se pausa tras 1 semana sin actividad**. Consecuencias:

- Fotos reducidas en el teléfono (≈1600 px, JPEG calidad 80 → ~300 KB).
- Una tarea programada semanal (p. ej. GitHub Actions) que haga una consulta
  ligera para que no se pause; o pasar al plan Pro si se prefiere.
- Como el juego funciona sin conexión, una pausa nunca impide jugar.

## Modelo de datos (por elementos, nunca un archivo único)

```
universes(id, name, created_by, created_at)
members(universe_id, user_id, character jsonb, joined_at)        -- máx. 2
invites(code, universe_id, created_by, expires_at, used_by)
objects(id uuid, universe_id, item, cell_x, cell_y, variant, data jsonb,
        placed_by, updated_by, updated_at, version int, deleted bool)
terrain_cells(universe_id, x, y, material, updated_by, updated_at, version)
memories(id, universe_id, title, date, description, author, media_path,
         tags text[], collection, favorite, created_at, version, deleted)
letters(id, universe_id, author, recipient, body, status: draft|sent|scheduled,
        deliver_at, opened_at, version)
history(id, universe_id, table_name, row_id, previous jsonb, replaced_by, at)
```

## Seguridad (RLS)

- Todas las tablas: acceso solo si `auth.uid()` es miembro del universo.
- `letters` con `status = 'draft'`: solo el autor.
- `letters` programadas: el destinatario no puede leer el cuerpo antes de
  `deliver_at` (política con `now() >= deliver_at`).
- Storage: bucket privado `memories/<universe_id>/…`, URLs firmadas de corta
  duración; política por pertenencia al universo.
- Invitaciones: código aleatorio de un solo uso con caducidad; una función
  `join_universe(code)` (SECURITY DEFINER) valida y añade al miembro. Sin
  buscador de usuarios.

## Sincronización

1. Cada cambio local genera una **operación** (`upsert`/`delete` de una fila)
   con `id` estable, autor, fecha y `version + 1`, y se aplica al estado local.
2. Las operaciones se guardan en una cola en `user://sync_queue.json` (atómico).
3. Con conexión: se envían en orden. El servidor acepta si
   `version_entrante = version_servidor + 1`; si no, hay conflicto.
4. Para recibir: se piden las filas con `updated_at > último_sync`.
5. **Conflictos:** gana el cambio más reciente, y la versión perdedora se copia
   en `history`. El juego muestra un aviso discreto («Tu pareja también movió
   esta lámpara; se conservó su versión. Ver la tuya»). Nada se pierde en
   silencio.
6. Cambiar una lámpara solo toca la fila de esa lámpara: nunca se sobrescribe
   una foto ni el resto de la isla.

## Registro de actividad

Derivado de `placed_by`/`updated_by`/`created_at`: «Ana plantó un cerezo
junto al lago · ayer». Útil y discreto, sin registrar movimientos.

## Exportación

Un botón «Exportar recuerdos» que genera un ZIP con las fotos originales y un
JSON/HTML legible con títulos, fechas y cartas, para no depender del juego.
