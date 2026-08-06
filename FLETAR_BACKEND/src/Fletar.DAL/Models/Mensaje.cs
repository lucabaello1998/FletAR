namespace Fletar.DAL.Models;

/// Chat de una Oferta puntual (Fase 7): conversación entre el dueño de la
/// publicación y el oferente de esa oferta en particular - dos fleteros
/// distintos que ofertaron sobre la misma publicación no comparten canal ni
/// se ven los mensajes entre ellos, porque cada uno tiene su propia Oferta y
/// por lo tanto su propio hilo de Mensajes.
public class Mensaje
{
    public const int TextoLargoMaximo = 2000;

    public int Id { get; set; }
    public int OfertaId { get; set; }
    public int RemitenteId { get; set; }
    public string Texto { get; set; } = null!;
    public DateTime FechaEnvio { get; set; }
}
