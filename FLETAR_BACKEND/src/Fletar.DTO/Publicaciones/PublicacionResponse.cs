namespace Fletar.DTO.Publicaciones;

public class PublicacionResponse
{
    public int Id { get; set; }
    public int UsuarioId { get; set; }
    public string Titulo { get; set; } = null!;
    public string Descripcion { get; set; } = null!;
    public int CategoriaCargaId { get; set; }
    public int? TipoVehiculoSugeridoId { get; set; }
    public double Latitud { get; set; }
    public double Longitud { get; set; }
    public string OrigenDireccionTexto { get; set; } = null!;
    public double? DestinoLatitud { get; set; }
    public double? DestinoLongitud { get; set; }
    public string? DestinoDireccionTexto { get; set; }
    public DateTime? FechaDeseada { get; set; }
    public DateTime FechaPublicacion { get; set; }
    public string Estado { get; set; } = null!;
    public int? OfertaAceptadaId { get; set; }
}
