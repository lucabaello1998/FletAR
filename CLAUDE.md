# FletAR

Marketplace de fletes en Argentina: quien necesita un flete publica un anuncio (origen,
destino, categoría de carga, fecha deseada), y quien puede hacerlo responde con una
**oferta de precio** sobre esa publicación. El publicador compara ofertas y acepta una.
Cualquier usuario puede tanto publicar como ofertar — no hay una cuenta "fletero"
separada, es un rol que se juega por transacción.

## Estado

Fases 0 a 4 completas. Fase 0: solución .NET con Auth JWT de punta a punta
(registro, login, refresh con rotación/revocación, detección de reuso) contra
Postgres+PostGIS en Docker, más el proyecto Flutter (mobile + desktop + web)
arrancando con su estructura, tema y login/registro — corriendo tanto de ventana
nativa de Windows como en el navegador. Login con Google agregado como alternativa
a email/password (funcional, con credencial de Google Cloud ya configurada).

Fases 1, 2 y 3 (Publicaciones + Ofertas + mapa/geo, y Calificaciones) se armaron
con un patrón Gauntlet Loop (builders + críticos de contexto fresco que corren el
artefacto real, no un resumen) y después una pasada de arreglos dirigida a mano en
cada una — ver *Cómo se armaron las Fases 1 y 2* y *Cómo se armó la Fase 3* para el
detalle de qué encontró cada etapa. Publicaciones y Ofertas tienen CRUD completo,
geobúsqueda por cercanía (`ST_DWithin`), la máquina de estados completa
(`Publicada → OfertaAceptada → EnCurso → Completada / Cancelada`) ejercitada de
punta a punta desde la UI, y mapa real con `flutter_map`+OSM tanto para elegir
origen/destino como para explorar publicaciones cercanas. Calificaciones habilita
un rating mutuo (1 a 5 + comentario) tras `Completada`, con reputación pública
visible en las listas de publicaciones/ofertas (`GET /api/usuarios/{id}`) antes de
decidir con quién hacer el flete.

Fase 4 (panel admin) se hizo directo, sin Gauntlet Loop, ya con el patrón de huecos
de las fases anteriores en la cabeza: cualquier usuario puede reportar una
publicación (`POST /api/publicaciones/{id}/reportes`, botón de bandera en el
detalle salvo para el propio dueño), y el admin tiene un panel con tres pestañas
(Reportes, Usuarios, Métricas) en `/admin` — gateado por rol en el router de
Flutter y por la policy `Admin` en el backend (defensa real; el gateo de Flutter es
sólo para no mostrar la pantalla, no la autorización). El admin puede
descartar/revisar un reporte, cancelar la publicación reportada
(`POST /api/admin/publicaciones/{id}/cancelar`, sin el chequeo de dueño de la
cancelación normal), y desactivar/reactivar cuentas (un usuario desactivado no
puede loguearse más).

**Sin arrancar:** push — ver *Roadmap*.

## Stack

| Capa | Definición |
|---|---|
| Backend | .NET 8 (LTS) / C# — ASP.NET Core Web API, arquitectura API/BLL/DAL/DTO |
| Datos | PostgreSQL 16 + PostGIS, vía EF Core 8 + Npgsql + NetTopologySuite |
| Mapping | AutoMapper (perfiles en BLL) — a diferencia de Ceta-Logística, que mapea a mano |
| Auth | JWT (access + refresh con rotación/revocación), rol como claim |
| Cliente | Flutter — un solo código para mobile (Android/iOS), desktop (Windows/Mac/Linux) y web |
| Estado (Flutter) | Riverpod (`flutter_riverpod`), sin codegen por ahora |
| Ruteo (Flutter) | `go_router` |
| Mapa | OpenStreetMap vía `flutter_map` (sin costo ni API key) |
| Login social | Google Sign-In (`google_sign_in`) además de email/password — ver *Login con Google* |
| Notificaciones | Firebase Cloud Messaging (solo mobile — FCM no soporta Windows/Linux desktop) |
| Tests | xUnit (backend) |

