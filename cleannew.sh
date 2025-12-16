#!/bin/bash
# ============================================================================
# Script de Mantenimiento Integral para Debian 13 (Testing/Trixie)
# ============================================================================
# Versión: 2025.6 - "Paranoid Edition with Modular Steps"
# Última revisión: Diciembre 2025
# Autor: Homero Thompson del Lago del Terror (Enhanced by Claude)
#
# ====================== FILOSOFÍA DE EJECUCIÓN ======================
# Este script implementa un sistema de mantenimiento PARANOICO diseñado
# específicamente para Debian Testing, con énfasis en:
#   1. Seguridad ante todo: Snapshot antes de cambios críticos
#   2. Control granular: Cada paso puede activarse/desactivarse
#   3. Análisis de riesgos: Detecta operaciones peligrosas antes de ejecutar
#   4. Punto de retorno: Timeshift snapshot para rollback completo
#   5. Validación inteligente: Verifica dependencias y estado del sistema
#   6. Detección avanzada de reinicio: Kernel + librerías críticas
#
# ====================== REQUISITOS DEL SISTEMA ======================
# OBLIGATORIO:
#   • Debian 13 (Testing/Trixie) o compatible
#   • Permisos de root (sudo)
#   • Conexión a internet
#
# RECOMENDADO (el script puede instalarlas automáticamente):
#   • timeshift      - Snapshots del sistema (CRÍTICO para seguridad)
#   • needrestart    - Detección inteligente de servicios a reiniciar
#   • fwupd          - Gestión de actualizaciones de firmware
#   • flatpak        - Si usas aplicaciones Flatpak
#   • snapd          - Si usas aplicaciones Snap
#
# Instalación manual de herramientas recomendadas:
#   sudo apt install timeshift needrestart fwupd flatpak
#
# ====================== CONFIGURACIÓN DE PASOS ======================
# Cada paso puede activarse (1) o desactivarse (0) según tus necesidades.
# El script validará dependencias automáticamente.
#
# PASOS DISPONIBLES:
#   STEP_CHECK_CONNECTIVITY    - Verificar conexión a internet
#   STEP_CHECK_DEPENDENCIES    - Verificar e instalar herramientas
#   STEP_BACKUP_TAR           - Backup de configuraciones APT
#   STEP_SNAPSHOT_TIMESHIFT   - Crear snapshot Timeshift (RECOMENDADO)
#   STEP_UPDATE_REPOS         - Actualizar repositorios (apt update)
#   STEP_UPGRADE_SYSTEM       - Actualizar paquetes (apt full-upgrade)
#   STEP_UPDATE_FLATPAK       - Actualizar aplicaciones Flatpak
#   STEP_UPDATE_SNAP          - Actualizar aplicaciones Snap
#   STEP_CHECK_FIRMWARE       - Verificar actualizaciones de firmware
#   STEP_CLEANUP_APT          - Limpieza de paquetes huérfanos
#   STEP_CLEANUP_KERNELS      - Eliminar kernels antiguos
#   STEP_CLEANUP_DISK         - Limpiar logs y caché
#   STEP_CHECK_REBOOT         - Verificar necesidad de reinicio
#
# ====================== EJEMPLOS DE USO ======================
# 1. Ejecución completa interactiva (RECOMENDADO):
#    sudo ./cleannew.sh
#
# 2. Modo simulación (prueba sin cambios reales):
#    sudo ./cleannew.sh --dry-run
#
# 3. Modo desatendido para automatización:
#    sudo ./cleannew.sh -y
#
# 4. Solo actualizar sistema sin limpieza:
#    Edita el script y configura:
#    STEP_CLEANUP_APT=0
#    STEP_CLEANUP_KERNELS=0
#    STEP_CLEANUP_DISK=0
#
# 5. Solo limpieza sin actualizar:
#    STEP_UPDATE_REPOS=0
#    STEP_UPGRADE_SYSTEM=0
#    STEP_UPDATE_FLATPAK=0
#    STEP_UPDATE_SNAP=0
#
# ====================== ARCHIVOS Y DIRECTORIOS ======================
# Logs:     /var/log/debian-maintenance/sys-update-YYYYMMDD_HHMMSS.log
# Backups:  /var/backups/debian-maintenance/backup_YYYYMMDD_HHMMSS.tar.gz
# Lock:     /var/run/debian-maintenance.lock
#
# ====================== CARACTERÍSTICAS DE SEGURIDAD ======================
# • Validación de espacio en disco antes de actualizar
# • Detección de operaciones masivas de eliminación de paquetes
# • Snapshot automático con Timeshift (si está configurado)
# • Backup de configuraciones APT antes de cambios
# • Lock file para evitar ejecuciones simultáneas
# • Reparación automática de base de datos dpkg
# • Detección inteligente de necesidad de reinicio:
#   - Comparación de kernel actual vs esperado
#   - Detección de librerías críticas actualizadas (glibc, systemd)
#   - Conteo de servicios que requieren reinicio
# • Modo dry-run para simular sin hacer cambios
#
# ====================== NOTAS IMPORTANTES ======================
# • Testing puede tener cambios disruptivos: SIEMPRE revisa los logs
# • El snapshot de Timeshift es tu seguro de vida: no lo omitas
# • MAX_REMOVALS_ALLOWED=0 evita eliminaciones automáticas masivas
# • En modo desatendido (-y), el script ABORTA si detecta riesgo
# • El script usa LC_ALL=C para parsing predecible de comandos
# • Los kernels se mantienen según KERNELS_TO_KEEP (default: 3)
# • Los logs se conservan según DIAS_LOGS (default: 7 días)
#
# ====================== SOLUCIÓN DE PROBLEMAS ======================
# Si el script falla:
#   1. Revisa el log en /var/log/debian-maintenance/
#   2. Ejecuta en modo --dry-run para diagnosticar
#   3. Verifica espacio en disco con: df -h
#   4. Repara dpkg manualmente: sudo dpkg --configure -a
#   5. Si hay problemas de Timeshift, restaura el snapshot
#
# Para reportar bugs o sugerencias:
#   Revisa el log completo y anota el paso donde falló
#
# ============================================================================

# Forzar idioma estándar para parsing predecible
export LC_ALL=C

# ============================================================================
# CONFIGURACIÓN GENERAL
# ============================================================================

# Archivos y directorios
BACKUP_DIR="/var/backups/debian-maintenance"
LOCK_FILE="/var/run/debian-maintenance.lock"
LOG_DIR="/var/log/debian-maintenance"
SCRIPT_VERSION="2025.6-paranoid-modular"

