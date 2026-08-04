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
