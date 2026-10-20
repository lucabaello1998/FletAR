import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errores.dart';
import '../../../core/theme/fletar_colors.dart';
import '../domain/verificacion_identidad.dart';
import '../usuarios_providers.dart';

/// Verificación de identidad (Fase 9) del usuario logueado: subir frente y
/// dorso del documento y ver en qué estado está la solicitud.
///
/// Es la única pantalla que usa `POST /api/usuarios/me/verificacion-identidad`;
/// sin ella ese endpoint no tendría camino real de UI (misma moraleja que "Mis
/// ofertas" en la Fase 3). Los documentos no se vuelven a mostrar acá: sólo un
/// admin los ve, desde el panel de moderación.
class VerificacionIdentidadScreen extends ConsumerStatefulWidget {
  const VerificacionIdentidadScreen({super.key});

  @override
  ConsumerState<VerificacionIdentidadScreen> createState() =>
      _VerificacionIdentidadScreenState();
}

class _VerificacionIdentidadScreenState
    extends ConsumerState<VerificacionIdentidadScreen> {
  XFile? _frente;
  Uint8List? _frenteBytes;
  XFile? _dorso;
  Uint8List? _dorsoBytes;
  bool _enviando = false;

  Future<void> _elegir(String lado) async {
    final origen = await _elegirOrigen();
    if (origen == null) return;

    final archivo = await ImagePicker().pickImage(
      source: origen,
      imageQuality: 85,
    );
    if (archivo == null) return;

    final bytes = await archivo.readAsBytes();
    if (!mounted) return;
    setState(() {
      if (lado == 'frente') {
        _frente = archivo;
        _frenteBytes = bytes;
      } else {
        _dorso = archivo;
        _dorsoBytes = bytes;
      }
    });
  }

  Future<ImageSource?> _elegirOrigen() {
    // Mismo criterio que MiPerfilScreen: la cámara no existe en web/desktop,
    // así que sólo se ofrece si el picker dice que la soporta.
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

  Future<void> _enviar() async {
    final frente = _frente;
    final dorso = _dorso;
    if (frente == null || dorso == null) return;

    setState(() => _enviando = true);
    try {
      await ref
          .read(verificacionIdentidadProvider.notifier)
          .solicitar(frente: frente, dorso: dorso);
      if (!mounted) return;
      setState(() {
        _frente = null;
        _frenteBytes = null;
        _dorso = null;
        _dorsoBytes = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud enviada. Un admin la va a revisar.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(verificacionIdentidadProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Verificación de identidad')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: state.when(
              data: (verificacion) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.badge_outlined,
                      size: 56,
                      color: FletarColors.primary,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Verificá tu identidad para dar más confianza cuando publicás u ofertás. '
                      'Sólo un administrador puede ver las fotos de tu documento.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: FletarColors.mutedForeground),
                    ),
                    const SizedBox(height: 20),
                    if (verificacion != null) ...[
                      _EstadoActual(verificacion: verificacion),
                      const SizedBox(height: 20),
                    ],
                    if (verificacion == null || verificacion.rechazada) ...[
                      const Text(
                        'Frente del documento',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      _DocumentoElegido(
                        bytes: _frenteBytes,
                        ayuda: 'Donde está tu foto y tus datos.',
                        onTap: _enviando ? null : () => _elegir('frente'),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Dorso del documento',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      _DocumentoElegido(
                        bytes: _dorsoBytes,
                        ayuda: 'Donde está el número de trámite y la firma.',
                        onTap: _enviando ? null : () => _elegir('dorso'),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed:
                            _enviando || _frente == null || _dorso == null
                            ? null
                            : _enviar,
                        icon: _enviando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_outlined),
                        label: Text(
                          verificacion?.rechazada == true
                              ? 'Volver a enviar'
                              : 'Enviar solicitud',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Se aceptan fotos JPG, PNG o WebP de hasta 5 MB cada una.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: FletarColors.mutedForeground,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(mensajeDeError(error), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => ref
                            .read(verificacionIdentidadProvider.notifier)
                            .recargar(),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EstadoActual extends StatelessWidget {
  const _EstadoActual({required this.verificacion});

  final VerificacionIdentidad verificacion;

  @override
  Widget build(BuildContext context) {
    final (icono, color, titulo, detalle) = switch (verificacion.estado) {
      'Aprobada' => (
        Icons.verified_user,
        FletarColors.success,
        'Identidad verificada',
        'Ya tenés la insignia en tu perfil público.',
      ),
      'Rechazada' => (
        Icons.error_outline,
        FletarColors.destructive,
        'La solicitud fue rechazada',
        verificacion.comentarioAdmin?.isNotEmpty == true
            ? verificacion.comentarioAdmin!
            : 'Volvé a subir las fotos del documento para que la revisen de nuevo.',
      ),
      _ => (
        Icons.hourglass_top,
        FletarColors.warning,
        'Solicitud en revisión',
        'Un administrador está revisando tus documentos. No hace falta que hagas nada más.',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  detalle,
                  style: const TextStyle(
                    color: FletarColors.mutedForeground,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentoElegido extends StatelessWidget {
  const _DocumentoElegido({
    required this.bytes,
    required this.ayuda,
    required this.onTap,
  });

  final Uint8List? bytes;
  final String ayuda;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final datos = bytes;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 150,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: FletarColors.border.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FletarColors.border),
        ),
        child: datos == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_a_photo_outlined,
                    size: 32,
                    color: FletarColors.mutedForeground,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ayuda,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: FletarColors.mutedForeground,
                      fontSize: 12,
                    ),
                  ),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(datos, fit: BoxFit.cover),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Cambiar',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
