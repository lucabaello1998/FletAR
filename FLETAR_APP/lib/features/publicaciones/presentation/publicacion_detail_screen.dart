import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../core/errores.dart';
import '../../../core/theme/fletar_colors.dart';
import '../../auth/auth_providers.dart';
import '../../calificaciones/calificaciones_providers.dart';
import '../../calificaciones/domain/calificacion.dart';
import '../../ofertas/domain/oferta.dart';
import '../../ofertas/ofertas_providers.dart';
import '../../ofertas/presentation/oferta_estado.dart';
import '../../reportes/reportes_providers.dart';
import '../../usuarios/presentation/reputacion_indicador.dart';
import '../../usuarios/usuarios_providers.dart';
import '../domain/categoria_carga.dart';
import '../domain/publicacion.dart';
import '../domain/tipo_vehiculo.dart';
import '../publicaciones_providers.dart';
import 'publicacion_estado.dart';

class PublicacionDetailScreen extends ConsumerStatefulWidget {
  const PublicacionDetailScreen({required this.publicacionId, super.key});

  final int publicacionId;

  @override
  ConsumerState<PublicacionDetailScreen> createState() => _PublicacionDetailScreenState();
}

class _PublicacionDetailScreenState extends ConsumerState<PublicacionDetailScreen> {
  final _ofertaFormKey = GlobalKey<FormState>();
  final _montoController = TextEditingController();
  final _mensajeController = TextEditingController();

  bool _enviandoOferta = false;
  int? _ofertaEnProcesoId;
  bool _accionEnProceso = false;

  @override
  void dispose() {
    _montoController.dispose();
    _mensajeController.dispose();
    super.dispose();
  }

