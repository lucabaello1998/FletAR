import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'data/publicaciones_api.dart';
import 'domain/categoria_carga.dart';
import 'domain/publicacion.dart';
import 'domain/tipo_vehiculo.dart';

final publicacionesApiProvider = Provider((ref) => PublicacionesApi(ref.watch(dioProvider)));

/// Catálogos casi estáticos (las tablas hoy están vacías salvo el seed del
/// backend) - alcanza con un FutureProvider simple, sin necesidad de recargar.
final categoriasCargaProvider =
    FutureProvider<List<CategoriaCarga>>((ref) => ref.watch(publicacionesApiProvider).categorias());

final tiposVehiculoProvider =
    FutureProvider<List<TipoVehiculo>>((ref) => ref.watch(publicacionesApiProvider).tiposVehiculo());

final publicacionesListProvider =
    AsyncNotifierProvider<PublicacionesListController, List<Publicacion>>(PublicacionesListController.new);

class PublicacionesListController extends AsyncNotifier<List<Publicacion>> {
  @override
  Future<List<Publicacion>> build() => ref.watch(publicacionesApiProvider).listar();

  Future<void> recargar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(publicacionesApiProvider).listar());
  }
}

final misPublicacionesProvider =
    AsyncNotifierProvider<MisPublicacionesController, List<Publicacion>>(MisPublicacionesController.new);

/// Publicaciones del usuario logueado, en CUALQUIER estado (a diferencia de
/// publicacionesListProvider, que solo trae las abiertas a ofertas de otros).
/// Sin esto una publicación propia desaparece de la app apenas deja de estar
/// Publicada.
class MisPublicacionesController extends AsyncNotifier<List<Publicacion>> {
  @override
  Future<List<Publicacion>> build() =>
      ref.watch(publicacionesApiProvider).listar(soloMias: true);

  Future<void> recargar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(publicacionesApiProvider).listar(soloMias: true));
  }
}

final publicacionDetailProvider =
    AsyncNotifierProvider.family<PublicacionDetailController, Publicacion, int>(
        PublicacionDetailController.new);

class PublicacionDetailController extends FamilyAsyncNotifier<Publicacion, int> {
  @override
  Future<Publicacion> build(int arg) => ref.watch(publicacionesApiProvider).obtenerPorId(arg);

  Future<void> recargar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(publicacionesApiProvider).obtenerPorId(arg));
  }

  Future<void> cancelar() async {
    await ref.read(publicacionesApiProvider).cancelar(arg);
    await recargar();
  }

  Future<void> iniciar() async {
    await ref.read(publicacionesApiProvider).iniciar(arg);
    await recargar();
  }

  Future<void> completar() async {
    await ref.read(publicacionesApiProvider).completar(arg);
    await recargar();
  }
}

/// Ubicación de ejemplo usada para la vista de mapa de "publicaciones
/// cercanas" (CABA) - queda fija hasta que se incorpore geolocator en una
/// pasada futura.
const latitudCercanasEjemplo = -34.6037;
const longitudCercanasEjemplo = -58.3816;
const radioKmCercanasPorDefecto = 10.0;

final publicacionesCercanasControllerProvider =
    AsyncNotifierProvider<PublicacionesCercanasController, List<Publicacion>>(
        PublicacionesCercanasController.new);

/// Estado de la búsqueda de publicaciones cercanas a un punto fijo, con un
/// radio (en km) que la pantalla puede ir cambiando (ver `buscar`).
class PublicacionesCercanasController extends AsyncNotifier<List<Publicacion>> {
  @override
  Future<List<Publicacion>> build() => _buscar(radioKmCercanasPorDefecto);

  Future<void> buscar(double radioKm) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _buscar(radioKm));
  }

  Future<List<Publicacion>> _buscar(double radioKm) => ref.read(publicacionesApiProvider).cercanas(
        lat: latitudCercanasEjemplo,
        lng: longitudCercanasEjemplo,
        radioKm: radioKm,
      );
}

final publicacionCreateControllerProvider =
    AsyncNotifierProvider<PublicacionCreateController, Publicacion?>(PublicacionCreateController.new);

/// Estado del formulario de creación: `null` mientras no se creó nada todavía,
/// la Publicación creada una vez que el POST tuvo éxito. La pantalla escucha
/// este provider para navegar y refrescar el listado (ver auth_providers.dart
/// para el mismo patrón con AuthController).
class PublicacionCreateController extends AsyncNotifier<Publicacion?> {
  @override
  Future<Publicacion?> build() async => null;

  Future<void> crear({
    required String titulo,
    required String descripcion,
    required int categoriaCargaId,
    int? tipoVehiculoSugeridoId,
    required double latitud,
    required double longitud,
    required String origenDireccionTexto,
    double? destinoLatitud,
    double? destinoLongitud,
    String? destinoDireccionTexto,
    DateTime? fechaDeseada,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(publicacionesApiProvider).crear(
          titulo: titulo,
          descripcion: descripcion,
          categoriaCargaId: categoriaCargaId,
          tipoVehiculoSugeridoId: tipoVehiculoSugeridoId,
          latitud: latitud,
          longitud: longitud,
          origenDireccionTexto: origenDireccionTexto,
          destinoLatitud: destinoLatitud,
          destinoLongitud: destinoLongitud,
          destinoDireccionTexto: destinoDireccionTexto,
          fechaDeseada: fechaDeseada,
        ));
  }
}
