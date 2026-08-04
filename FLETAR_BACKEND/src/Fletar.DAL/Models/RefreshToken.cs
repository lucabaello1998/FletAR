namespace Fletar.DAL.Models;

public class RefreshToken
{
    public Guid Id { get; set; }
    public int UsuarioId { get; set; }
    public Guid FamiliaId { get; set; }
    public string TokenHash { get; set; } = null!;
    public DateTime FechaCreacion { get; set; }
    public DateTime FechaExpiracion { get; set; }
    public DateTime? FechaRevocacion { get; set; }
    public Guid? ReemplazadoPorId { get; set; }
}
