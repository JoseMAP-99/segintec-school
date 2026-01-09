#!/bin/bash
# =============================================================================
# Script de Restauración - Moodle Docker
# Restaura: Base de datos + moodledata desde backup
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

# Contenedores
DB_CONTAINER="segintec_db"
MOODLE_CONTAINER="segintec_moodle"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

usage() {
    echo ""
    echo "Uso: $0 <archivo_backup.tar.gz>"
    echo ""
    echo "Ejemplo:"
    echo "  $0 ./backups/moodle_backup_20240115_120000.tar.gz"
    echo ""
    exit 1
}

confirm_restore() {
    echo ""
    log_warn "⚠️  ADVERTENCIA: Esta operación:"
    log_warn "   - Detendrá Moodle temporalmente"
    log_warn "   - Reemplazará la base de datos actual"
    log_warn "   - Reemplazará los archivos de moodledata"
    echo ""
    read -p "¿Estás seguro? Escribe 'RESTAURAR' para confirmar: " confirm
    
    if [ "$confirm" != "RESTAURAR" ]; then
        log_error "Operación cancelada"
        exit 1
    fi
}

extract_backup() {
    local backup_file="$1"
    local temp_dir="$2"
    
    log_info "Extrayendo backup..."
    tar -xzf "$backup_file" -C "$temp_dir"
    log_info "✅ Backup extraído"
}

restore_database() {
    local temp_dir="$1"
    local sql_file=$(find "$temp_dir" -name "*_db.sql" | head -1)
    
    if [ -z "$sql_file" ]; then
        log_error "No se encontró archivo SQL en el backup"
        exit 1
    fi
    
    log_info "Restaurando base de datos..."
    
    # Importar SQL
    docker exec -i "$DB_CONTAINER" psql \
        -U "${DB_USER}" \
        -d "${DB_NAME}" \
        < "$sql_file"
    
    log_info "✅ Base de datos restaurada"
}

restore_moodledata() {
    local temp_dir="$1"
    local data_file=$(find "$temp_dir" -name "*_moodledata.tar" | head -1)
    
    if [ -z "$data_file" ]; then
        log_error "No se encontró archivo moodledata en el backup"
        exit 1
    fi
    
    log_info "Restaurando moodledata (puede tardar varios minutos)..."
    
    # Copiar al volumen
    docker run --rm \
        -v segintec_moodledata:/data \
        -v "$temp_dir:/backup:ro" \
        alpine sh -c "rm -rf /data/* && tar -xf /backup/$(basename "$data_file") -C /data"
    
    log_info "✅ Moodledata restaurado"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    local backup_file="$1"
    
    # Verificar argumento
    if [ -z "$backup_file" ]; then
        usage
    fi
    
    # Verificar que el archivo existe
    if [ ! -f "$backup_file" ]; then
        log_error "Archivo no encontrado: $backup_file"
        exit 1
    fi
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║             RESTAURACIÓN MOODLE                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Confirmar operación
    confirm_restore
    
    # Crear directorio temporal
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    # Activar modo mantenimiento
    log_info "Activando modo mantenimiento..."
    docker exec "$MOODLE_CONTAINER" /opt/bitnami/php/bin/php \
        /bitnami/moodle/admin/cli/maintenance.php --enable || true
    
    # Extraer backup
    extract_backup "$backup_file" "$temp_dir"
    
    # Restaurar
    restore_database "$temp_dir"
    restore_moodledata "$temp_dir"
    
    # Limpiar cachés
    log_info "Limpiando cachés..."
    docker exec "$MOODLE_CONTAINER" /opt/bitnami/php/bin/php \
        /bitnami/moodle/admin/cli/purge_caches.php || true
    
    # Desactivar modo mantenimiento
    log_info "Desactivando modo mantenimiento..."
    docker exec "$MOODLE_CONTAINER" /opt/bitnami/php/bin/php \
        /bitnami/moodle/admin/cli/maintenance.php --disable || true
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║             RESTAURACIÓN COMPLETADA                            ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    log_info "✅ Restauración completada exitosamente"
    log_info "Verifica que Moodle funciona correctamente en tu navegador"
}

# Ejecutar
main "$@"

