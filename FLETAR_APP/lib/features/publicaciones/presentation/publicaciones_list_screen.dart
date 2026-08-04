import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../core/errores.dart';
import '../../../core/theme/fletar_colors.dart';
import '../../auth/auth_providers.dart';
import '../domain/publicacion.dart';
import '../publicaciones_providers.dart';
import 'publicacion_estado.dart';

class PublicacionesListScreen extends ConsumerStatefulWidget {
  const PublicacionesListScreen({super.key});

  @override
  ConsumerState<PublicacionesListScreen> createState() => _PublicacionesListScreenState();
}

class _PublicacionesListScreenState extends ConsumerState<PublicacionesListScreen> {
  bool _mostrarMapa = false;
  bool _mostrarMisPublicaciones = false;

  Future<void> _recargarTodo() async {
    ref.read(publicacionesListProvider.notifier).recargar();
    ref.read(misPublicacionesProvider.notifier).recargar();
  }

  @override
  Widget build(BuildContext context) {
    final publicacionesState = ref.watch(publicacionesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FletAR'),
        actions: [
          if (!_mostrarMisPublicaciones)
            IconButton(
              icon: Icon(_mostrarMapa ? Icons.list : Icons.map_outlined),
              tooltip: _mostrarMapa ? 'Ver lista' : 'Ver mapa de cercanas',
              onPressed: () => setState(() => _mostrarMapa = !_mostrarMapa),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, icon: Icon(Icons.explore_outlined), label: Text('Explorar')),
                ButtonSegment(value: true, icon: Icon(Icons.person_outline), label: Text('Mis publicaciones')),
              ],
              selected: {_mostrarMisPublicaciones},
              onSelectionChanged: (seleccion) =>
                  setState(() => _mostrarMisPublicaciones = seleccion.first),
            ),
          ),
          Expanded(
            child: _mostrarMisPublicaciones
                ? const _MisPublicaciones()
                : (_mostrarMapa
                    ? const _MapaPublicacionesCercanas()
                    : RefreshIndicator(
                        onRefresh: () => ref.read(publicacionesListProvider.notifier).recargar(),
                        child: publicacionesState.when(
                          data: (publicaciones) =>
                              _ListaPublicaciones(publicaciones: publicaciones, ref: ref),
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (error, stackTrace) => ListView(
                            children: [
                              const SizedBox(height: 120),
                              Icon(Icons.error_outline, size: 48, color: FletarColors.destructive),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(mensajeDeError(error), textAlign: TextAlign.center),
                              ),
                              const SizedBox(height: 12),
                              Center(
                                child: TextButton(
                                  onPressed: () =>
                                      ref.read(publicacionesListProvider.notifier).recargar(),
                                  child: const Text('Reintentar'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/publicaciones/nueva');
          _recargarTodo();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _MisPublicaciones extends ConsumerWidget {
  const _MisPublicaciones();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(misPublicacionesProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(misPublicacionesProvider.notifier).recargar(),
      child: state.when(
        data: (publicaciones) => _ListaPublicaciones(
          publicaciones: publicaciones,
          ref: ref,
          textoVacio: 'Todavía no publicaste ningún flete.\nCreá el primero con el botón +.',
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => ListView(
          children: [
            const SizedBox(height: 120),
            Icon(Icons.error_outline, size: 48, color: FletarColors.destructive),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(mensajeDeError(error), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => ref.read(misPublicacionesProvider.notifier).recargar(),
                child: const Text('Reintentar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListaPublicaciones extends StatelessWidget {
  const _ListaPublicaciones({
    required this.publicaciones,
    required this.ref,
    this.textoVacio = 'Todavía no hay publicaciones.\nCreá la primera con el botón +.',
  });

  final List<Publicacion> publicaciones;
  final WidgetRef ref;
  final String textoVacio;

  @override
  Widget build(BuildContext context) {
    if (publicaciones.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: Text(textoVacio, textAlign: TextAlign.center)),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: publicaciones.length,
      itemBuilder: (context, index) {
        final publicacion = publicaciones[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            title: Text(
              publicacion.titulo,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    publicacion.origenDireccionTexto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: FletarColors.mutedForeground),
                  ),
                  const SizedBox(height: 8),
                  EstadoPublicacionBadge(estado: publicacion.estado),
                ],
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await context.push('/publicaciones/${publicacion.id}');
              ref.read(publicacionesListProvider.notifier).recargar();
              ref.read(misPublicacionesProvider.notifier).recargar();
            },
          ),
        );
      },
    );
  }
}

/// Vista de mapa con las publicaciones cercanas a una ubicación de ejemplo
/// (CABA) dentro de un radio elegido con el slider. La ubicación queda fija
/// hasta que se incorpore geolocalización real (geolocator) en una pasada
/// futura.
class _MapaPublicacionesCercanas extends ConsumerStatefulWidget {
  const _MapaPublicacionesCercanas();

  @override
  ConsumerState<_MapaPublicacionesCercanas> createState() => _MapaPublicacionesCercanasState();
}

class _MapaPublicacionesCercanasState extends ConsumerState<_MapaPublicacionesCercanas> {
  double _radioKm = radioKmCercanasPorDefecto;

  @override
  Widget build(BuildContext context) {
    final cercanasState = ref.watch(publicacionesCercanasControllerProvider);
    const centro = ll.LatLng(latitudCercanasEjemplo, longitudCercanasEjemplo);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.social_distance, color: FletarColors.mutedForeground),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: _radioKm,
                  min: 1,
                  max: 50,
                  divisions: 49,
                  activeColor: FletarColors.primary,
                  label: '${_radioKm.round()} km',
                  onChanged: (value) => setState(() => _radioKm = value),
                  onChangeEnd: (value) =>
                      ref.read(publicacionesCercanasControllerProvider.notifier).buscar(value),
                ),
              ),
              SizedBox(
                width: 56,
                child: Text('${_radioKm.round()} km', textAlign: TextAlign.end),
              ),
            ],
          ),
        ),
        Expanded(
          child: cercanasState.when(
            data: (publicaciones) => FlutterMap(
              options: const MapOptions(initialCenter: centro, initialZoom: 12),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'ar.fletar.app',
                ),
                MarkerLayer(
                  markers: [
                    const Marker(
                      point: centro,
                      width: 44,
                      height: 44,
                      child: Icon(Icons.my_location, color: FletarColors.secondary, size: 32),
                    ),
                    for (final publicacion in publicaciones)
                      Marker(
                        point: ll.LatLng(publicacion.latitud, publicacion.longitud),
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () => context.push('/publicaciones/${publicacion.id}'),
                          child: const Icon(Icons.location_pin, color: FletarColors.primary, size: 40),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: FletarColors.destructive),
                    const SizedBox(height: 12),
                    Text(mensajeDeError(error), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => ref
                          .read(publicacionesCercanasControllerProvider.notifier)
                          .buscar(_radioKm),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
