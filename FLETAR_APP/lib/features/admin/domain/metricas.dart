class Metricas {
  const Metricas({
    required this.totalUsuarios,
    required this.totalPublicaciones,
    required this.publicacionesPublicadas,
    required this.publicacionesOfertaAceptada,
    required this.publicacionesEnCurso,
    required this.publicacionesCompletadas,
    required this.publicacionesCanceladas,
    required this.totalOfertas,
    this.promedioCalificacionGlobal,
    required this.reportesPendientes,
  });

  factory Metricas.fromJson(Map<String, dynamic> json) => Metricas(
        totalUsuarios: json['totalUsuarios'] as int,
        totalPublicaciones: json['totalPublicaciones'] as int,
        publicacionesPublicadas: json['publicacionesPublicadas'] as int,
        publicacionesOfertaAceptada: json['publicacionesOfertaAceptada'] as int,
        publicacionesEnCurso: json['publicacionesEnCurso'] as int,
        publicacionesCompletadas: json['publicacionesCompletadas'] as int,
        publicacionesCanceladas: json['publicacionesCanceladas'] as int,
        totalOfertas: json['totalOfertas'] as int,
        promedioCalificacionGlobal: (json['promedioCalificacionGlobal'] as num?)?.toDouble(),
        reportesPendientes: json['reportesPendientes'] as int,
      );

  final int totalUsuarios;
  final int totalPublicaciones;
  final int publicacionesPublicadas;
  final int publicacionesOfertaAceptada;
  final int publicacionesEnCurso;
  final int publicacionesCompletadas;
  final int publicacionesCanceladas;
  final int totalOfertas;
  final double? promedioCalificacionGlobal;
  final int reportesPendientes;
}
