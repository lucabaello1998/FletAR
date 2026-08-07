import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../core/errores.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/fletar_colors.dart';
import '../domain/publicacion.dart';
import '../domain/publicacion_foto.dart';
import '../publicaciones_providers.dart';

/// Punto inicial del mapa cuando todavía no se tocó ningún lugar: Buenos Aires.
const _puntoInicialBuenosAires = ll.LatLng(-34.6037, -58.3816);

class PublicacionCreateScreen extends ConsumerStatefulWidget {
  const PublicacionCreateScreen({this.publicacionAEditar, super.key});

  /// Si no es null, la pantalla queda en modo edición sobre esta publicación
  /// (PUT) en vez de crear una nueva (POST) - mismo formulario, precargado.
  /// Navegan para acá con esto los botones "Editar" de
  /// publicacion_detail_screen.dart, vía `extra` de go_router.
  final Publicacion? publicacionAEditar;

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

  bool get _esEdicion => widget.publicacionAEditar != null;

  @override
  void initState() {
    super.initState();
    final publicacion = widget.publicacionAEditar;
    if (publicacion == null) return;

    _tituloController.text = publicacion.titulo;
    _descripcionController.text = publicacion.descripcion;
    _direccionController.text = publicacion.origenDireccionTexto;
    _direccionDestinoController.text = publicacion.destinoDireccionTexto ?? '';
    _categoriaCargaId = publicacion.categoriaCargaId;
    _tipoVehiculoSugeridoId = publicacion.tipoVehiculoSugeridoId;
    _origenSeleccionado = ll.LatLng(publicacion.latitud, publicacion.longitud);
    final destinoLat = publicacion.destinoLatitud;
    final destinoLng = publicacion.destinoLongitud;
    if (destinoLat != null && destinoLng != null) {
      _tieneDestino = true;
      _destinoSeleccionado = ll.LatLng(destinoLat, destinoLng);
    }
    _fechaDeseada = publicacion.fechaDeseada;
  }

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

    final destinoLatitud = _tieneDestino ? destino!.latitude : null;
    final destinoLongitud = _tieneDestino ? destino!.longitude : null;
    final destinoDireccionTexto =
        _tieneDestino && _direccionDestinoController.text.trim().isNotEmpty
            ? _direccionDestinoController.text.trim()
            : null;

