using System.IdentityModel.Tokens.Jwt;
using System.Text;
using System.Threading.RateLimiting;
using Fletar.API;
using Fletar.API.Hubs;
using Fletar.BLL;
using Fletar.BLL.Hubs;
using Fletar.BLL.Services.Auth;
using Fletar.BLL.Settings;
using Fletar.DAL;
using FirebaseAdmin;
using Google.Apis.Auth.OAuth2;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Builder;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.FileProviders;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;

LoadEnvFile();

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<ManejadorDeExcepciones>();

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "FletAR API", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "Bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Token JWT: \"Bearer {token}\""
    });
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
                { Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" } },
            Array.Empty<string>()
        }
    });
});

var connectionString = Environment.GetEnvironmentVariable("FLETAR_CS")
    ?? throw new InvalidOperationException("Falta la variable de entorno FLETAR_CS (ver .env.example).");

var jwtSettings = new JwtSettings(
    key: Environment.GetEnvironmentVariable("FLETAR_JWT_KEY")
        ?? throw new InvalidOperationException("Falta la variable de entorno FLETAR_JWT_KEY (ver .env.example)."),
    issuer: Environment.GetEnvironmentVariable("FLETAR_JWT_ISSUER") ?? "FletAR",
    audience: Environment.GetEnvironmentVariable("FLETAR_JWT_AUDIENCE") ?? "FletAR");

var googleSettings = new GoogleSettings(Environment.GetEnvironmentVariable("FLETAR_GOOGLE_CLIENT_ID"));

// GOOGLE_APPLICATION_CREDENTIALS es el nombre estándar que usan las Application
// Default Credentials de Google - GoogleCredential.GetApplicationDefault() lo lee
// solo, no hace falta pasarle la ruta a mano.
var firebaseSettings = new FirebaseSettings(Environment.GetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS"));
// Firebase se crea una sola vez por proceso: los tests levantan varios hosts
// (WebApplicationFactory) y el segundo explotaba con "The default FirebaseApp
// already exists".
if (firebaseSettings.EstaConfigurado && FirebaseApp.DefaultInstance is null)
    FirebaseApp.Create(new AppOptions { Credential = GoogleCredential.GetApplicationDefault() });

// Uploads de usuarios (fotos de carga/vehículo, Fase 8; documentos de
// identidad, Fase 9) - ver AlmacenamientoSettings para el porqué de disco
// local en vez de un blob storage en la nube. Carpeta "uploads/" a secas
// dentro de Fletar.API (no wwwroot), partida en dos sub-raíces:
// "uploads/publico/" (fotos de carga/vehículo - servida más abajo por un
// PhysicalFileProvider explícito) y "uploads/privado/" (documentos de
// identidad - JAMÁS registrada en ningún middleware de archivos estáticos,
// son sensibles y sólo se leen vía un endpoint autenticado, ver
// VerificacionIdentidadService.ObtenerDocumentoAsync + AdminController). No se
// activa la convención genérica de wwwroot/UseStaticFiles() sin argumentos,
// que serviría cualquier cosa que alguien deje ahí.
var uploadsPath = Path.Combine(builder.Environment.ContentRootPath, "uploads");
var almacenamientoSettings = new AlmacenamientoSettings(uploadsPath);
Directory.CreateDirectory(Path.Combine(almacenamientoSettings.RutaPublicos, "publicaciones"));
Directory.CreateDirectory(Path.Combine(almacenamientoSettings.RutaPublicos, "vehiculos"));
Directory.CreateDirectory(Path.Combine(almacenamientoSettings.RutaPrivados, "documentos-identidad"));

builder.Services.AddBusinessLayer(connectionString, jwtSettings, googleSettings, firebaseSettings, almacenamientoSettings);
builder.Services.AddSignalR();

// Orígenes del cliente web separados por coma (p. ej. https://app.fletar.ar).
// Vacío por defecto: en producción hay que setear FLETAR_CORS_ORIGENES a mano,
// falla cerrado en vez de aceptar cualquier origen sin que nadie lo haya pedido.
var corsOrigenesProduccion = Environment.GetEnvironmentVariable("FLETAR_CORS_ORIGENES")
    ?.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
    ?? Array.Empty<string>();

const string PoliticaCorsWeb = "Web";
builder.Services.AddCors(options =>
{
    options.AddPolicy(PoliticaCorsWeb, policy =>
    {
        // En Development el cliente web corre en un puerto aleatorio cada vez
        // (`flutter run -d chrome`), así que no hay una lista fija que allowlistear.
        if (builder.Environment.IsDevelopment())
            policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod();
        else
            policy.WithOrigins(corsOrigenesProduccion).AllowAnyHeader().AllowAnyMethod();
    });
});

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.MapInboundClaims = false;
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwtSettings.Issuer,
            ValidateAudience = true,
            ValidAudience = jwtSettings.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSettings.Key)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.Zero
        };

        // SignalR no puede mandar el header Authorization en el handshake de
        // WebSocket - el cliente manda el JWT por query string (?access_token=...)
        // en su lugar. Restringido a /hubs para no abrir esa vía en el resto de
        // la API (ahí sigue haciendo falta el header Authorization normal).
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                var accessToken = context.Request.Query["access_token"];
                var path = context.HttpContext.Request.Path;
                if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/hubs"))
                    context.Token = accessToken;
                return Task.CompletedTask;
            },

            // Un access token vive 15 minutos: sin este chequeo, desactivar una
            // cuenta no cortaba la sesión hasta que venciera (o hasta el próximo
            // refresh). Se valida Activo en cada request - es una consulta por
            // índice primario y el corte queda inmediato, también para SignalR
            // (el handshake pasa por acá).
            OnTokenValidated = async context =>
            {
                var sub = context.Principal?.FindFirst(JwtRegisteredClaimNames.Sub)?.Value;
                if (!int.TryParse(sub, out var usuarioId))
                {
                    context.Fail("Token sin usuario.");
                    return;
                }

                var db = context.HttpContext.RequestServices.GetRequiredService<FletarDbContext>();
                var activo = await db.Usuarios.AsNoTracking()
                    .Where(u => u.Id == usuarioId)
                    .Select(u => u.Activo)
                    .SingleOrDefaultAsync();

                if (!activo)
                    context.Fail("Cuenta deshabilitada.");
            }
        };
    });

