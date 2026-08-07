import 'package:flutter/material.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme/fletar_colors.dart';

/// Círculo con la foto de vehículo de un usuario (Fase 8), o un ícono
/// placeholder si todavía no subió ninguna. Compartido entre el perfil propio
/// (`mi_perfil_screen.dart`, donde además se puede cambiar) y el perfil
/// público de cualquier otro usuario (`usuario_publico_screen.dart`,
/// sólo lectura) - misma representación visual en los dos lugares.
class FotoVehiculoAvatar extends StatelessWidget {
  const FotoVehiculoAvatar({required this.fotoUrl, this.tamanio = 140, super.key});

  final String? fotoUrl;
  final double tamanio;

  @override
  Widget build(BuildContext context) {
    final url = fotoUrl;
    return Container(
      width: tamanio,
      height: tamanio,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: FletarColors.border),
      child: url == null
          ? Icon(Icons.local_shipping_outlined, size: tamanio * 0.4, color: FletarColors.mutedForeground)
          : Image.network(
              resolverUrlMedia(url),
              width: tamanio,
              height: tamanio,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.local_shipping_outlined, size: tamanio * 0.4, color: FletarColors.mutedForeground),
            ),
    );
  }
}