    if (_esEdicion) {
      await ref.read(publicacionEditControllerProvider(widget.publicacionAEditar!.id).notifier).editar(
            titulo: _tituloController.text.trim(),
            descripcion: _descripcionController.text.trim(),
            categoriaCargaId: _categoriaCargaId!,
            tipoVehiculoSugeridoId: _tipoVehiculoSugeridoId,
            latitud: origen.latitude,
            longitud: origen.longitude,
            origenDireccionTexto: _direccionController.text.trim(),
            destinoLatitud: destinoLatitud,
            destinoLongitud: destinoLongitud,
            destinoDireccionTexto: destinoDireccionTexto,
            fechaDeseada: _fechaDeseada,
          );
    } else {
      await ref.read(publicacionCreateControllerProvider.notifier).crear(
            titulo: _tituloController.text.trim(),
            descripcion: _descripcionController.text.trim(),
            categoriaCargaId: _categoriaCargaId!,
            tipoVehiculoSugeridoId: _tipoVehiculoSugeridoId,
            latitud: origen.latitude,
            longitud: origen.longitude,
            origenDireccionTexto: _direccionController.text.trim(),
            destinoLatitud: destinoLatitud,
            destinoLongitud: destinoLongitud,
            destinoDireccionTexto: destinoDireccionTexto,
            fechaDeseada: _fechaDeseada,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriasState = ref.watch(categoriasCargaProvider);
    final tiposVehiculoState = ref.watch(tiposVehiculoProvider);

    void onExito() {
      ref.read(publicacionesListProvider.notifier).recargar();
      ref.read(misPublicacionesProvider.notifier).recargar();
      context.pop();
    }

    void onError(Object error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensajeDeError(error))));
    }

    final AsyncValue<Publicacion?> createState;
    if (_esEdicion) {
      final publicacionId = widget.publicacionAEditar!.id;
      createState = ref.watch(publicacionEditControllerProvider(publicacionId));
      ref.listen(publicacionEditControllerProvider(publicacionId), (previo, actual) {
        if (actual.hasError) {
          onError(actual.error!);
          return;
        }
        if (actual.valueOrNull != null && previo?.valueOrNull != actual.valueOrNull) {
          ref.read(publicacionDetailProvider(publicacionId).notifier).recargar();
          onExito();
        }
      });
    } else {
      createState = ref.watch(publicacionCreateControllerProvider);
      ref.listen(publicacionCreateControllerProvider, (previo, actual) {
        if (actual.hasError) {
          onError(actual.error!);
          return;
        }
        final creada = actual.valueOrNull;
        if (creada != null && previo?.valueOrNull != creada) {
          ref.read(publicacionesListProvider.notifier).recargar();
          ref.read(misPublicacionesProvider.notifier).recargar();
          // En vez de volver al listado (como sí hace guardar una edición),
          // se entra directo a "Editar" de la publicación recién creada: la
          // sección de fotos de más abajo necesita un id real para poder
          // subir algo (POST /publicaciones/{id}/fotos), que recién existe
          // después de este POST - sin este redirect, agregar una foto justo
          // después de crear requeriría salir, volver a entrar a la
          // publicación y tocar "Editar" a mano.
          context.pushReplacement('/publicaciones/${creada.id}/editar', extra: creada);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text(_esEdicion ? 'Editar publicación' : 'Nueva publicación')),
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
                    _SeccionFotosCarga(
                      publicacionId: widget.publicacionAEditar?.id,
                      fotosIniciales: widget.publicacionAEditar?.fotos ?? const [],
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
                          : Text(_esEdicion ? 'Guardar cambios' : 'Publicar'),
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

/// Sección de fotos de la carga (Fase 8): con `publicacionId` (modo edición,
/// o creación ya redirigida a "Editar" - ver el `ref.listen` de más arriba)
/// permite agregar/borrar fotos, subiéndolas de inmediato una por una (no
/// quedan "pendientes" hasta guardar el formulario - cada POST/DELETE ya
/// persiste solo). Sin `publicacionId` (creando por primera vez, todavía sin
/// POST exitoso) muestra un mensaje en vez de la sección activa: subir una
/// foto necesita un id real que recién existe después de crear.
class _SeccionFotosCarga extends ConsumerStatefulWidget {
  const _SeccionFotosCarga({required this.publicacionId, required this.fotosIniciales});

  final int? publicacionId;
  final List<PublicacionFoto> fotosIniciales;

  @override
  ConsumerState<_SeccionFotosCarga> createState() => _SeccionFotosCargaState();
}

class _SeccionFotosCargaState extends ConsumerState<_SeccionFotosCarga> {
  // Mismo tope que el backend (`PublicacionFoto.CantidadMaximaFotos`) -
  // duplicado a propósito para dar feedback inmediato sin esperar el 400 del
  // servidor cuando ya se llegó al máximo.
  static const _maximoFotos = 8;

  late List<PublicacionFoto> _fotos;
  bool _subiendo = false;
  int? _eliminandoId;

  @override
  void initState() {
    super.initState();
    _fotos = List.of(widget.fotosIniciales);
  }

  Future<void> _abrirSelector() async {
    final id = widget.publicacionId;
    if (id == null || _subiendo) return;
    if (_fotos.length >= _maximoFotos) {
      _mostrarMensaje('Ya llegaste al máximo de $_maximoFotos fotos por publicación.');
      return;
    }

    final soportaCamara = ImagePicker().supportsImageSource(ImageSource.camera);
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            if (soportaCamara)
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Tomar una foto'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
          ],
        ),
      ),
    );
    if (origen == null) return;

    try {
      final picker = ImagePicker();
      final espacioDisponible = _maximoFotos - _fotos.length;
      List<XFile> elegidas;
      if (origen == ImageSource.gallery) {
        // pickMultiImage con límite 1 delega en pickImage - alcanza igual
        // para el caso de "sólo queda espacio para una foto más".
        elegidas = espacioDisponible == 1
            ? _comoLista(await picker.pickImage(source: ImageSource.gallery, imageQuality: 85))
            : await picker.pickMultiImage(imageQuality: 85, limit: espacioDisponible);
      } else {
        elegidas = _comoLista(await picker.pickImage(source: ImageSource.camera, imageQuality: 85));
      }
      if (elegidas.isEmpty || !mounted) return;

      final aSubir =
          elegidas.length > espacioDisponible ? elegidas.sublist(0, espacioDisponible) : elegidas;
      if (aSubir.length < elegidas.length) {
        _mostrarMensaje(
            'Sólo se pudieron agregar ${aSubir.length} de ${elegidas.length} fotos (máximo $_maximoFotos por publicación).');
      }

      setState(() => _subiendo = true);
      for (final archivo in aSubir) {
        final foto = await ref.read(publicacionesApiProvider).agregarFoto(id, archivo);
        if (!mounted) return;
        setState(() => _fotos = [..._fotos, foto]);
      }
      // El detalle ya cacheado (si se llegó a mirar antes en esta sesión)
      // queda desactualizado - se invalida para que la próxima vez que se
      // mire se pidan las fotos nuevas, sin forzar un refetch inmediato acá.
      ref.invalidate(publicacionDetailProvider(id));
    } catch (e) {
      if (mounted) _mostrarMensaje(mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  List<XFile> _comoLista(XFile? archivo) => archivo == null ? const [] : [archivo];

  Future<void> _borrar(PublicacionFoto foto) async {
    final id = widget.publicacionId;
    if (id == null) return;

    setState(() => _eliminandoId = foto.id);
    try {
      await ref.read(publicacionesApiProvider).eliminarFoto(id, foto.id);
      if (!mounted) return;
      setState(() => _fotos = _fotos.where((f) => f.id != foto.id).toList());
      ref.invalidate(publicacionDetailProvider(id));
    } catch (e) {
      if (mounted) _mostrarMensaje(mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _eliminandoId = null);
    }
  }

  void _mostrarMensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.publicacionId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fotos de la carga (opcional)', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        if (id == null)
          const Text(
            'Vas a poder agregar fotos apenas termines de crear la publicación.',
            style: TextStyle(color: FletarColors.mutedForeground),
          )
        else
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final foto in _fotos)
                  _Miniatura(
                    foto: foto,
                    eliminando: _eliminandoId == foto.id,
                    onBorrar: () => _borrar(foto),
                  ),
                _BotonAgregarFoto(
                  habilitado: !_subiendo && _fotos.length < _maximoFotos,
                  subiendo: _subiendo,
                  onTap: _abrirSelector,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.foto, required this.eliminando, required this.onBorrar});

  final PublicacionFoto foto;
  final bool eliminando;
  final VoidCallback onBorrar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              resolverUrlMedia(foto.url),
              width: 90,
              height: 90,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 90,
                height: 90,
                color: FletarColors.border,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: eliminando
                ? const Padding(
                    padding: EdgeInsets.all(2),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  )
                : GestureDetector(
                    onTap: onBorrar,
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BotonAgregarFoto extends StatelessWidget {
  const _BotonAgregarFoto({required this.habilitado, required this.subiendo, required this.onTap});

  final bool habilitado;
  final bool subiendo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: habilitado ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          border: Border.all(color: FletarColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: subiendo
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  Icons.add_photo_alternate_outlined,
                  color: habilitado ? FletarColors.primary : FletarColors.mutedForeground,
                ),
        ),
      ),
    );
  }
}
