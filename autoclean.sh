#!/bin/bash
# ============================================================================
# Script de Mantenimiento Integral para Distribuciones basadas en Debian
# ============================================================================
# Versión: 2025.11
# Última revisión: Diciembre 2025
# Autor: Homero Thompson del Lago del Terror
# Contribuciones UI/UX: Dreadblitz (github.com/Dreadblitz)
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
SCRIPT_VERSION="2025.12"

# Configuración de idioma
LANG_DIR="${SCRIPT_DIR}/lang"
DEFAULT_LANG="en"
CURRENT_LANG=""
AVAILABLE_LANGS=("en" "es" "pt" "fr" "de" "it")

# Configuración de tema
THEME_DIR="${SCRIPT_DIR}/themes"
DEFAULT_THEME="default"
CURRENT_THEME=""
AVAILABLE_THEMES=("default" "norton" "turbo" "green" "amber")

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
STAT_CONNECTIVITY="[..]"
STAT_DEPENDENCIES="[..]"
STAT_BACKUP_TAR="[..]"
STAT_SNAPSHOT="[..]"
STAT_REPO="[..]"
STAT_UPGRADE="[..]"
STAT_FLATPAK="[..]"
STAT_SNAP="[..]"
STAT_FIRMWARE="[..]"
STAT_CLEAN_APT="[..]"
STAT_CLEAN_KERNEL="[..]"
STAT_CLEAN_DISK="[..]"
STAT_REBOOT="[..]"

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
UPGRADE_PERFORMED=false

# ============================================================================
# CONFIGURACIÓN DEL MENÚ INTERACTIVO
# ============================================================================

# Arrays para el menú interactivo (se llenan desde archivo de idioma)
declare -a MENU_STEP_NAMES
declare -a MENU_STEP_DESCRIPTIONS
declare -a STEP_SHORT_NAMES

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

# Función para actualizar arrays desde variables de idioma
update_language_arrays() {
    MENU_STEP_NAMES=(
        "$STEP_NAME_1"
        "$STEP_NAME_2"
        "$STEP_NAME_3"
        "$STEP_NAME_4"
        "$STEP_NAME_5"
        "$STEP_NAME_6"
        "$STEP_NAME_7"
        "$STEP_NAME_8"
        "$STEP_NAME_9"
        "$STEP_NAME_10"
        "$STEP_NAME_11"
        "$STEP_NAME_12"
        "$STEP_NAME_13"
    )

    MENU_STEP_DESCRIPTIONS=(
        "$STEP_DESC_1"
        "$STEP_DESC_2"
        "$STEP_DESC_3"
        "$STEP_DESC_4"
        "$STEP_DESC_5"
        "$STEP_DESC_6"
        "$STEP_DESC_7"
        "$STEP_DESC_8"
        "$STEP_DESC_9"
        "$STEP_DESC_10"
        "$STEP_DESC_11"
        "$STEP_DESC_12"
        "$STEP_DESC_13"
    )

    STEP_SHORT_NAMES=(
        "$STEP_SHORT_1"
        "$STEP_SHORT_2"
        "$STEP_SHORT_3"
        "$STEP_SHORT_4"
        "$STEP_SHORT_5"
        "$STEP_SHORT_6"
        "$STEP_SHORT_7"
        "$STEP_SHORT_8"
        "$STEP_SHORT_9"
        "$STEP_SHORT_10"
        "$STEP_SHORT_11"
        "$STEP_SHORT_12"
        "$STEP_SHORT_13"
    )
}

# ============================================================================
# FUNCIONES DE CONFIGURACIÓN PERSISTENTE
# ============================================================================

save_config() {
    # Guardar estado actual de los pasos y preferencias en archivo de configuración
    cat > "$CONFIG_FILE" << EOF
# Configuración de autoclean - Generado automáticamente
# Fecha: $(date '+%Y-%m-%d %H:%M:%S')
# No editar manualmente (usar el menú interactivo)

# Idioma / Language
SAVED_LANG=$CURRENT_LANG

# Tema / Theme
SAVED_THEME=$CURRENT_THEME

# Pasos / Steps
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
# FUNCIONES DE IDIOMA (i18n)
# ============================================================================

load_language() {
    local lang_to_load="$1"

    # Si no se especifica idioma, detectar automáticamente
    if [ -z "$lang_to_load" ]; then
        # Prioridad: 1) Config guardada, 2) Variable de entorno, 3) Sistema, 4) Default
        if [ -n "$SAVED_LANG" ]; then
            lang_to_load="$SAVED_LANG"
        elif [ -n "$AUTOCLEAN_LANG" ]; then
            lang_to_load="$AUTOCLEAN_LANG"
        else
            # Detectar idioma del sistema
            local sys_lang="${LANG%%_*}"
            sys_lang="${sys_lang%%.*}"
            lang_to_load="${sys_lang:-$DEFAULT_LANG}"
        fi
    fi

    # Verificar que el idioma existe
    local lang_file="${LANG_DIR}/${lang_to_load}.lang"
    if [ ! -f "$lang_file" ]; then
        # Fallback a idioma por defecto
        lang_file="${LANG_DIR}/${DEFAULT_LANG}.lang"
        lang_to_load="$DEFAULT_LANG"
    fi

    # Cargar archivo de idioma
    if [ -f "$lang_file" ]; then
        source "$lang_file"
        CURRENT_LANG="$lang_to_load"
        # Actualizar arrays con textos del idioma cargado
        update_language_arrays
        return 0
    else
        # Fallback crítico: usar inglés hardcodeado mínimo
        echo "ERROR: No language files found in $LANG_DIR"
        exit 1
    fi
}

show_language_selector() {
    # Nombres de idiomas para mostrar
    local -a LANG_NAMES=("English" "Español" "Português" "Français" "Deutsch" "Italiano")
    local selected=0
    local total=${#AVAILABLE_LANGS[@]}

    # Encontrar índice del idioma actual
    for i in "${!AVAILABLE_LANGS[@]}"; do
        if [[ "${AVAILABLE_LANGS[$i]}" == "$CURRENT_LANG" ]]; then
            selected=$i
            break
        fi
    done

    while true; do
        clear
        print_box_top
        print_box_center "${BOLD}SELECT LANGUAGE / SELECCIONAR IDIOMA${NC}"
        print_box_sep
        print_box_line ""

        # Mostrar idiomas con el seleccionado resaltado
        for i in "${!AVAILABLE_LANGS[@]}"; do
            if [[ $i -eq $selected ]]; then
                print_box_line "   ${TEXT_SELECTED}>${NC} ${TEXT_ACTIVE}[x]${NC} ${LANG_NAMES[$i]}"
            else
                print_box_line "     ${TEXT_INACTIVE}[ ] ${LANG_NAMES[$i]}${NC}"
            fi
        done

        print_box_line ""
        print_box_sep
        print_box_center "${STATUS_INFO}[ENTER]${NC} ${MENU_SELECT:-Select}  ${STATUS_INFO}[ESC]${NC} ${MENU_BACK:-Back}"
        print_box_bottom

        # Leer tecla
        local key=""
        read -rsn1 key

        # Detectar secuencias de escape (flechas o ESC solo)
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            case "$key" in
                '[A') # Flecha arriba
                    ((selected--))
                    [[ $selected -lt 0 ]] && selected=$((total - 1))
                    ;;
                '[B') # Flecha abajo
                    ((selected++))
                    [[ $selected -ge $total ]] && selected=0
                    ;;
                '') # ESC solo (sin secuencia de flecha)
                    return
                    ;;
            esac
        elif [[ "$key" == "" ]]; then
            # ENTER - seleccionar idioma
            load_language "${AVAILABLE_LANGS[$selected]}"
            return
        fi
    done
}

# ============================================================================
# SISTEMA DE TEMAS
# ============================================================================

load_theme() {
    local theme_to_load="$1"

    # Prioridad: 1. Parámetro, 2. Config guardada, 3. Default
    if [ -z "$theme_to_load" ]; then
        if [ -n "$SAVED_THEME" ]; then
            theme_to_load="$SAVED_THEME"
        else
            theme_to_load="$DEFAULT_THEME"
        fi
    fi

    # Verificar que el archivo existe
    local theme_file="${THEME_DIR}/${theme_to_load}.theme"
    if [ ! -f "$theme_file" ]; then
        theme_file="${THEME_DIR}/${DEFAULT_THEME}.theme"
        theme_to_load="$DEFAULT_THEME"
    fi

    # Cargar archivo de tema
    if [ -f "$theme_file" ]; then
        source "$theme_file"
        CURRENT_THEME="$theme_to_load"
        apply_theme
    fi
}

