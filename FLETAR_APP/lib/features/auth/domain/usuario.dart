class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.email,
    required this.rol,
    this.telefono,
    this.fotoUrl,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        email: json['email'] as String,
        rol: json['rol'] as String,
        telefono: json['telefono'] as String?,
        fotoUrl: json['fotoUrl'] as String?,
      );

  final int id;
  final String nombre;
  final String email;
  final String rol;
  final String? telefono;
  final String? fotoUrl;

  bool get esAdmin => rol == 'admin';
}
