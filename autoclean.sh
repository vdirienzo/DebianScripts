#!/bin/bash
# ============================================================================
# Script de Mantenimiento Integral para Distribuciones basadas en Debian
# ============================================================================
# Versión: 2025 
# Última revisión: Diciembre 2025
# Autor: Homero Thompson del Lago del Terror 
#
# ====================== DISTRIBUCIONES SOPORTADAS ======================
# Este script detecta y soporta automáticamente las siguientes distribuciones:
#   • Debian (todas las versiones: Stable, Testing, Unstable)
#   • Ubuntu (todas las versiones LTS y regulares)
#   • Linux Mint (todas las versiones)
#   • Pop!_OS
#   • Elementary OS
#   • Zorin OS
#   • Kali Linux
#   • Cualquier distribución basada en Debian/Ubuntu (detección automática)
#
# ====================== FILOSOFÍA DE EJECUCIÓN ======================
# Este script implementa un sistema de mantenimiento diseñado
# para distribuciones basadas en Debian/Ubuntu, con énfasis en:
#   1. Seguridad ante todo: Snapshot antes de cambios críticos
#   2. Control granular: Cada paso puede activarse/desactivarse
#   3. Análisis de riesgos: Detecta operaciones peligrosas antes de ejecutar
#   4. Punto de retorno: Timeshift snapshot para rollback completo
#   5. Validación inteligente: Verifica dependencias y estado del sistema
#   6. Detección avanzada de reinicio: Kernel + librerías críticas
#   7. Detección automática de distribución: Adapta servidores y comportamiento
#
# ====================== REQUISITOS DEL SISTEMA ======================
# OBLIGATORIO:
#   • Distribución basada en Debian o Ubuntu
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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/autoclean.conf"
BACKUP_DIR="/var/backups/debian-maintenance"
LOCK_FILE="/var/run/debian-maintenance.lock"
LOG_DIR="/var/log/debian-maintenance"
SCRIPT_VERSION="2025.9-paranoid-multidistro"

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
STEP_UPDATE_SNAP=0           # Actualizar aplicaciones Snap
STEP_CHECK_FIRMWARE=1        # Verificar actualizaciones de firmware
STEP_CLEANUP_APT=1           # Limpieza de paquetes huérfanos
STEP_CLEANUP_KERNELS=1       # Eliminar kernels antiguos
STEP_CLEANUP_DISK=1          # Limpiar logs y caché
STEP_CHECK_REBOOT=1          # Verificar necesidad de reinicio

# ============================================================================
# VARIABLES DE DISTRIBUCIÓN
# ============================================================================

# Estas variables se llenan automáticamente al detectar la distribución
DISTRO_ID=""
DISTRO_NAME=""
DISTRO_VERSION=""
DISTRO_CODENAME=""
DISTRO_FAMILY=""  # debian, ubuntu, mint
DISTRO_MIRROR=""  # Servidor para verificar conectividad

# Distribuciones soportadas
SUPPORTED_DISTROS="debian ubuntu linuxmint pop elementary zorin kali"

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
NO_MENU=false

# ============================================================================
# CONFIGURACIÓN DEL MENÚ INTERACTIVO
# ============================================================================

# Arrays para el menú interactivo (índice corresponde a cada paso)
MENU_STEP_NAMES=(
    "Verificar conectividad"
    "Verificar dependencias"
    "Backup configuraciones (tar)"
    "Snapshot Timeshift 🛡️"
    "Actualizar repositorios"
    "Actualizar sistema (APT)"
    "Actualizar Flatpak"
    "Actualizar Snap"
    "Verificar firmware"
    "Limpieza APT"
    "Limpieza kernels"
    "Limpieza disco/logs"
    "Verificar reinicio"
)

MENU_STEP_VARS=(
    "STEP_CHECK_CONNECTIVITY"
    "STEP_CHECK_DEPENDENCIES"
    "STEP_BACKUP_TAR"
    "STEP_SNAPSHOT_TIMESHIFT"
    "STEP_UPDATE_REPOS"
    "STEP_UPGRADE_SYSTEM"
    "STEP_UPDATE_FLATPAK"
    "STEP_UPDATE_SNAP"
    "STEP_CHECK_FIRMWARE"
    "STEP_CLEANUP_APT"
    "STEP_CLEANUP_KERNELS"
    "STEP_CLEANUP_DISK"
    "STEP_CHECK_REBOOT"
)

MENU_STEP_DESCRIPTIONS=(
    "Verifica conexión a internet antes de continuar"
    "Instala herramientas necesarias (timeshift, needrestart, etc.)"
    "Guarda configuraciones APT en /var/backups"
    "Crea snapshot del sistema para rollback (RECOMENDADO)"
    "Ejecuta apt update para actualizar lista de paquetes"
    "Ejecuta apt full-upgrade para actualizar paquetes"
    "Actualiza aplicaciones instaladas con Flatpak"
    "Actualiza aplicaciones instaladas con Snap"
    "Verifica actualizaciones de BIOS/dispositivos"
    "Elimina paquetes huérfanos y residuales"
    "Elimina kernels antiguos (mantiene 3)"
    "Limpia logs antiguos y caché del sistema"
    "Detecta si el sistema necesita reiniciarse"
)

# ============================================================================
# FUNCIONES DE CONFIGURACIÓN PERSISTENTE
# ============================================================================

save_config() {
    # Guardar estado actual de los pasos en archivo de configuración
    cat > "$CONFIG_FILE" << EOF
# Configuración de autoclean - Generado automáticamente
# Fecha: $(date '+%Y-%m-%d %H:%M:%S')
# No editar manualmente (usar el menú interactivo)

STEP_CHECK_CONNECTIVITY=$STEP_CHECK_CONNECTIVITY
STEP_CHECK_DEPENDENCIES=$STEP_CHECK_DEPENDENCIES
STEP_BACKUP_TAR=$STEP_BACKUP_TAR
STEP_SNAPSHOT_TIMESHIFT=$STEP_SNAPSHOT_TIMESHIFT
STEP_UPDATE_REPOS=$STEP_UPDATE_REPOS
STEP_UPGRADE_SYSTEM=$STEP_UPGRADE_SYSTEM
STEP_UPDATE_FLATPAK=$STEP_UPDATE_FLATPAK
STEP_UPDATE_SNAP=$STEP_UPDATE_SNAP
STEP_CHECK_FIRMWARE=$STEP_CHECK_FIRMWARE
STEP_CLEANUP_APT=$STEP_CLEANUP_APT
STEP_CLEANUP_KERNELS=$STEP_CLEANUP_KERNELS
STEP_CLEANUP_DISK=$STEP_CLEANUP_DISK
STEP_CHECK_REBOOT=$STEP_CHECK_REBOOT
EOF
    local result=$?

    # Cambiar ownership al usuario que ejecutó sudo (no root)
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        chown "$SUDO_USER:$SUDO_USER" "$CONFIG_FILE" 2>/dev/null
    fi

    return $result
}

load_config() {
    # Cargar configuración si existe el archivo
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        return 0
    fi
    return 1
}

config_exists() {
    [ -f "$CONFIG_FILE" ]
}

delete_config() {
    rm -f "$CONFIG_FILE" 2>/dev/null
}

# ============================================================================
# COLORES E ICONOS - ENTERPRISE EDITION
# ============================================================================

