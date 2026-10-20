import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errores.dart';
import '../../../core/theme/fletar_colors.dart';
import '../usuarios_providers.dart';
import 'foto_vehiculo_avatar.dart';

/// Perfil público de un usuario puntual: nombre, foto de vehículo (Fase 8,
/// señal de confianza para cuando oferta como fletero) y reputación agregada.
/// Se llega acá tocando el nombre/reputación de alguien en el detalle de una
/// publicación (dueño o cualquier oferente) - ver publicacion_detail_screen.dart.
class UsuarioPublicoScreen extends ConsumerWidget {
  const UsuarioPublicoScreen({required this.usuarioId, super.key});

  final int usuarioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarioState = ref.watch(usuarioPublicoProvider(usuarioId));

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: usuarioState.when(
        data: (usuario) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  FotoVehiculoAvatar(fotoUrl: usuario.fotoUrl),
                  const SizedBox(height: 16),
                  Text(
                    usuario.nombre,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  if (usuario.estaVerificado)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_user,
                          size: 18,
                          color: FletarColors.success,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Identidad verificada',
                          style: TextStyle(
                            color: FletarColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  if (usuario.estaVerificado) const SizedBox(height: 8),
                  if (usuario.tieneCalificaciones)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: FletarColors.warning),
                        const SizedBox(width: 4),
                        Text(
                          '${usuario.promedioCalificacion!.toStringAsFixed(1)} '
                          '(${usuario.cantidadCalificaciones} calificaci'
                          '${usuario.cantidadCalificaciones == 1 ? 'ón' : 'ones'})',
                          style: const TextStyle(
                            color: FletarColors.mutedForeground,
                          ),
                        ),
                      ],
                    )
                  else
                    const Text(
                      'Todavía no tiene calificaciones',
                      style: TextStyle(color: FletarColors.mutedForeground),
                    ),
                ],
              ),
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: FletarColors.destructive,
                ),
                const SizedBox(height: 12),
                Text(mensajeDeError(error), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(usuarioPublicoProvider(usuarioId)),
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
