using Fletar.API.Hubs;

namespace Fletar.Tests;

public class SeguimientoUbicacionRegistryTests
{
    [Fact]
    public void Registra_y_quita_una_conexion_por_fletero()
    {
        var registro = new SeguimientoUbicacionRegistry();

        registro.Registrar("conn-1", watcherId: 10, fleeterId: 20);
        registro.Registrar("conn-2", watcherId: 11, fleeterId: 20);

        Assert.Equal(2, registro.PorFletero(20).Count);
        Assert.Empty(registro.PorFletero(21));

        registro.Quitar("conn-1", fleeterId: 20);

        var restante = Assert.Single(registro.PorFletero(20));
        Assert.Equal("conn-2", restante.ConnectionId);
        Assert.Equal(11, restante.WatcherId);
    }

    [Fact]
    public void QuitarConexion_limpia_todos_los_fleteros_de_esa_conexion()
    {
        var registro = new SeguimientoUbicacionRegistry();

        registro.Registrar("conn-1", watcherId: 10, fleeterId: 20);
        registro.Registrar("conn-1", watcherId: 10, fleeterId: 21);
        registro.Registrar("conn-2", watcherId: 11, fleeterId: 20);

        registro.QuitarConexion("conn-1");

        var restante = Assert.Single(registro.PorFletero(20));
        Assert.Equal("conn-2", restante.ConnectionId);
        Assert.Empty(registro.PorFletero(21));
    }
}
