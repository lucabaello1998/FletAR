/// Perfil público de un usuario - refleja `UsuarioPublicoResponse` del backend
/// (sólo lo que cualquiera puede ver de otra persona: nombre, foto y
/// reputación agregada). Nunca agregar acá datos privados como email/rol.
class UsuarioPublico {
  const UsuarioPublico({
    required this.id,
    required this.nombre,
    this.fotoUrl,
    this.promedioCalificacion,
    required this.cantidadCalificaciones,
  });

  factory UsuarioPublico.fromJson(Map<String, dynamic> json) => UsuarioPublico(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        fotoUrl: json['fotoUrl'] as String?,
        promedioCalificacion: (json['promedioCalificacion'] as num?)?.toDouble(),
        cantidadCalificaciones: json['cantidadCalificaciones'] as int,
      );

  final int id;
  final String nombre;
  final String? fotoUrl;
  final double? promedioCalificacion;
  final int cantidadCalificaciones;

  bool get tieneCalificaciones => cantidadCalificaciones > 0 && promedioCalificacion != null;
}
