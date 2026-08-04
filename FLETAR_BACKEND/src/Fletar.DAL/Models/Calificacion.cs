namespace Fletar.DAL.Models;

public class Calificacion
{
    public int Id { get; set; }
    public int PublicacionId { get; set; }
    public int UsuarioQueCalificaId { get; set; }
    public int UsuarioCalificadoId { get; set; }
    public int Puntaje { get; set; }
    public string? Comentario { get; set; }
    public DateTime FechaCalificacion { get; set; }
}
