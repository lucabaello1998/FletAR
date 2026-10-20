import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../reportes/domain/reporte.dart';
import 'data/admin_api.dart';
import 'domain/metricas.dart';
import 'domain/usuario_admin.dart';
import 'domain/verificacion_identidad_admin.dart';

final adminApiProvider = Provider((ref) => AdminApi(ref.watch(dioProvider)));

final reportesPendientesProvider =
    AsyncNotifierProvider<ReportesPendientesController, List<Reporte>>(
      ReportesPendientesController.new,
    );

class ReportesPendientesController extends AsyncNotifier<List<Reporte>> {
  @override
  Future<List<Reporte>> build() {
    // Ver el comentario análogo en MisPublicacionesController - sin esto, si
    // un admin se desloguea y otra cuenta entra en el mismo dispositivo, se
    // ven los reportes (datos de moderación) de la sesión admin anterior.
    ref.watch(
      authControllerProvider.select((estado) => estado.valueOrNull?.id),
    );
    return ref
        .watch(adminApiProvider)
        .listarReportes(estado: EstadoReporte.pendiente);
  }

  Future<void> recargar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(adminApiProvider)
          .listarReportes(estado: EstadoReporte.pendiente),
    );
  }

  Future<void> revisar(int reporteId) async {
    await ref.read(adminApiProvider).revisarReporte(reporteId);
    await recargar();
  }

  Future<void> descartar(int reporteId) async {
    await ref.read(adminApiProvider).descartarReporte(reporteId);
    await recargar();
  }

  Future<void> cancelarPublicacion(int publicacionId) async {
    await ref.read(adminApiProvider).cancelarPublicacion(publicacionId);
  }
}

final adminUsuariosProvider =
    AsyncNotifierProvider<AdminUsuariosController, List<UsuarioAdmin>>(
      AdminUsuariosController.new,
    );

class AdminUsuariosController extends AsyncNotifier<List<UsuarioAdmin>> {
  @override
  Future<List<UsuarioAdmin>> build() {
    // Ver el comentario análogo en ReportesPendientesController - evita que
    // la lista de usuarios (con emails) de una sesión admin anterior quede
    // visible tras cambiar de cuenta en el mismo dispositivo.
    ref.watch(
      authControllerProvider.select((estado) => estado.valueOrNull?.id),
    );
    return ref.watch(adminApiProvider).listarUsuarios();
  }

  Future<void> buscar(String? busqueda) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(adminApiProvider).listarUsuarios(busqueda: busqueda),
    );
  }

  Future<void> desactivar(int usuarioId) async {
    await ref.read(adminApiProvider).desactivarUsuario(usuarioId);
    await buscar(null);
  }

  Future<void> reactivar(int usuarioId) async {
    await ref.read(adminApiProvider).reactivarUsuario(usuarioId);
    await buscar(null);
  }
}

final metricasProvider = FutureProvider<Metricas>(
  (ref) => ref.watch(adminApiProvider).obtenerMetricas(),
);

/// Moderación de verificaciones de identidad (Fase 9). Arranca en
/// "Pendiente" porque es lo único sobre lo que hay que actuar; el filtro
/// puede pasar a `null` (= todas) para ver el historial.
final adminVerificacionesProvider =
    AsyncNotifierProvider<
      AdminVerificacionesController,
      List<VerificacionIdentidadAdmin>
    >(AdminVerificacionesController.new);

class AdminVerificacionesController
    extends AsyncNotifier<List<VerificacionIdentidadAdmin>> {
  String? _estado = 'Pendiente';

  @override
  Future<List<VerificacionIdentidadAdmin>> build() {
    // Ver el comentario análogo en ReportesPendientesController: cambiar de
    // cuenta no puede dejar visible la cola de moderación anterior.
    ref.watch(
      authControllerProvider.select((estado) => estado.valueOrNull?.id),
    );
    return ref
        .watch(adminApiProvider)
        .listarVerificacionesIdentidad(estado: _estado);
  }

  Future<void> filtrar(String? estado) async {
    _estado = estado;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(adminApiProvider)
          .listarVerificacionesIdentidad(estado: estado),
    );
  }

  Future<void> recargar() => filtrar(_estado);

  Future<void> aprobar(int verificacionId) async {
    await ref.read(adminApiProvider).aprobarVerificacion(verificacionId);
    await recargar();
  }

  Future<void> rechazar(int verificacionId, {String? comentario}) async {
    await ref
        .read(adminApiProvider)
        .rechazarVerificacion(verificacionId, comentario: comentario);
    await recargar();
  }
}
