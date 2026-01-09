#!/bin/bash
# =============================================================================
# Script de Backup - Moodle Docker
# Respalda: Base de datos + moodledata
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Configuración
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Cargar variables de entorno
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env"
fi

# Valores por defecto
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_DIR/backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="moodle_backup_${TIMESTAMP}"

# Contenedores
DB_CONTAINER="segintec_db"
MOODLE_CONTAINER="segintec_moodle"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Funciones
# -----------------------------------------------------------------------------
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_containers() {
    log_info "Verificando contenedores..."
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
        log_error "Contenedor $DB_CONTAINER no está corriendo"
        exit 1
    fi
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${MOODLE_CONTAINER}$"; then
        log_error "Contenedor $MOODLE_CONTAINER no está corriendo"
        exit 1
    fi
    
    log_info "✅ Contenedores verificados"
}

backup_database() {
    log_info "Respaldando base de datos..."
    
    local db_backup_file="$BACKUP_DIR/${BACKUP_NAME}_db.sql"
    
    docker exec "$DB_CONTAINER" pg_dump \
        -U "${DB_USER}" \
        -d "${DB_NAME}" \
        --no-password \
        > "$db_backup_file"
    
    log_info "✅ Base de datos respaldada: $db_backup_file"
    echo "$db_backup_file"
}

backup_moodledata() {
    log_info "Respaldando moodledata (puede tardar varios minutos)..."
    
    local data_backup_file="$BACKUP_DIR/${BACKUP_NAME}_moodledata.tar"
    
    # Copiar moodledata desde el contenedor
    docker run --rm \
        -v segintec_moodledata:/data:ro \
        -v "$BACKUP_DIR:/backup" \
        alpine tar cvf "/backup/${BACKUP_NAME}_moodledata.tar" -C /data .
    
    log_info "✅ Moodledata respaldado: $data_backup_file"
    echo "$data_backup_file"
}

compress_backup() {
    log_info "Comprimiendo backup..."
    
    local final_backup="$BACKUP_DIR/${BACKUP_NAME}.tar.gz"
    
    cd "$BACKUP_DIR"
    tar -czf "$final_backup" \
        "${BACKUP_NAME}_db.sql" \
        "${BACKUP_NAME}_moodledata.tar"
    
    # Eliminar archivos temporales
    rm -f "${BACKUP_NAME}_db.sql" "${BACKUP_NAME}_moodledata.tar"
    
    log_info "✅ Backup comprimido: $final_backup"
    echo "$final_backup"
}

cleanup_old_backups() {
    log_info "Limpiando backups antiguos (>${RETENTION_DAYS} días)..."
    
    local count=$(find "$BACKUP_DIR" -name "moodle_backup_*.tar.gz" -mtime +"$RETENTION_DAYS" | wc -l)
    
    if [ "$count" -gt 0 ]; then
        find "$BACKUP_DIR" -name "moodle_backup_*.tar.gz" -mtime +"$RETENTION_DAYS" -delete
        log_info "✅ $count backup(s) antiguo(s) eliminado(s)"
    else
        log_info "No hay backups antiguos para eliminar"
    fi
}

show_backup_info() {
    local backup_file="$1"
    local size=$(du -h "$backup_file" | cut -f1)
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                    BACKUP COMPLETADO                           ║"
    echo "╠════════════════════════════════════════════════════════════════╣"
    echo "║  Archivo: $(basename "$backup_file")"
    echo "║  Tamaño:  $size"
    echo "║  Ruta:    $backup_file"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║             BACKUP MOODLE - INICIO                             ║"
    echo "║             $(date)                            ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Crear directorio de backups si no existe
    mkdir -p "$BACKUP_DIR"
    
    # Verificar contenedores
    check_containers
    
    # Realizar backups
    backup_database
    backup_moodledata
    
    # Comprimir
    local final_backup=$(compress_backup)
    
    # Limpiar backups antiguos
    cleanup_old_backups
    
    # Mostrar información
    show_backup_info "$final_backup"
    
    log_info "Backup completado exitosamente"
}

# Ejecutar
main "$@"

