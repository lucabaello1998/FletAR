import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errores.dart';
import '../../../core/theme/fletar_colors.dart';
import '../../auth/auth_providers.dart';
import '../../ofertas/domain/oferta.dart';
import '../../ofertas/ofertas_providers.dart';
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

  @override
  Widget build(BuildContext context) {
    final publicacionState = ref.watch(publicacionDetailProvider(widget.publicacionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Publicación')),
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
          if (esDueno) ...[
            const SizedBox(height: 12),
            _AccionesDueno(
              estado: publicacion.estado,
              enProceso: accionEnProceso,
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

/// Botones de la máquina de estados que solo el dueño de la publicación ve:
/// Publicada -> Cancelada, OfertaAceptada -> EnCurso, EnCurso -> Completada.
/// Cada estado muestra a lo sumo un botón (las transiciones son excluyentes).
class _AccionesDueno extends StatelessWidget {
  const _AccionesDueno({
    required this.estado,
    required this.enProceso,
    required this.onCancelar,
    required this.onIniciar,
    required this.onCompletar,
  });

  final String estado;
  final bool enProceso;
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
      EstadoPublicacion.publicada => OutlinedButton.icon(
          onPressed: onCancelar,
          icon: Icon(Icons.cancel_outlined, color: FletarColors.destructive),
          label: Text('Cancelar publicación', style: TextStyle(color: FletarColors.destructive)),
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
                      if (oferta.mensaje != null && oferta.mensaje!.isNotEmpty) Text(oferta.mensaje!),
                      Text(_formatearFecha(oferta.fechaOferta),
                          style: const TextStyle(color: FletarColors.mutedForeground, fontSize: 12)),
                      Text(_etiquetaEstadoOferta(oferta.estado),
                          style: TextStyle(color: _colorEstadoOferta(oferta.estado), fontSize: 12)),
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

String _etiquetaEstadoOferta(String estado) {
  switch (estado) {
    case EstadoOferta.pendiente:
      return 'Pendiente';
    case EstadoOferta.aceptada:
      return 'Aceptada';
    case EstadoOferta.rechazada:
      return 'Rechazada';
    case EstadoOferta.retirada:
      return 'Retirada';
    default:
      return estado;
  }
}

Color _colorEstadoOferta(String estado) {
  switch (estado) {
    case EstadoOferta.pendiente:
      return FletarColors.warning;
    case EstadoOferta.aceptada:
      return FletarColors.success;
    case EstadoOferta.rechazada:
    case EstadoOferta.retirada:
      return FletarColors.destructive;
    default:
      return FletarColors.mutedForeground;
  }
}
