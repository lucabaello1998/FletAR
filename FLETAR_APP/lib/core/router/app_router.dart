import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_home_screen.dart';
import '../../features/auth/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/mensajes/domain/chat_route_args.dart';
import '../../features/mensajes/presentation/chat_screen.dart';
import '../../features/publicaciones/domain/publicacion.dart';
import '../../features/publicaciones/presentation/publicacion_create_screen.dart';
import '../../features/publicaciones/presentation/publicacion_detail_screen.dart';
import '../../features/publicaciones/presentation/publicaciones_list_screen.dart';
import '../../features/usuarios/presentation/mi_perfil_screen.dart';
import '../../features/usuarios/presentation/usuario_publico_screen.dart';

/// Puente entre `authControllerProvider` y el `refreshListenable` que espera
/// GoRouter. Antes, `routerProvider` leía el estado de auth con `ref.watch` y
/// construía un `GoRouter` NUEVO en cada rebuild - cualquier cambio de estado
/// del usuario logueado (no sólo login/logout: `actualizarFotoUrl` tras subir
/// una foto de perfil también cuenta) tiraba abajo la instancia vieja y la
/// reemplazaba por una con `initialLocation: '/'`, así que la navegación
/// saltaba al inicio sin ningún error visible. Con este notifier el
/// `GoRouter` se crea una sola vez; `refreshListenable` le avisa que vuelva a
/// evaluar `redirect` sin recrear nada ni perder la ubicación actual.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (previous, next) => notifyListeners());
  }
}

final _routerRefreshProvider = Provider<_RouterRefreshNotifier>((ref) => _RouterRefreshNotifier(ref));

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(_routerRefreshProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final estaLogueado = authState.valueOrNull != null;
      final esAdmin = authState.valueOrNull?.esAdmin ?? false;
      final estaCargando = authState.isLoading;

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
      GoRoute(path: '/perfil', builder: (context, state) => const MiPerfilScreen()),
      GoRoute(
        path: '/usuarios/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return UsuarioPublicoScreen(usuarioId: id);
        },
      ),
      GoRoute(
        path: '/ofertas/:id/chat',
        builder: (context, state) {
          final ofertaId = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          final args = state.extra as ChatRouteArgs?;
          return ChatScreen(
            ofertaId: ofertaId,
            // Sin `extra` (recarga del navegador en web, o quien navegue sin
            // pasarlo) el chat sigue funcionando igual - sólo con un título
            // más genérico, a diferencia de "editar publicación" que sin sus
            // datos no puede mostrar nada.
            tituloPublicacion: args?.tituloPublicacion ?? 'Chat',
            otraParteNombre: args?.otraParteNombre,
          );
        },
      ),
    ],
  );
});
