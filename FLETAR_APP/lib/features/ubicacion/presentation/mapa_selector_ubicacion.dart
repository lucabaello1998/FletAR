import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../core/theme/fletar_colors.dart';

/// Punto inicial del mapa cuando todavía no se eligió nada: Buenos Aires.
const puntoInicialBuenosAires = ll.LatLng(-34.6037, -58.3816);

/// Mapa de selección de un punto, compartido por origen y destino del flete.
///
/// Es controlado: la pantalla es la dueña del punto (`seleccionado`) y este
/// widget sólo avisa los toques (`onTap`). Cuando el punto cambia desde afuera
/// - porque se eligió una dirección del autocompletado - el mapa se centra solo
/// en ese punto; y cuando se toca el mapa, además de avisar el toque se centra
/// ahí, así el pin nunca queda en un borde del recorte (que es lo que pasaba
/// antes: el marcador aparecía cortado arriba porque el mapa no se movía).
class MapaSelectorUbicacion extends StatefulWidget {
  const MapaSelectorUbicacion({
    required this.seleccionado,
    required this.onTap,
    this.altura = 260,
    this.zoomAlElegir = 16,
    super.key,
  });

  final ll.LatLng? seleccionado;
  final ValueChanged<ll.LatLng> onTap;
  final double altura;
  final double zoomAlElegir;

  @override
  State<MapaSelectorUbicacion> createState() => _MapaSelectorUbicacionState();
}

class _MapaSelectorUbicacionState extends State<MapaSelectorUbicacion> {
  final _mapController = MapController();
  bool _mapaListo = false;

  @override
  void didUpdateWidget(MapaSelectorUbicacion oldWidget) {
    super.didUpdateWidget(oldWidget);
    final punto = widget.seleccionado;
    if (punto == null || !_mapaListo) return;
    if (oldWidget.seleccionado == punto) return;

    // `move` durante el build tira; el mapa recién se puede mover después del
    // frame en el que se creó.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(punto, widget.zoomAlElegir);
    });
  }

  void _alTocar(_, ll.LatLng punto) {
    _mapController.move(punto, widget.zoomAlElegir);
    widget.onTap(punto);
  }

  @override
  Widget build(BuildContext context) {
    final inicial = widget.seleccionado;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.altura,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: inicial ?? puntoInicialBuenosAires,
            initialZoom: inicial == null ? 12 : widget.zoomAlElegir,
            onTap: _alTocar,
            onMapReady: () => _mapaListo = true,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'ar.fletar.app',
            ),
            if (inicial != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: inicial,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_pin, color: FletarColors.primary, size: 40),
                  ),
                ],
              ),
            const RichAttributionWidget(
              alignment: AttributionAlignment.bottomRight,
              attributions: [TextSourceAttribution('OpenStreetMap')],
            ),
          ],
        ),
      ),
    );
  }
}