**FletAR es un proyecto hermano de Ceta-Logística** (mismo equipo, mismo lenguaje de
dominio en español). Reutiliza deliberadamente varios de sus mecanismos — solución
`.sln` + `src/{API,BLL,DAL,DTO}` + `tests/`, `.env`/`.env.example` +
`DesignTimeDbContextFactory`, `JwtSettings` que valida la clave al construirse,
`RefreshToken` con `FamiliaId`/rotación, patrón `FallbackPolicy` — pero con **dos
desviaciones conscientes**, no inconsistencias:

- **AutoMapper**, donde Ceta-Logística mapea a mano. Pedido explícito para este
  proyecto. Ojo: el paquete cambió a licencia comercial a partir de una revisión
  reciente (gratis para individuos/orgs chicas, pago por encima de cierto umbral de
  ingresos) — conviene revisar los términos vigentes antes de escalar el uso.
- **PostgreSQL + PostGIS**, donde Ceta-Logística usa SQL Server. Se eligió por el
  soporte geoespacial (búsquedas de "fletes cercanos"), que es el corazón de esta app
  y no de esa.

**FletAR no sirve un frontend propio desde la API.** A diferencia de Ceta-Logística
(que sirve el build de Vite desde `wwwroot`), acá el cliente Flutter se compila y se
sirve/distribuye aparte (binarios nativos para mobile/desktop, o un build web servido
por otro origen) — no hay `UseStaticFiles()` ni fallback a `index.html` en la API.
Por eso, a diferencia de Ceta-Logística, **acá CORS sí hace falta y está configurado**
(ver *CORS*): el cliente web corre en un origen distinto al de la API, y el navegador
bloquearía las llamadas sin esto.

### CORS

Policy `Web` registrada en `Program.cs`:

- **En Development, cualquier origen** (`AllowAnyOrigin`) — `flutter run -d chrome`
  levanta el cliente en un puerto aleatorio cada vez, así que no hay una lista fija
  que allowlistear.
- **En producción, solo los orígenes de `FLETAR_CORS_ORIGENES`** (env var, separados
  por coma). Vacío por defecto — falla cerrado: sin configurarla a mano, el cliente
  web publicado no va a poder llamar a la API. No es un olvido, es la misma lógica
  de "explícito, no implícito" que el resto de la config sensible.
- No hace falta `AllowCredentials()`: el JWT viaja en el header `Authorization`, no en
  una cookie, así que no hay estado de sesión que el navegador tenga que compartir
  entre orígenes.

## Identidad visual

Investigada para este proyecto puntualmente (no heredada de Ceta-Logística, que es
dark-first porque es un portal interno). FletAR la usa el público general en la calle,
así que es **clara, no dark-first**. Naranja como primario porque en apps de
delivery/logística comunica velocidad y movimiento; azul marino como secundario porque
comunica confianza/profesionalismo y evita que la app se lea como una app de comida.

| Rol | Token | Valor |
|---|---|---|
| Fondo | `--background` | `#FAFAF8` (blanco cálido, no `#FFFFFF` puro) |
| Superficie | `--surface` | `#FFFFFF` |
| Texto principal | `--foreground` | `#1E2530` |
| Texto secundario | `--muted-foreground` | `#6B7280` |
| Primario / acción | `--primary` | `#F97316` (naranja) |
| Secundario / marca | `--secondary` | `#1E3A5F` (azul marino) |
| Borde | `--border` | `#E5E1DA` |
| Éxito | `--success` | `#22C55E` |
| Atención | `--warning` | `#F59E0B` |
| Peligro | `--destructive` | `#EF4444` |

Igual que en Ceta-Logística: el color sale siempre de tokens semánticos
(`FletarColors.primary`, nunca un naranja crudo escrito a mano en un widget), definidos
una sola vez en `lib/core/theme/`.

