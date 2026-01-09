# =============================================================================
# Makefile - Moodle Docker Producción
# Instituto Tecnológico
# =============================================================================

.PHONY: help setup up down restart logs status backup restore clean purge shell-moodle shell-db health cron-status

# Variables
COMPOSE = docker compose
BACKUP_SCRIPT = ./scripts/backup.sh

# -----------------------------------------------------------------------------
# Ayuda
# -----------------------------------------------------------------------------
help:
	@echo ""
	@echo "╔════════════════════════════════════════════════════════════════╗"
	@echo "║          Moodle Docker - Comandos Disponibles                  ║"
	@echo "╠════════════════════════════════════════════════════════════════╣"
	@echo "║  SETUP Y DESPLIEGUE                                            ║"
	@echo "║    make setup      - Prepara el entorno (copia env, crea dirs) ║"
	@echo "║    make up         - Levanta todos los contenedores            ║"
	@echo "║    make down       - Detiene todos los contenedores            ║"
	@echo "║    make restart    - Reinicia todos los servicios              ║"
	@echo "║                                                                ║"
	@echo "║  MONITOREO                                                     ║"
	@echo "║    make status     - Estado de los contenedores                ║"
	@echo "║    make logs       - Ver logs en tiempo real                   ║"
	@echo "║    make logs-moodle - Ver logs solo de Moodle                  ║"
	@echo "║    make health     - Verificar salud de servicios              ║"
	@echo "║    make cron-status - Ver estado del CRON                      ║"
	@echo "║                                                                ║"
	@echo "║  BACKUP Y RESTAURACIÓN                                         ║"
	@echo "║    make backup     - Crear backup completo (DB + moodledata)   ║"
	@echo "║    make restore    - Restaurar desde backup                    ║"
	@echo "║                                                                ║"
	@echo "║  SHELLS                                                        ║"
	@echo "║    make shell-moodle - Entrar al contenedor Moodle             ║"
	@echo "║    make shell-db     - Entrar al contenedor MariaDB            ║"
	@echo "║                                                                ║"
	@echo "║  LIMPIEZA (¡CUIDADO!)                                          ║"
	@echo "║    make clean      - Detiene y elimina contenedores            ║"
	@echo "║    make purge      - ELIMINA TODO (contenedores + volúmenes)   ║"
	@echo "╚════════════════════════════════════════════════════════════════╝"
	@echo ""

