import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fletar_app/features/publicaciones/domain/publicacion.dart';
import 'package:fletar_app/features/publicaciones/presentation/publicaciones_list_screen.dart';
import 'package:fletar_app/features/publicaciones/publicaciones_providers.dart';

class _PublicacionesListControllerFalso extends PublicacionesListController {
  @override
  Future<List<Publicacion>> build() async => [
        Publicacion(
          id: 1,
          usuarioId: 99,
          usuarioNombre: 'Juan Pérez',
          titulo: 'Flete de mudanza 2 ambientes',
          descripcion: 'Necesito mover muebles de un depto a otro',
          categoriaCargaId: 1,
          latitud: -34.6037,
          longitud: -58.3816,
          origenDireccionTexto: 'Av. Corrientes 1234, CABA',
          fechaPublicacion: DateTime.utc(2026, 1, 1),
          estado: EstadoPublicacion.publicada,
        ),
      ];
}

void main() {
  testWidgets('Lista de publicaciones muestra las publicaciones cargadas', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicacionesListProvider.overrideWith(_PublicacionesListControllerFalso.new),
        ],
        child: const MaterialApp(home: PublicacionesListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FletAR'), findsOneWidget);
    expect(find.text('Flete de mudanza 2 ambientes'), findsOneWidget);
    expect(find.text('Av. Corrientes 1234, CABA'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);
  });

  testWidgets('Lista vacía muestra mensaje de estado vacío', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicacionesListProvider.overrideWith(() => _ListaVaciaController()),
        ],
        child: const MaterialApp(home: PublicacionesListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Todavía no hay publicaciones'), findsOneWidget);
  });
}

class _ListaVaciaController extends PublicacionesListController {
  @override
  Future<List<Publicacion>> build() async => [];
}
