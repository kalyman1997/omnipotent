# omnipotent by kaly — trainer 1.3.0

Zombies individual local. Incluye Jetpack, las 13 opciones anteriores y una pestaña Armas.

## Uso

1. Cierra BO7 al actualizar el script.
2. Abre Omnipotent 1.3.0, entra en Mods y pulsa Abrir trainer. El launcher 1.2.0 descarga el trainer anterior: descarga el launcher nuevo para actualizar.
3. Pulsa Preparar juego y selecciona la carpeta cod25. Se respalda y actualiza únicamente nuestro script.
4. Inicia BO7 desde Omnipotent y entra en Zombies individual. Pulsa Conectar en el trainer.
5. En Armas, selecciona un arma y pulsa Give Weapon. El catálogo se amplía al conectar a una partida.
6. Los botones Nivel I, II y III mejoran el arma actual hasta ese nivel de Pack-a-Punch. No bajan un nivel que ya tengas.
7. Aplica electricidad, hielo, fuego, explosiones o Brain Rot al arma actual; Quitar modificador elimina el efecto.
8. Activa Jetpack con Ctrl + Num 5 o su interruptor. Mantén el botón de salto del juego para ascender y usa los controles de movimiento (W/A/S/D o stick) para dirigir el vuelo según la orientación de la cámara. Suelta movimiento para frenar lateralmente mientras mantienes salto; suelta salto para caer. El número ajusta el impulso vertical entre 150 y 800 (300 por defecto). Conserva las colisiones y la gravedad; God Mode es una opción separada.
9. Game Speed cambia el ritmo de la simulación (0,2–5×); al apagarlo recupera la velocidad anterior. Cambia el número y activa su interruptor. Si otro evento del juego toma el control, apaga y vuelve a activar la opción.
10. Terminar ronda elimina los zombis que cuentan para la ronda y solicita el cierre normal, incluidas las apariciones pendientes. Confirma el avance a la siguiente ronda; no sigue matando. Durante el intermedio o un encuentro con enemigos protegidos puede estar indisponible.

Las armas y los efectos dependen de los recursos del mapa y de la compatibilidad del arma. El selector admite un identificador interno manual. Los efectos elementales son los modificadores nativos: conservan su probabilidad de activación y sus tiempos de recarga, no activan el efecto en cada bala.

Give Weapon también acepta IDs que el motor reconoce aunque no estén en el catálogo del mapa. Verifica la carga y el equipamiento; si el inventario está lleno, sustituye el arma equipada. Si la entrega falla, intenta restaurar el arma anterior con su descriptor y munición. Esto no importa automáticamente scripts o efectos exclusivos ausentes del mapa.

## Correcciones probadas en 1.3.0 local

En Ashes of the Damned: las ocho referencias de armas especiales se entregaron y equiparon; la octava sustituyó correctamente el arma actual al llenarse el inventario. Game Speed produjo aproximadamente 0,48× y 1,99× al solicitar 0,5× y 2×, y volvió a 1× al apagarlo. Terminar ronda eliminó seis zombis, avanzó de la ronda 1 a la 2 y permitió que aparecieran y siguieran vivos los ocho zombis de la nueva ronda. Evidencias en validation/fixes. La entrega no demuestra todos los ataques alternativos ni efectos de cada arma en cada mapa.

En Astra Malorum también se entregaron y equiparon las ocho armas especiales, incluida la sustitución al llenarse el inventario. El cambio de mapa no repitió la orden de terminar ronda anterior. Se verificaron firefly, ruby, mantis, locust, hornet, scarab, raygunmark2 y raygun; no se ha completado una matriz de todos sus efectos en los seis mapas.

Prueba del ejecutable mediante clics: en Astra, Terminar ronda eliminó seis enemigos y confirmó ronda 2; después aparecieron nueve enemigos nuevos y la orden no se repitió. Game Speed se probó a 1,1× y 1,2× (medidas 1,12× y 1,20×), con confirmación activa sin conflicto, y al apagarlo volvió a 1×. Se corrigió una confirmación prematura mientras el motor terminaba de aplicar la velocidad. God Mode permaneció activo y la salud se mantuvo en 150. Evidencias gui-*.json en validation/fixes.

## Prueba anterior (1.2.0)

En Ashes of the Damned, Estándar individual: entrega y equipamiento de Ray Gun y M15 Mod 0; Pack-a-Punch I, II y III sobre FG42 con cambio visible del arma y nivel III en HUD; asignación y lectura real de los cinco modificadores; retirada del modificador. Se observó una baja con Impacto eléctrico al disparar. No se observaron por separado todas las animaciones de los demás efectos ni se probaron todas las armas y mapas. Esta prueba no desconectó físicamente Internet.

La versión candidata pasa 34 pruebas automatizadas del protocolo y las acciones. Cada pulsación usa una orden única; las órdenes completadas dejan de enviarse para impedir su repetición al cambiar de mapa. La validación del Jetpack se registra por separado.

## Recuperación

Los respaldos del script están en %LOCALAPPDATA%\BO7KronosTrainer\backups. Para restaurar uno, cierra BO7 y copia el archivo respaldado a kronos\custom_scripts\codex_solo_trainer.gsc dentro de cod25.

Desconectar o cerrar el trainer desactiva los modificadores continuos. Las armas entregadas y las mejoras ya aplicadas no se deshacen. Si el trainer se cierra inesperadamente, los modificadores continuos se liberan tras cinco segundos de simulación sin señal; pausar el juego detiene ese contador.

El trainer usa el componente offline instalado por Omnipotent y su canal de scripts local. No constituye un reemplazo independiente de ese componente.

