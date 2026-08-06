import 'dart:async';

import 'package:signalr_core/signalr_core.dart';

import '../domain/mensaje.dart';

/// Cliente de UNA sola conexión al hub de chat en vivo (Fase 7, `ChatHub` en
/// el backend, `/hubs/chat`) - mismo criterio que `UbicacionHubClient` (Fase
/// 6): una sola conexión de SignalR por usuario logueado, reutilizada por
/// todas las conversaciones que se sigan (`SeguirConversacion`) en vez de
/// abrir un socket por pantalla de chat.
///
/// El JWT viaja como `?access_token=` en la URL del WebSocket, igual que
/// `UbicacionHubClient` - ver ese archivo para el detalle de por qué alcanza
/// con `accessTokenFactory`.
class ChatHubClient {
  ChatHubClient({
    required String hubUrl,
    required Future<String?> Function() obtenerAccessToken,
  }) : _connection = HubConnectionBuilder()
            .withUrl(
              hubUrl,
              HttpConnectionOptions(
                accessTokenFactory: obtenerAccessToken,
                logging: (level, message) {},
              ),
            )
            .withAutomaticReconnect()
            .build() {
    _connection.on('RecibirMensaje', _alRecibirMensaje);
    // Mismos dos arreglos de la Fase 6 (ver UbicacionHubClient para el detalle
    // completo de por qué hacen falta los dos): `onreconnected` no alcanza
    // solo porque los grupos del servidor son por conexión (hay que volver a
    // pedir SeguirConversacion tras reconectar), y `onclose` porque
    // `withAutomaticReconnect()` agota sus reintentos y deja la conexión
    // "disconnected" para siempre si nadie la vuelve a levantar.
    _connection.onreconnected((_) => _reseguirTodas());
    _connection.onclose((_) => _programarReintentoDeConexion());
  }

  final HubConnection _connection;
  final _recibidos = StreamController<Mensaje>.broadcast();
  final _seguidasActualmente = <int>{};
  Future<void>? _conexionEnCurso;
  Timer? _reintentoTimer;
  bool _disposed = false;

  void _reseguirTodas() {
    for (final ofertaId in _seguidasActualmente) {
      unawaited(_connection.invoke('SeguirConversacion', args: [ofertaId]));
    }
  }

  void _programarReintentoDeConexion() {
    if (_disposed) return;
    _reintentoTimer?.cancel();
    _reintentoTimer = Timer(const Duration(seconds: 5), () async {
      try {
        await asegurarConectado();
        _reseguirTodas();
      } catch (_) {
        _programarReintentoDeConexion();
      }
    });
  }

  /// Emite cada `RecibirMensaje` que llega del servidor, de cualquier
  /// conversación - quien escucha filtra por el `ofertaId` que le interesa
  /// (ver `MensajesDeOfertaController` en mensajes_providers.dart).
  Stream<Mensaje> get mensajesRecibidos => _recibidos.stream;

  void _alRecibirMensaje(List<dynamic>? args) {
    if (args == null || args.isEmpty) return;
    _recibidos.add(Mensaje.fromJson(args[0] as Map<String, dynamic>));
  }

  /// Idempotente, mismo patrón single-flight que `UbicacionHubClient.asegurarConectado`.
  Future<void> asegurarConectado() async {
    if (_connection.state == HubConnectionState.connected) return;
    if (_connection.state != HubConnectionState.disconnected) return;

    await (_conexionEnCurso ??= (_connection.start() ?? Future.value())
        .whenComplete(() => _conexionEnCurso = null));
  }

  /// Lo llama quien abre la pantalla de chat de una oferta puntual. La
  /// autorización real la hace el backend (`ChatHub.SeguirConversacion`):
  /// sólo el dueño de la publicación o el oferente de esa oferta puede
  /// unirse al grupo - si no, esto tira y el provider que lo llamó queda en
  /// AsyncError.
  Future<void> seguirConversacion(int ofertaId) async {
    await asegurarConectado();
    _seguidasActualmente.add(ofertaId);
    await _connection.invoke('SeguirConversacion', args: [ofertaId]);
  }

  /// Se llama al salir de la pantalla de chat de esa oferta.
  Future<void> dejarDeSeguirConversacion(int ofertaId) async {
    _seguidasActualmente.remove(ofertaId);
    if (_connection.state != HubConnectionState.connected) return;
    try {
      await _connection.invoke('DejarDeSeguirConversacion', args: [ofertaId]);
    } catch (_) {
      // Best-effort: si la conexión ya se cayó no hay grupo del que salir.
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _reintentoTimer?.cancel();
    await _recibidos.close();
    await _connection.stop();
  }
}