apply_theme() {
    # Mapear variables del tema a las variables globales del script
    RED="${T_RED:-\033[0;31m}"
    GREEN="${T_GREEN:-\033[0;32m}"
    YELLOW="${T_YELLOW:-\033[1;33m}"
    BLUE="${T_BLUE:-\033[0;34m}"
    CYAN="${T_CYAN:-\033[0;36m}"
    MAGENTA="${T_MAGENTA:-\033[0;35m}"
    BRIGHT_GREEN="${T_BRIGHT_GREEN:-\033[1;32m}"
    BRIGHT_YELLOW="${T_BRIGHT_YELLOW:-\033[1;33m}"
    BRIGHT_CYAN="${T_BRIGHT_CYAN:-\033[1;36m}"
    DIM="${T_DIM:-\033[2m}"

    # Variables semanticas adicionales (usadas por funciones UI)
    BOX_BORDER="${T_BOX_BORDER:-$BLUE}"
    BOX_TITLE="${T_BOX_TITLE:-$BOLD}"
    TEXT_SELECTED="${T_TEXT_SELECTED:-$BRIGHT_CYAN}"
    TEXT_ACTIVE="${T_TEXT_ACTIVE:-$GREEN}"
    TEXT_INACTIVE="${T_TEXT_INACTIVE:-$DIM}"
    STATUS_OK="${T_STATUS_OK:-$GREEN}"
    STATUS_ERROR="${T_STATUS_ERROR:-$RED}"
    STATUS_WARN="${T_STATUS_WARN:-$YELLOW}"
    STATUS_INFO="${T_STATUS_INFO:-$CYAN}"
    STEP_HEADER="${T_STEP_HEADER:-$BLUE}"
}

show_theme_selector() {
    # Nombres de temas para mostrar
    local -a THEME_NAMES=("Default" "Norton Commander" "Bloody Red" "Green Terminal" "Amber Terminal")
    local selected=0
    local total=${#AVAILABLE_THEMES[@]}

    # Encontrar indice del tema actual
    for i in "${!AVAILABLE_THEMES[@]}"; do
        if [[ "${AVAILABLE_THEMES[$i]}" == "$CURRENT_THEME" ]]; then
            selected=$i
            break
        fi
    done

    while true; do
        clear
        print_box_top
        print_box_center "${BOLD}${MENU_THEME_TITLE:-SELECT THEME / SELECCIONAR TEMA}${NC}"
        print_box_sep
        print_box_line ""

        # Mostrar temas con el seleccionado resaltado
        for i in "${!AVAILABLE_THEMES[@]}"; do
            if [[ $i -eq $selected ]]; then
                print_box_line "   ${TEXT_SELECTED}>${NC} ${TEXT_ACTIVE}[x]${NC} ${THEME_NAMES[$i]}"
            else
                print_box_line "     ${TEXT_INACTIVE}[ ] ${THEME_NAMES[$i]}${NC}"
            fi
        done

        print_box_line ""
        print_box_sep
        print_box_center "${STATUS_INFO}[ENTER]${NC} ${MENU_SELECT:-Select}  ${STATUS_INFO}[ESC]${NC} ${MENU_BACK:-Back}"
        print_box_bottom

        # Leer tecla
        local key=""
        read -rsn1 key

        # Detectar secuencias de escape (flechas o ESC solo)
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            case "$key" in
                '[A') # Flecha arriba
                    ((selected--))
                    [[ $selected -lt 0 ]] && selected=$((total - 1))
                    ;;
                '[B') # Flecha abajo
                    ((selected++))
                    [[ $selected -ge $total ]] && selected=0
                    ;;
                '') # ESC solo
                    return
                    ;;
            esac
        elif [[ "$key" == "" ]]; then
            # ENTER - seleccionar tema
            load_theme "${AVAILABLE_THEMES[$selected]}"
            return
        fi
    done
}

# ============================================================================
# COLORES E ICONOS (valores por defecto, serán sobrescritos por el tema)
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

ICON_OK="[OK]"
ICON_FAIL="[XX]"
ICON_SKIP="[--]"
ICON_WARN="[!!]"
ICON_SHIELD="[TF]"
ICON_CLOCK=""
ICON_ROCKET=""

# ============================================================================
# UI ENTERPRISE - Colores adicionales y controles
# ============================================================================

# Colores brillantes
BRIGHT_GREEN='\033[1;32m'
BRIGHT_YELLOW='\033[1;33m'
BRIGHT_CYAN='\033[1;36m'
DIM='\033[2m'

# Variables semanticas de tema (valores por defecto)
BOX_BORDER="$BLUE"
BOX_TITLE="$BOLD"
TEXT_SELECTED="$BRIGHT_CYAN"
TEXT_ACTIVE="$GREEN"
TEXT_INACTIVE="$DIM"
STATUS_OK="$GREEN"
STATUS_ERROR="$RED"
STATUS_WARN="$YELLOW"
STATUS_INFO="$CYAN"
STEP_HEADER="$BLUE"

# Colores FIJOS para metricas (NO cambian con el tema)
FIXED_GREEN='\033[0;32m'
FIXED_RED='\033[0;31m'
FIXED_YELLOW='\033[1;33m'
FIXED_CYAN='\033[0;36m'

# Control de cursor
CURSOR_HIDE='\033[?25l'
CURSOR_SHOW='\033[?25h'
CLEAR_LINE='\033[2K'

# Íconos ASCII de ancho fijo (4 chars) - garantiza alineación
ICON_SUM_OK='[OK]'
ICON_SUM_FAIL='[XX]'
ICON_SUM_WARN='[!!]'
ICON_SUM_SKIP='[--]'
ICON_SUM_RUN='[..]'
ICON_SUM_PEND='[  ]'

# Caracteres de progress bar
PROGRESS_FILLED="█"
PROGRESS_EMPTY="░"

# Spinner frames (estilo dots)
SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
SPINNER_PID=""
SPINNER_ACTIVE=false

# Constantes de diseño UI (terminal 80x24)
BOX_WIDTH=78
BOX_INNER=76

# Arrays de estado de pasos para resumen
declare -a STEP_STATUS_ARRAY
declare -a STEP_TIME_START
declare -a STEP_TIME_END

# Inicializar arrays de estado
for i in {0..12}; do
    STEP_STATUS_ARRAY[$i]="pending"
    STEP_TIME_START[$i]=0
    STEP_TIME_END[$i]=0
done

# ============================================================================
# FUNCIONES UI ENTERPRISE
# ============================================================================

# Remover códigos ANSI de un texto - múltiples métodos para robustez
strip_ansi() {
    local text="$1"
    # Usar printf %b para expandir y sed para limpiar
    # Esta combinación es más robusta que echo -e
    printf '%b' "$text" | sed 's/\x1b\[[0-9;]*m//g; s/\x1b\[[0-9;]*[A-Za-z]//g'
}

# Calcular longitud visible - método ultra-robusto
# Usa wc -L que calcula el ancho de columna real
visible_length() {
    local text="$1"
    local clean
    clean=$(strip_ansi "$text")
    # wc -L devuelve el ancho de la línea más larga (considera Unicode correctamente)
    local len
    len=$(printf '%s' "$clean" | wc -L)
    # Fallback a ${#} si wc -L falla
    [ -z "$len" ] || [ "$len" -eq 0 ] && len=${#clean}
    echo "$len"
}

# Generar N espacios
make_spaces() {
    local n="$1"
    [ "$n" -le 0 ] && echo "" && return
    printf '%*s' "$n" ''
}

# Imprimir línea con bordes - MÉTODO ULTRA-ROBUSTO
# Usa posicionamiento absoluto de cursor para garantizar alineación
print_box_line() {
    local content="$1"

    # Imprimir borde izquierdo + espacio
    printf '%b' "${BOX_BORDER:-$BLUE}║${NC} "

    # Imprimir contenido
    printf '%b' "$content"

    # Mover cursor a columna BOX_WIDTH-1 (posición fija del borde derecho)
    # y luego imprimir espacio + borde derecho
    printf '\033[%dG' "$BOX_WIDTH"
    printf '%b\n' "${BOX_BORDER:-$BLUE}║${NC}"
}

# Imprimir línea centrada - MÉTODO ULTRA-ROBUSTO
# Usa posicionamiento absoluto para borde derecho
print_box_center() {
    local content="$1"

    # Calcular longitud visible para centrado
    local content_len
    content_len=$(visible_length "$content")

    # Calcular padding izquierdo para centrar
    local total_pad=$((BOX_INNER - content_len))
    [ "$total_pad" -lt 0 ] && total_pad=0
    local left_pad=$((total_pad / 2))

    # Generar espacios izquierdos
    local left_spaces
    left_spaces=$(make_spaces "$left_pad")

    # Imprimir: borde + espacios izquierdos + contenido
    printf '%b' "${BOX_BORDER:-$BLUE}║${NC}"
    printf '%s' "$left_spaces"
    printf '%b' "$content"

    # Posicionar cursor en columna fija y imprimir borde derecho
    printf '\033[%dG' "$BOX_WIDTH"
    printf '%b\n' "${BOX_BORDER:-$BLUE}║${NC}"
}

# Imprimir separador horizontal
print_box_sep() {
    printf '%b' "${BOX_BORDER:-$BLUE}╠"
    printf '═%.0s' $(seq 1 $BOX_INNER)
    printf '%b\n' "╣${NC}"
}

# Imprimir marco superior
print_box_top() {
    local color="${1:-${BOX_BORDER:-$BLUE}}"
    printf '%b' "${color}╔"
    printf '═%.0s' $(seq 1 $BOX_INNER)
    printf '%b\n' "╗${NC}"
}

# Imprimir marco inferior
print_box_bottom() {
    local color="${1:-${BOX_BORDER:-$BLUE}}"
    printf '%b' "${color}╚"
    printf '═%.0s' $(seq 1 $BOX_INNER)
    printf '%b\n' "╝${NC}"
}

# Obtener ícono ASCII por estado
get_step_icon_summary() {
    local status=$1
    case $status in
        "success")  echo "${GREEN}${ICON_SUM_OK}${NC}" ;;
        "error")    echo "${RED}${ICON_SUM_FAIL}${NC}" ;;
        "warning")  echo "${YELLOW}${ICON_SUM_WARN}${NC}" ;;
        "skipped")  echo "${YELLOW}${ICON_SUM_SKIP}${NC}" ;;
        "running")  echo "${CYAN}${ICON_SUM_RUN}${NC}" ;;
        *)          echo "${DIM}${ICON_SUM_PEND}${NC}" ;;
    esac
}

