namespace Fletar.DAL.Models;

/// Foto de la carga que se quiere transportar (Fase 8) - pública, visible para
/// cualquiera que vea el detalle de la publicación, a diferencia de la foto de
/// vehículo de un Usuario (que es un dato de su perfil, no de una Publicacion
/// puntual - ver Usuario.FotoUrl). NombreArchivo es sólo el nombre generado en
/// disco (GUID + extensión, nunca el nombre original que manda el cliente) -
/// la URL completa se construye en el service a partir de él (ver
/// IAlmacenamientoArchivosService.ConstruirUrlRelativa), nunca se persiste la
/// URL ya armada para no atar la tabla a un host puntual.
public class PublicacionFoto
{
    /// Tope simple para que nadie suba una cantidad desmedida de fotos a una
    /// sola publicación - no hay un requerimiento de negocio detrás del número
    /// exacto, sólo una cota razonable (ver CLAUDE.md, Fase 8).
    public const int CantidadMaximaFotos = 8;

    public int Id { get; set; }
    public int PublicacionId { get; set; }
    public string NombreArchivo { get; set; } = null!;
    public int Orden { get; set; }
    public DateTime FechaSubida { get; set; }
}
