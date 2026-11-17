# Android: exportar, instalar y actualizar

## Estado

- ✅ El APK de depuración **se ha exportado de verdad** con Godot 4.6.2 en el
  entorno de desarrollo (arm64-v8a + armeabi-v7a, destino Android 15/API 35,
  ~57 MB) y la firma se ha verificado con `apksigner`.
- ❌ **No se ha instalado ni probado en ningún teléfono todavía.**

## Requisitos (una sola vez)

1. Godot 4.6.2 y sus *export templates* (Editor → Manage Export Templates).
2. JDK 17 o superior.
3. Android SDK con `platform-tools`, `build-tools;35.0.1` y `platforms;android-35`.
4. En Godot: Editor → Editor Settings → Export → Android → rutas del SDK y del JDK.

## Clave de firma: MUY importante

Android solo permite **actualizar** una app si la versión nueva está firmada con
**la misma clave**. Si cambia la clave, hay que desinstalar la app y se
**pierden los datos locales**.

Crear la clave del proyecto una sola vez:

```bash
keytool -genkeypair -v -keystore nuestro_universo.keystore -alias universo \
  -keyalg RSA -keysize 2048 -validity 20000
```

- Guárdala en un lugar seguro, con copia (nunca en el repositorio).
- En `export_presets.cfg` → `keystore/release`, `keystore/release_user`,
  `keystore/release_password` (o en el diálogo de exportación de Godot).
- Las versiones de prueba actuales usan una clave de depuración del entorno de
  desarrollo; cuando haya clave definitiva habrá que desinstalar una vez.

## Exportar

```bash
godot --headless --import                       # la primera vez
godot --headless --export-debug "Android" export/nuestro_universo.apk
# versión final:
godot --headless --export-release "Android" export/nuestro_universo.apk
```

Antes de cada versión, sube `version/code` (entero) y `version/name` en
`export_presets.cfg`.

## Instalar en los teléfonos

- Opción A: copiar el APK al teléfono y abrirlo (activar «Instalar apps de
  orígenes desconocidos» para el gestor de archivos o el navegador).
- Opción B: `adb install -r export/nuestro_universo.apk` por USB
  (`-r` = reemplazar conservando datos).

## Los datos sobreviven a las actualizaciones

Todo se guarda en `user://` (almacenamiento interno de la app). Una
actualización con la misma clave y un `version/code` mayor **conserva** esos
datos. Desinstalar los borra (`retain_data_on_uninstall=false`).

## Lista de pruebas en el teléfono (pendientes)

- [ ] La app se instala y abre en horizontal, a pantalla completa.
- [ ] El joystick responde y el personaje se mueve con fluidez (~60 FPS).
- [ ] Moverse y pulsar el botón de acción a la vez funciona.
- [ ] Pellizcar acerca y aleja la cámara.
- [ ] Sentarse, contemplar, encender faroles, leer textos.
- [ ] Botón atrás: cierra paneles / abre ajustes.
- [ ] Audio: música, olas, pasos; los volúmenes y el silencio funcionan.
- [ ] La hora real se refleja (probar de noche).
- [ ] Muescas y bordes: nada importante queda tapado.
- [ ] Cerrar y volver a abrir: el personaje aparece donde estaba.
- [ ] Actualizar con una versión nueva sin perder datos.
- [ ] Temperatura y batería tras 15 minutos.