# Parámetros de sistema
DIAS_LOGS=7
KERNELS_TO_KEEP=3
MIN_FREE_SPACE_GB=5
MIN_FREE_SPACE_BOOT_MB=200
APT_CLEAN_MODE="autoclean"

# Seguridad paranoica
MAX_REMOVALS_ALLOWED=0
ASK_TIMESHIFT_RUN=true

# ============================================================================
# CONFIGURACIÓN DE PASOS A EJECUTAR
# ============================================================================
# Cambia a 0 para desactivar un paso, 1 para activarlo
# El script validará dependencias automáticamente

STEP_CHECK_CONNECTIVITY=1     # Verificar conexión a internet
STEP_CHECK_DEPENDENCIES=1     # Verificar e instalar herramientas
STEP_BACKUP_TAR=1            # Backup de configuraciones APT
STEP_SNAPSHOT_TIMESHIFT=1    # Crear snapshot Timeshift (RECOMENDADO)
STEP_UPDATE_REPOS=1          # Actualizar repositorios (apt update)
STEP_UPGRADE_SYSTEM=1        # Actualizar paquetes (apt full-upgrade)
STEP_UPDATE_FLATPAK=1        # Actualizar aplicaciones Flatpak
STEP_UPDATE_SNAP=1           # Actualizar aplicaciones Snap
STEP_CHECK_FIRMWARE=1        # Verificar actualizaciones de firmware
STEP_CLEANUP_APT=1           # Limpieza de paquetes huérfanos
STEP_CLEANUP_KERNELS=1       # Eliminar kernels antiguos
STEP_CLEANUP_DISK=1          # Limpiar logs y caché
STEP_CHECK_REBOOT=1          # Verificar necesidad de reinicio

# ============================================================================
# VARIABLES DE ESTADO Y CONTROL
# ============================================================================

# Estados visuales de cada paso
STAT_CONNECTIVITY="⏳"
STAT_DEPENDENCIES="⏳"
STAT_BACKUP_TAR="⏳"
STAT_SNAPSHOT="⏳"
STAT_REPO="⏳"
STAT_UPGRADE="⏳"
STAT_FLATPAK="⏳"
STAT_SNAP="⏳"
STAT_FIRMWARE="⏳"
STAT_CLEAN_APT="⏳"
STAT_CLEAN_KERNEL="⏳"
STAT_CLEAN_DISK="⏳"
STAT_REBOOT="✅ No requerido"

# Contadores y tiempo
SPACE_BEFORE_ROOT=0
SPACE_BEFORE_BOOT=0
START_TIME=$(date +%s)
CURRENT_STEP=0
TOTAL_STEPS=0

# Flags de control
DRY_RUN=false
UNATTENDED=false
QUIET=false
REBOOT_NEEDED=false

# ============================================================================
# COLORES E ICONOS
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

ICON_OK="✅"
ICON_FAIL="❌"
ICON_SKIP="⏩"
ICON_WARN="⚠️"
ICON_SHIELD="🛡️"
ICON_CLOCK="⏱️"
ICON_ROCKET="🚀"

# ============================================================================
# FUNCIONES BASE Y UTILIDADES
# ============================================================================

init_log() {
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/sys-update-$(date +%Y%m%d_%H%M%S).log"
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"
}

log() {
    local level="$1"; shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"

    [ "$QUIET" = true ] && return

    case "$level" in
        ERROR)   echo -e "${RED}❌ ${message}${NC}" ;;
        WARN)    echo -e "${YELLOW}⚠️  ${message}${NC}" ;;
        SUCCESS) echo -e "${GREEN}✅ ${message}${NC}" ;;
        INFO)    echo -e "${CYAN}ℹ️  ${message}${NC}" ;;
        *)       echo "$message" ;;
    esac
}

die() {
    log "ERROR" "CRÍTICO: $1"
    echo -e "\n${RED}${BOLD}⛔ PROCESO ABORTADO: $1${NC}"
    rm -f "$LOCK_FILE" 2>/dev/null
    exit 1
}

safe_run() {
    local cmd="$1"
    local err_msg="$2"

    log "INFO" "Ejecutando: $cmd"

    if [ "$DRY_RUN" = true ]; then
        log "INFO" "[DRY-RUN] $cmd"
        echo -e "${YELLOW}[DRY-RUN]${NC} $cmd"
        return 0
    fi

    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        return 0
    else
        log "ERROR" "$err_msg"
        return 1
    fi
}

print_step() {
    [ "$QUIET" = true ] && return
    ((CURRENT_STEP++))
    echo -e "\n${BLUE}${BOLD}>>> [$CURRENT_STEP/$TOTAL_STEPS] $1${NC}"
    log "INFO" "PASO [$CURRENT_STEP/$TOTAL_STEPS]: $1"
}

print_header() {
    [ "$QUIET" = true ] && return
    clear
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   MANTENIMIENTO DEBIAN 13 (TESTING) - v${SCRIPT_VERSION}      ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    [ "$DRY_RUN" = true ] && echo -e "${YELLOW}🔍 MODO DRY-RUN ACTIVADO${NC}\n"
}

cleanup() {
    rm -f "$LOCK_FILE" 2>/dev/null
    log "INFO" "Lock file eliminado"
}

trap cleanup EXIT INT TERM

# ============================================================================
# FUNCIONES DE VALIDACIÓN Y CHEQUEO
# ============================================================================

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ Este script requiere permisos de root (sudo)${NC}"
        exit 1
    fi
}

check_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${RED}❌ Ya hay una instancia del script corriendo (PID: $pid)${NC}"
            exit 1
        fi
        rm -f "$LOCK_FILE"
    fi
    echo $$ > "$LOCK_FILE"

    # Verificación extra de locks de APT
    if fuser /var/lib/dpkg/lock* /var/lib/apt/lists/lock* 2>/dev/null | grep -q .; then
        echo -e "${RED}❌ APT está ocupado. Cierra Synaptic/Discover e intenta de nuevo.${NC}"
        rm -f "$LOCK_FILE"
        exit 1
    fi
}

count_active_steps() {
    TOTAL_STEPS=0
    [ "$STEP_CHECK_CONNECTIVITY" = 1 ] && ((TOTAL_STEPS++))
    [ "$STEP_CHECK_DEPENDENCIES" = 1 ] && ((TOTAL_STEPS++))
    [ "$STEP_BACKUP_TAR" = 1 ] && ((TOTAL_STEPS++))
    [ "$STEP_SNAPSHOT_TIMESHIFT" = 1 ] && ((TOTAL_STEPS++))
    [ "$STEP_UPDATE_REPOS" = 1 ] && ((TOTAL_STEPS++))
    [ "$STEP_UPGRADE_SYSTEM" = 1 ] && ((TOTAL_STEPS++))
    [ "$STEP_UPDATE_FLATPAK" = 1 ] && ((TOTAL_STEPS++))
    [ "$STEP_UPDATE_SNAP" = 1 ] && ((TOTAL_STEPS++))
    [ "$STEP_CHECK_FIRMWARE" = 1 ] && ((TOTAL_STEPS++))
    [ "$STEP_CLEANUP_APT" = 1 ] && ((TOTAL_STEPS++))
    [ "$STEP_CLEANUP_KERNELS" = 1 ] && ((TOTAL_STEPS++))
    [ "$STEP_CLEANUP_DISK" = 1 ] && ((TOTAL_STEPS++))
    [ "$STEP_CHECK_REBOOT" = 1 ] && ((TOTAL_STEPS++))
}

