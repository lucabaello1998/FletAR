# FletAR — lo que falta para estar en producción

Estado al 21/10/2026: MVP completo (fases 1-9), release Android firmado y endurecido,
backend desplegado en Railway con Neon/PostGIS y healthcheck público.
Lo que sigue, en orden de dependencia.

## 1. Backend desplegado

- [x] **Base de datos**: PostgreSQL + PostGIS en Neon. La API usa `DATABASE_URL`
      (sin pooling) y la extensión `postgis` está creada.
- [x] **API**: publicada en Railway con HTTPS:
      `https://fletar-production.up.railway.app` (healthcheck `/api/health`).
      Variables: `DATABASE_URL`, `FLETAR_JWT_KEY`, `FLETAR_JWT_ISSUER`,
      `FLETAR_JWT_AUDIENCE`, `FLETAR_MIGRATE_ON_START`, `FLETAR_UPLOADS_PATH`.
      Sentry es opcional (`SENTRY_DSN`).
- [x] **Migraciones**: se aplican al arrancar (`FLETAR_MIGRATE_ON_START=true`).
- [x] **Uploads persistentes**: volumen `fletar-volume` montado en `/data/uploads`.
- [x] **Backups**: workflow diario `backup.yml`, `scripts/backup-neon.ps1` y
      `scripts/backup-uploads.ps1`; detalle en `FLETAR_BACKEND/docs/BACKUPS.md`.
- [ ] Cargar el secret `DATABASE_URL` en GitHub, habilitar la restore window de
      Neon y probar un restore real en una branch temporal.
- [ ] **Firebase**: proyecto de producción, `google-services.json` en la app y cuenta de
      servicio en la API (push real).
- [ ] **Google OAuth**: cliente de producción con el SHA-1 del keystore de release.
- [ ] Probar el flujo completo contra la URL real (registro, publicar, ofertar, chat,
      ubicación, verificación de identidad).

## 2. Publicación en Google Play

