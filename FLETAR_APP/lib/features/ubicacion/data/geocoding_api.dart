import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sugerencia_direccion.dart';

/// Geocoder de OpenStreetMap (Nominatim): sin API key, con límites de uso
/// públicos (máximo ~1 request por segundo y User-Agent identificable). Alcanza
/// para autocompletar direcciones de un formulario; si algún día hace falta
/// volumen, hay que pasar a un proveedor con key (Google Places, Mapbox).
const _nominatimUrl = 'https://nominatim.openstreetmap.org';

/// Mismo contacto que figura en la política de privacidad: Nominatim exige un
/// User-Agent que identifique la aplicación y permita contactar al responsable.
const _userAgent = 'FletAR/1.0 (https://github.com/lucabaello1998/FletAR)';

/// Mínimo de caracteres para consultar: con menos, Nominatim devuelve ruido
/// (calles de todo el país con el mismo nombre).
const minimoCaracteresBusqueda = 4;

/// El geocoder no respondió (sin red, timeout, 5xx). Se distingue de "no hay
/// resultados": decirle "esa dirección no existe" a alguien que está sin
/// conexión es desinformar y hace que reescriba la dirección al pedo.
class GeocodingNoDisponible implements Exception {
  const GeocodingNoDisponible();

  @override
  String toString() => 'No se pudo consultar el buscador de direcciones.';
}

class GeocodingApi {
  GeocodingApi({Dio? dio}) : _dio = dio ?? _crearDio();

  final Dio _dio;

  /// Caché en memoria de búsquedas y reversas: tipear y borrar sobre la misma
  /// dirección, o tocar dos veces el mismo punto del mapa, no vuelve a pegarle
  /// al geocoder.
  final Map<String, List<SugerenciaDireccion>> _cacheBusquedas = {};
  final Map<String, SugerenciaDireccion?> _cacheReversas = {};

  /// Nominatim pide no superar 1 request/segundo. La UI ya debouncea el
  /// tipeo, pero dos campos (origen y destino) pueden disparar casi juntos:
  /// esta espera serializa las llamadas reales.
  DateTime _ultimaLlamada = DateTime.fromMillisecondsSinceEpoch(0);
  static const _intervaloMinimo = Duration(milliseconds: 1100);

  static Dio _crearDio() {
    return Dio(BaseOptions(
      baseUrl: _nominatimUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {
        'Accept': 'application/json',
        'Accept-Language': 'es',
        // En web el navegador prohíbe setear User-Agent desde JS; mandarlo
        // igual hace que el adapter lo ignore (o tire en algunos navegadores),
        // así que sólo se envía en mobile/desktop.
        if (!kIsWeb) 'User-Agent': _userAgent,
      },
      // Sin esto, Dio tira DioException ante cualquier 4xx/5xx y la UI tendría
      // que distinguir "no hay resultados" de "falló el geocoder".
      validateStatus: (status) => status != null && status < 500,
    ));
  }

  /// Devuelve hasta [limite] direcciones de Argentina para [texto]. Lista vacía
  /// si no hay resultados o si el texto es muy corto.
  ///
  /// Tira [GeocodingNoDisponible] si el geocoder no respondió: el formulario
  /// tiene que seguir funcionando (el texto es libre), pero la UI necesita
  /// distinguir "no existe" de "no hay conexión".
  Future<List<SugerenciaDireccion>> buscar(String texto, {int limite = 5}) async {
    final consulta = texto.trim();
    if (consulta.length < minimoCaracteresBusqueda) return const [];

    final clave = consulta.toLowerCase();
    final cacheada = _cacheBusquedas[clave];
    if (cacheada != null) return cacheada;

    await _respetarIntervalo();

    try {
      final response = await _dio.get<List<dynamic>>(
        '/search',
        queryParameters: {
          'q': consulta,
          'format': 'jsonv2',
          'addressdetails': 1,
          'limit': limite,
          'countrycodes': 'ar',
          'accept-language': 'es',
          'dedupe': 1,
        },
      );

      final resultados = (response.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SugerenciaDireccion.desdeNominatim)
          .where((s) => s.latitud != 0 && s.longitud != 0 && s.direccionCorta.isNotEmpty)
          .toList();

      _cacheBusquedas[clave] = resultados;
      return resultados;
    } catch (_) {
      // Sin red, timeout o geocoder caído: el campo queda como texto libre,
      // pero la UI avisa que fue un problema de conexión, no que la dirección
      // no exista.
      throw const GeocodingNoDisponible();
    }
  }

  /// Dirección más cercana a un punto del mapa (lo que se muestra al tocar el
  /// mapa). `null` si no hay resultado o si falló la consulta.
  Future<SugerenciaDireccion?> reversa(double latitud, double longitud) async {
    final clave = '${latitud.toStringAsFixed(5)},${longitud.toStringAsFixed(5)}';
    if (_cacheReversas.containsKey(clave)) return _cacheReversas[clave];

    await _respetarIntervalo();

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/reverse',
        queryParameters: {
          'lat': latitud,
          'lon': longitud,
          'format': 'jsonv2',
          'addressdetails': 1,
          'zoom': 18,
          'accept-language': 'es',
        },
      );

      final data = response.data;
      if (data == null || data['error'] != null) {
        _cacheReversas[clave] = null;
        return null;
      }

      final sugerencia = SugerenciaDireccion.desdeNominatim(data);
      final resultado = sugerencia.direccionCorta.isEmpty ? null : sugerencia;
      _cacheReversas[clave] = resultado;
      return resultado;
    } catch (_) {
      return null;
    }
  }

  /// Cola de a una: dos llamadas simultáneas (origen y destino) se serializan
  /// en vez de salir juntas y comerse el rate limit.
  Future<void> _cola = Future<void>.value();

  Future<void> _respetarIntervalo() {
    final turno = _cola.then((_) async {
      final desdeLaUltima = DateTime.now().difference(_ultimaLlamada);
      if (desdeLaUltima < _intervaloMinimo) {
        await Future<void>.delayed(_intervaloMinimo - desdeLaUltima);
      }
      _ultimaLlamada = DateTime.now();
    });
    _cola = turno;
    return turno;
  }
}

final geocodingApiProvider = Provider<GeocodingApi>((ref) => GeocodingApi());
