import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'data/usuarios_api.dart';
import 'domain/usuario_publico.dart';

final usuariosApiProvider = Provider((ref) => UsuariosApi(ref.watch(dioProvider)));

/// Perfil público (nombre + reputación) de un usuario puntual (`arg` = su id).
/// De sólo lectura - no hay acciones que disparen un refresco, así que alcanza
/// con un FutureProvider.family en vez de un AsyncNotifier con controller.
final usuarioPublicoProvider = FutureProvider.family<UsuarioPublico, int>(
    (ref, usuarioId) => ref.watch(usuariosApiProvider).obtenerPorId(usuarioId));
