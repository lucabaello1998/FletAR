# FletAR

Marketplace de fletes en Argentina: quien necesita un flete publica un anuncio (origen,
destino, categoría de carga, fecha deseada), y quien puede hacerlo responde con una
**oferta de precio** sobre esa publicación. El publicador compara ofertas y acepta una.
Cualquier usuario puede tanto publicar como ofertar — no hay una cuenta "fletero"
separada, es un rol que se juega por transacción.

## Estado

Fases 0 a 8 completas. Fase 0: solución .NET con Auth JWT de punta a punta
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
origen/destino como para explorar publicaciones cercanas, además de en el propio
detalle de una publicación (solo lectura, pin de origen y de destino si tiene —
ver *Cómo se hizo la iteración de mejora continua post-Fase 5*). Calificaciones habilita
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

Fase 5 (push) hecha directo, sin Gauntlet Loop: requiere un paso manual externo
(crear el proyecto de Firebase) igual que Login con Google, así que no se podía
automatizar de punta a punta de entrada, y el riesgo acá es de integración con un
SDK externo, no del hueco backend-sin-camino-en-la-UI que Gauntlet Loop caza bien.
`Usuario.FcmToken` ya existía desde la Fase 0; se sumó `PUT /api/usuarios/me/fcm-token`
para registrar/desregistrar el token, `FcmSenderService` (paquete `FirebaseAdmin`,
opcional igual que `GoogleSettings` — sin `GOOGLE_APPLICATION_CREDENTIALS` configurada
no manda nada y no rompe nada) disparado desde `OfertaService` en los tres eventos
(nueva oferta, oferta aceptada, publicación completada), y del lado de Flutter
`firebase_core`+`firebase_messaging` (mobile únicamente — `soportaPush` en
`fcm_service.dart` da `false` en desktop/web sin tocar `dart:io Platform`, que tiene
problemas conocidos en web). Verificado real de punta a punta contra un proyecto de
Firebase de verdad en un emulador Android: pedido de permiso nativo, token
registrado en el backend (`UPDATE Usuarios SET FcmToken`), y notificación recibida
tanto con la app en segundo plano (bandeja del sistema) como en primer plano
(SnackBar propio, ya que FCM no la muestra sola ahí).

Fase 6 (ubicación en tiempo real) agregada por fuera del roadmap original del MVP,
a pedido puntual para competir mejor con otras apps del rubro: `UbicacionHub` de
SignalR, el dueño ve al fletero moverse en vivo en el mapa mientras el flete está
`EnCurso`, y a los fleteros con oferta Pendiente mientras todavía está `Publicada`.
La verificación final encontró y se arregló ahí mismo dos bugs reales (un
congelamiento silencioso del tracking a los 20-30s, y que el JWT de 15 minutos no
se refrescaba para la conexión de SignalR) — ver *Fase 6* para el detalle y la
limitación que quedó sin resolver.

Fase 7 (chat entre publicador y fletero) en la misma tanda: conversación por
Oferta vía `ChatHub` de SignalR + `GET`/`POST /api/ofertas/{id}/mensajes`, con
botón "Chatear" tanto en el detalle de publicación (dueño) como en "Mis ofertas"
(fletero). A diferencia de la Fase 6, esta pasó la verificación final sin
encontrar nada que arreglar — ver *Fase 7* para el detalle.

Fase 8 (fotos) en la misma tanda: fotos de la carga en una publicación (dueño,
hasta 8, visibles para cualquiera que vea el detalle) y una foto de vehículo por
usuario (perfil propio, vía la nueva pantalla "Mi perfil") — almacenamiento en
disco local scopeado a `Fletar.API/uploads/` (nunca `wwwroot`), con validación
real de Content-Type + magic bytes y nombres GUID (nunca el nombre que manda el
cliente). A diferencia de la Fase 7, esta vez la verificación final sí encontró
dos bugs reales — ver *Fase 8* para el detalle — ambos arreglados aparte,
directo, apenas se detectaron.

**Fase 9 (verificación de identidad)** — backend completo: frente y dorso subidos
por el usuario a `uploads/privado/documentos-identidad/` (esa carpeta no se
registra en `UseStaticFiles`, sólo se descarga por un endpoint de admin), una fila
por usuario, estados Pendiente/Aprobada/Rechazada, endpoints propios en
`/api/usuarios/me/verificacion-identidad` y moderación en
`/api/admin/verificaciones-identidad` (listar, descargar documento, aprobar,
rechazar con comentario). La pantalla de verificación existe en Flutter (Mi
perfil → Verificación de identidad: subir frente y dorso, ver estado y motivo de
rechazo) y el panel admin tiene la pestaña *Identidad* (ver documentos privados,
aprobar, rechazar con motivo); el perfil público muestra la insignia
"Identidad verificada". Cubierto por `flutter analyze`, `flutter build web` y
tests de widget de las dos pantallas, además de `dotnet build` y los health
tests del backend.

