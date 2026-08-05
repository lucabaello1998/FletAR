import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/fletar_colors.dart';
import '../usuarios_providers.dart';

/// Indicador chico de reputación ("★ 4.5 (12)" o "Sin calificaciones") para
/// mostrar al lado del nombre de quien publica/oferta. Mientras carga muestra
/// un espacio vacío en vez de un spinner para no saltar el layout de la fila;
/// si falla el pedido simplemente no muestra nada - no es información crítica.
class ReputacionIndicador extends ConsumerWidget {
  const ReputacionIndicador({required this.usuarioId, super.key});

  final int usuarioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarioState = ref.watch(usuarioPublicoProvider(usuarioId));

    return usuarioState.when(
      data: (usuario) {
        const estilo = TextStyle(color: FletarColors.mutedForeground, fontSize: 12);
        if (!usuario.tieneCalificaciones) {
          return const Text('Sin calificaciones', style: estilo);
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, size: 14, color: FletarColors.warning),
            const SizedBox(width: 2),
            Text(
              '${usuario.promedioCalificacion!.toStringAsFixed(1)} (${usuario.cantidadCalificaciones})',
              style: estilo,
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
