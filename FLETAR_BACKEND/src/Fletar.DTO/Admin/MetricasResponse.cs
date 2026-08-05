namespace Fletar.DTO.Admin;

public class MetricasResponse
{
    public int TotalUsuarios { get; set; }
    public int TotalPublicaciones { get; set; }
    public int PublicacionesPublicadas { get; set; }
    public int PublicacionesOfertaAceptada { get; set; }
    public int PublicacionesEnCurso { get; set; }
    public int PublicacionesCompletadas { get; set; }
    public int PublicacionesCanceladas { get; set; }
    public int TotalOfertas { get; set; }
    public double? PromedioCalificacionGlobal { get; set; }
    public int ReportesPendientes { get; set; }
}
