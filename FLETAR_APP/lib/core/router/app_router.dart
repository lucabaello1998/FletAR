import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_providers.dart';
import '../../features/auth/presentation/home_placeholder_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  final estaLogueado = authState.valueOrNull != null;
  final estaCargando = authState.isLoading;

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (estaCargando) return null;

      final vaAPantallaPublica = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      if (!estaLogueado && !vaAPantallaPublica) return '/login';
      if (estaLogueado && vaAPantallaPublica) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomePlaceholderScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
    ],
  );
});