- [ ] Cuenta de desarrollador de Play Console (pago único de USD 25).
- [ ] **Backup del keystore** (`FletAR\.secrets\`) en dos lugares fuera de la PC.
      Sin eso no hay actualizaciones (o hay que usar Play App Signing).
- [x] Versión `1.0.0+1` en `pubspec.yaml`.
- [x] Compilar con la URL real:
      `flutter build appbundle --release --dart-define=FLETAR_API_URL=https://fletar-production.up.railway.app/api`
      Generados `app-release.aab` (46.5 MB) y `app-release.apk` (59.0 MB),
      firmados con la key de FletAR.
- [x] Política de privacidad, términos y página de eliminación publicadas:
      `https://lucabaello1998.github.io/FletAR/`.
- [ ] Ficha de la app: nombre, descripción, ícono, capturas y feature graphic.
- [ ] *Data safety*: declarar ubicación, fotos, identidad y datos de cuenta.
- [ ] *Content rating* y clasificación para Argentina.
- [x] **Eliminación de cuenta dentro de la app** (`DELETE /api/usuarios/me` y
      **Mi perfil → Eliminar mi cuenta**) y URL pública de solicitud.
- [ ] Testing interno → cerrado → producción.

## 3. Producto / seguridad pendientes

- [ ] **Cuota de uploads** por usuario (hoy sólo hay límite por archivo y por publicación).
- [ ] **Expiración de la autorización de GPS** también en el cliente (hoy el backend corta
      a los 5 min, pero la pantalla puede seguir mostrando el último pin).
- [ ] Aviso explícito al fletero cuando el dueño deja de seguirlo / el viaje termina.
- [ ] Revisar los límites anti-abuso con uso real (120/min global, 10/min en auth).
- [x] Política de privacidad y términos y condiciones (Ley 25.326 de datos personales).
- [ ] Procedimiento de moderación de documentos de identidad (quién, cuándo, cuánto se guardan).
- [x] Monitoreo de errores con Sentry en API y app (código integrado, sin DSN
      queda apagado).
- [ ] Crear proyectos de Sentry, cargar `SENTRY_DSN` en Railway y compilar la app
      con `--dart-define=SENTRY_DSN=...`; configurar alertas de uptime.

## 4. Calidad

- [ ] Tests de integración contra Postgres real (hoy la sesión se prueba con base en memoria).
- [ ] Más cobertura de widgets en las pantallas nuevas (verificación, admin identidad).
- [ ] Prueba manual en un teléfono físico: push en background, GPS con pantalla apagada,
      cámara/galería, deep links.
- [ ] Accesibilidad y textos (revisar acentos/encoding en algunos mensajes heredados).

## 5. Autocompletado de direcciones y auditoría (21/10/2026)

- [x] **Autocompletar direcciones** en origen y destino con Nominatim (OpenStreetMap,
      sin API key): debounce de 650 ms, mínimo 4 caracteres, caché en memoria y cola
      de 1 request/1,1 s. Si el geocoder falla, el campo sigue aceptando texto libre.
- [x] **Sincronización bidireccional**: elegir una sugerencia mueve el pin del mapa, y
      tocar el mapa completa la dirección con geocodificación reversa. Si se escribe la
      dirección sin elegir sugerencia, al publicar se intenta ubicarla antes de rechazar.
- [x] **Cartel de error al publicar**: era un 500 real - `fechaDeseada` llegaba como
      `DateTime` sin zona y Npgsql no puede escribir eso en `timestamp with time zone`.
      Se normaliza en el backend y la app manda el mediodía UTC del día elegido (es un
      dato de calendario, no un instante).
- [x] **Sesión vencida**: cuando el refresh token deja de servir, la app limpia los
      tokens y vuelve al login con un aviso, en vez de quedar "logueada" con cada acción
      fallando. Los `title` de error ya no muestran "Error interno" ni "ocurrió un error
      inesperado" para 401/403/404/429/5xx.
- [x] **Auditoría aplicada (backend)**: `UseForwardedHeaders` para que el rate limit sea
      por IP real (antes era global), validaciones de registro (`[EmailAddress]`,
      contraseña 8-128), `403` para "no sos el dueño" (antes 401 y el cliente refrescaba
      en loop), 409 para choques de índice único, límites de `pageSize` y de radio en
      `/cercanas`, `catch` de los pushes de FCM (podían convertir una operación ya
      guardada en 500) y borrado de archivos de cuenta **después** del commit.
- [x] **Auditoría aplicada (app)**: candado anti doble envío, validación de categoría
      cuando falla el provider, `TapRegion` para cerrar la lista de sugerencias,
      confirmación al quitar el destino, fecha del date picker acotada y carreras del
      geocoder descartadas por número de solicitud.
- [ ] Desplegar este commit en Railway (el `DELETE /usuarios/me` todavía no está en
      producción: la API respondió 404 en la prueba E2E).
- [ ] `GET /api/health/ready` queda disponible para usar como healthcheck con chequeo de
      base; hoy Railway sigue usando `/api/health` (liveness).
## 6. Incidente de Railway (22/10/2026) y secretos

- Incidente global (status.railway.com, QH8L8B3E): builds y deploys pausados desde
  las 07:24 UTC, con aviso de seguridad y recomendación de rotar variables. Los
  commits `b37165f`, `24de08f` y `9ff1613` quedaron **skipped**: producción sigue
  con el build del 21/10.
- [x] `DATABASE_URL` actualizado en Railway.
- [ ] Confirmar en Neon que la password del rol se reseteó (si no, el valor nuevo
      de `DATABASE_URL` no conecta cuando se redeploye).
- [ ] Rotar `FLETAR_JWT_KEY` **pospuesto a propósito**: la app está en etapa de
      demostración, no hay usuarios reales y rotarlo invalida todas las sesiones.
      Hacerlo cuando se pase a producción en serio (junto con el hosting definitivo).
- [ ] Después de que los builds vuelvan: Redeploy del último commit y verificar
      `/api/health/ready`, publicar con fecha, `DELETE /usuarios/me`.