# Actualizar estado de un paso
update_step_status() {
    local step_index=$1
    local new_status=$2
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

# Spinner - Animación durante operaciones largas
start_spinner() {
    local message="${1:-Procesando...}"
    [ "$QUIET" = true ] && return
    [ "$SPINNER_ACTIVE" = true ] && return
    SPINNER_ACTIVE=true
    printf "${CURSOR_HIDE}"
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
    local status=${1:-0}
    local message="${2:-}"
    [ "$QUIET" = true ] && return
    [ "$SPINNER_ACTIVE" = false ] && return
    if [ -n "$SPINNER_PID" ] && kill -0 "$SPINNER_PID" 2>/dev/null; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null
    fi
    SPINNER_PID=""
    SPINNER_ACTIVE=false
    printf "\r${CLEAR_LINE}"
    case $status in
        0) printf "  ${GREEN}${ICON_OK}${NC} ${message}\n" ;;
        1) printf "  ${RED}${ICON_FAIL}${NC} ${message}\n" ;;
        2) printf "  ${YELLOW}${ICON_WARN}${NC} ${message}\n" ;;
        3) printf "  ${DIM}${ICON_SKIP}${NC} ${message}\n" ;;
    esac
    printf "${CURSOR_SHOW}"
}

# ============================================================================
# FUNCIONES BASE Y UTILIDADES
# ============================================================================

init_log() {
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/sys-update-$(date +%Y%m%d_%H%M%S).log"
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"

    # Limpiar logs antiguos (mantener últimas 5 ejecuciones)
    ls -t "$LOG_DIR"/sys-update-*.log 2>/dev/null | tail -n +6 | xargs -r rm -f
}

log() {
    local level="$1"; shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
    
    [ "$QUIET" = true ] && return
    
    case "$level" in
        ERROR)   echo -e "${RED}[XX] ${message}${NC}" ;;
        WARN)    echo -e "${YELLOW}[!!] ${message}${NC}" ;;
        SUCCESS) echo -e "${GREEN}[OK] ${message}${NC}" ;;
        INFO)    echo -e "${CYAN}[ii] ${message}${NC}" ;;
        *)       echo "$message" ;;
    esac
}

die() {
    log "ERROR" "${MSG_LOG_CRITICAL}: $1"
    echo -e "\n${RED}${BOLD}[XX] ${MSG_PROCESS_ABORTED}: $1${NC}"
    rm -f "$LOCK_FILE" 2>/dev/null
    exit 1
}

safe_run() {
    local cmd="$1"
    local err_msg="$2"

    log "INFO" "${MSG_EXECUTING}: $cmd"
    
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
    log "INFO" "${MSG_STEP_PREFIX} [$CURRENT_STEP/$TOTAL_STEPS]: $1"
}

print_header() {
    [ "$QUIET" = true ] && return
    clear
    print_box_top
    print_box_center "${BOLD}${MENU_SYSTEM_TITLE}${NC} - v${SCRIPT_VERSION}"
    print_box_bottom
    echo ""
    echo -e "  ${CYAN}${MSG_DISTRO_DETECTED}:${NC} ${BOLD}${DISTRO_NAME}${NC}"
    echo -e "  ${CYAN}${MSG_DISTRO_FAMILY}:${NC}      ${DISTRO_FAMILY^} (${DISTRO_CODENAME:-N/A})"
    echo ""
    [ "$DRY_RUN" = true ] && echo -e "${YELLOW}[??] DRY-RUN MODE${NC}\n"
}

cleanup() {
    rm -f "$LOCK_FILE" 2>/dev/null
    log "INFO" "Lock file removed"
}

trap cleanup EXIT INT TERM

# ============================================================================
# FUNCIONES DE VALIDACIÓN Y CHEQUEO
# ============================================================================

detect_distro() {
    # Detectar distribución usando /etc/os-release
    if [ ! -f /etc/os-release ]; then
        die "${MSG_DISTRO_NOT_DETECTED}"
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
                    die "$(printf "${MSG_DISTRO_NOT_SUPPORTED}" "$DISTRO_NAME")"
                fi
            else
                die "$(printf "${MSG_DISTRO_NOT_SUPPORTED}" "$DISTRO_NAME")"
            fi
            ;;
    esac

    log "INFO" "${MSG_DISTRO_DETECTED}: $DISTRO_NAME ($DISTRO_ID)"
    log "INFO" "${MSG_DISTRO_FAMILY}: $DISTRO_FAMILY | ${MSG_DISTRO_VERSION}: $DISTRO_VERSION | ${MSG_DISTRO_CODENAME}: $DISTRO_CODENAME"
    log "INFO" "${MSG_DISTRO_MIRROR}: $DISTRO_MIRROR"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo ""
        print_box_top "$RED"
        print_box_line "${RED}[XX] ERROR: Este script requiere permisos de root${NC}"
        print_box_bottom "$RED"
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
            echo -e "${RED}[XX] Ya hay una instancia del script corriendo (PID: $pid)${NC}"
            exit 1
        fi
        rm -f "$LOCK_FILE"
    fi
    echo $$ > "$LOCK_FILE"
    
    # Verificación extra de locks de APT
    if fuser /var/lib/dpkg/lock* /var/lib/apt/lists/lock* 2>/dev/null | grep -q .; then
        echo -e "${RED}[XX] APT esta ocupado. Cierra Synaptic/Discover e intenta de nuevo.${NC}"
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
            echo -e "${YELLOW}[!!] Vas a limpiar kernels sin crear snapshot de Timeshift.${NC}"
            read -p "¿Continuar de todos modos? (s/N): " -n 1 -r
            echo
            [[ ! $REPLY =~ ^[Ss]$ ]] && die "Abortado por el usuario"
        fi
    fi
    
    log "SUCCESS" "Validación de dependencias OK"
}

