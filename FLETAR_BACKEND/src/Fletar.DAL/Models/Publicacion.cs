using NetTopologySuite.Geometries;

namespace Fletar.DAL.Models;

public enum EstadoPublicacion
{
    Publicada,
    OfertaAceptada,
    EnCurso,
    Completada,
    Cancelada
}

public class Publicacion
{
    public int Id { get; set; }
    public int UsuarioId { get; set; }
    public string Titulo { get; set; } = null!;
    public string Descripcion { get; set; } = null!;
    public int CategoriaCargaId { get; set; }
    public int? TipoVehiculoSugeridoId { get; set; }
    public Point Origen { get; set; } = null!;
    public string OrigenDireccionTexto { get; set; } = null!;
    public Point? Destino { get; set; }
    public string? DestinoDireccionTexto { get; set; }
    public DateTime? FechaDeseada { get; set; }
    public DateTime FechaPublicacion { get; set; }
    public EstadoPublicacion Estado { get; set; } = EstadoPublicacion.Publicada;
    public int? OfertaAceptadaId { get; set; }
}