# Colores base
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Colores brillantes
BRIGHT_RED='\033[1;31m'
BRIGHT_GREEN='\033[1;32m'
BRIGHT_YELLOW='\033[1;33m'
BRIGHT_BLUE='\033[1;34m'
BRIGHT_CYAN='\033[1;36m'
BRIGHT_MAGENTA='\033[1;35m'

# Control de cursor
CURSOR_HIDE='\033[?25l'
CURSOR_SHOW='\033[?25h'
CLEAR_LINE='\033[2K'
MOVE_UP='\033[1A'
SAVE_CURSOR='\033[s'
RESTORE_CURSOR='\033[u'

# Iconos principales
ICON_OK="✅"
ICON_FAIL="❌"
ICON_SKIP="⏩"
ICON_WARN="⚠️"
ICON_SHIELD="🛡️"
ICON_CLOCK="⏱️"
ICON_ROCKET="🚀"

# Iconos adicionales enterprise
ICON_RUNNING="🔄"
ICON_PENDING="⏳"

# Íconos ASCII puros para resumen (garantizado 1 char width)
ICON_SUM_OK='[OK]'
ICON_SUM_FAIL='[XX]'
ICON_SUM_WARN='[!!]'
ICON_SUM_SKIP='[--]'
ICON_SUM_RUN='[..]'
ICON_SUM_PEND='[  ]'
ICON_PACKAGE="📦"
ICON_DISK="💾"
ICON_NETWORK="🌐"
ICON_TOOLS="🔧"
ICON_CLEAN="🧹"
ICON_KERNEL="🧠"
ICON_FIRMWARE="🔌"
ICON_REBOOT="🔄"

# Caracteres para progress bar
PROGRESS_FILLED="█"
PROGRESS_EMPTY="░"
PROGRESS_HEAD="▓"

# Spinner frames (estilo dots)
SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

# Variables de control del spinner
SPINNER_PID=""
SPINNER_ACTIVE=false

# Arrays de estado de pasos para dashboard
declare -a STEP_STATUS_ARRAY
declare -a STEP_TIME_START
declare -a STEP_TIME_END

# Inicializar arrays de estado
for i in {0..12}; do
    STEP_STATUS_ARRAY[$i]="pending"
    STEP_TIME_START[$i]=0
    STEP_TIME_END[$i]=0
done

# Nombres cortos de pasos para dashboard
STEP_SHORT_NAMES=(
    "Conectividad"
    "Dependencias"
    "Backup"
    "Snapshot"
    "Repos"
    "Upgrade"
    "Flatpak"
    "Snap"
    "Firmware"
    "APT Clean"
    "Kernels"
    "Disk"
    "Reboot"
)

# ============================================================================
# FUNCIONES UX/UI ENTERPRISE
# ============================================================================

# ------------------------------------------------------------------------------
# Progress Bar - Muestra barra de progreso visual
# Uso: show_progress_bar current total [width] [label]
# ------------------------------------------------------------------------------
show_progress_bar() {
    local current=$1
    local total=$2
    local width=${3:-40}
    local label=${4:-""}

    # Evitar división por cero
    [ "$total" -eq 0 ] && total=1

    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    # Construir barra
    local bar=""
    for ((i=0; i<filled; i++)); do
        bar+="${PROGRESS_FILLED}"
    done
    if [ $filled -lt $width ] && [ $current -gt 0 ]; then
        bar+="${PROGRESS_HEAD}"
        empty=$((empty - 1))
    fi
    for ((i=0; i<empty; i++)); do
        bar+="${PROGRESS_EMPTY}"
    done

    # Color según progreso
    local color="${CYAN}"
    [ $percent -ge 50 ] && color="${YELLOW}"
    [ $percent -ge 80 ] && color="${GREEN}"
    [ $percent -eq 100 ] && color="${BRIGHT_GREEN}"

    # Imprimir
    printf "\r  ${color}${bar}${NC} %3d%% " "$percent"
    [ -n "$label" ] && printf "${DIM}(%s)${NC}" "$label"
}

# ------------------------------------------------------------------------------
# Progress Bar con ETA
# Uso: show_progress_bar_eta current total start_time [width] [label]
# ------------------------------------------------------------------------------
show_progress_bar_eta() {
    local current=$1
    local total=$2
    local start_time=$3
    local width=${4:-35}
    local label=${5:-""}

    [ "$total" -eq 0 ] && total=1

    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    # Calcular ETA
    local now=$(date +%s)
    local elapsed=$((now - start_time))
    local eta="--:--"

    if [ $current -gt 0 ] && [ $elapsed -gt 0 ]; then
        local rate=$((current * 1000 / elapsed))  # items per 1000 seconds
        if [ $rate -gt 0 ]; then
            local remaining=$(( (total - current) * 1000 / rate ))
            local eta_min=$((remaining / 60))
            local eta_sec=$((remaining % 60))
            eta=$(printf "%02d:%02d" $eta_min $eta_sec)
        fi
    fi

    # Construir barra
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="${PROGRESS_FILLED}"; done
    [ $filled -lt $width ] && [ $current -gt 0 ] && { bar+="${PROGRESS_HEAD}"; empty=$((empty - 1)); }
    for ((i=0; i<empty; i++)); do bar+="${PROGRESS_EMPTY}"; done

    # Color
    local color="${CYAN}"
    [ $percent -ge 50 ] && color="${YELLOW}"
    [ $percent -ge 80 ] && color="${GREEN}"

    printf "\r  ${color}${bar}${NC} %3d%% ${DIM}ETA: %s${NC} " "$percent" "$eta"
    [ -n "$label" ] && printf "${DIM}%s${NC}" "$label"
}

# ------------------------------------------------------------------------------
# Spinner - Animación durante operaciones largas
# Uso: start_spinner "mensaje" && comando && stop_spinner
# ------------------------------------------------------------------------------
start_spinner() {
    local message="${1:-Procesando...}"

    [ "$QUIET" = true ] && return
    [ "$SPINNER_ACTIVE" = true ] && return

    SPINNER_ACTIVE=true

    # Ocultar cursor
    printf "${CURSOR_HIDE}"

    # Iniciar spinner en background
    (
        local i=0
        local frames_count=${#SPINNER_FRAMES[@]}
        while true; do
            printf "\r  ${CYAN}${SPINNER_FRAMES[$i]}${NC} ${message}   "
            i=$(( (i + 1) % frames_count ))
            sleep 0.1
        done
    ) &
    SPINNER_PID=$!
    disown $SPINNER_PID 2>/dev/null
}

stop_spinner() {
    local status=${1:-0}  # 0=success, 1=error, 2=warning, 3=skip
    local message="${2:-}"

    [ "$QUIET" = true ] && return
    [ "$SPINNER_ACTIVE" = false ] && return

    # Detener proceso de spinner
    if [ -n "$SPINNER_PID" ] && kill -0 "$SPINNER_PID" 2>/dev/null; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null
    fi

    SPINNER_PID=""
    SPINNER_ACTIVE=false

    # Limpiar línea y mostrar resultado
    printf "\r${CLEAR_LINE}"

    case $status in
        0) printf "  ${GREEN}${ICON_OK}${NC} ${message}\n" ;;
        1) printf "  ${RED}${ICON_FAIL}${NC} ${message}\n" ;;
        2) printf "  ${YELLOW}${ICON_WARN}${NC} ${message}\n" ;;
        3) printf "  ${GRAY}${ICON_SKIP}${NC} ${message}\n" ;;
    esac

    # Restaurar cursor
    printf "${CURSOR_SHOW}"
}

