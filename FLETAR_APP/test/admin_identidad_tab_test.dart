import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fletar_app/features/admin/admin_providers.dart';
import 'package:fletar_app/features/admin/data/admin_api.dart';
import 'package:fletar_app/features/admin/domain/usuario_admin.dart';
import 'package:fletar_app/features/admin/domain/verificacion_identidad_admin.dart';
import 'package:fletar_app/features/admin/presentation/admin_home_screen.dart';
import 'package:fletar_app/features/reportes/domain/reporte.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Panel admin sin backend: reportes vacíos y una sola verificación.
class _AdminApiFalso extends AdminApi {
  _AdminApiFalso(this.verificaciones) : super(Dio());

  final List<VerificacionIdentidadAdmin> verificaciones;
  bool aprobada = false;
  String? comentarioDeRechazo;

  /// PNG de 1x1 transparente: alcanza para que `Image.memory` decodifique algo
  /// real en el test del visor de documentos.
  static final Uint8List pngMinimo = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );

  @override
  Future<Uint8List> descargarDocumentoVerificacion(
    int verificacionId,
    String lado,
  ) async => pngMinimo;

  @override
  Future<List<Reporte>> listarReportes({String? estado}) async => [];

  @override
  Future<List<VerificacionIdentidadAdmin>> listarVerificacionesIdentidad({
    String? estado,
  }) async => estado == null
      ? verificaciones
      : verificaciones.where((v) => v.estado == estado).toList();

  @override
  Future<void> aprobarVerificacion(int verificacionId) async {
    aprobada = true;
  }

  @override
  Future<void> rechazarVerificacion(
    int verificacionId, {
    String? comentario,
  }) async {
    comentarioDeRechazo = comentario ?? '(sin comentario)';
  }

  @override
  Future<List<UsuarioAdmin>> listarUsuarios({String? busqueda}) async => [];
}

VerificacionIdentidadAdmin _pendiente() => VerificacionIdentidadAdmin(
  id: 7,
  usuarioId: 3,
  usuarioNombre: 'Ana Fixture',
  usuarioEmail: 'ana@example.com',
  estado: 'Pendiente',
  fechaSolicitud: DateTime(2026, 8, 7),
);

Future<void> _abrirTabIdentidad(WidgetTester tester, _AdminApiFalso api) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [adminApiProvider.overrideWithValue(api)],
      child: const MaterialApp(home: AdminHomeScreen()),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Identidad'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la pestaña Identidad lista las solicitudes pendientes', (
    tester,
  ) async {
    await _abrirTabIdentidad(tester, _AdminApiFalso([_pendiente()]));

    expect(find.text('Ana Fixture'), findsOneWidget);
    expect(find.text('ana@example.com'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.text('Aprobar'), findsOneWidget);
    expect(find.text('Rechazar'), findsOneWidget);
  });

  testWidgets('ver documentos abre el visor con el frente y el dorso', (
    tester,
  ) async {
    await _abrirTabIdentidad(tester, _AdminApiFalso([_pendiente()]));

    await tester.tap(find.text('Ver documentos'));
    await tester.pumpAndSettle();

    expect(find.text('Documento de Ana Fixture'), findsOneWidget);
    expect(find.text('Frente'), findsOneWidget);
    expect(find.text('Dorso'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
  });

  testWidgets('aprobar pide confirmación y llama al backend', (tester) async {
    final api = _AdminApiFalso([_pendiente()]);
    await _abrirTabIdentidad(tester, api);

    await tester.tap(find.text('Aprobar'));
    await tester.pumpAndSettle();

    expect(find.text('¿Aprobar esta identidad?'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Aprobar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.aprobada, isTrue);
  });

  testWidgets('rechazar manda el motivo escrito y uno vacío viaja como null', (
    tester,
  ) async {
    final api = _AdminApiFalso([_pendiente()]);
    await _abrirTabIdentidad(tester, api);

    // Primer intento: sin motivo. El comentario es opcional.
    await tester.tap(find.text('Rechazar'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Rechazar'),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.comentarioDeRechazo, '(sin comentario)');

    // Segundo intento: con motivo, aparece en el campo del diálogo.
    await tester.tap(find.text('Rechazar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'El dorso está borroso');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Rechazar'),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.comentarioDeRechazo, 'El dorso está borroso');
  });
}