show_step_summary() {
    [ "$QUIET" = true ] && return

    local step_vars=("STEP_CHECK_CONNECTIVITY" "STEP_CHECK_DEPENDENCIES" "STEP_BACKUP_TAR"
                     "STEP_SNAPSHOT_TIMESHIFT" "STEP_UPDATE_REPOS" "STEP_UPGRADE_SYSTEM"
                     "STEP_UPDATE_FLATPAK" "STEP_UPDATE_SNAP" "STEP_CHECK_FIRMWARE"
                     "STEP_CLEANUP_APT" "STEP_CLEANUP_KERNELS" "STEP_CLEANUP_DISK" "STEP_CHECK_REBOOT")

    print_box_top
    print_box_center "${BOLD}CONFIGURACIÓN DE PASOS - RESUMEN${NC}"
    print_box_sep
    print_box_center "${DISTRO_NAME} | ${DISTRO_FAMILY^} (${DISTRO_CODENAME:-N/A})"
    print_box_sep
    print_box_line "${BOLD}PASOS A EJECUTAR${NC}"

    # Mostrar en 3 columnas (5 filas) - formato fijo 15 chars por celda
    for row in {0..4}; do
        local line=""
        for col in {0..2}; do
            local idx=$((row * 3 + col))
            if [ $idx -lt 13 ]; then
                local var_name="${step_vars[$idx]}"
                local var_value="${!var_name}"
                # Nombre con ancho fijo de 10 chars
                local name
                name=$(printf "%-10.10s" "${STEP_SHORT_NAMES[$idx]}")

                if [ "$var_value" = "1" ]; then
                    line+=" ${GREEN}[x]${NC} ${name}"
                else
                    line+=" ${DIM}[--]${NC}${name}"
                fi
            else
                # Celda vacía: 15 espacios
                line+="               "
            fi
        done
        print_box_line "$line"
    done

    print_box_sep
    print_box_line "${MENU_TOTAL}: ${GREEN}${TOTAL_STEPS}${NC}/13 ${MENU_STEPS}    ${MENU_EST_TIME}: ${CYAN}~$((TOTAL_STEPS / 2 + 1)) ${MENU_MIN}${NC}"
    print_box_bottom
    echo ""

    if [ "$UNATTENDED" = false ] && [ "$DRY_RUN" = false ]; then
        read -p "${PROMPT_CONTINUE_CONFIG} " -n 1 -r
        echo
        [[ ! $REPLY =~ $PROMPT_YES_PATTERN ]] && die "${MSG_CANCELLED_BY_USER}"
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
    trap 'tput cnorm 2>/dev/null' RETURN

    while [ "$menu_running" = true ]; do
        # Contar pasos activos
        local active_count=0
        for var_name in "${MENU_STEP_VARS[@]}"; do
            [ "${!var_name}" = "1" ] && ((active_count++))
        done

        # Calcular fila y columna actual
        local cur_row=$((current_index / 3))
        local cur_col=$((current_index % 3))

        # Limpiar pantalla y mostrar interfaz enterprise
        clear
        print_box_top
        print_box_center "${BOLD}${MENU_TITLE}${NC}"
        print_box_sep
        print_box_center "${DISTRO_NAME} | ${DISTRO_FAMILY^} (${DISTRO_CODENAME:-N/A})"
        print_box_sep
        print_box_line "${BOLD}${MENU_STEPS_TITLE}${NC} ${DIM}${MENU_STEPS_HELP}${NC}"

        # Mostrar pasos en 3 columnas (5 filas)
        # Cada celda: 15 chars fijos (prefix[1] + bracket[1] + check[1] + bracket[1] + name[11])
        for row in {0..4}; do
            local line=""
            for col in {0..2}; do
                local idx=$((row * 3 + col))
                if [ $idx -lt $total_items ]; then
                    local var_name="${MENU_STEP_VARS[$idx]}"
                    local var_value="${!var_name}"
                    # Truncar/pad nombre a exactamente 11 chars
                    local name
                    name=$(printf "%-11.11s" "${STEP_SHORT_NAMES[$idx]}")

                    # Determinar prefijo y estado
                    local prefix=" "
                    local check=" "
                    [ "$var_value" = "1" ] && check="x"
                    [ $idx -eq $current_index ] && prefix=">"

                    # Construir celda con formato CONSISTENTE (15 chars fijos)
                    if [ $idx -eq $current_index ]; then
                        # Seleccionado: todo en cyan brillante
                        line+="${BRIGHT_CYAN}${prefix}[${check}]${name}${NC}"
                    elif [ "$var_value" = "1" ]; then
                        # Activo: [x] en verde
                        line+=" ${GREEN}[x]${NC}${name}"
                    else
                        # Inactivo: [ ] en dim
                        line+=" ${DIM}[ ]${NC}${name}"
                    fi
                else
                    # Celda vacía: 15 espacios
                    line+="               "
                fi
            done
            print_box_line "$line"
        done

        print_box_sep
        print_box_line "${CYAN}>${NC} ${MENU_STEP_DESCRIPTIONS[$current_index]:0:68}"
        print_box_sep
        print_box_line "${MENU_SELECTED}: ${GREEN}${active_count}${NC}/${total_items}    ${MENU_PROFILE}: $(config_exists && echo "${GREEN}${MENU_PROFILE_SAVED}${NC}" || echo "${DIM}${MENU_PROFILE_UNSAVED}${NC}")"
        print_box_sep
        print_box_center "${CYAN}[ENTER]${NC} ${MENU_CTRL_ENTER} ${CYAN}[A]${NC} ${MENU_CTRL_ALL} ${CYAN}[N]${NC} ${MENU_CTRL_NONE} ${CYAN}[G]${NC} ${MENU_CTRL_SAVE} ${CYAN}[L]${NC} ${MENU_CTRL_LANG} ${CYAN}[T]${NC} ${MENU_CTRL_THEME:-Theme} ${CYAN}[Q]${NC} ${MENU_CTRL_QUIT}"
        print_box_bottom

        # Leer tecla
        local key=""
        IFS= read -rsn1 key

        # Detectar secuencias de escape (flechas)
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            case "$key" in
                '[A') # Arriba: misma columna, fila anterior
                    if [ $cur_row -gt 0 ]; then
                        ((current_index-=3))
                    else
                        # Ir a la última fila de la columna
                        local last_row=$(( (total_items - 1) / 3 ))
                        local new_idx=$((last_row * 3 + cur_col))
                        [ $new_idx -ge $total_items ] && new_idx=$((new_idx - 3))
                        current_index=$new_idx
                    fi
                    ;;
                '[B') # Abajo: misma columna, fila siguiente
                    local new_idx=$((current_index + 3))
                    if [ $new_idx -lt $total_items ]; then
                        current_index=$new_idx
                    else
                        # Volver a la primera fila de la columna
                        current_index=$cur_col
                    fi
                    ;;
                '[C') # Derecha: columna siguiente
                    if [ $cur_col -lt 2 ] && [ $((current_index + 1)) -lt $total_items ]; then
                        ((current_index++))
                    else
                        current_index=$((cur_row * 3))
                    fi
                    ;;
                '[D') # Izquierda: columna anterior
                    if [ $cur_col -gt 0 ]; then
                        ((current_index--))
                    else
                        local new_idx=$((cur_row * 3 + 2))
                        [ $new_idx -ge $total_items ] && new_idx=$((total_items - 1))
                        current_index=$new_idx
                    fi
                    ;;
            esac
        elif [[ "$key" == " " ]]; then
            local var_name="${MENU_STEP_VARS[$current_index]}"
            [ "${!var_name}" = "1" ] && eval "$var_name=0" || eval "$var_name=1"
        elif [[ "$key" == "" ]]; then
            menu_running=false
        else
            case "$key" in
                'a'|'A') for var_name in "${MENU_STEP_VARS[@]}"; do eval "$var_name=1"; done ;;
                'n'|'N') for var_name in "${MENU_STEP_VARS[@]}"; do eval "$var_name=0"; done ;;
                'g'|'G') save_config ;;
                'd'|'D') config_exists && delete_config ;;
                'l'|'L') show_language_selector ;;
                't'|'T') show_theme_selector ;;
                'q'|'Q') tput cnorm 2>/dev/null; die "${MSG_CANCELLED_BY_USER}" ;;
            esac
        fi
    done

    tput cnorm 2>/dev/null
    count_active_steps
}

check_disk_space() {
    print_step "${MSG_CHECKING_DISK_SPACE}"

    local root_gb=$(df / --output=avail | tail -1 | awk '{print int($1/1024/1024)}')
    local boot_mb=$(df /boot --output=avail 2>/dev/null | tail -1 | awk '{print int($1/1024)}' || echo 0)

    printf "→ ${MSG_FREE_SPACE_ROOT}\n" "$root_gb"
    [ -n "$boot_mb" ] && [ "$boot_mb" -gt 0 ] && printf "→ ${MSG_FREE_SPACE_BOOT}\n" "$boot_mb"

    if [ "$root_gb" -lt "$MIN_FREE_SPACE_GB" ]; then
        die "$(printf "$MSG_INSUFFICIENT_SPACE" "$root_gb" "$MIN_FREE_SPACE_GB")"
    fi

    if [ -n "$boot_mb" ] && [ "$boot_mb" -gt 0 ] && [ "$boot_mb" -lt "$MIN_FREE_SPACE_BOOT_MB" ]; then
        log "WARN" "$(printf "$MSG_LOW_BOOT_SPACE" "$boot_mb")"
    fi

    # Guardar espacio inicial
    SPACE_BEFORE_ROOT=$(df / --output=used | tail -1 | awk '{print $1}')
    SPACE_BEFORE_BOOT=$(df /boot --output=used 2>/dev/null | tail -1 | awk '{print $1}' || echo 0)

    log "SUCCESS" "${MSG_DISK_SPACE_OK}"
}

