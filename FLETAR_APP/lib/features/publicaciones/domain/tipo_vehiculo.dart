class TipoVehiculo {
  const TipoVehiculo({
    required this.id,
    required this.nombre,
    this.capacidadKg,
    this.volumenM3,
    required this.activo,
  });

  factory TipoVehiculo.fromJson(Map<String, dynamic> json) => TipoVehiculo(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        capacidadKg: (json['capacidadKg'] as num?)?.toDouble(),
        volumenM3: (json['volumenM3'] as num?)?.toDouble(),
        activo: json['activo'] as bool,
      );

  final int id;
  final String nombre;
  final double? capacidadKg;
  final double? volumenM3;
  final bool activo;
}