**Sin arrancar:** pagos, lo único que queda del roadmap original por fuera del MVP.

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
referencias internas — igual que Ceta-Logística. Única excepción: `Fletar.BLL`
tiene un `FrameworkReference` a `Microsoft.AspNetCore.App` (no una referencia a
`Fletar.API` — la dirección de *proyectos* no cambió) para poder usar
`IHubContext<T>` desde un Service e inyectarlo sin que el Hub tenga que vivir en
`Fletar.API`. Se dio por primera vez con `ChatHub` (Fase 7): a diferencia de
`UbicacionHub` (Fase 6, vive en `Fletar.API/Hubs` porque nada de `Fletar.BLL`
necesitaba notificarlo desde fuera de un request HTTP), `MensajeService` sí
necesita disparar la notificación al grupo de SignalR desde dentro del propio
`POST /mensajes` — por eso `ChatHub` vive en `Fletar.BLL/Hubs`.

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

## Cómo se hizo la iteración de mejora continua post-Fase 5 (Gauntlet Loop)

Con las 5 fases del MVP completas, se pidió agregar mapa+dirección al detalle de
una publicación y después una pasada de mejora continua con Gauntlet Loop "hasta
donde tenga sentido". 13 agentes / ~1.49M tokens / ~99 min, en cuatro etapas:

1. **Mapa en el detalle** (builder + crítico): `_MapaUbicacionPublicacion` en
   `publicacion_detail_screen.dart`, mismo patrón que `_MapaSeleccionOrigen`/
   `_MapaPublicacionesCercanas` (TileLayer OSM), pin de origen siempre y de destino
   si existe, con `CameraFit.coordinates` para que ambos queden visibles. Aprobado
   a la primera ronda, con verificación visual real contra el emulador Android.
2. **Búsqueda de mejoras** (4 lentes en paralelo, sólo lectura — sin implementar
   nada todavía): navegación/UX, seguridad, correctitud/máquina-de-estados, calidad
   de código. Encontraron **24 hallazgos** en total.
3. **Implementación** de los 3 priorizados (los primeros `high` por orden de
   llegada de las 4 lentes, no necesariamente los 3 más graves — ver más abajo):
   - Faltaba **editar una publicación** desde la UI (el backend ya lo soportaba,
     `PUT /api/publicaciones/{id}`, desde antes de esta pasada): nueva ruta
     `/publicaciones/:id/editar`, reutiliza el formulario de creación precargado.
   - **"Mis ofertas" mostraba un estado engañoso**: el badge era el de la
     *publicación* (`OfertaAceptada`), no el de la *oferta propia* — un fletero
     rechazado veía "Oferta aceptada" y podía creer que era la suya. Se separó en
     dos badges (`oferta_estado.dart`, nuevo, compartido con el detalle).
   - **Fix de seguridad real**: `GET /api/publicaciones/{id}/ofertas` devolvía el
     monto y mensaje de *todos* los oferentes a cualquier usuario autenticado, no
     solo al dueño — rompía la lógica de "oferta ciega" de un marketplace de
     subasta. Ahora un no-dueño recibe como máximo su propia oferta.
4. **Verificación final**: build+test de ambos lados limpio, y smoke test end-to-end
   en el emulador ejercitando las tres cosas nuevas (mapa, editar, badges) contra
   datos reales.

**Quedaron sin implementar 21 de los 24 hallazgos** (documentados en el journal del
workflow, no en este archivo — son demasiados para este nivel de detalle). El
criterio de priorización de esos 3 fue simple (los primeros `high` que llegaron
de las 4 lentes en paralelo, no un ranking real de severidad), así que se colaron
dos `high` afuera del top-3 — se arreglaron aparte, directo, apenas se detectó esto:

