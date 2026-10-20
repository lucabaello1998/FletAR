/// Solicitud de verificación de identidad vista por un admin (Fase 9) -
/// refleja `VerificacionIdentidadAdminResponse`. A diferencia de la vista del
/// dueño, identifica a quién pertenece (nombre y email) para el listado de
/// moderación.
class VerificacionIdentidadAdmin {
  const VerificacionIdentidadAdmin({
    required this.id,
    required this.usuarioId,
    required this.usuarioNombre,
    required this.usuarioEmail,
    required this.estado,
    required this.fechaSolicitud,
    this.fechaRevision,
    this.comentarioAdmin,
  });

  factory VerificacionIdentidadAdmin.fromJson(Map<String, dynamic> json) =>
      VerificacionIdentidadAdmin(
        id: json['id'] as int,
        usuarioId: json['usuarioId'] as int,
        usuarioNombre: json['usuarioNombre'] as String,
        usuarioEmail: json['usuarioEmail'] as String,
        estado: json['estado'] as String,
        fechaSolicitud: DateTime.parse(json['fechaSolicitud'] as String),
        fechaRevision: json['fechaRevision'] == null
            ? null
            : DateTime.parse(json['fechaRevision'] as String),
        comentarioAdmin: json['comentarioAdmin'] as String?,
      );

  final int id;
  final int usuarioId;
  final String usuarioNombre;
  final String usuarioEmail;

  /// `Pendiente` | `Aprobada` | `Rechazada`.
  final String estado;
  final DateTime fechaSolicitud;
  final DateTime? fechaRevision;
  final String? comentarioAdmin;

  bool get pendiente => estado == 'Pendiente';
  bool get aprobada => estado == 'Aprobada';
}
