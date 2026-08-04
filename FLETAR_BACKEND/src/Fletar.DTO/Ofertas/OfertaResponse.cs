namespace Fletar.DTO.Ofertas;

public class OfertaResponse
{
    public int Id { get; set; }
    public int PublicacionId { get; set; }
    public int UsuarioId { get; set; }
    public decimal Monto { get; set; }
    public string? Mensaje { get; set; }
    public DateTime FechaOferta { get; set; }
    public string Estado { get; set; } = null!;
}
