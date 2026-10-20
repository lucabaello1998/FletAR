/// Estado propio de la verificación de identidad (Fase 9) - refleja
/// `VerificacionIdentidadResponse` del backend.
///
/// Nunca trae los documentos ni sus nombres de archivo: sólo un admin los ve,
/// vía `/api/admin/verificaciones-identidad/{id}/documento/{lado}`. Acá sólo
/// viaja el estado y, si hubo rechazo, el comentario que dejó el admin.
class VerificacionIdentidad {
  const VerificacionIdentidad({
    required this.id,
    required this.estado,
    required this.fechaSolicitud,
    this.fechaRevision,
    this.comentarioAdmin,
  });

  factory VerificacionIdentidad.fromJson(Map<String, dynamic> json) =>
      VerificacionIdentidad(
        id: json['id'] as int,
        estado: json['estado'] as String,
        fechaSolicitud: DateTime.parse(json['fechaSolicitud'] as String),
        fechaRevision: json['fechaRevision'] == null
            ? null
            : DateTime.parse(json['fechaRevision'] as String),
        comentarioAdmin: json['comentarioAdmin'] as String?,
      );

  final int id;

  /// `Pendiente` | `Aprobada` | `Rechazada` (el backend serializa el enum como
  /// string - ver VerificacionIdentidadProfile).
  final String estado;
  final DateTime fechaSolicitud;
  final DateTime? fechaRevision;
  final String? comentarioAdmin;

  bool get aprobada => estado == 'Aprobada';
  bool get pendiente => estado == 'Pendiente';
  bool get rechazada => estado == 'Rechazada';
}
