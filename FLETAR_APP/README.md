# FletAR App

Cliente Flutter de FletAR: marketplace de fletes y logística liviana en
Argentina. Consume la API .NET 8 y los hubs SignalR de GPS y chat.

## Requisitos

- Flutter 3.x (Dart 3.11+)
- Android SDK para compilar el APK/AAB
- API de FletAR corriendo en local o la URL pública

## Correr en local

```bash
flutter pub get
flutter run -d chrome --dart-define=FLETAR_API_URL=http://localhost:5080/api
```

Para un emulador Android, la API local se ve como `http://10.0.2.2:5080/api`:

```bash
flutter run -d emulator-5554 \
  --dart-define=FLETAR_API_URL=http://10.0.2.2:5080/api
```

Para un dispositivo físico, usá la IP de la PC en la red local.

## Producción

```bash
flutter build appbundle --release \
  --dart-define=FLETAR_API_URL=https://fletar-production.up.railway.app/api \
  --dart-define=SENTRY_DSN=https://<public-key>@o<org>.ingest.sentry.io/<project-id>

flutter build apk --release \
  --dart-define=FLETAR_API_URL=https://fletar-production.up.railway.app/api \
  --dart-define=SENTRY_DSN=https://<public-key>@o<org>.ingest.sentry.io/<project-id>
```

Artefactos:

- `build/app/outputs/bundle/release/app-release.aab`
- `build/app/outputs/flutter-apk/app-release.apk`

La firma release usa `android/key.properties` y el keystore de `.secrets/`, que
no se versionan.

## Tests

```bash
flutter test
flutter analyze
```

## Legal y eliminación de cuenta

- [Política de Privacidad](https://lucabaello1998.github.io/FletAR/privacidad.html)
- [Términos y Condiciones](https://lucabaello1998.github.io/FletAR/terminos.html)
- [Eliminación de cuenta](https://lucabaello1998.github.io/FletAR/eliminar-cuenta.html)

La eliminación también está disponible en la app: **Mi perfil → Eliminar mi
cuenta**. El backend anonimiza la cuenta, borra documentos/fotos y revoca las
sesiones.

## Monitoreo

Sentry se activa sólo si se compila con `SENTRY_DSN`. Sin DSN la app funciona
igual y no envía eventos.