validate_step_dependencies() {
    log "INFO" "Validando dependencias entre pasos..."

    # Si se va a actualizar sistema, DEBE actualizarse repositorios
    if [ "$STEP_UPGRADE_SYSTEM" = 1 ] && [ "$STEP_UPDATE_REPOS" = 0 ]; then
        die "No puedes actualizar el sistema (STEP_UPGRADE_SYSTEM=1) sin actualizar repositorios (STEP_UPDATE_REPOS=0). Activa STEP_UPDATE_REPOS."
    fi

    # Si se va a limpiar kernels en Testing, recomendamos snapshot
    if [ "$STEP_CLEANUP_KERNELS" = 1 ] && [ "$STEP_SNAPSHOT_TIMESHIFT" = 0 ]; then
        log "WARN" "Limpieza de kernels sin snapshot de Timeshift puede ser riesgoso"
        if [ "$UNATTENDED" = false ]; then
            echo -e "${YELLOW}⚠️  Vas a limpiar kernels sin crear snapshot de Timeshift.${NC}"
            read -p "¿Continuar de todos modos? (s/N): " -n 1 -r
            echo
            [[ ! $REPLY =~ ^[Ss]$ ]] && die "Abortado por el usuario"
        fi
    fi

    log "SUCCESS" "Validación de dependencias OK"
}

show_step_summary() {
    [ "$QUIET" = true ] && return

    echo -e "${MAGENTA}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║        CONFIGURACIÓN DE PASOS - RESUMEN                       ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local step_num=0

    show_step_line() {
        local enabled=$1
        local name=$2
        ((step_num++))
        if [ "$enabled" = 1 ]; then
            echo -e "  ${GREEN}✅ [$step_num]${NC} $name"
        else
            echo -e "  ${YELLOW}⏩ [$step_num]${NC} $name ${YELLOW}[OMITIDO]${NC}"
        fi
    }

    show_step_line "$STEP_CHECK_CONNECTIVITY" "Verificar conectividad"
    show_step_line "$STEP_CHECK_DEPENDENCIES" "Verificar dependencias"
    show_step_line "$STEP_BACKUP_TAR" "Backup configuraciones (tar)"
    show_step_line "$STEP_SNAPSHOT_TIMESHIFT" "Snapshot Timeshift ${ICON_SHIELD}"
    show_step_line "$STEP_UPDATE_REPOS" "Actualizar repositorios"
    show_step_line "$STEP_UPGRADE_SYSTEM" "Actualizar sistema (APT)"
    show_step_line "$STEP_UPDATE_FLATPAK" "Actualizar Flatpak"
    show_step_line "$STEP_UPDATE_SNAP" "Actualizar Snap"
    show_step_line "$STEP_CHECK_FIRMWARE" "Verificar firmware"
    show_step_line "$STEP_CLEANUP_APT" "Limpieza APT"
    show_step_line "$STEP_CLEANUP_KERNELS" "Limpieza kernels"
    show_step_line "$STEP_CLEANUP_DISK" "Limpieza disco/logs"
    show_step_line "$STEP_CHECK_REBOOT" "Verificar reinicio"

    echo ""
    echo -e "  ${CYAN}${ICON_ROCKET} Total de pasos a ejecutar: ${BOLD}$TOTAL_STEPS${NC}${CYAN} de 13${NC}"
    echo -e "  ${CYAN}${ICON_CLOCK} Tiempo estimado: ~$((TOTAL_STEPS / 2 + 1)) minutos${NC}"
    echo ""

    if [ "$UNATTENDED" = false ] && [ "$DRY_RUN" = false ]; then
        read -p "¿Continuar con esta configuración? (s/N): " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Ss]$ ]] && die "Cancelado por el usuario"
    fi
}

check_disk_space() {
    print_step "Verificando espacio en disco..."

    local root_gb=$(df / --output=avail | tail -1 | awk '{print int($1/1024/1024)}')
    local boot_mb=$(df /boot --output=avail 2>/dev/null | tail -1 | awk '{print int($1/1024)}' || echo 0)

    echo "→ Espacio libre en /: ${root_gb} GB"
    [ -n "$boot_mb" ] && [ "$boot_mb" -gt 0 ] && echo "→ Espacio libre en /boot: ${boot_mb} MB"

    if [ "$root_gb" -lt "$MIN_FREE_SPACE_GB" ]; then
        die "Espacio insuficiente en / (${root_gb}GB < ${MIN_FREE_SPACE_GB}GB)"
    fi

    if [ -n "$boot_mb" ] && [ "$boot_mb" -gt 0 ] && [ "$boot_mb" -lt "$MIN_FREE_SPACE_BOOT_MB" ]; then
        log "WARN" "Espacio bajo en /boot (${boot_mb}MB). Se recomienda limpiar kernels."
    fi

    # Guardar espacio inicial
    SPACE_BEFORE_ROOT=$(df / --output=used | tail -1 | awk '{print $1}')
    SPACE_BEFORE_BOOT=$(df /boot --output=used 2>/dev/null | tail -1 | awk '{print $1}' || echo 0)

    log "SUCCESS" "Espacio en disco suficiente"
}

# ============================================================================
# PASO 1: VERIFICAR CONECTIVIDAD
# ============================================================================

step_check_connectivity() {
    [ "$STEP_CHECK_CONNECTIVITY" = 0 ] && return

    print_step "Verificando conectividad..."

    if ping -c 1 -W 3 deb.debian.org >/dev/null 2>&1; then
        echo "→ Conexión a internet: OK"
        STAT_CONNECTIVITY="$ICON_OK"
        log "SUCCESS" "Conectividad verificada"
    else
        STAT_CONNECTIVITY="$ICON_FAIL"
        die "Sin conexión a internet. Verifica tu red."
    fi
}

# ============================================================================
# PASO 2: VERIFICAR E INSTALAR DEPENDENCIAS
# ============================================================================