builder.Services.AddAuthorizationBuilder()
    .AddPolicy("Admin", p => p.RequireClaim("rol", "admin"))
    .SetFallbackPolicy(new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build());

// Límites anti-abuso (auditoría post-MVP). Global por usuario autenticado (o
// por IP si todavía no hay usuario): un techo alto que no molesta en uso real
// pero corta scripts que crean publicaciones/ofertas/reportes en loop. El
// login tiene además una política propia mucho más estricta (AuthController).
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
    {
        var usuarioId = context.User.FindFirst(JwtRegisteredClaimNames.Sub)?.Value;
        var particion = usuarioId is null
            ? $"ip:{context.Connection.RemoteIpAddress?.ToString() ?? "desconocida"}"
            : $"usuario:{usuarioId}";

        return RateLimitPartition.GetFixedWindowLimiter(particion, _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = 120,
            Window = TimeSpan.FromMinutes(1),
            QueueLimit = 0
        });
    });

    options.AddPolicy("auth", context =>
        RateLimitPartition.GetFixedWindowLimiter(
            $"auth-ip:{context.Connection.RemoteIpAddress?.ToString() ?? "desconocida"}",
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 10,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0
            }));

    options.OnRejected = (context, _) =>
    {
        context.HttpContext.Response.Headers.RetryAfter = "60";
        return ValueTask.CompletedTask;
    };
});

var app = builder.Build();

app.UseCabecerasDeSeguridad();
app.UseExceptionHandler();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();

    using var scopeSeed = app.Services.CreateScope();
    await scopeSeed.ServiceProvider.GetRequiredService<IUsuarioDevSeeder>().SembrarAsync();
}
else
{
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseCors(PoliticaCorsWeb);

// Uploads PÚBLICOS de usuarios (fotos de carga/vehículo, Fase 8) - servidos
// como archivos estáticos, pero SCOPEADOS explícitamente a
// AlmacenamientoSettings.RutaPublicos ("uploads/publico/"), nunca a wwwroot
// completo, al resto del proyecto, ni a "uploads/privado/" (documentos de
// identidad, Fase 9 - ver más arriba, esa carpeta no se registra en ningún
// middleware de archivos estáticos) para no reabrir la puerta que CLAUDE.md
// cierra a propósito ("FletAR no sirve un frontend propio desde la API" - ver
// Estructura del repositorio). Esto es sólo para contenido subido por
// usuarios que es explícitamente público, nunca para servir el build de
// Flutter web ni un index.html: no hay UseDefaultFiles ni fallback de SPA
// acá. Va después de UseCors (no antes) para que las respuestas de imagen
// salgan con los headers CORS correspondientes - si no, un <img> cargado
// desde Flutter web con el renderer CanvasKit (que trae los bytes por
// fetch/XHR, no un <img> plano) se rompería por falta de
// Access-Control-Allow-Origin.
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(almacenamientoSettings.RutaPublicos),
    RequestPath = "/uploads"
});

app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();
app.MapControllers();
app.MapHub<UbicacionHub>("/hubs/ubicacion");
app.MapHub<ChatHub>("/hubs/chat");

app.Run();

static void LoadEnvFile()
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

public partial class Program;
