namespace Fletar.DAL.Models;

public enum EstadoReporte
{
    Pendiente,
    Revisado,
    Descartado
}

public class Reporte
{
    public int Id { get; set; }
    public int PublicacionId { get; set; }
    public int UsuarioReportanteId { get; set; }
    public string Motivo { get; set; } = null!;
    public string? Comentario { get; set; }
    public DateTime FechaReporte { get; set; }
    public EstadoReporte Estado { get; set; } = EstadoReporte.Pendiente;
}