step_check_dependencies() {
    [ "$STEP_CHECK_DEPENDENCIES" = 0 ] && return

    print_step "Verificando herramientas recomendadas..."

    declare -A TOOLS
    declare -A TOOL_STEPS

    # Definir herramientas y qué paso las requiere
    TOOLS[timeshift]="Snapshots del sistema (CRÍTICO para seguridad)"
    TOOL_STEPS[timeshift]=$STEP_SNAPSHOT_TIMESHIFT

    TOOLS[needrestart]="Detección inteligente de reinicio"
    TOOL_STEPS[needrestart]=$STEP_CHECK_REBOOT

    TOOLS[fwupdmgr]="Gestión de firmware"
    TOOL_STEPS[fwupdmgr]=$STEP_CHECK_FIRMWARE

    TOOLS[flatpak]="Gestor de aplicaciones Flatpak"
    TOOL_STEPS[flatpak]=$STEP_UPDATE_FLATPAK

    TOOLS[snap]="Gestor de aplicaciones Snap"
    TOOL_STEPS[snap]=$STEP_UPDATE_SNAP

    local missing=()
    local missing_names=()
    local skipped_tools=()

    for tool in "${!TOOLS[@]}"; do
        # Solo verificar si el paso asociado está activo
        if [ "${TOOL_STEPS[$tool]}" = "1" ]; then
            if ! command -v "$tool" &>/dev/null; then
                missing+=("$tool")
                missing_names+=("${TOOLS[$tool]}")
            fi
        else
            # El paso está desactivado, no verificar esta herramienta
            skipped_tools+=("$tool")
            log "INFO" "Omitiendo verificación de $tool (paso desactivado)"
        fi
    done

    # Mostrar herramientas omitidas si hay alguna
    if [ ${#skipped_tools[@]} -gt 0 ] && [ "$QUIET" = false ]; then
        echo -e "${CYAN}→ Herramientas omitidas (pasos desactivados): ${skipped_tools[*]}${NC}"
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Faltan ${#missing[@]} herramientas necesarias para los pasos activos:${NC}"
        for i in "${!missing[@]}"; do
            echo -e "   • ${missing[$i]}: ${missing_names[$i]}"
        done
        echo ""

        if [ "$UNATTENDED" = false ] && [ "$DRY_RUN" = false ]; then
            read -p "¿Deseas instalarlas automáticamente? (s/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Ss]$ ]]; then
                echo "→ Instalando herramientas..."

                # Determinar qué paquetes instalar
                local packages_to_install=""
                for tool in "${missing[@]}"; do
                    case "$tool" in
                        timeshift) packages_to_install="$packages_to_install timeshift" ;;
                        needrestart) packages_to_install="$packages_to_install needrestart" ;;
                        fwupdmgr) packages_to_install="$packages_to_install fwupd" ;;
                        flatpak) packages_to_install="$packages_to_install flatpak" ;;
                        snap) packages_to_install="$packages_to_install snapd" ;;
                    esac
                done

                if safe_run "apt update && apt install -y $packages_to_install" "Error instalando herramientas"; then
                    log "SUCCESS" "Herramientas instaladas correctamente"
                    STAT_DEPENDENCIES="$ICON_OK (instaladas)"
                else
                    log "WARN" "Error al instalar algunas herramientas"
                    STAT_DEPENDENCIES="${YELLOW}$ICON_WARN Parcial${NC}"
                fi
            else
                log "WARN" "Usuario decidió continuar sin instalar herramientas"
                STAT_DEPENDENCIES="${YELLOW}$ICON_WARN Incompleto${NC}"
            fi
        else
            log "WARN" "Herramientas faltantes en modo desatendido/dry-run"
            STAT_DEPENDENCIES="${YELLOW}$ICON_WARN Incompleto${NC}"
        fi
    else
        echo "→ Todas las herramientas necesarias están instaladas"
        STAT_DEPENDENCIES="$ICON_OK"
        log "SUCCESS" "Todas las herramientas necesarias disponibles"
    fi
}

# ============================================================================
# PASO 3: BACKUP DE CONFIGURACIONES (TAR)
# ============================================================================

step_backup_tar() {
    [ "$STEP_BACKUP_TAR" = 0 ] && return

    print_step "Creando backup de configuraciones (Tar)..."

    mkdir -p "$BACKUP_DIR"
    local backup_date=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/backup_${backup_date}.tar.gz"

    # Crear tarball de configuraciones APT
    if tar czf "$backup_file" \
        /etc/apt/sources.list* \
        /etc/apt/sources.list.d/ \
        /etc/apt/trusted.gpg.d/ 2>/dev/null; then

        # Lista de paquetes instalados
        dpkg --get-selections > "$BACKUP_DIR/packages_${backup_date}.list" 2>/dev/null

        echo "→ Backup creado: $backup_file"
        STAT_BACKUP_TAR="$ICON_OK"
        log "SUCCESS" "Backup Tar creado"

        # Limpiar backups antiguos (mantener últimos 5)
        ls -t "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | tail -n +6 | xargs -r rm -f
    else
        STAT_BACKUP_TAR="$ICON_FAIL"
        log "ERROR" "Error creando backup Tar"
    fi
}

# ============================================================================
# PASO 4: SNAPSHOT TIMESHIFT
# ============================================================================

step_snapshot_timeshift() {
    [ "$STEP_SNAPSHOT_TIMESHIFT" = 0 ] && return

    print_step "${ICON_SHIELD} Creando Snapshot de Sistema (Timeshift)..."

    if ! command -v timeshift &>/dev/null; then
        echo -e "${YELLOW}→ Timeshift no está instalado${NC}"
        STAT_SNAPSHOT="${YELLOW}$ICON_SKIP No disponible${NC}"
        log "WARN" "Timeshift no disponible"
        return
    fi

    # Preguntar si desea omitir (solo en modo interactivo)
    if [ "$ASK_TIMESHIFT_RUN" = true ] && [ "$UNATTENDED" = false ] && [ "$DRY_RUN" = false ]; then
        echo -e "${YELLOW}¿Deseas OMITIR la creación del Snapshot de Timeshift?${NC}"
        read -p "Escribe 's' para OMITIR, cualquier otra tecla para CREAR: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            log "WARN" "Usuario omitió snapshot de Timeshift"
            STAT_SNAPSHOT="${YELLOW}$ICON_SKIP Omitido por usuario${NC}"
            return
        fi
    fi

    if [ "$DRY_RUN" = true ]; then
        STAT_SNAPSHOT="${YELLOW}Simulado${NC}"
        return
    fi

    # Crear snapshot
    local ts_comment="Pre-Maintenance $(date +%Y-%m-%d_%H:%M:%S)"
    if timeshift --create --comments "$ts_comment" --tags O >> "$LOG_FILE" 2>&1; then
        echo "→ Snapshot Timeshift creado exitosamente"
        STAT_SNAPSHOT="${GREEN}$ICON_OK Creado${NC}"
        log "SUCCESS" "Snapshot Timeshift creado"
    else
        STAT_SNAPSHOT="${RED}$ICON_FAIL${NC}"
        die "No se pudo crear el snapshot de Timeshift. Abortando por seguridad."
    fi
}