  void _mostrarError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensajeDeError(error))));
  }

  Future<void> _enviarOferta() async {
    if (!_ofertaFormKey.currentState!.validate()) return;
    setState(() => _enviandoOferta = true);
    try {
      await ref.read(ofertasDePublicacionProvider(widget.publicacionId).notifier).crear(
            monto: double.parse(_montoController.text.trim()),
            mensaje: _mensajeController.text.trim().isEmpty ? null : _mensajeController.text.trim(),
          );
      _montoController.clear();
      _mensajeController.clear();
    } catch (e) {
      _mostrarError(e);
    } finally {
      if (mounted) setState(() => _enviandoOferta = false);
    }
  }

  Future<void> _aceptarOferta(int ofertaId) async {
    setState(() => _ofertaEnProcesoId = ofertaId);
    try {
      await ref.read(ofertasDePublicacionProvider(widget.publicacionId).notifier).aceptar(ofertaId);
      await ref.read(publicacionDetailProvider(widget.publicacionId).notifier).recargar();
    } catch (e) {
      _mostrarError(e);
    } finally {
      if (mounted) setState(() => _ofertaEnProcesoId = null);
    }
  }

  Future<void> _retirarOferta(int ofertaId) async {
    setState(() => _ofertaEnProcesoId = ofertaId);
    try {
      await ref.read(ofertasDePublicacionProvider(widget.publicacionId).notifier).retirar(ofertaId);
    } catch (e) {
      _mostrarError(e);
    } finally {
      if (mounted) setState(() => _ofertaEnProcesoId = null);
    }
  }

  void _editarPublicacion(Publicacion publicacion) {
    context.push('/publicaciones/${publicacion.id}/editar', extra: publicacion);
  }

  Future<void> _cancelarPublicacion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar esta publicación?'),
        content: const Text('No vas a poder revertir esto, y va a dejar de aceptar ofertas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Volver')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar publicación'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _accionEnProceso = true);
    try {
      await ref.read(publicacionDetailProvider(widget.publicacionId).notifier).cancelar();
    } catch (e) {
      _mostrarError(e);
    } finally {
      if (mounted) setState(() => _accionEnProceso = false);
    }
  }

  Future<void> _iniciarPublicacion() async {
    setState(() => _accionEnProceso = true);
    try {
      await ref.read(publicacionDetailProvider(widget.publicacionId).notifier).iniciar();
    } catch (e) {
      _mostrarError(e);
    } finally {
      if (mounted) setState(() => _accionEnProceso = false);
    }
  }

  Future<void> _completarPublicacion() async {
    setState(() => _accionEnProceso = true);
    try {
      await ref.read(publicacionDetailProvider(widget.publicacionId).notifier).completar();
    } catch (e) {
      _mostrarError(e);
    } finally {
      if (mounted) setState(() => _accionEnProceso = false);
    }
  }

  Future<void> _reportar() async {
    final motivoController = TextEditingController();
    final comentarioController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reportar publicación'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: motivoController,
                decoration: const InputDecoration(labelText: 'Motivo'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresá un motivo' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: comentarioController,
                decoration: const InputDecoration(labelText: 'Comentario (opcional)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Reportar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    try {
      await ref.read(reportesApiProvider).crear(
            widget.publicacionId,
            motivo: motivoController.text.trim(),
            comentario: comentarioController.text.trim().isEmpty ? null : comentarioController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Reporte enviado. Gracias por avisarnos.')));
      }
    } catch (e) {
      _mostrarError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final publicacionState = ref.watch(publicacionDetailProvider(widget.publicacionId));
    final usuarioActualId = ref.watch(authControllerProvider).valueOrNull?.id;
    final esDuenoDeEsta =
        usuarioActualId != null && publicacionState.valueOrNull?.esDueno(usuarioActualId) == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Publicación'),
        actions: [
          if (publicacionState.hasValue && !esDuenoDeEsta)
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: 'Reportar publicación',
              onPressed: _reportar,
            ),
        ],
      ),
      body: publicacionState.when(
        data: (publicacion) => _DetalleCargado(
          publicacion: publicacion,
          ofertaFormKey: _ofertaFormKey,
          montoController: _montoController,
          mensajeController: _mensajeController,
          enviandoOferta: _enviandoOferta,
          ofertaEnProcesoId: _ofertaEnProcesoId,
          accionEnProceso: _accionEnProceso,
          onEnviarOferta: _enviarOferta,
          onAceptarOferta: _aceptarOferta,
          onRetirarOferta: _retirarOferta,
          onEditar: () => _editarPublicacion(publicacion),
          onCancelar: _cancelarPublicacion,
          onIniciar: _iniciarPublicacion,
          onCompletar: _completarPublicacion,
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
                  onPressed: () =>
                      ref.read(publicacionDetailProvider(widget.publicacionId).notifier).recargar(),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetalleCargado extends ConsumerWidget {
  const _DetalleCargado({
    required this.publicacion,
    required this.ofertaFormKey,
    required this.montoController,
    required this.mensajeController,
    required this.enviandoOferta,
    required this.ofertaEnProcesoId,
    required this.accionEnProceso,
    required this.onEnviarOferta,
    required this.onAceptarOferta,
    required this.onRetirarOferta,
    required this.onEditar,
    required this.onCancelar,
    required this.onIniciar,
    required this.onCompletar,
  });

  final Publicacion publicacion;
  final GlobalKey<FormState> ofertaFormKey;
  final TextEditingController montoController;
  final TextEditingController mensajeController;
  final bool enviandoOferta;
  final int? ofertaEnProcesoId;
  final bool accionEnProceso;
  final Future<void> Function() onEnviarOferta;
  final Future<void> Function(int ofertaId) onAceptarOferta;
  final Future<void> Function(int ofertaId) onRetirarOferta;
  final VoidCallback onEditar;
  final Future<void> Function() onCancelar;
  final Future<void> Function() onIniciar;
  final Future<void> Function() onCompletar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarioId = ref.watch(authControllerProvider).valueOrNull?.id;
    final esDueno = usuarioId != null && publicacion.esDueno(usuarioId);
    final ofertasState = ref.watch(ofertasDePublicacionProvider(publicacion.id));
    final categoriasState = ref.watch(categoriasCargaProvider);
    final tiposVehiculoState = ref.watch(tiposVehiculoProvider);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(publicacionDetailProvider(publicacion.id).notifier).recargar();
        await ref.read(ofertasDePublicacionProvider(publicacion.id).notifier).recargar();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(publicacion.titulo, style: Theme.of(context).textTheme.headlineSmall),
              ),
              EstadoPublicacionBadge(estado: publicacion.estado),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: FletarColors.mutedForeground),
              const SizedBox(width: 4),
              Text('Publica: ${publicacion.usuarioNombre}',
                  style: const TextStyle(color: FletarColors.mutedForeground)),
              const SizedBox(width: 8),
              ReputacionIndicador(usuarioId: publicacion.usuarioId),
            ],
          ),
          if (esDueno) ...[
            const SizedBox(height: 12),
            _AccionesDueno(
              estado: publicacion.estado,
              enProceso: accionEnProceso,
              onEditar: onEditar,
              onCancelar: onCancelar,
              onIniciar: onIniciar,
              onCompletar: onCompletar,
            ),
          ],
          const SizedBox(height: 12),
          Text(publicacion.descripcion),
          const SizedBox(height: 16),
          _filaDato(
            context,
            Icons.category_outlined,
            categoriasState.when(
              data: (categorias) => _nombreCategoria(categorias, publicacion.categoriaCargaId),
              loading: () => 'Cargando...',
              error: (_, _) => 'Categoría #${publicacion.categoriaCargaId}',
            ),
          ),
          if (publicacion.tipoVehiculoSugeridoId != null)
            _filaDato(
              context,
              Icons.local_shipping_outlined,
              tiposVehiculoState.when(
                data: (tipos) => _nombreTipoVehiculo(tipos, publicacion.tipoVehiculoSugeridoId!),
                loading: () => 'Cargando...',
                error: (_, _) => 'Tipo de vehículo #${publicacion.tipoVehiculoSugeridoId}',
              ),
            ),
          _filaDato(context, Icons.place_outlined, publicacion.origenDireccionTexto),
          if (publicacion.destinoDireccionTexto != null)
            _filaDato(context, Icons.flag_outlined, publicacion.destinoDireccionTexto!),
          const SizedBox(height: 8),
          _MapaUbicacionPublicacion(publicacion: publicacion),
          const SizedBox(height: 16),
          _filaDato(context, Icons.event_outlined, 'Publicada el ${_formatearFecha(publicacion.fechaPublicacion)}'),
          if (publicacion.fechaDeseada != null)
            _filaDato(context, Icons.schedule_outlined, 'Deseada para ${_formatearFecha(publicacion.fechaDeseada!)}'),
          const Divider(height: 32),
          Text('Ofertas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ofertasState.when(
            data: (ofertas) => _ListaOfertas(
              ofertas: ofertas,
              usuarioActualId: usuarioId,
              mostrarAceptar: esDueno && publicacion.estado == EstadoPublicacion.publicada,
              ofertaEnProcesoId: ofertaEnProcesoId,
              onAceptar: onAceptarOferta,
              onRetirar: onRetirarOferta,
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => Text(mensajeDeError(error)),
          ),
          if (publicacion.estado == EstadoPublicacion.completada)
            _SeccionCalificaciones(
              publicacion: publicacion,
              usuarioActualId: usuarioId,
              esDueno: esDueno,
              ofertaAceptadaUsuarioId:
                  _ofertaAceptadaUsuarioId(ofertasState.valueOrNull ?? const [], publicacion.ofertaAceptadaId),
            ),
          if (!esDueno) ...[
            const Divider(height: 32),
            Text('Hacer una oferta', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (publicacion.estado == EstadoPublicacion.publicada)
              Form(
                key: ofertaFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: montoController,
                      decoration: const InputDecoration(labelText: 'Monto (\$)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Ingresá un monto';
                        final monto = double.tryParse(v.trim());
                        if (monto == null || monto <= 0) return 'Ingresá un monto válido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: mensajeController,
                      decoration: const InputDecoration(labelText: 'Mensaje (opcional)'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: enviandoOferta ? null : onEnviarOferta,
                      child: enviandoOferta
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Enviar oferta'),
                    ),
                  ],
                ),
              )
            else
              const Text(
                'Esta publicación ya no acepta ofertas nuevas.',
                style: TextStyle(color: FletarColors.mutedForeground),
              ),
          ],
        ],
      ),
    );
  }

  Widget _filaDato(BuildContext context, IconData icon, String texto) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: FletarColors.mutedForeground),
            const SizedBox(width: 8),
            Expanded(child: Text(texto)),
          ],
        ),
      );

  String _nombreCategoria(List<CategoriaCarga> categorias, int id) {
    for (final categoria in categorias) {
      if (categoria.id == id) return categoria.nombre;
    }
    return 'Categoría #$id';
  }

  String _nombreTipoVehiculo(List<TipoVehiculo> tipos, int id) {
    for (final tipo in tipos) {
      if (tipo.id == id) return tipo.nombre;
    }
    return 'Tipo de vehículo #$id';
  }
}

