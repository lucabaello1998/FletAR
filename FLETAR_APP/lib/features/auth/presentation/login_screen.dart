import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/errores.dart';
import '../auth_providers.dart';
import 'google_web_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

/// En desktop (Windows/Mac/Linux) no hay implementación de plataforma para
/// google_sign_in, y el placeholder de google_sign_in_platform_interface
/// tira UnimplementedError en vez de devolver false - hay que atajarlo acá.
bool _soportaGoogleSignInNativo() {
  try {
    return GoogleSignIn.instance.supportsAuthenticate();
  } on UnimplementedError {
    return false;
  }
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (previo, actual) {
      if (actual.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeDeError(actual.error!))),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SvgPicture.asset('assets/branding/logo_v0.svg', height: 96),
                    const SizedBox(height: 8),
                    Text('FletAR', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v == null || v.isEmpty) ? 'Ingresá tu email' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Contraseña'),
                      obscureText: true,
                      validator: (v) => (v == null || v.isEmpty) ? 'Ingresá tu contraseña' : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: authState.isLoading ? null : _enviar,
                      child: authState.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Ingresar'),
                    ),
                    if (googleClientId.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Row(children: [
                        Expanded(child: Divider()),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('o')),
                        Expanded(child: Divider()),
                      ]),
                      const SizedBox(height: 16),
                      if (kIsWeb)
                        Center(child: renderGoogleButton())
                      else if (_soportaGoogleSignInNativo())
                        OutlinedButton(
                          onPressed: authState.isLoading
                              ? null
                              : () => ref.read(authControllerProvider.notifier).iniciarConGoogle(),
                          child: const Text('Continuar con Google'),
                        ),
                    ],
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/register'),
                      child: const Text('¿No tenés cuenta? Registrate'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
