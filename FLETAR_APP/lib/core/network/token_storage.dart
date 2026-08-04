import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda el access/refresh token. Nunca en `SharedPreferences` (texto plano) -
/// `flutter_secure_storage` usa Keychain/Keystore/DPAPI según la plataforma.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _claveAccess = 'fletar.access_token';
  static const _claveRefresh = 'fletar.refresh_token';

  Future<String?> leerAccessToken() => _storage.read(key: _claveAccess);
  Future<String?> leerRefreshToken() => _storage.read(key: _claveRefresh);

  Future<void> guardar({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _claveAccess, value: accessToken);
    await _storage.write(key: _claveRefresh, value: refreshToken);
  }

  Future<void> limpiar() async {
    await _storage.delete(key: _claveAccess);
    await _storage.delete(key: _claveRefresh);
  }
}
