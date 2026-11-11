# Capturas para el README y la landing

Las cuatro imágenes son **capturas reales del cliente Flutter**, no maquetas. Los datos que se ven son
sintéticos (una cuenta de prueba y direcciones de ejemplo), no de clientes.

| Archivo | Qué muestra |
|---|---|
| `01-crear-publicacion.png` | Formulario "Nueva publicación" con título, descripción y la lista de sugerencias de direcciones abierta. |
| `02-mapa-direccion.png` | El mismo formulario con el mapa y el pin ubicado en la dirección elegida. |
| `03-detalle-ofertas.png` | Detalle de una publicación con tres ofertas y los botones Aceptar / Chatear. |
| `04-chat.png` | Chat de una oferta con mensajes de ida y vuelta. |

## Cómo se regeneran

Las tres primeras salen del build web de la app apuntando a una API local con datos de ejemplo:

```bash
flutter build web --release --dart-define=FLETAR_API_URL=http://localhost:5099/api
# servís build/web, abrís la app, iniciás sesión, navegás y capturás
```

El chat necesita SignalR para unirse a la conversación, así que se captura desde un test de widget con
un controller falso y fuentes reales:

```bash
flutter test --update-goldens tool/capturas/captura_chat_test.dart
```

Ese test no corre en CI (vive fuera de `test/`) y sólo existe para generar la imagen.