- **Condición de carrera en `OfertaService.AceptarAsync`**: sin concurrency token
  ni update condicional, dos aceptaciones casi simultáneas sobre la misma
  publicación podían dejar dos `Oferta.Estado = Aceptada` con `Publicacion.
  OfertaAceptadaId` apuntando a una sola. Arreglado con un `ExecuteUpdateAsync`
  condicionado a `Estado = Publicada` antes de tocar la Oferta — sólo una de las
  dos aceptaciones concurrentes encuentra la fila todavía en ese estado; la otra
  ve 0 filas afectadas y falla con un 400 claro. Verificado disparando dos
  aceptaciones reales en paralelo contra la API: sólo una tuvo éxito, la otra
  recibió el error esperado, sin datos huérfanos.
- **Refresh de token no serializado en `AuthInterceptor`** (Flutter): si varias
  requests recibían 401 casi al mismo tiempo (típico al abrir el listado, que
  dispara 4 providers a la vez), cada una disparaba su propio `/auth/refresh`; el
  backend revoca toda la familia ante el reuso del token viejo, y el usuario
  quedaba deslogueado sin haber hecho nada malo. Arreglado con un patrón
  single-flight (`_refreshEnCurso`): el chequeo+asignación del Future compartido
  es sincrónico (sin `await` entre medio), así que dos `onError` casi
  simultáneos no alcanzan a crear cada uno su propio refresh — Dart corre cada
  continuación hasta el próximo `await` sin interrupción, así que el segundo
  siempre ve el Future del primero ya asignado.

Los 19 hallazgos restantes (`medium`/`low` en su mayoría — duplicación de código,
falta de validación server-side de `Monto`, `UsuarioService` sin AutoMapper, etc.)
quedan pendientes para una próxima pasada.

Moraleja nueva para la próxima pasada de mejora continua: priorizar por severidad
real entre *todos* los hallazgos antes de elegir qué implementar, no por el orden
de llegada de los buscadores en paralelo.

## Fase 6 — Ubicación en tiempo real (Gauntlet Loop)

Pedida explícitamente por fuera del roadmap original ("qué más podemos hacer para
competir con otras apps del rubro"): ver dónde está el fletero en el mapa mientras
el flete está `EnCurso`, y ver la posición de cada fletero con oferta `Pendiente`
mientras el dueño todavía está evaluando ofertas. 5 agentes / ~971k tokens / ~99 min
en tres etapas (backend, Flutter, verificación end-to-end).

- **Backend**: `UbicacionHub` (SignalR, `/hubs/ubicacion`) con tres métodos —
  `ActualizarUbicacion` (lo llama el fletero, persiste `Usuario.UltimaLatitud/
  UltimaLongitud/UltimaUbicacionFecha` y emite a su grupo), `SeguirFletero` (lo
  llama quien quiere verlo — **autorización real**: sólo si el que llama es dueño
  de una publicación donde ese fletero tiene oferta Pendiente o Aceptada, si no
  tira `HubException`) y `DejarDeSeguirFletero`. El JWT no puede ir en el header
  `Authorization` en el handshake de un WebSocket — va por `?access_token=` en la
  URL, restringido a rutas bajo `/hubs` (`JwtBearerEvents.OnMessageReceived` en
  `Program.cs`) para no abrir esa vía en el resto de la API.
- **Flutter**: `geolocator` (opt-in explícito con un toggle, sólo foreground —
  nunca tracking en segundo plano) + `signalr_core` (elegido sobre `signalr_netcore`
  porque este último no soporta web). Una sola conexión de SignalR compartida por
  usuario logueado (`ubicacionHubClientProvider`, ver Fase 5 para el mismo criterio
  con Firebase). Pin de camión en vivo en el mapa del detalle (`EnCurso`) y chip de
  distancia por cada oferta `Pendiente` (`Publicada`).

**La verificación final (crítico de contexto fresco) encontró un bug real de
severidad alta** que los críticos por etapa no vieron: el tracking se congelaba en
silencio a los 20-30 segundos de uso normal (con el backend corriendo todo el
tiempo, sin ninguna falla de red de por medio) — la conexión de SignalR se caía y
nadie la volvía a levantar porque `UbicacionHubClient` sólo escuchaba
`onreconnected`, nunca `onclose` (que es lo que dispara `withAutomaticReconnect()`
cuando agota sus reintentos). Arreglado agregando un `onclose` que reintenta cada 5
segundos hasta reconectar y volver a seguir a los fleteros que estaban en
seguimiento. Verificado re-disparando el escenario original: 72+ segundos de
movimiento simulado (vía un cliente SignalR real en Node) sin ningún congelamiento,
muy por encima de la ventana de 20-30s donde antes fallaba.

Al verificar el arreglo se encontró **un segundo problema, más importante que el
primero**: el JWT dura 15 minutos (`JwtSettings.AccessTokenDuracion`), y a
diferencia de una request HTTP normal (que `AuthInterceptor` refresca sola ante un
401), el JWT de un Hub de SignalR se valida una sola vez, en el handshake — así que
una pantalla de tracking abierta más de 15 minutos (el caso de uso central de esta
fase: acompañar un flete real de punta a punta) pierde el tracking para siempre en
cuanto el token vence, sin ningún camino de recuperación automática. Arreglado con
`core/network/access_token_refresher.dart`: antes de cada intento de (re)conexión,
decodifica el `exp` del JWT guardado y, si está vencido o vence en menos de 30
segundos, lo refresca *antes* de usarlo (duplica a propósito la llamada a
`/auth/refresh` que ya tiene `AuthInterceptor` — unificarlas requeriría romper la
separación de `core/network` por un helper que hoy se usa en un solo lugar).

**Limitación conocida, no resuelta en esta pasada**: en el escenario más extremo
posible — el backend cae por completo *y* el JWT vence *mientras* la pantalla de
tracking sigue abierta y conectada — la reconexión automática de la conexión ya
abierta no se recupera sola (confirmado en pruebas manuales repetidas, esperando
varios minutos). Los datos sí llegan bien al backend y se persisten correctamente
(confirmado con `SeguirFletero` al volver a entrar a la pantalla, que trae la
última posición real), así que no es un problema de datos — es específicamente que
la conexión SignalR ya viva no se da cuenta de que tiene que reconectarse con un
token nuevo en este caso compuesto. Salir y volver a entrar a la pantalla de la
publicación soluciona el problema (fuerza un `SeguirFletero` nuevo). Queda para una
próxima pasada investigar por qué `onclose`/`withAutomaticReconnect()` no reacciona
en este caso puntual (backend caído + token vencido a la vez), a diferencia del
caso ya arreglado (backend vivo todo el tiempo).

## Fase 7 — Chat entre publicador y fletero (Gauntlet Loop)

Pedida junto con la Fase 6 en la misma tanda de "qué más podemos hacer para
competir con otras apps del rubro". Chat por **Oferta** (no por Publicación
entera): cada oferta tiene su propia conversación entre el dueño de la
publicación y ese oferente puntual — así dos fleteros que ofertaron sobre la
misma publicación no se ven los mensajes entre ellos. 5 agentes / ~1M tokens /
~100 min en tres etapas (backend, Flutter, verificación end-to-end). Ambas
etapas aprobaron a la primera ronda — a diferencia de las Fases 1-3 y 6, esta
vez no hubo que arreglar nada después de la verificación final.

