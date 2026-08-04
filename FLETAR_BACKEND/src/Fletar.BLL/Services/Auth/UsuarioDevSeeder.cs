using Fletar.DAL;
using Fletar.DAL.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace Fletar.BLL.Services.Auth;

/// Solo se ejecuta en Development (ver Program.cs). Nunca modifica una fila
/// existente: si el email ya está tomado (por este seeder o por un registro
/// real), no hace nada.
public class UsuarioDevSeeder(FletarDbContext db) : IUsuarioDevSeeder
{
    public const string EmailAdmin = "admin@fletar.ar";
    public const string PasswordAdmin = "FletAR.Dev.2026";

    private static readonly PasswordHasher<Usuario> Hasher = new();

    public async Task SembrarAsync()
    {
        var yaExiste = await db.Usuarios.AnyAsync(u => u.Email == EmailAdmin);
        if (yaExiste) return;

        var admin = new Usuario
        {
            Nombre = "Admin FletAR",
            Email = EmailAdmin,
            Rol = Rol.Admin,
            FechaRegistro = DateTime.UtcNow,
            Activo = true
        };
        admin.PasswordHash = Hasher.HashPassword(admin, PasswordAdmin);

        db.Usuarios.Add(admin);
        await db.SaveChangesAsync();
    }
}
