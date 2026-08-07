/// Una foto de la carga de una Publicación (Fase 8) - refleja
/// `PublicacionFotoResponse` del backend. Son públicas (cualquiera que vea el
/// detalle de la publicación las ve), sólo el dueño puede agregar/borrar.
///
/// `url` es relativa al host de la API (no a `/api`) - usar `resolverUrlMedia`
/// (core/network/dio_client.dart) antes de pasarla a `Image.network`.
class PublicacionFoto {
  const PublicacionFoto({required this.id, required this.url, required this.orden});

  factory PublicacionFoto.fromJson(Map<String, dynamic> json) => PublicacionFoto(
        id: json['id'] as int,
        url: json['url'] as String,
        orden: json['orden'] as int,
      );

  final int id;
  final String url;
  final int orden;
}
