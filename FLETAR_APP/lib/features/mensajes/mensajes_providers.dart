import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/access_token_refresher.dart';
import '../../core/network/dio_client.dart';
import '../auth/auth_providers.dart';
import 'data/chat_hub_client.dart';
import 'data/mensajes_api.dart';
import 'domain/mensaje.dart';

final mensajesApiProvider = Provider((ref) => MensajesApi(ref.watch(dioProvider)));

/// El hub vive al mismo nivel que la API pero fuera de `/api` (ver Program.cs:
/// `app.MapHub<ChatHub>("/hubs/chat")` está junto a `app.MapControllers()`,
/// no debajo) - mismo criterio que `_ubicacionHubUrl` en ubicacion_providers.dart.
String _chatHubUrl() => '${apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '')}/hubs/chat';

/// Una sola conexión de SignalR por usuario logueado, mismo criterio que
/// `ubicacionHubClientProvider` (Fase 6) - ver ese archivo para la explicación
/// completa de por qué depende del id del usuario actual (para que un cambio
/// de sesión sin reiniciar la app fuerce una conexión nueva, autenticada con
/// el usuario correcto) y por qué usa `obtenerAccessTokenVigente` en vez de
/// leer el token guardado a secas (una pantalla de chat puede quedar abierta
/// más de los 15 minutos que dura el access token).
final chatHubClientProvider = Provider<ChatHubClient>((ref) {
  ref.watch(authControllerProvider.select((estado) => estado.valueOrNull?.id));

  final tokenStorage = ref.watch(tokenStorageProvider);
  final client = ChatHubClient(
    hubUrl: _chatHubUrl(),
    obtenerAccessToken: () => obtenerAccessTokenVigente(tokenStorage, apiBaseUrl),
  );
  ref.onDispose(() => unawaited(client.dispose()));
  return client;
});

final mensajesDeOfertaProvider = AsyncNotifierProvider.autoDispose
    .family<MensajesDeOfertaController, List<Mensaje>, int>(MensajesDeOfertaController.new);

/// Conversación de UNA Oferta puntual (`arg` = ofertaId): historial por REST
/// (`GET /api/ofertas/{id}/mensajes`) fusionado con lo que va llegando en vivo
/// por SignalR (`ChatHub`). `autoDispose` para que salir de la pantalla de
/// chat se desuscriba sola del grupo (`DejarDeSeguirConversacion`), mismo
/// criterio que `seguimientoFleteroProvider` (Fase 6).
///
/// Los mensajes se guardan en un mapa por id (no una lista a secas) para
/// deduplicar sin esfuerzo: el propio mensaje que uno manda vuelve a llegar
/// por el broadcast de SignalR (uno mismo está en el grupo de su propia
/// conversación), y el historial por REST puede solaparse con mensajes que
/// ya llegaron en vivo mientras ese GET todavía estaba en curso.
class MensajesDeOfertaController extends AutoDisposeFamilyAsyncNotifier<List<Mensaje>, int> {
  StreamSubscription<Mensaje>? _sub;
  final Map<int, Mensaje> _mensajesPorId = {};

  @override
  Future<List<Mensaje>> build(int arg) async {
    _mensajesPorId.clear();
    final hub = ref.watch(chatHubClientProvider);

    ref.onDispose(() {
      _sub?.cancel();
      unawaited(hub.dejarDeSeguirConversacion(arg));
    });

    _sub = hub.mensajesRecibidos.where((m) => m.ofertaId == arg).listen(_agregar);

    // Autorización real la hace el backend (ChatHub.SeguirConversacion): sólo
    // el dueño de la publicación o el oferente de esta oferta puntual puede
    // unirse - si no, esto tira y el provider queda en AsyncError, igual que
    // seguimientoFleteroProvider.
    await hub.seguirConversacion(arg);

    final historial = await ref.read(mensajesApiProvider).listar(arg);
    for (final mensaje in historial) {
      _mensajesPorId[mensaje.id] = mensaje;
    }

    return _ordenados();
  }

  List<Mensaje> _ordenados() => _mensajesPorId.values.toList()
    ..sort((a, b) => a.fechaEnvio.compareTo(b.fechaEnvio));

  void _agregar(Mensaje mensaje) {
    if (_mensajesPorId.containsKey(mensaje.id)) return;
    _mensajesPorId[mensaje.id] = mensaje;
    state = AsyncData(_ordenados());
  }

  /// Manda un mensaje nuevo. El mensaje devuelto por el POST se agrega ya
  /// mismo (no hace falta esperar a que vuelva por el broadcast de SignalR,
  /// aunque también va a llegar por ahí - `_agregar` deduplica por id).
  Future<void> enviar(String texto) async {
    final nuevo = await ref.read(mensajesApiProvider).enviar(arg, texto);
    _agregar(nuevo);
  }
}
