using System.Text;
using Fletar.API;
using Fletar.BLL;
using Fletar.BLL.Services.Auth;
using Fletar.BLL.Settings;
using FirebaseAdmin;
using Google.Apis.Auth.OAuth2;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
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

builder.Services.AddBusinessLayer(connectionString, jwtSettings, googleSettings, firebaseSettings);

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
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

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
