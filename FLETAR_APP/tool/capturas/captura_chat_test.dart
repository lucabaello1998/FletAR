import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fletar_app/core/theme/fletar_theme.dart';
import 'package:fletar_app/features/auth/auth_providers.dart';
import 'package:fletar_app/features/auth/domain/usuario.dart';
import 'package:fletar_app/features/mensajes/domain/mensaje.dart';
import 'package:fletar_app/features/mensajes/mensajes_providers.dart';
import 'package:fletar_app/features/mensajes/presentation/chat_screen.dart';

/// Genera la captura del chat con datos de ejemplo. Se corre una vez:
///   flutter test --update-goldens test/capturas_test.dart
/// y produce docs/capturas/04-chat.png.

final _mensajes = [
  Mensaje(
    id: 1,
    ofertaId: 11,
    remitenteId: 21,
    remitenteNombre: 'Diego Fernández',
    texto: 'Buenas, ¿el sillón es de 3 cuerpos?',
    fechaEnvio: DateTime.utc(2026, 11, 11, 10, 12),
  ),
  Mensaje(
    id: 2,
    ofertaId: 11,
    remitenteId: 1,
    remitenteNombre: 'Luca Baello',
    texto: 'Sí, de 3 cuerpos. Entra por la puerta del edificio.',
    fechaEnvio: DateTime.utc(2026, 11, 11, 10, 15),
  ),
  Mensaje(
    id: 3,
    ofertaId: 11,
    remitenteId: 21,
    remitenteNombre: 'Diego Fernández',
    texto: 'Perfecto. Si te sirve, paso el sábado a las 9 y cargamos.',
    fechaEnvio: DateTime.utc(2026, 11, 11, 10, 18),
  ),
];

class _MensajesFalso extends MensajesDeOfertaController {
  @override
  Future<List<Mensaje>> build(int arg) async => _mensajes;
}

class _AuthFalso extends AuthController {
  @override
  Future<Usuario?> build() async =>
      const Usuario(id: 1, nombre: 'Luca Baello', email: 'luca@fletar.ar', rol: 'usuario');
}

Future<void> cargarFuentes() async {
  final base = 'C:\\src\\flutter\\bin\\cache\\artifacts\\material_fonts';
  final fuentes = {
    'Roboto': ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf'],
  };
  for (final entrada in fuentes.entries) {
    final loader = FontLoader(entrada.key);
    for (final archivo in entrada.value) {
      final bytes = File('$base\\$archivo').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
  final iconos = File('C:\\src\\flutter\\bin\\cache\\artifacts\\material_fonts\\MaterialIcons-Regular.otf');
  if (iconos.existsSync()) {
    final loader = FontLoader('MaterialIcons');
    loader.addFont(Future.value(ByteData.view(iconos.readAsBytesSync().buffer)));
    await loader.load();
  }
}

void main() {
  testWidgets('captura del chat', (tester) async {
    await cargarFuentes();
    tester.view.physicalSize = const Size(500, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mensajesDeOfertaProvider.overrideWith(_MensajesFalso.new),
          authControllerProvider.overrideWith(_AuthFalso.new),
        ],
        child: MaterialApp(
          theme: FletarTheme.light(),
          debugShowCheckedModeBanner: false,
          home: ChatScreen(
            ofertaId: 11,
            tituloPublicacion: 'Mudanza de 2 ambientes',
            otraParteNombre: 'Diego Fernández',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../../docs/capturas/04-chat.png'));
  });
}

