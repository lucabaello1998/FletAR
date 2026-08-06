namespace Fletar.DTO.Mensajes;

public class MensajeResponse
{
    public int Id { get; set; }
    public int OfertaId { get; set; }
    public int RemitenteId { get; set; }
    public string RemitenteNombre { get; set; } = null!;
    public string Texto { get; set; } = null!;
    public DateTime FechaEnvio { get; set; }
}
