import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fletar_app/app.dart';

void main() {
  testWidgets('La app arranca en la pantalla de login sin sesión', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FletarApp()));
    await tester.pumpAndSettle();

    expect(find.text('FletAR'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Ingresar'), findsOneWidget);
  });
}
