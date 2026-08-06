/// Mensaje del chat de una Oferta puntual (Fase 7) - ver `Mensaje` en el
/// backend (`Fletar.DAL/Models/Mensaje.cs`). `remitenteNombre` no viene de una
/// navegación de EF, el backend lo resuelve con un lookup por lote (mismo
/// patrón que `usuarioNombre` en `Oferta`).
class Mensaje {
  const Mensaje({
    required this.id,
    required this.ofertaId,
    required this.remitenteId,
    required this.remitenteNombre,
    required this.texto,
    required this.fechaEnvio,
  });

  factory Mensaje.fromJson(Map<String, dynamic> json) => Mensaje(
        id: json['id'] as int,
        ofertaId: json['ofertaId'] as int,
        remitenteId: json['remitenteId'] as int,
        remitenteNombre: json['remitenteNombre'] as String,
        texto: json['texto'] as String,
        fechaEnvio: DateTime.parse(json['fechaEnvio'] as String),
      );

  final int id;
  final int ofertaId;
  final int remitenteId;
  final String remitenteNombre;
  final String texto;
  final DateTime fechaEnvio;
}

/// Espejo de `Mensaje.TextoLargoMaximo` en el backend - el servidor es la
/// autoridad real (ver `MensajeService.EnviarAsync`), esto es sólo para que la
/// UI avise antes de mandar algo que el servidor va a rechazar de todas formas.
const mensajeTextoLargoMaximo = 2000;
