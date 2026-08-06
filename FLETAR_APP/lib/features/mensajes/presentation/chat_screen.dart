import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errores.dart';
import '../../../core/theme/fletar_colors.dart';
import '../../auth/auth_providers.dart';
import '../domain/mensaje.dart';
import '../mensajes_providers.dart';

/// Chat de una Oferta puntual (Fase 7): conversación entre el dueño de la
/// publicación y el oferente de esa oferta - accesible tanto desde el detalle
/// de una publicación (dueño, junto a cada oferta) como desde "Mis ofertas"
/// (fletero, sobre su propia oferta) - ver PublicacionDetailScreen y
/// PublicacionesListScreen. `tituloPublicacion`/`otraParteNombre` son sólo
/// para contexto visual en el AppBar; el chat funciona igual sin ellos (ver
/// ChatRouteArgs).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    required this.ofertaId,
    required this.tituloPublicacion,
    this.otraParteNombre,
    super.key,
  });

  final int ofertaId;
  final String tituloPublicacion;
  final String? otraParteNombre;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textoController = TextEditingController();
  final _scrollController = ScrollController();
  bool _enviando = false;

  @override
  void dispose() {
    _textoController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _desplazarAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _enviar() async {
    final texto = _textoController.text.trim();
    if (texto.isEmpty || _enviando) return;

    setState(() => _enviando = true);
    try {
      await ref.read(mensajesDeOfertaProvider(widget.ofertaId).notifier).enviar(texto);
      _textoController.clear();
      _desplazarAlFinal();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mensajesState = ref.watch(mensajesDeOfertaProvider(widget.ofertaId));
    final usuarioActualId = ref.watch(authControllerProvider).valueOrNull?.id;

    // Cada mensaje nuevo (propio o de la otra parte) empuja la lista al
    // fondo, igual que cualquier chat estándar - se escucha acá (no sólo tras
    // `_enviar`) porque un mensaje puede llegar en vivo por SignalR sin que
    // esta pantalla haya disparado ninguna acción.
    ref.listen(mensajesDeOfertaProvider(widget.ofertaId), (anterior, actual) {
      final cantidadAnterior = anterior?.valueOrNull?.length ?? 0;
      final cantidadActual = actual.valueOrNull?.length ?? 0;
      if (cantidadActual > cantidadAnterior) _desplazarAlFinal();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otraParteNombre != null ? 'Chat con ${widget.otraParteNombre}' : 'Chat'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.tituloPublicacion,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: mensajesState.when(
                data: (mensajes) => _ListaMensajes(
                  mensajes: mensajes,
                  usuarioActualId: usuarioActualId,
                  scrollController: _scrollController,
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: FletarColors.destructive),
                        const SizedBox(height: 12),
                        Text(mensajeDeError(error), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => ref.invalidate(mensajesDeOfertaProvider(widget.ofertaId)),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textoController,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: mensajeTextoLargoMaximo,
                      textInputAction: TextInputAction.send,
                      decoration: const InputDecoration(
                        hintText: 'Escribí un mensaje...',
                        border: OutlineInputBorder(),
                        counterText: '',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _enviar(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _enviando
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton.filled(
                          onPressed: _enviar,
                          icon: const Icon(Icons.send),
                          tooltip: 'Enviar',
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListaMensajes extends StatelessWidget {
  const _ListaMensajes({
    required this.mensajes,
    required this.usuarioActualId,
    required this.scrollController,
  });

  final List<Mensaje> mensajes;
  final int? usuarioActualId;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (mensajes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Todavía no hay mensajes.\nEscribí el primero para arrancar la conversación.',
            textAlign: TextAlign.center,
            style: TextStyle(color: FletarColors.mutedForeground),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: mensajes.length,
      itemBuilder: (context, index) {
        final mensaje = mensajes[index];
        final esPropio = usuarioActualId != null && mensaje.remitenteId == usuarioActualId;
        return _BurbujaMensaje(mensaje: mensaje, esPropio: esPropio);
      },
    );
  }
}

class _BurbujaMensaje extends StatelessWidget {
  const _BurbujaMensaje({required this.mensaje, required this.esPropio});

  final Mensaje mensaje;
  final bool esPropio;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: esPropio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: esPropio ? FletarColors.primary.withValues(alpha: 0.14) : FletarColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FletarColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!esPropio)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  mensaje.remitenteNombre,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: FletarColors.secondary,
                  ),
                ),
              ),
            Text(mensaje.texto),
            const SizedBox(height: 2),
            Text(
              _formatearHora(mensaje.fechaEnvio),
              style: const TextStyle(fontSize: 10, color: FletarColors.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatearHora(DateTime fecha) {
  final local = fecha.toLocal();
  final hora = local.hour.toString().padLeft(2, '0');
  final minuto = local.minute.toString().padLeft(2, '0');
  return '$hora:$minuto';
}
