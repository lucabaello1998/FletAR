/// Datos de contexto para el AppBar de la pantalla de chat (título de la
/// publicación y, si se conoce desde donde se navegó, el nombre de la otra
/// parte de la conversación) - viajan por `extra` de go_router porque no son
/// parte de la URL en sí (el chat funciona igual sólo con el `ofertaId` del
/// path, ver ChatScreen). Sin `extra` (por ej. una recarga del navegador en
/// web, que pierde ese estado en memoria) el chat sigue funcionando, sólo con
/// un título más genérico - a diferencia de "editar publicación", que sin sus
/// datos no puede mostrar nada útil.
class ChatRouteArgs {
  const ChatRouteArgs({required this.tituloPublicacion, this.otraParteNombre});

  final String tituloPublicacion;
  final String? otraParteNombre;
}