# ------------------------------------------------------------------------------
# Dashboard de estado en tiempo real
# ------------------------------------------------------------------------------
get_step_icon() {
    local status=$1
    case $status in
        "pending")  echo "${GRAY}${ICON_PENDING}${NC}" ;;
        "running")  echo "${CYAN}${ICON_RUNNING}${NC}" ;;
        "success")  echo "${GREEN}${ICON_OK}${NC}" ;;
        "error")    echo "${RED}${ICON_FAIL}${NC}" ;;
        "skipped")  echo "${YELLOW}${ICON_SKIP}${NC}" ;;
        "warning")  echo "${YELLOW}${ICON_WARN}${NC}" ;;
        *)          echo "${GRAY}○${NC}" ;;
    esac
}

# Íconos de ancho fijo para resumen (evita desalineación)
get_step_icon_summary() {
    local status=$1
    case $status in
        "pending")  echo "${GRAY}${ICON_SUM_PEND}${NC}" ;;
        "running")  echo "${CYAN}${ICON_SUM_RUN}${NC}" ;;
        "success")  echo "${GREEN}${ICON_SUM_OK}${NC}" ;;
        "error")    echo "${RED}${ICON_SUM_FAIL}${NC}" ;;
        "skipped")  echo "${YELLOW}${ICON_SUM_SKIP}${NC}" ;;
        "warning")  echo "${YELLOW}${ICON_SUM_WARN}${NC}" ;;
        *)          echo "${GRAY}${ICON_SUM_PEND}${NC}" ;;
    esac
}

# Función para calcular longitud visible (sin códigos ANSI)
visible_length() {
    local text="$1"
    local clean
    clean=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    echo ${#clean}
}

# Función para imprimir línea con borde alineado automáticamente
print_box_line() {
    local content="$1"
    local box_width=64  # Ancho interno del contenido

    local visible_len
    visible_len=$(visible_length "$content")

    local padding=$((box_width - visible_len))
    [ $padding -lt 0 ] && padding=0

    local spaces
    spaces=$(printf '%*s' "$padding" '')

    echo -e "${BLUE}║${NC} ${content}${spaces} ${BLUE}║${NC}"
}

update_step_status() {
    local step_index=$1
    local new_status=$2  # pending, running, success, error, skipped, warning

    STEP_STATUS_ARRAY[$step_index]="$new_status"

    case $new_status in
        "running")
            STEP_TIME_START[$step_index]=$(date +%s)
            ;;
        "success"|"error"|"skipped"|"warning")
            STEP_TIME_END[$step_index]=$(date +%s)
            ;;
    esac
}

show_dashboard() {
    [ "$QUIET" = true ] && return

    local current_step=${1:-0}
    local step_name=${2:-""}
    local detail=${3:-""}

    # Calcular tiempo transcurrido
    local now=$(date +%s)
    local elapsed=$((now - START_TIME))
    local elapsed_min=$((elapsed / 60))
    local elapsed_sec=$((elapsed % 60))
    local elapsed_str=$(printf "%02d:%02d" $elapsed_min $elapsed_sec)

    # Limpiar pantalla y mostrar dashboard
    clear

    # Header
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${BOLD}DEBIAN MAINTENANCE${NC} v${SCRIPT_VERSION}            ${ICON_CLOCK} ${elapsed_str}  ${BLUE}║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════════╣${NC}"

    # Info del sistema
    printf "${BLUE}║${NC}  ${CYAN}🐧${NC} %-20s ${CYAN}📦${NC} %-20s        ${BLUE}║${NC}\n" "${DISTRO_NAME:0:20}" "${DISTRO_FAMILY^}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════════╣${NC}"

    # Paso actual con detalle
    if [ -n "$step_name" ]; then
        printf "${BLUE}║${NC}  ${BRIGHT_CYAN}▶ Step %d/%d:${NC} %-45s ${BLUE}║${NC}\n" "$((current_step + 1))" "$TOTAL_STEPS" "${step_name:0:45}"
        if [ -n "$detail" ]; then
            printf "${BLUE}║${NC}    ${DIM}%-60s${NC} ${BLUE}║${NC}\n" "${detail:0:60}"
        fi
        echo -e "${BLUE}╠══════════════════════════════════════════════════════════════════╣${NC}"
    fi

    # Grid de estados (4 columnas)
    echo -e "${BLUE}║${NC}                                                                  ${BLUE}║${NC}"

    local col=0
    local line=""
    for i in {0..12}; do
        local icon=$(get_step_icon "${STEP_STATUS_ARRAY[$i]}")
        local name="${STEP_SHORT_NAMES[$i]:0:10}"

        if [ $col -eq 0 ]; then
            line="  "
        fi

        line+=$(printf "%s %-10s  " "$icon" "$name")
        col=$((col + 1))

        if [ $col -eq 4 ] || [ $i -eq 12 ]; then
            printf "${BLUE}║${NC}%-66s${BLUE}║${NC}\n" "$line"
            line=""
            col=0
        fi
    done

    echo -e "${BLUE}║${NC}                                                                  ${BLUE}║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════════╣${NC}"

    # Estadísticas
    local success_count=0
    local error_count=0
    local running_count=0
    for status in "${STEP_STATUS_ARRAY[@]}"; do
        [ "$status" = "success" ] && ((success_count++))
        [ "$status" = "error" ] && ((error_count++))
        [ "$status" = "running" ] && ((running_count++))
    done

    printf "${BLUE}║${NC}  ${GREEN}✓ %d completados${NC}  ${RED}✗ %d errores${NC}  ${CYAN}● %d en progreso${NC}            ${BLUE}║${NC}\n" \
        "$success_count" "$error_count" "$running_count"

    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ------------------------------------------------------------------------------
# Print step mejorado con dashboard
# ------------------------------------------------------------------------------
print_step_enterprise() {
    local step_index=$1
    local step_name=$2
    local step_detail=${3:-""}

    [ "$QUIET" = true ] && return

    # Actualizar estado a running
    update_step_status "$step_index" "running"

    # Mostrar dashboard actualizado
    show_dashboard "$step_index" "$step_name" "$step_detail"

    # Log
    ((CURRENT_STEP++))
    log "INFO" "PASO [$CURRENT_STEP/$TOTAL_STEPS]: $step_name"
}

# ------------------------------------------------------------------------------
# Ejecutar comando con spinner
# ------------------------------------------------------------------------------
run_with_spinner() {
    local message="$1"
    local cmd="$2"
    local success_msg="${3:-$message completado}"
    local error_msg="${4:-Error en $message}"

    start_spinner "$message"

    if [ "$DRY_RUN" = true ]; then
        sleep 0.5  # Simular trabajo
        stop_spinner 0 "[DRY-RUN] $message"
        return 0
    fi

    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        stop_spinner 0 "$success_msg"
        return 0
    else
        stop_spinner 1 "$error_msg"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# Resumen final enterprise
# ------------------------------------------------------------------------------
show_final_summary_enterprise() {
    [ "$QUIET" = true ] && return

    local end_time=$(date +%s)
    local execution_time=$((end_time - START_TIME))
    local minutes=$((execution_time / 60))
    local seconds=$((execution_time % 60))

    # Calcular espacio liberado
    local space_after_root=$(df / --output=used | tail -1 | awk '{print $1}')
    local space_freed_root=$(( (SPACE_BEFORE_ROOT - space_after_root) / 1024 ))
    [ $space_freed_root -lt 0 ] && space_freed_root=0

    # Contar resultados
    local success_count=0
    local error_count=0
    local skipped_count=0
    local warning_count=0

    for status in "${STEP_STATUS_ARRAY[@]}"; do
        case $status in
            "success") ((success_count++)) ;;
            "error") ((error_count++)) ;;
            "skipped") ((skipped_count++)) ;;
            "warning") ((warning_count++)) ;;
        esac
    done

    # Determinar estado general (íconos ASCII de ancho fijo)
    local overall_status="COMPLETED"
    local overall_color="${GREEN}"
    local overall_icon="[OK]"

    if [ $error_count -gt 0 ]; then
        overall_status="COMPLETED WITH ERRORS"
        overall_color="${RED}"
        overall_icon="[XX]"
    elif [ $warning_count -gt 0 ]; then
        overall_status="COMPLETED WITH WARNINGS"
        overall_color="${YELLOW}"
        overall_icon="[!!]"
    fi

    clear
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    print_box_line "                   ${BOLD}EXECUTION SUMMARY${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════════╣${NC}"
    print_box_line "Status: ${overall_color}${overall_icon} ${overall_status}${NC}"
    print_box_line "Duration: $(printf '%02d:%02d' $minutes $seconds)"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════════╣${NC}"
    print_box_line "${BOLD}METRICS${NC}"
    print_box_line " - Steps completed:    ${GREEN}${success_count}${NC}"
    print_box_line " - Steps with errors:  ${RED}${error_count}${NC}"
    print_box_line " - Steps skipped:      ${YELLOW}${skipped_count}${NC}"
    print_box_line " - Space freed:        ${CYAN}${space_freed_root} MB${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════════╣${NC}"
    print_box_line "${BOLD}STEP DETAILS${NC}"

    # Mostrar cada paso con su resultado (íconos de ancho fijo)
    for i in {0..12}; do
        local icon=$(get_step_icon_summary "${STEP_STATUS_ARRAY[$i]}")
        local name="${STEP_SHORT_NAMES[$i]}"
        local time_taken=""

        if [ "${STEP_TIME_END[$i]}" -gt 0 ] && [ "${STEP_TIME_START[$i]}" -gt 0 ]; then
            local step_time=$((STEP_TIME_END[$i] - STEP_TIME_START[$i]))
            time_taken="${step_time}s"
        fi

        # Formatear línea: icono + nombre (20 chars) + tiempo
        local line_content
        line_content=$(printf "%b %-18s %s" "$icon" "$name" "$time_taken")
        print_box_line "$line_content"
    done

    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════════╣${NC}"

    # Reinicio requerido
    if [ "$REBOOT_NEEDED" = true ]; then
        print_box_line "${RED}${BOLD}[!!] REBOOT REQUIRED${NC}"
    else
        print_box_line "${GREEN}[OK] No reboot required${NC}"
    fi

    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════════╣${NC}"
    print_box_line "Log: ${LOG_FILE:0:55}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

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
    echo -e "${BLUE}║       MANTENIMIENTO DE SISTEMA - v${SCRIPT_VERSION}           ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${CYAN}🐧 Distribución:${NC} ${BOLD}${DISTRO_NAME}${NC}"
    echo -e "  ${CYAN}📦 Familia:${NC}      ${DISTRO_FAMILY^} (${DISTRO_CODENAME:-N/A})"
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