**Logo**: no hay forma de generar imágenes rasterizadas en este entorno. Se dejó un
ícono placeholder en `FLETAR_APP/assets/branding/logo_v0.svg` (pin de mapa + silueta de
camión, en la paleta de arriba) — es un v0 para tener algo en la barra de título
mientras se arranca, **no un logo final**: conviene reemplazarlo con un diseñador antes
de publicar la app.

## Modelo de datos

Todas las entidades del MVP ya están modeladas en `Fletar.DAL/Models/` y todas ya
tienen su CRUD completo: `PublicacionesController`+`PublicacionService`,
`OfertasController`+`OfertaService`, `CalificacionesController`+`CalificacionService`,
`UsuariosController`+`UsuarioService` (perfil público/reputación + gestión admin), y
`ReportesController`+`ReporteService` (crear) más `AdminController`+`AdminService`
(listar/revisar/descartar reportes, cancelar publicaciones, métricas).

- **Usuario**: cuenta única, sin distinción publicador/fletero. `Rol` (`Usuario`/`Admin`)
  como único diferenciador de permisos. `PasswordHash` es `string?`: una cuenta creada
  vía Google (ver *Login con Google*) no tiene una, y no puede loguearse por
  `/auth/login`.
- **Publicacion**: `Origen` (`Point`, obligatorio, columna `geography(Point,4326)` con
  índice GIST) y `Destino` (`Point?`, opcional). `Estado` seguí este ciclo:
  ```
  Publicada → OfertaAceptada → EnCurso → Completada
                                       ↘ Cancelada
  Publicada → Cancelada   (el dueño cancela antes de aceptar una oferta)
  ```
  `EnCurso` existe específicamente para que un futuro pago/escrow tenga dónde
  engancharse sin otra migración — no hay lógica de pago todavía.
- **Oferta**: precio estructurado sobre una `Publicacion`, con su propio estado
  (`Pendiente`/`Aceptada`/`Rechazada`/`Retirada`).
- **Calificacion**: una por dirección por publicación completada (índice único en
  `PublicacionId`+`UsuarioQueCalificaId`), habilitada recién en `Completada`.
- **CategoriaCarga** y **TipoVehiculo**: tablas, no enums — el admin puede sumar
  categorías/tipos sin tocar código.
- **Reporte**: moderación de publicaciones, consumido por el panel admin (Fase 4).
- **RefreshToken**: igual que en Ceta-Logística — `FamiliaId`, hash, rotación,
  detección de reuso (revoca toda la familia si un token ya usado se vuelve a
  presentar).

**Sin propiedades de navegación en los models** (mismo criterio que Ceta-Logística):
toda relación se declara explícita en `FletarDbContext.OnModelCreating` con
`HasOne<T>().WithMany().HasForeignKey(...)`, `Restrict` por defecto.

## Cuenta de admin en desarrollo

`UsuarioDevSeeder` (mismo patrón que `UsuarioDevSeeder` de Ceta-Logística) crea sola
una cuenta con `Rol = Admin` la primera vez que la API arranca en Development — nunca
en el ambiente publicado, y nunca pisa una fila existente (si el email ya existe, no
hace nada):

```
admin@fletar.ar / FletAR.Dev.2026
```

No hay panel admin todavía (Fase 4) para usarla desde una UI, pero ya sirve para
loguearse y obtener un JWT con el claim `rol=admin`, útil para probar la policy
`Admin` a mano (Swagger/curl) antes de que exista el panel.

## Autenticación

Mismo mecanismo que Ceta-Logística, adaptado a un modelo de roles mucho más simple:

- Claim `rol` con valor `usuario` o `admin` (Ceta-Logística usa `tipoUsuario` con tres
  valores; acá alcanza con dos).
- **`FallbackPolicy` = `RequireAuthenticatedUser()`, sin claim exigido.** A diferencia
  de Ceta-Logística (donde el fallback exige `interno` porque el caso por defecto es
  restringido), acá el caso por defecto es "cualquier usuario autenticado puede
  publicar/ofertar/calificar". `[AllowAnonymous]` explícito en
  `/auth/{register,login,refresh,logout}` y `/health`.
