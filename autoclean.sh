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
LANG_DIR="${SCRIPT_DIR}/plugins/lang"
DEFAULT_LANG="en"
CURRENT_LANG=""
AVAILABLE_LANGS=()    # Se llena dinámicamente con detect_languages()
LANG_NAMES=()         # Nombres para mostrar (de LANG_NAME en cada archivo)

# Configuración de tema
THEME_DIR="${SCRIPT_DIR}/plugins/themes"
DEFAULT_THEME="default"
CURRENT_THEME=""
AVAILABLE_THEMES=()   # Se llena dinámicamente con detect_themes()
THEME_NAMES=()        # Nombres para mostrar (de THEME_NAME en cada archivo)

# Configuración de notificadores
NOTIFIER_DIR="${SCRIPT_DIR}/plugins/notifiers"
AVAILABLE_NOTIFIERS=()    # Se llena dinámicamente con detect_notifiers()
NOTIFIER_NAMES=()         # Nombres para mostrar (de NOTIFIER_NAME en cada archivo)
NOTIFIER_DESCRIPTIONS=()  # Descripciones de cada notificador
declare -A NOTIFIER_ENABLED   # Estado habilitado/deshabilitado por código
declare -A NOTIFIER_LOADED    # Notificadores cargados exitosamente

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
STEP_CLEANUP_DOCKER=0        # Limpiar Docker/Podman (deshabilitado por defecto)
STEP_CHECK_SMART=1           # Verificar salud de discos (SMART)
STEP_CHECK_REBOOT=1          # Verificar necesidad de reinicio

# Variables para programación Systemd Timer
SCHEDULE_MODE=""             # Modo: daily, weekly, monthly
UNSCHEDULE=false             # Flag para eliminar timer
SCHEDULE_STATUS=false        # Flag para mostrar estado del timer

# Variables para Perfiles Predefinidos
PROFILE=""                   # Perfil: server, desktop, developer, minimal

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
STAT_DOCKER="[..]"
STAT_SMART="[..]"
STAT_REBOOT="[..]"

# Contadores y tiempo
SPACE_BEFORE_ROOT=0
SPACE_BEFORE_BOOT=0
START_TIME=$(date +%s)
CURRENT_STEP=0
TOTAL_STEPS=0

# Flags de control
DRY_RUN=false
NOTIFY_ON_DRY_RUN=false
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
    "STEP_CHECK_CONNECTIVITY"    # 1 - Verificar conectividad
    "STEP_CHECK_DEPENDENCIES"    # 2 - Verificar dependencias
    "STEP_CHECK_SMART"           # 3 - SMART (verificar disco antes de cambios)
    "STEP_BACKUP_TAR"            # 4 - Backup TAR
    "STEP_SNAPSHOT_TIMESHIFT"    # 5 - Snapshot Timeshift
    "STEP_UPDATE_REPOS"          # 6 - Actualizar repos
    "STEP_UPGRADE_SYSTEM"        # 7 - Actualizar sistema
    "STEP_UPDATE_FLATPAK"        # 8 - Flatpak
    "STEP_UPDATE_SNAP"           # 9 - Snap
    "STEP_CHECK_FIRMWARE"        # 10 - Firmware
    "STEP_CLEANUP_APT"           # 11 - Limpieza APT
    "STEP_CLEANUP_KERNELS"       # 12 - Limpieza Kernels
    "STEP_CLEANUP_DISK"          # 13 - Limpieza Disco
    "STEP_CLEANUP_DOCKER"        # 14 - Limpieza Docker
    "STEP_CHECK_REBOOT"          # 15 - Verificar reinicio
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
        "$STEP_NAME_14"
        "$STEP_NAME_15"
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
        "$STEP_DESC_14"
        "$STEP_DESC_15"
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
        "$STEP_SHORT_14"
        "$STEP_SHORT_15"
    )
}

# ============================================================================
# FUNCIONES DE CONFIGURACIÓN PERSISTENTE
# ============================================================================

save_config() {
    # Guardar estado actual de los pasos y preferencias en archivo de configuración
    # SECURITY: Crear archivo con permisos restrictivos desde el inicio (evita race condition)
    local old_umask=$(umask)
    umask 077
    cat > "$CONFIG_FILE" << EOF
# Configuración de autoclean - Generado automáticamente
# Fecha: $(date '+%Y-%m-%d %H:%M:%S')

# ============================================================================
# PERFIL / PROFILE
# ============================================================================
# Valores: server, desktop, developer, minimal, custom
SAVED_PROFILE=${PROFILE:-custom}

# ============================================================================
# IDIOMA / LANGUAGE
# ============================================================================
SAVED_LANG=$CURRENT_LANG

# ============================================================================
# TEMA / THEME
# ============================================================================
SAVED_THEME=$CURRENT_THEME

# ============================================================================
# CONFIGURACION DE PASOS / STEPS CONFIGURATION
# ============================================================================
# (Solo aplica cuando SAVED_PROFILE=custom)
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
STEP_CLEANUP_DOCKER=$STEP_CLEANUP_DOCKER
STEP_CHECK_SMART=$STEP_CHECK_SMART
STEP_CHECK_REBOOT=$STEP_CHECK_REBOOT
EOF

    # Agregar sección de notificadores
    cat >> "$CONFIG_FILE" << 'NOTIF_HEADER'

# ============================================================================
# NOTIFICACIONES / NOTIFICATIONS
# ============================================================================
NOTIF_HEADER

    # Guardar estado habilitado/deshabilitado de cada notificador
    for code in "${AVAILABLE_NOTIFIERS[@]}"; do
        local enabled="${NOTIFIER_ENABLED[$code]:-0}"
        echo "NOTIFIER_${code^^}_ENABLED=$enabled" >> "$CONFIG_FILE"
    done

    # Guardar configuraciones específicas de cada notificador
    # Telegram
    [ -n "$NOTIFIER_TELEGRAM_BOT_TOKEN" ] && echo "NOTIFIER_TELEGRAM_BOT_TOKEN=\"$NOTIFIER_TELEGRAM_BOT_TOKEN\"" >> "$CONFIG_FILE"
    [ -n "$NOTIFIER_TELEGRAM_CHAT_ID" ] && echo "NOTIFIER_TELEGRAM_CHAT_ID=\"$NOTIFIER_TELEGRAM_CHAT_ID\"" >> "$CONFIG_FILE"
    # Email SMTP
    [ -n "$NOTIFIER_EMAIL_TO" ] && echo "NOTIFIER_EMAIL_TO=\"$NOTIFIER_EMAIL_TO\"" >> "$CONFIG_FILE"
    [ -n "$NOTIFIER_EMAIL_FROM" ] && echo "NOTIFIER_EMAIL_FROM=\"$NOTIFIER_EMAIL_FROM\"" >> "$CONFIG_FILE"
    [ -n "$NOTIFIER_EMAIL_SMTP_SERVER" ] && echo "NOTIFIER_EMAIL_SMTP_SERVER=\"$NOTIFIER_EMAIL_SMTP_SERVER\"" >> "$CONFIG_FILE"
    [ -n "$NOTIFIER_EMAIL_SMTP_PORT" ] && echo "NOTIFIER_EMAIL_SMTP_PORT=\"$NOTIFIER_EMAIL_SMTP_PORT\"" >> "$CONFIG_FILE"
    [ -n "$NOTIFIER_EMAIL_USER" ] && echo "NOTIFIER_EMAIL_USER=\"$NOTIFIER_EMAIL_USER\"" >> "$CONFIG_FILE"
    [ -n "$NOTIFIER_EMAIL_PASSWORD" ] && echo "NOTIFIER_EMAIL_PASSWORD=\"$NOTIFIER_EMAIL_PASSWORD\"" >> "$CONFIG_FILE"
    # ntfy.sh
    [ -n "$NOTIFIER_NTFY_TOPIC" ] && echo "NOTIFIER_NTFY_TOPIC=\"$NOTIFIER_NTFY_TOPIC\"" >> "$CONFIG_FILE"
    [ -n "$NOTIFIER_NTFY_SERVER" ] && echo "NOTIFIER_NTFY_SERVER=\"$NOTIFIER_NTFY_SERVER\"" >> "$CONFIG_FILE"
    [ -n "$NOTIFIER_NTFY_TOKEN" ] && echo "NOTIFIER_NTFY_TOKEN=\"$NOTIFIER_NTFY_TOKEN\"" >> "$CONFIG_FILE"
    # Webhook
    [ -n "$NOTIFIER_WEBHOOK_URL" ] && echo "NOTIFIER_WEBHOOK_URL=\"$NOTIFIER_WEBHOOK_URL\"" >> "$CONFIG_FILE"
    [ -n "$NOTIFIER_WEBHOOK_PRESET" ] && echo "NOTIFIER_WEBHOOK_PRESET=\"$NOTIFIER_WEBHOOK_PRESET\"" >> "$CONFIG_FILE"
    [ -n "$NOTIFIER_WEBHOOK_METHOD" ] && echo "NOTIFIER_WEBHOOK_METHOD=\"$NOTIFIER_WEBHOOK_METHOD\"" >> "$CONFIG_FILE"
    [ -n "$NOTIFIER_WEBHOOK_AUTH_HEADER" ] && echo "NOTIFIER_WEBHOOK_AUTH_HEADER=\"$NOTIFIER_WEBHOOK_AUTH_HEADER\"" >> "$CONFIG_FILE"
    [ -n "$NOTIFIER_WEBHOOK_CONTENT_TYPE" ] && echo "NOTIFIER_WEBHOOK_CONTENT_TYPE=\"$NOTIFIER_WEBHOOK_CONTENT_TYPE\"" >> "$CONFIG_FILE"

    local result=$?

    # SECURITY: Restaurar umask original
    umask "$old_umask"

    # Cambiar ownership al usuario que ejecutó sudo (no root)
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        chown "$SUDO_USER:$SUDO_USER" "$CONFIG_FILE" 2>/dev/null
    fi

    # Nota: chmod 600 ya no es necesario, umask 077 crea el archivo con permisos correctos

    return $result
}

