import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'package:fletar_app/features/publicaciones/domain/categoria_carga.dart';
import 'package:fletar_app/features/publicaciones/domain/tipo_vehiculo.dart';
import 'package:fletar_app/features/publicaciones/presentation/publicacion_create_screen.dart';
import 'package:fletar_app/features/publicaciones/publicaciones_providers.dart';
import 'package:fletar_app/features/ubicacion/data/geocoding_api.dart';
import 'package:fletar_app/features/ubicacion/domain/sugerencia_direccion.dart';

const _sugerenciaOrigen = SugerenciaDireccion(
  latitud: -34.610981,
  longitud: -58.433791,
  etiqueta: 'Italia 2274, Caballito, Ciudad Autónoma de Buenos Aires, Argentina',
  calle: 'Italia',
  numero: '2274',
  barrio: 'Caballito',
);

const _reversaDelMapa = SugerenciaDireccion(
  latitud: -34.620000,
  longitud: -58.440000,
  etiqueta: 'Otamendi 500, Caballito',
  calle: 'Otamendi',
  numero: '500',
  barrio: 'Caballito',
);

class _GeocodingFalso extends GeocodingApi {
  _GeocodingFalso({this.fallaBusqueda = false});

  final bool fallaBusqueda;
  int reversas = 0;

  @override
  Future<List<SugerenciaDireccion>> buscar(String texto, {int limite = 5}) async {
    if (fallaBusqueda) throw const GeocodingNoDisponible();
    return const [_sugerenciaOrigen];
  }

  @override
  Future<SugerenciaDireccion?> reversa(double latitud, double longitud) async {
    reversas++;
    return _reversaDelMapa;
  }
}

Widget _pantalla(GeocodingApi geocoding) {
  return ProviderScope(
    overrides: [
      geocodingApiProvider.overrideWithValue(geocoding),
      categoriasCargaProvider.overrideWith(
        (ref) async => const [CategoriaCarga(id: 1, nombre: 'Mudanza', activa: true)],
      ),
      tiposVehiculoProvider.overrideWith(
        (ref) async => const [TipoVehiculo(id: 1, nombre: 'Utilitario', activo: true)],
      ),
    ],
    child: const MaterialApp(home: PublicacionCreateScreen()),
  );
}

/// Pantalla alta: el formulario completo (dirección + dos mapas + botón) no
/// entra en los 800x600 por defecto de los tests y los taps quedarían fuera.
Future<void> _montar(WidgetTester tester, GeocodingApi geocoding) async {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_pantalla(geocoding));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('elegir una sugerencia mueve el pin del mapa de origen', (tester) async {
    await _montar(tester, _GeocodingFalso());

    await tester.enterText(find.byType(TextFormField).at(2), 'italia 2274');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Italia 2274, Caballito'));
    await tester.pumpAndSettle();

    // El texto bajo el mapa muestra las coordenadas del pin: son las de la
    // sugerencia elegida, no las del centro del mapa.
    expect(find.text('Lat: -34.610981 · Lng: -58.433791'), findsOneWidget);
    expect(find.byType(MarkerLayer), findsWidgets);
  });

  testWidgets('tocar el mapa completa la dirección con la geocodificación reversa', (tester) async {
    final geocoding = _GeocodingFalso();
    await _montar(tester, geocoding);

    final mapa = find.byType(FlutterMap).first;
    await tester.tapAt(tester.getCenter(mapa));
    // flutter_map retrasa el tap simple ~250 ms para distinguirlo del doble
    // tap de zoom: pumpAndSettle no avanza timers que no programan frames.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(geocoding.reversas, 1);
    final campoOrigen = tester.widget<TextFormField>(find.byType(TextFormField).at(2));
    expect(campoOrigen.controller?.text, 'Otamendi 500, Caballito');
    expect(find.textContaining('Lat: -34.6'), findsOneWidget);
  });

  testWidgets('si el buscador falla muestra un aviso de conexión, no "no existe"', (tester) async {
    await _montar(tester, _GeocodingFalso(fallaBusqueda: true));

    await tester.enterText(find.byType(TextFormField).at(2), 'italia 2274');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.textContaining('No pudimos buscar direcciones'), findsOneWidget);
    expect(find.textContaining('No encontramos esa dirección'), findsNothing);
  });

  testWidgets('sin categoría no intenta publicar (no explota con el null check)', (tester) async {
    // Se apunta a que el formulario inválido no rompa: al tocar Publicar con
    // todo vacío tiene que mostrar los errores de validación, no un TypeError.
    await _montar(tester, _GeocodingFalso());

    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresá un título'), findsOneWidget);
    expect(find.text('Elegí una categoría'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('la coordenada del pin se redondea a 6 decimales', () {
    const punto = ll.LatLng(-34.61098149, -58.43379149);
    expect(punto.latitude.toStringAsFixed(6), '-34.610981');
  });
}
