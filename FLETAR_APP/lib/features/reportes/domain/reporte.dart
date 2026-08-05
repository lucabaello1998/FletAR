abstract final class EstadoReporte {
  static const pendiente = 'Pendiente';
  static const revisado = 'Revisado';
  static const descartado = 'Descartado';
}

class Reporte {
  const Reporte({
    required this.id,
    required this.publicacionId,
    required this.publicacionTitulo,
    required this.usuarioReportanteId,
    required this.usuarioReportanteNombre,
    required this.motivo,
    this.comentario,
    required this.fechaReporte,
    required this.estado,
  });

  factory Reporte.fromJson(Map<String, dynamic> json) => Reporte(
        id: json['id'] as int,
        publicacionId: json['publicacionId'] as int,
        publicacionTitulo: json['publicacionTitulo'] as String,
        usuarioReportanteId: json['usuarioReportanteId'] as int,
        usuarioReportanteNombre: json['usuarioReportanteNombre'] as String,
        motivo: json['motivo'] as String,
        comentario: json['comentario'] as String?,
        fechaReporte: DateTime.parse(json['fechaReporte'] as String),
        estado: json['estado'] as String,
      );

  final int id;
  final int publicacionId;
  final String publicacionTitulo;
  final int usuarioReportanteId;
  final String usuarioReportanteNombre;
  final String motivo;
  final String? comentario;
  final DateTime fechaReporte;
  final String estado;
}