# -----------------------------------------------------------------------------
# Setup inicial
# -----------------------------------------------------------------------------
setup:
	@echo "🔧 Preparando entorno..."
	@if [ ! -f .env ]; then \
		cp env.example .env; \
		echo "✅ Archivo .env creado. EDÍTALO antes de continuar."; \
		echo "   → nano .env"; \
	else \
		echo "⚠️  .env ya existe. Verifica que esté configurado."; \
	fi
	@mkdir -p scripts backups
	@chmod +x scripts/*.sh 2>/dev/null || true
	@echo "✅ Directorios creados."
	@echo ""
	@echo "📋 Siguiente paso: edita .env y luego ejecuta 'make up'"

# -----------------------------------------------------------------------------
# Levantar servicios
# -----------------------------------------------------------------------------
up:
	@echo "🚀 Levantando contenedores..."
	$(COMPOSE) up -d
	@echo ""
	@echo "✅ Contenedores iniciados."
	@echo ""
	@echo "📋 URLs importantes:"
	@echo "   → Moodle:              http://localhost:8080"
	@echo "   → Nginx Proxy Manager: http://localhost:81"
	@echo "      Usuario: admin@example.com"
	@echo "      Password: changeme"
	@echo ""
	@echo "⏳ Moodle tarda ~3-5 minutos en inicializar la primera vez."
	@echo "   Usa 'make logs-moodle' para ver el progreso."

# -----------------------------------------------------------------------------
# Detener servicios
# -----------------------------------------------------------------------------
down:
	@echo "🛑 Deteniendo contenedores..."
	$(COMPOSE) down
	@echo "✅ Contenedores detenidos."

restart:
	@echo "🔄 Reiniciando servicios..."
	$(COMPOSE) restart
	@echo "✅ Servicios reiniciados."

# -----------------------------------------------------------------------------
# Monitoreo
# -----------------------------------------------------------------------------
status:
	@echo "📊 Estado de contenedores:"
	@echo ""
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

logs-moodle:
	$(COMPOSE) logs -f moodle

logs-db:
	$(COMPOSE) logs -f db

health:
	@echo "🏥 Verificando salud de servicios..."
	@echo ""
	@echo "PostgreSQL:"
	@docker exec segintec_db pg_isready -U moodle && echo "  ✅ Saludable" || echo "  ❌ Con problemas"
	@echo ""
	@echo "Moodle:"
	@curl -sf http://localhost:8080/login/index.php > /dev/null && echo "  ✅ Respondiendo" || echo "  ❌ No responde"
	@echo ""
	@echo "Nginx Proxy Manager:"
	@curl -sf http://localhost:81 > /dev/null && echo "  ✅ Respondiendo" || echo "  ❌ No responde"

cron-status:
	@echo "⏰ Estado del CRON (integrado en Moodle):"
	@docker exec segintec_moodle cat /opt/bitnami/moodle/admin/cli/cron.php > /dev/null 2>&1 && echo "  ✅ CRON disponible (ejecutado por Bitnami)" || echo "  ❌ Error"

# -----------------------------------------------------------------------------
# Backup y restauración
# -----------------------------------------------------------------------------
backup:
	@echo "💾 Iniciando backup..."
	@chmod +x $(BACKUP_SCRIPT)
	@$(BACKUP_SCRIPT)

restore:
	@echo "♻️  Para restaurar, usa:"
	@echo "   ./scripts/restore.sh <archivo_backup.tar.gz>"

# -----------------------------------------------------------------------------
# Shells interactivos
# -----------------------------------------------------------------------------
shell-moodle:
	@echo "🐚 Entrando al contenedor Moodle..."
	docker exec -it segintec_moodle /bin/bash

shell-db:
	@echo "🐚 Entrando a PostgreSQL..."
	@docker exec -it segintec_db psql -U moodle -d moodle

# -----------------------------------------------------------------------------
# Limpieza
# -----------------------------------------------------------------------------
clean:
	@echo "🧹 Limpiando contenedores..."
	$(COMPOSE) down --remove-orphans
	@echo "✅ Contenedores eliminados (volúmenes preservados)."

purge:
	@echo ""
	@echo "⚠️  ¡ADVERTENCIA! Esto eliminará:"
	@echo "   - Todos los contenedores"
	@echo "   - Todos los volúmenes (BASE DE DATOS Y ARCHIVOS)"
	@echo ""
	@read -p "¿Estás seguro? Escribe 'SI' para confirmar: " confirm; \
	if [ "$$confirm" = "SI" ]; then \
		$(COMPOSE) down -v --remove-orphans; \
		echo "✅ Todo eliminado."; \
	else \
		echo "❌ Operación cancelada."; \
	fi

# -----------------------------------------------------------------------------
# Utilidades para producción
# -----------------------------------------------------------------------------
update-moodle:
	@echo "📦 Actualizando imagen de Moodle..."
	$(COMPOSE) pull moodle
	$(COMPOSE) up -d moodle
	@echo "✅ Moodle actualizado."

maintenance-on:
	@echo "🔧 Activando modo mantenimiento..."
	docker exec segintec_moodle /opt/bitnami/php/bin/php /bitnami/moodle/admin/cli/maintenance.php --enable
	@echo "✅ Modo mantenimiento activado."

maintenance-off:
	@echo "🔧 Desactivando modo mantenimiento..."
	docker exec segintec_moodle /opt/bitnami/php/bin/php /bitnami/moodle/admin/cli/maintenance.php --disable
	@echo "✅ Modo mantenimiento desactivado."

purge-caches:
	@echo "🗑️  Limpiando cachés de Moodle..."
	docker exec segintec_moodle /opt/bitnami/php/bin/php /bitnami/moodle/admin/cli/purge_caches.php
	@echo "✅ Cachés limpiados."