- **Policy `Admin`** (`RequireClaim("rol", "admin")`) aplicada explícitamente con
  `[Authorize(Policy = "Admin")]` en cada controller/acción del panel admin. Ojo: acá
  el fallback es permisivo por default, así que **olvidarse el atributo en un endpoint
  admin nuevo lo deja abierto a cualquier usuario logueado** — es el caso inverso al de
  Ceta-Logística, donde olvidarse una anotación no importaba porque el fallback ya
  bloqueaba todo.
- `RefreshTokenHasher` guarda el hash (SHA-256) del refresh token, nunca el valor
  crudo. Rotación: cada `/refresh` revoca el token usado y emite uno nuevo con la
  misma `FamiliaId`. Reuso de un token ya revocado revoca toda la familia — señal de
  robo o carrera de refresh.
- `JwtSettings` valida el largo de la clave al construirse (mínimo 32 bytes, exigido
  por HmacSha256) — igual que Ceta-Logística.
- `MapInboundClaims = false` en la config de `AddJwtBearer` — sin esto,
  `JwtSecurityTokenHandler` renombra `sub` a `ClaimTypes.NameIdentifier` y buscar
  `"sub"` a mano devuelve null en silencio.
- Login con hash de referencia (`HashDeReferencia`) cuando el email no existe, para
  que el tiempo de respuesta no delate si la cuenta existe — mismo patrón que
  Ceta-Logística.

## Login con Google

Alternativa a email/password, no un reemplazo. El backend nunca confía en el
nombre/email que mande el cliente: valida el ID token de Google contra los
servidores de Google (`Google.Apis.Auth`, paquete oficial) antes de crear o
loguear un usuario.

- **Backend**: `POST /api/auth/google` recibe `{ idToken }`, lo valida con
  `GoogleJsonWebSignature.ValidateAsync` usando `FLETAR_GOOGLE_CLIENT_ID` como
  audience, busca el usuario por email y lo crea si no existe (`PasswordHash =
  null` — esa cuenta nunca puede loguearse por `/auth/login`, solo por Google).
  `GoogleSettings` es **opcional**: sin la env var, la API arranca igual y solo
  ese endpoint falla con un mensaje claro — Google Sign-In es una forma más de
  entrar, no un requisito para que el resto de la API funcione.
- **Flutter**: mismo Client ID (`--dart-define=FLETAR_GOOGLE_CLIENT_ID=...`) para
  las tres plataformas soportadas — el paquete `google_sign_in` v7 lo usa como
  `clientId` y `serverClientId` a la vez, así el ID token que llega al backend
  siempre tiene el mismo audience sin importar desde qué plataforma se logueó.
  Sin esa variable, el botón "Continuar con Google" directamente no se renderiza
  (no queda un botón roto en pantalla).
  - **Mobile (Android/iOS) y Web**: soportado. En mobile dispara el picker nativo
    de cuentas (`GoogleSignIn.instance.authenticate()`); en web hay que usar el
    botón que renderiza el propio SDK de Google (`google_sign_in_web`), no un
    botón propio — la GIS SDK no permite disparar el login desde UI custom.
    El resultado de ambos llega por el stream `authenticationEvents`, no como
    valor de retorno directo (así cambió la API en `google_sign_in` v7).
  - **Desktop (Windows/Mac/Linux): no soportado todavía.** El plugin no tiene
    implementación federada para desktop — haría falta un flujo OAuth manual
    con loopback (browser del sistema + servidor local que recibe el redirect),
    que no se armó en esta pasada. `supportsAuthenticate()` da `false` ahí y el
    botón no se muestra; en desktop solo queda el login con email/password.
  - **`google_sign_in_web/web_only.dart` no se importa directo** en ningún
    archivo que se compile fuera de web (rompía `flutter test`, que corre en la
    VM: ese archivo usa `dart:js_interop`, que no compila ahí). Se aisló detrás
    de un import condicional (`google_web_button.dart` con
    `if (dart.library.js_interop)`) — un stub para VM/mobile/desktop, la
    implementación real solo para web. Cualquier otro uso directo de ese import
    tiene que pasar por el mismo patrón.

