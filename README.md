# Moodle Docker - Instituto Tecnológico

Moodle 4.1 LTS + PostgreSQL + Nginx Proxy Manager

## Stack

- **Moodle 4.1 LTS** (Bitnami)
- **PostgreSQL 15**
- **Nginx Proxy Manager** (SSL/Let's Encrypt)

## Requisitos

- Docker 20.10+ y Docker Compose v2
- 2 vCPU / 4 GB RAM / SSD
- Dominio apuntando al servidor

## Despliegue

```bash
# 1. Preparar entorno
make setup

# 2. Editar configuración
nano .env   # Cambiar passwords, dominio, etc.

# 3. Levantar
make up

# 4. Ver logs (tarda 3-5 min primera vez)
make logs-moodle
```

## Configurar SSL

1. Ir a `http://IP:81` (Nginx Proxy Manager)
2. Login: `admin@example.com` / `changeme`
3. Proxy Hosts → Add:
   - Domain: `tudominio.com`
   - Forward: `moodle_app:8080`
   - SSL → Request new certificate

## Comandos

```bash
make up              # Levantar
make down            # Detener
make status          # Estado
make logs            # Logs
make backup          # Backup DB + archivos
make shell-db        # Entrar a PostgreSQL
make shell-moodle    # Entrar a Moodle
make purge-caches    # Limpiar cachés
make maintenance-on  # Modo mantenimiento
make help            # Ver todos
```

## Backup automático

```bash
# Agregar a crontab (backup diario 3 AM)
crontab -e
0 3 * * * cd /opt/moodle && ./scripts/backup.sh >> /var/log/moodle-backup.log 2>&1
```

## Estructura de categorías sugerida

```
├── Carreras Técnicas/
│   ├── Técnico en Informática/
│   │   ├── Semestre 1/
│   │   ├── Semestre 2/
│   │   └── ...
│   └── [Otras carreras]/
├── Cursos de Capacitación/
│   ├── Tecnología/
│   ├── Administración/
│   └── Idiomas/
└── Recursos Institucionales/
```

## Primeros 7 días

| Día | Qué hacer |
|-----|-----------|
| 1 | Configurar idioma, zona horaria, logo |
| 2 | Políticas de contraseña, deshabilitar auto-registro |
| 3 | Configurar SMTP (SendGrid/Mailgun recomendado) |
| 4 | Crear categorías y roles |
| 5 | Usuarios de prueba, curso piloto |
| 6 | Verificar backups, configurar monitoreo (UptimeRobot) |
| 7 | Documentación interna para docentes/estudiantes |

## NO configurar al inicio

- BigBlueButton (usar enlaces Zoom)
- H5P, plugins de certificados
- Temas custom, plugins de gamificación
- Competencias, insignias, blogs

## Archivos

```
├── docker-compose.yml   # Servicios
├── env.example          # Template de variables
├── Makefile             # Comandos
├── scripts/
│   ├── backup.sh        # Backup
│   └── restore.sh       # Restauración
└── backups/             # Backups generados
```
