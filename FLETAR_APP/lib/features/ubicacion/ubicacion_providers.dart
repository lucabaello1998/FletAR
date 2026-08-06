import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/network/access_token_refresher.dart';
import '../../core/network/dio_client.dart';
import '../auth/auth_providers.dart';
import 'data/ubicacion_hub_client.dart';
import 'domain/ubicacion_actual.dart';

/// El hub vive en el mismo host/puerto que la API pero fuera de `/api` (ver
/// Program.cs: `app.MapHub<UbicacionHub>("/hubs/ubicacion")` está al mismo
/// nivel que `app.MapControllers()`, no debajo de `/api`) - `apiBaseUrl` (ver
/// dio_client.dart) siempre termina en `/api`, así que alcanza con sacarlo.
String _ubicacionHubUrl() => '${apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '')}/hubs/ubicacion';

/// Una sola conexión de SignalR por USUARIO logueado (mismo criterio que
/// `dioProvider`): compartir ubicación y seguir fleteros son dos USOS de la
/// misma conexión, no dos sockets separados - ver UbicacionHubClient.
///
/// Depende del id del usuario actual (no sólo se crea una vez y listo) a
/// propósito: la auth de un Hub de SignalR se valida UNA sola vez, en el
/// handshake de la conexión - a diferencia del header `Authorization` en cada
/// request HTTP, no hay forma de "refrescarla" a mitad de una conexión ya
/// abierta. Si alguien cierra sesión y otro usuario entra en la misma app sin
/// reiniciarla, una conexión vieja seguiría autenticada como el usuario
/// anterior (`Context.User` en el Hub no cambia solo) - el backend
/// rechazaría entonces `SeguirFletero` con un 403 confuso, autorizado contra
/// la identidad equivocada. Mirar el id acá fuerza a Riverpod a descartar el
/// cliente viejo (cierra su conexión, ver `ref.onDispose`) y abrir uno nuevo
/// que se autentica con el token del usuario actual apenas se usa.
final ubicacionHubClientProvider = Provider<UbicacionHubClient>((ref) {
  ref.watch(authControllerProvider.select((estado) => estado.valueOrNull?.id));

  final tokenStorage = ref.watch(tokenStorageProvider);
  final client = UbicacionHubClient(
    hubUrl: _ubicacionHubUrl(),
    // No alcanza con tokenStorage.leerAccessToken a secas: el JWT del hub se
    // valida una sola vez por conexión, y una pantalla de tracking puede
    // quedar abierta más de los 15 minutos que dura el access token. Sin
    // refrescarlo antes de cada intento de (re)conexión, todo intento
    // posterior a esa ventana fallaría con 401 para siempre - ver
    // access_token_refresher.dart.
    obtenerAccessToken: () => obtenerAccessTokenVigente(tokenStorage, apiBaseUrl),
  );
  ref.onDispose(() => unawaited(client.dispose()));
  return client;
});

/// Estado del toggle "Compartir mi ubicación en vivo" (opt-in explícito del
/// fletero, nunca tracking en segundo plano - ver CLAUDE.md Fase 6).
/// `autoDispose` a propósito: al salir de la pantalla que lo muestra (o
/// desloguearse, que la saca del árbol al redirigir a /login) el timer se
/// cancela solo - nunca queda mandando ubicación sin que el toggle esté a la
/// vista de nadie.
final compartirUbicacionControllerProvider =
    NotifierProvider.autoDispose<CompartirUbicacionController, bool>(
        CompartirUbicacionController.new);

class CompartirUbicacionController extends AutoDisposeNotifier<bool> {
  Timer? _timer;

  @override
  bool build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    return false;
  }

  /// Pide permiso de ubicación (foreground) si hace falta y, si se concede,
  /// manda un ping ya mismo y arranca a mandar `ActualizarUbicacion` cada 7
  /// segundos (dentro del rango de 5-10s pedido) mientras la pantalla siga
  /// montada. Tira una excepción (que la UI atrapa y muestra) si el permiso
  /// se niega - así el toggle nunca queda "prendido" sin estar mandando nada.
  Future<void> activar() async {
    if (state) return;

    final permitido = await _asegurarPermiso();
    if (!permitido) {
      throw Exception('Activá el permiso de ubicación para compartir tu posición.');
    }

    final hub = ref.read(ubicacionHubClientProvider);
    state = true;
    unawaited(_enviarUbicacionActual(hub));
    _timer = Timer.periodic(const Duration(seconds: 7), (_) => _enviarUbicacionActual(hub));
  }

  /// Se llama tanto desde el toggle como automáticamente al descartarse el
  /// provider (ver `build`) - cancelar el timer es lo único que hace falta,
  /// no hay nada del lado del servidor que "apagar" (el backend simplemente
  /// deja de recibir pings; la última posición ya guardada queda como
  /// referencia hasta la próxima vez que alguien la comparta).
  void desactivar() {
    _timer?.cancel();
    _timer = null;
    state = false;
  }

  Future<void> _enviarUbicacionActual(UbicacionHubClient hub) async {
    try {
      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await hub.actualizarUbicacion(posicion.latitude, posicion.longitude);
    } catch (_) {
      // Best-effort: un ping fallido (sin señal GPS, hub caído, etc.) no
      // debería cortar los pings siguientes - el próximo Timer.periodic
      // reintenta solo.
    }
  }

  Future<bool> _asegurarPermiso() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    // `unableToDetermine` sólo lo devuelve la web en navegadores sin Permissions
    // API - ahí igual conviene dejar intentar `getCurrentPosition`, que va a
    // disparar el prompt nativo del navegador en ese momento.
    return permiso == LocationPermission.whileInUse ||
        permiso == LocationPermission.always ||
        permiso == LocationPermission.unableToDetermine;
  }
}

/// Posición en vivo de UN fletero puntual (`arg` = su usuarioId): se une a su
/// grupo (`SeguirFletero`) al construirse y sale (`DejarDeSeguirFletero`) al
/// descartarse - `autoDispose` para que salir de la pantalla que lo mira lo
/// limpie solo, sin dejar una suscripción colgada (ver
/// `SeguimientoFleteroController.build`).
final seguimientoFleteroProvider = AsyncNotifierProvider.autoDispose
    .family<SeguimientoFleteroController, UbicacionActual?, int>(SeguimientoFleteroController.new);

class SeguimientoFleteroController extends AutoDisposeFamilyAsyncNotifier<UbicacionActual?, int> {
  StreamSubscription<UbicacionActual>? _sub;

  @override
  Future<UbicacionActual?> build(int arg) async {
    final hub = ref.watch(ubicacionHubClientProvider);

    ref.onDispose(() {
      _sub?.cancel();
      unawaited(hub.dejarDeSeguirFletero(arg));
    });

    _sub = hub.ubicacionesRecibidas.where((u) => u.usuarioId == arg).listen((ubicacion) {
      state = AsyncData(ubicacion);
    });

    // Autorización real la hace el backend (UbicacionHub.SeguirFletero): si
    // quien mira esta pantalla no es dueño de una publicación donde `arg`
    // tiene una oferta Pendiente/Aceptada, esto tira y el provider queda en
    // AsyncError - lo natural dado que el backend es la autoridad, acá no se
    // duplica esa regla.
    return hub.seguirFletero(arg);
  }
}
