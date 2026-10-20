import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errores.dart';
import '../../../core/theme/fletar_colors.dart';
import '../../reportes/domain/reporte.dart';
import '../admin_providers.dart';
import '../data/admin_api.dart';
import '../domain/verificacion_identidad_admin.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel admin'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Reportes', icon: Icon(Icons.flag_outlined)),
              Tab(text: 'Identidad', icon: Icon(Icons.badge_outlined)),
              Tab(text: 'Usuarios', icon: Icon(Icons.people_outline)),
              Tab(text: 'Métricas', icon: Icon(Icons.bar_chart_outlined)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ReportesTab(),
            _IdentidadTab(),
            _UsuariosTab(),
            _MetricasTab(),
          ],
        ),
      ),
    );
  }
}

class _ReportesTab extends ConsumerWidget {
  const _ReportesTab();

  Future<void> _cancelarPublicacion(
    BuildContext context,
    WidgetRef ref,
    Reporte reporte,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar esta publicación?'),
        content: Text(
          'Se va a cancelar "${reporte.publicacionTitulo}" y el reporte queda revisado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar publicación'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await ref
          .read(reportesPendientesProvider.notifier)
          .cancelarPublicacion(reporte.publicacionId);
      await ref.read(reportesPendientesProvider.notifier).revisar(reporte.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportesPendientesProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(reportesPendientesProvider.notifier).recargar(),
      child: state.when(
        data: (reportes) {
          if (reportes.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No hay reportes pendientes.')),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: reportes.length,
            itemBuilder: (context, index) {
              final reporte = reportes[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reporte.publicacionTitulo,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text('Motivo: ${reporte.motivo}'),
                      if (reporte.comentario != null &&
                          reporte.comentario!.isNotEmpty)
                        Text(
                          reporte.comentario!,
                          style: const TextStyle(
                            color: FletarColors.mutedForeground,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        'Reportado por ${reporte.usuarioReportanteNombre}',
                        style: const TextStyle(
                          color: FletarColors.mutedForeground,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => context.push(
                              '/publicaciones/${reporte.publicacionId}',
                            ),
                            child: const Text('Ver publicación'),
                          ),
                          TextButton(
                            onPressed: () => ref
                                .read(reportesPendientesProvider.notifier)
                                .descartar(reporte.id),
                            child: const Text('Descartar'),
                          ),
                          TextButton(
                            onPressed: () => ref
                                .read(reportesPendientesProvider.notifier)
                                .revisar(reporte.id),
                            child: const Text('Marcar revisado'),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: FletarColors.destructive,
                            ),
                            onPressed: () =>
                                _cancelarPublicacion(context, ref, reporte),
                            child: const Text('Cancelar publicación'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text(mensajeDeError(error))),
      ),
    );
  }
}

class _UsuariosTab extends ConsumerStatefulWidget {
  const _UsuariosTab();

  @override
  ConsumerState<_UsuariosTab> createState() => _UsuariosTabState();
}

class _UsuariosTabState extends ConsumerState<_UsuariosTab> {
  final _busquedaController = TextEditingController();

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminUsuariosProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _busquedaController,
            decoration: const InputDecoration(
              labelText: 'Buscar por nombre o email',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (valor) => ref
                .read(adminUsuariosProvider.notifier)
                .buscar(valor.trim().isEmpty ? null : valor.trim()),
          ),
        ),
        Expanded(
          child: state.when(
            data: (usuarios) => ListView.builder(
              itemCount: usuarios.length,
              itemBuilder: (context, index) {
                final usuario = usuarios[index];
                return ListTile(
                  title: Text(usuario.nombre),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(usuario.email),
                      Text(
                        usuario.promedioCalificacion == null
                            ? 'Sin calificaciones'
                            : '★ ${usuario.promedioCalificacion!.toStringAsFixed(1)} (${usuario.cantidadCalificaciones})',
                        style: const TextStyle(
                          color: FletarColors.mutedForeground,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: usuario.activo
                          ? FletarColors.destructive
                          : FletarColors.success,
                    ),
                    onPressed: () => usuario.activo
                        ? ref
                              .read(adminUsuariosProvider.notifier)
                              .desactivar(usuario.id)
                        : ref
                              .read(adminUsuariosProvider.notifier)
                              .reactivar(usuario.id),
                    child: Text(usuario.activo ? 'Desactivar' : 'Reactivar'),
                  ),
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                Center(child: Text(mensajeDeError(error))),
          ),
        ),
      ],
    );
  }
}

class _MetricasTab extends ConsumerWidget {
  const _MetricasTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(metricasProvider);

    return state.when(
      data: (metricas) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _fila('Usuarios totales', '${metricas.totalUsuarios}'),
          _fila('Reportes pendientes', '${metricas.reportesPendientes}'),
          const Divider(height: 32),
          Text('Publicaciones', style: Theme.of(context).textTheme.titleMedium),
          _fila('Total', '${metricas.totalPublicaciones}'),
          _fila('Publicadas', '${metricas.publicacionesPublicadas}'),
          _fila(
            'Con oferta aceptada',
            '${metricas.publicacionesOfertaAceptada}',
          ),
          _fila('En curso', '${metricas.publicacionesEnCurso}'),
          _fila('Completadas', '${metricas.publicacionesCompletadas}'),
          _fila('Canceladas', '${metricas.publicacionesCanceladas}'),
          const Divider(height: 32),
          _fila('Ofertas totales', '${metricas.totalOfertas}'),
          _fila(
            'Calificación promedio global',
            metricas.promedioCalificacionGlobal == null
                ? 'Sin calificaciones'
                : metricas.promedioCalificacionGlobal!.toStringAsFixed(2),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text(mensajeDeError(error))),
    );
  }

  Widget _fila(String etiqueta, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(etiqueta),
        Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _IdentidadTab extends ConsumerStatefulWidget {
  const _IdentidadTab();

  @override
  ConsumerState<_IdentidadTab> createState() => _IdentidadTabState();
}

class _IdentidadTabState extends ConsumerState<_IdentidadTab> {
  String? _estado = 'Pendiente';

  void _filtrar(String? estado) {
    setState(() => _estado = estado);
    ref.read(adminVerificacionesProvider.notifier).filtrar(estado);
  }

  Future<void> _verDocumentos(VerificacionIdentidadAdmin verificacion) {
    return showDialog<void>(
      context: context,
      builder: (context) => _DocumentosDialog(
        verificacion: verificacion,
        api: ref.read(adminApiProvider),
      ),
    );
  }

  Future<void> _aprobar(VerificacionIdentidadAdmin verificacion) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Aprobar esta identidad?'),
        content: Text(
          'Vas a verificar la identidad de ${verificacion.usuarioNombre}. '
          'Va a aparecer con la insignia en su perfil público.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await ref
          .read(adminVerificacionesProvider.notifier)
          .aprobar(verificacion.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Identidad aprobada.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
      }
    }
  }

  Future<void> _rechazar(VerificacionIdentidadAdmin verificacion) async {
    // El comentario es opcional (el backend lo acepta vacío), pero suele ser
    // la única forma de que el usuario sepa qué corregir. El diálogo es dueño
    // del TextEditingController: si lo creara acá, al cerrarse seguiría
    // reconstruyéndose durante la animación y lo usaría ya liberado.
    final resultado = await showDialog<_MotivoRechazo>(
      context: context,
      builder: (context) => const _RechazoDialog(),
    );
    if (resultado == null) return;

    try {
      await ref
          .read(adminVerificacionesProvider.notifier)
          .rechazar(verificacion.id, comentario: resultado.comentario);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Solicitud rechazada.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminVerificacionesProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Pendientes'),
                selected: _estado == 'Pendiente',
                onSelected: (_) => _filtrar('Pendiente'),
              ),
              ChoiceChip(
                label: const Text('Todas'),
                selected: _estado == null,
                onSelected: (_) => _filtrar(null),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(adminVerificacionesProvider.notifier).recargar(),
            child: state.when(
              data: (verificaciones) {
                if (verificaciones.isEmpty) {
                  return ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Text(
                          _estado == 'Pendiente'
                              ? 'No hay solicitudes pendientes.'
                              : 'Todavía no hay verificaciones.',
                        ),
                      ),
                    ],
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: verificaciones.length,
                  itemBuilder: (context, index) {
                    final verificacion = verificaciones[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        verificacion.usuarioNombre,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      Text(
                                        verificacion.usuarioEmail,
                                        style: const TextStyle(
                                          color: FletarColors.mutedForeground,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _EstadoChip(estado: verificacion.estado),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Solicitada el ${_fechaCorta(verificacion.fechaSolicitud)}',
                              style: const TextStyle(
                                color: FletarColors.mutedForeground,
                                fontSize: 12,
                              ),
                            ),
                            if (verificacion.comentarioAdmin != null &&
                                verificacion.comentarioAdmin!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Comentario: ${verificacion.comentarioAdmin}',
                                  style: const TextStyle(
                                    color: FletarColors.mutedForeground,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _verDocumentos(verificacion),
                                  icon: const Icon(
                                    Icons.image_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Ver documentos'),
                                ),
                                if (verificacion.pendiente) ...[
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: FletarColors.success,
                                    ),
                                    onPressed: () => _aprobar(verificacion),
                                    child: const Text('Aprobar'),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: FletarColors.destructive,
                                    ),
                                    onPressed: () => _rechazar(verificacion),
                                    child: const Text('Rechazar'),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  Center(child: Text(mensajeDeError(error))),
            ),
          ),
        ),
      ],
    );
  }

  static String _fechaCorta(DateTime fecha) =>
      '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
}

/// Resultado del diálogo de rechazo: `null` en el flujo significa "canceló";
/// `comentario == null` significa "rechazar sin motivo".
class _MotivoRechazo {
  const _MotivoRechazo(this.comentario);

  final String? comentario;
}

class _RechazoDialog extends StatefulWidget {
  const _RechazoDialog();

  @override
  State<_RechazoDialog> createState() => _RechazoDialogState();
}

class _RechazoDialogState extends State<_RechazoDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('¿Rechazar esta solicitud?'),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Motivo (opcional)',
          hintText: 'Por ejemplo: la foto del dorso está borrosa.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Volver'),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: FletarColors.destructive,
          ),
          onPressed: () {
            final comentario = _controller.text.trim();
            Navigator.pop(
              context,
              _MotivoRechazo(comentario.isEmpty ? null : comentario),
            );
          },
          child: const Text('Rechazar'),
        ),
      ],
    );
  }
}

