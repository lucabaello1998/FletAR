using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Fletar.DAL.Migrations
{
    /// <inheritdoc />
    public partial class SeedCategoriasYTiposVehiculo : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.InsertData(
                table: "CategoriasCarga",
                columns: new[] { "Id", "Activa", "Nombre" },
                values: new object[,]
                {
                    { 1, true, "Mudanza" },
                    { 2, true, "Paquetería chica" },
                    { 3, true, "Carga mediana" },
                    { 4, true, "Carga grande" },
                    { 5, true, "Otro" }
                });

            migrationBuilder.InsertData(
                table: "TiposVehiculo",
                columns: new[] { "Id", "Activo", "CapacidadKg", "Nombre", "VolumenM3" },
                values: new object[,]
                {
                    { 1, true, null, "Moto", null },
                    { 2, true, null, "Utilitario", null },
                    { 3, true, null, "Camioneta", null },
                    { 4, true, null, "Camión chico", null },
                    { 5, true, null, "Camión grande", null },
                    { 6, true, null, "Camión con acoplado", null }
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "CategoriasCarga",
                keyColumn: "Id",
                keyValue: 1);

            migrationBuilder.DeleteData(
                table: "CategoriasCarga",
                keyColumn: "Id",
                keyValue: 2);

            migrationBuilder.DeleteData(
                table: "CategoriasCarga",
                keyColumn: "Id",
                keyValue: 3);

            migrationBuilder.DeleteData(
                table: "CategoriasCarga",
                keyColumn: "Id",
                keyValue: 4);

            migrationBuilder.DeleteData(
                table: "CategoriasCarga",
                keyColumn: "Id",
                keyValue: 5);

            migrationBuilder.DeleteData(
                table: "TiposVehiculo",
                keyColumn: "Id",
                keyValue: 1);

            migrationBuilder.DeleteData(
                table: "TiposVehiculo",
                keyColumn: "Id",
                keyValue: 2);

            migrationBuilder.DeleteData(
                table: "TiposVehiculo",
                keyColumn: "Id",
                keyValue: 3);

            migrationBuilder.DeleteData(
                table: "TiposVehiculo",
                keyColumn: "Id",
                keyValue: 4);

            migrationBuilder.DeleteData(
                table: "TiposVehiculo",
                keyColumn: "Id",
                keyValue: 5);

            migrationBuilder.DeleteData(
                table: "TiposVehiculo",
                keyColumn: "Id",
                keyValue: 6);
        }
    }
}