detect_distro() {
    # Detectar distribución usando /etc/os-release
    if [ ! -f /etc/os-release ]; then
        die "No se puede detectar la distribución. Archivo /etc/os-release no encontrado."
    fi

    # Cargar variables de os-release
    source /etc/os-release

    DISTRO_ID="${ID:-unknown}"
    DISTRO_NAME="${PRETTY_NAME:-$NAME}"
    DISTRO_VERSION="${VERSION_ID:-unknown}"
    DISTRO_CODENAME="${VERSION_CODENAME:-$UBUNTU_CODENAME}"

    # Determinar familia y servidor de mirror según la distribución
    case "$DISTRO_ID" in
        debian)
            DISTRO_FAMILY="debian"
            DISTRO_MIRROR="deb.debian.org"
            ;;
        ubuntu)
            DISTRO_FAMILY="ubuntu"
            DISTRO_MIRROR="archive.ubuntu.com"
            ;;
        linuxmint)
            DISTRO_FAMILY="mint"
            DISTRO_MIRROR="packages.linuxmint.com"
            # Linux Mint está basado en Ubuntu
            [ -z "$DISTRO_CODENAME" ] && DISTRO_CODENAME="${UBUNTU_CODENAME:-unknown}"
            ;;
        pop)
            DISTRO_FAMILY="ubuntu"
            DISTRO_MIRROR="apt.pop-os.org"
            ;;
        elementary)
            DISTRO_FAMILY="ubuntu"
            DISTRO_MIRROR="packages.elementary.io"
            ;;
        zorin)
            DISTRO_FAMILY="ubuntu"
            DISTRO_MIRROR="packages.zorinos.com"
            ;;
        kali)
            DISTRO_FAMILY="debian"
            DISTRO_MIRROR="http.kali.org"
            ;;
        *)
            # Verificar si es derivada de Debian/Ubuntu
            if [ -n "$ID_LIKE" ]; then
                if echo "$ID_LIKE" | grep -q "ubuntu"; then
                    DISTRO_FAMILY="ubuntu"
                    DISTRO_MIRROR="archive.ubuntu.com"
                elif echo "$ID_LIKE" | grep -q "debian"; then
                    DISTRO_FAMILY="debian"
                    DISTRO_MIRROR="deb.debian.org"
                else
                    die "Distribución no soportada: $DISTRO_NAME. Este script solo soporta distribuciones basadas en Debian/Ubuntu."
                fi
            else
                die "Distribución no soportada: $DISTRO_NAME. Este script solo soporta distribuciones basadas en Debian/Ubuntu."
            fi
            ;;
    esac

    log "INFO" "Distribución detectada: $DISTRO_NAME ($DISTRO_ID)"
    log "INFO" "Familia: $DISTRO_FAMILY | Versión: $DISTRO_VERSION | Codename: $DISTRO_CODENAME"
    log "INFO" "Mirror de verificación: $DISTRO_MIRROR"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo ""
        echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║  ❌ ERROR: Este script requiere permisos de root              ║${NC}"
        echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${YELLOW}Uso correcto:${NC}"
        echo -e "    ${GREEN}sudo ./autoclean.sh${NC}"
        echo ""
        echo -e "  ${CYAN}Opciones disponibles:${NC}"
        echo -e "    ${GREEN}sudo ./autoclean.sh --help${NC}      Ver ayuda completa"
        echo -e "    ${GREEN}sudo ./autoclean.sh --dry-run${NC}   Simular sin cambios"
        echo -e "    ${GREEN}sudo ./autoclean.sh -y${NC}          Modo desatendido"
        echo ""
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

# ============================================================================
# MENÚ INTERACTIVO DE CONFIGURACIÓN
# ============================================================================

