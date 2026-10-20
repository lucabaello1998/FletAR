import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errores.dart';
import '../../../core/theme/fletar_colors.dart';
import '../../auth/auth_providers.dart';
import '../domain/verificacion_identidad.dart';
import '../usuarios_providers.dart';
import 'foto_vehiculo_avatar.dart';
import 'reputacion_indicador.dart';

/// Pantalla de "mi perfil" (Fase 8) - hasta esta fase no existía ninguna
/// pantalla navegable donde el usuario logueado pudiera ver/editar algo
/// propio (sólo `ReputacionIndicador`, de sólo lectura, embebido en otras
/// pantallas). Sin esto, `PUT /api/usuarios/me/foto-vehiculo` no tendría
/// ningún camino real de UI para usarse - mismo tipo de hueco de navegación
/// que el proyecto ya encontró y cerró varias veces (ver CLAUDE.md, la
/// moraleja de "Mis ofertas" en la Fase 3). Se llega acá desde el ícono de
/// perfil en el AppBar de `PublicacionesListScreen`.
class MiPerfilScreen extends ConsumerStatefulWidget {
  const MiPerfilScreen({super.key});

  @override
  ConsumerState<MiPerfilScreen> createState() => _MiPerfilScreenState();
}

class _MiPerfilScreenState extends ConsumerState<MiPerfilScreen> {
  bool _subiendo = false;

  Future<void> _cambiarFotoVehiculo() async {
    final origen = await _elegirOrigen(context);
    if (origen == null) return;

    try {
      final archivo = await ImagePicker().pickImage(
        source: origen,
        imageQuality: 85,
      );
      if (archivo == null || !mounted) return;

      setState(() => _subiendo = true);
      final usuarioId = ref.read(authControllerProvider).valueOrNull?.id;
      final nuevaUrl = await ref
          .read(usuariosApiProvider)
          .actualizarFotoVehiculo(archivo);
      if (!mounted) return;

      // Actualiza el estado en memoria (no hay endpoint `/usuarios/me` para
      // refetchear el usuario completo - ver CLAUDE.md, gaps conocidos) y
      // marca como obsoleto el perfil público cacheado, para que quien lo
      // mire de nuevo vea la foto nueva sin tener que reabrir la app.
      ref.read(authControllerProvider.notifier).actualizarFotoUrl(nuevaUrl);
      if (usuarioId != null) ref.invalidate(usuarioPublicoProvider(usuarioId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
      }
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  Future<ImageSource?> _elegirOrigen(BuildContext context) {
    final soportaCamara = ImagePicker().supportsImageSource(ImageSource.camera);
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            if (soportaCamara)
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Tomar una foto'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
          ],
        ),
      ),
    );
  }

  String _textoVerificacion(VerificacionIdentidad? verificacion) {
    if (verificacion == null) return 'Todavía no la pediste';
    return switch (verificacion.estado) {
      'Aprobada' => 'Verificada',
      'Rechazada' => 'Rechazada - podés volver a enviarla',
      _ => 'En revisión',
    };
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authControllerProvider).valueOrNull;
    final verificacion = ref.watch(verificacionIdentidadProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: usuario == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          usuario.nombre,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          usuario.email,
                          style: const TextStyle(
                            color: FletarColors.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ReputacionIndicador(usuarioId: usuario.id),
                        const Divider(height: 40),
                        Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: const Icon(Icons.badge_outlined),
                            title: const Text('Verificación de identidad'),
                            subtitle: Text(
                              _textoVerificacion(verificacion.valueOrNull),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('/perfil/verificacion'),
                          ),
                        ),
                        const Divider(height: 40),
                        Text(
                          'Foto de tu vehículo',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Es una señal de confianza para quienes evalúan tu oferta cuando '
                          'ofertás como fletero - la ven en tu perfil público.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: FletarColors.mutedForeground,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            FotoVehiculoAvatar(fotoUrl: usuario.fotoUrl),
                            if (_subiendo)
                              const CircularProgressIndicator(
                                color: FletarColors.primary,
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _subiendo ? null : _cambiarFotoVehiculo,
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: Text(
                            usuario.fotoUrl == null
                                ? 'Agregar foto'
                                : 'Cambiar foto',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
