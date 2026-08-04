using Fletar.DAL.Models;
using Microsoft.EntityFrameworkCore;

namespace Fletar.DAL;

public class FletarDbContext : DbContext
{
    public FletarDbContext(DbContextOptions<FletarDbContext> options) : base(options)
    {
    }

    public DbSet<Usuario> Usuarios => Set<Usuario>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<CategoriaCarga> CategoriasCarga => Set<CategoriaCarga>();
    public DbSet<TipoVehiculo> TiposVehiculo => Set<TipoVehiculo>();
    public DbSet<Publicacion> Publicaciones => Set<Publicacion>();
    public DbSet<Oferta> Ofertas => Set<Oferta>();
    public DbSet<Calificacion> Calificaciones => Set<Calificacion>();
    public DbSet<Reporte> Reportes => Set<Reporte>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasPostgresExtension("postgis");

        modelBuilder.Entity<Usuario>(b =>
        {
            b.HasIndex(u => u.Email).IsUnique();
        });

        modelBuilder.Entity<RefreshToken>(b =>
        {
            b.HasOne<Usuario>().WithMany().HasForeignKey(rt => rt.UsuarioId).OnDelete(DeleteBehavior.Cascade);
            b.HasIndex(rt => rt.FamiliaId);
        });

        modelBuilder.Entity<Publicacion>(b =>
        {
            b.Property(p => p.Origen).HasColumnType("geography (Point,4326)");
            b.Property(p => p.Destino).HasColumnType("geography (Point,4326)");
            b.HasIndex(p => p.Origen).HasMethod("GIST");

            b.HasOne<Usuario>().WithMany().HasForeignKey(p => p.UsuarioId).OnDelete(DeleteBehavior.Restrict);
            b.HasOne<CategoriaCarga>().WithMany().HasForeignKey(p => p.CategoriaCargaId).OnDelete(DeleteBehavior.Restrict);
            b.HasOne<TipoVehiculo>().WithMany().HasForeignKey(p => p.TipoVehiculoSugeridoId).OnDelete(DeleteBehavior.Restrict);
            b.HasOne<Oferta>().WithMany().HasForeignKey(p => p.OfertaAceptadaId).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Oferta>(b =>
        {
            b.Property(o => o.Monto).HasColumnType("numeric(12,2)");
            b.HasOne<Publicacion>().WithMany().HasForeignKey(o => o.PublicacionId).OnDelete(DeleteBehavior.Cascade);
            b.HasOne<Usuario>().WithMany().HasForeignKey(o => o.UsuarioId).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Calificacion>(b =>
        {
            b.HasOne<Publicacion>().WithMany().HasForeignKey(c => c.PublicacionId).OnDelete(DeleteBehavior.Cascade);
            b.HasOne<Usuario>().WithMany().HasForeignKey(c => c.UsuarioQueCalificaId).OnDelete(DeleteBehavior.Restrict);
            b.HasOne<Usuario>().WithMany().HasForeignKey(c => c.UsuarioCalificadoId).OnDelete(DeleteBehavior.Restrict);
            b.HasIndex(c => new { c.PublicacionId, c.UsuarioQueCalificaId }).IsUnique();
        });

        modelBuilder.Entity<Reporte>(b =>
        {
            b.HasOne<Publicacion>().WithMany().HasForeignKey(r => r.PublicacionId).OnDelete(DeleteBehavior.Cascade);
            b.HasOne<Usuario>().WithMany().HasForeignKey(r => r.UsuarioReportanteId).OnDelete(DeleteBehavior.Restrict);
        });
    }
}