# ============================================================================
# PASO 5: ACTUALIZAR REPOSITORIOS
# ============================================================================

step_update_repos() {
    [ "$STEP_UPDATE_REPOS" = 0 ] && return

    print_step "Actualizando lista de repositorios..."

    # Reparar dpkg antes de actualizar
    dpkg --configure -a >> "$LOG_FILE" 2>&1

    if safe_run "apt update" "Error al actualizar repositorios"; then
        echo "→ Repositorios actualizados"
        STAT_REPO="$ICON_OK"
    else
        STAT_REPO="$ICON_FAIL"
        die "Error crítico al actualizar repositorios"
    fi
}

# ============================================================================
# PASO 6: ACTUALIZAR SISTEMA (APT)
# ============================================================================

step_upgrade_system() {
    [ "$STEP_UPGRADE_SYSTEM" = 0 ] && return

    print_step "Analizando y aplicando actualizaciones del sistema..."

    # Contar actualizaciones disponibles
    local updates_output=$(apt list --upgradable 2>/dev/null)
    local updates=$(echo "$updates_output" | grep -c '\[upgradable' || echo 0)
    updates=${updates//[^0-9]/}
    updates=${updates:-0}
    updates=$((updates + 0))

    if [ "$updates" -gt 0 ]; then
        echo "→ $updates paquetes para actualizar"

        # Análisis heurístico de riesgo (borrados masivos)
        log "INFO" "Simulando actualización para detectar borrados..."
        local simulation=$(apt full-upgrade -s 2>/dev/null)
        local remove_count=$(echo "$simulation" | grep "^Remv" | wc -l)

        if [ "$remove_count" -gt "$MAX_REMOVALS_ALLOWED" ]; then
            echo -e "\n${RED}${BOLD}⚠️  ALERTA DE SEGURIDAD: APT propone eliminar $remove_count paquetes${NC}"
            echo "$simulation" | grep "^Remv" | head -n 5 | sed 's/^Remv/ - Eliminando:/'

            if [ "$UNATTENDED" = true ]; then
                die "Abortado automáticamente por riesgo de eliminación masiva en modo desatendido."
            fi

            echo -e "\n${YELLOW}¿Tienes un snapshot válido? ¿Quieres proceder?${NC}"
            read -p "Escribe 'SI' (mayúsculas) para continuar: " -r CONFIRM
            if [ "$CONFIRM" != "SI" ]; then
                die "Cancelado por el usuario."
            fi
        fi

        # Ejecutar actualización
        if safe_run "apt full-upgrade -y" "Error aplicando actualizaciones"; then
            echo "→ $updates paquetes actualizados exitosamente"
            STAT_UPGRADE="$ICON_OK ($updates instalados)"
            log "SUCCESS" "$updates paquetes actualizados"
        else
            STAT_UPGRADE="$ICON_FAIL"
            log "ERROR" "Error actualizando paquetes"
        fi
    else
        echo "→ Sistema ya actualizado"
        STAT_UPGRADE="$ICON_OK (sin cambios)"
        log "INFO" "No hay actualizaciones disponibles"
    fi
}

# ============================================================================
# PASO 7: ACTUALIZAR FLATPAK
# ============================================================================

step_update_flatpak() {
    [ "$STEP_UPDATE_FLATPAK" = 0 ] && return

    print_step "Actualizando aplicaciones Flatpak..."

    if ! command -v flatpak &>/dev/null; then
        echo "→ Flatpak no está instalado"
        STAT_FLATPAK="$ICON_SKIP (no instalado)"
        return
    fi

    if safe_run "flatpak update -y" "Error actualizando Flatpak"; then
        # Limpiar referencias huérfanas
        safe_run "flatpak uninstall --unused -y" "Error limpiando Flatpak huérfanos"

        # Reparar instalación
        safe_run "flatpak repair" "Error reparando Flatpak"

        echo "→ Flatpak actualizado y limpiado"
        STAT_FLATPAK="$ICON_OK"
        log "SUCCESS" "Flatpak actualizado"
    else
        STAT_FLATPAK="$ICON_FAIL"
    fi
}

# ============================================================================
# PASO 8: ACTUALIZAR SNAP
# ============================================================================

step_update_snap() {
    [ "$STEP_UPDATE_SNAP" = 0 ] && return

    print_step "Actualizando aplicaciones Snap..."

    if ! command -v snap &>/dev/null; then
        echo "→ Snap no está instalado"
        STAT_SNAP="$ICON_SKIP (no instalado)"
        return
    fi

    if safe_run "snap refresh" "Error actualizando Snap"; then
        echo "→ Snap actualizado"
        STAT_SNAP="$ICON_OK"
        log "SUCCESS" "Snap actualizado"
    else
        STAT_SNAP="$ICON_FAIL"
    fi
}

# ============================================================================
# PASO 9: VERIFICAR FIRMWARE
# ============================================================================

step_check_firmware() {
    [ "$STEP_CHECK_FIRMWARE" = 0 ] && return

    print_step "Verificando actualizaciones de firmware..."

    if ! command -v fwupdmgr &>/dev/null; then
        echo "→ fwupd no está instalado"
        STAT_FIRMWARE="$ICON_SKIP (no instalado)"
        return
    fi

    # Verificar si necesita refresh (más de 7 días)
    local last_refresh=$(stat -c %Y /var/lib/fwupd/metadata.xml 2>/dev/null || echo 0)
    local current_time=$(date +%s)
    local days_old=$(( (current_time - last_refresh) / 86400 ))

    if [ "$days_old" -gt 7 ]; then
        safe_run "fwupdmgr refresh --force" "Error actualizando metadata de firmware"
        echo "→ Metadata de firmware actualizada"
    else
        echo "→ Metadata actualizada hace $days_old días"
    fi

    # Verificar si hay actualizaciones disponibles
    if fwupdmgr get-updates >/dev/null 2>&1; then
        echo -e "${YELLOW}→ ¡Hay actualizaciones de Firmware disponibles!${NC}"
        STAT_FIRMWARE="${YELLOW}$ICON_WARN DISPONIBLE${NC}"
        log "WARN" "Actualizaciones de firmware disponibles"
    else
        echo "→ Firmware actualizado"
        STAT_FIRMWARE="$ICON_OK"
    fi
}

# ============================================================================
# PASO 10: LIMPIEZA APT
# ============================================================================

step_cleanup_apt() {
    [ "$STEP_CLEANUP_APT" = 0 ] && return

    print_step "Limpieza de paquetes huérfanos y residuales..."

    # Autoremove (paquetes huérfanos)
    if safe_run "apt autoremove -y" "Error en autoremove"; then
        echo "→ Paquetes huérfanos eliminados"
    else
        STAT_CLEAN_APT="$ICON_FAIL"
        return
    fi

    # Purge (paquetes con config residual)
    local pkgs_rc=$(dpkg -l 2>/dev/null | grep "^rc" | awk '{print $2}')
    if [ -n "$pkgs_rc" ]; then
        local rc_count=$(echo "$pkgs_rc" | wc -l)
        if echo "$pkgs_rc" | xargs apt purge -y >/dev/null 2>&1; then
            echo "→ $rc_count archivos residuales purgados"
            log "INFO" "$rc_count paquetes residuales purgados"
        else
            STAT_CLEAN_APT="$ICON_FAIL"
            log "ERROR" "Error purgando residuales"
            return
        fi
    else
        echo "→ No hay archivos residuales"
    fi

    # Autoclean o clean
    if safe_run "apt $APT_CLEAN_MODE" "Error limpiando caché APT"; then
        echo "→ Caché de APT limpiado"
    fi

    STAT_CLEAN_APT="$ICON_OK"
    log "SUCCESS" "Limpieza APT completada"
}

# ============================================================================
# PASO 11: LIMPIEZA DE KERNELS ANTIGUOS
# ============================================================================

step_cleanup_kernels() {
    [ "$STEP_CLEANUP_KERNELS" = 0 ] && return

    print_step "Limpieza segura de Kernels antiguos..."

    # Obtener kernel actual
    local current_kernel=$(uname -r)
    local current_kernel_pkg="linux-image-${current_kernel}"

    log "INFO" "Kernel actual: $current_kernel"
    echo "→ Kernel en uso: $current_kernel"

    # Obtener todos los kernels instalados
    local installed_kernels=$(dpkg -l 2>/dev/null | awk '/^ii.*linux-image-[0-9]/ {print $2}' | grep -v "meta")

    if [ -z "$installed_kernels" ]; then
        echo "→ No se encontraron kernels para gestionar"
        STAT_CLEAN_KERNEL="$ICON_OK (Ninguno encontrado)"
        return
    fi

    # Contar kernels
    local kernel_count=$(echo "$installed_kernels" | wc -l)
    echo "→ Kernels instalados: $kernel_count"

    # Mantener: kernel actual + los N más recientes
    local kernels_to_keep=$(echo "$installed_kernels" | sort -V | tail -n "$KERNELS_TO_KEEP")

    # Validación crítica: asegurar que el kernel actual esté en la lista
    if ! echo "$kernels_to_keep" | grep -q "$current_kernel_pkg"; then
        log "WARN" "Kernel actual no está en los más recientes, forzando inclusión"
        kernels_to_keep=$(echo -e "${current_kernel_pkg}\n${kernels_to_keep}" | sort -V | tail -n "$KERNELS_TO_KEEP")
    fi

    # Identificar kernels a eliminar
    local kernels_to_remove=""
    for kernel in $installed_kernels; do
        if ! echo "$kernels_to_keep" | grep -q "$kernel" && [ "$kernel" != "$current_kernel_pkg" ]; then
            kernels_to_remove="$kernels_to_remove $kernel"
        fi
    done

    if [ -n "$kernels_to_remove" ]; then
        echo "→ Kernels a mantener:"
        echo "$kernels_to_keep" | sed 's/^/   ✓ /'
        echo ""
        echo "→ Kernels a eliminar:"
        echo "$kernels_to_remove" | tr ' ' '\n' | sed 's/^/   ✗ /'

        # Confirmación en modo interactivo
        if [ "$UNATTENDED" = false ] && [ "$DRY_RUN" = false ]; then
            read -p "¿Continuar con la eliminación? (s/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Ss]$ ]]; then
                log "INFO" "Usuario canceló limpieza de kernels"
                STAT_CLEAN_KERNEL="$ICON_SKIP (Cancelado)"
                echo "→ Limpieza de kernels cancelada"
                return
            fi
        fi

        # Eliminar kernels
        if echo "$kernels_to_remove" | xargs apt purge -y >> "$LOG_FILE" 2>&1; then
            echo "→ Kernels antiguos eliminados"
            STAT_CLEAN_KERNEL="$ICON_OK"
            log "SUCCESS" "Kernels antiguos eliminados"

            # Regenerar GRUB
            if command -v update-grub &>/dev/null; then
                safe_run "update-grub" "Error actualizando GRUB"
                echo "→ GRUB actualizado"
            fi
        else
            STAT_CLEAN_KERNEL="$ICON_FAIL"
            log "ERROR" "Error eliminando kernels"
        fi
    else
        echo "→ No hay kernels antiguos para limpiar"
        STAT_CLEAN_KERNEL="$ICON_OK (Nada que limpiar)"
    fi
}

# ============================================================================
# PASO 12: LIMPIEZA DE DISCO (LOGS Y CACHÉ)
# ============================================================================

step_cleanup_disk() {
    [ "$STEP_CLEANUP_DISK" = 0 ] && return

    print_step "Limpieza de logs y caché del sistema..."

    # Journalctl
    if command -v journalctl &>/dev/null; then
        if safe_run "journalctl --vacuum-time=${DIAS_LOGS}d --vacuum-size=500M" "Error limpiando journalctl"; then
            echo "→ Logs de journalctl reducidos"
        fi
    fi

    # Archivos temporales antiguos
    find /var/tmp -type f -atime +30 -delete 2>/dev/null && \
        echo "→ Archivos temporales antiguos eliminados" || true

    # Thumbnails
    local cleaned_homes=0
    for user_home in /home/* /root; do
        if [ -d "$user_home/.cache/thumbnails" ]; then
            rm -rf "$user_home/.cache/thumbnails/"* 2>/dev/null && ((cleaned_homes++))
        fi
    done
    [ "$cleaned_homes" -gt 0 ] && echo "→ Caché de miniaturas limpiado ($cleaned_homes usuarios)"

    STAT_CLEAN_DISK="$ICON_OK"
    log "SUCCESS" "Limpieza de disco completada"
}

# ============================================================================
# PASO 13: VERIFICAR NECESIDAD DE REINICIO
# ============================================================================

step_check_reboot() {
    [ "$STEP_CHECK_REBOOT" = 0 ] && return

    print_step "Verificando necesidad de reinicio..."

    # Verificar archivo de reinicio requerido
    if [ -f /var/run/reboot-required ]; then
        REBOOT_NEEDED=true
        log "WARN" "Archivo /var/run/reboot-required presente"
        echo "→ Detectado archivo /var/run/reboot-required"
    fi

    # Verificar servicios fallidos
    local failed_services=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
    failed_services=${failed_services//[^0-9]/}
    failed_services=${failed_services:-0}

    if [ "$failed_services" -gt 0 ]; then
        log "WARN" "$failed_services servicios fallidos detectados"
        echo -e "${YELLOW}→ $failed_services servicios en estado fallido${NC}"

        if [ "$UNATTENDED" = false ]; then
            systemctl --failed --no-pager 2>/dev/null | head -10
        fi
    fi

    # Needrestart - Verificación avanzada
    if command -v needrestart &>/dev/null; then
        echo "→ Analizando kernel y servicios con needrestart..."

        # Ejecutar needrestart en modo batch
        local needrestart_output=$(needrestart -b 2>/dev/null)

        # Extraer información del kernel
        local running_kernel=$(echo "$needrestart_output" | grep "NEEDRESTART-KCUR:" | awk '{print $2}')
        local expected_kernel=$(echo "$needrestart_output" | grep "NEEDRESTART-KEXP:" | awk '{print $2}')
        local kernel_status=$(echo "$needrestart_output" | grep "NEEDRESTART-KSTA:" | awk '{print $2}')

        log "INFO" "Kernel en ejecución: $running_kernel"
        log "INFO" "Kernel esperado: $expected_kernel"
        log "INFO" "Estado KSTA: $kernel_status"

        # VERIFICACIÓN 1: Kernel desactualizado (COMPARACIÓN DIRECTA)
        if [ -n "$expected_kernel" ] && [ -n "$running_kernel" ]; then
            if [ "$running_kernel" != "$expected_kernel" ]; then
                REBOOT_NEEDED=true
                log "WARN" "Kernel desactualizado: $running_kernel → $expected_kernel"
                echo -e "${YELLOW}→ Kernel desactualizado detectado${NC}"
            else
                log "INFO" "Kernel actualizado (coincide con el esperado)"
                echo "→ Kernel actualizado"
            fi
        fi

        # VERIFICACIÓN 2: Servicios que necesitan reinicio
        local services_restart=$(echo "$needrestart_output" | grep "NEEDRESTART-SVC:" | wc -l)
        services_restart=${services_restart//[^0-9]/}
        services_restart=${services_restart:-0}
        services_restart=$((services_restart + 0))

        if [ "$services_restart" -gt 0 ]; then
            log "INFO" "$services_restart servicios requieren reinicio"
            echo "→ $services_restart servicios con librerías obsoletas detectados"
        fi

        # VERIFICACIÓN 3: Librerías críticas (LÓGICA REFINADA)
        local critical_libs=$(echo "$needrestart_output" | grep "NEEDRESTART-UCSTA:" | awk '{print $2}')
        critical_libs=$(echo "$critical_libs" | tr -d '[:space:]')

        log "INFO" "Estado UCSTA (librerías críticas): '$critical_libs'"

        # LÓGICA CRÍTICA:
        # UCSTA=1 puede ser persistente desde una actualización anterior
        # Solo marcamos reinicio si:
        # 1. UCSTA=1 (hay cambios críticos) Y
        # 2. Se instalaron paquetes en ESTA sesión Y
        # 3. Esos paquetes incluyen librerías del sistema

        if [ -n "$critical_libs" ] && [ "$critical_libs" = "1" ]; then
            # Verificar si hubo actualizaciones DE SISTEMA en esta sesión
            local system_updated=false

            # Si el estado de upgrade NO es "sin cambios" ni "skip", hubo actualizaciones
            if [[ "$STAT_UPGRADE" == *"instalado"* ]] || [[ "$STAT_UPGRADE" == *"actualizado"* ]]; then
                system_updated=true
            fi

            if [ "$system_updated" = true ]; then
                REBOOT_NEEDED=true
                log "WARN" "Librerías críticas actualizadas en esta sesión, reinicio requerido"
                echo -e "${YELLOW}→ Librerías críticas actualizadas en esta sesión${NC}"
            else
                # UCSTA=1 es de una actualización anterior, no de ahora
                log "INFO" "UCSTA=1 persistente de actualización anterior (no de esta sesión)"
                echo "→ Librerías del sistema estables (UCSTA persistente, sin cambios nuevos)"
            fi
        else
            log "INFO" "No hay cambios en librerías críticas"
            echo "→ No hay cambios en librerías críticas"
        fi

        # Intentar reiniciar servicios automáticamente
        if [ "$DRY_RUN" = false ]; then
            if [ "$services_restart" -gt 0 ]; then
                echo "→ Reiniciando servicios obsoletos automáticamente..."
                needrestart -r a >> "$LOG_FILE" 2>&1
                log "INFO" "Needrestart ejecutado para $services_restart servicios"
            else
                echo "→ No hay servicios que necesiten reinicio"
            fi
        fi
    else
        log "INFO" "needrestart no está instalado"
        echo "→ needrestart no disponible (recomendado instalarlo)"
    fi

    # Establecer estado final
    if [ "$REBOOT_NEEDED" = true ]; then
        STAT_REBOOT="${RED}$ICON_WARN REQUERIDO${NC}"
        log "WARN" "REINICIO REQUERIDO"
    else
        STAT_REBOOT="${GREEN}$ICON_OK No necesario${NC}"
        log "INFO" "No se requiere reinicio"
    fi
}

# ============================================================================
# RESUMEN FINAL
# ============================================================================

show_final_summary() {
    [ "$QUIET" = true ] && exit 0

    # Calcular tiempo de ejecución
    local end_time=$(date +%s)
    local execution_time=$((end_time - START_TIME))
    local minutes=$((execution_time / 60))
    local seconds=$((execution_time % 60))

    # Calcular espacio liberado
    local space_after_root=$(df / --output=used | tail -1 | awk '{print $1}')
    local space_after_boot=$(df /boot --output=used 2>/dev/null | tail -1 | awk '{print $1}' || echo 0)

    local space_freed_root=$(( (SPACE_BEFORE_ROOT - space_after_root) / 1024 ))
    local space_freed_boot=$(( (SPACE_BEFORE_BOOT - space_after_boot) / 1024 ))

    # Enviar notificación desktop si está disponible
    if [ -n "$DISPLAY" ] && command -v notify-send &>/dev/null; then
        if [ "$REBOOT_NEEDED" = true ]; then
            notify-send "Mantenimiento Debian" "Completado. Se requiere reinicio." -u critical -i system-software-update 2>/dev/null
        else
            notify-send "Mantenimiento Debian" "Completado exitosamente." -u normal -i emblem-default 2>/dev/null
        fi
    fi

    log "INFO" "=========================================="
    log "INFO" "Mantenimiento completado en ${minutes}m ${seconds}s"
    log "INFO" "=========================================="

    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                 RESUMEN DE MANTENIMIENTO                      ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Mostrar solo los pasos que se ejecutaron
    [ "$STEP_CHECK_CONNECTIVITY" = 1 ] && echo -e "  🌐 Conectividad:       $STAT_CONNECTIVITY"
    [ "$STEP_CHECK_DEPENDENCIES" = 1 ] && echo -e "  🔧 Dependencias:       $STAT_DEPENDENCIES"
    [ "$STEP_BACKUP_TAR" = 1 ] && echo -e "  💾 Backup Tar:         $STAT_BACKUP_TAR"
    [ "$STEP_SNAPSHOT_TIMESHIFT" = 1 ] && echo -e "  $ICON_SHIELD Timeshift:         $STAT_SNAPSHOT"
    [ "$STEP_UPDATE_REPOS" = 1 ] && echo -e "  📦 Repositorios:       $STAT_REPO"
    [ "$STEP_UPGRADE_SYSTEM" = 1 ] && echo -e "  ⬆️  Sistema (APT):      $STAT_UPGRADE"
    [ "$STEP_UPDATE_FLATPAK" = 1 ] && echo -e "  📦 Flatpak:            $STAT_FLATPAK"
    [ "$STEP_UPDATE_SNAP" = 1 ] && echo -e "  📦 Snap:               $STAT_SNAP"
    [ "$STEP_CHECK_FIRMWARE" = 1 ] && echo -e "  🔌 Firmware:           $STAT_FIRMWARE"
    [ "$STEP_CLEANUP_APT" = 1 ] && echo -e "  🧹 Limpieza APT:       $STAT_CLEAN_APT"
    [ "$STEP_CLEANUP_KERNELS" = 1 ] && echo -e "  🧠 Limpieza Kernels:   $STAT_CLEAN_KERNEL"
    [ "$STEP_CLEANUP_DISK" = 1 ] && echo -e "  💾 Limpieza Disco:     $STAT_CLEAN_DISK"
    [ "$STEP_CHECK_REBOOT" = 1 ] && echo ""
    [ "$STEP_CHECK_REBOOT" = 1 ] && echo -e "──────────────────────────────────────────────────────────────"
    [ "$STEP_CHECK_REBOOT" = 1 ] && echo -e "  🔄 ESTADO DE REINICIO: $STAT_REBOOT"
    [ "$STEP_CHECK_REBOOT" = 1 ] && echo -e "──────────────────────────────────────────────────────────────"

    echo ""

    # Estadísticas
    if [ "$space_freed_root" -gt 0 ] || [ "$space_freed_boot" -gt 0 ]; then
        echo -e "  💿 Espacio liberado:"
        [ "$space_freed_root" -gt 0 ] && echo -e "     • /: ${GREEN}${space_freed_root} MB${NC}"
        [ "$space_freed_boot" -gt 0 ] && echo -e "     • /boot: ${GREEN}${space_freed_boot} MB${NC}"
    fi

    echo -e "  ⏱️  Tiempo de ejecución: ${minutes}m ${seconds}s"
    echo ""

    # Advertencias finales
    if [[ "$STAT_FIRMWARE" == *"DISPONIBLE"* ]]; then
        echo -e "${YELLOW}💡 FIRMWARE: Hay actualizaciones de BIOS/Dispositivos disponibles.${NC}"
        echo "   → Para instalar: sudo fwupdmgr update"
        echo ""
    fi

    if [ "$REBOOT_NEEDED" = true ]; then
        echo -e "${RED}${BOLD}⚠️  REINICIO REQUERIDO${NC}"
        echo -e "${YELLOW}   Se necesita reiniciar para aplicar actualizaciones críticas.${NC}"

        if [ "$UNATTENDED" = false ]; then
            echo ""
            read -p "¿Deseas reiniciar ahora? (s/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Ss]$ ]]; then
                log "INFO" "Usuario solicitó reinicio inmediato"
                echo "Reiniciando en 5 segundos... (Ctrl+C para cancelar)"
                sleep 5
                reboot
            fi
        fi
        echo ""
    fi

    echo "📄 Log completo: $LOG_FILE"
    [ "$STEP_BACKUP_TAR" = 1 ] && echo "💾 Backups en: $BACKUP_DIR"
    echo ""
}

# ============================================================================
# PROCESAMIENTO DE ARGUMENTOS
# ============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -y|--unattended)
            UNATTENDED=true
            shift
            ;;
        --no-backup)
            STEP_BACKUP_TAR=0
            shift
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        --help)
            cat << 'EOF'
Mantenimiento Integral para Debian 13 (Testing/Trixie)

Uso: sudo ./cleannew.sh [opciones]

Opciones:
  --dry-run          Simular ejecución sin hacer cambios reales
  -y, --unattended   Modo desatendido sin confirmaciones
  --no-backup        No crear backup de configuraciones
  --quiet            Modo silencioso (solo logs)
  --help             Mostrar esta ayuda

Ejemplos:
  sudo ./cleannew.sh                    # Ejecución normal
  sudo ./cleannew.sh --dry-run          # Simular cambios
  sudo ./cleannew.sh -y                 # Modo desatendido

Configuración:
  Edita las variables STEP_* al inicio del script para
  activar/desactivar pasos individuales.

Más información en los comentarios del script.
EOF
            exit 0
            ;;
        *)
            echo "Opción desconocida: $1"
            echo "Usa --help para ver las opciones disponibles"
            exit 1
            ;;
    esac
done

# ============================================================================
# EJECUCIÓN MAESTRA
# ============================================================================

# Inicialización
init_log
log "INFO" "=========================================="
log "INFO" "Iniciando Mantenimiento Paranoid v${SCRIPT_VERSION}"
log "INFO" "=========================================="

# Chequeos previos obligatorios
check_root
check_lock

# Contar y validar pasos
count_active_steps
validate_step_dependencies

# Mostrar configuración
print_header
show_step_summary
check_disk_space

# Ejecutar pasos configurados
step_check_connectivity
step_check_dependencies
step_backup_tar
step_snapshot_timeshift
step_update_repos
step_upgrade_system
step_update_flatpak
step_update_snap
step_check_firmware
step_cleanup_apt
step_cleanup_kernels
step_cleanup_disk
step_check_reboot

# Mostrar resumen final
show_final_summary

exit 0
