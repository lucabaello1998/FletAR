using System.ComponentModel.DataAnnotations;

namespace Fletar.DTO.Publicaciones;

/// Mismos límites que `PublicacionCreateRequest`: sin esto, el PUT aceptaba
/// strings sin tope (las columnas son `text` en Postgres) y guardaba
/// descripciones/direcciones enormes que el POST rechaza.
public class PublicacionUpdateRequest
{
    [Required(ErrorMessage = "El título es obligatorio.")]
    [StringLength(120, MinimumLength = 3, ErrorMessage = "El título debe tener entre 3 y 120 caracteres.")]
    public string Titulo { get; set; } = null!;

    [Required(ErrorMessage = "La descripción es obligatoria.")]
    [StringLength(2000, MinimumLength = 10, ErrorMessage = "La descripción debe tener entre 10 y 2000 caracteres.")]
    public string Descripcion { get; set; } = null!;

    [Range(1, int.MaxValue, ErrorMessage = "La categoría de carga es obligatoria.")]
    public int CategoriaCargaId { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "El tipo de vehículo no es válido.")]
    public int? TipoVehiculoSugeridoId { get; set; }

    [Range(-90d, 90d, ErrorMessage = "La latitud de origen debe estar entre -90 y 90.")]
    public double Latitud { get; set; }

    [Range(-180d, 180d, ErrorMessage = "La longitud de origen debe estar entre -180 y 180.")]
    public double Longitud { get; set; }

    [Required(ErrorMessage = "La dirección de origen es obligatoria.")]
    [StringLength(300, MinimumLength = 3, ErrorMessage = "La dirección de origen debe tener entre 3 y 300 caracteres.")]
    public string OrigenDireccionTexto { get; set; } = null!;

    [Range(-90d, 90d, ErrorMessage = "La latitud de destino debe estar entre -90 y 90.")]
    public double? DestinoLatitud { get; set; }

    [Range(-180d, 180d, ErrorMessage = "La longitud de destino debe estar entre -180 y 180.")]
    public double? DestinoLongitud { get; set; }

    [StringLength(300, ErrorMessage = "La dirección de destino no puede superar los 300 caracteres.")]
    public string? DestinoDireccionTexto { get; set; }

    public DateTime? FechaDeseada { get; set; }
}