show_interactive_menu() {
    local current_index=0
    local total_items=${#MENU_STEP_NAMES[@]}
    local menu_running=true

    # Ocultar cursor
    tput civis 2>/dev/null

    # Restaurar cursor al salir
    trap 'tput cnorm 2>/dev/null' RETURN

    while [ "$menu_running" = true ]; do
        # Limpiar pantalla y mostrar header
        clear
        echo -e "${MAGENTA}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${MAGENTA}${BOLD}║           CONFIGURACIÓN DE PASOS - MENÚ INTERACTIVO           ║${NC}"
        echo -e "${MAGENTA}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${CYAN}🐧 Distribución:${NC} ${BOLD}${DISTRO_NAME}${NC}"
        echo -e "  ${CYAN}📦 Familia:${NC}      ${DISTRO_FAMILY^} (${DISTRO_CODENAME:-N/A})"
        echo ""
        echo -e "  ${YELLOW}Usa ↑/↓ para navegar, ESPACIO para activar/desactivar, ENTER para ejecutar${NC}"
        echo ""

        # Mostrar opciones del menú
        for i in "${!MENU_STEP_NAMES[@]}"; do
            local var_name="${MENU_STEP_VARS[$i]}"
            local var_value="${!var_name}"
            local checkbox="[ ]"
            local line_color=""
            local line_end=""

            # Determinar estado del checkbox
            if [ "$var_value" = "1" ]; then
                checkbox="${GREEN}[✓]${NC}"
            else
                checkbox="${YELLOW}[ ]${NC}"
            fi

            # Resaltar línea actual
            if [ $i -eq $current_index ]; then
                line_color="${BOLD}${CYAN}"
                line_end="${NC}"
                echo -e "  ${BLUE}>${NC} ${checkbox} ${line_color}${MENU_STEP_NAMES[$i]}${line_end}"
            else
                echo -e "    ${checkbox} ${MENU_STEP_NAMES[$i]}"
            fi
        done

        # Contar pasos activos
        local active_count=0
        for var_name in "${MENU_STEP_VARS[@]}"; do
            [ "${!var_name}" = "1" ] && ((active_count++))
        done

        # Mostrar descripción del paso actual
        echo ""
        echo -e "  ─────────────────────────────────────────────────────────────"
        echo -e "  ${CYAN}💡 ${MENU_STEP_DESCRIPTIONS[$current_index]}${NC}"
        echo -e "  ─────────────────────────────────────────────────────────────"
        echo ""
        echo -e "  ${GREEN}${ICON_ROCKET} Pasos seleccionados: ${BOLD}${active_count}${NC}${GREEN} de ${total_items}${NC}"

        # Mostrar estado de configuración guardada
        if config_exists; then
            echo -e "  ${MAGENTA}💾 Configuración guardada: ${BOLD}Sí${NC} ${MAGENTA}(${CONFIG_FILE})${NC}"
        else
            echo -e "  ${YELLOW}💾 Configuración guardada: No${NC}"
        fi
        echo ""
        echo -e "  ${BLUE}[ENTER]${NC} Ejecutar  ${BLUE}[A]${NC} Todos  ${BLUE}[N]${NC} Ninguno  ${BLUE}[G]${NC} Guardar  ${BLUE}[D]${NC} Borrar config  ${BLUE}[Q]${NC} Salir"

        # Leer tecla
        local key=""
        IFS= read -rsn1 key

        # Detectar secuencias de escape (flechas)
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            case "$key" in
                '[A') # Flecha arriba
                    ((current_index--))
                    [ $current_index -lt 0 ] && current_index=$((total_items - 1))
                    ;;
                '[B') # Flecha abajo
                    ((current_index++))
                    [ $current_index -ge $total_items ] && current_index=0
                    ;;
            esac
        # Espacio - toggle opción actual (comparación explícita)
        elif [[ "$key" == " " ]]; then
            local var_name="${MENU_STEP_VARS[$current_index]}"
            if [ "${!var_name}" = "1" ]; then
                eval "$var_name=0"
            else
                eval "$var_name=1"
            fi
        # Enter - ejecutar (string vacío después de read)
        elif [[ "$key" == "" ]]; then
            menu_running=false
        # Otras teclas
        else
            case "$key" in
                'a'|'A') # Activar todos
                    for var_name in "${MENU_STEP_VARS[@]}"; do
                        eval "$var_name=1"
                    done
                    ;;
                'n'|'N') # Desactivar todos
                    for var_name in "${MENU_STEP_VARS[@]}"; do
                        eval "$var_name=0"
                    done
                    ;;
                'g'|'G') # Guardar configuración
                    if save_config; then
                        # Mostrar mensaje temporal
                        tput cup $(($(tput lines)-2)) 0
                        echo -e "  ${GREEN}${BOLD}✓ Configuración guardada en ${CONFIG_FILE}${NC}          "
                        sleep 1
                    fi
                    ;;
                'd'|'D') # Borrar configuración guardada
                    if config_exists; then
                        delete_config
                        tput cup $(($(tput lines)-2)) 0
                        echo -e "  ${YELLOW}✓ Configuración eliminada${NC}                              "
                        sleep 1
                    fi
                    ;;
                'q'|'Q') # Salir
                    tput cnorm 2>/dev/null
                    die "Cancelado por el usuario"
                    ;;
            esac
        fi
    done

    # Restaurar cursor
    tput cnorm 2>/dev/null

    # Recontar pasos activos después de la selección
    count_active_steps

    # Mostrar confirmación
    clear
    echo -e "${GREEN}${BOLD}✓ Configuración guardada${NC}"
    echo -e "  Se ejecutarán ${BOLD}$TOTAL_STEPS${NC} pasos."
    echo ""
    sleep 1
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
    [ "$STEP_CHECK_CONNECTIVITY" = 0 ] && { update_step_status 0 "skipped"; return; }

    print_step_enterprise 0 "Verificando conectividad..."
    update_step_status 0 "running"

    # Usar el mirror correspondiente a la distribución detectada
    local mirror_to_check="${DISTRO_MIRROR:-deb.debian.org}"

    echo "→ Verificando conexión a $mirror_to_check..."

    if ping -c 1 -W 3 "$mirror_to_check" >/dev/null 2>&1; then
        echo -e "  ${BRIGHT_GREEN}✓${NC} Conexión a internet: OK"
        STAT_CONNECTIVITY="$ICON_OK"
        log "SUCCESS" "Conectividad verificada con $mirror_to_check"
        update_step_status 0 "success"
    else
        # Intentar con un servidor de respaldo genérico
        if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
            echo -e "  ${BRIGHT_YELLOW}⚠${NC} Mirror específico no alcanzable, pero hay conexión a internet"
            STAT_CONNECTIVITY="$ICON_WARN"
            log "WARN" "Mirror $mirror_to_check no alcanzable, pero hay conectividad general"
            update_step_status 0 "warning"
        else
            STAT_CONNECTIVITY="$ICON_FAIL"
            update_step_status 0 "error"
            die "Sin conexión a internet. Verifica tu red."
        fi
    fi
}

# ============================================================================
# PASO 2: VERIFICAR E INSTALAR DEPENDENCIAS
# ============================================================================

step_check_dependencies() {
    [ "$STEP_CHECK_DEPENDENCIES" = 0 ] && { update_step_status 1 "skipped"; return; }

    print_step_enterprise 1 "Verificando herramientas recomendadas..."
    update_step_status 1 "running"

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
                    update_step_status 1 "success"
                else
                    log "WARN" "Error al instalar algunas herramientas"
                    STAT_DEPENDENCIES="${YELLOW}$ICON_WARN Parcial${NC}"
                    update_step_status 1 "warning"
                fi
            else
                log "WARN" "Usuario decidió continuar sin instalar herramientas"
                STAT_DEPENDENCIES="${YELLOW}$ICON_WARN Incompleto${NC}"
                update_step_status 1 "warning"
            fi
        else
            log "WARN" "Herramientas faltantes en modo desatendido/dry-run"
            STAT_DEPENDENCIES="${YELLOW}$ICON_WARN Incompleto${NC}"
            update_step_status 1 "warning"
        fi
    else
        echo -e "  ${BRIGHT_GREEN}✓${NC} Todas las herramientas necesarias están instaladas"
        STAT_DEPENDENCIES="$ICON_OK"
        log "SUCCESS" "Todas las herramientas necesarias disponibles"
        update_step_status 1 "success"
    fi
}