# Validar archivo antes de hacer source (seguridad)
# Rechaza archivos con sintaxis peligrosa que podría ejecutar código
validate_source_file() {
    local file="$1"
    local file_type="${2:-file}"

    # Verificar que el archivo existe y es legible
    [[ ! -f "$file" || ! -r "$file" ]] && return 1

    # SECURITY: Verificar que no es un symlink apuntando fuera del directorio esperado
    local real_path
    real_path=$(realpath "$file" 2>/dev/null)
    local expected_dir
    expected_dir=$(dirname "$file")
    expected_dir=$(realpath "$expected_dir" 2>/dev/null)
    if [[ "$real_path" != "$expected_dir"/* ]]; then
        log "WARN" "Archivo $file_type rechazado: symlink fuera del directorio permitido"
        return 1
    fi

    # Patrones peligrosos a rechazar (podrían ejecutar código arbitrario)
    # Se buscan en contenido no comentado
    local content
    content=$(grep -v '^\s*#' "$file" 2>/dev/null)

    # SECURITY: Buscar patrones peligrosos con regex más estricto:
    # - $( o ` = command substitution
    # - ; seguido de cualquier caracter (no solo espacio+letra) = ejecución secuencial
    # - | = pipe a otro comando
    # - && o || = operadores lógicos (con o sin espacios)
    # - ${ con comandos = parameter expansion peligrosa
    if echo "$content" | grep -qE '\$\(|`|;.|[^a-zA-Z0-9_]\|[^a-zA-Z0-9_]|&&|\|\||\$\{[^}]*(:|/|%|#)' 2>/dev/null; then
        log "WARN" "Archivo $file_type rechazado: contiene sintaxis no permitida"
        return 1
    fi

    return 0
}

# Validar archivo notifier (menos restrictivo que validate_source_file)
# Los notifiers necesitan ejecutar comandos, pero bloqueamos patrones muy peligrosos
validate_notifier_file() {
    local file="$1"

    # Verificar que el archivo existe y es legible
    [[ ! -f "$file" || ! -r "$file" ]] && return 1

    # SECURITY: Verificar que no es un symlink apuntando fuera del directorio de notifiers
    local real_path
    real_path=$(realpath "$file" 2>/dev/null)
    local expected_dir
    expected_dir=$(realpath "$NOTIFIER_DIR" 2>/dev/null)
    if [[ "$real_path" != "$expected_dir"/* ]]; then
        log "WARN" "Archivo notifier rechazado: symlink fuera del directorio permitido"
        return 1
    fi

    local content
    content=$(grep -v '^\s*#' "$file" 2>/dev/null)

    # SECURITY: Patrones peligrosos a bloquear (regex reforzado):
    # - eval con cualquier separador (no solo espacio)
    # - source/. de URLs o variables = cargar código externo
    # - curl/wget con -o/-O = descarga a archivo
    # - curl/wget piped to bash/sh = ejecución remota
    # - rm -rf / = destrucción del sistema
    # - dd if= = escritura directa a disco
    # - mkfs = formateo de discos
    # - chmod 777 = permisos inseguros
    # - exec = reemplazo del proceso
    local dangerous_patterns='eval[^a-zA-Z]|exec[^a-zA-Z]'
    dangerous_patterns+='|source\s+["\x27]?(https?://|\$)|^\s*\.\s+["\x27]?(https?://|\$)'
    dangerous_patterns+='|curl.*-[oO]\s|wget.*-[oO]\s'
    dangerous_patterns+='|curl.*\|\s*(ba)?sh|wget.*\|\s*(ba)?sh'
    dangerous_patterns+='|rm\s+-[rf]*\s+/[^a-zA-Z]|dd\s+if=|mkfs\.|chmod\s+777'

    if echo "$content" | grep -qE "$dangerous_patterns" 2>/dev/null; then
        log "WARN" "Archivo notifier rechazado: contiene patrones peligrosos"
        return 1
    fi

    # Verificar que tiene las funciones básicas requeridas
    if ! grep -q 'notifier_send\s*()' "$file" 2>/dev/null; then
        log "WARN" "Archivo notifier rechazado: falta función notifier_send()"
        return 1
    fi

    return 0
}

load_config() {
    # Cargar configuración si existe el archivo
    if [ -f "$CONFIG_FILE" ]; then
        if validate_source_file "$CONFIG_FILE" "config"; then
            source "$CONFIG_FILE"
            # Aplicar configuración de notificadores
            apply_notifier_config
            return 0
        else
            log "WARN" "Archivo de configuración no pasó validación de seguridad"
            return 1
        fi
    fi
    return 1
}

apply_notifier_config() {
    # Aplicar configuración guardada de notificadores al array NOTIFIER_ENABLED
    # Las variables NOTIFIER_*_ENABLED se cargan del config file via source
    for code in "${AVAILABLE_NOTIFIERS[@]}"; do
        local var_name="NOTIFIER_${code^^}_ENABLED"
        if [ -n "${!var_name}" ]; then
            NOTIFIER_ENABLED["$code"]="${!var_name}"
        fi
    done
}

config_exists() {
    [ -f "$CONFIG_FILE" ]
}

delete_config() {
    rm -f "$CONFIG_FILE" 2>/dev/null
}

generate_default_config() {
    # Genera autoclean.conf con valores predeterminados del script
    # Esta funcion se llama automaticamente si el archivo no existe
    log "INFO" "${MSG_CONFIG_GENERATING:-Generating default configuration file...}"

    # Detectar idioma del sistema y verificar si está soportado
    local detected_lang="$DEFAULT_LANG"
    local sys_lang="${LANG%%_*}"
    sys_lang="${sys_lang%%.*}"
    if [ -n "$sys_lang" ] && [ -f "${LANG_DIR}/${sys_lang}.lang" ]; then
        detected_lang="$sys_lang"
    fi

    # SECURITY: Crear archivo con permisos restrictivos desde el inicio
    local old_umask=$(umask)
    umask 077
    cat > "$CONFIG_FILE" << EOF
# Configuracion de autoclean - Generado automaticamente
# Fecha: $(date '+%Y-%m-%d %H:%M:%S')

# ============================================================================
# PERFIL / PROFILE
# ============================================================================
# Valores: server, desktop, developer, minimal, custom
# custom = usa los valores STEP_* definidos abajo
SAVED_PROFILE=custom

# ============================================================================
# IDIOMA / LANGUAGE
# ============================================================================
SAVED_LANG=$detected_lang

# ============================================================================
# TEMA / THEME
# ============================================================================
SAVED_THEME=$DEFAULT_THEME

# ============================================================================
# CONFIGURACION DE PASOS / STEPS CONFIGURATION
# ============================================================================
# (Solo aplica cuando SAVED_PROFILE=custom)
# Cambia a 0 para desactivar un paso, 1 para activarlo

STEP_CHECK_CONNECTIVITY=1
STEP_CHECK_DEPENDENCIES=1
STEP_BACKUP_TAR=1
STEP_SNAPSHOT_TIMESHIFT=1
STEP_UPDATE_REPOS=1
STEP_UPGRADE_SYSTEM=1
STEP_UPDATE_FLATPAK=1
STEP_UPDATE_SNAP=0
STEP_CHECK_FIRMWARE=1
STEP_CLEANUP_APT=1
STEP_CLEANUP_KERNELS=1
STEP_CLEANUP_DISK=1
STEP_CLEANUP_DOCKER=0
STEP_CHECK_SMART=1
STEP_CHECK_REBOOT=1
EOF

    local result=$?

    # SECURITY: Restaurar umask original
    umask "$old_umask"

    # Cambiar ownership al usuario que ejecuto sudo (no root)
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        chown "$SUDO_USER:$SUDO_USER" "$CONFIG_FILE" 2>/dev/null
    fi

    if [ $result -eq 0 ]; then
        log "INFO" "${MSG_CONFIG_GENERATED:-Default configuration file generated}: $CONFIG_FILE"
    fi

    return $result
}

# ============================================================================
# PERFILES PREDEFINIDOS
# ============================================================================

apply_profile() {
    local profile="$1"

    case "$profile" in
        server)
            # Servidor: Sin UI, Docker habilitado, SMART activo, sin Flatpak/Snap
            STEP_CHECK_CONNECTIVITY=1
            STEP_CHECK_DEPENDENCIES=1
            STEP_CHECK_SMART=1
            STEP_BACKUP_TAR=1
            STEP_SNAPSHOT_TIMESHIFT=0    # Servidores no usan Timeshift
            STEP_UPDATE_REPOS=1
            STEP_UPGRADE_SYSTEM=1
            STEP_UPDATE_FLATPAK=0        # Servidores no usan Flatpak
            STEP_UPDATE_SNAP=0           # Servidores no usan Snap
            STEP_CHECK_FIRMWARE=1
            STEP_CLEANUP_APT=1
            STEP_CLEANUP_KERNELS=1
            STEP_CLEANUP_DISK=1
            STEP_CLEANUP_DOCKER=1        # Docker habilitado
            STEP_CHECK_REBOOT=1
            NO_MENU=true                 # Sin UI interactiva
            UNATTENDED=true              # Modo desatendido (acepta todo)
            ;;
        desktop)
            # Desktop: UI activa, sin Docker, SMART activo, Flatpak habilitado
            STEP_CHECK_CONNECTIVITY=1
            STEP_CHECK_DEPENDENCIES=1
            STEP_CHECK_SMART=1
            STEP_BACKUP_TAR=1
            STEP_SNAPSHOT_TIMESHIFT=1    # Timeshift recomendado
            STEP_UPDATE_REPOS=1
            STEP_UPGRADE_SYSTEM=1
            STEP_UPDATE_FLATPAK=1        # Flatpak habilitado
            STEP_UPDATE_SNAP=0
            STEP_CHECK_FIRMWARE=1
            STEP_CLEANUP_APT=1
            STEP_CLEANUP_KERNELS=1
            STEP_CLEANUP_DISK=1
            STEP_CLEANUP_DOCKER=0        # Sin Docker
            STEP_CHECK_REBOOT=1
            ;;
        developer)
            # Desarrollador: UI activa, Docker habilitado, sin SMART, todo activo
            STEP_CHECK_CONNECTIVITY=1
            STEP_CHECK_DEPENDENCIES=1
            STEP_CHECK_SMART=0           # Sin SMART (puede ser lento)
            STEP_BACKUP_TAR=1
            STEP_SNAPSHOT_TIMESHIFT=1
            STEP_UPDATE_REPOS=1
            STEP_UPGRADE_SYSTEM=1
            STEP_UPDATE_FLATPAK=1
            STEP_UPDATE_SNAP=1           # Snap habilitado
            STEP_CHECK_FIRMWARE=0        # Sin firmware (evita interrupciones)
            STEP_CLEANUP_APT=1
            STEP_CLEANUP_KERNELS=1
            STEP_CLEANUP_DISK=1
            STEP_CLEANUP_DOCKER=1        # Docker habilitado
            STEP_CHECK_REBOOT=1
            ;;
        minimal)
            # Minimo: Solo actualizaciones esenciales, sin limpieza agresiva
            STEP_CHECK_CONNECTIVITY=1
            STEP_CHECK_DEPENDENCIES=0
            STEP_CHECK_SMART=0
            STEP_BACKUP_TAR=0
            STEP_SNAPSHOT_TIMESHIFT=0
            STEP_UPDATE_REPOS=1
            STEP_UPGRADE_SYSTEM=1
            STEP_UPDATE_FLATPAK=0
            STEP_UPDATE_SNAP=0
            STEP_CHECK_FIRMWARE=0
            STEP_CLEANUP_APT=1
            STEP_CLEANUP_KERNELS=0
            STEP_CLEANUP_DISK=0
            STEP_CLEANUP_DOCKER=0
            STEP_CHECK_REBOOT=1
            NO_MENU=true                 # Sin UI interactiva
            UNATTENDED=true              # Modo desatendido (acepta todo)
            ;;
        custom)
            # Custom: Lee configuracion desde autoclean.conf, sin UI
            # NO modifica las variables STEP_* - usa exactamente lo que esta en el archivo
            if config_exists; then
                load_config
                log "INFO" "${MSG_PROFILE_CUSTOM_LOADED:-Custom profile loaded from configuration file}"
            else
                log "WARN" "${MSG_CONFIG_NOT_FOUND:-Configuration file not found, using defaults}"
            fi
            NO_MENU=true                 # Sin UI interactiva
            UNATTENDED=true              # Modo desatendido (acepta todo)
            ;;
        *)
            echo "Error: ${MSG_PROFILE_UNKNOWN:-Unknown profile}: $profile"
            echo "${MSG_PROFILE_AVAILABLE:-Available profiles}: server, desktop, developer, minimal, custom"
            exit 1
            ;;
    esac

    log "INFO" "$(printf "${MSG_PROFILE_APPLIED:-Profile applied}: %s" "$profile")"
}

# ============================================================================
# FUNCIONES DE IDIOMA (i18n)
# ============================================================================

# Detectar idiomas disponibles dinámicamente desde la carpeta lang/
detect_languages() {
    AVAILABLE_LANGS=()
    LANG_NAMES=()

    # Buscar todos los archivos .lang
    local lang_file
    for lang_file in "$LANG_DIR"/*.lang; do
        [ -f "$lang_file" ] || continue

        # Extraer código del idioma (nombre del archivo sin extensión)
        local code
        code=$(basename "$lang_file" .lang)

        # Extraer nombre del idioma del archivo (LANG_NAME="...")
        local name
        name=$(grep -m1 '^LANG_NAME=' "$lang_file" 2>/dev/null | cut -d'"' -f2)

        # Si no tiene LANG_NAME, usar el código en mayúsculas
        [ -z "$name" ] && name="${code^^}"

        AVAILABLE_LANGS+=("$code")
        LANG_NAMES+=("$name")
    done

    # Si no hay idiomas, usar inglés como fallback
    if [ ${#AVAILABLE_LANGS[@]} -eq 0 ]; then
        AVAILABLE_LANGS=("en")
        LANG_NAMES=("English")
    fi
}

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

    # Cargar archivo de idioma (con validación de seguridad)
    if [ -f "$lang_file" ]; then
        if validate_source_file "$lang_file" "lang"; then
            source "$lang_file"
            CURRENT_LANG="$lang_to_load"
            # Actualizar arrays con textos del idioma cargado
            update_language_arrays
            return 0
        else
            echo "ERROR: Language file failed security validation"
            exit 1
        fi
    else
        # Fallback crítico: usar inglés hardcodeado mínimo
        echo "ERROR: No language files found in $LANG_DIR"
        exit 1
    fi
}

show_language_selector() {
    # Detectar idiomas disponibles dinámicamente
    detect_languages

    local selected=0
    local total=${#AVAILABLE_LANGS[@]}
    local cols=4  # Número de columnas en el grid

    # Encontrar índice del idioma actual
    for i in "${!AVAILABLE_LANGS[@]}"; do
        if [[ "${AVAILABLE_LANGS[$i]}" == "$CURRENT_LANG" ]]; then
            selected=$i
            break
        fi
    done

    # Ocultar cursor
    tput civis 2>/dev/null
    trap 'tput cnorm 2>/dev/null' RETURN

    while true; do
        # Calcular fila y columna actual
        local cur_row=$((selected / cols))
        local cur_col=$((selected % cols))
        local total_rows=$(( (total + cols - 1) / cols ))

        clear
        print_box_top
        print_box_center "${BOLD}SELECT LANGUAGE / SELECCIONAR IDIOMA${BOX_NC}"
        print_box_sep
        print_box_line ""

        # Mostrar idiomas en grid de 4 columnas
        # Cada celda: 18 chars (prefix[1] + bracket[1] + check[1] + bracket[1] + space[1] + name[13])
        for row in $(seq 0 $((total_rows - 1))); do
            local line=""
            for col in $(seq 0 $((cols - 1))); do
                local idx=$((row * cols + col))
                if [ $idx -lt $total ]; then
                    # Truncar/pad nombre a exactamente 13 chars
                    local name
                    name=$(printf "%-13.13s" "${LANG_NAMES[$idx]}")

                    # Determinar prefijo y estado
                    local prefix=" "
                    local check=" "
                    [ "${AVAILABLE_LANGS[$idx]}" = "$CURRENT_LANG" ] && check="x"
                    [ $idx -eq $selected ] && prefix=">"

                    # Construir celda con formato consistente (18 chars)
                    if [ $idx -eq $selected ]; then
                        # Seleccionado: todo en cyan brillante
                        line+="${BRIGHT_CYAN}${prefix}[${check}]${BOX_NC} ${BRIGHT_CYAN}${name}${BOX_NC}"
                    elif [ "${AVAILABLE_LANGS[$idx]}" = "$CURRENT_LANG" ]; then
                        # Idioma activo: [x] en verde
                        line+=" ${GREEN}[x]${BOX_NC} ${name}"
                    else
                        # Inactivo: [ ] en dim
                        line+=" ${DIM}[ ]${BOX_NC} ${name}"
                    fi
                else
                    # Celda vacía: 18 espacios
                    line+="                  "
                fi
            done
            print_box_line "$line"
        done

        print_box_line ""
        print_box_sep
        print_box_center "${DIM}${MENU_LANG_HINT:-Add .lang files to plugins/lang/ folder}${BOX_NC}"
        print_box_sep
        print_box_center "${STATUS_INFO}[ENTER]${BOX_NC} ${MENU_SELECT:-Select}  ${STATUS_INFO}[ESC]${BOX_NC} ${MENU_BACK:-Back}"
        print_box_bottom

        # Leer tecla
        local key=""
        IFS= read -rsn1 key

        # Detectar secuencias de escape (flechas o ESC solo)
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            case "$key" in
                '[A') # Arriba: misma columna, fila anterior
                    if [ $cur_row -gt 0 ]; then
                        ((selected-=cols))
                    else
                        # Ir a la última fila de la columna
                        local last_row=$(( (total - 1) / cols ))
                        local new_idx=$((last_row * cols + cur_col))
                        [ $new_idx -ge $total ] && new_idx=$((new_idx - cols))
                        [ $new_idx -ge 0 ] && selected=$new_idx
                    fi
                    ;;
                '[B') # Abajo: misma columna, fila siguiente
                    local new_idx=$((selected + cols))
                    if [ $new_idx -lt $total ]; then
                        selected=$new_idx
                    else
                        # Volver a la primera fila de la columna
                        selected=$cur_col
                    fi
                    ;;
                '[C') # Derecha: columna siguiente
                    if [ $cur_col -lt $((cols - 1)) ]; then
                        local new_idx=$((selected + 1))
                        [ $new_idx -lt $total ] && selected=$new_idx
                    else
                        # Ir al inicio de la fila
                        selected=$((cur_row * cols))
                    fi
                    ;;
                '[D') # Izquierda: columna anterior
                    if [ $cur_col -gt 0 ]; then
                        ((selected--))
                    else
                        # Ir al final de la fila
                        local new_idx=$((cur_row * cols + cols - 1))
                        [ $new_idx -ge $total ] && new_idx=$((total - 1))
                        selected=$new_idx
                    fi
                    ;;
                '') # ESC solo
                    tput cnorm 2>/dev/null
                    return
                    ;;
            esac
        elif [[ "$key" == "" ]]; then
            # ENTER - seleccionar idioma
            load_language "${AVAILABLE_LANGS[$selected]}"
            tput cnorm 2>/dev/null
            return
        fi
    done
}

# ============================================================================
# SISTEMA DE TEMAS
# ============================================================================

# Detectar temas disponibles dinámicamente desde la carpeta themes/
detect_themes() {
    AVAILABLE_THEMES=()
    THEME_NAMES=()

    # Buscar todos los archivos .theme
    local theme_file
    for theme_file in "$THEME_DIR"/*.theme; do
        [ -f "$theme_file" ] || continue

        # Extraer código del tema (nombre del archivo sin extensión)
        local code
        code=$(basename "$theme_file" .theme)

        # Extraer nombre del tema del archivo (THEME_NAME="...")
        local name
        name=$(grep -m1 '^THEME_NAME=' "$theme_file" 2>/dev/null | cut -d'"' -f2)

        # Si no tiene THEME_NAME, usar el código con primera letra mayúscula
        [ -z "$name" ] && name="${code^}"

        AVAILABLE_THEMES+=("$code")
        THEME_NAMES+=("$name")
    done

    # Si no hay temas, usar default como fallback
    if [ ${#AVAILABLE_THEMES[@]} -eq 0 ]; then
        AVAILABLE_THEMES=("default")
        THEME_NAMES=("Default")
    fi
}

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

    # Cargar archivo de tema (con validación de seguridad)
    if [ -f "$theme_file" ]; then
        if validate_source_file "$theme_file" "theme"; then
            # Limpiar variables de tema anterior (especialmente las opcionales)
            unset T_BOX_BG T_BOX_NC
            unset T_RED T_GREEN T_YELLOW T_BLUE T_CYAN T_MAGENTA
            unset T_BRIGHT_GREEN T_BRIGHT_YELLOW T_BRIGHT_CYAN T_DIM
            unset T_BOX_BORDER T_BOX_TITLE T_TEXT_NORMAL T_TEXT_SELECTED
            unset T_TEXT_ACTIVE T_TEXT_INACTIVE T_STATUS_OK T_STATUS_ERROR
            unset T_STATUS_WARN T_STATUS_INFO T_STEP_HEADER

            source "$theme_file"
            CURRENT_THEME="$theme_to_load"
            apply_theme
        else
            log "WARN" "Theme file failed security validation, using defaults"
        fi
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
    BOX_BG="${T_BOX_BG:-}"             # Fondo de caja (vacio por defecto, azul para norton)
    BOX_NC="${T_BOX_NC:-$NC}"          # Reset dentro de cajas (preserva fondo en norton)
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
    # Detectar temas disponibles dinámicamente
    detect_themes

    local selected=0
    local total=${#AVAILABLE_THEMES[@]}
    local cols=4  # Número de columnas en el grid

    # Encontrar índice del tema actual
    for i in "${!AVAILABLE_THEMES[@]}"; do
        if [[ "${AVAILABLE_THEMES[$i]}" == "$CURRENT_THEME" ]]; then
            selected=$i
            break
        fi
    done

    # Ocultar cursor
    tput civis 2>/dev/null
    trap 'tput cnorm 2>/dev/null' RETURN

    while true; do
        # Calcular fila y columna actual
        local cur_row=$((selected / cols))
        local cur_col=$((selected % cols))
        local total_rows=$(( (total + cols - 1) / cols ))

        clear
        print_box_top
        print_box_center "${BOLD}${MENU_THEME_TITLE:-SELECT THEME / SELECCIONAR TEMA}${BOX_NC}"
        print_box_sep
        print_box_line ""

        # Mostrar temas en grid de 4 columnas
        # Cada celda: 18 chars (prefix[1] + bracket[1] + check[1] + bracket[1] + space[1] + name[13])
        for row in $(seq 0 $((total_rows - 1))); do
            local line=""
            for col in $(seq 0 $((cols - 1))); do
                local idx=$((row * cols + col))
                if [ $idx -lt $total ]; then
                    # Truncar/pad nombre a exactamente 13 chars
                    local name
                    name=$(printf "%-13.13s" "${THEME_NAMES[$idx]}")

                    # Determinar prefijo y estado
                    local prefix=" "
                    local check=" "
                    [ "${AVAILABLE_THEMES[$idx]}" = "$CURRENT_THEME" ] && check="x"
                    [ $idx -eq $selected ] && prefix=">"

                    # Construir celda con formato consistente (18 chars)
                    if [ $idx -eq $selected ]; then
                        # Seleccionado: todo en cyan brillante
                        line+="${BRIGHT_CYAN}${prefix}[${check}]${BOX_NC} ${BRIGHT_CYAN}${name}${BOX_NC}"
                    elif [ "${AVAILABLE_THEMES[$idx]}" = "$CURRENT_THEME" ]; then
                        # Tema activo: [x] en verde
                        line+=" ${GREEN}[x]${BOX_NC} ${name}"
                    else
                        # Inactivo: [ ] en dim
                        line+=" ${DIM}[ ]${BOX_NC} ${name}"
                    fi
                else
                    # Celda vacía: 18 espacios
                    line+="                  "
                fi
            done
            print_box_line "$line"
        done

        print_box_line ""
        print_box_sep
        print_box_center "${DIM}${MENU_THEME_HINT:-Add .theme files to plugins/themes/ folder}${BOX_NC}"
        print_box_sep
        print_box_center "${STATUS_INFO}[ENTER]${BOX_NC} ${MENU_SELECT:-Select}  ${STATUS_INFO}[ESC]${BOX_NC} ${MENU_BACK:-Back}"
        print_box_bottom

        # Leer tecla
        local key=""
        IFS= read -rsn1 key

        # Detectar secuencias de escape (flechas o ESC solo)
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            case "$key" in
                '[A') # Arriba: misma columna, fila anterior
                    if [ $cur_row -gt 0 ]; then
                        ((selected-=cols))
                    else
                        # Ir a la última fila de la columna
                        local last_row=$(( (total - 1) / cols ))
                        local new_idx=$((last_row * cols + cur_col))
                        [ $new_idx -ge $total ] && new_idx=$((new_idx - cols))
                        [ $new_idx -ge 0 ] && selected=$new_idx
                    fi
                    ;;
                '[B') # Abajo: misma columna, fila siguiente
                    local new_idx=$((selected + cols))
                    if [ $new_idx -lt $total ]; then
                        selected=$new_idx
                    else
                        # Volver a la primera fila de la columna
                        selected=$cur_col
                    fi
                    ;;
                '[C') # Derecha: columna siguiente
                    if [ $cur_col -lt $((cols - 1)) ]; then
                        local new_idx=$((selected + 1))
                        [ $new_idx -lt $total ] && selected=$new_idx
                    else
                        # Ir al inicio de la fila
                        selected=$((cur_row * cols))
                    fi
                    ;;
                '[D') # Izquierda: columna anterior
                    if [ $cur_col -gt 0 ]; then
                        ((selected--))
                    else
                        # Ir al final de la fila
                        local new_idx=$((cur_row * cols + cols - 1))
                        [ $new_idx -ge $total ] && new_idx=$((total - 1))
                        selected=$new_idx
                    fi
                    ;;
                '') # ESC solo
                    tput cnorm 2>/dev/null
                    return
                    ;;
            esac
        elif [[ "$key" == "" ]]; then
            # ENTER - seleccionar tema
            load_theme "${AVAILABLE_THEMES[$selected]}"
            tput cnorm 2>/dev/null
            return
        fi
    done
}

# ============================================================================
# SISTEMA DE NOTIFICADORES (Plugins)
# ============================================================================

detect_notifiers() {
    AVAILABLE_NOTIFIERS=()
    NOTIFIER_NAMES=()
    NOTIFIER_DESCRIPTIONS=()

    # Verificar que existe el directorio
    [ ! -d "$NOTIFIER_DIR" ] && return

    # Buscar todos los archivos .notifier
    local notifier_file
    for notifier_file in "$NOTIFIER_DIR"/*.notifier; do
        [ -f "$notifier_file" ] || continue

        # Extraer código del notificador (nombre del archivo sin extensión)
        local code
        code=$(basename "$notifier_file" .notifier)

        # Extraer metadata del archivo
        local name desc
        name=$(grep -m1 '^NOTIFIER_NAME=' "$notifier_file" 2>/dev/null | cut -d'"' -f2)
        desc=$(grep -m1 '^NOTIFIER_DESCRIPTION=' "$notifier_file" 2>/dev/null | cut -d'"' -f2)

        # Si no tiene NOTIFIER_NAME, usar el código con primera letra mayúscula
        [ -z "$name" ] && name="${code^}"
        [ -z "$desc" ] && desc="$name notifier"

        # Intentar obtener descripción traducida (NOTIF_DESC_TELEGRAM, NOTIF_DESC_DESKTOP, etc.)
        local i18n_key="NOTIF_DESC_${code^^}"
        [ -n "${!i18n_key}" ] && desc="${!i18n_key}"

        AVAILABLE_NOTIFIERS+=("$code")
        NOTIFIER_NAMES+=("$name")
        NOTIFIER_DESCRIPTIONS+=("$desc")
    done
}

load_notifier() {
    local notifier_code="$1"
    local notifier_file="${NOTIFIER_DIR}/${notifier_code}.notifier"

    # Verificar que el archivo existe
    [ ! -f "$notifier_file" ] && return 1

    # Cargar archivo de notificador (con validación de seguridad para notifiers)
    if validate_notifier_file "$notifier_file"; then
        source "$notifier_file"
        NOTIFIER_LOADED["$notifier_code"]=1

        # Verificar si tiene las funciones requeridas
        if type -t notifier_send &>/dev/null; then
            return 0
        else
            log "WARN" "Notifier $notifier_code missing required function notifier_send()"
            unset NOTIFIER_LOADED["$notifier_code"]
            return 1
        fi
    else
        log "WARN" "Notifier file $notifier_code failed security validation"
        return 1
    fi
}

load_all_enabled_notifiers() {
    # Cargar todos los notificadores habilitados
    for code in "${AVAILABLE_NOTIFIERS[@]}"; do
        if [ "${NOTIFIER_ENABLED[$code]}" = "1" ]; then
            load_notifier "$code"
        fi
    done
}

send_notification() {
    local title="$1"
    local message="$2"
    local severity="${3:-info}"

    # No enviar si estamos en dry-run (a menos que --notify este activo)
    if [ "$DRY_RUN" = true ] && [ "$NOTIFY_ON_DRY_RUN" != true ]; then
        return 0
    fi

    # Agregar prefijo [DRY-RUN] si estamos en modo simulacion
    if [ "$DRY_RUN" = true ]; then
        title="[DRY-RUN] $title"
    fi

    local any_sent=0

    # Enviar a todos los notificadores habilitados
    for code in "${AVAILABLE_NOTIFIERS[@]}"; do
        if [ "${NOTIFIER_ENABLED[$code]}" = "1" ]; then
            # Cargar el notificador para tener sus funciones disponibles
            if load_notifier "$code"; then
                # Verificar que está configurado
                if type -t notifier_is_configured &>/dev/null && notifier_is_configured; then
                    if notifier_send "$title" "$message" "$severity" 2>/dev/null; then
                        log "INFO" "Notification sent via $code"
                        any_sent=1
                    else
                        log "WARN" "Failed to send notification via $code"
                    fi
                else
                    log "DEBUG" "Notifier $code not configured, skipping"
                fi
            fi
        fi
    done

    return 0
}

send_critical_notification() {
    # Enviar notificación crítica inmediata (para errores graves)
    local title="$1"
    local message="$2"
    send_notification "$title" "$message" "critical"
}

build_summary_notification() {
    # Construir el mensaje de resumen detallado para la notificación final
    local hostname
    hostname=$(hostname 2>/dev/null || echo "unknown")

    local duration=$(($(date +%s) - START_TIME))
    local mins=$((duration / 60))
    local secs=$((duration % 60))

    # Calcular espacio liberado
    local space_after_root space_freed_root
    space_after_root=$(df / --output=used 2>/dev/null | tail -1 | awk '{print $1}')
    space_freed_root=$(( (SPACE_BEFORE_ROOT - space_after_root) / 1024 ))
    [ $space_freed_root -lt 0 ] && space_freed_root=0

    # Estado general
    local status_emoji status_text
    if [ "$REBOOT_NEEDED" = true ]; then
        status_emoji="⚠️"
        status_text="${MSG_REBOOT_REQUIRED:-Reboot Required}"
    else
        status_emoji="✅"
        status_text="${MSG_COMPLETED:-Completed}"
    fi

    # Construir lista de pasos
    local steps_summary=""
    local step_statuses=(
        "$STAT_CONNECTIVITY"
        "$STAT_DEPENDENCIES"
        "$STAT_SMART"
        "$STAT_BACKUP_TAR"
        "$STAT_SNAPSHOT"
        "$STAT_REPO"
        "$STAT_UPGRADE"
        "$STAT_FLATPAK"
        "$STAT_SNAP"
        "$STAT_FIRMWARE"
        "$STAT_CLEAN_APT"
        "$STAT_CLEAN_KERNEL"
        "$STAT_CLEAN_DISK"
        "$STAT_DOCKER"
        "$STAT_REBOOT"
    )

    local i=0
    for step_name in "${MENU_STEP_NAMES[@]}"; do
        local stat="${step_statuses[$i]}"
        local icon="⏭️"
        case "$stat" in
            "$ICON_OK") icon="✓" ;;
            "$ICON_FAIL") icon="✗" ;;
            "$ICON_WARN") icon="⚠️" ;;
            "$ICON_SKIP"|"[--]") icon="-" ;;
        esac
        steps_summary+="$icon ${step_name}
"
        ((i++))
    done

    # Construir mensaje completo
    cat << EOF
🖥️ AUTOCLEAN - ${hostname}
━━━━━━━━━━━━━━━━━━━━━━
${status_emoji} Status: ${status_text}
⏱️ Duration: ${mins}m ${secs}s
💾 Space freed: ${space_freed_root} MB

📋 STEPS:
${steps_summary}
📁 Log: ${LOG_FILE:-N/A}
EOF
}

show_notification_menu() {
    # Detectar notificadores disponibles
    detect_notifiers

    local selected=0
    local total=${#AVAILABLE_NOTIFIERS[@]}

    # Si no hay notificadores, mostrar mensaje
    if [ $total -eq 0 ]; then
        clear
        print_box_top
        print_box_center "${BOLD}${MENU_NOTIF_TITLE:-NOTIFICATIONS}${BOX_NC}"
        print_box_sep
        print_box_center "${YELLOW}${MENU_NOTIF_NONE:-No notifiers found}${BOX_NC}"
        print_box_line ""
        print_box_line "${MENU_NOTIF_INSTALL:-Install notifiers in:}"
        print_box_line "  ${CYAN}${NOTIFIER_DIR}${BOX_NC}"
        print_box_sep
        print_box_center "${DIM}${MENU_PRESS_ANY:-Press any key to continue}${BOX_NC}"
        print_box_bottom
        read -rsn1
        return
    fi

    # Ocultar cursor
    tput civis 2>/dev/null
    trap 'tput cnorm 2>/dev/null' RETURN

    while true; do
        clear
        print_box_top
        print_box_center "${BOLD}${MENU_NOTIF_TITLE:-NOTIFICATIONS}${BOX_NC}"
        print_box_sep
        print_box_line "${MENU_NOTIF_HELP:-Toggle notifications, configure, or test}"
        print_box_sep

        # Mostrar lista de notificadores
        local i=0
        for code in "${AVAILABLE_NOTIFIERS[@]}"; do
            local name="${NOTIFIER_NAMES[$i]}"
            local enabled="${NOTIFIER_ENABLED[$code]:-0}"
            local status_icon status_color

            if [ "$enabled" = "1" ]; then
                status_icon="[x]"
                status_color="$GREEN"
            else
                status_icon="[ ]"
                status_color="$DIM"
            fi

            local prefix=" "
            [ $i -eq $selected ] && prefix=">"

            if [ $i -eq $selected ]; then
                print_box_line "${BRIGHT_CYAN}${prefix}${status_icon} ${name}${BOX_NC}"
            else
                print_box_line " ${status_color}${status_icon}${BOX_NC} ${name}"
            fi
            ((i++))
        done

        print_box_sep
        local current_code="${AVAILABLE_NOTIFIERS[$selected]}"
        local current_desc="${NOTIFIER_DESCRIPTIONS[$selected]}"
        print_box_line "${CYAN}>${BOX_NC} ${current_desc:0:68}"
        print_box_sep
        print_box_line "${CYAN}[SPACE]${BOX_NC} ${MENU_NOTIF_TOGGLE:-Toggle} ${CYAN}[C]${BOX_NC} ${MENU_NOTIF_CONFIG:-Config} ${CYAN}[T]${BOX_NC} ${MENU_NOTIF_TEST:-Test} ${CYAN}[H]${BOX_NC} ${MENU_NOTIF_HELP_KEY:-Help} ${CYAN}[S]${BOX_NC} ${MENU_SAVE:-Save} ${CYAN}[ESC]${BOX_NC} ${MENU_BACK:-Back}"
        print_box_bottom

        # Leer tecla
        local key=""
        IFS= read -rsn1 key

        # Detectar secuencias de escape
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            case "$key" in
                '[A') # Arriba
                    ((selected--))
                    [ $selected -lt 0 ] && selected=$((total - 1))
                    ;;
                '[B') # Abajo
                    ((selected++))
                    [ $selected -ge $total ] && selected=0
                    ;;
                '') # ESC solo - volver
                    tput cnorm 2>/dev/null
                    return
                    ;;
            esac
        elif [[ "$key" == " " ]]; then
            # Toggle habilitado/deshabilitado
            local code="${AVAILABLE_NOTIFIERS[$selected]}"
            if [ "${NOTIFIER_ENABLED[$code]}" = "1" ]; then
                NOTIFIER_ENABLED["$code"]=0
            else
                NOTIFIER_ENABLED["$code"]=1
            fi
        elif [[ "$key" == "c" || "$key" == "C" ]]; then
            # Configurar notificador
            show_notifier_config "${AVAILABLE_NOTIFIERS[$selected]}"
        elif [[ "$key" == "t" || "$key" == "T" ]]; then
            # Probar notificador
            test_notifier "${AVAILABLE_NOTIFIERS[$selected]}"
        elif [[ "$key" == "h" || "$key" == "H" ]]; then
            # Mostrar ayuda
            show_notifier_help "${AVAILABLE_NOTIFIERS[$selected]}"
        elif [[ "$key" == "s" || "$key" == "S" ]]; then
            # Guardar configuración
            save_config
            # Mostrar confirmación breve
            clear
            print_box_top
            print_box_center "${GREEN}${MENU_CONFIG_SAVED:-Configuration saved!}${BOX_NC}"
            print_box_bottom
            sleep 1
        elif [[ "$key" == "q" || "$key" == "Q" ]]; then
            tput cnorm 2>/dev/null
            return
        fi
    done
}

show_notifier_config() {
    local code="$1"
    local notifier_file="${NOTIFIER_DIR}/${code}.notifier"

    # Cargar el notificador para obtener NOTIFIER_FIELDS
    [ ! -f "$notifier_file" ] && return
    source "$notifier_file" 2>/dev/null

    # Verificar si tiene campos de configuración
    if [ ${#NOTIFIER_FIELDS[@]} -eq 0 ]; then
        clear
        print_box_top
        print_box_center "${BOLD}${MENU_CONFIG:-CONFIGURE}: ${NOTIFIER_NAME}${BOX_NC}"
        print_box_sep
        print_box_center "${GREEN}${MENU_NO_CONFIG:-No configuration needed}${BOX_NC}"
        print_box_sep
        print_box_center "${DIM}${MENU_PRESS_ANY:-Press any key to continue}${BOX_NC}"
        print_box_bottom
        read -rsn1
        return
    fi

    # Convertir NOTIFIER_FIELDS a arrays indexados para acceso por número
    local -a field_vars=()
    local -a field_labels=()
    for var_name in "${!NOTIFIER_FIELDS[@]}"; do
        field_vars+=("$var_name")
        field_labels+=("${NOTIFIER_FIELDS[$var_name]}")
    done
    local num_fields=${#field_vars[@]}
    local current_index=0

    tput civis 2>/dev/null

    while true; do
        clear
        print_box_top
        print_box_center "${BOLD}${MENU_CONFIG:-CONFIGURE}: ${NOTIFIER_NAME}${BOX_NC}"
        print_box_sep
        print_box_line ""

        # Mostrar campos en 1 columna con navegación por flechas
        local i
        for ((i=0; i<num_fields; i++)); do
            local var_name="${field_vars[$i]}"
            local label="${field_labels[$i]}"
            local current_value="${!var_name}"
            local display_value="${current_value:-not set}"
            [[ "$var_name" == *"TOKEN"* || "$var_name" == *"PASSWORD"* || "$var_name" == *"KEY"* || "$var_name" == *"AUTH"* ]] && [ -n "$current_value" ] && display_value="${current_value:0:10}..."
            local status_color="${RED}"; [ -n "$current_value" ] && status_color="${GREEN}"

            # Mostrar indicador de selección
            if [ $i -eq $current_index ]; then
                print_box_line "  ${CYAN}▶${BOX_NC} ${BOLD}${label}${BOX_NC}"
                print_box_line "      ${status_color}▶${BOX_NC} ${display_value}"
            else
                print_box_line "    ${DIM}${label}${BOX_NC}"
                print_box_line "      ${status_color}▶${BOX_NC} ${display_value}"
            fi
            print_box_line ""
        done

        print_box_sep
        print_box_line "  ${CYAN}[↑/↓]${BOX_NC} ${MENU_NAV_SELECT:-Navigate}    ${CYAN}[ENTER]${BOX_NC} ${MENU_EDIT_FIELD:-Edit}    ${CYAN}[S]${BOX_NC} ${MENU_SAVE:-Save}    ${CYAN}[Q]${BOX_NC} ${MENU_BACK:-Back}"
        print_box_bottom

        # Leer tecla
        local key=""
        IFS= read -rsn1 key

        # Detectar secuencias de escape (flechas)
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            case "$key" in
                '[A') # Arriba
                    if [ $current_index -gt 0 ]; then
                        ((current_index--))
                    else
                        current_index=$((num_fields - 1))
                    fi
                    ;;
                '[B') # Abajo
                    if [ $current_index -lt $((num_fields - 1)) ]; then
                        ((current_index++))
                    else
                        current_index=0
                    fi
                    ;;
            esac
        elif [[ "$key" == "" ]]; then
            # ENTER - Editar campo seleccionado
            tput cnorm 2>/dev/null
            local var_name="${field_vars[$current_index]}"
            local label="${field_labels[$current_index]}"

            echo ""
            print_box_top
            print_box_center "${BOLD}${label}${BOX_NC}"
            print_box_bottom
            echo ""
            printf "  ${MENU_ENTER_VALUE:-Enter value}: "
            local new_value
            read -r new_value

            if [ -n "$new_value" ]; then
                export "$var_name"="$new_value"
                # Advertencia de seguridad para URLs HTTP (sin cifrado)
                if [[ "$var_name" == *"URL"* || "$var_name" == *"SERVER"* ]] && [[ "$new_value" == http://* ]]; then
                    echo ""
                    print_box_top
                    print_box_center "${YELLOW}${ICON_WARN:-⚠}  ${MENU_HTTP_WARNING:-WARNING: HTTP is not secure}${BOX_NC}"
                    print_box_line "  ${DIM}${MENU_HTTP_WARNING_DESC:-Credentials may be transmitted in plaintext.}${BOX_NC}"
                    print_box_line "  ${DIM}${MENU_HTTP_WARNING_HINT:-Consider using HTTPS instead.}${BOX_NC}"
                    print_box_bottom
                    sleep 2
                fi
            fi
            tput civis 2>/dev/null
        elif [[ "$key" == "s" || "$key" == "S" ]]; then
            # Guardar configuración
            save_config
            clear
            print_box_top
            print_box_center "${GREEN}${MENU_CONFIG_SAVED:-Configuration saved!}${BOX_NC}"
            print_box_bottom
            sleep 1
        elif [[ "$key" == "q" || "$key" == "Q" ]]; then
            break
        fi
    done

    tput cnorm 2>/dev/null
}

show_notifier_help() {
    local code="$1"
    local notifier_file="${NOTIFIER_DIR}/${code}.notifier"

    # Cargar el notificador
    [ ! -f "$notifier_file" ] && return
    source "$notifier_file" 2>/dev/null

    clear

    # Verificar si tiene función de ayuda
    if type -t notifier_help &>/dev/null; then
        notifier_help
    else
        print_box_top
        print_box_center "${BOLD}${MENU_HELP:-HELP}: ${NOTIFIER_NAME}${BOX_NC}"
        print_box_sep
        print_box_center "${DIM}${MENU_NO_HELP:-No help available for this notifier}${BOX_NC}"
        print_box_bottom
    fi

    echo ""
    printf "${DIM}${MENU_PRESS_ANY:-Press any key to continue}${NC}"
    read -rsn1
}

test_notifier() {
    local code="$1"

    clear
    print_box_top
    print_box_center "${BOLD}${MENU_TEST:-TEST}: ${code}${BOX_NC}"
    print_box_sep

    # Cargar el notificador
    if ! load_notifier "$code"; then
        print_box_center "${RED}${MENU_LOAD_FAILED:-Failed to load notifier}${BOX_NC}"
        print_box_bottom
        read -rsn1
        return
    fi

    # Verificar dependencias
    print_box_line "${MENU_CHECKING_DEPS:-Checking dependencies...}"
    if type -t notifier_check_deps &>/dev/null && ! notifier_check_deps; then
        print_box_line "${RED}${MENU_DEPS_MISSING:-Dependencies missing}${BOX_NC}"
        print_box_line "${MENU_DEPS_INSTALL:-Please install:} ${NOTIFIER_DEPS:-N/A}"
        print_box_bottom
        read -rsn1
        return
    fi
    print_box_line "  ${GREEN}${ICON_OK}${BOX_NC} ${MENU_DEPS_OK:-Dependencies OK}"

    # Verificar configuración
    print_box_line "${MENU_CHECKING_CONFIG:-Checking configuration...}"
    if type -t notifier_is_configured &>/dev/null && ! notifier_is_configured; then
        print_box_line "${YELLOW}${MENU_NOT_CONFIGURED:-Not configured}${BOX_NC}"
        print_box_line "${MENU_CONFIG_FIRST:-Please configure this notifier first}"
        print_box_bottom
        read -rsn1
        return
    fi
    print_box_line "  ${GREEN}${ICON_OK}${BOX_NC} ${MENU_CONFIG_OK:-Configuration OK}"

    # Enviar notificación de prueba
    print_box_line "${MENU_SENDING_TEST:-Sending test notification...}"
    if type -t notifier_test &>/dev/null && notifier_test; then
        print_box_line "  ${GREEN}${ICON_OK}${BOX_NC} ${MENU_TEST_SUCCESS:-Test notification sent!}"
    else
        print_box_line "  ${RED}${ICON_FAIL}${BOX_NC} ${MENU_TEST_FAILED:-Failed to send test notification}"
    fi

    print_box_sep
    print_box_center "${DIM}${MENU_PRESS_ANY:-Press any key to continue}${BOX_NC}"
    print_box_bottom
    read -rsn1
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
# Usa ESC[K (clear to EOL) + posicionamiento absoluto para garantizar alineación
print_box_line() {
    local content="$1"

    # Imprimir borde izquierdo + espacio (con fondo si está definido)
    printf '%b' "${BOX_BORDER:-$BLUE}║${NC}${BOX_BG} "

    # Imprimir contenido
    printf '%b' "$content"

    # Limpiar hasta el final de línea (respeta color de fondo actual para Norton)
    printf '\033[K'

    # Posicionar cursor en columna fija para borde derecho (independiente de Unicode)
    printf '\033[%dG' "$BOX_WIDTH"
    printf '%b\033[K\n' "${BOX_BORDER:-$BLUE}║${NC}"
}

# Imprimir línea centrada - MÉTODO ULTRA-ROBUSTO
# Usa ESC[K (clear to EOL) + posicionamiento absoluto para garantizar alineación
print_box_center() {
    local content="$1"

    # Calcular longitud visible para centrado (solo para padding izquierdo)
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
    printf '%b' "${BOX_BORDER:-$BLUE}║${NC}${BOX_BG}"
    printf '%s' "$left_spaces"
    printf '%b' "$content"

    # Limpiar hasta el final de línea (respeta color de fondo actual)
    printf '\033[K'

    # Posicionar cursor en columna fija para borde derecho
    printf '\033[%dG' "$BOX_WIDTH"
    printf '%b\033[K\n' "${BOX_BORDER:-$BLUE}║${NC}"
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
        "success")  echo "${GREEN}${ICON_SUM_OK}${BOX_NC}" ;;
        "error")    echo "${RED}${ICON_SUM_FAIL}${BOX_NC}" ;;
        "warning")  echo "${YELLOW}${ICON_SUM_WARN}${BOX_NC}" ;;
        "skipped")  echo "${YELLOW}${ICON_SUM_SKIP}${BOX_NC}" ;;
        "running")  echo "${CYAN}${ICON_SUM_RUN}${BOX_NC}" ;;
        *)          echo "${DIM}${ICON_SUM_PEND}${BOX_NC}" ;;
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
    # Usa find para manejo seguro de nombres de archivo
    find "$LOG_DIR" -maxdepth 1 -name "sys-update-*.log" -type f -printf '%T@ %p\n' 2>/dev/null | \
        sort -rn | tail -n +6 | cut -d' ' -f2- | xargs -r -d'\n' rm -f
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

    # SECURITY: Usar bash -c en lugar de eval para evitar expansión doble
    # Nota: safe_run solo debe usarse con comandos construidos internamente,
    # NUNCA con input de usuario sin sanitizar
    if bash -c "$cmd" >> "$LOG_FILE" 2>&1; then
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
    # SECURITY: Cerrar el file descriptor del flock y eliminar lock file
    exec 200>&- 2>/dev/null  # Cerrar fd 200 (libera el flock automáticamente)
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

    # SECURITY: Validar /etc/os-release antes de hacer source
    # Solo permitir asignaciones de variables simples (VAR=value o VAR="value")
    if grep -qE '(\$\(|`|\||;|&&|\|\|)' /etc/os-release 2>/dev/null; then
        die "ERROR: /etc/os-release contains unsafe content"
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
    # SECURITY: Usar flock para bloqueo atómico (evita race conditions TOCTOU)
    # El file descriptor 200 se mantiene abierto durante toda la ejecución
    exec 200>"$LOCK_FILE"
    if ! flock -n 200; then
        # No pudimos obtener el lock, verificar quién lo tiene
        local pid
        pid=$(cat "$LOCK_FILE" 2>/dev/null)
        echo -e "${RED}[XX] Ya hay una instancia del script corriendo (PID: ${pid:-desconocido})${NC}"
        exit 1
    fi
    # Escribir nuestro PID al archivo (para información, el lock real es flock)
    echo $$ >&200

    # Verificación extra de locks de APT
    if fuser /var/lib/dpkg/lock* /var/lib/apt/lists/lock* 2>/dev/null | grep -q .; then
        echo -e "${RED}[XX] APT esta ocupado. Cierra Synaptic/Discover e intenta de nuevo.${NC}"
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
    [ "$STEP_CLEANUP_DOCKER" = 1 ] && ((TOTAL_STEPS++))
    [ "$STEP_CHECK_SMART" = 1 ] && ((TOTAL_STEPS++))
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
    print_box_line "${MENU_TOTAL}: ${GREEN}${TOTAL_STEPS}${NC}/15 ${MENU_STEPS}    ${MENU_EST_TIME}: ${CYAN}~$((TOTAL_STEPS / 2 + 1)) ${MENU_MIN}${NC}"
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
        print_box_center "${BOLD}${MENU_TITLE}${BOX_NC}"
        print_box_sep
        print_box_center "${DISTRO_NAME} | ${DISTRO_FAMILY^} (${DISTRO_CODENAME:-N/A})"
        print_box_sep
        print_box_line "${BOLD}${MENU_STEPS_TITLE}${BOX_NC} ${DIM}${MENU_STEPS_HELP}${BOX_NC}"

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
                        line+="${BRIGHT_CYAN}${prefix}[${check}]${name}${BOX_NC}"
                    elif [ "$var_value" = "1" ]; then
                        # Activo: [x] en verde
                        line+=" ${GREEN}[x]${BOX_NC}${name}"
                    else
                        # Inactivo: [ ] en dim
                        line+=" ${DIM}[ ]${BOX_NC}${name}"
                    fi
                else
                    # Celda vacía: 15 espacios
                    line+="               "
                fi
            done
            print_box_line "$line"
        done

        print_box_sep
        print_box_line "${CYAN}>${BOX_NC} ${MENU_STEP_DESCRIPTIONS[$current_index]:0:68}"
        print_box_sep
        print_box_line "${MENU_SELECTED}: ${GREEN}${active_count}${BOX_NC}/${total_items}    ${MENU_PROFILE}: $(config_exists && echo "${GREEN}${MENU_PROFILE_SAVED}${BOX_NC}" || echo "${DIM}${MENU_PROFILE_UNSAVED}${BOX_NC}")"
        print_box_sep
        print_box_center "${CYAN}[ENTER]${BOX_NC} ${MENU_CTRL_ENTER} ${CYAN}[G]${BOX_NC} ${MENU_CTRL_SAVE} ${CYAN}[L]${BOX_NC} ${MENU_CTRL_LANG} ${CYAN}[T]${BOX_NC} ${MENU_CTRL_THEME:-Theme} ${CYAN}[O]${BOX_NC} ${MENU_CTRL_NOTIF:-Notif} ${CYAN}[Q]${BOX_NC} ${MENU_CTRL_QUIT}"
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
            declare -n ref="$var_name"
            [ "$ref" = "1" ] && ref=0 || ref=1
        elif [[ "$key" == "" ]]; then
            menu_running=false
        else
            case "$key" in
                'a'|'A') for var_name in "${MENU_STEP_VARS[@]}"; do declare -n ref="$var_name"; ref=1; done ;;
                'n'|'N') for var_name in "${MENU_STEP_VARS[@]}"; do declare -n ref="$var_name"; ref=0; done ;;
                'g'|'G') save_config ;;
                'd'|'D') config_exists && delete_config ;;
                'l'|'L') show_language_selector ;;
                't'|'T') show_theme_selector ;;
                'o'|'O') show_notification_menu ;;
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
            send_critical_notification "No Internet Connection" "Autoclean aborted: No internet connection available on $(hostname)"
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

    TOOLS[smartctl]="Diagnósticos SMART de discos"
    TOOL_STEPS[smartctl]=$STEP_CHECK_SMART

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
                        smartctl) packages_to_install="$packages_to_install smartmontools" ;;
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
        # Usa find para manejo seguro de nombres de archivo
        find "$BACKUP_DIR" -maxdepth 1 -name "backup_*.tar.gz" -type f -printf '%T@ %p\n' 2>/dev/null | \
            sort -rn | tail -n +6 | cut -d' ' -f2- | xargs -r -d'\n' rm -f
        find "$BACKUP_DIR" -maxdepth 1 -name "packages_*.list" -type f -printf '%T@ %p\n' 2>/dev/null | \
            sort -rn | tail -n +6 | cut -d' ' -f2- | xargs -r -d'\n' rm -f
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
        send_critical_notification "Timeshift Snapshot Failed" "WARNING: Could not create system snapshot on $(hostname). Proceeding without backup protection."

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
                send_critical_notification "Upgrade Aborted" "SECURITY: Upgrade on $(hostname) would remove ${remove_count} packages. Operation aborted for safety."
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
# PASO 13: LIMPIEZA DOCKER/PODMAN
# ============================================================================

step_cleanup_docker() {
    [ "$STEP_CLEANUP_DOCKER" = 0 ] && return

    print_step "${MSG_DOCKER_CLEANING}"

    local docker_available=false
    local podman_available=false
    local space_before space_after space_freed

    command -v docker &>/dev/null && docker_available=true
    command -v podman &>/dev/null && podman_available=true

    if ! $docker_available && ! $podman_available; then
        echo "→ ${MSG_DOCKER_NOT_INSTALLED}"
        log "INFO" "${MSG_DOCKER_NOT_INSTALLED}"
        STAT_DOCKER="$ICON_SKIP"
        return
    fi

    space_before=$(df / --output=used | tail -1)

    if $docker_available; then
        echo "→ ${MSG_DOCKER_PRUNING}"
        if [ "$DRY_RUN" = true ]; then
            echo "  [DRY-RUN] docker system prune -af --volumes"
        else
            docker system prune -af --volumes 2>&1 | while read -r line; do
                log "DEBUG" "$line"
            done
        fi
    fi

    if $podman_available; then
        echo "→ ${MSG_PODMAN_PRUNING}"
        if [ "$DRY_RUN" = true ]; then
            echo "  [DRY-RUN] podman system prune -af --volumes"
        else
            podman system prune -af --volumes 2>&1 | while read -r line; do
                log "DEBUG" "$line"
            done
        fi
    fi

    space_after=$(df / --output=used | tail -1)
    space_freed=$(( (space_before - space_after) / 1024 ))

    if [ "$space_freed" -gt 0 ]; then
        printf "→ ${MSG_DOCKER_FREED}\n" "${space_freed}MB"
        log "SUCCESS" "$(printf "${MSG_DOCKER_FREED}" "${space_freed}MB")"
    fi

    STAT_DOCKER="$ICON_OK"
    log "SUCCESS" "${MSG_DOCKER_CLEANUP_OK}"
}

# ============================================================================
# PASO 14: VERIFICACION SALUD DE DISCOS (SMART)
# ============================================================================

step_check_smart() {
    [ "$STEP_CHECK_SMART" = 0 ] && return

    print_step "${MSG_SMART_CHECKING}"

    if ! command -v smartctl &>/dev/null; then
        echo "→ ${MSG_SMART_NOT_INSTALLED}"
        echo "  ${MSG_SMART_INSTALL_HINT}"

        if [ "$UNATTENDED" = false ] && [ "$DRY_RUN" = false ]; then
            read -p "${PROMPT_INSTALL_SMARTMONTOOLS} " -n 1 -r
            echo
            if [[ $REPLY =~ $PROMPT_YES_PATTERN ]]; then
                echo "→ ${MSG_INSTALLING_SMARTMONTOOLS}"
                if apt install -y smartmontools; then
                    log "SUCCESS" "${MSG_SMARTMONTOOLS_INSTALLED}"
                    echo "→ ${MSG_SMARTMONTOOLS_INSTALLED}"
                else
                    log "WARN" "${MSG_SMARTMONTOOLS_INSTALL_FAILED}"
                    STAT_SMART="$ICON_SKIP"
                    return
                fi
            else
                log "WARN" "${MSG_SMART_NOT_INSTALLED}"
                STAT_SMART="$ICON_SKIP"
                return
            fi
        else
            log "WARN" "${MSG_SMART_NOT_INSTALLED}"
            STAT_SMART="$ICON_SKIP"
            return
        fi
    fi

    local disks=()
    local disk health_status has_warning=false has_error=false

    # Detectar discos SATA/SAS
    for disk in /dev/sd?; do
        [ -b "$disk" ] && disks+=("$disk")
    done

    # Detectar discos NVMe
    for disk in /dev/nvme?n1; do
        [ -b "$disk" ] && disks+=("$disk")
    done

    if [ ${#disks[@]} -eq 0 ]; then
        echo "→ ${MSG_SMART_NO_DISKS}"
        log "INFO" "${MSG_SMART_NO_DISKS}"
        STAT_SMART="$ICON_SKIP"
        return
    fi

    for disk in "${disks[@]}"; do
        printf "→ ${MSG_SMART_CHECKING_DISK}\n" "$disk"
        log "INFO" "$(printf "${MSG_SMART_CHECKING_DISK}" "$disk")"

        # Obtener estado de salud
        health_status=$(smartctl -H "$disk" 2>/dev/null | grep -E "SMART overall-health|SMART Health Status")

        if echo "$health_status" | grep -qiE "PASSED|OK"; then
            echo "  ${FIXED_GREEN}[OK]${NC} $disk"
        elif echo "$health_status" | grep -qi "FAILED"; then
            echo "  ${FIXED_RED}[FAIL]${NC} $disk - ${MSG_SMART_DISK_FAILING}"
            log "ERROR" "$disk: ${MSG_SMART_DISK_FAILING}"
            has_error=true
        else
            # Verificar atributos críticos
            local reallocated pending
            reallocated=$(smartctl -A "$disk" 2>/dev/null | grep -i "Reallocated_Sector" | awk '{print $NF}')
            pending=$(smartctl -A "$disk" 2>/dev/null | grep -i "Current_Pending" | awk '{print $NF}')

            if [ "${reallocated:-0}" -gt 0 ] || [ "${pending:-0}" -gt 0 ]; then
                echo "  ${FIXED_YELLOW}[!!]${NC} $disk - ${MSG_SMART_DISK_WARNING}"
                log "WARN" "$disk: ${MSG_SMART_DISK_WARNING} (Reallocated: ${reallocated:-0}, Pending: ${pending:-0})"
                has_warning=true
            else
                echo "  ${FIXED_GREEN}[OK]${NC} $disk"
            fi
        fi
    done

    if $has_error; then
        STAT_SMART="$ICON_FAIL"
        log "ERROR" "${MSG_SMART_ERRORS_FOUND}"
        send_critical_notification "DISK FAILURE DETECTED" "CRITICAL: One or more disks on $(hostname) are reporting SMART errors. Backup your data IMMEDIATELY and consider replacing the failing disk(s)."
    elif $has_warning; then
        STAT_SMART="$ICON_WARN"
        log "WARN" "${MSG_SMART_WARNINGS_FOUND}"
    else
        STAT_SMART="$ICON_OK"
        log "SUCCESS" "${MSG_SMART_ALL_OK}"
    fi
}

# ============================================================================
# PASO 15: VERIFICAR NECESIDAD DE REINICIO
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

    # Mapear STAT_* a STEP_STATUS_ARRAY para resumen (orden lógico por fases)
    # Fase 1: 0=Conectividad, 1=Dependencias, 2=SMART
    # Fase 2: 3=Backup, 4=Snapshot
    # Fase 3: 5=Repos, 6=Upgrade, 7=Flatpak, 8=Snap, 9=Firmware
    # Fase 4: 10=APT, 11=Kernels, 12=Disco, 13=Docker
    # Fase 5: 14=Reinicio
    local step_vars=("STEP_CHECK_CONNECTIVITY" "STEP_CHECK_DEPENDENCIES" "STEP_CHECK_SMART"
                     "STEP_BACKUP_TAR" "STEP_SNAPSHOT_TIMESHIFT" "STEP_UPDATE_REPOS"
                     "STEP_UPGRADE_SYSTEM" "STEP_UPDATE_FLATPAK" "STEP_UPDATE_SNAP"
                     "STEP_CHECK_FIRMWARE" "STEP_CLEANUP_APT" "STEP_CLEANUP_KERNELS"
                     "STEP_CLEANUP_DISK" "STEP_CLEANUP_DOCKER" "STEP_CHECK_REBOOT")
    local stat_vars=("STAT_CONNECTIVITY" "STAT_DEPENDENCIES" "STAT_SMART"
                     "STAT_BACKUP_TAR" "STAT_SNAPSHOT" "STAT_REPO"
                     "STAT_UPGRADE" "STAT_FLATPAK" "STAT_SNAP" "STAT_FIRMWARE"
                     "STAT_CLEAN_APT" "STAT_CLEAN_KERNEL" "STAT_CLEAN_DISK"
                     "STAT_DOCKER" "STAT_REBOOT")

    # Contar resultados y determinar estados
    local success_count=0 error_count=0 skipped_count=0 warning_count=0
    for i in {0..14}; do
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

    # Enviar notificación via sistema de plugins
    local notification_severity="success"
    [ $error_count -gt 0 ] && notification_severity="error"
    [ "$REBOOT_NEEDED" = true ] && notification_severity="warning"

    local notification_message
    notification_message=$(build_summary_notification)
    send_notification "Autoclean ${overall_status}" "$notification_message" "$notification_severity"

    log "INFO" "=========================================="
    log "INFO" "Mantenimiento completado en ${minutes}m ${seconds}s"
    log "INFO" "=========================================="

    # === RESUMEN ENTERPRISE 3 COLUMNAS (78 chars) ===
    echo ""
    print_box_top
    print_box_center "${BOLD}${MENU_SUMMARY_TITLE}${BOX_NC}"
    print_box_sep
    print_box_line "${MSG_SUMMARY_STATUS}: ${overall_color}${overall_icon} ${overall_status}${BOX_NC}                          ${MSG_SUMMARY_DURATION}: ${CYAN}${duration_str}${BOX_NC}"
    print_box_sep
    print_box_line "${BOLD}${MSG_SUMMARY_METRICS}${BOX_NC}"
    print_box_line "${MSG_SUMMARY_COMPLETED_COUNT}: ${GREEN}${success_count}${BOX_NC}    ${MSG_SUMMARY_ERRORS}: ${RED}${error_count}${BOX_NC}    ${MSG_SUMMARY_SKIPPED}: ${YELLOW}${skipped_count}${BOX_NC}    ${MSG_SUMMARY_SPACE}: ${CYAN}${total_freed} MB${BOX_NC}"
    print_box_sep
    print_box_line "${BOLD}${MSG_SUMMARY_STEP_DETAIL}${BOX_NC}"

    # Generar líneas de 3 columnas (5 filas x 3 cols = 15 slots, usamos 13)
    # Formato fijo: icono[4] + espacio[1] + nombre[10] = 15 chars por celda
    for row in {0..4}; do
        local line=""
        for col in {0..2}; do
            local idx=$((row * 3 + col))
            if [ $idx -le 14 ]; then
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
        print_box_line "${RED}${ICON_SUM_WARN} ${MSG_REBOOT_REQUIRED}${BOX_NC}"
    else
        print_box_line "${GREEN}${ICON_SUM_OK} ${MSG_REBOOT_NOT_REQUIRED}${BOX_NC}"
    fi

    print_box_sep
    print_box_line "${MSG_SUMMARY_LOG}: ${DIM}${LOG_FILE}${BOX_NC}"
    [ "$STEP_BACKUP_TAR" = 1 ] && print_box_line "${MSG_SUMMARY_BACKUPS}: ${DIM}${BACKUP_DIR}${BOX_NC}"
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
# FUNCIONES DE SYSTEMD TIMER
# ============================================================================

generate_systemd_timer() {
    local schedule="$1"
    local script_path="$(readlink -f "$0")"
    local service_file="/etc/systemd/system/autoclean.service"
    local timer_file="/etc/systemd/system/autoclean.timer"

    local oncalendar
    case "$schedule" in
        daily)   oncalendar="*-*-* 02:00:00" ;;
        weekly)  oncalendar="Sun *-*-* 02:00:00" ;;
        monthly) oncalendar="*-*-01 02:00:00" ;;
    esac

    echo "$MSG_SCHEDULE_CREATING"

    # Create service file
    cat > "$service_file" << EOF
[Unit]
Description=Autoclean System Maintenance
After=network-online.target

[Service]
Type=oneshot
ExecStart=$script_path -y --no-menu
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Create timer file
    cat > "$timer_file" << EOF
[Unit]
Description=Autoclean Scheduled Maintenance Timer

[Timer]
OnCalendar=$oncalendar
Persistent=true
RandomizedDelaySec=1800

[Install]
WantedBy=timers.target
EOF

    # Enable and start timer
    systemctl daemon-reload
    systemctl enable autoclean.timer
    systemctl start autoclean.timer

    echo ""
    echo "$MSG_SCHEDULE_CREATED"
    echo "  → $MSG_SCHEDULE_MODE: $schedule"
    echo "  → $MSG_SCHEDULE_TIME: $oncalendar"
    echo ""
    systemctl status autoclean.timer --no-pager
}

remove_systemd_timer() {
    echo "$MSG_SCHEDULE_REMOVING"
    systemctl stop autoclean.timer 2>/dev/null
    systemctl disable autoclean.timer 2>/dev/null
    rm -f /etc/systemd/system/autoclean.service
    rm -f /etc/systemd/system/autoclean.timer
    systemctl daemon-reload
    echo "$MSG_SCHEDULE_REMOVED"
}

show_schedule_status() {
    if systemctl is-active autoclean.timer &>/dev/null; then
        echo "$MSG_SCHEDULE_ACTIVE"
        echo ""
        systemctl status autoclean.timer --no-pager
        echo ""
        echo "$MSG_SCHEDULE_NEXT_RUN:"
        systemctl list-timers autoclean.timer --no-pager
    else
        echo "$MSG_SCHEDULE_NOT_ACTIVE"
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
        -n|--notify)
            NOTIFY_ON_DRY_RUN=true
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
        --schedule)
            if [ -n "$2" ] && [[ "$2" =~ ^(daily|weekly|monthly)$ ]]; then
                SCHEDULE_MODE="$2"
                shift 2
            else
                echo "Error: --schedule requires: daily, weekly, or monthly"
                exit 1
            fi
            ;;
        --unschedule)
            UNSCHEDULE=true
            shift
            ;;
        --schedule-status)
            SCHEDULE_STATUS=true
            shift
            ;;
        --profile)
            if [ -n "$2" ] && [[ "$2" =~ ^(server|desktop|developer|minimal|custom)$ ]]; then
                PROFILE="$2"
                shift 2
            else
                echo "Error: --profile requires: server, desktop, developer, minimal, or custom"
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
  --dry-run              Simular ejecución sin hacer cambios reales
  -n, --notify           Enviar notificaciones en modo dry-run
  -y, --unattended       Modo desatendido sin confirmaciones
  --no-backup            No crear backup de configuraciones
  --no-menu              Omitir menú interactivo (usar config por defecto)
  --quiet                Modo silencioso (solo logs)
  --lang LANG            Establecer idioma (en, es, pt, fr, de, it)
  --profile PERFIL       Usar perfil predefinido (ver abajo)
  --schedule MODE        Crear timer systemd (daily, weekly, monthly)
  --unschedule           Eliminar timer systemd programado
  --schedule-status      Mostrar estado del timer programado
  --help                 Mostrar esta ayuda

Perfiles predefinidos (--profile):
  server      Desatendido, Docker ON, SMART ON, sin Flatpak/Snap
  desktop     Interactivo, Docker OFF, SMART ON, Flatpak ON, Timeshift ON
  developer   Interactivo, Docker ON, Snap ON, sin SMART/Firmware
  minimal     Desatendido, solo apt update/upgrade y limpieza APT
  custom      Desatendido, lee toda la configuracion desde autoclean.conf

Ejemplos:
  sudo ./autoclean.sh                    # Ejecución normal (interactivo)
  sudo ./autoclean.sh --profile server   # Perfil servidor
  sudo ./autoclean.sh --profile desktop  # Perfil escritorio
  sudo ./autoclean.sh --profile custom   # Perfil custom (lee autoclean.conf)
  sudo ./autoclean.sh --dry-run          # Simular cambios
  sudo ./autoclean.sh --dry-run --notify # Simular y enviar notificaciones
  sudo ./autoclean.sh -y                 # Modo desatendido
  sudo ./autoclean.sh --schedule weekly  # Programar semanal

Configuración:
  - Edita autoclean.conf para configurar idioma, tema y pasos
  - Si el archivo no existe, se genera automaticamente con valores por defecto
  - Usa --profile custom para ejecutar con la configuracion guardada

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

# Detectar notificadores disponibles (antes de load_config para apply_notifier_config)
detect_notifiers

# Cargar configuración guardada si existe (para obtener SAVED_LANG antes de cargar idioma)
# Si no existe, generar archivo con valores predeterminados
if config_exists; then
    load_config
else
    generate_default_config
    load_config
fi

# Cargar idioma (usa SAVED_LANG si existe, o detecta del sistema)
load_language

# Cargar tema (usa SAVED_THEME si existe, o usa default)
load_theme

# Cargar notificadores habilitados
load_all_enabled_notifiers

# Manejar operaciones de schedule (antes de ejecución principal)
if [ "$SCHEDULE_STATUS" = true ]; then
    show_schedule_status
    exit 0
fi

if [ "$UNSCHEDULE" = true ]; then
    check_root
    remove_systemd_timer
    exit 0
fi

if [ -n "$SCHEDULE_MODE" ]; then
    check_root
    generate_systemd_timer "$SCHEDULE_MODE"
    exit 0
fi

# Verificar permisos de root ANTES de cualquier operación
check_root

# Inicialización
init_log
log "INFO" "=========================================="
log "INFO" "Iniciando Mantenimiento v${SCRIPT_VERSION}"
log "INFO" "=========================================="

# Aplicar perfil si se especificó via CLI (--profile)
# Debe ejecutarse después de init_log para que log() funcione correctamente
if [ -n "$PROFILE" ]; then
    apply_profile "$PROFILE"
fi

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
# FASE 1: Verificaciones previas
step_check_connectivity
step_check_dependencies
step_check_smart

# FASE 2: Backups
step_backup_tar
step_snapshot_timeshift

# FASE 3: Actualizaciones
step_update_repos
step_upgrade_system
step_update_flatpak
step_update_snap
step_check_firmware

# FASE 4: Limpieza
step_cleanup_apt
step_cleanup_kernels
step_cleanup_disk
step_cleanup_docker

# FASE 5: Verificación final
step_check_reboot

# Mostrar resumen final
show_final_summary

exit 0
