# osu-web con datos reales de Torii

Instancia local de osu-web (clon de ppy/osu-web) cargada con la base de
produccion de Torii, para evaluar si vale la pena adoptarla como frontend.

Corre en http://localhost:8080. Login: `Shikkesora` / `toriitest123` (es la
cuenta real, id 3, con una contrasena puesta a mano para esta instancia).

## Como se rearma de cero

```bash
docker compose up -d
```

Despues, en orden:

| paso | archivo | que hace |
|---|---|---|
| 1 | `torii-schema-widen.sql` | ensancha `beatmapset_id` de mediumint a int |
| 2 | `torii-medals.sql` | catalogo de las 134 medallas de g0v0 |
| 3 | `torii-project.sql` | proyeccion principal, todo lo demas |
| 4 | `torii-extras.sql` | segunda tanda: grupos, sanciones, favoritos de perfil, agregados |
| 5 | `torii-rank-history.sql` | grafico de posicion global de los perfiles |
| 6 | `torii-index-scores.php` | indice `scores` de elasticsearch |
| 7 | `torii-userpages.php` | la pestana "me!" de cada perfil |

```bash
docker compose exec -T db sh -c 'mysql -uroot < /tmp/....sql'
docker compose exec -T php php /tmp/index-scores.php
docker compose exec -T php sh -c 'cd /app && php artisan es:index-documents --types=beatmapsets,users,teams --no-interaction'
docker compose exec -T php sh -c 'cd /app && php artisan rankings:recalculate-country-stats'
docker compose exec -T php sh -c 'cd /app && php artisan rankings:recalculate-team-stats'
docker compose exec -T php sh -c 'cd /app && php artisan rankings:recalculate-top-plays'
docker compose exec -T php sh -c 'cd /app && php artisan user-count-by-ruleset:recalculate'
```

Los rankings por pais y por equipo, el ranking de top plays y el desglose por
modo NO salen de la proyeccion: osu-web los calcula con esos comandos y los deja
cacheados. Sin correrlos esas paginas quedan en blanco aunque los datos esten.

Despues de cualquier cambio en la autoria de mapas hay que reindexar, porque el
indice de beatmapsets es una copia de esos datos:

```bash
docker compose exec -T php sh -c 'cd /app && php artisan es:index-documents --types=beatmapsets --cleanup --no-interaction'
```

Los tres primeros archivos SQL se pueden correr cuantas veces haga falta.

## Los datos

Salen de un dump de `osu_api` de produccion importado en el esquema local
`torii`. `torii-project.sql` traduce de ahi al esquema `osu` que espera
osu-web.

| | |
|---|---|
| usuarios | 791 |
| stats por modo | osu, taiko, catch, mania |
| beatmapsets / beatmaps | 108.665 / 363.805 |
| scores | 197.166 |
| medallas desbloqueadas | 3.879 |
| favoritos | 369 |
| mas jugados | 63.772 |
| actividad reciente | 61.220 |
| amigos y bloqueos | 1.231 |
| equipos | 51 |

## Lo que se aprendio en el camino

Estas son las cosas que no estaban en ninguna documentacion y costaron una
vuelta cada una.

**El bind mount de Windows es 430 veces mas lento.** Leer 2000 archivos del
codigo tardaba 16,9s por el mount y 0,039s adentro del contenedor. Por eso un
perfil tardaba 60 segundos en cargar. `compose.override.yml` cambia `/app` a un
volumen de Docker y baja a 0,14s. El precio: editar el codigo desde Windows ya
no se refleja solo.

**Los ids de mapas locales de Torii no entran en el esquema de osu-web.** ppy
dimensiono `beatmapset_id` como mediumint, tope 16.777.215. Torii reparte los
ids de los mapas subidos localmente a partir de 800.000.000. Son 68 sets con
sus difficulties y 1039 scores. Si algun dia esto pasa a ser en serio, hay que
decidir si se migran los ids o se parchea el esquema de entrada.

**La clave primaria de `scores` es `(id, preserve, unix_updated_at)`,** no el
id, porque la tabla esta particionada. Si se deja el timestamp al default toma
la hora de la corrida, nunca colisiona con la anterior y `ON DUPLICATE KEY` no
sirve de nada: la segunda pasada duplica los 197 mil scores.

**osu-web no indexa scores en elasticsearch.** Solo los encola; quien escribe
de verdad es `osu-elastic-indexer`, un servicio aparte que este compose no
levanta. Sin ese indice la pagina de un score tira 404, porque para mostrar la
posicion del jugador hace una busqueda. `torii-index-scores.php` arma el indice
directo desde MySQL.

**La actividad reciente se guarda como html y se vuelve a parsear.** No hay
nada estructurado: `osu_events.text` es una linea de html y `Event::parse()` le
corre una expresion regular por tipo de evento. Hay que escribir exactamente el
formato que esa regex espera, incluido el signo de admiracion del final.

