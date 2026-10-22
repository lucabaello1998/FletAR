import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fletar_app/features/ubicacion/data/geocoding_api.dart';
import 'package:fletar_app/features/ubicacion/domain/sugerencia_direccion.dart';
import 'package:fletar_app/features/ubicacion/presentation/direccion_autocomplete_field.dart';

/// Respuestas de Nominatim reales (recortadas) para no inventar el formato:
/// `GET /search?q=italia+2274` y `GET /reverse?lat=-34.610981&lon=-58.433791`.
const _respuestaBusqueda = <String, dynamic>{
  'place_id': 123456,
  'lat': '-34.6109810',
  'lon': '-58.4337910',
  'display_name':
      'Italia 2274, Caballito, Comuna 6, Ciudad Autónoma de Buenos Aires, 1424, Argentina',
  'address': {
    'road': 'Italia',
    'house_number': '2274',
    'suburb': 'Caballito',
    'city_district': 'Comuna 6',
    'city': 'Ciudad Autónoma de Buenos Aires',
    'state': 'Ciudad Autónoma de Buenos Aires',
    'postcode': '1424',
    'country': 'Argentina',
  },
};

const _respuestaReversa = <String, dynamic>{
  'lat': '-34.610981',
  'lon': '-58.433791',
  'display_name': 'Otamendi 500, Caballito, Comuna 6, Ciudad Autónoma de Buenos Aires, 1424, Argentina',
  'address': {
    'road': 'Otamendi',
    'house_number': '500',
    'suburb': 'Caballito',
    'city': 'Ciudad Autónoma de Buenos Aires',
    'state': 'Ciudad Autónoma de Buenos Aires',
  },
};

class _GeocodingFalso extends GeocodingApi {
  _GeocodingFalso(this.resultados);

  final List<SugerenciaDireccion> resultados;
  int llamadas = 0;

  @override
  Future<List<SugerenciaDireccion>> buscar(String texto, {int limite = 5}) async {
    llamadas++;
    return resultados;
  }
}

void main() {
  group('SugerenciaDireccion', () {
    test('arma "calle y altura, barrio" desde una búsqueda de Nominatim', () {
      final sugerencia = SugerenciaDireccion.desdeNominatim(_respuestaBusqueda);

      expect(sugerencia.latitud, closeTo(-34.610981, 0.000001));
      expect(sugerencia.longitud, closeTo(-58.433791, 0.000001));
      expect(sugerencia.calle, 'Italia');
      expect(sugerencia.numero, '2274');
      expect(sugerencia.direccionCorta, 'Italia 2274, Caballito');
      expect(sugerencia.detalle, contains('Caballito'));
    });

    test('usa la ciudad cuando el resultado no trae barrio', () {
      final sugerencia = SugerenciaDireccion.desdeNominatim({
        'lat': '-31.420',
        'lon': '-64.190',
        'display_name': 'Av. Colón 100, Córdoba, Argentina',
        'address': {'road': 'Avenida Colón', 'house_number': '100', 'city': 'Córdoba'},
      });

      expect(sugerencia.direccionCorta, 'Avenida Colón 100, Córdoba');
    });

    test('sin calle cae al primer tramo del display_name', () {
      final sugerencia = SugerenciaDireccion.desdeNominatim({
        'lat': '-34.6',
        'lon': '-58.4',
        'display_name': 'Plaza Italia, Buenos Aires, Argentina',
        'address': {'suburb': 'Recoleta'},
      });

      expect(sugerencia.direccionCorta, 'Plaza Italia, Recoleta');
    });

    test('no repite la localidad si ya está en el nombre de la calle', () {
      final sugerencia = SugerenciaDireccion.desdeNominatim({
        'lat': '-34.6',
        'lon': '-58.4',
        'display_name': 'Caballito 100, Caballito',
        'address': {'road': 'Caballito', 'house_number': '100', 'suburb': 'Caballito'},
      });

      expect(sugerencia.direccionCorta, 'Caballito 100');
    });

    test('parsea la respuesta reversa del punto tocado en el mapa', () {
      final sugerencia = SugerenciaDireccion.desdeNominatim(_respuestaReversa);

      expect(sugerencia.direccionCorta, 'Otamendi 500, Caballito');
    });

    test('una respuesta sin coordenadas queda en 0 para descartarla', () {
      final sugerencia = SugerenciaDireccion.desdeNominatim({'display_name': 'Nada'});

      expect(sugerencia.latitud, 0);
      expect(sugerencia.longitud, 0);
    });
  });

  group('DireccionAutocompleteField', () {
    testWidgets('elegir una sugerencia completa el campo y devuelve las coordenadas', (tester) async {
      final controller = TextEditingController();
      final api = _GeocodingFalso([
        const SugerenciaDireccion(
          latitud: -34.610981,
          longitud: -58.433791,
          etiqueta: 'Italia 2274, Caballito, Ciudad Autónoma de Buenos Aires, Argentina',
          calle: 'Italia',
          numero: '2274',
          barrio: 'Caballito',
        ),
      ]);
      SugerenciaDireccion? elegida;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: DireccionAutocompleteField(
                  controller: controller,
                  label: 'Dirección de origen',
                  api: api,
                  onSeleccionada: (sugerencia) => elegida = sugerencia,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'italia 2274');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(api.llamadas, 1);
      expect(find.text('Italia 2274, Caballito'), findsOneWidget);

      await tester.tap(find.text('Italia 2274, Caballito'));
      await tester.pumpAndSettle();

      expect(controller.text, 'Italia 2274, Caballito');
      expect(elegida?.latitud, -34.610981);
      expect(find.byType(ListTile), findsNothing); // la lista de sugerencias se cierra
    });

    testWidgets('con menos de 4 caracteres no consulta el geocoder', (tester) async {
      final controller = TextEditingController();
      final api = _GeocodingFalso(const []);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: DireccionAutocompleteField(
                  controller: controller,
                  label: 'Dirección',
                  api: api,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'ita');
      await tester.pump(const Duration(seconds: 1));

      expect(api.llamadas, 0);
    });

    testWidgets('muestra un aviso cuando no hay resultados', (tester) async {
      final controller = TextEditingController();
      final api = _GeocodingFalso(const []);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: DireccionAutocompleteField(
                  controller: controller,
                  label: 'Dirección',
                  api: api,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'calle que no existe 9999');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(find.textContaining('No encontramos esa dirección'), findsOneWidget);
    });
  });
}
