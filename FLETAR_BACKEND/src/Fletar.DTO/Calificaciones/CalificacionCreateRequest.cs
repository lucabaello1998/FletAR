using System.ComponentModel.DataAnnotations;

namespace Fletar.DTO.Calificaciones;

public class CalificacionCreateRequest
{
    [Range(1, 5, ErrorMessage = "El puntaje debe estar entre 1 y 5.")]
    public int Puntaje { get; set; }

    [StringLength(500, ErrorMessage = "El comentario no puede superar los 500 caracteres.")]
    public string? Comentario { get; set; }
}
