# Backups de FletAR

El volumen de Railway **no es un backup**: protege los archivos de un redeploy,
pero si se borra el volumen, se corrompe la base o alguien elimina datos, no hay
copia. FletAR necesita dos respaldos independientes:

1. **Base PostgreSQL/PostGIS (Neon)** — dump lógico diario + ventana de restore
   de Neon.
2. **Uploads (`/data/uploads`)** — copia del volumen, porque ahí están las fotos
   de cargas/vehículos y los documentos de identidad.

## 1. Base en Neon

### Restore window (PITR)

En el panel de Neon, el proyecto tiene una **Restore window** (point-in-time
recovery). Sirve para volver a un instante anterior sin depender de un dump.
Verificá que esté habilitada y que la retención sea suficiente para tu plan.

### Dump diario automatizado

El workflow [`.github/workflows/backup.yml`](../../.github/workflows/backup.yml)
corre `pg_dump` todos los días y deja el artefacto en GitHub Actions por 30 días.

Para activarlo, agregá el secret del repositorio:

```text
DATABASE_URL = postgresql://... (connection string directa de Neon, sin -pooler)
```

También podés correrlo a mano desde **Actions → Backup → Run workflow**.

### Dump manual

```powershell
cd FLETAR_BACKEND
$env:DATABASE_URL = "postgresql://...?sslmode=require"
.\scripts\backup-neon.ps1
```

Genera `FLETAR_BACKEND/backups/fletar-YYYYMMDD-HHMMSS.dump` con `pg_dump -Fc`.
Restaurar en una base vacía:

```bash
pg_restore --dbname="$DATABASE_URL" --clean --no-owner --no-privileges backups/fletar-....dump
```

> No restaures un dump sobre producción sin probarlo antes en una branch de Neon.

## 2. Uploads en Railway

### Backup manual

```powershell
cd FLETAR_BACKEND
railway login
railway link          # elegí el proyecto/servicio de FletAR
.\scripts\backup-uploads.ps1
```

El script usa `railway volume files download /data/uploads ...` y deja una
carpeta `backups/uploads-YYYYMMDD-HHMMSS/`.

### Backup desde el panel

En Railway, abrí el volumen `fletar-volume` y usá la opción de backups del
volumen si está disponible en tu plan. Igual conviene bajar una copia propia:
los backups del proveedor viven en la misma cuenta.

### Cuidado con los documentos de identidad

`/data/uploads/privado/documentos-identidad/` contiene imágenes sensibles. Las
copias deben:

- guardarse cifradas (por ejemplo, un ZIP con contraseña o un disco cifrado);
- no subirse a un repositorio ni a un servicio público;
- borrarse cuando ya no sean necesarias.

## 3. Frecuencia recomendada

| Qué | Frecuencia | Retención |
| --- | --- | --- |
| `pg_dump` | diario | 30 días en Actions + 12 copias mensuales externas |
| Volumen de uploads | semanal o después de cada release | 8 semanas |
| Prueba de restore | mensual | una branch temporal de Neon |

## 4. Checklist

- [ ] `DATABASE_URL` cargada como secret en GitHub.
- [ ] Workflow `Backup` corriendo sin errores.
- [ ] Restore window de Neon habilitada.
- [ ] Copia de uploads descargada y cifrada fuera de Railway.
- [ ] Restore de prueba hecho en una branch de Neon.
- [ ] Alguien sabe dónde están las copias y cómo restaurarlas.
