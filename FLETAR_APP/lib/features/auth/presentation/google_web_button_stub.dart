import 'package:flutter/widgets.dart';

/// Stub para plataformas que no son web - nunca debería llamarse en la
/// práctica porque login_screen.dart lo gatea con `kIsWeb`, pero tiene que
/// existir para que el import condicional de google_web_button.dart resuelva.
Widget renderGoogleButton() => const SizedBox.shrink();
