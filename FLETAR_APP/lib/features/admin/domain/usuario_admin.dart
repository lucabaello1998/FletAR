class UsuarioAdmin {
  const UsuarioAdmin({
    required this.id,
    required this.nombre,
    required this.email,
    this.telefono,
    required this.rol,
    required this.activo,
    required this.fechaRegistro,
    this.promedioCalificacion,
    required this.cantidadCalificaciones,
  });

  factory UsuarioAdmin.fromJson(Map<String, dynamic> json) => UsuarioAdmin(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        email: json['email'] as String,
        telefono: json['telefono'] as String?,
        rol: json['rol'] as String,
        activo: json['activo'] as bool,
        fechaRegistro: DateTime.parse(json['fechaRegistro'] as String),
        promedioCalificacion: (json['promedioCalificacion'] as num?)?.toDouble(),
        cantidadCalificaciones: json['cantidadCalificaciones'] as int,
      );

  final int id;
  final String nombre;
  final String email;
  final String? telefono;
  final String rol;
  final bool activo;
  final DateTime fechaRegistro;
  final double? promedioCalificacion;
  final int cantidadCalificaciones;
}
