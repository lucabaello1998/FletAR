using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Fletar.DAL;

public class DesignTimeDbContextFactory : IDesignTimeDbContextFactory<FletarDbContext>
{
    public FletarDbContext CreateDbContext(string[] args)
    {
        LoadEnvFile();

        var connectionString = Environment.GetEnvironmentVariable("FLETAR_CS")
            ?? throw new InvalidOperationException("Falta la variable de entorno FLETAR_CS (ver .env.example).");

        var optionsBuilder = new DbContextOptionsBuilder<FletarDbContext>();
        optionsBuilder.UseNpgsql(connectionString, o => o.UseNetTopologySuite());

        return new FletarDbContext(optionsBuilder.Options);
    }

    private static void LoadEnvFile()
    {
        var directorio = new DirectoryInfo(Directory.GetCurrentDirectory());
        while (directorio is not null)
        {
            var candidato = Path.Combine(directorio.FullName, ".env");
            if (File.Exists(candidato))
            {
                foreach (var linea in File.ReadAllLines(candidato))
                {
                    if (string.IsNullOrWhiteSpace(linea) || linea.TrimStart().StartsWith('#'))
                        continue;

                    var separador = linea.IndexOf('=');
                    if (separador <= 0)
                        continue;

                    var clave = linea[..separador].Trim();
                    var valor = linea[(separador + 1)..].Trim();
                    Environment.SetEnvironmentVariable(clave, valor);
                }
                return;
            }
            directorio = directorio.Parent;
        }
    }
}
