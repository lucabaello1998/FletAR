class Calificacion {
  const Calificacion({
    required this.id,
    required this.publicacionId,
    required this.usuarioQueCalificaId,
    required this.usuarioCalificadoId,
    required this.puntaje,
    this.comentario,
    required this.fechaCalificacion,
  });

  factory Calificacion.fromJson(Map<String, dynamic> json) => Calificacion(
        id: json['id'] as int,
        publicacionId: json['publicacionId'] as int,
        usuarioQueCalificaId: json['usuarioQueCalificaId'] as int,
        usuarioCalificadoId: json['usuarioCalificadoId'] as int,
        puntaje: json['puntaje'] as int,
        comentario: json['comentario'] as String?,
        fechaCalificacion: DateTime.parse(json['fechaCalificacion'] as String),
      );

  final int id;
  final int publicacionId;
  final int usuarioQueCalificaId;
  final int usuarioCalificadoId;
  final int puntaje;
  final String? comentario;
  final DateTime fechaCalificacion;
}
