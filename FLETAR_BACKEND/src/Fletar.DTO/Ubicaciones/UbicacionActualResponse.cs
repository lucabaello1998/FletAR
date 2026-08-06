namespace Fletar.DTO.Ubicaciones;

/// Última posición conocida de un fletero (ubicación en vivo, Fase 6). Se
/// devuelve como resultado de UbicacionHub.SeguirFletero para que quien recién
/// se suma a un tracking vea algo de inmediato, sin esperar el próximo ping.
public class UbicacionActualResponse
{
    public int UsuarioId { get; set; }
    public double Lat { get; set; }
    public double Lng { get; set; }
    public DateTime Fecha { get; set; }
}
