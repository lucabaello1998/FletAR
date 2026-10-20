# FletAR — lo que falta para estar en producción

Estado al 20/10/2026: MVP completo (fases 1-9), release Android firmado y endurecido.
Lo que sigue, en orden de dependencia.

## 1. Backend desplegado (bloquea todo lo demás)

- [ ] **Base de datos**: Postgres 16 + PostGIS en un proveedor gestionado (Neon, Supabase,
      Railway, Render) o un VPS. Guardar la cadena en `FLETAR_CS`.
- [ ] **API**: publicar `FLETAR_BACKEND` (Dockerfile ya existe) con HTTPS y dominio propio.
      Variables de producción: `FLETAR_CS`, `FLETAR_JWT_KEY` (nueva, no la de dev),
      `FLETAR_JWT_ISSUER`, `FLETAR_JWT_AUDIENCE`, `FLETAR_GOOGLE_CLIENT_ID`,
      `GOOGLE_APPLICATION_CREDENTIALS`, `CORS` con el dominio real.
- [ ] **Migraciones**: correr `dotnet ef database update` contra la base nueva (o dejarlas
      en el arranque, decidido explícitamente).
- [ ] **Uploads persistentes**: volumen para `uploads/publico` y `uploads/privado`
      (los documentos de identidad NO pueden quedar en el disco efímero del contenedor).
- [ ] **Backups** automáticos de la base y de `uploads/privado`.
- [ ] **Firebase**: proyecto de producción, `google-services.json` en la app y cuenta de
      servicio en la API (push real).
- [ ] **Google OAuth**: cliente de producción con el SHA-1 del keystore de release.
- [ ] Probar el flujo completo contra la URL real (registro, publicar, ofertar, chat,
      ubicación, verificación de identidad).

## 2. Publicación en Google Play

- [ ] Cuenta de desarrollador de Play Console (pago único de USD 25).
- [ ] **Backup del keystore** (`FletAR\.secrets\`) en dos lugares fuera de la PC.
      Sin eso no hay actualizaciones (o hay que usar Play App Signing).
- [ ] Subir `version` en `pubspec.yaml` (empezar en `1.0.0+1`).
- [ ] Compilar con la URL real:
      `flutter build appbundle --release --dart-define=FLETAR_API_URL=https://TU-DOMINIO/api`
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
