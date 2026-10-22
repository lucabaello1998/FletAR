import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../core/errores.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/fletar_colors.dart';
import '../../ubicacion/data/geocoding_api.dart';
import '../../ubicacion/domain/sugerencia_direccion.dart';
import '../../ubicacion/presentation/direccion_autocomplete_field.dart';
import '../../ubicacion/presentation/mapa_selector_ubicacion.dart';
import '../domain/publicacion.dart';
import '../domain/publicacion_foto.dart';
import '../publicaciones_providers.dart';

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

  // Geocodificación reversa (tocar el mapa → completar la dirección). El
  // contador descarta respuestas viejas cuando se toca el mapa varias veces
  // seguidas: la última elección es la que manda.
  bool _buscandoDireccionOrigen = false;
  bool _buscandoDireccionDestino = false;
  int _solicitudReversaOrigen = 0;
  int _solicitudReversaDestino = 0;

  /// Candado de reentrada del botón: `createState.isLoading` se pone en true
  /// recién cuando arranca el POST, y antes de eso `_enviar` puede esperar
  /// varios segundos al geocoder (cola de Nominatim de 1 req/1,1 s + timeout de
  /// 8 s). Sin esto, dos toques seguidos creaban dos publicaciones iguales.
  bool _enviando = false;

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
    } else if (publicacion.destinoDireccionTexto?.trim().isNotEmpty ?? false) {
      // Publicaciones viejas o creadas con sólo el texto de destino: al editar
      // hay que mostrar el campo igual, o el switch apagado borraría la
      // dirección de destino sin que el usuario lo note.
      _tieneDestino = true;
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
    final hoy = DateUtils.dateOnly(DateTime.now());
    final elegida = _fechaDeseada == null ? null : DateUtils.dateOnly(_fechaDeseada!);
    // Si la fecha guardada ya quedó en el pasado (publicación vieja), showDatePicker
    // revienta si initialDate < firstDate: se arranca en hoy en ese caso.
    final inicial = elegida == null || elegida.isBefore(hoy) ? hoy : elegida;
    final fecha = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: hoy,
      lastDate: hoy.add(const Duration(days: 365)),
      helpText: 'Fecha en la que necesitás el flete',
    );
    if (!mounted) return;
    if (fecha != null) setState(() => _fechaDeseada = fecha);
  }

  /// Sugerencia elegida en el autocompletado de origen: el pin del mapa salta
  /// a esas coordenadas (el mapa se recentra solo, ver MapaSelectorUbicacion).
  void _alElegirDireccionOrigen(SugerenciaDireccion sugerencia) {
    // Elegir una sugerencia cancela cualquier geocodificación reversa en vuelo:
    // si el reverse del último toque al mapa llega después, pisaría la
    // dirección que el usuario acaba de elegir.
    _solicitudReversaOrigen++;
    setState(() {
      _buscandoDireccionOrigen = false;
      _origenSeleccionado = ll.LatLng(sugerencia.latitud, sugerencia.longitud);
    });
  }

  /// Misma lógica para destino. Además enciende el switch: elegir una
  /// dirección de destino implica que el flete tiene destino conocido.
  void _alElegirDireccionDestino(SugerenciaDireccion sugerencia) {
    _solicitudReversaDestino++;
    setState(() {
      _tieneDestino = true;
      _buscandoDireccionDestino = false;
      _destinoSeleccionado = ll.LatLng(sugerencia.latitud, sugerencia.longitud);
    });
  }

  /// Tocar el mapa fija el punto y completa la dirección con la geocodificación
  /// reversa (la dirección "va y viene" entre el campo y el mapa).
  Future<void> _alTocarMapaOrigen(ll.LatLng punto) async {
    final solicitud = ++_solicitudReversaOrigen;
    setState(() {
      _origenSeleccionado = punto;
      _buscandoDireccionOrigen = true;
    });

    final sugerencia = await ref.read(geocodingApiProvider).reversa(punto.latitude, punto.longitude);
    if (!mounted || solicitud != _solicitudReversaOrigen) return;

    setState(() => _buscandoDireccionOrigen = false);
    if (sugerencia != null) {
      _direccionController.text = sugerencia.direccionCorta;
    }
  }

  Future<void> _alTocarMapaDestino(ll.LatLng punto) async {
    final solicitud = ++_solicitudReversaDestino;
    setState(() {
      _destinoSeleccionado = punto;
      _buscandoDireccionDestino = true;
    });

    final sugerencia = await ref.read(geocodingApiProvider).reversa(punto.latitude, punto.longitude);
    if (!mounted || solicitud != _solicitudReversaDestino) return;

    setState(() => _buscandoDireccionDestino = false);
    if (sugerencia != null) {
      _direccionDestinoController.text = sugerencia.direccionCorta;
    }
  }

  String _textoCoordenadas(ll.LatLng punto) =>
      'Lat: ${punto.latitude.toStringAsFixed(6)} · Lng: ${punto.longitude.toStringAsFixed(6)}';

  /// Apagar el switch borra el destino guardado: se pregunta antes en vez de
  /// perderlo por un toque accidental (el switch está pegado al mapa).
  Future<void> _alCambiarTieneDestino(bool value) async {
    if (!value) {
      final teniaDestino =
          _destinoSeleccionado != null || _direccionDestinoController.text.trim().isNotEmpty;
      if (teniaDestino) {
        final confirmar = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('¿Quitar el destino?'),
            content: const Text('Se va a borrar la dirección y el punto de destino de esta publicación.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Quitar'),
              ),
            ],
          ),
        );
        if (confirmar != true) return;
        _direccionDestinoController.clear();
        _destinoSeleccionado = null;
      }
    }

    if (!mounted) return;
    setState(() => _tieneDestino = value);
  }


  /// Último recurso cuando escribieron una dirección pero nunca eligieron una
  /// sugerencia ni tocaron el mapa: se intenta ubicar el texto tal cual antes
  /// de rechazar el formulario. Si el geocoder no la encuentra, se le pide al
  /// usuario que marque el punto a mano.
  Future<ll.LatLng?> _puntoDesdeDireccion(String texto) async {
    if (texto.trim().length < minimoCaracteresBusqueda) return null;
    try {
      final sugerencias = await ref.read(geocodingApiProvider).buscar(texto, limite: 1);
      if (sugerencias.isEmpty) return null;
      return ll.LatLng(sugerencias.first.latitud, sugerencias.first.longitud);
    } on GeocodingNoDisponible {
      return null;
    }
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    if (!_formKey.currentState!.validate()) return;

    // `validate()` no cubre la categoría si `categoriasCargaProvider` falló: en
    // ese caso el dropdown no está en el árbol, su validator nunca corre y
    // `_categoriaCargaId` sigue en null (antes el `!` explotaba al enviar).
    final categoriaCargaId = _categoriaCargaId;
    if (categoriaCargaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elegí una categoría de carga para continuar.')),
      );
      return;
    }

    setState(() => _enviando = true);
    try {
      await _enviarConDatos(categoriaCargaId);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _enviarConDatos(int categoriaCargaId) async {
    var origen = _origenSeleccionado;
    if (origen == null) {
      final ubicado = await _puntoDesdeDireccion(_direccionController.text);
      if (!mounted) return;
      if (ubicado == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos ubicar la dirección. Tocá el mapa para marcar el origen.'),
          ),
        );
        return;
      }
      setState(() => _origenSeleccionado = ubicado);
      origen = ubicado;
    }

    var destino = _destinoSeleccionado;
    if (_tieneDestino && destino == null) {
      final ubicado = await _puntoDesdeDireccion(_direccionDestinoController.text);
      if (!mounted) return;
      if (ubicado == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos ubicar la dirección de destino. Tocá el mapa de destino o desmarcá "Tiene destino".',
            ),
          ),
        );
        return;
      }
      setState(() => _destinoSeleccionado = ubicado);
      destino = ubicado;
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
            categoriaCargaId: categoriaCargaId,
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
            categoriaCargaId: categoriaCargaId,
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
                    DireccionAutocompleteField(
                      controller: _direccionController,
                      label: 'Dirección de origen',
                      hintText: 'Calle y altura, por ej. Italia 2274',
                      textoAyuda: 'Elegí una sugerencia o tocá el mapa: se completan solos.',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Ingresá una dirección' : null,
                      onSeleccionada: _alElegirDireccionOrigen,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Origen en el mapa (tocá para marcar el punto exacto)',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    MapaSelectorUbicacion(
                      seleccionado: _origenSeleccionado,
                      onTap: _alTocarMapaOrigen,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _buscandoDireccionOrigen
                          ? 'Buscando la dirección del punto marcado…'
                          : _origenSeleccionado == null
                              ? 'Sin punto marcado todavía'
                              : _textoCoordenadas(_origenSeleccionado!),
                      style: const TextStyle(color: FletarColors.mutedForeground),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('¿Tiene destino conocido?'),
                      value: _tieneDestino,
                      onChanged: _alCambiarTieneDestino,
                    ),
                    if (_tieneDestino) ...[
                      const SizedBox(height: 8),
                      DireccionAutocompleteField(
                        controller: _direccionDestinoController,
                        label: 'Dirección de destino (opcional)',
                        hintText: 'Calle y altura del destino',
                        onSeleccionada: _alElegirDireccionDestino,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Destino en el mapa (tocá para marcar el punto)',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      MapaSelectorUbicacion(
                        seleccionado: _destinoSeleccionado,
                        onTap: _alTocarMapaDestino,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _buscandoDireccionDestino
                            ? 'Buscando la dirección del punto marcado…'
                            : _destinoSeleccionado == null
                                ? 'Sin punto marcado todavía'
                                : _textoCoordenadas(_destinoSeleccionado!),
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
                      onPressed: createState.isLoading || _enviando ? null : _enviar,
                      child: createState.isLoading || _enviando
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