class _EstadoChip extends StatelessWidget {
  const _EstadoChip({required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final color = switch (estado) {
      'Aprobada' => FletarColors.success,
      'Rechazada' => FletarColors.destructive,
      _ => FletarColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        estado,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Los documentos se piden como bytes (son privados, no tienen URL pública) y
/// se muestran recién cuando llegaron los dos.
class _DocumentosDialog extends StatefulWidget {
  const _DocumentosDialog({required this.verificacion, required this.api});

  final VerificacionIdentidadAdmin verificacion;
  final AdminApi api;

  @override
  State<_DocumentosDialog> createState() => _DocumentosDialogState();
}

class _DocumentosDialogState extends State<_DocumentosDialog> {
  late final Future<(Uint8List, Uint8List)> _documentos = Future.wait([
    widget.api.descargarDocumentoVerificacion(widget.verificacion.id, 'frente'),
    widget.api.descargarDocumentoVerificacion(widget.verificacion.id, 'dorso'),
  ]).then((bytes) => (bytes[0], bytes[1]));

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Documento de ${widget.verificacion.usuarioNombre}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: FutureBuilder<(Uint8List, Uint8List)>(
                  future: _documentos,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(mensajeDeError(snapshot.error!)),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final (frente, dorso) = snapshot.data!;
                    return ListView(
                      shrinkWrap: true,
                      children: [
                        _documento('Frente', frente),
                        const SizedBox(height: 16),
                        _documento('Dorso', dorso),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _documento(String titulo, Uint8List bytes) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(bytes, fit: BoxFit.contain, width: double.infinity),
      ),
    ],
  );
}
