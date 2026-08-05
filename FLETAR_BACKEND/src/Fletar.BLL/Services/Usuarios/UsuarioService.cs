using Fletar.DAL;
using Fletar.DTO.Usuarios;
using Microsoft.EntityFrameworkCore;

namespace Fletar.BLL.Services.Usuarios;

public class UsuarioService(FletarDbContext db) : IUsuarioService
{
    public async Task<UsuarioPublicoResponse> ObtenerPerfilPublicoAsync(int id)
    {
        var usuario = await db.Usuarios.SingleOrDefaultAsync(u => u.Id == id)
            ?? throw new KeyNotFoundException("El usuario indicado no existe.");

        var puntajes = await db.Calificaciones
            .Where(c => c.UsuarioCalificadoId == id)
            .Select(c => c.Puntaje)
            .ToListAsync();

        return new UsuarioPublicoResponse
        {
            Id = usuario.Id,
            Nombre = usuario.Nombre,
            FotoUrl = usuario.FotoUrl,
            PromedioCalificacion = puntajes.Count == 0 ? null : puntajes.Average(),
            CantidadCalificaciones = puntajes.Count
        };
    }
}