# ============================================================================
# PASO 1: VERIFICAR CONECTIVIDAD
# ============================================================================

step_check_connectivity() {
    [ "$STEP_CHECK_CONNECTIVITY" = 0 ] && return

    print_step "${MSG_CHECKING_CONNECTIVITY}"

    # Usar el mirror correspondiente a la distribución detectada
    local mirror_to_check="${DISTRO_MIRROR:-deb.debian.org}"

    echo "→ ${MSG_CHECKING_CONNECTION_TO} $mirror_to_check..."

    if ping -c 1 -W 3 "$mirror_to_check" >/dev/null 2>&1; then
        echo "→ ${MSG_CONNECTION_OK}"
        STAT_CONNECTIVITY="$ICON_OK"
        log "SUCCESS" "${MSG_CONNECTION_OK}"
    else
        # Intentar con un servidor de respaldo genérico
        if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
            echo -e "${YELLOW}→ ${MSG_CONNECTION_WARN}${NC}"
            STAT_CONNECTIVITY="$ICON_WARN"
            log "WARN" "${MSG_CONNECTION_WARN}"
        else
            STAT_CONNECTIVITY="$ICON_FAIL"
            die "${MSG_NO_CONNECTION}"
        fi
    fi
}

# ============================================================================
# PASO 2: VERIFICAR E INSTALAR DEPENDENCIAS
# ============================================================================

step_check_dependencies() {
    [ "$STEP_CHECK_DEPENDENCIES" = 0 ] && return

    print_step "${MSG_CHECKING_TOOLS}"
    
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
        echo -e "${CYAN}→ ${MSG_TOOLS_SKIPPED}: ${skipped_tools[*]}${NC}"
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        printf "${YELLOW}[!!] ${MSG_MISSING_TOOLS}${NC}\n" "${#missing[@]}"
        for i in "${!missing[@]}"; do
            echo -e "   • ${missing[$i]}: ${missing_names[$i]}"
        done
        echo ""

        if [ "$UNATTENDED" = false ] && [ "$DRY_RUN" = false ]; then
            read -p "${PROMPT_INSTALL_TOOLS} " -n 1 -r
            echo
            if [[ $REPLY =~ $PROMPT_YES_PATTERN ]]; then
                echo "→ ${MSG_INSTALLING_TOOLS}"
                
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
                
                if safe_run "apt update && apt install -y $packages_to_install" "Error"; then
                    log "SUCCESS" "${MSG_TOOLS_INSTALLED}"
                    STAT_DEPENDENCIES="$ICON_OK"
                else
                    log "WARN" "${MSG_TOOLS_PARTIAL}"
                    STAT_DEPENDENCIES="${YELLOW}$ICON_WARN${NC}"
                fi
            else
                log "WARN" "${MSG_USER_SKIPPED_TOOLS}"
                STAT_DEPENDENCIES="${YELLOW}$ICON_WARN${NC}"
            fi
        else
            log "WARN" "${MSG_USER_SKIPPED_TOOLS}"
            STAT_DEPENDENCIES="${YELLOW}$ICON_WARN${NC}"
        fi
    else
        echo "→ ${MSG_TOOLS_OK}"
        STAT_DEPENDENCIES="$ICON_OK"
        log "SUCCESS" "${MSG_TOOLS_OK}"
    fi
}

# ============================================================================
# PASO 3: BACKUP DE CONFIGURACIONES (TAR)
# ============================================================================

step_backup_tar() {
    [ "$STEP_BACKUP_TAR" = 0 ] && return

    print_step "${MSG_CREATING_BACKUP}"
    
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
        
        echo "→ ${MSG_BACKUP_CREATED}: $backup_file"
        STAT_BACKUP_TAR="$ICON_OK"
        log "SUCCESS" "${MSG_BACKUP_CREATED}"

        # Limpiar backups antiguos (mantener últimas 5 ejecuciones)
        ls -t "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | tail -n +6 | xargs -r rm -f
        ls -t "$BACKUP_DIR"/packages_*.list 2>/dev/null | tail -n +6 | xargs -r rm -f
    else
        STAT_BACKUP_TAR="$ICON_FAIL"
        log "ERROR" "${MSG_BACKUP_FAILED}"
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
    [ "$STEP_SNAPSHOT_TIMESHIFT" = 0 ] && return

    print_step "${ICON_SHIELD} ${MSG_CREATING_SNAPSHOT}"

    if ! command -v timeshift &>/dev/null; then
        echo -e "${YELLOW}→ ${MSG_TIMESHIFT_NOT_INSTALLED}${NC}"
        STAT_SNAPSHOT="${YELLOW}$ICON_SKIP${NC}"
        log "WARN" "${MSG_TIMESHIFT_NOT_INSTALLED}"
        return
    fi

    # Verificar si Timeshift está CONFIGURADO
    if ! check_timeshift_configured; then
        echo ""
        print_box_top "$YELLOW"
        print_box_line "${YELLOW}[!!] ${MSG_TIMESHIFT_NOT_CONFIGURED}${NC}"
        print_box_bottom "$YELLOW"
        echo ""
        echo -e "  ${MSG_TIMESHIFT_CONFIG_NEEDED}"
        echo ""
        echo -e "  ${CYAN}${MSG_TIMESHIFT_CONFIG_INSTRUCTIONS}${NC}"
        echo -e "    ${GREEN}sudo timeshift-gtk${NC}  ${MSG_TIMESHIFT_CONFIG_GUI}"
        echo -e "    ${GREEN}sudo timeshift --wizard${NC}  ${MSG_TIMESHIFT_CONFIG_CLI}"
        echo ""
        echo -e "  ${CYAN}${MSG_TIMESHIFT_MUST_CONFIG}${NC}"
        echo -e "    • ${MSG_TIMESHIFT_CONFIG_TYPE}"
        echo -e "    • ${MSG_TIMESHIFT_CONFIG_DEVICE}"
        echo ""
        log "WARN" "${MSG_TIMESHIFT_SKIPPED_NOCONFIG}"
        STAT_SNAPSHOT="${YELLOW}$ICON_WARN${NC}"

        if [ "$UNATTENDED" = false ]; then
            echo -e "${YELLOW}${MSG_CONTINUE_WITHOUT_SNAPSHOT}${NC}"
            read -n 1 -s -r
            echo ""
        fi

        return
    fi

    # Preguntar si desea omitir (solo en modo interactivo)
    if [ "$ASK_TIMESHIFT_RUN" = true ] && [ "$UNATTENDED" = false ] && [ "$DRY_RUN" = false ]; then
        echo -e "${YELLOW}${PROMPT_SKIP_SNAPSHOT}${NC}"
        read -p "${PROMPT_SKIP_INSTRUCTIONS} " -n 1 -r
        echo
        if [[ $REPLY =~ $PROMPT_YES_PATTERN ]]; then
            log "WARN" "${MSG_TIMESHIFT_SKIPPED_USER}"
            STAT_SNAPSHOT="${YELLOW}$ICON_SKIP${NC}"
            return
        fi
    fi
    
    if [ "$DRY_RUN" = true ]; then
        STAT_SNAPSHOT="${YELLOW}DRY-RUN${NC}"
        return
    fi

    # Crear snapshot
    local ts_comment="Pre-Maintenance $(date +%Y-%m-%d_%H:%M:%S)"
    if timeshift --create --comments "$ts_comment" --tags O >> "$LOG_FILE" 2>&1; then
        echo "→ ${MSG_SNAPSHOT_CREATED}"
        STAT_SNAPSHOT="${GREEN}$ICON_OK${NC}"
        log "SUCCESS" "${MSG_SNAPSHOT_CREATED}"
    else
        echo -e "${RED}→ ${MSG_SNAPSHOT_FAILED}${NC}"
        STAT_SNAPSHOT="${RED}$ICON_FAIL${NC}"
        log "ERROR" "${MSG_SNAPSHOT_FAILED}"

        if [ "$UNATTENDED" = false ]; then
            echo -e "${YELLOW}${PROMPT_CONTINUE_NO_SNAPSHOT}${NC}"
            read -p "${PROMPT_CONFIRM_SI} " -r CONFIRM
            if [ "$CONFIRM" != "${PROMPT_CONFIRM_YES}" ]; then
                die "${MSG_ABORTED_NO_SNAPSHOT}"
            fi
            log "WARN" "${MSG_USER_CONTINUED_NO_SNAPSHOT}"
        else
            # En modo desatendido, abortar por seguridad
            die "${MSG_ABORTED_NO_SNAPSHOT}"
        fi
    fi
}

# ============================================================================
# PASO 5: ACTUALIZAR REPOSITORIOS
# ============================================================================