**El ranking no se calcula al vuelo.** `rank_score_index` y `rank` se leen de
la fila. Si quedan en cero el perfil muestra el pp pero sin ningun numero de
posicion al lado.

**El historial de rank son 90 columnas r0..r89 usadas como buffer circular,**
con un contador en `osu_counts` que dice cual es la de hoy. Cuando ese contador
no existe, se lee de r1 a r89 y despues se le pega la posicion actual.

**El tipo del indexador se llama `beatmapsets`, no `beatmaps`.** Pasarle un
tipo que no existe no da error: indexa cero documentos y dice que termino bien.

**`torii.beatmapsets.user_id` no es un usuario de Torii.** Es el id del creador
en el espacio de ids de ppy, copiado crudo de lo que devuelve el mirror. Como
los ids locales van de 2 a 793, cualquier set cuyo creador tenga un id chico
quedaba acreditado a un jugador de Torii que no lo mapeo. El caso extremo: el
mirror devuelve `user_id = 3` para 10.728 sets de 3.853 mappers distintos, y el
3 local es Shikkesora, que aparecia con 5.327 mapas ranked propios. Ahora los
sets que no son locales van con `user_id = 0` y el nombre del mapper se lee de
la columna `creator`, que siempre estuvo bien.

**El indice de elasticsearch es una segunda copia de esa atribucion.** Reparar
MySQL no alcanza: la busqueda de mapas sigue leyendo del indice viejo hasta que
se reindexa.

**Sin `cover_updated_at` el front ni siquiera pide la portada.** Descarta las
urls que terminan en `?0` antes de renderizar, asi que la columna en NULL deja
todos los mapas con el degradado de fondo y ningun 404 en la consola que lo
delate.

**Las imagenes no se configuran, se interceptan.** osu-web arma toda url de
imagen como el base url del disco local mas el id, o sea que todo cae bajo
`/uploads/`. Los archivos no estan ahi: los de mapas viven en el cdn de ppy y
los propios de Torii en su api. La forma menos invasiva es un bloque de
`proxy_pass` en nginx, sin tocar php ni la config de Laravel. Esta en
`docker/development/nginx-default.conf`.

**El `.env` del repo no llega al contenedor php.** `/app` es un volumen, asi que
editarlo desde Windows no hace nada. Las variables van por `environment:` en
`compose.override.yml`, que el CLI de compose si lee desde Windows.

**Las medallas se resuelven por `slug`, no por la columna `image`.**
`Achievement::iconUrl()` concatena un prefijo de config con el slug. El default
apunta a `assets.ppy.sh/user-achievements/`, donde las 144 dan 404; en
`medals/web/` estan todas (medido: 0 de 144 faltan).

**En la pagina de medallas, `ordering` es la fila y `progression` la posicion
dentro de la fila.** No es el orden general. Con todo en 1 quedaba un solo
renglon larguisimo por seccion, con el texto a tamano gigante.

**osu-web rechaza el evento entero si el modo no es uno de los suyos.** Torii
tiene relax y autopilot; eran 13.888 eventos que se mostraban como error de
parseo. Se proyectan como su modo base.

**El `pink` del segundo mapa de colores no sigue a `--base-hue`.** Es a la vez
la marca de osu! Y el color semantico de loved, del corazon de supporter y de
los mods Fun. Si se pisa se rompen esas tres cosas; hay que agregar un color
propio y repuntar solo las secciones que lo usaban como marca.

**El indice de scores de elasticsearch tiene que venir prefiltrado.** osu-web
asume que ya viene filtrado por `Score::scopeIndexable` y no vuelve a filtrar al
leerlo, asi que meter todos los scores llena los leaderboards de plays falladas.
De 197.166 quedan 54.190.

**Los rankings por pais y por equipo no se proyectan, se calculan.** Salen de
comandos de artisan que dejan el resultado cacheado.

**`AssetsManifest` es un singleton warmeado por octane.** Lee el manifest una
sola vez al arrancar el worker, asi que despues de recompilar css el html sigue
pidiendo el hash viejo hasta correr `php artisan octane:reload`.

## El theming

La identidad vive casi entera en un solo archivo, `resources/css/torii-signage.less`,
importado ULTIMO en `app.less`. Eso no es una preferencia: osu-web importa sus
variables al final a proposito, con el comentario "Less has the rule 'Last
Defined Wins'". Un archivo agregado despues de esa linea redefine variables que
retro-aplican a cada llamada de mixin ya escrita en los 453 archivos bem, y
emite sus reglas ultimas, asi que gana a igual especificidad. Se apaga borrando
la linea del import y sobrevive un pull de ppy sin conflictos.

**La tesis.** osu!web es una economia de tarjetas: caja clara sobre fondo
oscuro, radio de 10px, sombra, cajas adentro de cajas, y una foto de stock en la
cabecera de cada seccion. Aca es una hoja impresa: fondo mate, cero fotos, cero
sombras, todo sostenido por reglas de un pixel y tinta bermellon. El motivo es
la puerta: cada encabezado de seccion es una viga gruesa arriba, una viga fina
abajo y el nombre en el medio. Un perfil tiene veinte modulos, asi que
scrolleando pasas por veinte puertas.

