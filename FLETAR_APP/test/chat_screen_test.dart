import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fletar_app/features/auth/auth_providers.dart';
import 'package:fletar_app/features/auth/domain/usuario.dart';
import 'package:fletar_app/features/mensajes/domain/mensaje.dart';
import 'package:fletar_app/features/mensajes/mensajes_providers.dart';
import 'package:fletar_app/features/mensajes/presentation/chat_screen.dart';

final _mensajeInicial = Mensaje(
  id: 1,
  ofertaId: 5,
  remitenteId: 2,
  remitenteNombre: 'Beto Fletero',
  texto: '¿Seguís disponible para el flete?',
  fechaEnvio: DateTime.utc(2026, 1, 1, 10, 0),
);

/// Controller falso: evita tocar la conexión real de SignalR/REST (mismo
/// patrón que _OfertasDePublicacionControllerFalso en
/// publicacion_detail_calificaciones_test.dart) - sólo se prueba que la
/// pantalla muestra el historial y que "enviar" se dispara con el texto
/// correcto.
class _MensajesDeOfertaControllerFalso extends MensajesDeOfertaController {
  static String? ultimoTextoEnviado;

  @override
  Future<List<Mensaje>> build(int arg) async => [_mensajeInicial];

  @override
  Future<void> enviar(String texto) async {
    ultimoTextoEnviado = texto;
    final actuales = state.valueOrNull ?? const [];
    state = AsyncData([
      ...actuales,
      Mensaje(
        id: actuales.length + 2,
        ofertaId: arg,
        remitenteId: 1,
        remitenteNombre: 'Ana Dueña',
        texto: texto,
        fechaEnvio: DateTime.utc(2026, 1, 1, 10, 1),
      ),
    ]);
  }
}

class _AuthControllerFalso extends AuthController {
  @override
  Future<Usuario?> build() async =>
      const Usuario(id: 1, nombre: 'Ana Dueña', email: 'ana@fletar.ar', rol: 'usuario');
}

void main() {
  testWidgets('El chat muestra el historial y el título de contexto', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mensajesDeOfertaProvider.overrideWith(_MensajesDeOfertaControllerFalso.new),
          authControllerProvider.overrideWith(_AuthControllerFalso.new),
        ],
        child: const MaterialApp(
          home: ChatScreen(
            ofertaId: 5,
            tituloPublicacion: 'Mudanza de oficina',
            otraParteNombre: 'Beto Fletero',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chat con Beto Fletero'), findsOneWidget);
    expect(find.text('Mudanza de oficina'), findsOneWidget);
    expect(find.text('¿Seguís disponible para el flete?'), findsOneWidget);
  });

  testWidgets('Mandar un mensaje lo agrega a la conversación y limpia el campo',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mensajesDeOfertaProvider.overrideWith(_MensajesDeOfertaControllerFalso.new),
          authControllerProvider.overrideWith(_AuthControllerFalso.new),
        ],
        child: const MaterialApp(
          home: ChatScreen(ofertaId: 5, tituloPublicacion: 'Mudanza de oficina'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Sí, dale, ¿cuándo te viene bien?');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(_MensajesDeOfertaControllerFalso.ultimoTextoEnviado, 'Sí, dale, ¿cuándo te viene bien?');
    expect(find.text('Sí, dale, ¿cuándo te viene bien?'), findsOneWidget);

    final campoTexto = tester.widget<TextField>(find.byType(TextField));
    expect(campoTexto.controller?.text, isEmpty);
  });
}
