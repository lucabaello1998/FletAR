import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/fletar_colors.dart';
import '../data/geocoding_api.dart';
import '../domain/sugerencia_direccion.dart';

/// Campo de dirección con autocompletado contra OpenStreetMap.
///
/// El texto sigue siendo libre: si el geocoder no encuentra nada (o no hay
/// red), se puede escribir la dirección a mano y marcar el punto en el mapa,
/// igual que antes. El autocompletado es una ayuda, no un requisito.
class DireccionAutocompleteField extends ConsumerStatefulWidget {
  const DireccionAutocompleteField({
    required this.controller,
    required this.label,
    this.validator,
    this.onSeleccionada,
    this.textoAyuda,
    this.hintText,
    this.api,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;

  /// Se dispara al elegir una sugerencia: la pantalla mueve el mapa y fija el
  /// pin en esas coordenadas.
  final ValueChanged<SugerenciaDireccion>? onSeleccionada;

  final String? textoAyuda;
  final String? hintText;

  /// Inyectable para tests; en producción sale de `geocodingApiProvider`.
  final GeocodingApi? api;

  @override
  ConsumerState<DireccionAutocompleteField> createState() => _DireccionAutocompleteFieldState();
}

class _DireccionAutocompleteFieldState extends ConsumerState<DireccionAutocompleteField> {
  static const _debounce = Duration(milliseconds: 650);

  final _focusNode = FocusNode();
  Timer? _timerDebounce;
  List<SugerenciaDireccion> _opciones = const [];
  bool _buscando = false;
  bool _sinResultados = false;
  bool _falloElBuscador = false;
  int _consultaId = 0;
  String _textoConsultado = '';

  /// Grupo de toques compartido entre el campo y la lista de sugerencias: así,
  /// tocar una sugerencia cuenta como "adentro" y no dispara el
  /// `onTapOutside` que cierra la lista antes de que el tap llegue al ListTile.
  final Object _grupoDeToques = Object();

  GeocodingApi get _api => widget.api ?? ref.read(geocodingApiProvider);

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_alCambiarFoco);
    widget.controller.addListener(_alCambiarTextoDesdeAfuera);
  }

  @override
  void dispose() {
    _timerDebounce?.cancel();
    _focusNode.removeListener(_alCambiarFoco);
    _focusNode.dispose();
    widget.controller.removeListener(_alCambiarTextoDesdeAfuera);
    super.dispose();
  }

  void _alCambiarFoco() {
    if (mounted) setState(() {});
  }

  /// Cuando la pantalla escribe la dirección (geocodificación reversa al tocar
  /// el mapa) hay que descartar las sugerencias de la búsqueda anterior: si no,
  /// quedarían flotando resultados que ya no corresponden al texto del campo.
  void _alCambiarTextoDesdeAfuera() {
    if (_opciones.isEmpty && !_sinResultados && !_falloElBuscador) return;
    if (widget.controller.text.trim() == _textoConsultado) return;
    if (!mounted) return;
    // También hay que cortar la búsqueda pendiente: si se tocó el mapa mientras
    // el debounce estaba corriendo, la respuesta vieja reabriría la lista con
    // sugerencias que ya no corresponden al texto del campo.
    _timerDebounce?.cancel();
    _consultaId++;
    setState(() {
      _opciones = const [];
      _sinResultados = false;
      _falloElBuscador = false;
      _buscando = false;
    });
  }

  void _alEscribir(String texto) {
    _timerDebounce?.cancel();

    final consulta = texto.trim();
    if (consulta.length < minimoCaracteresBusqueda) {
      setState(() {
        _opciones = const [];
        _sinResultados = false;
        _falloElBuscador = false;
        _buscando = false;
      });
      return;
    }

    setState(() => _buscando = true);
    _timerDebounce = Timer(_debounce, () => _buscar(consulta));
  }

  Future<void> _buscar(String consulta) async {
    final id = ++_consultaId;
    _textoConsultado = consulta;

    try {
      final resultados = await _api.buscar(consulta);
      if (!mounted || id != _consultaId) return;

      setState(() {
        _opciones = resultados;
        _sinResultados = resultados.isEmpty;
        _falloElBuscador = false;
        _buscando = false;
      });
    } on GeocodingNoDisponible {
      if (!mounted || id != _consultaId) return;

      setState(() {
        _opciones = const [];
        _sinResultados = false;
        _falloElBuscador = true;
        _buscando = false;
      });
    }
  }

  void _seleccionar(SugerenciaDireccion sugerencia) {
    _timerDebounce?.cancel();
    _consultaId++; // descarta una búsqueda en vuelo
    _textoConsultado = sugerencia.direccionCorta;

    widget.controller.value = TextEditingValue(
      text: sugerencia.direccionCorta,
      selection: TextSelection.collapsed(offset: sugerencia.direccionCorta.length),
    );

    setState(() {
      _opciones = const [];
      _sinResultados = false;
      _falloElBuscador = false;
      _buscando = false;
    });
    _focusNode.unfocus();
    widget.onSeleccionada?.call(sugerencia);
  }

  void _limpiar() {
    _timerDebounce?.cancel();
    _consultaId++;
    _textoConsultado = '';
    widget.controller.clear();
    setState(() {
      _opciones = const [];
      _sinResultados = false;
      _falloElBuscador = false;
      _buscando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mostrarLista =
        _focusNode.hasFocus && (_opciones.isNotEmpty || _sinResultados || _falloElBuscador);

    return TapRegion(
      groupId: _grupoDeToques,
      // Tocar afuera cierra la lista (antes quedaba abierta tapando el mapa
      // hasta elegir algo o borrar el texto).
      onTapOutside: (_) => _focusNode.unfocus(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            groupId: _grupoDeToques,
            validator: widget.validator,
            onChanged: _alEscribir,
            textInputAction: TextInputAction.search,
            onFieldSubmitted: (_) {
              if (_opciones.isNotEmpty) _seleccionar(_opciones.first);
            },
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hintText,
              helperText: widget.textoAyuda,
              helperMaxLines: 2,
              suffixIcon: _sufijo(),
            ),
          ),
          if (mostrarLista)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).cardColor,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: _falloElBuscador
                      ? _mensajeDelBuscador()
                      : _sinResultados
                          ? _sinResultadosWidget()
                          : _listaSugerencias(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sufijo() {
    if (_buscando) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (widget.controller.text.isNotEmpty) {
      return IconButton(
        icon: const Icon(Icons.clear),
        tooltip: 'Borrar dirección',
        onPressed: _limpiar,
      );
    }
    return const Padding(
      padding: EdgeInsets.all(14),
      child: Icon(Icons.search, size: 18, color: FletarColors.mutedForeground),
    );
  }

  Widget _listaSugerencias() {
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _opciones.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final sugerencia = _opciones[index];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.place_outlined, color: FletarColors.primary),
          title: Text(
            sugerencia.direccionCorta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            sugerencia.detalle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: FletarColors.mutedForeground),
          ),
          onTap: () => _seleccionar(sugerencia),
        );
      },
    );
  }

  Widget _sinResultadosWidget() {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Text(
        'No encontramos esa dirección. Podés escribirla a mano y marcar el punto en el mapa.',
        style: TextStyle(fontSize: 12, color: FletarColors.mutedForeground),
      ),
    );
  }

  Widget _mensajeDelBuscador() {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Text(
        'No pudimos buscar direcciones (revisá tu conexión). Podés escribirla a mano y marcar el punto en el mapa.',
        style: TextStyle(fontSize: 12, color: FletarColors.mutedForeground),
      ),
    );
  }
}
