import 'dart:async';

import 'package:signalr_core/signalr_core.dart';

import '../domain/ubicacion_actual.dart';

/// Cliente de UNA sola conexión al hub de ubicación en vivo (Fase 6,
/// `UbicacionHub` en el backend, `/hubs/ubicacion`). Tanto el toggle de
/// "compartir mi ubicación" (`actualizarUbicacion`) como cada pantalla que
/// sigue a uno o varios fleteros (`seguirFletero`/`dejarDeSeguirFletero`)
/// reutilizan la MISMA conexión - SignalR agrupa por conexión
/// (`Groups.AddToGroupAsync` del lado del servidor), así que abrir un socket
/// nuevo por feature rompería el modelo de grupos, no sólo sería ineficiente.
///
/// El JWT viaja como `?access_token=` en la URL del WebSocket (el backend no
/// puede leer el header `Authorization` en el handshake de un socket) - acá
/// alcanza con pasarlo como `accessTokenFactory`: `signalr_core` ya lo agrega
/// como query string en el transporte de WebSocket (ver
/// `WebSocketTransport.connect` en el paquete), igual que hace el cliente
/// oficial de JS.
class UbicacionHubClient {
  UbicacionHubClient({
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
    _connection.on('RecibirUbicacion', _alRecibirUbicacion);
    // La reconexión automática no restaura sola los grupos del servidor (son
    // por conexión, y la reconexión abre una conexión nueva) - hay que
    // volver a pedir SeguirFletero por cada fletero que se estaba siguiendo.
    _connection.onreconnected((_) => _reseguirTodos());
    // withAutomaticReconnect() agota sus reintentos y termina en onclose si
    // no logra reconectar - sin esto, la conexión queda "disconnected" para
    // siempre y nadie la vuelve a levantar mientras la pantalla sólo esté
    // ESCUCHANDO (sin disparar una acción nueva como seguirFletero), que es
    // el caso normal de uso: el dueño deja la pantalla de "En curso" abierta
    // viendo moverse el pin, y el tracking se congela en silencio.
    _connection.onclose((_) => _programarReintentoDeConexion());
  }

  final HubConnection _connection;
  final _recibidas = StreamController<UbicacionActual>.broadcast();
  final _seguidosActualmente = <int>{};
  Future<void>? _conexionEnCurso;
  Timer? _reintentoTimer;
  bool _disposed = false;

  void _reseguirTodos() {
    for (final usuarioId in _seguidosActualmente) {
      unawaited(_connection.invoke('SeguirFletero', args: [usuarioId]));
    }
  }

  void _programarReintentoDeConexion() {
    if (_disposed) return;
    _reintentoTimer?.cancel();
    _reintentoTimer = Timer(const Duration(seconds: 5), () async {
      try {
        await asegurarConectado();
        _reseguirTodos();
      } catch (_) {
        _programarReintentoDeConexion();
      }
    });
  }

  /// Emite cada `RecibirUbicacion` que llega del servidor, de cualquier
  /// usuarioId - quien escucha filtra por el usuarioId que le interesa (ver
  /// `SeguimientoFleteroController` en ubicacion_providers.dart).
  Stream<UbicacionActual> get ubicacionesRecibidas => _recibidas.stream;

  void _alRecibirUbicacion(List<dynamic>? args) {
    if (args == null || args.length < 4) return;
    _recibidas.add(UbicacionActual(
      usuarioId: args[0] as int,
      lat: (args[1] as num).toDouble(),
      lng: (args[2] as num).toDouble(),
      fecha: DateTime.parse(args[3] as String),
    ));
  }

  /// Idempotente: si ya está conectado no hace nada, y si ya hay un intento de
  /// conexión en curso todos los llamados esperan el mismo (mismo patrón de
  /// single-flight que `AuthInterceptor._refrescar`). Si la conexión está en
  /// medio de una reconexión automática no se vuelve a llamar `start()` -
  /// eso tiraría, `HubConnection.start()` exige el estado `disconnected`.
  Future<void> asegurarConectado() async {
    if (_connection.state == HubConnectionState.connected) return;
    if (_connection.state != HubConnectionState.disconnected) return;

    await (_conexionEnCurso ??= (_connection.start() ?? Future.value())
        .whenComplete(() => _conexionEnCurso = null));
  }

  /// Lo llama el fletero (toggle "Compartir mi ubicación en vivo").
  Future<void> actualizarUbicacion(double lat, double lng) async {
    await asegurarConectado();
    await _connection.invoke('ActualizarUbicacion', args: [lat, lng]);
  }

  /// Lo llama el dueño para ver a un fletero en vivo. Devuelve la última
  /// posición ya conocida (o `null` si ese fletero todavía no compartió
  /// ninguna) apenas se une al grupo - ver `UbicacionHub.SeguirFletero`.
  Future<UbicacionActual?> seguirFletero(int usuarioId) async {
    await asegurarConectado();
    _seguidosActualmente.add(usuarioId);
    final resultado = await _connection.invoke('SeguirFletero', args: [usuarioId]);
    if (resultado == null) return null;
    final mapa = resultado as Map<String, dynamic>;
    return UbicacionActual(
      usuarioId: mapa['usuarioId'] as int,
      lat: (mapa['lat'] as num).toDouble(),
      lng: (mapa['lng'] as num).toDouble(),
      fecha: DateTime.parse(mapa['fecha'] as String),
    );
  }

  /// Se llama al salir de la pantalla que sigue a este fletero.
  Future<void> dejarDeSeguirFletero(int usuarioId) async {
    _seguidosActualmente.remove(usuarioId);
    if (_connection.state != HubConnectionState.connected) return;
    try {
      await _connection.invoke('DejarDeSeguirFletero', args: [usuarioId]);
    } catch (_) {
      // Best-effort: si la conexión ya se cayó no hay grupo del que salir.
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _reintentoTimer?.cancel();
    await _recibidas.close();
    await _connection.stop();
  }
}
