# Omnipotent 1.0.1

Launcher ligero para preparar y abrir el modo offline de una instalación compatible de Black Ops 7 en Windows de 64 bits.

## Uso

1. Descarga **Omnipotent.exe** de [Releases](https://github.com/kalyman1997/omnipotent/releases/tag/launcher-1.0.1).
2. Abre el ejecutable. Detecta la instalación en las bibliotecas locales de Xbox, incluidas las rutas personalizadas de `.GamingRoot`. Respeta una carpeta guardada que siga siendo válida. Si encuentra varias instalaciones o ninguna, pulsa **Elegir carpeta** (cod25, Content o su carpeta superior).
3. Pulsa **Instalar**. La primera instalación necesita internet y descarga aproximadamente 1 GB, menos si ya hay archivos válidos en el equipo.
4. Cuando termine la verificación, pulsa **Play**.

No necesitas descargar manualmente los archivos con nombres largos de la release. El launcher los selecciona y verifica automáticamente. No necesitas Railway ni abrir el launcher de Kronos.

## Compatibilidad y estado

Esta entrega prepara las dependencias que antes estaban configuradas únicamente en la PC de referencia: acceso a xpak_cache, perfil local y registro del servicio del controlador firmado incluido en el paquete. El juego completo, sus mapas y assets siguen siendo necesarios. Se comprueban nueve archivos originales de la build probada antes de modificar la instalación. Otras builds o distribuciones pueden ser rechazadas.

El núcleo offline es **Kronos v1.36**. Omnipotent aporta su interfaz, descarga verificada, respaldos, preparación y arranque; no es una reimplementación independiente del núcleo. El rótulo Omnipotent 1.0 es un cambio de presentación.

Se validó Zombies individual en Ashes of the Damned en la PC de referencia antes de preparar esta distribución. La preparación portable se probó con fixtures y verificaciones locales. **La primera partida en otra PC sigue pendiente de validación.** Esta release se publica como prerelease por ese motivo; no promete compatibilidad universal.

## Datos locales

El ejecutable incluye su motor y lo extrae en `%LOCALAPPDATA%\Omnipotent\runtime`. La configuración y los respaldos se guardan en el mismo directorio base, separados por instalación. No contiene perfiles, partidas, identificadores ni respaldos de otra persona.

Cada descarga se verifica por tamaño y SHA-256 contra el manifiesto incluido. El instalador guarda los archivos que reemplaza y conserva los cambios externos si una recuperación encuentra conflictos. No borres los respaldos. El launcher necesita permisos de administrador para escribir en el juego y registrar/iniciar su servicio.

El instalador no desactiva la seguridad de Windows ni modifica un servicio que apunta a otra instalación. Si Windows no permite el controlador, la instalación o el arranque informa del fallo.

## Desarrollo y publicación

`Launcher.cs`, `Interface.cs`, `Bundle.cs` y `GameDiscovery.cs` contienen la aplicación. La detección se ejecuta en segundo plano y solo lee carpetas; la compatibilidad exacta sigue comprobándose al instalar. `build.ps1` compila la variante para desarrollo. `Build-Client.ps1 -OutputPath <exe>` compila únicamente el cliente con el servidor configurado en `distribution.json`. La versión 1.0.1 reutiliza los objetos inmutables de `offline-1.0`. `Build-Share.ps1` compila el ejecutable único y exporta solamente los objetos originales verificados desde un almacén local; exige que el destino no exista. Los binarios grandes se alojan como assets de Releases, fuera del historial Git.

`distribution.json` fija la release y su dirección HTTPS. Una versión nueva se prepara con un tag nuevo; no se sustituye silenciosamente el manifiesto instalado.

`Publish-GitHub.ps1 -PackagePath <entrega> -Mode Inspect|Stage|Publish` usa la sesión existente de Git Credential Manager. Primero crea el borrador y verifica los hashes remotos; después lo publica. No incluye tokens en el ejecutable ni los guarda en el repositorio.
