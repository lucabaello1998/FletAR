namespace Fletar.DTO.Reportes;

public class ReporteResponse
{
    public int Id { get; set; }
    public int PublicacionId { get; set; }
    public string PublicacionTitulo { get; set; } = null!;
    public int UsuarioReportanteId { get; set; }
    public string UsuarioReportanteNombre { get; set; } = null!;
    public string Motivo { get; set; } = null!;
    public string? Comentario { get; set; }
    public DateTime FechaReporte { get; set; }
    public string Estado { get; set; } = null!;
}