/// Mapa de solo lectura con la ubicación de una Publicación: pin de origen
/// (obligatorio) y, si existe, pin de destino en otro color/ícono para
/// diferenciarlo. A diferencia de _MapaSeleccionOrigen (create screen), acá
/// no hay onTap - el punto ya está fijado, esto es solo para visualizarlo.
class _MapaUbicacionPublicacion extends StatelessWidget {
  const _MapaUbicacionPublicacion({required this.publicacion});

  final Publicacion publicacion;

  @override
  Widget build(BuildContext context) {
    final origen = ll.LatLng(publicacion.latitud, publicacion.longitud);
    final destinoLat = publicacion.destinoLatitud;
    final destinoLng = publicacion.destinoLongitud;
    final destino = (destinoLat != null && destinoLng != null) ? ll.LatLng(destinoLat, destinoLng) : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 220,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: origen,
            initialZoom: 13,
            // Con destino, encuadra la cámara para que ambos pines queden
            // visibles; sin destino, alcanza con centrar en el origen.
            initialCameraFit: destino == null
                ? null
                : CameraFit.coordinates(
                    coordinates: [origen, destino],
                    padding: const EdgeInsets.all(40),
                    maxZoom: 15,
                  ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'ar.fletar.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: origen,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_pin, color: FletarColors.primary, size: 40),
                ),
                if (destino != null)
                  Marker(
                    point: destino,
                    width: 36,
                    height: 36,
                    child: const Icon(Icons.flag, color: FletarColors.secondary, size: 32),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Botones de la máquina de estados que solo el dueño de la publicación ve:
/// Publicada -> Cancelada, OfertaAceptada -> EnCurso, EnCurso -> Completada.
/// Cada estado muestra a lo sumo un botón (las transiciones son excluyentes).
class _AccionesDueno extends StatelessWidget {
  const _AccionesDueno({
    required this.estado,
    required this.enProceso,
    required this.onEditar,
    required this.onCancelar,
    required this.onIniciar,
    required this.onCompletar,
  });

  final String estado;
  final bool enProceso;
  final VoidCallback onEditar;
  final Future<void> Function() onCancelar;
  final Future<void> Function() onIniciar;
  final Future<void> Function() onCompletar;

  @override
  Widget build(BuildContext context) {
    if (enProceso) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return switch (estado) {
      EstadoPublicacion.publicada => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onEditar,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar'),
            ),
            OutlinedButton.icon(
              onPressed: onCancelar,
              icon: Icon(Icons.cancel_outlined, color: FletarColors.destructive),
              label: Text('Cancelar publicación', style: TextStyle(color: FletarColors.destructive)),
            ),
          ],
        ),
      EstadoPublicacion.ofertaAceptada => ElevatedButton.icon(
          onPressed: onIniciar,
          icon: const Icon(Icons.local_shipping_outlined),
          label: const Text('Marcar como en curso'),
        ),
      EstadoPublicacion.enCurso => ElevatedButton.icon(
          onPressed: onCompletar,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Marcar como completada'),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _ListaOfertas extends StatelessWidget {
  const _ListaOfertas({
    required this.ofertas,
    required this.usuarioActualId,
    required this.mostrarAceptar,
    required this.ofertaEnProcesoId,
    required this.onAceptar,
    required this.onRetirar,
  });

  final List<Oferta> ofertas;
  final int? usuarioActualId;
  final bool mostrarAceptar;
  final int? ofertaEnProcesoId;
  final Future<void> Function(int ofertaId) onAceptar;
  final Future<void> Function(int ofertaId) onRetirar;

  @override
  Widget build(BuildContext context) {
    if (ofertas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Todavía no hay ofertas.', style: TextStyle(color: FletarColors.mutedForeground)),
      );
    }

    return Column(
      children: ofertas
          .map((oferta) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text('\$${oferta.monto.toStringAsFixed(2)}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 14, color: FletarColors.mutedForeground),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              oferta.usuarioNombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: FletarColors.mutedForeground, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 6),
                          ReputacionIndicador(usuarioId: oferta.usuarioId),
                        ],
                      ),
                      if (oferta.mensaje != null && oferta.mensaje!.isNotEmpty) Text(oferta.mensaje!),
                      Text(_formatearFecha(oferta.fechaOferta),
                          style: const TextStyle(color: FletarColors.mutedForeground, fontSize: 12)),
                      Text(etiquetaEstadoOferta(oferta.estado),
                          style: TextStyle(color: colorEstadoOferta(oferta.estado), fontSize: 12)),
                    ],
                  ),
                  trailing: _trailingOferta(oferta),
                ),
              ))
          .toList(),
    );
  }

  Widget? _trailingOferta(Oferta oferta) {
    if (ofertaEnProcesoId == oferta.id) {
      return const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (mostrarAceptar && oferta.estaPendiente) {
      return TextButton(onPressed: () => onAceptar(oferta.id), child: const Text('Aceptar'));
    }
    if (oferta.estaPendiente && usuarioActualId != null && oferta.usuarioId == usuarioActualId) {
      return TextButton(
        onPressed: () => onRetirar(oferta.id),
        style: TextButton.styleFrom(foregroundColor: FletarColors.destructive),
        child: const Text('Retirar'),
      );
    }
    return null;
  }
}

