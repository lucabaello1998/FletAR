using AutoMapper;
using Fletar.BLL.Helpers;
using Fletar.BLL.Settings;
using Fletar.DAL;
using Fletar.DAL.Models;
using Fletar.DTO.Auth;
using Google.Apis.Auth;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace Fletar.BLL.Services.Auth;

public class AuthService(
    FletarDbContext db,
    IJwtTokenGenerator jwtTokenGenerator,
    JwtSettings jwtSettings,
    GoogleSettings googleSettings,
    IMapper mapper) : IAuthService
{
    private static readonly PasswordHasher<Usuario> Hasher = new();

    // Hash de referencia contra el que se compara cuando el email no existe, para que
    // el tiempo de respuesta del login no delate si la cuenta existe o no.
    private static readonly string HashDeReferencia = Hasher.HashPassword(null!, Guid.NewGuid().ToString());

    // Un refresh concurrente con el mismo token no puede generar dos hijos: el
    // primero rota el token y el segundo tiene que detectar el reuso. El UPDATE
    // condicional de abajo ya lo resuelve entre procesos; este lock por franjas
    // evita que dos requests del mismo proceso lleguen juntos al UPDATE y reduce
    // el ruido de colisiones en la base. Es un arreglo fijo (no un diccionario
    // por hash) para que no crezca con cada refresh.
    private static readonly SemaphoreSlim[] RefreshLocks =
        Enumerable.Range(0, 64).Select(_ => new SemaphoreSlim(1, 1)).ToArray();

    public async Task<LoginResponse> RegistrarAsync(RegisterRequest request)
    {
        var yaExiste = await db.Usuarios.AnyAsync(u => u.Email == request.Email.ToLower());
        if (yaExiste)
            throw new InvalidOperationException("Ya existe una cuenta con ese email.");

        var usuario = new Usuario
        {
            Nombre = request.Nombre,
            Email = request.Email.ToLower(),
            Telefono = request.Telefono,
            Rol = Rol.Usuario,
            FechaRegistro = DateTime.UtcNow,
            Activo = true
        };
        usuario.PasswordHash = Hasher.HashPassword(usuario, request.Password);

        db.Usuarios.Add(usuario);
        await db.SaveChangesAsync();

        return await EmitirLoginResponseAsync(usuario);
    }

    public async Task<LoginResponse> LoginAsync(LoginRequest request)
    {
        var usuario = await db.Usuarios.SingleOrDefaultAsync(u => u.Email == request.Email.ToLower());

        var resultado = Hasher.VerifyHashedPassword(
            usuario!,
            usuario?.PasswordHash ?? HashDeReferencia,
            request.Password);

        if (usuario is null || !usuario.Activo || resultado == PasswordVerificationResult.Failed)
            throw new UnauthorizedAccessException("Email o contraseña incorrectos.");

        return await EmitirLoginResponseAsync(usuario);
    }

    public async Task<LoginResponse> LoginConGoogleAsync(string idToken)
    {
        if (string.IsNullOrEmpty(googleSettings.ClientId))
            throw new InvalidOperationException("Google Sign-In no está configurado en este ambiente.");

        GoogleJsonWebSignature.Payload payload;
        try
        {
            payload = await GoogleJsonWebSignature.ValidateAsync(idToken, new GoogleJsonWebSignature.ValidationSettings
            {
                Audience = [googleSettings.ClientId]
            });
        }
        catch (InvalidJwtException)
        {
            throw new UnauthorizedAccessException("Token de Google inválido.");
        }

        var email = payload.Email.ToLower();
        var usuario = await db.Usuarios.SingleOrDefaultAsync(u => u.Email == email);

        if (usuario is null)
        {
            usuario = new Usuario
            {
                Nombre = payload.Name ?? email,
                Email = email,
                FotoUrl = payload.Picture,
                Rol = Rol.Usuario,
                FechaRegistro = DateTime.UtcNow,
                Activo = true
            };
            db.Usuarios.Add(usuario);
            await db.SaveChangesAsync();
        }
        else if (!usuario.Activo)
        {
            throw new UnauthorizedAccessException("Cuenta deshabilitada.");
        }

        return await EmitirLoginResponseAsync(usuario);
    }

    public async Task<RefreshResponse> RefreshAsync(string refreshToken)
    {
        var hash = RefreshTokenHasher.Hash(refreshToken);
        var gate = RefreshLocks[(hash.GetHashCode() & int.MaxValue) % RefreshLocks.Length];
        await gate.WaitAsync();
        try
        {
            var actual = await db.RefreshTokens.SingleOrDefaultAsync(rt => rt.TokenHash == hash);

            if (actual is null)
                throw new UnauthorizedAccessException("Refresh token inválido.");

            if (actual.FechaRevocacion is not null)
            {
                // El token ya se usó una vez: esto es reuso (robo o carrera de refresh),
                // así que se revoca toda la familia de tokens derivados de él.
                await RevocarFamiliaAsync(actual.FamiliaId);
                throw new UnauthorizedAccessException("Refresh token ya utilizado; sesión revocada.");
            }

            if (actual.FechaExpiracion < DateTime.UtcNow)
                throw new UnauthorizedAccessException("Refresh token expirado.");

            var usuario = await db.Usuarios.SingleAsync(u => u.Id == actual.UsuarioId);

            // Una cuenta desactivada no puede renovar: se corta también la familia
            // entera, no sólo este refresh, para que no quede ningún token vivo.
            if (!usuario.Activo)
            {
                await RevocarFamiliaAsync(actual.FamiliaId);
                throw new UnauthorizedAccessException("Cuenta deshabilitada.");
            }

            var (accessToken, expiracion) = jwtTokenGenerator.GenerarAccessToken(usuario);
            var nuevoRefreshTokenCrudo = RefreshTokenHasher.GenerarTokenAleatorio();
            var ahora = DateTime.UtcNow;

            var nuevo = new RefreshToken
            {
                Id = Guid.NewGuid(),
                UsuarioId = usuario.Id,
                FamiliaId = actual.FamiliaId,
                TokenHash = RefreshTokenHasher.Hash(nuevoRefreshTokenCrudo),
                FechaCreacion = ahora,
                FechaExpiracion = ahora.Add(jwtSettings.RefreshTokenDuracion)
            };

            if (db.Database.IsRelational())
            {
                // UPDATE condicional: sólo el primer request que vea el token sin
                // revocar lo rota. Si otro proceso ya lo hizo, esta consulta afecta
                // 0 filas y el request se trata como reuso, no como un refresh
                // válido con dos hijos.
                var reuso = false;

                await using (var tx = await db.Database.BeginTransactionAsync())
                {
                    db.Entry(actual).State = EntityState.Detached;

                    var filas = await db.RefreshTokens
                        .Where(rt => rt.Id == actual.Id && rt.FechaRevocacion == null)
                        .ExecuteUpdateAsync(setters => setters
                            .SetProperty(rt => rt.FechaRevocacion, ahora)
                            .SetProperty(rt => rt.ReemplazadoPorId, nuevo.Id));

                    if (filas == 0)
                    {
                        reuso = true;
                        await tx.RollbackAsync();
                    }
                    else
                    {
                        db.RefreshTokens.Add(nuevo);
                        await db.SaveChangesAsync();
                        await tx.CommitAsync();
                    }
                }

                if (reuso)
                {
                    // Fuera de la transacción: revocar la familia con otra
                    // conexión del mismo contexto mientras la transacción sigue
                    // siendo la actual fallaría.
                    await RevocarFamiliaAsync(actual.FamiliaId);
                    throw new UnauthorizedAccessException("Refresh token ya utilizado; sesión revocada.");
                }
            }
            else
            {
                // Fallback para el proveedor InMemory de los tests: no soporta
                // transacciones ni ExecuteUpdate. El lock por franjas mantiene la
                // misma garantía dentro del proceso.
                if (actual.FechaRevocacion is not null)
                {
                    await RevocarFamiliaAsync(actual.FamiliaId);
                    throw new UnauthorizedAccessException("Refresh token ya utilizado; sesión revocada.");
                }

                actual.FechaRevocacion = ahora;
                actual.ReemplazadoPorId = nuevo.Id;
                db.RefreshTokens.Add(nuevo);
                await db.SaveChangesAsync();
            }

            return new RefreshResponse
            {
                AccessToken = accessToken,
                RefreshToken = nuevoRefreshTokenCrudo,
                AccessTokenExpiracion = expiracion
            };
        }
        finally
        {
            gate.Release();
        }
    }

    public async Task LogoutAsync(string refreshToken)
    {
        var hash = RefreshTokenHasher.Hash(refreshToken);
        var ahora = DateTime.UtcNow;

        if (db.Database.IsRelational())
        {
            await db.RefreshTokens
                .Where(rt => rt.TokenHash == hash && rt.FechaRevocacion == null)
                .ExecuteUpdateAsync(setters => setters
                    .SetProperty(rt => rt.FechaRevocacion, ahora));
            return;
        }

        var actual = await db.RefreshTokens.SingleOrDefaultAsync(rt => rt.TokenHash == hash);

        if (actual is null || actual.FechaRevocacion is not null)
            return;

        actual.FechaRevocacion = ahora;
        await db.SaveChangesAsync();
    }

    private async Task RevocarFamiliaAsync(Guid familiaId)
    {
        var ahora = DateTime.UtcNow;

        if (db.Database.IsRelational())
        {
            await db.RefreshTokens
                .Where(rt => rt.FamiliaId == familiaId && rt.FechaRevocacion == null)
                .ExecuteUpdateAsync(setters => setters
                    .SetProperty(rt => rt.FechaRevocacion, ahora));
            return;
        }

        var tokens = await db.RefreshTokens
            .Where(rt => rt.FamiliaId == familiaId && rt.FechaRevocacion == null)
            .ToListAsync();

        foreach (var token in tokens)
            token.FechaRevocacion = ahora;

        await db.SaveChangesAsync();
    }

    private async Task<LoginResponse> EmitirLoginResponseAsync(Usuario usuario)
    {
        var (accessToken, expiracion) = jwtTokenGenerator.GenerarAccessToken(usuario);
        var refreshTokenCrudo = RefreshTokenHasher.GenerarTokenAleatorio();

        db.RefreshTokens.Add(new RefreshToken
        {
            Id = Guid.NewGuid(),
            UsuarioId = usuario.Id,
            FamiliaId = Guid.NewGuid(),
            TokenHash = RefreshTokenHasher.Hash(refreshTokenCrudo),
            FechaCreacion = DateTime.UtcNow,
            FechaExpiracion = DateTime.UtcNow.Add(jwtSettings.RefreshTokenDuracion)
        });
        await db.SaveChangesAsync();

        return new LoginResponse
        {
            AccessToken = accessToken,
            RefreshToken = refreshTokenCrudo,
            AccessTokenExpiracion = expiracion,
            Usuario = mapper.Map<UsuarioResponse>(usuario)
        };
    }
}
