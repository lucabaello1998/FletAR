import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'data/ofertas_api.dart';
import 'domain/oferta.dart';

final ofertasApiProvider = Provider((ref) => OfertasApi(ref.watch(dioProvider)));

final ofertasDePublicacionProvider =
    AsyncNotifierProvider.family<OfertasDePublicacionController, List<Oferta>, int>(
        OfertasDePublicacionController.new);

/// Ofertas de una Publicación puntual (`arg` = publicacionId). Las acciones
/// de crear/aceptar/retirar dejan que la excepción de Dio se propague - la
/// pantalla la atrapa y muestra el mensaje con `mensajeDeError` (ver
/// publicacion_detail_screen.dart), y sólo si tienen éxito se recarga la lista.
class OfertasDePublicacionController extends FamilyAsyncNotifier<List<Oferta>, int> {
  @override
  Future<List<Oferta>> build(int arg) => ref.watch(ofertasApiProvider).listar(arg);

  Future<void> recargar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(ofertasApiProvider).listar(arg));
  }

  Future<void> crear({required double monto, String? mensaje}) async {
    await ref.read(ofertasApiProvider).crear(arg, monto: monto, mensaje: mensaje);
    await recargar();
  }

  Future<void> aceptar(int ofertaId) async {
    await ref.read(ofertasApiProvider).aceptar(arg, ofertaId);
    await recargar();
  }

  Future<void> retirar(int ofertaId) async {
    await ref.read(ofertasApiProvider).retirar(arg, ofertaId);
    await recargar();
  }
}

final misOfertasProvider =
    AsyncNotifierProvider<MisOfertasController, List<Oferta>>(MisOfertasController.new);

/// Ofertas que hice yo, cruzando publicaciones en cualquier estado (ver
/// OfertasApi.misOfertas). Sin esto, un usuario que ofertó y le aceptaron no
/// tiene forma de volver a esa publicación para calificar al dueño una vez
/// completada.
class MisOfertasController extends AsyncNotifier<List<Oferta>> {
  @override
  Future<List<Oferta>> build() => ref.watch(ofertasApiProvider).misOfertas();

  Future<void> recargar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(ofertasApiProvider).misOfertas());
  }
}