String _formatearFecha(DateTime fecha) {
  final local = fecha.toLocal();
  final dia = local.day.toString().padLeft(2, '0');
  final mes = local.month.toString().padLeft(2, '0');
  final hora = local.hour.toString().padLeft(2, '0');
  final minuto = local.minute.toString().padLeft(2, '0');
  return '$dia/$mes/${local.year} $hora:$minuto';
}

/// Busca en la lista de ofertas ya cargada cuál es la aceptada, para saber
/// quién es "la otra parte" a calificar (mismo criterio que
/// CalificacionService.DeterminarCalificadoAsync en el backend, hecho acá con
/// datos que la pantalla ya tiene en memoria en vez de pedirle de nuevo al
/// servidor).
int? _ofertaAceptadaUsuarioId(List<Oferta> ofertas, int? ofertaAceptadaId) {
  if (ofertaAceptadaId == null) return null;
  for (final oferta in ofertas) {
    if (oferta.id == ofertaAceptadaId) return oferta.usuarioId;
  }
  return null;
}

/// Sección de calificaciones de una Publicación Completada: lista las que ya
/// existen y, si quien mira participó (dueño u ofertante aceptado) y todavía
/// no calificó a la otra parte, muestra el formulario para hacerlo.
class _SeccionCalificaciones extends ConsumerStatefulWidget {
  const _SeccionCalificaciones({
    required this.publicacion,
    required this.usuarioActualId,
    required this.esDueno,
    required this.ofertaAceptadaUsuarioId,
  });