- **Backend**: entidad `Mensaje` (`OfertaId`, `RemitenteId`, `Texto` con tope de
  2000 caracteres validado en el servidor, `FechaEnvio`), `GET`/`POST
  /api/ofertas/{id}/mensajes` con autorización real (sólo el dueño de la
  publicación o el oferente de *esa* oferta — el resto recibe 401, oferta
  inexistente 404). Entrega en vivo vía `ChatHub` (SignalR, `/hubs/chat`, mismo
  patrón de autorización explícita que `UbicacionHub`), y notificación push
  (`FcmSenderService`, ya existente desde la Fase 5) a la otra parte en cada
  mensaje nuevo. `ChatHub` vive en `Fletar.BLL/Hubs` en vez de `Fletar.API/Hubs`
  — ver *Estructura del repositorio* para el porqué (única excepción a la
  dirección de dependencias del backend).
- **Flutter**: `lib/features/mensajes/`, con `ChatHubClient` calcado de
  `UbicacionHubClient` (mismo doble arreglo de reconexión y refresco de token de
  la Fase 6 — este código ya nace con esos dos bugs arreglados, en vez de
  reintroducirlos). Botón "Chatear" en dos lugares — el detalle de una
  publicación (lado dueño, por cada oferta) y "Mis ofertas" (lado fletero, sobre
  la propia oferta) — aplicando ya la moraleja de navegación-de-las-dos-partes
  de las fases anteriores desde el diseño, no como arreglo posterior.

Verificado real de punta a punta en el emulador Android con dos cuentas reales:
mensaje del fletero enviado por script (simulando al fletero mientras el dueño
tiene la pantalla abierta) llega en vivo a la UI del dueño sin recargar
(confirmado con una captura de pantalla), y mensaje del dueño escrito desde la
UI real queda persistido en la base con el remitente correcto (confirmado
consultando el backend). Caso negativo (un tercero sin relación con la oferta)
rechazado tanto en `GET`/`POST` (401) como al intentar `SeguirConversacion` por
el Hub (`HubException`).

