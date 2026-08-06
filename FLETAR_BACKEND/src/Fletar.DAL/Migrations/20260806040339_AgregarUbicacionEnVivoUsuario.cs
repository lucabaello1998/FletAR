using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Fletar.DAL.Migrations
{
    /// <inheritdoc />
    public partial class AgregarUbicacionEnVivoUsuario : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<double>(
                name: "UltimaLatitud",
                table: "Usuarios",
                type: "double precision",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "UltimaLongitud",
                table: "Usuarios",
                type: "double precision",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "UltimaUbicacionFecha",
                table: "Usuarios",
                type: "timestamp with time zone",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "UltimaLatitud",
                table: "Usuarios");

            migrationBuilder.DropColumn(
                name: "UltimaLongitud",
                table: "Usuarios");

            migrationBuilder.DropColumn(
                name: "UltimaUbicacionFecha",
                table: "Usuarios");
        }
    }
}