# ============================================================================
# PASO 3: BACKUP DE CONFIGURACIONES (TAR)
# ============================================================================

step_backup_tar() {
    [ "$STEP_BACKUP_TAR" = 0 ] && { update_step_status 2 "skipped"; return; }

    print_step_enterprise 2 "Creando backup de configuraciones (Tar)..."
    update_step_status 2 "running"

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

        echo -e "  ${BRIGHT_GREEN}✓${NC} Backup creado: $backup_file"
        STAT_BACKUP_TAR="$ICON_OK"
        log "SUCCESS" "Backup Tar creado"
        update_step_status 2 "success"

        # Limpiar backups antiguos (mantener últimos 5)
        ls -t "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | tail -n +6 | xargs -r rm -f
    else
        STAT_BACKUP_TAR="$ICON_FAIL"
        log "ERROR" "Error creando backup Tar"
        update_step_status 2 "error"
    fi
}

# ============================================================================
# PASO 4: SNAPSHOT TIMESHIFT
# ============================================================================

# Verificar si Timeshift está configurado correctamente
check_timeshift_configured() {
    local config_file="/etc/timeshift/timeshift.json"

    # Verificar que existe el archivo de configuración
    if [ ! -f "$config_file" ]; then
        return 1
    fi

    # Verificar que tiene un dispositivo configurado (no vacío)
    if grep -q '"backup_device_uuid" *: *""' "$config_file" 2>/dev/null; then
        return 1
    fi

    # Verificar que el dispositivo no sea "none" o similar
    if grep -q '"backup_device_uuid" *: *"none"' "$config_file" 2>/dev/null; then
        return 1
    fi

    return 0
}

step_snapshot_timeshift() {
    [ "$STEP_SNAPSHOT_TIMESHIFT" = 0 ] && { update_step_status 3 "skipped"; return; }

    print_step_enterprise 3 "Creando Snapshot de Sistema (Timeshift)..."
    update_step_status 3 "running"

    if ! command -v timeshift &>/dev/null; then
        echo -e "  ${BRIGHT_YELLOW}⚠${NC} Timeshift no está instalado"
        STAT_SNAPSHOT="${YELLOW}$ICON_SKIP No disponible${NC}"
        log "WARN" "Timeshift no disponible"
        update_step_status 3 "warning"
        return
    fi

    # Verificar si Timeshift está CONFIGURADO
    if ! check_timeshift_configured; then
        echo ""
        echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║  ⚠️  TIMESHIFT NO ESTÁ CONFIGURADO                            ║${NC}"
        echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  Timeshift está instalado pero necesita configuración inicial."
        echo ""
        echo -e "  ${CYAN}Para configurarlo, ejecuta:${NC}"
        echo -e "    ${GREEN}sudo timeshift-gtk${NC}  (interfaz gráfica)"
        echo -e "    ${GREEN}sudo timeshift --wizard${NC}  (terminal)"
        echo ""
        echo -e "  ${CYAN}Debes configurar:${NC}"
        echo -e "    • Tipo de snapshot (RSYNC recomendado para ext4/xfs)"
        echo -e "    • Dispositivo/partición donde guardar los backups"
        echo ""
        log "WARN" "Timeshift instalado pero no configurado - saltando paso"
        STAT_SNAPSHOT="${YELLOW}$ICON_WARN No configurado${NC}"
        update_step_status 3 "warning"

        if [ "$UNATTENDED" = false ]; then
            echo -e "${YELLOW}Presiona cualquier tecla para continuar sin snapshot...${NC}"
            read -n 1 -s -r
            echo ""
        fi

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
            update_step_status 3 "skipped"
            return
        fi
    fi

    if [ "$DRY_RUN" = true ]; then
        STAT_SNAPSHOT="${YELLOW}Simulado${NC}"
        update_step_status 3 "skipped"
        return
    fi

    # Crear snapshot
    local ts_comment="Pre-Maintenance $(date +%Y-%m-%d_%H:%M:%S)"
    if timeshift --create --comments "$ts_comment" --tags O >> "$LOG_FILE" 2>&1; then
        echo -e "  ${BRIGHT_GREEN}✓${NC} Snapshot Timeshift creado exitosamente"
        STAT_SNAPSHOT="${GREEN}$ICON_OK Creado${NC}"
        log "SUCCESS" "Snapshot Timeshift creado"
        update_step_status 3 "success"
    else
        echo -e "  ${BRIGHT_RED}✗${NC} Error al crear snapshot de Timeshift"
        STAT_SNAPSHOT="${RED}$ICON_FAIL Error${NC}"
        log "ERROR" "Fallo al crear snapshot de Timeshift"
        update_step_status 3 "error"

        if [ "$UNATTENDED" = false ]; then
            echo -e "${YELLOW}¿Deseas continuar SIN snapshot? Esto es RIESGOSO.${NC}"
            read -p "Escribe 'SI' (mayúsculas) para continuar sin backup: " -r CONFIRM
            if [ "$CONFIRM" != "SI" ]; then
                die "Abortado por el usuario - sin snapshot de seguridad"
            fi
            log "WARN" "Usuario decidió continuar sin snapshot"
        else
            # En modo desatendido, abortar por seguridad
            die "No se pudo crear el snapshot de Timeshift. Abortando por seguridad."
        fi
    fi
}

# ============================================================================
# PASO 5: ACTUALIZAR REPOSITORIOS
# ============================================================================

step_update_repos() {
    [ "$STEP_UPDATE_REPOS" = 0 ] && { update_step_status 4 "skipped"; return; }

    print_step_enterprise 4 "Actualizando lista de repositorios..."
    update_step_status 4 "running"

    # Reparar dpkg antes de actualizar
    dpkg --configure -a >> "$LOG_FILE" 2>&1

    if safe_run "apt update" "Error al actualizar repositorios"; then
        echo -e "  ${BRIGHT_GREEN}✓${NC} Repositorios actualizados"
        STAT_REPO="$ICON_OK"
        update_step_status 4 "success"
    else
        STAT_REPO="$ICON_FAIL"
        update_step_status 4 "error"
        die "Error crítico al actualizar repositorios"
    fi
}

# ============================================================================
# PASO 6: ACTUALIZAR SISTEMA (APT)
# ============================================================================

