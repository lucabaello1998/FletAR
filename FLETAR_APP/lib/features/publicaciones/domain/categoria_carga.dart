class CategoriaCarga {
  const CategoriaCarga({required this.id, required this.nombre, required this.activa});

  factory CategoriaCarga.fromJson(Map<String, dynamic> json) => CategoriaCarga(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        activa: json['activa'] as bool,
      );

  final int id;
  final String nombre;
  final bool activa;
}
