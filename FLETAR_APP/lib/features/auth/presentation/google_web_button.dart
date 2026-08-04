// `google_sign_in_web/web_only.dart` usa dart:js_interop y no compila fuera
// de un target web (rompe `flutter test`, que corre en la VM). Este import
// condicional hace que solo se incluya la versión real al compilar para web;
// cualquier otro target (VM de tests, mobile, desktop) usa el stub.
export 'google_web_button_stub.dart' if (dart.library.js_interop) 'google_web_button_web.dart';
