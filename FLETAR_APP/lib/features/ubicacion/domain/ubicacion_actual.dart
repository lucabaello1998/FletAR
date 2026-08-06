/// Última posición conocida de un fletero (ubicación en vivo, Fase 6).
///
/// Refleja tanto la respuesta de `UbicacionHub.SeguirFletero` (backend, ver
/// `UbicacionActualResponse`) como el evento `RecibirUbicacion(usuarioId, lat,
/// lng, fecha)` que emite ese mismo Hub - ambos tienen la misma forma, así que
/// comparten este único modelo del lado de Flutter.
class UbicacionActual {
  const UbicacionActual({
    required this.usuarioId,
    required this.lat,
    required this.lng,
    required this.fecha,
  });

  final int usuarioId;
  final double lat;
  final double lng;
  final DateTime fecha;
}
