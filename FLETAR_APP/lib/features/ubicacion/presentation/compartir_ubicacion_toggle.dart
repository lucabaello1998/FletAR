import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errores.dart';
import '../../../core/theme/fletar_colors.dart';
import '../../ofertas/domain/oferta.dart';
import '../../ofertas/ofertas_providers.dart';
import '../ubicacion_providers.dart';

/// Toggle de opt-in para compartir la posición en vivo mientras la app está
/// en foreground. Sólo se muestra si el usuario tiene alguna oferta activa
/// (Pendiente o Aceptada) - es lo único para lo que un dueño podría querer
/// seguirlo (ver `UbicacionHub.SeguirFletero` en el backend), así que sin eso
/// el toggle no tendría ningún efecto visible para nadie. Vive en la pestaña
/// "Mis ofertas" (ver publicaciones_list_screen.dart).
class CompartirUbicacionToggle extends ConsumerWidget {
  const CompartirUbicacionToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ofertas = ref.watch(misOfertasProvider).valueOrNull ?? const [];
    final tieneOfertaActiva = ofertas.any(
      (o) => o.estado == EstadoOferta.pendiente || o.estado == EstadoOferta.aceptada,
    );
    if (!tieneOfertaActiva) return const SizedBox.shrink();

    final activo = ref.watch(compartirUbicacionControllerProvider);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SwitchListTile(
        secondary: Icon(
          Icons.share_location,
          color: activo ? FletarColors.primary : FletarColors.mutedForeground,
        ),
        title: const Text('Compartir mi ubicación en vivo'),
        subtitle: Text(
          activo
              ? 'Los dueños de tus ofertas activas pueden verte en el mapa.'
              : 'Activalo para que puedan verte mientras vas a buscar el flete.',
          style: const TextStyle(fontSize: 12),
        ),
        value: activo,
        activeThumbColor: FletarColors.primary,
        onChanged: (valor) => _cambiar(context, ref, valor),
      ),
    );
  }

  Future<void> _cambiar(BuildContext context, WidgetRef ref, bool valor) async {
    final controller = ref.read(compartirUbicacionControllerProvider.notifier);
    if (!valor) {
      controller.desactivar();
      return;
    }
    try {
      await controller.activar();
    } catch (e) {
      if (!context.mounted) return;
      // `activar()` tira una excepción simple (no de Dio) cuando falta el
      // permiso de ubicación - `mensajeDeError` está pensado para errores de
      // red/API, así que acá se muestra el mensaje propio en vez de caer en
      // el genérico.
      final texto = e.toString().startsWith('Exception: ')
          ? e.toString().substring('Exception: '.length)
          : mensajeDeError(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
    }
  }
}
