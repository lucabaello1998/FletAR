using System.ComponentModel.DataAnnotations;

namespace Fletar.DTO.Reportes;

public class ReporteCreateRequest
{
    [Required(ErrorMessage = "El motivo es obligatorio.")]
    [StringLength(120, MinimumLength = 3, ErrorMessage = "El motivo debe tener entre 3 y 120 caracteres.")]
    public string Motivo { get; set; } = null!;

    [StringLength(1000, ErrorMessage = "El comentario no puede superar los 1000 caracteres.")]
    public string? Comentario { get; set; }
}
