import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../auth/auth_providers.dart';
import 'data/usuarios_api.dart';
import 'domain/usuario_publico.dart';
import 'domain/verificacion_identidad.dart';

final usuariosApiProvider = Provider(
  (ref) => UsuariosApi(ref.watch(dioProvider)),
);

/// Perfil público (nombre + reputación) de un usuario puntual (`arg` = su id).
/// De sólo lectura - no hay acciones que disparen un refresco, así que alcanza
/// con un FutureProvider.family en vez de un AsyncNotifier con controller.
final usuarioPublicoProvider = FutureProvider.family<UsuarioPublico, int>(
  (ref, usuarioId) => ref.watch(usuariosApiProvider).obtenerPorId(usuarioId),
);

/// Verificación de identidad (Fase 9) del usuario logueado. `null` = todavía
/// no la pidió. Es AsyncNotifier (y no FutureProvider) porque subir los
/// documentos cambia el estado y la pantalla tiene que reflejarlo sin recargar
/// todo el perfil.
final verificacionIdentidadProvider =
    AsyncNotifierProvider<
      VerificacionIdentidadController,
      VerificacionIdentidad?
    >(VerificacionIdentidadController.new);

class VerificacionIdentidadController
    extends AsyncNotifier<VerificacionIdentidad?> {
  @override
  Future<VerificacionIdentidad?> build() {
    // Mismo criterio que el resto de los controllers de datos privados: al
    // cambiar de cuenta en el mismo dispositivo no puede quedar visible el
    // estado de la sesión anterior.
    ref.watch(
      authControllerProvider.select((estado) => estado.valueOrNull?.id),
    );
    return ref.watch(usuariosApiProvider).obtenerVerificacionIdentidad();
  }

  Future<void> recargar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(usuariosApiProvider).obtenerVerificacionIdentidad(),
    );
  }

  Future<void> solicitar({required XFile frente, required XFile dorso}) async {
    final verificacion = await ref
        .read(usuariosApiProvider)
        .solicitarVerificacionIdentidad(frente: frente, dorso: dorso);
    state = AsyncData(verificacion);
  }
}
