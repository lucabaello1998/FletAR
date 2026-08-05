import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../usuarios/usuarios_providers.dart';
import 'data/calificaciones_api.dart';
import 'domain/calificacion.dart';

final calificacionesApiProvider = Provider((ref) => CalificacionesApi(ref.watch(dioProvider)));

final calificacionesDePublicacionProvider =
    AsyncNotifierProvider.family<CalificacionesDePublicacionController, List<Calificacion>, int>(
        CalificacionesDePublicacionController.new);

/// Calificaciones de una Publicación puntual (`arg` = publicacionId), mismo
/// patrón que OfertasDePublicacionController (ver ofertas_providers.dart): la
/// pantalla atrapa el error de `crear` y sólo si tiene éxito se recarga la lista.
class CalificacionesDePublicacionController extends FamilyAsyncNotifier<List<Calificacion>, int> {
  @override
  Future<List<Calificacion>> build(int arg) => ref.watch(calificacionesApiProvider).listar(arg);

  Future<void> recargar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(calificacionesApiProvider).listar(arg));
  }

  Future<void> crear({required int puntaje, String? comentario}) async {
    final nueva =
        await ref.read(calificacionesApiProvider).crear(arg, puntaje: puntaje, comentario: comentario);
    // Sin esto, usuarioPublicoProvider (FutureProvider.family) sigue mostrando
    // la reputación vieja del calificado en cualquier otra pantalla ya
    // montada durante la misma sesión - Riverpod no lo refresca solo porque
    // el valor en el backend cambió.
    ref.invalidate(usuarioPublicoProvider(nueva.usuarioCalificadoId));
    await recargar();
  }
}