step_upgrade_system() {
    [ "$STEP_UPGRADE_SYSTEM" = 0 ] && { update_step_status 5 "skipped"; return; }

    print_step_enterprise 5 "Analizando y aplicando actualizaciones del sistema..."
    update_step_status 5 "running"

    # Contar actualizaciones disponibles
    local updates_output=$(apt list --upgradable 2>/dev/null)
    local updates=$(echo "$updates_output" | grep -c '\[upgradable' || echo 0)
    updates=${updates//[^0-9]/}
    updates=${updates:-0}
    updates=$((updates + 0))

    if [ "$updates" -gt 0 ]; then
        echo -e "  ${BRIGHT_CYAN}📦${NC} $updates paquetes para actualizar"

        # Análisis heurístico de riesgo (borrados masivos)
        log "INFO" "Simulando actualización para detectar borrados..."
        local simulation=$(apt full-upgrade -s 2>/dev/null)
        local remove_count=$(echo "$simulation" | grep "^Remv" | wc -l)

        if [ "$remove_count" -gt "$MAX_REMOVALS_ALLOWED" ]; then
            echo -e "\n${RED}${BOLD}⚠️  ALERTA DE SEGURIDAD: APT propone eliminar $remove_count paquetes${NC}"
            echo "$simulation" | grep "^Remv" | head -n 5 | sed 's/^Remv/ - Eliminando:/'

            if [ "$UNATTENDED" = true ]; then
                update_step_status 5 "error"
                die "Abortado automáticamente por riesgo de eliminación masiva en modo desatendido."
            fi

            echo -e "\n${YELLOW}¿Tienes un snapshot válido? ¿Quieres proceder?${NC}"
            read -p "Escribe 'SI' (mayúsculas) para continuar: " -r CONFIRM
            if [ "$CONFIRM" != "SI" ]; then
                update_step_status 5 "error"
                die "Cancelado por el usuario."
            fi
        fi

        # Ejecutar actualización
        if safe_run "apt full-upgrade -y" "Error aplicando actualizaciones"; then
            echo -e "  ${BRIGHT_GREEN}✓${NC} $updates paquetes actualizados exitosamente"
            STAT_UPGRADE="$ICON_OK ($updates instalados)"
            log "SUCCESS" "$updates paquetes actualizados"
            update_step_status 5 "success"
        else
            STAT_UPGRADE="$ICON_FAIL"
            log "ERROR" "Error actualizando paquetes"
            update_step_status 5 "error"
        fi
    else
        echo -e "  ${BRIGHT_GREEN}✓${NC} Sistema ya actualizado"
        STAT_UPGRADE="$ICON_OK (sin cambios)"
        log "INFO" "No hay actualizaciones disponibles"
        update_step_status 5 "success"
    fi
}

# ============================================================================
# PASO 7: ACTUALIZAR FLATPAK
# ============================================================================

step_update_flatpak() {
    [ "$STEP_UPDATE_FLATPAK" = 0 ] && { update_step_status 6 "skipped"; return; }

    print_step_enterprise 6 "Actualizando aplicaciones Flatpak..."
    update_step_status 6 "running"

    if ! command -v flatpak &>/dev/null; then
        echo -e "  ${BRIGHT_YELLOW}⚠${NC} Flatpak no está instalado"
        STAT_FLATPAK="$ICON_SKIP (no instalado)"
        update_step_status 6 "skipped"
        return
    fi

    if safe_run "flatpak update -y" "Error actualizando Flatpak"; then
        # Limpiar referencias huérfanas
        safe_run "flatpak uninstall --unused -y" "Error limpiando Flatpak huérfanos"

        # Reparar instalación
        safe_run "flatpak repair" "Error reparando Flatpak"

        echo -e "  ${BRIGHT_GREEN}✓${NC} Flatpak actualizado y limpiado"
        STAT_FLATPAK="$ICON_OK"
        log "SUCCESS" "Flatpak actualizado"
        update_step_status 6 "success"
    else
        STAT_FLATPAK="$ICON_FAIL"
        update_step_status 6 "error"
    fi
}

# ============================================================================
# PASO 8: ACTUALIZAR SNAP
# ============================================================================

step_update_snap() {
    [ "$STEP_UPDATE_SNAP" = 0 ] && { update_step_status 7 "skipped"; return; }

    print_step_enterprise 7 "Actualizando aplicaciones Snap..."
    update_step_status 7 "running"

    if ! command -v snap &>/dev/null; then
        echo -e "  ${BRIGHT_YELLOW}⚠${NC} Snap no está instalado"
        STAT_SNAP="$ICON_SKIP (no instalado)"
        update_step_status 7 "skipped"
        return
    fi

    if safe_run "snap refresh" "Error actualizando Snap"; then
        echo -e "  ${BRIGHT_GREEN}✓${NC} Snap actualizado"
        STAT_SNAP="$ICON_OK"
        log "SUCCESS" "Snap actualizado"
        update_step_status 7 "success"
    else
        STAT_SNAP="$ICON_FAIL"
        update_step_status 7 "error"
    fi
}

# ============================================================================
# PASO 9: VERIFICAR FIRMWARE
# ============================================================================

step_check_firmware() {
    [ "$STEP_CHECK_FIRMWARE" = 0 ] && { update_step_status 8 "skipped"; return; }

    print_step_enterprise 8 "Verificando actualizaciones de firmware..."
    update_step_status 8 "running"

    if ! command -v fwupdmgr &>/dev/null; then
        echo -e "  ${BRIGHT_YELLOW}⚠${NC} fwupd no está instalado"
        STAT_FIRMWARE="$ICON_SKIP (no instalado)"
        update_step_status 8 "skipped"
        return
    fi

    # Verificar si necesita refresh (más de 7 días)
    local last_refresh=$(stat -c %Y /var/lib/fwupd/metadata.xml 2>/dev/null || echo 0)
    local current_time=$(date +%s)
    local days_old=$(( (current_time - last_refresh) / 86400 ))

    if [ "$days_old" -gt 7 ]; then
        safe_run "fwupdmgr refresh --force" "Error actualizando metadata de firmware"
        echo -e "  ${BRIGHT_CYAN}↻${NC} Metadata de firmware actualizada"
    else
        echo -e "  ${DIM}→ Metadata actualizada hace $days_old días${NC}"
    fi

    # Verificar si hay actualizaciones disponibles
    if fwupdmgr get-updates >/dev/null 2>&1; then
        echo -e "  ${BRIGHT_YELLOW}⚠${NC} ¡Hay actualizaciones de Firmware disponibles!"
        STAT_FIRMWARE="${YELLOW}$ICON_WARN DISPONIBLE${NC}"
        log "WARN" "Actualizaciones de firmware disponibles"
        update_step_status 8 "warning"
    else
        echo -e "  ${BRIGHT_GREEN}✓${NC} Firmware actualizado"
        STAT_FIRMWARE="$ICON_OK"
        update_step_status 8 "success"
    fi
}

# ============================================================================
# PASO 10: LIMPIEZA APT
# ============================================================================

step_cleanup_apt() {
    [ "$STEP_CLEANUP_APT" = 0 ] && { update_step_status 9 "skipped"; return; }

    print_step_enterprise 9 "Limpieza de paquetes huérfanos y residuales..."
    update_step_status 9 "running"

    # Autoremove (paquetes huérfanos)
    if safe_run "apt autoremove -y" "Error en autoremove"; then
        echo -e "  ${BRIGHT_GREEN}✓${NC} Paquetes huérfanos eliminados"
    else
        STAT_CLEAN_APT="$ICON_FAIL"
        update_step_status 9 "error"
        return
    fi

    # Purge (paquetes con config residual)
    local pkgs_rc=$(dpkg -l 2>/dev/null | grep "^rc" | awk '{print $2}')
    if [ -n "$pkgs_rc" ]; then
        local rc_count=$(echo "$pkgs_rc" | wc -l)
        if echo "$pkgs_rc" | xargs apt purge -y >/dev/null 2>&1; then
            echo -e "  ${BRIGHT_GREEN}✓${NC} $rc_count archivos residuales purgados"
            log "INFO" "$rc_count paquetes residuales purgados"
        else
            STAT_CLEAN_APT="$ICON_FAIL"
            log "ERROR" "Error purgando residuales"
            update_step_status 9 "error"
            return
        fi
    else
        echo -e "  ${DIM}→ No hay archivos residuales${NC}"
    fi

    # Autoclean o clean
    if safe_run "apt $APT_CLEAN_MODE" "Error limpiando caché APT"; then
        echo -e "  ${BRIGHT_GREEN}✓${NC} Caché de APT limpiado"
    fi

    STAT_CLEAN_APT="$ICON_OK"
    log "SUCCESS" "Limpieza APT completada"
    update_step_status 9 "success"
}

# ============================================================================
# PASO 11: LIMPIEZA DE KERNELS ANTIGUOS
# ============================================================================

step_cleanup_kernels() {
    [ "$STEP_CLEANUP_KERNELS" = 0 ] && { update_step_status 10 "skipped"; return; }

    print_step_enterprise 10 "Limpieza segura de Kernels antiguos..."
    update_step_status 10 "running"

    # Obtener kernel actual
    local current_kernel=$(uname -r)
    local current_kernel_pkg="linux-image-${current_kernel}"

    log "INFO" "Kernel actual: $current_kernel"
    echo -e "  ${BRIGHT_CYAN}🐧${NC} Kernel en uso: $current_kernel"
    
    # Obtener todos los kernels instalados
    local installed_kernels=$(dpkg -l 2>/dev/null | awk '/^ii.*linux-image-[0-9]/ {print $2}' | grep -v "meta")
    
    if [ -z "$installed_kernels" ]; then
        echo -e "  ${DIM}→ No se encontraron kernels para gestionar${NC}"
        STAT_CLEAN_KERNEL="$ICON_OK (Ninguno encontrado)"
        update_step_status 10 "success"
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
                echo -e "  ${BRIGHT_YELLOW}⚠${NC} Limpieza de kernels cancelada"
                update_step_status 10 "skipped"
                return
            fi
        fi

        # Eliminar kernels
        if echo "$kernels_to_remove" | xargs apt purge -y >> "$LOG_FILE" 2>&1; then
            echo -e "  ${BRIGHT_GREEN}✓${NC} Kernels antiguos eliminados"
            STAT_CLEAN_KERNEL="$ICON_OK"
            log "SUCCESS" "Kernels antiguos eliminados"

            # Regenerar GRUB
            if command -v update-grub &>/dev/null; then
                safe_run "update-grub" "Error actualizando GRUB"
                echo -e "  ${BRIGHT_GREEN}✓${NC} GRUB actualizado"
            fi
            update_step_status 10 "success"
        else
            STAT_CLEAN_KERNEL="$ICON_FAIL"
            log "ERROR" "Error eliminando kernels"
            update_step_status 10 "error"
        fi
    else
        echo -e "  ${BRIGHT_GREEN}✓${NC} No hay kernels antiguos para limpiar"
        STAT_CLEAN_KERNEL="$ICON_OK (Nada que limpiar)"
        update_step_status 10 "success"
    fi
}

# ============================================================================
# PASO 12: LIMPIEZA DE DISCO (LOGS Y CACHÉ)
# ============================================================================

step_cleanup_disk() {
    [ "$STEP_CLEANUP_DISK" = 0 ] && { update_step_status 11 "skipped"; return; }

    print_step_enterprise 11 "Limpieza de logs y caché del sistema..."
    update_step_status 11 "running"

    # Journalctl
    if command -v journalctl &>/dev/null; then
        if safe_run "journalctl --vacuum-time=${DIAS_LOGS}d --vacuum-size=500M" "Error limpiando journalctl"; then
            echo -e "  ${BRIGHT_GREEN}✓${NC} Logs de journalctl reducidos"
        fi
    fi

    # Archivos temporales antiguos
    find /var/tmp -type f -atime +30 -delete 2>/dev/null && \
        echo -e "  ${BRIGHT_GREEN}✓${NC} Archivos temporales antiguos eliminados" || true

    # Thumbnails
    local cleaned_homes=0
    for user_home in /home/* /root; do
        if [ -d "$user_home/.cache/thumbnails" ]; then
            rm -rf "$user_home/.cache/thumbnails/"* 2>/dev/null && ((cleaned_homes++))
        fi
    done
    [ "$cleaned_homes" -gt 0 ] && echo -e "  ${BRIGHT_GREEN}✓${NC} Caché de miniaturas limpiado ($cleaned_homes usuarios)"

    STAT_CLEAN_DISK="$ICON_OK"
    log "SUCCESS" "Limpieza de disco completada"
    update_step_status 11 "success"
}

# ============================================================================
# PASO 13: VERIFICAR NECESIDAD DE REINICIO
# ============================================================================

step_check_reboot() {
    [ "$STEP_CHECK_REBOOT" = 0 ] && { update_step_status 12 "skipped"; return; }

    print_step_enterprise 12 "Verificando necesidad de reinicio..."
    update_step_status 12 "running"

    # Verificar archivo de reinicio requerido
    if [ -f /var/run/reboot-required ]; then
        REBOOT_NEEDED=true
        log "WARN" "Archivo /var/run/reboot-required presente"
        echo -e "  ${BRIGHT_YELLOW}⚠${NC} Detectado archivo /var/run/reboot-required"
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
        update_step_status 12 "warning"
    else
        STAT_REBOOT="${GREEN}$ICON_OK No necesario${NC}"
        log "INFO" "No se requiere reinicio"
        update_step_status 12 "success"
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
        --no-menu)
            NO_MENU=true
            shift
            ;;
        --help)
            cat << 'EOF'
Mantenimiento Integral para Distribuciones basadas en Debian/Ubuntu

Distribuciones soportadas:
  • Debian (Stable, Testing, Unstable)
  • Ubuntu (todas las versiones)
  • Linux Mint
  • Pop!_OS, Elementary OS, Zorin OS, Kali Linux
  • Cualquier derivada de Debian/Ubuntu

Uso: sudo ./autoclean.sh [opciones]

Opciones:
  --dry-run          Simular ejecución sin hacer cambios reales
  -y, --unattended   Modo desatendido sin confirmaciones
  --no-backup        No crear backup de configuraciones
  --no-menu          Omitir menú interactivo (usar config por defecto)
  --quiet            Modo silencioso (solo logs)
  --help             Mostrar esta ayuda

Ejemplos:
  sudo ./autoclean.sh                    # Ejecución normal
  sudo ./autoclean.sh --dry-run          # Simular cambios
  sudo ./autoclean.sh -y                 # Modo desatendido

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

# Verificar permisos de root ANTES de cualquier operación
check_root

# Inicialización
init_log
log "INFO" "=========================================="
log "INFO" "Iniciando Mantenimiento v${SCRIPT_VERSION}"
log "INFO" "=========================================="

# Chequeos previos obligatorios
check_lock

# Detectar distribución (debe ejecutarse antes de print_header)
detect_distro

# Cargar configuración guardada si existe
if config_exists; then
    load_config
    log "INFO" "Configuración cargada desde $CONFIG_FILE"
fi

# Contar pasos iniciales
count_active_steps

# Mostrar configuración según modo de ejecución
if [ "$UNATTENDED" = false ] && [ "$QUIET" = false ] && [ "$NO_MENU" = false ]; then
    # Modo interactivo: mostrar menú de configuración
    show_interactive_menu
else
    # Modo no interactivo: mostrar resumen y confirmar
    print_header
    show_step_summary
fi

# Validar dependencias después de la configuración
validate_step_dependencies

# Mostrar header antes de ejecutar (si usamos menú interactivo ya se limpió)
[ "$QUIET" = false ] && print_header

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

# Mostrar resumen final (Enterprise Edition)
show_final_summary_enterprise

exit 0