step_update_repos() {
    [ "$STEP_UPDATE_REPOS" = 0 ] && return

    print_step "${MSG_UPDATING_REPOS}"

    # Reparar dpkg antes de actualizar
    dpkg --configure -a >> "$LOG_FILE" 2>&1

    if safe_run "apt update" "Error"; then
        echo "→ ${MSG_REPOS_UPDATED}"
        STAT_REPO="$ICON_OK"
    else
        STAT_REPO="$ICON_FAIL"
        die "${MSG_REPOS_ERROR}"
    fi
}

# ============================================================================
# PASO 6: ACTUALIZAR SISTEMA (APT)
# ============================================================================

step_upgrade_system() {
    [ "$STEP_UPGRADE_SYSTEM" = 0 ] && return

    print_step "${MSG_ANALYZING_UPDATES}"

    # Contar actualizaciones disponibles
    local updates_output=$(apt list --upgradable 2>/dev/null)
    local updates=$(echo "$updates_output" | grep -c '\[upgradable' || echo 0)
    updates=${updates//[^0-9]/}
    updates=${updates:-0}
    updates=$((updates + 0))

    if [ "$updates" -gt 0 ]; then
        printf "→ ${MSG_PACKAGES_TO_UPDATE}\n" "$updates"

        # Análisis heurístico de riesgo (borrados masivos)
        log "INFO" "${MSG_SIMULATING_UPGRADE}"
        local simulation=$(apt full-upgrade -s 2>/dev/null)
        local remove_count=$(echo "$simulation" | grep "^Remv" | wc -l)

        if [ "$remove_count" -gt "$MAX_REMOVALS_ALLOWED" ]; then
            printf "\n${RED}${BOLD}[!!] ${MSG_SECURITY_ALERT}${NC}\n" "$remove_count"
            echo "$simulation" | grep "^Remv" | head -n 5 | sed "s/^Remv/ - ${MSG_REMOVING}/"

            if [ "$UNATTENDED" = true ]; then
                die "${MSG_ABORTED_MASS_REMOVAL}"
            fi

            echo -e "\n${YELLOW}${MSG_HAVE_SNAPSHOT}${NC}"
            read -p "${PROMPT_CONFIRM_SI} " -r CONFIRM
            if [ "$CONFIRM" != "${PROMPT_CONFIRM_YES}" ]; then
                die "${MSG_CANCELLED_BY_USER}"
            fi
        fi

        # Ejecutar actualización
        if safe_run "apt full-upgrade -y" "Error"; then
            printf "→ ${MSG_PACKAGES_UPDATED}\n" "$updates"
            STAT_UPGRADE="$ICON_OK"
            UPGRADE_PERFORMED=true
            log "SUCCESS" "$(printf "$MSG_PACKAGES_UPDATED" "$updates")"
        else
            STAT_UPGRADE="$ICON_FAIL"
            log "ERROR" "${MSG_UPGRADE_ERROR}"
        fi
    else
        echo "→ ${MSG_SYSTEM_UPTODATE}"
        STAT_UPGRADE="$ICON_OK"
        log "INFO" "${MSG_SYSTEM_UPTODATE}"
    fi
}

# ============================================================================
# PASO 7: ACTUALIZAR FLATPAK
# ============================================================================

step_update_flatpak() {
    [ "$STEP_UPDATE_FLATPAK" = 0 ] && return

    print_step "${MSG_UPDATING_FLATPAK}"

    if ! command -v flatpak &>/dev/null; then
        echo "→ ${MSG_FLATPAK_NOT_INSTALLED}"
        STAT_FLATPAK="$ICON_SKIP"
        return
    fi

    if safe_run "flatpak update -y" "Error"; then
        # Limpiar referencias huérfanas
        safe_run "flatpak uninstall --unused -y" "Error"

        # Reparar instalación
        safe_run "flatpak repair" "Error"

        echo "→ ${MSG_FLATPAK_UPDATED}"
        STAT_FLATPAK="$ICON_OK"
        log "SUCCESS" "${MSG_FLATPAK_UPDATED}"
    else
        STAT_FLATPAK="$ICON_FAIL"
        log "ERROR" "${MSG_FLATPAK_ERROR}"
    fi
}

# ============================================================================
# PASO 8: ACTUALIZAR SNAP
# ============================================================================

step_update_snap() {
    [ "$STEP_UPDATE_SNAP" = 0 ] && return

    print_step "${MSG_UPDATING_SNAP}"

    if ! command -v snap &>/dev/null; then
        echo "→ ${MSG_SNAP_NOT_INSTALLED}"
        STAT_SNAP="$ICON_SKIP"
        return
    fi

    if safe_run "snap refresh" "Error"; then
        echo "→ ${MSG_SNAP_UPDATED}"
        STAT_SNAP="$ICON_OK"
        log "SUCCESS" "${MSG_SNAP_UPDATED}"
    else
        STAT_SNAP="$ICON_FAIL"
        log "ERROR" "${MSG_SNAP_ERROR}"
    fi
}

# ============================================================================
# PASO 9: VERIFICAR FIRMWARE
# ============================================================================

step_check_firmware() {
    [ "$STEP_CHECK_FIRMWARE" = 0 ] && return

    print_step "${MSG_CHECKING_FIRMWARE}"

    if ! command -v fwupdmgr &>/dev/null; then
        echo "→ ${MSG_FWUPD_NOT_INSTALLED}"
        STAT_FIRMWARE="$ICON_SKIP"
        return
    fi
    
    # Verificar si necesita refresh (más de 7 días)
    local last_refresh=$(stat -c %Y /var/lib/fwupd/metadata.xml 2>/dev/null || echo 0)
    local current_time=$(date +%s)
    local days_old=$(( (current_time - last_refresh) / 86400 ))
    
    if [ "$days_old" -gt 7 ]; then
        safe_run "fwupdmgr refresh --force" "${MSG_FIRMWARE_REFRESH_ERROR}"
        echo "→ ${MSG_FIRMWARE_METADATA_UPDATED}"
    else
        printf "→ ${MSG_FIRMWARE_METADATA_DAYS}\n" "$days_old"
    fi

    # Verificar si hay actualizaciones disponibles
    if fwupdmgr get-updates >/dev/null 2>&1; then
        echo -e "${YELLOW}→ ${MSG_FIRMWARE_AVAILABLE}${NC}"
        STAT_FIRMWARE="${YELLOW}$ICON_WARN AVAILABLE${NC}"
        log "WARN" "${MSG_FIRMWARE_AVAILABLE}"
    else
        echo "→ ${MSG_FIRMWARE_UPTODATE}"
        STAT_FIRMWARE="$ICON_OK"
    fi
}

# ============================================================================
# PASO 10: LIMPIEZA APT
# ============================================================================

step_cleanup_apt() {
    [ "$STEP_CLEANUP_APT" = 0 ] && return

    print_step "${MSG_CLEANING_APT}"

    # Autoremove (paquetes huérfanos)
    if safe_run "apt autoremove -y" "Error"; then
        echo "→ ${MSG_ORPHANS_REMOVED}"
    else
        STAT_CLEAN_APT="$ICON_FAIL"
        return
    fi

    # Purge (paquetes con config residual)
    local pkgs_rc=$(dpkg -l 2>/dev/null | grep "^rc" | awk '{print $2}')
    if [ -n "$pkgs_rc" ]; then
        local rc_count=$(echo "$pkgs_rc" | wc -l)
        if echo "$pkgs_rc" | xargs apt purge -y >/dev/null 2>&1; then
            printf "→ ${MSG_RESIDUALS_PURGED}\n" "$rc_count"
            log "INFO" "$(printf "$MSG_RESIDUALS_PURGED" "$rc_count")"
        else
            STAT_CLEAN_APT="$ICON_FAIL"
            log "ERROR" "${MSG_APT_CLEANUP_ERROR}"
            return
        fi
    else
        echo "→ ${MSG_NO_RESIDUALS}"
    fi

    # Autoclean o clean
    if safe_run "apt $APT_CLEAN_MODE" "Error"; then
        echo "→ ${MSG_APT_CACHE_CLEANED}"
    fi

    STAT_CLEAN_APT="$ICON_OK"
    log "SUCCESS" "${MSG_APT_CLEANUP_OK}"
}

# ============================================================================
# PASO 11: LIMPIEZA DE KERNELS ANTIGUOS
# ============================================================================

step_cleanup_kernels() {
    [ "$STEP_CLEANUP_KERNELS" = 0 ] && return

    print_step "${MSG_CLEANING_KERNELS}"

    # Obtener kernel actual
    local current_kernel=$(uname -r)
    local current_kernel_pkg="linux-image-${current_kernel}"

    log "INFO" "${MSG_CURRENT_KERNEL}: $current_kernel"
    echo "→ ${MSG_KERNEL_IN_USE}: $current_kernel"

    # Obtener todos los kernels instalados
    local installed_kernels=$(dpkg -l 2>/dev/null | awk '/^ii.*linux-image-[0-9]/ {print $2}' | grep -v "meta")

    if [ -z "$installed_kernels" ]; then
        echo "→ ${MSG_NO_KERNELS_FOUND}"
        STAT_CLEAN_KERNEL="$ICON_OK"
        return
    fi

    # Contar kernels
    local kernel_count=$(echo "$installed_kernels" | wc -l)
    echo "→ ${MSG_INSTALLED_KERNELS}: $kernel_count"
    
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
        echo "→ ${MSG_KERNELS_TO_KEEP}"
        echo "$kernels_to_keep" | sed 's/^/   [x] /'
        echo ""
        echo "→ ${MSG_KERNELS_TO_REMOVE}"
        echo "$kernels_to_remove" | tr ' ' '\n' | sed 's/^/   [-] /'

        # Confirmación en modo interactivo
        if [ "$UNATTENDED" = false ] && [ "$DRY_RUN" = false ]; then
            read -p "${PROMPT_DELETE_KERNELS} " -n 1 -r
            echo
            if [[ ! $REPLY =~ $PROMPT_YES_PATTERN ]]; then
                log "INFO" "${MSG_USER_CANCELLED_KERNELS}"
                STAT_CLEAN_KERNEL="$ICON_SKIP"
                echo "→ ${MSG_USER_CANCELLED_KERNELS}"
                return
            fi
        fi

        # Eliminar kernels
        if echo "$kernels_to_remove" | xargs apt purge -y >> "$LOG_FILE" 2>&1; then
            echo "→ ${MSG_KERNELS_REMOVED}"
            STAT_CLEAN_KERNEL="$ICON_OK"
            log "SUCCESS" "${MSG_KERNELS_REMOVED}"

            # Regenerar GRUB
            if command -v update-grub &>/dev/null; then
                safe_run "update-grub" "Error"
                echo "→ ${MSG_GRUB_UPDATED}"
            fi
        else
            STAT_CLEAN_KERNEL="$ICON_FAIL"
            log "ERROR" "${MSG_KERNEL_CLEANUP_ERROR}"
        fi
    else
        echo "→ ${MSG_NO_KERNELS_TO_CLEAN}"
        STAT_CLEAN_KERNEL="$ICON_OK"
    fi
}

# ============================================================================
# PASO 12: LIMPIEZA DE DISCO (LOGS Y CACHÉ)
# ============================================================================

step_cleanup_disk() {
    [ "$STEP_CLEANUP_DISK" = 0 ] && return

    print_step "${MSG_CLEANING_DISK}"

    # Journalctl
    if command -v journalctl &>/dev/null; then
        if safe_run "journalctl --vacuum-time=${DIAS_LOGS}d --vacuum-size=500M" "Error"; then
            echo "→ ${MSG_JOURNALCTL_REDUCED}"
        fi
    fi

    # Archivos temporales antiguos
    find /var/tmp -type f -atime +30 -delete 2>/dev/null && \
        echo "→ ${MSG_TEMP_FILES_DELETED}" || true

    # Thumbnails
    local cleaned_homes=0
    for user_home in /home/* /root; do
        if [ -d "$user_home/.cache/thumbnails" ]; then
            rm -rf "$user_home/.cache/thumbnails/"* 2>/dev/null && ((cleaned_homes++))
        fi
    done
    [ "$cleaned_homes" -gt 0 ] && printf "→ ${MSG_THUMBNAILS_CLEANED}\n" "$cleaned_homes"

    STAT_CLEAN_DISK="$ICON_OK"
    log "SUCCESS" "${MSG_DISK_CLEANUP_OK}"
}

# ============================================================================
# PASO 13: VERIFICAR NECESIDAD DE REINICIO
# ============================================================================

step_check_reboot() {
    [ "$STEP_CHECK_REBOOT" = 0 ] && return

    print_step "${MSG_CHECKING_REBOOT}"

    # Verificar archivo de reinicio requerido
    if [ -f /var/run/reboot-required ]; then
        REBOOT_NEEDED=true
        log "WARN" "${MSG_REBOOT_FILE_DETECTED}"
        echo "→ ${MSG_REBOOT_FILE_DETECTED}"
    fi

    # Verificar servicios fallidos
    local failed_services=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
    failed_services=${failed_services//[^0-9]/}
    failed_services=${failed_services:-0}

    if [ "$failed_services" -gt 0 ]; then
        log "WARN" "$(printf "$MSG_FAILED_SERVICES" "$failed_services")"
        printf "${YELLOW}→ ${MSG_FAILED_SERVICES}${NC}\n" "$failed_services"
        
        if [ "$UNATTENDED" = false ]; then
            systemctl --failed --no-pager 2>/dev/null | head -10
        fi
    fi
    
    # Needrestart - Verificación avanzada
    if command -v needrestart &>/dev/null; then
        echo "→ ${MSG_ANALYZING_NEEDRESTART}"

        # Ejecutar needrestart en modo batch
        local needrestart_output=$(needrestart -b 2>/dev/null)

        # Extraer información del kernel
        local running_kernel=$(echo "$needrestart_output" | grep "NEEDRESTART-KCUR:" | awk '{print $2}')
        local expected_kernel=$(echo "$needrestart_output" | grep "NEEDRESTART-KEXP:" | awk '{print $2}')
        local kernel_status=$(echo "$needrestart_output" | grep "NEEDRESTART-KSTA:" | awk '{print $2}')

        log "INFO" "Running kernel: $running_kernel"
        log "INFO" "Expected kernel: $expected_kernel"
        log "INFO" "KSTA status: $kernel_status"

        # VERIFICACIÓN 1: Kernel desactualizado (COMPARACIÓN DIRECTA)
        if [ -n "$expected_kernel" ] && [ -n "$running_kernel" ]; then
            if [ "$running_kernel" != "$expected_kernel" ]; then
                REBOOT_NEEDED=true
                log "WARN" "${MSG_KERNEL_OUTDATED}: $running_kernel → $expected_kernel"
                echo -e "${YELLOW}→ ${MSG_KERNEL_OUTDATED}${NC}"
            else
                log "INFO" "${MSG_KERNEL_UPTODATE}"
                echo "→ ${MSG_KERNEL_UPTODATE}"
            fi
        fi

        # VERIFICACIÓN 2: Servicios que necesitan reinicio
        local services_restart=$(echo "$needrestart_output" | grep "NEEDRESTART-SVC:" | wc -l)
        services_restart=${services_restart//[^0-9]/}
        services_restart=${services_restart:-0}
        services_restart=$((services_restart + 0))

        if [ "$services_restart" -gt 0 ]; then
            log "INFO" "$(printf "$MSG_SERVICES_NEED_RESTART" "$services_restart")"
            printf "→ ${MSG_SERVICES_NEED_RESTART}\n" "$services_restart"
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
            # Usamos el flag UPGRADE_PERFORMED que se establece en step_upgrade_system()
            if [ "$UPGRADE_PERFORMED" = true ]; then
                REBOOT_NEEDED=true
                log "WARN" "${MSG_CRITICAL_LIBS_UPDATED}"
                echo -e "${YELLOW}→ ${MSG_CRITICAL_LIBS_UPDATED}${NC}"
            else
                # UCSTA=1 es de una actualización anterior, no de ahora
                log "INFO" "UCSTA=1 persistent from previous update (not this session)"
                echo "→ ${MSG_CRITICAL_LIBS_STABLE}"
            fi
        else
            log "INFO" "${MSG_NO_CRITICAL_LIBS_CHANGES}"
            echo "→ ${MSG_NO_CRITICAL_LIBS_CHANGES}"
        fi
        
        # Intentar reiniciar servicios automáticamente
        if [ "$DRY_RUN" = false ]; then
            if [ "$services_restart" -gt 0 ]; then
                echo "→ ${MSG_RESTARTING_SERVICES}"
                needrestart -r a >> "$LOG_FILE" 2>&1
                log "INFO" "Needrestart executed for $services_restart services"
            else
                echo "→ ${MSG_NO_SERVICES_RESTART}"
            fi
        fi
    else
        log "INFO" "needrestart not installed"
        echo "→ ${MSG_NEEDRESTART_NOT_INSTALLED}"
    fi
    
    # Establecer estado final
    if [ "$REBOOT_NEEDED" = true ]; then
        STAT_REBOOT="${RED}$ICON_WARN ${MSG_STAT_REQUIRED}${NC}"
        log "WARN" "${MSG_REBOOT_REQUIRED}"
    else
        STAT_REBOOT="${GREEN}$ICON_OK ${MSG_STAT_NOT_NEEDED}${NC}"
        log "INFO" "${MSG_REBOOT_NOT_REQUIRED}"
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
    local duration_str=$(printf "%02d:%02d" $minutes $seconds)

    # Calcular espacio liberado
    local space_after_root=$(df / --output=used | tail -1 | awk '{print $1}')
    local space_after_boot=$(df /boot --output=used 2>/dev/null | tail -1 | awk '{print $1}' || echo 0)
    local space_freed_root=$(( (SPACE_BEFORE_ROOT - space_after_root) / 1024 ))
    local space_freed_boot=$(( (SPACE_BEFORE_BOOT - space_after_boot) / 1024 ))
    [ $space_freed_root -lt 0 ] && space_freed_root=0
    [ $space_freed_boot -lt 0 ] && space_freed_boot=0
    local total_freed=$((space_freed_root + space_freed_boot))

    # Mapear STAT_* a STEP_STATUS_ARRAY para resumen
    # Índice: 0=Conectividad, 1=Dependencias, 2=Backup, 3=Snapshot, 4=Repos
    #         5=Upgrade, 6=Flatpak, 7=Snap, 8=Firmware, 9=APT, 10=Kernels, 11=Disco, 12=Reinicio
    local step_vars=("STEP_CHECK_CONNECTIVITY" "STEP_CHECK_DEPENDENCIES" "STEP_BACKUP_TAR"
                     "STEP_SNAPSHOT_TIMESHIFT" "STEP_UPDATE_REPOS" "STEP_UPGRADE_SYSTEM"
                     "STEP_UPDATE_FLATPAK" "STEP_UPDATE_SNAP" "STEP_CHECK_FIRMWARE"
                     "STEP_CLEANUP_APT" "STEP_CLEANUP_KERNELS" "STEP_CLEANUP_DISK" "STEP_CHECK_REBOOT")
    local stat_vars=("STAT_CONNECTIVITY" "STAT_DEPENDENCIES" "STAT_BACKUP_TAR" "STAT_SNAPSHOT"
                     "STAT_REPO" "STAT_UPGRADE" "STAT_FLATPAK" "STAT_SNAP" "STAT_FIRMWARE"
                     "STAT_CLEAN_APT" "STAT_CLEAN_KERNEL" "STAT_CLEAN_DISK" "STAT_REBOOT")

    # Contar resultados y determinar estados
    local success_count=0 error_count=0 skipped_count=0 warning_count=0
    for i in {0..12}; do
        local step_var="${step_vars[$i]}"
        local stat_var="${stat_vars[$i]}"
        local step_enabled="${!step_var}"
        local stat_value="${!stat_var}"

        if [ "$step_enabled" != "1" ]; then
            STEP_STATUS_ARRAY[$i]="skipped"
            ((skipped_count++))
        elif [[ "$stat_value" == *"$ICON_OK"* ]] || [[ "$stat_value" == *"[OK]"* ]]; then
            STEP_STATUS_ARRAY[$i]="success"
            ((success_count++))
        elif [[ "$stat_value" == *"$ICON_FAIL"* ]] || [[ "$stat_value" == *"[XX]"* ]]; then
            STEP_STATUS_ARRAY[$i]="error"
            ((error_count++))
        elif [[ "$stat_value" == *"$ICON_WARN"* ]] || [[ "$stat_value" == *"[!!]"* ]] || [[ "$stat_value" == *"WARN"* ]]; then
            STEP_STATUS_ARRAY[$i]="warning"
            ((warning_count++))
        elif [[ "$stat_value" == *"$ICON_SKIP"* ]] || [[ "$stat_value" == *"[--]"* ]] || [[ "$stat_value" == *"Omitido"* ]]; then
            STEP_STATUS_ARRAY[$i]="skipped"
            ((skipped_count++))
        else
            STEP_STATUS_ARRAY[$i]="success"
            ((success_count++))
        fi
    done

    # Determinar estado general
    local overall_status="${MSG_SUMMARY_COMPLETED}"
    local overall_color="${GREEN}"
    local overall_icon="${ICON_SUM_OK}"
    if [ $error_count -gt 0 ]; then
        overall_status="${MSG_SUMMARY_COMPLETED_ERRORS}"
        overall_color="${RED}"
        overall_icon="${ICON_SUM_FAIL}"
    elif [ $warning_count -gt 0 ]; then
        overall_status="${MSG_SUMMARY_COMPLETED_WARNINGS}"
        overall_color="${YELLOW}"
        overall_icon="${ICON_SUM_WARN}"
    fi

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

    # === RESUMEN ENTERPRISE 3 COLUMNAS (78 chars) ===
    echo ""
    print_box_top
    print_box_center "${BOLD}${MENU_SUMMARY_TITLE}${NC}"
    print_box_sep
    print_box_line "${MSG_SUMMARY_STATUS}: ${overall_color}${overall_icon} ${overall_status}${NC}                          ${MSG_SUMMARY_DURATION}: ${FIXED_CYAN}${duration_str}${NC}"
    print_box_sep
    print_box_line "${BOLD}${MSG_SUMMARY_METRICS}${NC}"
    print_box_line "${MSG_SUMMARY_COMPLETED_COUNT}: ${FIXED_GREEN}${success_count}${NC}    ${MSG_SUMMARY_ERRORS}: ${FIXED_RED}${error_count}${NC}    ${MSG_SUMMARY_SKIPPED}: ${FIXED_YELLOW}${skipped_count}${NC}    ${MSG_SUMMARY_SPACE}: ${FIXED_CYAN}${total_freed} MB${NC}"
    print_box_sep
    print_box_line "${BOLD}${MSG_SUMMARY_STEP_DETAIL}${NC}"

    # Generar líneas de 3 columnas (5 filas x 3 cols = 15 slots, usamos 13)
    # Formato fijo: icono[4] + espacio[1] + nombre[10] = 15 chars por celda
    for row in {0..4}; do
        local line=""
        for col in {0..2}; do
            local idx=$((row * 3 + col))
            if [ $idx -le 12 ]; then
                local icon=$(get_step_icon_summary "${STEP_STATUS_ARRAY[$idx]}")
                # Nombre con ancho fijo de 10 chars
                local name
                name=$(printf "%-10.10s" "${STEP_SHORT_NAMES[$idx]}")
                line+="${icon} ${name} "
            else
                # Celda vacía: 16 espacios
                line+="                "
            fi
        done
        print_box_line "$line"
    done

    print_box_sep

    # Estado de reinicio
    if [ "$REBOOT_NEEDED" = true ]; then
        print_box_line "${RED}${ICON_SUM_WARN} ${MSG_REBOOT_REQUIRED}${NC}"
    else
        print_box_line "${GREEN}${ICON_SUM_OK} ${MSG_REBOOT_NOT_REQUIRED}${NC}"
    fi

    print_box_sep
    print_box_line "${MSG_SUMMARY_LOG}: ${DIM}${LOG_FILE}${NC}"
    [ "$STEP_BACKUP_TAR" = 1 ] && print_box_line "${MSG_SUMMARY_BACKUPS}: ${DIM}${BACKUP_DIR}${NC}"
    print_box_bottom
    echo ""

    # Advertencias fuera del box
    if [[ "$STAT_FIRMWARE" == *"DISPONIBLE"* ]] || [[ "$STAT_FIRMWARE" == *"AVAILABLE"* ]]; then
        echo -e "${YELLOW}[!!] ${MSG_FIRMWARE_AVAILABLE_NOTE}${NC}"
        echo "   → ${MSG_FIRMWARE_INSTALL_HINT}"
        echo ""
    fi

    if [ "$REBOOT_NEEDED" = true ] && [ "$UNATTENDED" = false ]; then
        echo ""
        read -p "${PROMPT_REBOOT_NOW} " -n 1 -r
        echo
        if [[ $REPLY =~ $PROMPT_YES_PATTERN ]]; then
            log "INFO" "User requested immediate reboot"
            echo "${MSG_REBOOTING_IN}"
            sleep 5
            reboot
        fi
    fi
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
        --lang)
            if [ -n "$2" ]; then
                AUTOCLEAN_LANG="$2"
                shift 2
            else
                echo "Error: --lang requires a language code (en, es)"
                exit 1
            fi
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

# Cargar configuración guardada si existe (para obtener SAVED_LANG antes de cargar idioma)
if config_exists; then
    load_config
fi

# Cargar idioma (usa SAVED_LANG si existe, o detecta del sistema)
load_language

# Cargar tema (usa SAVED_THEME si existe, o usa default)
load_theme

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

# Mostrar resumen final
show_final_summary

exit 0
