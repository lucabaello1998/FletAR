import 'package:dio/dio.dart';

import '../domain/usuario.dart';

class SesionAuth {
  const SesionAuth({required this.usuario, required this.accessToken, required this.refreshToken});

  final Usuario usuario;
  final String accessToken;
  final String refreshToken;
}

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<SesionAuth> registrar({
    required String nombre,
    required String email,
    required String password,
    String? telefono,
  }) async {
    final response = await _dio.post('/auth/register', data: {
      'nombre': nombre,
      'email': email,
      'password': password,
      'telefono': telefono,
    });
    return _sesionDesdeLogin(response.data as Map<String, dynamic>);
  }

  Future<SesionAuth> login({required String email, required String password}) async {
    final response = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    return _sesionDesdeLogin(response.data as Map<String, dynamic>);
  }

  Future<SesionAuth> loginConGoogle(String idToken) async {
    final response = await _dio.post('/auth/google', data: {'idToken': idToken});
    return _sesionDesdeLogin(response.data as Map<String, dynamic>);
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
  }

  SesionAuth _sesionDesdeLogin(Map<String, dynamic> data) => SesionAuth(
        usuario: Usuario.fromJson(data['usuario'] as Map<String, dynamic>),
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
}
