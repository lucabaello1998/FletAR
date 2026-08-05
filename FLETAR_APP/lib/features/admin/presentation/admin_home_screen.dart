import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errores.dart';
import '../../../core/theme/fletar_colors.dart';
import '../../reportes/domain/reporte.dart';
import '../admin_providers.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel admin'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Reportes', icon: Icon(Icons.flag_outlined)),
            Tab(text: 'Usuarios', icon: Icon(Icons.people_outline)),
            Tab(text: 'Métricas', icon: Icon(Icons.bar_chart_outlined)),
          ]),
        ),
        body: const TabBarView(children: [
          _ReportesTab(),
          _UsuariosTab(),
          _MetricasTab(),
        ]),
      ),
    );
  }
}

class _ReportesTab extends ConsumerWidget {
  const _ReportesTab();

  Future<void> _cancelarPublicacion(BuildContext context, WidgetRef ref, Reporte reporte) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar esta publicación?'),
        content: Text('Se va a cancelar "${reporte.publicacionTitulo}" y el reporte queda revisado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Volver')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancelar publicación')),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await ref.read(reportesPendientesProvider.notifier).cancelarPublicacion(reporte.publicacionId);
      await ref.read(reportesPendientesProvider.notifier).revisar(reporte.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
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
                      Text(reporte.publicacionTitulo, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('Motivo: ${reporte.motivo}'),
                      if (reporte.comentario != null && reporte.comentario!.isNotEmpty)
                        Text(reporte.comentario!, style: const TextStyle(color: FletarColors.mutedForeground)),
                      const SizedBox(height: 4),
                      Text(
                        'Reportado por ${reporte.usuarioReportanteNombre}',
                        style: const TextStyle(color: FletarColors.mutedForeground, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => context.push('/publicaciones/${reporte.publicacionId}'),
                            child: const Text('Ver publicación'),
                          ),
                          TextButton(
                            onPressed: () => ref.read(reportesPendientesProvider.notifier).descartar(reporte.id),
                            child: const Text('Descartar'),
                          ),
                          TextButton(
                            onPressed: () => ref.read(reportesPendientesProvider.notifier).revisar(reporte.id),
                            child: const Text('Marcar revisado'),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: FletarColors.destructive),
                            onPressed: () => _cancelarPublicacion(context, ref, reporte),
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
        error: (error, stackTrace) => Center(child: Text(mensajeDeError(error))),
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
            onSubmitted: (valor) =>
                ref.read(adminUsuariosProvider.notifier).buscar(valor.trim().isEmpty ? null : valor.trim()),
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
                        style: const TextStyle(color: FletarColors.mutedForeground, fontSize: 12),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: usuario.activo ? FletarColors.destructive : FletarColors.success,
                    ),
                    onPressed: () => usuario.activo
                        ? ref.read(adminUsuariosProvider.notifier).desactivar(usuario.id)
                        : ref.read(adminUsuariosProvider.notifier).reactivar(usuario.id),
                    child: Text(usuario.activo ? 'Desactivar' : 'Reactivar'),
                  ),
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(child: Text(mensajeDeError(error))),
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
          _fila('Con oferta aceptada', '${metricas.publicacionesOfertaAceptada}'),
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
