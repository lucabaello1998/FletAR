namespace Fletar.DTO.Ofertas;

public class OfertaResponse
{
    public int Id { get; set; }
    public int PublicacionId { get; set; }
    public int UsuarioId { get; set; }
    public string UsuarioNombre { get; set; } = null!;
    public decimal Monto { get; set; }
    public string? Mensaje { get; set; }
    public DateTime FechaOferta { get; set; }
    public string Estado { get; set; } = null!;
    public string PublicacionTitulo { get; set; } = null!;
    public string PublicacionEstado { get; set; } = null!;
}
