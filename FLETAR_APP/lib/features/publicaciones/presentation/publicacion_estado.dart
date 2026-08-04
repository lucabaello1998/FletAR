import 'package:flutter/material.dart';

import '../../../core/theme/fletar_colors.dart';
import '../domain/publicacion.dart';

/// Mapeo de estado -> color/etiqueta legible, compartido entre la lista y el
/// detalle de Publicaciones para que el badge se vea siempre igual.
Color colorEstadoPublicacion(String estado) {
  switch (estado) {
    case EstadoPublicacion.publicada:
      return FletarColors.primary;
    case EstadoPublicacion.ofertaAceptada:
      return FletarColors.secondary;
    case EstadoPublicacion.enCurso:
      return FletarColors.warning;
    case EstadoPublicacion.completada:
      return FletarColors.success;
    case EstadoPublicacion.cancelada:
      return FletarColors.destructive;
    default:
      return FletarColors.mutedForeground;
  }
}

String etiquetaEstadoPublicacion(String estado) {
  switch (estado) {
    case EstadoPublicacion.publicada:
      return 'Publicada';
    case EstadoPublicacion.ofertaAceptada:
      return 'Oferta aceptada';
    case EstadoPublicacion.enCurso:
      return 'En curso';
    case EstadoPublicacion.completada:
      return 'Completada';
    case EstadoPublicacion.cancelada:
      return 'Cancelada';
    default:
      return estado;
  }
}

class EstadoPublicacionBadge extends StatelessWidget {
  const EstadoPublicacionBadge({required this.estado, super.key});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final color = colorEstadoPublicacion(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        etiquetaEstadoPublicacion(estado),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
