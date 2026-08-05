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
    required this.usuarioNombre,
    required this.monto,
    this.mensaje,
    required this.fechaOferta,
    required this.estado,
    required this.publicacionTitulo,
    required this.publicacionEstado,
  });

  factory Oferta.fromJson(Map<String, dynamic> json) => Oferta(
        id: json['id'] as int,
        publicacionId: json['publicacionId'] as int,
        usuarioId: json['usuarioId'] as int,
        usuarioNombre: json['usuarioNombre'] as String,
        monto: (json['monto'] as num).toDouble(),
        mensaje: json['mensaje'] as String?,
        fechaOferta: DateTime.parse(json['fechaOferta'] as String),
        estado: json['estado'] as String,
        publicacionTitulo: json['publicacionTitulo'] as String,
        publicacionEstado: json['publicacionEstado'] as String,
      );

  final int id;
  final int publicacionId;
  final int usuarioId;
  final String usuarioNombre;
  final double monto;
  final String? mensaje;
  final DateTime fechaOferta;
  final String estado;
  final String publicacionTitulo;
  final String publicacionEstado;

  bool get estaPendiente => estado == EstadoOferta.pendiente;
}
