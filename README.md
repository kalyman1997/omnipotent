# omnipotent by kaly

Launcher ligero para preparar y abrir el modo offline de una instalación compatible de Black Ops 7 en Windows de 64 bits.

## Uso

1. Descarga **Omnipotent.exe** de [Releases](https://github.com/kalyman1997/omnipotent/releases/tag/launcher-1.1.0).
2. Abre el ejecutable. Detecta la instalación en las bibliotecas locales de Xbox, incluidas las rutas personalizadas de `.GamingRoot`. Respeta una carpeta guardada que siga siendo válida. Si encuentra varias instalaciones o ninguna, pulsa **Elegir carpeta** (cod25, Content o su carpeta superior).
3. Pulsa **Instalar**. La primera instalación necesita internet y descarga aproximadamente 1 GB, menos si ya hay archivos válidos en el equipo.
4. Cuando termine la verificación, pulsa **Play**.

No necesitas descargar manualmente los archivos con nombres largos de la release. El launcher los selecciona y verifica automáticamente. No necesitas Railway ni abrir el launcher de Kronos.

## Mods

La pestaña **Mods** incluye **Abrir trainer**. El primer clic descarga el trainer de Zombies individual (aproximadamente 15 MB), comprueba SHA-256, prepara sus dependencias y abre su ventana. Las siguientes aperturas utilizan la copia local; no necesitan Python instalado ni otra descarga si la copia es válida. Un segundo clic enfoca la ventana existente.

Antes de la primera partida con mods, utiliza **Preparar juego** dentro del trainer para instalar su script y reinicia el juego si ya estaba abierto. Abrir el trainer desde el launcher no instala el script ni activa opciones automáticamente. Conserva las funciones y límites del trainer v0.5 existente; esta actualización verifica su apertura, no todos sus efectos en partida.

La interfaz 1.1.0 es compacta: encabezado **omnipotent by kaly**, pestañas Juego y Mods, selector de carpeta, Instalar, Play y progreso.

## Compatibilidad y estado

Esta entrega prepara las dependencias que antes estaban configuradas únicamente en la PC de referencia: acceso a xpak_cache, perfil local y registro del servicio del controlador firmado incluido en el paquete. El juego completo, sus mapas y assets siguen siendo necesarios. Se comprueban nueve archivos originales de la build probada antes de modificar la instalación. Otras builds o distribuciones pueden ser rechazadas.

El núcleo offline es **Kronos v1.36**. Omnipotent aporta su interfaz, descarga verificada, respaldos, preparación y arranque; no es una reimplementación independiente del núcleo. El rótulo Omnipotent 1.0 es un cambio de presentación.

Se validó Zombies individual en Ashes of the Damned en la PC de referencia antes de preparar esta distribución. La preparación portable se probó con fixtures y verificaciones locales. **La primera partida en otra PC sigue pendiente de validación.** Esta release se publica como prerelease por ese motivo; no promete compatibilidad universal.

## Datos locales

El ejecutable incluye su motor y lo extrae en `%LOCALAPPDATA%\Omnipotent\runtime`. La configuración y los respaldos se guardan en el mismo directorio base, separados por instalación. No contiene perfiles, partidas, identificadores ni respaldos de otra persona.

Cada descarga se verifica por tamaño y SHA-256 contra el manifiesto incluido. El instalador guarda los archivos que reemplaza y conserva los cambios externos si una recuperación encuentra conflictos. No borres los respaldos. El launcher necesita permisos de administrador para escribir en el juego y registrar/iniciar su servicio.

El instalador no desactiva la seguridad de Windows ni modifica un servicio que apunta a otra instalación. Si Windows no permite el controlador, la instalación o el arranque informa del fallo.

## Desarrollo y publicación

`Launcher.cs`, `Interface.cs`, `Bundle.cs`, `GameDiscovery.cs` y `Trainer.cs` contienen la aplicación. La detección se ejecuta en segundo plano y solo lee carpetas; la compatibilidad exacta sigue comprobándose al instalar. `build.ps1` compila la variante para desarrollo. `Build-Client.ps1 -OutputPath <exe>` compila únicamente el cliente con el servidor configurado en `distribution.json`. La versión 1.1.0 reutiliza los objetos inmutables de `offline-1.0`; `trainer.json` fija el paquete del trainer alojado en `launcher-1.1.0`. Conservar ambas releases. `Build-Share.ps1` compila el ejecutable único y exporta solamente los objetos originales verificados desde un almacén local; exige que el destino no exista. Los binarios grandes se alojan como assets de Releases, fuera del historial Git.

`distribution.json` fija la release y su dirección HTTPS. Una versión nueva se prepara con un tag nuevo; no se sustituye silenciosamente el manifiesto instalado.

`Publish-GitHub.ps1 -PackagePath <entrega> -Mode Inspect|Stage|Publish` usa la sesión existente de Git Credential Manager. Primero crea el borrador y verifica los hashes remotos; después lo publica. No incluye tokens en el ejecutable ni los guarda en el repositorio.

## Trainer 1.3.0


Descarga **Omnipotent.exe**. En **Mods > Abrir trainer** se descarga el trainer 1.3.0 con verificación SHA-256.
Con el juego cerrado, pulsa **Preparar juego** en el trainer para actualizar el script. Después inicia el juego y conecta el trainer.

- Jetpack con impulso vertical y movimiento lateral mediante los controles de movimiento.
- Give Weapon: admite las ocho armas especiales reconocidas por el motor fuera del catálogo del mapa, confirma equipamiento y sustituye el arma equipada cuando el inventario está lleno.
- Game Speed: cambia la velocidad real, confirma la transición y restaura la velocidad anterior al apagarlo.
- Terminar ronda: elimina enemigos de la ronda y confirma el avance normal sin seguir matando en la siguiente.
- Las acciones completadas no se vuelven a ejecutar al cambiar de mapa.

Validación: 34 pruebas automatizadas; compilación y validación estática del script. Las ocho armas se entregaron y equiparon en Ashes y Astra. Terminar ronda avanzó de 1 a 2 en ambos, con enemigos de la nueva ronda vivos. Velocidad medida a 0.5×, 2×, 1.1× y 1.2×; restauración a 1×. God Mode mantuvo salud 150. El usuario confirmó el vuelo vertical; la dirección lateral está implementada pero aún no tiene prueba de movimiento en partida registrada.

No se comprobaron todos los ataques/efectos de todas las armas en todos los mapas. Primera partida en otra PC pendiente; sigue siendo prerelease. Requiere juego completo compatible. El núcleo offline sigue siendo Kronos 1.36. No se repitió una prueba con Internet físicamente desconectado en esta actualización.

El launcher anterior no se actualiza solo: descarga este Omnipotent.exe para recibir el trainer nuevo. Se conservan los datos locales y las releases anteriores.

El código fuente del trainer y sus pruebas están en `trainer/`.
