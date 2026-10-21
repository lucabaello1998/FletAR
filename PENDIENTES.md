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
- [x] **Migraciones**: se aplican al arrancar (`FLETAR_MIGRATE_ON_START=true`).
- [x] **Uploads persistentes**: volumen `fletar-volume` montado en `/data/uploads`.
- [ ] **Backups** automáticos de la base y del volumen de uploads.
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
      Generados `app-release.aab` (45.1 MB) y `app-release.apk` (56.7 MB).
- [ ] Ficha de la app: nombre, descripción, ícono, capturas, política de privacidad (URL).
- [ ] *Data safety*: declarar ubicación, fotos, identidad y datos de cuenta.
- [ ] *Content rating* y clasificación para Argentina.
- [ ] **Eliminación de cuenta dentro de la app** (requisito de Play; hoy sólo la
      desactiva un admin) y URL pública de solicitud de borrado.
- [ ] Testing interno → cerrado → producción.

## 3. Producto / seguridad pendientes

- [ ] **Cuota de uploads** por usuario (hoy sólo hay límite por archivo y por publicación).
- [ ] **Expiración de la autorización de GPS** también en el cliente (hoy el backend corta
      a los 5 min, pero la pantalla puede seguir mostrando el último pin).
- [ ] Aviso explícito al fletero cuando el dueño deja de seguirlo / el viaje termina.
- [ ] Revisar los límites anti-abuso con uso real (120/min global, 10/min en auth).
- [ ] Política de privacidad y términos y condiciones (Ley 25.326 de datos personales).
- [ ] Procedimiento de moderación de documentos de identidad (quién, cuándo, cuánto se guardan).
- [ ] Monitoreo: uptime, logs, errores (Sentry o similar) y alertas.

## 4. Calidad

- [ ] Tests de integración contra Postgres real (hoy la sesión se prueba con base en memoria).
- [ ] Más cobertura de widgets en las pantallas nuevas (verificación, admin identidad).
- [ ] Prueba manual en un teléfono físico: push en background, GPS con pantalla apagada,
      cámara/galería, deep links.
- [ ] Accesibilidad y textos (revisar acentos/encoding en algunos mensajes heredados).
