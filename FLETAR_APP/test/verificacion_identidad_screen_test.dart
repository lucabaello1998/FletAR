import 'package:dio/dio.dart';
import 'package:fletar_app/features/usuarios/data/usuarios_api.dart';
import 'package:fletar_app/features/usuarios/domain/verificacion_identidad.dart';
import 'package:fletar_app/features/usuarios/presentation/verificacion_identidad_screen.dart';
import 'package:fletar_app/features/usuarios/usuarios_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Devuelve siempre el mismo estado, sin tocar la red.
class _UsuariosApiFalso extends UsuariosApi {
  _UsuariosApiFalso(this.verificacion) : super(Dio());

  final VerificacionIdentidad? verificacion;

  @override
  Future<VerificacionIdentidad?> obtenerVerificacionIdentidad() async =>
      verificacion;
}

Widget _app(VerificacionIdentidad? verificacion) => ProviderScope(
  overrides: [
    usuariosApiProvider.overrideWithValue(_UsuariosApiFalso(verificacion)),
  ],
  child: const MaterialApp(home: VerificacionIdentidadScreen()),
);

VerificacionIdentidad _verificacion({
  required String estado,
  String? comentario,
}) => VerificacionIdentidad(
  id: 1,
  estado: estado,
  fechaSolicitud: DateTime(2026, 8, 7),
  comentarioAdmin: comentario,
);

void main() {
  testWidgets(
    'sin solicitud previa muestra el formulario para subir los dos lados',
    (tester) async {
      await tester.pumpWidget(_app(null));
      await tester.pumpAndSettle();

      expect(find.text('Frente del documento'), findsOneWidget);
      expect(find.text('Dorso del documento'), findsOneWidget);

      final enviar = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Enviar solicitud'),
      );
      // Sin las dos fotos elegidas no se puede enviar.
      expect(enviar.onPressed, isNull);
    },
  );

  testWidgets('una solicitud en revisión no vuelve a pedir los documentos', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_verificacion(estado: 'Pendiente')));
    await tester.pumpAndSettle();

    expect(find.text('Solicitud en revisión'), findsOneWidget);
    expect(find.text('Frente del documento'), findsNothing);
    expect(find.text('Enviar solicitud'), findsNothing);
  });

  testWidgets(
    'una solicitud rechazada muestra el motivo y deja volver a enviarla',
    (tester) async {
      await tester.pumpWidget(
        _app(
          _verificacion(
            estado: 'Rechazada',
            comentario: 'La foto del dorso está borrosa.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('La solicitud fue rechazada'), findsOneWidget);
      expect(find.text('La foto del dorso está borrosa.'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Volver a enviar'),
        findsOneWidget,
      );
    },
  );

  testWidgets('una identidad aprobada se muestra como verificada', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_verificacion(estado: 'Aprobada')));
    await tester.pumpAndSettle();

    expect(find.text('Identidad verificada'), findsOneWidget);
    expect(find.text('Frente del documento'), findsNothing);
  });
}