**Para activarlo, hace falta que alguien con acceso a Google Cloud Console:**

1. Cree (o reutilice) un proyecto en https://console.cloud.google.com/.
2. Configure la pantalla de consentimiento OAuth (External, con el nombre/logo
   de FletAR).
3. Cree una credencial **"ID de cliente de OAuth 2.0"** de tipo **"Aplicación
   web"** en *Credenciales*. Ese es el `FLETAR_GOOGLE_CLIENT_ID` — el mismo
   valor va en el backend (`.env`) y en el `--dart-define` de Flutter.
4. Agregue los orígenes de desarrollo (`http://localhost`, y el puerto que use
   `flutter run -d chrome --web-hostname localhost --web-port <puerto fijo>`)
   a **Authorized JavaScript origins** de esa credencial.

No se automatizó este paso: crear proyectos/credenciales de OAuth es una acción
sobre una cuenta de Google Cloud ajena a este repo, no algo que se pueda scriptear
a ciegas.

## Estructura del repositorio

```
FLETAR_BACKEND/     .NET
  Fletar.sln
  global.json               pin SDK 8.0.423
  .env / .env.example
  docker-compose.yml         Postgres+PostGIS en :5433 (host) -> :5432 (contenedor)
  Dockerfile
  src/
    Fletar.API/       Controllers. Program.cs, ManejadorDeExcepciones, CabecerasSeguridad.
    Fletar.BLL/       Services, Helpers (JWT/refresh), Settings, Mapping (perfiles AutoMapper).
    Fletar.DAL/       Models, FletarDbContext, DesignTimeDbContextFactory, Migrations.
    Fletar.DTO/       DTOs de entrada/salida por dominio (Auth/, y lo que sigue en Fase 1+).
  tests/
    Fletar.Tests/     xUnit + WebApplicationFactory.

FLETAR_APP/          Flutter (mobile + desktop + web, un solo código)
  lib/
    core/             network (Dio+interceptor JWT), router (go_router), theme, errores.
    features/         auth/, y las que se suman en cada fase (publicaciones/, ofertas/, ...).
  assets/branding/    logo_v0.svg (placeholder, ver *Identidad visual*).
  web/                index.html/manifest.json con branding de FletAR, íconos generados
                      desde el logo (ver *Identidad visual*) - no son los default de Flutter.

CLAUDE.md            Este archivo.
```

Dependencias del backend: `API → BLL, DTO`; `BLL → DAL, DTO`; `DAL` y `DTO` sin
referencias internas — igual que Ceta-Logística.

**Puerto de Postgres en desarrollo: 5433, no 5432.** Se descubrió en esta misma sesión
que 5432 puede estar ocupado por un Postgres nativo instalado como servicio de
Windows (pasó acá con `postgresql-x64-18`) — el contenedor arrancaba pero Npgsql se
conectaba al servicio nativo en vez de al contenedor, y fallaba la autenticación
porque las credenciales no coincidían. `docker-compose.yml` mapea `5433:5432`
puntualmente por eso.

## Cómo se probó la Fase 0

Verificado a mano en esta sesión, no solo "debería andar":

```
dotnet build FLETAR_BACKEND/Fletar.sln          # 0 errores
dotnet test FLETAR_BACKEND/Fletar.sln           # 2/2 tests OK (health + fallback policy)
docker compose up -d db                          # Postgres+PostGIS healthy
dotnet ef database update --project src/Fletar.DAL --startup-project src/Fletar.DAL
dotnet run --project src/Fletar.API
# POST /api/auth/register  -> 200, JWT real
# POST /api/auth/login     -> 200, JWT real
# GET  /api/algo-inexistente sin token -> 401 (FallbackPolicy)
# POST /api/auth/refresh   -> rota access+refresh token
# POST /api/auth/refresh (con el token ya usado) -> 401 + revoca toda la familia
```