  final Publicacion publicacion;
  final int? usuarioActualId;
  final bool esDueno;
  final int? ofertaAceptadaUsuarioId;

  @override
  ConsumerState<_SeccionCalificaciones> createState() => _SeccionCalificacionesState();
}

class _SeccionCalificacionesState extends ConsumerState<_SeccionCalificaciones> {
  int _puntaje = 5;
  final _comentarioController = TextEditingController();
  bool _enviando = false;

  bool get _participo =>
      widget.usuarioActualId != null &&
      (widget.esDueno || widget.usuarioActualId == widget.ofertaAceptadaUsuarioId);

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _enviarCalificacion() async {
    setState(() => _enviando = true);
    try {
      await ref.read(calificacionesDePublicacionProvider(widget.publicacion.id).notifier).crear(
            puntaje: _puntaje,
            comentario:
                _comentarioController.text.trim().isEmpty ? null : _comentarioController.text.trim(),
          );
      _comentarioController.clear();
      if (mounted) setState(() => _puntaje = 5);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final calificacionesState = ref.watch(calificacionesDePublicacionProvider(widget.publicacion.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Text('Calificaciones', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        calificacionesState.when(
          data: (calificaciones) => _contenido(calificaciones),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => Text(mensajeDeError(error)),
        ),
      ],
    );
  }

  Widget _contenido(List<Calificacion> calificaciones) {
    Calificacion? miCalificacion;
    if (widget.usuarioActualId != null) {
      for (final calificacion in calificaciones) {
        if (calificacion.usuarioQueCalificaId == widget.usuarioActualId) {
          miCalificacion = calificacion;
          break;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (calificaciones.isEmpty)
          const Text('Todavía no hay calificaciones para esta publicación.',
              style: TextStyle(color: FletarColors.mutedForeground))
        else
          ...calificaciones.map((c) => _TarjetaCalificacion(
                calificacion: c,
                esLaMia: widget.usuarioActualId != null && c.usuarioQueCalificaId == widget.usuarioActualId,
              )),
        if (_participo) ...[
          const SizedBox(height: 12),
          if (miCalificacion != null)
            const Text(
              'Ya calificaste esta publicación (tu calificación está en la lista de arriba).',
              style: TextStyle(color: FletarColors.mutedForeground, fontStyle: FontStyle.italic),
            )
          else
            _FormularioCalificacion(
              puntaje: _puntaje,
              comentarioController: _comentarioController,
              enviando: _enviando,
              onCambiarPuntaje: (p) => setState(() => _puntaje = p),
              onEnviar: _enviarCalificacion,
            ),
        ],
      ],
    );
  }
}

class _FormularioCalificacion extends StatelessWidget {
  const _FormularioCalificacion({
    required this.puntaje,
    required this.comentarioController,
    required this.enviando,
    required this.onCambiarPuntaje,
    required this.onEnviar,
  });

  final int puntaje;
  final TextEditingController comentarioController;
  final bool enviando;
  final ValueChanged<int> onCambiarPuntaje;
  final Future<void> Function() onEnviar;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Calificá a la otra parte', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _EstrellasSelector(puntaje: puntaje, onCambiar: onCambiarPuntaje),
            const SizedBox(height: 8),
            TextField(
              controller: comentarioController,
              decoration: const InputDecoration(labelText: 'Comentario (opcional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: enviando ? null : onEnviar,
              child: enviando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Enviar calificación'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstrellasSelector extends StatelessWidget {
  const _EstrellasSelector({required this.puntaje, required this.onCambiar});

  final int puntaje;
  final ValueChanged<int> onCambiar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final valor = i + 1;
        return IconButton(
          onPressed: () => onCambiar(valor),
          icon: Icon(
            valor <= puntaje ? Icons.star : Icons.star_border,
            color: FletarColors.warning,
          ),
          tooltip: '$valor estrella${valor == 1 ? '' : 's'}',
        );
      }),
    );
  }
}

class _EstrellasReadOnly extends StatelessWidget {
  const _EstrellasReadOnly({required this.puntaje});

