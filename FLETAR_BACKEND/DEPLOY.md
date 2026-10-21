# Deploy de FletAR API

Stack recomendado para la primera URL pública:

- **Neon** para PostgreSQL 16 + PostGIS.
- **Railway** para la API .NET 8 en Docker, con WebSockets para SignalR.

La app Flutter se compila apuntando a la URL pública; no se sirve desde la API.

## 1. Base de datos en Neon

1. Crear un proyecto en [Neon](https://neon.tech) con PostgreSQL 16.
2. Copiar la connection string **directa** (no la pooled) con `sslmode=require`.
3. En el SQL Editor ejecutar:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

Neon soporta PostGIS; la extensión tiene que quedar creada en la base antes de
que la API aplique las migraciones.

## 2. API en Railway

1. Crear un proyecto en [Railway](https://railway.com) y elegir
   **Deploy from GitHub repo**.
2. Seleccionar `lucabaello1998/FletAR`.
3. Configurar **Root Directory** = `FLETAR_BACKEND`.
   Railway detecta el `Dockerfile` y el `railway.json` de esa carpeta.
4. Agregar un **Volume** montado en `/data/uploads`.
5. Cargar estas variables de entorno:

| Variable | Valor |
| --- | --- |
| `DATABASE_URL` | Connection string directa de Neon (`postgresql://...?...sslmode=require`) |
| `FLETAR_JWT_KEY` | Clave aleatoria de al menos 32 caracteres |
| `FLETAR_JWT_ISSUER` | `FletAR` |
| `FLETAR_JWT_AUDIENCE` | `FletAR` |
| `FLETAR_MIGRATE_ON_START` | `true` |
| `FLETAR_UPLOADS_PATH` | `/data/uploads` |
| `FLETAR_CORS_ORIGENES` | Opcional: orígenes del cliente web separados por coma |
| `FLETAR_GOOGLE_CLIENT_ID` | Opcional: login con Google |
| `GOOGLE_APPLICATION_CREDENTIALS` | Opcional: ruta al service account de Firebase dentro del contenedor |

`FLETAR_CS` no hace falta si se usa `DATABASE_URL`; si están las dos, gana
`FLETAR_CS`.

6. Generar un dominio público en **Networking > Generate Domain**.
7. Verificar:

```bash
curl https://<dominio>/api/health
# {"status":"ok"}
```

La API aplica las migraciones al arrancar porque `FLETAR_MIGRATE_ON_START=true`.
Si se prefiere correrlas como paso separado, apagar esa variable y ejecutar
`dotnet ef database update` con `FLETAR_CS` apuntando a Neon.

## 3. App Flutter

```bash
cd FLETAR_APP
flutter build appbundle \
  --dart-define=FLETAR_API_URL=https://<dominio>/api
```

Para un emulador Android local, la API en la PC se ve como
`http://10.0.2.2:5080/api`; para un dispositivo físico, usar la IP de la PC en la
red local.

## 4. Checklist antes de publicar

- [ ] `/api/health` responde desde internet.
- [ ] `CREATE EXTENSION postgis` ejecutado en Neon.
- [ ] Migraciones aplicadas y `__EFMigrationsHistory` presente.
- [ ] Volumen `/data/uploads` montado y persistente.
- [ ] `FLETAR_JWT_KEY` distinta de la de desarrollo.
- [ ] Variables de Firebase/Google cargadas si se quieren notificaciones/login.
- [ ] Probar registro, login, publicar, ofertar, aceptar, chat y GPS con la URL pública.
- [ ] Configurar backups de Neon y alertas de uso en Railway.

## Pendientes conocidos

- Los uploads siguen en disco local; el volumen de Railway evita perderlos, pero
  un blob storage (S3/R2) es la solución para varias réplicas.
- Firebase Cloud Messaging necesita el service account disponible dentro del
  contenedor; si no se configura, las notificaciones push quedan apagadas.
- Para producción conviene separar migraciones del arranque y correrlas como
  release command, con backups antes de cada deploy.
