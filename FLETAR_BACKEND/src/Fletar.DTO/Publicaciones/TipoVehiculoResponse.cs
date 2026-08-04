namespace Fletar.DTO.Publicaciones;

public class TipoVehiculoResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = null!;
    public decimal? CapacidadKg { get; set; }
    public decimal? VolumenM3 { get; set; }
    public bool Activo { get; set; }
}
