/// Estados posibles de una Oferta - reflejan el enum `EstadoOferta` del
/// backend, serializado como string (ver OfertaProfile.cs).
abstract final class EstadoOferta {
  static const pendiente = 'Pendiente';
  static const aceptada = 'Aceptada';
  static const rechazada = 'Rechazada';
  static const retirada = 'Retirada';
}

class Oferta {
  const Oferta({
    required this.id,
    required this.publicacionId,
    required this.usuarioId,
    required this.monto,
    this.mensaje,
    required this.fechaOferta,
    required this.estado,
  });

  factory Oferta.fromJson(Map<String, dynamic> json) => Oferta(
        id: json['id'] as int,
        publicacionId: json['publicacionId'] as int,
        usuarioId: json['usuarioId'] as int,
        monto: (json['monto'] as num).toDouble(),
        mensaje: json['mensaje'] as String?,
        fechaOferta: DateTime.parse(json['fechaOferta'] as String),
        estado: json['estado'] as String,
      );

  final int id;
  final int publicacionId;
  final int usuarioId;
  final double monto;
  final String? mensaje;
  final DateTime fechaOferta;
  final String estado;

  bool get estaPendiente => estado == EstadoOferta.pendiente;
}
