namespace Fletar.DTO.VerificacionesIdentidad;

/// Body de POST .../rechazar - el comentario es opcional incluso ahí (el
/// admin puede rechazar sin explicar por qué). POST .../aprobar no tiene body.
public class VerificacionIdentidadRevisionRequest
{
    public string? Comentario { get; set; }
}
