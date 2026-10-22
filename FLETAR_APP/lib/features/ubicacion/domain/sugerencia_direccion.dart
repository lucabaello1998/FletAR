/// Resultado de un geocoder (búsqueda por texto o reversa por coordenadas).
///
/// Se modela lo mínimo que necesita la UI: un texto listo para mostrar
/// (`direccionCorta`) y las coordenadas para mover el mapa. El resto de los
/// componentes de la dirección se guarda por separado para poder armar ese
/// texto sin depender del `display_name` completo del proveedor, que en
/// Argentina suele venir larguísimo ("Italia 2274, Caballito, Comuna 6, Ciudad
/// Autónoma de Buenos Aires, 1424, Argentina").
class SugerenciaDireccion {
  const SugerenciaDireccion({
    required this.latitud,
    required this.longitud,
    required this.etiqueta,
    this.calle,
    this.numero,
    this.barrio,
    this.ciudad,
    this.provincia,
    this.codigoPostal,
  });

  final double latitud;
  final double longitud;

  /// Texto completo devuelto por el geocoder, útil como subtítulo para
  /// desambiguar dos resultados con la misma calle y altura.
  final String etiqueta;

  final String? calle;
  final String? numero;
  final String? barrio;
  final String? ciudad;
  final String? provincia;
  final String? codigoPostal;

  /// "Italia 2274, Caballito" - lo que se guarda en `origenDireccionTexto` y lo
  /// que se muestra en listados y detalle.
  String get direccionCorta {
    final via = calle?.trim();
    final altura = numero?.trim();
    final linea1 = via == null || via.isEmpty
        ? etiqueta.split(',').first.trim()
        : [via, if (altura != null && altura.isNotEmpty) altura].join(' ');

    final localidad = _primeraNoVacia([barrio, ciudad, provincia]);
    if (localidad == null || linea1.toLowerCase().contains(localidad.toLowerCase())) {
      return linea1;
    }
    return '$linea1, $localidad';
  }

  /// Lo que se muestra como subtítulo de la sugerencia: el texto completo del
  /// proveedor, recortado para que no ocupe tres líneas.
  String get detalle => etiqueta;

  static SugerenciaDireccion desdeNominatim(Map<String, dynamic> json) {
    final direccion = (json['address'] as Map<String, dynamic>?) ?? const {};
    final latitud = double.tryParse('${json['lat'] ?? ''}') ?? 0;
    final longitud = double.tryParse('${json['lon'] ?? ''}') ?? 0;

    return SugerenciaDireccion(
      latitud: latitud,
      longitud: longitud,
      etiqueta: (json['display_name'] as String?)?.trim() ?? '',
      calle: _textoNoVacio(direccion['road']) ??
          _textoNoVacio(direccion['pedestrian']) ??
          _textoNoVacio(direccion['footway']) ??
          _textoNoVacio(direccion['path']) ??
          _textoNoVacio(direccion['residential']),
      numero: _textoNoVacio(direccion['house_number']),
      barrio: _textoNoVacio(direccion['suburb']) ??
          _textoNoVacio(direccion['neighbourhood']) ??
          _textoNoVacio(direccion['city_district']),
      ciudad: _textoNoVacio(direccion['city']) ??
          _textoNoVacio(direccion['town']) ??
          _textoNoVacio(direccion['village']) ??
          _textoNoVacio(direccion['municipality']),
      provincia: _textoNoVacio(direccion['state']),
      codigoPostal: _textoNoVacio(direccion['postcode']),
    );
  }

  static String? _textoNoVacio(dynamic valor) {
    if (valor is! String) return null;
    final texto = valor.trim();
    return texto.isEmpty ? null : texto;
  }

  static String? _primeraNoVacia(List<String?> valores) {
    for (final valor in valores) {
      if (valor != null && valor.trim().isNotEmpty) return valor.trim();
    }
    return null;
  }
}