  final int puntaje;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < puntaje ? Icons.star : Icons.star_border,
          size: 16,
          color: FletarColors.warning,
        ),
      ),
    );
  }
}

class _TarjetaCalificacion extends ConsumerWidget {
  const _TarjetaCalificacion({required this.calificacion, this.esLaMia = false});

  final Calificacion calificacion;
  final bool esLaMia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calificadorState = ref.watch(usuarioPublicoProvider(calificacion.usuarioQueCalificaId));
    final calificadoState = ref.watch(usuarioPublicoProvider(calificacion.usuarioCalificadoId));
    final nombreCalificador =
        calificadorState.valueOrNull?.nombre ?? 'Usuario #${calificacion.usuarioQueCalificaId}';
    final nombreCalificado =
        calificadoState.valueOrNull?.nombre ?? 'Usuario #${calificacion.usuarioCalificadoId}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: esLaMia ? FletarColors.primary.withValues(alpha: 0.06) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$nombreCalificador calificó a $nombreCalificado',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                _EstrellasReadOnly(puntaje: calificacion.puntaje),
              ],
            ),
            if (calificacion.comentario != null && calificacion.comentario!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(calificacion.comentario!),
            ],
            const SizedBox(height: 4),
            Text(_formatearFecha(calificacion.fechaCalificacion),
                style: const TextStyle(color: FletarColors.mutedForeground, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
