import 'package:http_parser/http_parser.dart';

/// Determina el Content-Type con el que se sube una imagen elegida con
/// `image_picker` (Fase 8: fotos de carga / foto de vehículo).
///
/// `XFile.mimeType` (de `image_picker`/`cross_file`) suele venir resuelto en
/// web, pero en mobile/desktop suele ser null - el backend valida este header
/// estrictamente (sólo jpg/png/webp, ver `AlmacenamientoArchivosService` en
/// FLETAR_BACKEND), así que hace falta un fallback confiable por extensión de
/// archivo en vez de mandar algo genérico como `application/octet-stream`,
/// que el backend rechazaría siempre con 400.
MediaType mimeTypeDeImagen({required String nombreArchivo, String? mimeTypeConocido}) {
  if (mimeTypeConocido != null && mimeTypeConocido.isNotEmpty) {
    return MediaType.parse(mimeTypeConocido);
  }

  final nombre = nombreArchivo.toLowerCase();
  if (nombre.endsWith('.png')) return MediaType('image', 'png');
  if (nombre.endsWith('.webp')) return MediaType('image', 'webp');
  // .jpg/.jpeg y cualquier otro caso (la cámara casi siempre entrega JPEG).
  return MediaType('image', 'jpeg');
}
