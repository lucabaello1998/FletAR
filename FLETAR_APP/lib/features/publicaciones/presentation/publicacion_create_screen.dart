import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../core/errores.dart';
import '../../../core/theme/fletar_colors.dart';
import '../publicaciones_providers.dart';

/// Punto inicial del mapa cuando todavía no se tocó ningún lugar: Buenos Aires.
const _puntoInicialBuenosAires = ll.LatLng(-34.6037, -58.3816);

class PublicacionCreateScreen extends ConsumerStatefulWidget {
  const PublicacionCreateScreen({super.key});

  @override
  ConsumerState<PublicacionCreateScreen> createState() => _PublicacionCreateScreenState();
}

class _PublicacionCreateScreenState extends ConsumerState<PublicacionCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _direccionController = TextEditingController();
  final _direccionDestinoController = TextEditingController();

  int? _categoriaCargaId;
  int? _tipoVehiculoSugeridoId;
  ll.LatLng? _origenSeleccionado;
  bool _tieneDestino = false;
  ll.LatLng? _destinoSeleccionado;
  DateTime? _fechaDeseada;

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _direccionController.dispose();
    _direccionDestinoController.dispose();
    super.dispose();
  }

  Future<void> _elegirFechaDeseada() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaDeseada ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (fecha != null) setState(() => _fechaDeseada = fecha);
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    final origen = _origenSeleccionado;
    if (origen == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tocá el mapa para marcar el origen del flete')),
      );
      return;
    }
    final destino = _destinoSeleccionado;
    if (_tieneDestino && destino == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tocá el mapa de destino para marcar el punto, o desmarcá "Tiene destino"')),
      );
      return;
    }

    await ref.read(publicacionCreateControllerProvider.notifier).crear(
          titulo: _tituloController.text.trim(),
          descripcion: _descripcionController.text.trim(),
          categoriaCargaId: _categoriaCargaId!,
          tipoVehiculoSugeridoId: _tipoVehiculoSugeridoId,
          latitud: origen.latitude,
          longitud: origen.longitude,
          origenDireccionTexto: _direccionController.text.trim(),
          destinoLatitud: _tieneDestino ? destino!.latitude : null,
          destinoLongitud: _tieneDestino ? destino!.longitude : null,
          destinoDireccionTexto:
              _tieneDestino && _direccionDestinoController.text.trim().isNotEmpty
                  ? _direccionDestinoController.text.trim()
                  : null,
          fechaDeseada: _fechaDeseada,
        );
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(publicacionCreateControllerProvider);
    final categoriasState = ref.watch(categoriasCargaProvider);
    final tiposVehiculoState = ref.watch(tiposVehiculoProvider);

    ref.listen(publicacionCreateControllerProvider, (previo, actual) {
      if (actual.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeDeError(actual.error!))),
        );
        return;
      }
      if (actual.valueOrNull != null && previo?.valueOrNull != actual.valueOrNull) {
        ref.read(publicacionesListProvider.notifier).recargar();
        ref.read(misPublicacionesProvider.notifier).recargar();
        context.pop();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva publicación')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _tituloController,
                      decoration: const InputDecoration(labelText: 'Título'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresá un título' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descripcionController,
                      decoration: const InputDecoration(labelText: 'Descripción'),
                      maxLines: 3,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Ingresá una descripción' : null,
                    ),
                    const SizedBox(height: 16),
                    categoriasState.when(
                      data: (categorias) => DropdownButtonFormField<int>(
                        initialValue: _categoriaCargaId,
                        decoration: const InputDecoration(labelText: 'Categoría de carga'),
                        items: categorias
                            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre)))
                            .toList(),
                        onChanged: (value) => setState(() => _categoriaCargaId = value),
                        validator: (v) => v == null ? 'Elegí una categoría' : null,
                      ),
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      ),
                      error: (error, stackTrace) => Text(mensajeDeError(error)),
                    ),
                    const SizedBox(height: 16),
                    tiposVehiculoState.when(
                      data: (tipos) => DropdownButtonFormField<int?>(
                        initialValue: _tipoVehiculoSugeridoId,
                        decoration: const InputDecoration(labelText: 'Tipo de vehículo (opcional)'),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Sin preferencia')),
                          ...tipos.map((t) => DropdownMenuItem<int?>(value: t.id, child: Text(t.nombre))),
                        ],
                        onChanged: (value) => setState(() => _tipoVehiculoSugeridoId = value),
                      ),
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      ),
                      error: (error, stackTrace) => Text(mensajeDeError(error)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _direccionController,
                      decoration: const InputDecoration(labelText: 'Dirección de origen'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Ingresá una dirección' : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Origen en el mapa (tocá para marcar el punto exacto)',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    _MapaSeleccionOrigen(
                      seleccionado: _origenSeleccionado,
                      onTap: (punto) => setState(() => _origenSeleccionado = punto),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _origenSeleccionado == null
                          ? 'Sin punto marcado todavía'
                          : 'Lat: ${_origenSeleccionado!.latitude.toStringAsFixed(6)} · '
                              'Lng: ${_origenSeleccionado!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(color: FletarColors.mutedForeground),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('¿Tiene destino conocido?'),
                      value: _tieneDestino,
                      onChanged: (value) => setState(() => _tieneDestino = value),
                    ),
                    if (_tieneDestino) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _direccionDestinoController,
                        decoration: const InputDecoration(labelText: 'Dirección de destino (opcional)'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Destino en el mapa (tocá para marcar el punto)',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      _MapaSeleccionOrigen(
                        seleccionado: _destinoSeleccionado,
                        onTap: (punto) => setState(() => _destinoSeleccionado = punto),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _destinoSeleccionado == null
                            ? 'Sin punto marcado todavía'
                            : 'Lat: ${_destinoSeleccionado!.latitude.toStringAsFixed(6)} · '
                                'Lng: ${_destinoSeleccionado!.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(color: FletarColors.mutedForeground),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_outlined),
                      title: const Text('Fecha deseada (opcional)'),
                      subtitle: Text(_fechaDeseada == null
                          ? 'Sin definir'
                          : '${_fechaDeseada!.day}/${_fechaDeseada!.month}/${_fechaDeseada!.year}'),
                      trailing: _fechaDeseada == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _fechaDeseada = null),
                            ),
                      onTap: _elegirFechaDeseada,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: createState.isLoading ? null : _enviar,
                      child: createState.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Publicar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapaSeleccionOrigen extends StatelessWidget {
  const _MapaSeleccionOrigen({required this.seleccionado, required this.onTap});

  final ll.LatLng? seleccionado;
  final ValueChanged<ll.LatLng> onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 260,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: seleccionado ?? _puntoInicialBuenosAires,
            initialZoom: 12,
            onTap: (tapPosition, punto) => onTap(punto),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'ar.fletar.app',
            ),
            if (seleccionado != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: seleccionado!,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_pin, color: FletarColors.primary, size: 40),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
