/// Estados posibles de una Publicación - reflejan el enum `EstadoPublicacion`
/// del backend, serializado como string (ver PublicacionProfile.cs).
abstract final class EstadoPublicacion {
  static const publicada = 'Publicada';
  static const ofertaAceptada = 'OfertaAceptada';
  static const enCurso = 'EnCurso';
  static const completada = 'Completada';
  static const cancelada = 'Cancelada';
}

class Publicacion {
  const Publicacion({
    required this.id,
    required this.usuarioId,
    required this.usuarioNombre,
    required this.titulo,
    required this.descripcion,
    required this.categoriaCargaId,
    this.tipoVehiculoSugeridoId,
    required this.latitud,
    required this.longitud,
    required this.origenDireccionTexto,
    this.destinoLatitud,
    this.destinoLongitud,
    this.destinoDireccionTexto,
    this.fechaDeseada,
    required this.fechaPublicacion,
    required this.estado,
    this.ofertaAceptadaId,
  });

  factory Publicacion.fromJson(Map<String, dynamic> json) => Publicacion(
        id: json['id'] as int,
        usuarioId: json['usuarioId'] as int,
        usuarioNombre: json['usuarioNombre'] as String,
        titulo: json['titulo'] as String,
        descripcion: json['descripcion'] as String,
        categoriaCargaId: json['categoriaCargaId'] as int,
        tipoVehiculoSugeridoId: json['tipoVehiculoSugeridoId'] as int?,
        latitud: (json['latitud'] as num).toDouble(),
        longitud: (json['longitud'] as num).toDouble(),
        origenDireccionTexto: json['origenDireccionTexto'] as String,
        destinoLatitud: (json['destinoLatitud'] as num?)?.toDouble(),
        destinoLongitud: (json['destinoLongitud'] as num?)?.toDouble(),
        destinoDireccionTexto: json['destinoDireccionTexto'] as String?,
        fechaDeseada:
            json['fechaDeseada'] == null ? null : DateTime.parse(json['fechaDeseada'] as String),
        fechaPublicacion: DateTime.parse(json['fechaPublicacion'] as String),
        estado: json['estado'] as String,
        ofertaAceptadaId: json['ofertaAceptadaId'] as int?,
      );

  final int id;
  final int usuarioId;
  final String usuarioNombre;
  final String titulo;
  final String descripcion;
  final int categoriaCargaId;
  final int? tipoVehiculoSugeridoId;
  final double latitud;
  final double longitud;
  final String origenDireccionTexto;
  final double? destinoLatitud;
  final double? destinoLongitud;
  final String? destinoDireccionTexto;
  final DateTime? fechaDeseada;
  final DateTime fechaPublicacion;
  final String estado;
  final int? ofertaAceptadaId;

  bool esDueno(int usuarioActualId) => usuarioId == usuarioActualId;
}
