## VULFT


VULFT - Script de bot de anulación total. Comportamiento de lucha altamente dinámico. Los roles de DotaBuff y las secuencias de compilación de inventario se actualizan el: 19/03/23. Requiere instalación manual en la carpeta vscripts/bots (igual que Phalanx Bot y otros bots recientes, debido a un error de taller de Dota). VUL-FT no está afiliado con DotaBuff.



##  Traducción 

La traducción me lleva mucho tiempo, unos 30 minutos. Necesito volver a la programación, por lo que este archivo puede estar desactualizado. Si el proceso de instalación manual está solucionado y ya no es necesario, actualizaré este documento. Consulte la página del taller en inglés para conocer la fecha de compilación actual de DotaBuff y la fecha de lanzamiento del software.



##  Instalación manual 

VUL-FT actualmente no funcionará solo suscribiéndose. Volverá a los bots predeterminados, otros bots lanzados recientemente tienen el mismo problema. Por ahora, es necesario instalar manualmente los bots.



Opcional: Antes de configurar VUL-FT como script de desarrollo local, también puede ser una buena idea hacer una copia de seguridad de su antigua carpeta 'vscript/bots' si tiene otro bot que haya almacenado allí:

La carpeta del bot de desarrollo local se encuentra en

[unidad]:/%Archivos de programa%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots

0) Cambie el nombre de la carpeta Bots a bots.old.

1) Crear una nueva carpeta llamada bots

2) copie los archivos VUL-FT de GitHub o de la carpeta Workshop en la nueva carpeta Bots.



-- A través de archivos locales de taller: (los archivos de taller verificados por Valve)

Después de descargar VULFT en el juego o en el taller, busque la carpeta reciente en

[unidad]:/%Archivos de programa%/Steam/steamapps/workshop/content/570/2872725543

y copie el contenido de esa carpeta en la carpeta bots en

[unidad]:/%Archivos de programa%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots/



-- Vía Github: (actualizado por el creador)

Si sabes cómo usar git puedes descargar manualmente los bots desde el [official VUL-FT Github](https://github.com/yewchi/vulft) y ponerlos en

[unidad]:/%Archivos de programa%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots/



-- Iniciar un partido:

Después de completar uno de los pasos anteriores, puede ejecutar los bots navegando en el juego hasta Lobbies personalizados -> Create -> Edit:

En BOT SETTINGS, cambie los bots del equipo a Local Dev Script (si aún desea luchar contra los bots de Valve, tenga en cuenta que también hay una opción para "Bots predeterminados" aquí)

Cambie SERVER LOCATION a HOST LOCAL (su computadora).

El modo fácil o Injusto aún no tiene efecto, pero Injusto puede aumentar el oro pasivo del bot.

Pulse OK.

Únete al primer espacio de cualquiera de los equipos.

Presiona INICIAR JUEGO.



Alternativamente, puede usar la opción "Jugar VS Bots", pero no todos los héroes están implementados.



##  Características 

- Toma dinámica de decisiones de lucha.

- Más como jugadores reales.

- Comienzan a moverse inmediatamente después de lanzar un ataque.

- Gestión avanzada de inventarios.

- Ubicaciones de los observadores generados automáticamente, por si el mapa cambia alguna vez.

- Analizador DotaBuff para promediar de 5 habilidades de juego, roles y una construcción de objetos de jugadores divinos - inmortales esa semana.

- Caza básica de monstruos en su tiempo libre.

- Pueden impedir que el enemigo consiga una muerte en el juego inicial al darle a un monstruo de la jungla el ataque final.

- Retirada dinámica, a torres amistosas (a menos que la torre se llene demasiado), o a aliados amistosos en dirección a la fuente aliada.

- Asignación de tareas de runas de recompensa basada en la proximidad, la seguridad, la niebla y la calificación de codicia - Asignación de defensa de torres basada en la dificultad de lucha.

- Menor uso de CPU que otros bots populares.

- ¡Errores de software! :)



Pero también, prometo que el código de este proyecto es 100% funcional fuera de línea y se mantendrá así. Esta base de código no utilizará ninguna API de red, nunca.

##  Informe de errores 

[ Lua Error Dump (enlace de discusión de Steam)](https://steamcommunity.com/workshop/filedetails/discussion/2872725543/3648503910213521285/) -- Utilícelo si desea copiar algunos mensajes de error del registro de la consola rápidamente.

[ Código fuente VUL-FT](https://github.com/Yewchi/vulft) -- Github público



##  Problemas conocidos 

Esta sección es muy difícil de traducir, ¡lo siento!



Todas las nuevas entidades de recompensas de oro y las entidades de río de agua introducidas en algún momento en 7.x actualmente no pueden ser recogidas por scripts de bot de anulación total. Esto incluye la nueva característica de las entidades de recompensa que se apilan una encima de la otra. Además, solo se puede cobrar la entidad de recompensa aparecida más recientemente. Una solución está en su lugar antes del trombón de guerra a las 0:00 para permitir que los bots los recojan, sin embargo, la solución hace que los bots pierdan el control total de su inventario, por lo que se elimina después de la bocina alrededor de las 0:30



##  Estado del proyecto 

Versión alfa. Por favor, envíe sus comentarios.

¿El proyecto es actualmente estable?: Estable, sin bloqueos de juego o ruptura de guión en 10 partidos a partir del 30/03/23 (30 de marzo)

Última meta actualización de DotaBuff: Por favor, compruebe las fechas de la página del taller de inglés.



##  Contacto de desarrollo 

zyewchi@gmail.com

