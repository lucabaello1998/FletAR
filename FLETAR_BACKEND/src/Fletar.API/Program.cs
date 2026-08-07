using System.Text;
using Fletar.API;
using Fletar.API.Hubs;
using Fletar.BLL;
using Fletar.BLL.Hubs;
using Fletar.BLL.Services.Auth;
using Fletar.BLL.Settings;
using FirebaseAdmin;
using Google.Apis.Auth.OAuth2;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Builder;
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
if (firebaseSettings.EstaConfigurado)
    FirebaseApp.Create(new AppOptions { Credential = GoogleCredential.GetApplicationDefault() });

// Uploads de usuarios (fotos de carga/vehículo, Fase 8) - ver AlmacenamientoSettings
// para el porqué de disco local en vez de un blob storage en la nube. Carpeta
// "uploads/" a secas dentro de Fletar.API (no wwwroot): no se activa la
// convención genérica de wwwroot/UseStaticFiles() sin argumentos, que serviría
// cualquier cosa que alguien deje ahí - en su lugar más abajo se registra un
// PhysicalFileProvider apuntado únicamente a esta carpeta puntual.
var uploadsPath = Path.Combine(builder.Environment.ContentRootPath, "uploads");
Directory.CreateDirectory(Path.Combine(uploadsPath, "publicaciones"));
Directory.CreateDirectory(Path.Combine(uploadsPath, "vehiculos"));
var almacenamientoSettings = new AlmacenamientoSettings(uploadsPath);

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
            }
        };
    });

builder.Services.AddAuthorizationBuilder()
    .AddPolicy("Admin", p => p.RequireClaim("rol", "admin"))
    .SetFallbackPolicy(new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build());

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

// Uploads de usuarios (fotos de carga/vehículo, Fase 8) - servidos como
// archivos estáticos, pero SCOPEADOS explícitamente a esta única carpeta
// (PhysicalFileProvider apunta sólo a `uploads/`, no a wwwroot completo ni al
// resto del proyecto) para no reabrir la puerta que CLAUDE.md cierra a
// propósito ("FletAR no sirve un frontend propio desde la API" - ver
// Estructura del repositorio). Esto es sólo para contenido subido por
// usuarios, nunca para servir el build de Flutter web ni un index.html: no
// hay UseDefaultFiles ni fallback de SPA acá. Va después de UseCors (no
// antes) para que las respuestas de imagen salgan con los headers CORS
// correspondientes - si no, un <img> cargado desde Flutter web con el
// renderer CanvasKit (que trae los bytes por fetch/XHR, no un <img> plano)
// se rompería por falta de Access-Control-Allow-Origin.
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(uploadsPath),
    RequestPath = "/uploads"
});

app.UseAuthentication();
app.UseAuthorization();
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