## Fase 8 — Fotos (Gauntlet Loop)

Agregada en la misma tanda que las Fases 6 y 7 ("qué más podemos hacer para
competir"), pero por fuera del pedido puntual de esas dos — fotos era una de
las mejoras discutidas desde el arranque de esta tanda de mejora continua. Dos
casos de uso independientes: fotos de la **carga** (el dueño de una
publicación sube hasta 8, públicas como el resto de la publicación) y foto del
**vehículo** (una por usuario, en el perfil propio — señal de confianza para
cuando ese usuario oferta como fletero). 5 agentes / ~346k tokens / ~50 min en
tres etapas (backend, Flutter, verificación end-to-end).

- **Backend**: entidad `PublicacionFoto` (guarda sólo `NombreArchivo`, nunca la
  URL armada — la URL relativa se construye en el service, así no queda atada
  a un host) + `Usuario.FotoUrl` (ya existía desde la Fase 0, reutilizado sin
  migración nueva). `IAlmacenamientoArchivosService` guarda en disco local
  bajo `Fletar.API/uploads/{publicaciones,vehiculos}/` con nombre
  `Guid.NewGuid()` — el código ni siquiera lee `IFormFile.FileName`, así que
  un nombre de archivo malicioso (`../../../etc/passwd.jpg`) no tiene ningún
  efecto porque nunca se consulta. Valida Content-Type contra una whitelist
  (jpg/png/webp) Y la firma de magic bytes de los primeros bytes reales del
  archivo (no la extensión declarada), tope de 5MB y de 8 fotos por
  publicación. Servido con `UseStaticFiles` + un `PhysicalFileProvider`
  explícito scopeado *sólo* a `uploads/` (nunca `wwwroot` — ver *Estructura
  del repositorio*), colocado después de `UseCors` para que las imágenes
  salgan con headers CORS (necesario para que Flutter web con renderer
  CanvasKit, que trae los bytes por fetch/XHR, pueda mostrarlas).
  `POST`/`DELETE /api/publicaciones/{id}/fotos(/{fotoId})` y
  `PUT /api/usuarios/me/foto-vehiculo`, con la autorización real en los
  services (`ValidarDuenio`), no en el controller.
- **Flutter**: `image_picker` para elegir de galería o cámara. Sección de
  fotos en crear/editar publicación (con un giro de UX: tras crear una
  publicación, la pantalla redirige sola a "Editar" en vez de volver al
  listado — agregar una foto recién creada la publicación hubiera requerido
  salir y volver a entrar a mano, el mismo tipo de hueco de navegación que ya
  se evitó en fases anteriores, esta vez resuelto desde el diseño). Carrusel
  de sólo lectura en el detalle. **Hueco de navegación real que no existía
  hasta esta fase**: no había ninguna pantalla "Mi perfil" — se creó una
  (ruta `/perfil`, ícono nuevo en el AppBar) para que el propio usuario suba
  su foto de vehículo, más `UsuarioPublicoScreen` (`/usuarios/:id`) para ver
  el perfil público de cualquier otro usuario navegando desde el nombre del
  dueño/oferentes.

**La verificación final encontró dos bugs reales — a diferencia de la Fase 7,
que no encontró nada, esta se pareció más a la Fase 6:**

- **Una subida de foto con el JWT vencido rompía en silencio**:
  `AuthInterceptor` reintenta un 401 refrescando el token y reenviando el
  mismo `RequestOptions`, pero para una subida multipart eso significa
  reenviar la misma instancia de `FormData` — Dio la marca "finalizada" la
  primera vez que se serializa, y reusarla tira un `StateError` (no un
  `DioException`, así que el `catch` existente ni siquiera lo atrapaba): el
  usuario veía el genérico "Ocurrió un error inesperado" sin ninguna pista de
  la causa real. Arreglado clonando la `FormData` antes de reintentar
  (`FormData.clone()`, que Dio expone puntualmente para este caso). Verificado
  con un test nuevo (`test/auth_interceptor_formdata_retry_test.dart`, primer
  test automatizado de `AuthInterceptor`) que arma un servidor HTTP real en
  loopback, fuerza un 401 en el primer intento y confirma que el reintento
  llega con el archivo completo — confirmé además que ese test *falla* si se
  saca el fix, no sólo que pasa con él puesto.
- **Cambiar la foto de vehículo desde "Mi perfil" expulsaba de esa pantalla**:
  `routerProvider` construía un `GoRouter` *nuevo* (con
  `initialLocation: '/'`) cada vez que `ref.watch(authControllerProvider)`
  cambiaba — y `actualizarFotoUrl()` (para reflejar la foto nueva en memoria
  sin un endpoint `/usuarios/me`) es la primera vez que algo muta ese estado
  por un motivo distinto a login/logout, así que nadie había notado que
  cualquier cambio ahí resetea toda la navegación. Arreglado con el patrón
  estándar de Riverpod+go_router: un `ChangeNotifier` puente
  (`_RouterRefreshNotifier`) pasado como `refreshListenable`, así el
  `GoRouter` se crea una sola vez y sólo se le pide reevaluar `redirect` —
  nunca se recrea ni pierde la ubicación actual. Verificado real en el
  emulador: subir una foto de vehículo ahora deja al usuario en "Mi perfil"
  viendo la foto nueva, no en el listado principal.

Moraleja que se repite (ver Fases 1+2, 3 y 6): una verificación de punta a
punta encuentra lo que cada etapa por separado no puede — ni backend ni
Flutter por separado tenían motivo para ejercitar "¿qué pasa si el token
vence justo antes de subir una foto?" ni "¿qué pasa si cambio esta foto y no
otra cosa del estado de auth?".

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
- **Fase 5 — listo.** `PUT /api/usuarios/me/fcm-token` + `FcmSenderService`
  disparado en nueva-oferta/oferta-aceptada/publicacion-completada, con Firebase
  real conectado y verificado en emulador Android (foreground y background).
  Alcance mobile únicamente (ver *Stack*).
- **Fase 6 — listo, con una limitación conocida.** Ubicación en tiempo real del
  fletero (`UbicacionHub` de SignalR) en el mapa del detalle de una publicación,
  tanto `EnCurso` como `Publicada` con ofertas Pendientes. Ver *Fase 6* para el
  detalle de los dos bugs reales que encontró la verificación final y la
  limitación que quedó sin resolver (reconexión tras backend caído + JWT vencido
  a la vez).
- **Fase 7 — listo.** Chat entre publicador y fletero por Oferta (`ChatHub` de
  SignalR + `GET`/`POST /api/ofertas/{id}/mensajes`), con navegación real desde
  ambas partes (detalle de publicación para el dueño, "Mis ofertas" para el
  fletero) desde el diseño inicial. Ver *Fase 7*.
- **Fase 8 — listo.** Fotos de la carga (`PublicacionFoto`, hasta 8 por
  publicación) y foto de vehículo por usuario (`Usuario.FotoUrl`, perfil
  propio vía la nueva pantalla "Mi perfil"), en disco local servido desde
  `Fletar.API/uploads/` (nunca `wwwroot`). Ver *Fase 8* para los dos bugs
  reales que encontró la verificación final y cómo se arreglaron.

Gaps menores conocidos, no bloqueantes: sin tests automatizados de
`PublicacionService`/`OfertaService`/`CalificacionService`/`UsuarioService`/
`ReporteService`/`AdminService`/`FcmSenderService`/`MensajeService`/
`AlmacenamientoArchivosService` (solo hay tests triviales de salud del lado
backend; del lado Flutter sí hay uno puntual desde la Fase 8,
`auth_interceptor_formdata_retry_test.dart`); la vista de mapa de "cercanas" usa una ubicación fija (CABA) — `geolocator`
ya es una dependencia desde la Fase 6, pero todavía no se reusó ahí, sólo para
compartir la posición del fletero; la sesión no persiste tras un reload real
del navegador (falta un endpoint `/usuarios/me` para validar el token guardado en el
arranque frío, ver `AuthController.build()` en `auth_providers.dart`); notificación
push sin acción de tap-para-navegar (llega con título/cuerpo nomás, no deep-link a
la publicación); ícono de la app Android sigue siendo el default de Flutter; la
reconexión de SignalR no se recupera sola si el backend cae por completo y el JWT
vence al mismo tiempo mientras una pantalla de tracking sigue abierta (ver *Fase
6*); otros 19 hallazgos `medium`/`low` de la pasada de mejora continua post-Fase 5
sin implementar todavía.

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
- No se versiona `.env` (clave JWT y cadena de conexión), `firebase-service-account.json`
  (backend) ni `google-services.json` (`FLETAR_APP/android/app/`) — están en `.gitignore`.
- No hacer `git push` ni `git commit` salvo pedido expreso.
