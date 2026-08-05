import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fletar_app/features/auth/auth_providers.dart';
import 'package:fletar_app/features/auth/domain/usuario.dart';
import 'package:fletar_app/features/calificaciones/calificaciones_providers.dart';
import 'package:fletar_app/features/calificaciones/domain/calificacion.dart';
import 'package:fletar_app/features/ofertas/domain/oferta.dart';
import 'package:fletar_app/features/ofertas/ofertas_providers.dart';
import 'package:fletar_app/features/publicaciones/domain/publicacion.dart';
import 'package:fletar_app/features/publicaciones/presentation/publicacion_detail_screen.dart';
import 'package:fletar_app/features/publicaciones/publicaciones_providers.dart';
import 'package:fletar_app/features/usuarios/domain/usuario_publico.dart';
import 'package:fletar_app/features/usuarios/usuarios_providers.dart';

final _publicacionCompletada = Publicacion(
  id: 1,
  usuarioId: 1,
  usuarioNombre: 'Ana Dueña',
  titulo: 'Mudanza de oficina',
  descripcion: 'Mover escritorios y sillas',
  categoriaCargaId: 1,
  latitud: -34.6037,
  longitud: -58.3816,
  origenDireccionTexto: 'Av. Corrientes 1234, CABA',
  fechaPublicacion: DateTime.utc(2026, 1, 1),
  estado: EstadoPublicacion.completada,
  ofertaAceptadaId: 10,
);

final _ofertaAceptada = Oferta(
  id: 10,
  publicacionId: 1,
  usuarioId: 2,
  usuarioNombre: 'Beto Fletero',
  monto: 15000,
  fechaOferta: DateTime.utc(2026, 1, 1),
  estado: EstadoOferta.aceptada,
  publicacionTitulo: 'Mudanza de oficina',
  publicacionEstado: EstadoPublicacion.completada,
);

class _PublicacionDetailControllerFalso extends PublicacionDetailController {
  @override
  Future<Publicacion> build(int arg) async => _publicacionCompletada;
}

class _OfertasDePublicacionControllerFalso extends OfertasDePublicacionController {
  @override
  Future<List<Oferta>> build(int arg) async => [_ofertaAceptada];
}

class _AuthControllerFalso extends AuthController {
  @override
  Future<Usuario?> build() async => const Usuario(
        id: 1,
        nombre: 'Ana Dueña',
        email: 'ana@fletar.ar',
        rol: 'usuario',
      );
}

List<Override> _overridesComunes({required List<Calificacion> calificaciones}) => [
      publicacionDetailProvider.overrideWith(_PublicacionDetailControllerFalso.new),
      ofertasDePublicacionProvider.overrideWith(_OfertasDePublicacionControllerFalso.new),
      authControllerProvider.overrideWith(_AuthControllerFalso.new),
      categoriasCargaProvider.overrideWith((ref) async => []),
      tiposVehiculoProvider.overrideWith((ref) async => []),
      calificacionesDePublicacionProvider.overrideWith(() => _CalificacionesFalsas(calificaciones)),
      usuarioPublicoProvider.overrideWith(
        (ref, usuarioId) async => UsuarioPublico(
          id: usuarioId,
          nombre: usuarioId == 1 ? 'Ana Dueña' : 'Beto Fletero',
          cantidadCalificaciones: 0,
        ),
      ),
    ];

class _CalificacionesFalsas extends CalificacionesDePublicacionController {
  _CalificacionesFalsas(this._calificaciones);

  final List<Calificacion> _calificaciones;

  @override
  Future<List<Calificacion>> build(int arg) async => _calificaciones;
}

void main() {
  testWidgets('Publicación Completada sin calificar muestra el formulario para calificar',
      (WidgetTester tester) async {
    // El detalle ahora incluye un mapa de ubicación además del texto de
    // dirección (ver _MapaUbicacionPublicacion), lo que empuja la sección de
    // Calificaciones fuera del viewport por defecto de flutter_test (800x600)
    // - sin agrandar la superficie, el ListView ni siquiera monta esos
    // widgets (lazy dentro del cache extent) y find.text() no los encuentra.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overridesComunes(calificaciones: []),
        child: const MaterialApp(home: PublicacionDetailScreen(publicacionId: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Calificaciones'), findsOneWidget);
    expect(find.text('Calificá a la otra parte'), findsOneWidget);
    expect(find.text('Enviar calificación'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsWidgets);
  });

  testWidgets('Publicación ya calificada por el usuario actual muestra su calificación en vez del formulario',
      (WidgetTester tester) async {
    final miCalificacion = Calificacion(
      id: 5,
      publicacionId: 1,
      usuarioQueCalificaId: 1,
      usuarioCalificadoId: 2,
      puntaje: 4,
      comentario: 'Todo muy bien',
      fechaCalificacion: DateTime.utc(2026, 1, 2),
    );

    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overridesComunes(calificaciones: [miCalificacion]),
        child: const MaterialApp(home: PublicacionDetailScreen(publicacionId: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Ya calificaste esta publicación (tu calificación está en la lista de arriba).'),
      findsOneWidget,
    );
    expect(find.text('Todo muy bien'), findsOneWidget);
    expect(find.text('Calificá a la otra parte'), findsNothing);
  });
}
