namespace Fletar.DAL.Models;

public enum EstadoOferta
{
    Pendiente,
    Aceptada,
    Rechazada,
    Retirada
}

public class Oferta
{
    public int Id { get; set; }
    public int PublicacionId { get; set; }
    public int UsuarioId { get; set; }
    public decimal Monto { get; set; }
    public string? Mensaje { get; set; }
    public DateTime FechaOferta { get; set; }
    public EstadoOferta Estado { get; set; } = EstadoOferta.Pendiente;
}