**Dos tintas que no se cruzan.** Violeta es suelo y navegacion, o sea lo que se
puede tocar. Bermellon es estructura y estado, o sea lo que el sitio afirma. Y
el bermellon se gana: viga, poste de fila, podio, hover. El resto del chrome
nunca es calido.

Lo concreto:

| | |
|---|---|
| paleta | sumi `#0D0910` de suelo, tinta `#1A141F` de panel, shu `#E8481F` de estructura. Todas las secciones al mismo tono: que el fondo cambie de color segun donde estas parado es una idea de osu!web |
| sombras | cero. Un token (`@box-shadow-color: transparent`) apaga las ~90 llamadas de `.default-box-shadow()`. Vuelven a mano solo en menus, modales y la barra flotante, que es telon y no decoracion |
| radios | 2px. El cero lee brutalismo generico; 2px lee papel cortado |
| barra | 56px que NO se anima. Los 90px que se encogen a 50 al scrollear son una de las señas mas fuertes de osu!web. Fuera los triangulitos, mas wordmark |
| cabecera | fuera las fotos de stock de ppy y los iconos de seccion. Sobreviven donde la imagen es del usuario: beatmapset, perfil, equipo |
| tablas | sin pastillas ni cebrado: renglones separados por una regla, numeros a la derecha con cifras tabulares, encabezados en caja alta |
| tipografia | Archivo para estructura, la superfamilia Barlow para interfaz y numeros, Zen Kaku Gothic New explicita en la cadena |
| movimiento | dos momentos. La viga de la cabecera se dibuja de izquierda a derecha al llegar, y el poste de fila se enciende de abajo hacia arriba. Nada disparado por scroll, nada que levite |

**El podio.** Los tres primeros del ranking llevan el poste encendido con
temperatura: el primero es brasa, el tercero ya se enfrio hacia el violeta. Es
el degrade del logo usado como escala y no como decoracion.

### Trampas del theming

**El bermellon no sirve como texto.** Medido sobre la tinta da 3.8:1 y AA pide
4.5. Se usa solo en estructura, que pide 3:1 y pasa de sobra. Para texto hay un
escalon aparte, `--shu-ink`.

**`.nav2-header__triangles` es lo UNICO que pinta la barra fija.** Ni
`.nav2-header`, ni `__body`, ni `.nav2` tienen fondo propio, y `__menu-bg` esta
en opacity 0 en reposo porque es el telon del desplegable. Ponerle `display:
none` a los triangulos deja la barra transparente sobre el contenido: hay que
conservar el elemento y repintarlo.

**`@border-radius--large` no es solo un radio.** En `beatmapset-panel` tambien
es el ancho y el alto de las muescas de esquina y el padding horizontal de la
ficha, y hay cuatro `clip-path` con arcos de radio 10 escritos a mano. Bajar el
token sin reescribirlos deja muescas visibles en las 107 mil fichas.

**Las columnas numericas de la tabla de rankings no tienen clase propia.** Una
fila son diez celdas donde la 1 es el rank, la 2 el cambio de posicion, la 3 el
jugador y de la 4 en adelante son valores. Los encabezados son ocho porque el
primero abarca las tres primeras celdas. Alinear por nombre de modificador no
matchea nada: hay que ir por posicion.

**`.ranking-page-table` arranca con `.own-layer()`**, o sea `translateZ(0)`. Un
ancestro transformado se convierte en el bloque contenedor, asi que cualquier
encabezado sticky se pega contra la tabla y no contra la ventana.

**La altura de la barra esta en dos lados.** `variables.less` avisa con un
comentario que hay que actualizar `resources/js/app-deps.ts`, que tiene tres
numeros propios (`height`, `heightMobile`, `heightSticky`) que lee el JS de
pinning.

**Los dos logos de la barra estan en `position: absolute`**, asi que no reservan
ancho y cualquier cosa que se agregue al lado les cae encima.

## Seguridad de la instancia

`/_dusk/login/{id}` loguea como cualquiera de los 791 usuarios sin contrasena y
`/__clockwork/latest` publicaba la cookie de sesion del ultimo request a
cualquier anonimo. Clockwork quedo apagado y nginx publica solo en loopback
(`NGINX_PORT=127.0.0.1:8080`). La ruta de dusk se deja porque es justo lo que
hace falta para probar como otro usuario, y ya no es alcanzable desde afuera.

## Que no se copio

Correo, contrasena e ip de los jugadores. Es una instancia de prueba y no hay
razon para meterle credenciales reales.

Los modos propios de Torii (relax, autopilot y los rulesets custom) no tienen
tabla de stats donde ir, asi que esas estadisticas quedan afuera. Los scores de
esos modos si entran, porque son plays reales, pero con `ranked = 0` para que no
ensucien rankings ni el top play de cada perfil.
