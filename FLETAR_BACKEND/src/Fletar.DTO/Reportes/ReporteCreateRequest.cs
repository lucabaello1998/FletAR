namespace Fletar.DTO.Reportes;

public class ReporteCreateRequest
{
    public string Motivo { get; set; } = null!;
    public string? Comentario { get; set; }
}
