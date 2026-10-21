using System.Collections.Concurrent;

namespace Fletar.API.Hubs;

/// <summary>
/// Conexiones que están mirando el GPS de un fletero. El hub no puede confiar
/// sólo en el grupo de SignalR para revocar acceso: si el viaje se completa o
/// se cancela, la conexión sigue en el grupo hasta que el cliente se va. Este
/// registro permite revalidar el vínculo en cada ping y cortar el envío en el
/// mismo request, sin esperar a que el cliente llame a DejarDeSeguirFletero.
/// </summary>
public sealed class SeguimientoUbicacionRegistry
{
    public readonly record struct Seguidor(string ConnectionId, int WatcherId, int FleeterId);

    private readonly ConcurrentDictionary<(string ConnectionId, int FleeterId), Seguidor> _seguidores = new();

    public void Registrar(string connectionId, int watcherId, int fleeterId)
        => _seguidores[(connectionId, fleeterId)] = new Seguidor(connectionId, watcherId, fleeterId);

    public void Quitar(string connectionId, int fleeterId)
        => _seguidores.TryRemove((connectionId, fleeterId), out _);

    public void QuitarConexion(string connectionId)
    {
        foreach (var par in _seguidores)
        {
            if (par.Value.ConnectionId == connectionId)
                _seguidores.TryRemove(par.Key, out _);
        }
    }

    public IReadOnlyList<Seguidor> PorFletero(int fleeterId)
        => _seguidores.Values.Where(s => s.FleeterId == fleeterId).ToList();
}