También corriendo de punta a punta contra la API real (no solo compilado): la app
Flutter como ventana nativa de Windows (`flutter run -d windows`, requirió agregar el
workload "Desktop development with C++" a Visual Studio) y en Chrome
(`flutter run -d chrome`), ambas mostrando la pantalla de login real. Login con Google
implementado, compila en los tres targets, y ya tiene un Client ID real de Google Cloud
configurado en `FLETAR_BACKEND/.env` — pendiente de que Google termine de propagar la
credencial nueva (puede tardar de minutos a horas) para probar el flujo completo con
una cuenta real.

## Cómo se armaron las Fases 1 y 2 (Gauntlet Loop)

Publicaciones, Ofertas y el mapa/geo se construyeron con un workflow de builders +
críticos de contexto fresco (patrón "Gauntlet Loop": el que construye nunca se
autoevalúa, el crítico corre el artefacto real —build, curl, `flutter analyze`/`test`—
en vez de confiar en un resumen). Costó 9 agentes / ~658k tokens / ~54 min para las 4
etapas (Publicaciones+geo, Ofertas+transiciones, Flutter UI, Flutter mapa) más una
verificación final integrada.

Las 4 etapas pasaron su propio crítico a la primera ronda. La verificación **final**
—que prueba todo junto, no pieza por pieza— encontró lo que un crítico por etapa no
podía ver: el backend soportaba toda la máquina de estados
(`Publicada→OfertaAceptada→EnCurso→Completada`), pero la UI de Flutter solo llegaba
hasta aceptar una oferta. Nadie podía marcar un flete en curso, completarlo ni
cancelarlo desde la app, y encima una publicación **desaparecía del listado
principal** apenas se le aceptaba una oferta (el listado filtraba `Estado=Publicada`
por defecto y no había forma de pedir las propias en cualquier estado). Se arregló
después a mano, sin otra vuelta del workflow:

- Backend: `GET /api/publicaciones?soloMias=true` devuelve las publicaciones del
  usuario logueado en cualquier estado (el listado público sigue filtrando solo
  `Publicada`, que es lo que le sirve a alguien buscando qué ofertar).
- Flutter: pestaña "Mis publicaciones" en el listado (además de "Explorar"), botones
  de Cancelar/Marcar en curso/Marcar completada en el detalle (uno solo visible según
  el estado, y solo para el dueño), botón "Retirar" en las ofertas propias pendientes,
  y campos de destino (con su propio mapa) + fecha deseada en el alta.

Moraleja para la próxima vez que se use este patrón acá: los críticos por etapa
verifican bien su propia pieza, pero la integración cruzada (¿la UI expone *todo* lo
que el backend soporta?) solo la agarra una verificación final de punta a punta — no
alcanza con que cada etapa apruebe por separado.

## Cómo se armó la Fase 3 (Gauntlet Loop)

Mismo patrón, esta vez más chico (3 etapas en vez de 5, proporcional a que es una
sola entidad nueva): Backend Calificaciones+reputación, Flutter Calificaciones, y
verificación final. 5 agentes / ~523k tokens / ~46 min. Las dos primeras etapas
aprobaron a la primera ronda.

La verificación final volvió a encontrar el **mismo tipo de hueco que en Fases 1+2**,
esta vez interactuando con Chrome real vía DevTools Protocol (clicks reales, no
simulados): el backend permitía perfectamente que el fletero (oferente aceptado)
calificara al dueño, pero la app no tenía **ningún camino de navegación** para que el
fletero volviera a una publicación una vez que dejaba de estar `Publicada` — "Mis
publicaciones" filtra por dueño, "Explorar" y el mapa filtran a `Publicada`, y no
existía ninguna pantalla "Mis ofertas" ni el endpoint que la sustente. La única forma
en que el crítico logró que el fletero calificara fue tipeando la URL a mano dentro
de la misma sesión — impracticable para un usuario real. También encontró que la
reputación de un usuario quedaba cacheada indefinidamente dentro de la misma sesión
(`usuarioPublicoProvider`, un `FutureProvider.family` de Riverpod) sin invalidarse
después de calificar. Se arregló después a mano:

- Backend: `GET /api/ofertas/mias` (ruta absoluta en `OfertasController`, sin anidar
  bajo una publicación puntual) devuelve las ofertas del usuario logueado cruzando
  publicaciones en cualquier estado, con `PublicacionTitulo`/`PublicacionEstado`
  denormalizados para no pedir el detalle de cada una.
- Flutter: tercera pestaña "Mis ofertas" en el listado, y
  `ref.invalidate(usuarioPublicoProvider(...))` después de calificar con éxito.

Segunda confirmación de la moraleja de Fases 1+2: cuando el backend soporta una
acción de "la otra parte" de una transacción (no el dueño), conviene revisar desde el
arranque si esa otra parte tiene algún camino de navegación real para llegar a
ejercerla — no solo si el endpoint funciona.

## Roadmap

- **Fase 0 — listo.** Scaffold + Auth de punta a punta.
- **Fase 1 — listo.** Publicaciones + Ofertas: CRUD completo, transiciones de
  `EstadoPublicacion` (incluida cancelación) ejercitadas desde la UI, no solo la API.
- **Fase 2 — listo.** `GET /publicaciones/cercanas?lat&lng&radioKm` con `ST_DWithin`,
  `flutter_map` para elegir origen/destino al publicar y para explorar cercanas.
- **Fase 3 — listo.** Calificaciones mutuas tras `Completada`, reputación pública
  (`GET /api/usuarios/{id}`) visible en publicaciones/ofertas, pantalla "Mis ofertas"
  para que el fletero encuentre sus publicaciones en cualquier estado.
- **Fase 4 — listo.** `Reporte` + flujo de reportar una publicación (botón de
  bandera en el detalle, oculto para el propio dueño), panel admin en `/admin`
  (Reportes/Usuarios/Métricas) gateado por rol en Flutter y por policy `Admin` en
  el backend, cancelación de publicaciones por moderación, y
  desactivar/reactivar cuentas. Hecha directo (sin Gauntlet Loop), aplicando ya la
  moraleja de las fases anteriores.
- **Fase 5 — Push.** Endpoint para registrar `FcmToken`, `FcmSenderService` en BLL
  disparado en nueva-oferta/oferta-aceptada/publicacion-completada. Alcance mobile
  únicamente (ver *Stack*).

Gaps menores conocidos, no bloqueantes: sin tests automatizados de
`PublicacionService`/`OfertaService`/`CalificacionService`/`UsuarioService`/
`ReporteService`/`AdminService` (solo hay tests triviales de salud); la vista de
mapa de "cercanas" usa una ubicación fija
(CABA) hasta que se integre `geolocator`; la sesión no persiste tras un reload real
del navegador (falta un endpoint `/usuarios/me` para validar el token guardado en el
arranque frío, ver `AuthController.build()` en `auth_providers.dart`).

Explícitamente fuera de este roadmap por ahora (decisión tomada, no olvido): pagos/
Mercado Pago, verificación de identidad/documentación del fletero, cache con Redis.
Se agregan cuando haya uso real que lo justifique.

## Idioma del código

Igual que Ceta-Logística: **el dominio se nombra en español, lo técnico en inglés.**
`Publicacion`, `Oferta`, `Calificacion`, `Fletero` (como rol, no como entidad) no se
traducen. `Service`, `Repository`, `DTO`, `options` van en inglés. Sin `ñ` ni tildes en
identificadores; en texto visible al usuario, sí.

## Cómo se trabaja

- Documentación, comunicación y mensajes de commit en español.
- No se versiona `.env` (clave JWT y cadena de conexión) ni
  `firebase-service-account.json` — están en `.gitignore`.
- No hacer `git push` ni `git commit` salvo pedido expreso.
