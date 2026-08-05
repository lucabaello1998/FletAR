import 'package:flutter/material.dart';

import '../../../core/theme/fletar_colors.dart';
import '../domain/oferta.dart';

/// Mapeo de estado de Oferta (Pendiente/Aceptada/Rechazada/Retirada) ->
/// color/etiqueta legible, compartido entre el detalle de una publicación y
/// "Mis ofertas" para que el badge se vea siempre igual. Análogo a
/// publicacion_estado.dart, pero para el estado propio de la oferta (no
/// confundir con el estado de la publicación sobre la que se ofertó).
Color colorEstadoOferta(String estado) {
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

String etiquetaEstadoOferta(String estado) {
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

class EstadoOfertaBadge extends StatelessWidget {
  const EstadoOfertaBadge({required this.estado, super.key});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final color = colorEstadoOferta(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        etiquetaEstadoOferta(estado),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
