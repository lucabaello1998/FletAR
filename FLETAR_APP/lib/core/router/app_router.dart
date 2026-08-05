import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_home_screen.dart';
import '../../features/auth/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/publicaciones/domain/publicacion.dart';
import '../../features/publicaciones/presentation/publicacion_create_screen.dart';
import '../../features/publicaciones/presentation/publicacion_detail_screen.dart';
import '../../features/publicaciones/presentation/publicaciones_list_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  final estaLogueado = authState.valueOrNull != null;
  final esAdmin = authState.valueOrNull?.esAdmin ?? false;
  final estaCargando = authState.isLoading;

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (estaCargando) return null;

      final vaAPantallaPublica = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      if (!estaLogueado && !vaAPantallaPublica) return '/login';
      if (estaLogueado && vaAPantallaPublica) return '/';
      // El panel admin se gatea por rol, no por plataforma: la autorización real
      // la hace igual la policy "Admin" del backend, esto es sólo para no dejar
      // la pantalla a mano de un usuario común que adivine la URL.
      if (state.matchedLocation.startsWith('/admin') && !esAdmin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const PublicacionesListScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: '/publicaciones/nueva',
        builder: (context, state) => const PublicacionCreateScreen(),
      ),
      GoRoute(
        path: '/publicaciones/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return PublicacionDetailScreen(publicacionId: id);
        },
      ),
      GoRoute(
        path: '/publicaciones/:id/editar',
        builder: (context, state) {
          final publicacion = state.extra as Publicacion?;
          if (publicacion == null) {
            // Sin la publicación en `extra` (por ej. una recarga del navegador
            // en web, que pierde ese estado en memoria) no hay datos para
            // precargar el formulario - volvemos al detalle en vez de abrir
            // "Editar" a ciegas y arriesgar que se confunda con "Crear".
            final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return PublicacionDetailScreen(publicacionId: id);
          }
          return PublicacionCreateScreen(publicacionAEditar: publicacion);
        },
      ),
      GoRoute(path: '/admin', builder: (context, state) => const AdminHomeScreen()),
    ],
  );
});
