#!/bin/bash
# ============================================================================
# Comprehensive Maintenance Script for Debian-based Distributions
# ============================================================================
# Version: 2025.11
# Last revision: December 2025
# Author: Homero Thompson del Lago del Terror
# UI/UX Contributions: Dreadblitz (github.com/Dreadblitz)
#
# ====================== SUPPORTED DISTRIBUTIONS ======================
# This script automatically detects and supports the following distributions:
#   • Debian (all versions: Stable, Testing, Unstable)
#   • Ubuntu (all LTS and regular versions)
#   • Linux Mint (all versions)
#   • Pop!_OS
#   • Elementary OS
#   • Zorin OS
#   • Kali Linux
#   • Any Debian/Ubuntu based distribution (automatic detection)
#
# ====================== EXECUTION PHILOSOPHY ======================
# This script implements a maintenance system designed
# for Debian/Ubuntu based distributions, with emphasis on:
#   1. Security first: Snapshot before critical changes
#   2. Granular control: Each step can be enabled/disabled
#   3. Risk analysis: Detects dangerous operations before executing
#   4. Return point: Timeshift snapshot for complete rollback
#   5. Intelligent validation: Verifies dependencies and system state
#   6. Advanced reboot detection: Kernel + critical libraries
#   7. Automatic distribution detection: Adapts servers and behavior
#
# ====================== SYSTEM REQUIREMENTS ======================
# MANDATORY:
#   • Debian or Ubuntu based distribution
#   • Root permissions (sudo)
#   • Internet connection
#
# RECOMMENDED (script can install them automatically):
#   • timeshift      - System snapshots (CRITICAL for safety)
#   • needrestart    - Intelligent detection of services to restart
#   • fwupd          - Firmware update management
#   • flatpak        - If you use Flatpak applications
#   • snapd          - If you use Snap applications
#
# Manual installation of recommended tools:
#   sudo apt install timeshift needrestart fwupd flatpak
#
# ====================== STEP CONFIGURATION ======================
# Each step can be enabled (1) or disabled (0) according to your needs.
# The script will validate dependencies automatically.
#
# AVAILABLE STEPS:
#   STEP_CHECK_CONNECTIVITY    - Verify internet connection
#   STEP_CHECK_DEPENDENCIES    - Verify and install tools
#   STEP_BACKUP_TAR           - Backup APT configurations
#   STEP_SNAPSHOT_TIMESHIFT   - Create Timeshift snapshot (RECOMMENDED)
#   STEP_UPDATE_REPOS         - Update repositories (apt update)
#   STEP_UPGRADE_SYSTEM       - Update packages (apt full-upgrade)
#   STEP_UPDATE_FLATPAK       - Update Flatpak applications
#   STEP_UPDATE_SNAP          - Update Snap applications
#   STEP_CHECK_FIRMWARE       - Check firmware updates
#   STEP_CLEANUP_APT          - Orphan package cleanup
#   STEP_CLEANUP_KERNELS      - Remove old kernels
#   STEP_CLEANUP_DISK         - Clean logs and cache
#   STEP_CHECK_REBOOT         - Check reboot necessity
#
# ====================== USAGE EXAMPLES ======================
# 1. Full interactive execution (RECOMMENDED):
#    sudo ./cleannew.sh
#
# 2. Simulation mode (test without real changes):
#    sudo ./cleannew.sh --dry-run
#
# 3. Unattended mode for automation:
#    sudo ./cleannew.sh -y
#
# 4. Only update system without cleanup:
#    Edit the script and configure:
#    STEP_CLEANUP_APT=0
#    STEP_CLEANUP_KERNELS=0
#    STEP_CLEANUP_DISK=0
#
# 5. Only cleanup without updating:
#    STEP_UPDATE_REPOS=0
#    STEP_UPGRADE_SYSTEM=0
#    STEP_UPDATE_FLATPAK=0
#    STEP_UPDATE_SNAP=0
#
# ====================== FILES AND DIRECTORIES ======================
# Logs:     /var/log/debian-maintenance/sys-update-YYYYMMDD_HHMMSS.log
# Backups:  /var/backups/debian-maintenance/backup_YYYYMMDD_HHMMSS.tar.gz
# Lock:     /var/run/debian-maintenance.lock
#
# ====================== SECURITY FEATURES ======================
# • Disk space validation before updating
# • Detection of mass package removal operations
# • Automatic Timeshift snapshot (if configured)
# • APT configuration backup before changes
# • Lock file to prevent simultaneous executions
# • Automatic dpkg database repair
# • Intelligent reboot detection:
#   - Current vs expected kernel comparison
#   - Detection of updated critical libraries (glibc, systemd)
#   - Count of services requiring restart
# • Dry-run mode to simulate without making changes
#
# ====================== IMPORTANT NOTES ======================
# • Testing may have disruptive changes: ALWAYS review logs
# • Timeshift snapshot is your safety net: don't skip it
# • MAX_REMOVALS_ALLOWED=0 prevents automatic mass deletions
# • In unattended mode (-y), script ABORTS if risk detected
# • Script uses LC_ALL=C for predictable command parsing
# • Kernels are maintained according to KERNELS_TO_KEEP (default: 3)
# • Logs are kept according to DIAS_LOGS (default: 7 days)
#
# ====================== TROUBLESHOOTING ======================
# If the script fails:
#   1. Check log in /var/log/debian-maintenance/
#   2. Run in --dry-run mode to diagnose
#   3. Verify disk space with: df -h
#   4. Repair dpkg manually: sudo dpkg --configure -a
#   5. If Timeshift issues, restore the snapshot
#
# To report bugs or suggestions:
#   Review the complete log and note the step where it failed
#
# ============================================================================

# Force standard locale for predictable parsing
export LC_ALL=C

# ============================================================================
# GENERAL CONFIGURATION
# ============================================================================

# Files and directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/autoclean.conf"
BACKUP_DIR="/var/backups/debian-maintenance"
LOCK_FILE="/var/run/debian-maintenance.lock"
LOG_DIR="/var/log/debian-maintenance"
SCRIPT_VERSION="2025.12"

# Language configuration
LANG_DIR="${SCRIPT_DIR}/plugins/lang"
DEFAULT_LANG="en"
CURRENT_LANG=""
AVAILABLE_LANGS=()    # Filled dynamically with detect_languages()
LANG_NAMES=()         # Display names (from LANG_NAME in each file)

# Theme configuration
THEME_DIR="${SCRIPT_DIR}/plugins/themes"
DEFAULT_THEME="default"
CURRENT_THEME=""
AVAILABLE_THEMES=()   # Filled dynamically with detect_themes()
THEME_NAMES=()        # Display names (from THEME_NAME in each file)

# Notifier configuration
NOTIFIER_DIR="${SCRIPT_DIR}/plugins/notifiers"
AVAILABLE_NOTIFIERS=()    # Filled dynamically with detect_notifiers()
NOTIFIER_NAMES=()         # Display names (from NOTIFIER_NAME in each file)
NOTIFIER_DESCRIPTIONS=()  # Descriptions for each notifier
declare -A NOTIFIER_ENABLED   # Enabled/disabled state by code
declare -A NOTIFIER_LOADED    # Successfully loaded notifiers

# Help system configuration
HELP_DIR="${SCRIPT_DIR}/plugins/help"
HELP_WINDOW_HEIGHT=12     # Visible lines in scrollable help window

# System parameters
DIAS_LOGS=7
KERNELS_TO_KEEP=3
MIN_FREE_SPACE_GB=5
MIN_FREE_SPACE_BOOT_MB=200
APT_CLEAN_MODE="autoclean"

# Paranoid security
MAX_REMOVALS_ALLOWED=0
ASK_TIMESHIFT_RUN=true

# ============================================================================
# STEP EXECUTION CONFIGURATION
# ============================================================================
# Change to 0 to disable a step, 1 to enable it
# The script will validate dependencies automatically

STEP_CHECK_CONNECTIVITY=1     # Verify internet connection
STEP_CHECK_DEPENDENCIES=1     # Verify and install tools
STEP_BACKUP_TAR=1            # Backup APT configurations
STEP_SNAPSHOT_TIMESHIFT=1    # Create Timeshift snapshot (RECOMMENDED)
STEP_UPDATE_REPOS=1          # Update repositories (apt update)
STEP_UPGRADE_SYSTEM=1        # Update packages (apt full-upgrade)
STEP_UPDATE_FLATPAK=1        # Update Flatpak applications
STEP_UPDATE_SNAP=0           # Update Snap applications
STEP_CHECK_FIRMWARE=1        # Check firmware updates
STEP_CLEANUP_APT=1           # Orphan package cleanup
STEP_CLEANUP_KERNELS=1       # Remove old kernels
STEP_CLEANUP_DISK=1          # Clean logs and cache
STEP_CLEANUP_DOCKER=0        # Clean Docker/Podman (disabled by default)
STEP_CHECK_SMART=1           # Check disk health (SMART)
STEP_CHECK_REBOOT=1          # Check reboot necessity

# ============================================================================
# NEW SECURITY AND MAINTENANCE STEPS (v2025.12)
# ============================================================================
STEP_CHECK_REPOS=1           # Verify APT repository integrity
STEP_CHECK_DEBSUMS=0         # Verify package integrity (debsums)
STEP_CHECK_SECURITY=1        # Check pending security updates
STEP_CHECK_PERMISSIONS=0     # Verify critical file permissions
STEP_AUDIT_SERVICES=0        # Audit unnecessary services
STEP_CLEANUP_SESSIONS=0      # Clean abandoned sessions
STEP_CHECK_LOGROTATE=0       # Verify/configure logrotate
STEP_CHECK_INODES=0          # Check inode space

# Systemd Timer scheduling variables
SCHEDULE_MODE=""             # Mode: daily, weekly, monthly
UNSCHEDULE=false             # Flag to remove timer
SCHEDULE_STATUS=false        # Flag to show timer status

# Predefined Profiles variables
PROFILE=""                   # Profile: server, desktop, developer, minimal

# ============================================================================
# DISTRIBUTION VARIABLES
# ============================================================================

# These variables are filled automatically when detecting the distribution
DISTRO_ID=""
DISTRO_NAME=""
DISTRO_VERSION=""
DISTRO_CODENAME=""
DISTRO_FAMILY=""  # debian, ubuntu, mint
DISTRO_MIRROR=""  # Server for connectivity verification

# Supported distributions
SUPPORTED_DISTROS="debian ubuntu linuxmint pop elementary zorin kali"

# ============================================================================
# STATE AND CONTROL VARIABLES
# ============================================================================

# Visual states for each step
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

# New states (v2025.12)
STAT_CHECK_REPOS="[..]"
STAT_DEBSUMS="[..]"
STAT_SECURITY="[..]"
STAT_PERMISSIONS="[..]"
STAT_AUDIT_SERVICES="[..]"
STAT_SESSIONS="[..]"
STAT_LOGROTATE="[..]"
STAT_INODES="[..]"

# Counters and time
SPACE_BEFORE_ROOT=0
SPACE_BEFORE_BOOT=0
START_TIME=$(date +%s)
CURRENT_STEP=0
TOTAL_STEPS=0

# Control flags
DRY_RUN=false
NOTIFY_ON_DRY_RUN=false
UNATTENDED=false
QUIET=false
REBOOT_NEEDED=false
NO_MENU=false
UPGRADE_PERFORMED=false

# ============================================================================
# INTERACTIVE MENU CONFIGURATION
# ============================================================================

# Arrays for interactive menu (filled from language file)
declare -a MENU_STEP_NAMES
declare -a MENU_STEP_DESCRIPTIONS
declare -a STEP_SHORT_NAMES

MENU_STEP_VARS=(
    # PHASE 1: Pre-checks (4 steps)
    "STEP_CHECK_CONNECTIVITY"    # 1  - Check connectivity
    "STEP_CHECK_DEPENDENCIES"    # 2  - Check dependencies
    "STEP_CHECK_REPOS"           # 3  - Check APT/GPG repos (NEW)
    "STEP_CHECK_SMART"           # 4  - SMART (disk health)

    # PHASE 2: Security audit (4 steps - NEW)
    "STEP_CHECK_DEBSUMS"         # 5  - Package integrity (NEW)
    "STEP_CHECK_SECURITY"        # 6  - Security updates (NEW)
    "STEP_CHECK_PERMISSIONS"     # 7  - Critical permissions (NEW)
    "STEP_AUDIT_SERVICES"        # 8  - Audit services (NEW)

    # PHASE 3: Backups (2 steps)
    "STEP_BACKUP_TAR"            # 9  - TAR Backup
    "STEP_SNAPSHOT_TIMESHIFT"    # 10 - Timeshift Snapshot

    # PHASE 4: Updates (5 steps)
    "STEP_UPDATE_REPOS"          # 11 - Update repos
    "STEP_UPGRADE_SYSTEM"        # 12 - Update system
    "STEP_UPDATE_FLATPAK"        # 13 - Flatpak
    "STEP_UPDATE_SNAP"           # 14 - Snap
    "STEP_CHECK_FIRMWARE"        # 15 - Firmware

    # PHASE 5: Cleanup (7 steps)
    "STEP_CLEANUP_APT"           # 16 - APT Cleanup
    "STEP_CLEANUP_KERNELS"       # 17 - Kernel Cleanup
    "STEP_CLEANUP_DISK"          # 18 - Disk Cleanup
    "STEP_CLEANUP_DOCKER"        # 19 - Docker Cleanup
    "STEP_CLEANUP_SESSIONS"      # 20 - Clean sessions (NEW)
    "STEP_CHECK_LOGROTATE"       # 21 - Logrotate (NEW)
    "STEP_CHECK_INODES"          # 22 - Inodes (NEW)

    # PHASE 6: Final check (1 step)
    "STEP_CHECK_REBOOT"          # 23 - Check reboot
)

# Function to update arrays from language variables
update_language_arrays() {
    MENU_STEP_NAMES=(
        "$STEP_NAME_1"   # Connectivity
        "$STEP_NAME_2"   # Dependencies
        "$STEP_NAME_3"   # APT Repos (NEW)
        "$STEP_NAME_4"   # SMART
        "$STEP_NAME_5"   # Debsums (NEW)
        "$STEP_NAME_6"   # Security (NEW)
        "$STEP_NAME_7"   # Permissions (NEW)
        "$STEP_NAME_8"   # Services (NEW)
        "$STEP_NAME_9"   # Backup TAR
        "$STEP_NAME_10"  # Timeshift
        "$STEP_NAME_11"  # Update Repos
        "$STEP_NAME_12"  # Upgrade
        "$STEP_NAME_13"  # Flatpak
        "$STEP_NAME_14"  # Snap
        "$STEP_NAME_15"  # Firmware
        "$STEP_NAME_16"  # Cleanup APT
        "$STEP_NAME_17"  # Cleanup Kernels
        "$STEP_NAME_18"  # Cleanup Disk
        "$STEP_NAME_19"  # Docker
        "$STEP_NAME_20"  # Sessions (NEW)
        "$STEP_NAME_21"  # Logrotate (NEW)
        "$STEP_NAME_22"  # Inodes (NEW)
        "$STEP_NAME_23"  # Reboot
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
        "$STEP_DESC_16"
        "$STEP_DESC_17"
        "$STEP_DESC_18"
        "$STEP_DESC_19"
        "$STEP_DESC_20"
        "$STEP_DESC_21"
        "$STEP_DESC_22"
        "$STEP_DESC_23"
    )

    STEP_SHORT_NAMES=(
        "$STEP_SHORT_1"   # Connect
        "$STEP_SHORT_2"   # Deps
        "$STEP_SHORT_3"   # APT Repos
        "$STEP_SHORT_4"   # SMART
        "$STEP_SHORT_5"   # Debsums
        "$STEP_SHORT_6"   # Security
        "$STEP_SHORT_7"   # Perms
        "$STEP_SHORT_8"   # Services
        "$STEP_SHORT_9"   # Backup
        "$STEP_SHORT_10"  # Snapshot
        "$STEP_SHORT_11"  # Repos
        "$STEP_SHORT_12"  # Upgrade
        "$STEP_SHORT_13"  # Flatpak
        "$STEP_SHORT_14"  # Snap
        "$STEP_SHORT_15"  # Firmware
        "$STEP_SHORT_16"  # APT Clean
        "$STEP_SHORT_17"  # Kernels
        "$STEP_SHORT_18"  # Disk
        "$STEP_SHORT_19"  # Docker
        "$STEP_SHORT_20"  # Sessions
        "$STEP_SHORT_21"  # Logrotate
        "$STEP_SHORT_22"  # Inodes
        "$STEP_SHORT_23"  # Reboot
    )
}

# ============================================================================
# PERSISTENT CONFIGURATION FUNCTIONS
# ============================================================================

save_config() {
    # Save current step states and preferences to configuration file
    # SECURITY: Create file with restrictive permissions from the start (avoid race condition)
    local old_umask=$(umask)
    umask 077
    cat > "$CONFIG_FILE" << EOF
# Autoclean configuration - Auto-generated
# Date: $(date '+%Y-%m-%d %H:%M:%S')

# ============================================================================
# PROFILE
# ============================================================================
# Values: server, desktop, developer, minimal, custom
SAVED_PROFILE=${PROFILE:-custom}

# ============================================================================
# LANGUAGE
# ============================================================================
SAVED_LANG=$CURRENT_LANG

# ============================================================================
# THEME
# ============================================================================
SAVED_THEME=$CURRENT_THEME

# ============================================================================
# STEPS CONFIGURATION
# ============================================================================
# (Only applies when SAVED_PROFILE=custom)
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

    # Add notifiers section
    cat >> "$CONFIG_FILE" << 'NOTIF_HEADER'

# ============================================================================
# NOTIFICATIONS
# ============================================================================
NOTIF_HEADER

    # Save enabled/disabled state of each notifier
    for code in "${AVAILABLE_NOTIFIERS[@]}"; do
        local enabled="${NOTIFIER_ENABLED[$code]:-0}"
        echo "NOTIFIER_${code^^}_ENABLED=$enabled" >> "$CONFIG_FILE"
    done

    # Save specific configuration for each notifier
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

    # SECURITY: Restore original umask
    umask "$old_umask"

    # Change ownership to the user who ran sudo (not root)
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        chown "$SUDO_USER:$SUDO_USER" "$CONFIG_FILE" 2>/dev/null
    fi

    # Note: chmod 600 is no longer needed, umask 077 creates the file with correct permissions

    return $result
}

# Validate file before sourcing (security)
# Rejects files with dangerous syntax that could execute code
validate_source_file() {
    local file="$1"
    local file_type="${2:-file}"

    # Verify that the file exists and is readable
    [[ ! -f "$file" || ! -r "$file" ]] && return 1

    # SECURITY: Verify that it's not a symlink pointing outside the expected directory
    local real_path
    real_path=$(realpath "$file" 2>/dev/null)
    local expected_dir
    expected_dir=$(dirname "$file")
    expected_dir=$(realpath "$expected_dir" 2>/dev/null)
    if [[ "$real_path" != "$expected_dir"/* ]]; then
        log "WARN" "File $file_type rejected: symlink outside allowed directory"
        return 1
    fi

    # Dangerous patterns to reject (could execute arbitrary code)
    # Searched in non-commented content
    local content
    content=$(grep -v '^\s*#' "$file" 2>/dev/null)

    # SECURITY: Search for dangerous patterns with regex:
    # - $( or ` = command substitution
    # - ; followed by optional spaces and letter = sequential execution (allows ;0-9 for ANSI codes)
    # - | = pipe to another command
    # - && or || = logical operators (with or without spaces)
    # - ${ with commands = dangerous parameter expansion
    if echo "$content" | grep -qE '\$\(|`|;[[:space:]]*[a-zA-Z_]|[^a-zA-Z0-9_]\|[^a-zA-Z0-9_]|&&|\|\||\$\{[^}]*(:|/|%|#)' 2>/dev/null; then
        log "WARN" "File $file_type rejected: contains disallowed syntax"
        return 1
    fi

    return 0
}

# Validate notifier file (less restrictive than validate_source_file)
# Notifiers need to execute commands, but we block very dangerous patterns
validate_notifier_file() {
    local file="$1"

    # Verify that the file exists and is readable
    [[ ! -f "$file" || ! -r "$file" ]] && return 1

    # SECURITY: Verify that it's not a symlink pointing outside the notifiers directory
    local real_path
    real_path=$(realpath "$file" 2>/dev/null)
    local expected_dir
    expected_dir=$(realpath "$NOTIFIER_DIR" 2>/dev/null)
    if [[ "$real_path" != "$expected_dir"/* ]]; then
        log "WARN" "Notifier file rejected: symlink outside allowed directory"
        return 1
    fi

    local content
    content=$(grep -v '^\s*#' "$file" 2>/dev/null)

    # SECURITY: Dangerous patterns to block (reinforced regex):
    # - eval with any separator (not just space)
    # - source/. from URLs or variables = load external code
    # - curl/wget with -o/-O = download to file
    # - curl/wget piped to bash/sh = remote execution
    # - rm -rf / = system destruction
    # - dd if= = direct disk writing
    # - mkfs = disk formatting
    # - chmod 777 = insecure permissions
    # - exec = process replacement
    local dangerous_patterns='eval[^a-zA-Z]|exec[^a-zA-Z]'
    dangerous_patterns+='|source\s+["\x27]?(https?://|\$)|^\s*\.\s+["\x27]?(https?://|\$)'
    dangerous_patterns+='|curl.*-[oO]\s|wget.*-[oO]\s'
    dangerous_patterns+='|curl.*\|\s*(ba)?sh|wget.*\|\s*(ba)?sh'
    dangerous_patterns+='|rm\s+-[rf]*\s+/[^a-zA-Z]|dd\s+if=|mkfs\.|chmod\s+777'

    if echo "$content" | grep -qE "$dangerous_patterns" 2>/dev/null; then
        log "WARN" "Notifier file rejected: contains dangerous patterns"
        return 1
    fi

    # Verify that it has the required basic functions
    if ! grep -q 'notifier_send\s*()' "$file" 2>/dev/null; then
        log "WARN" "Notifier file rejected: missing notifier_send() function"
        return 1
    fi

    return 0
}

load_config() {
    # Load configuration if file exists
    if [ -f "$CONFIG_FILE" ]; then
        if validate_source_file "$CONFIG_FILE" "config"; then
            source "$CONFIG_FILE"
            # Apply notifier configuration
            apply_notifier_config
            return 0
        else
            log "WARN" "Configuration file failed security validation"
            return 1
        fi
    fi
    return 1
}

apply_notifier_config() {
    # Apply saved notifier configuration to the NOTIFIER_ENABLED array
    # The NOTIFIER_*_ENABLED variables are loaded from config file via source
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
    # Generate autoclean.conf with script default values
    # This function is called automatically if the file doesn't exist
    log "INFO" "${MSG_CONFIG_GENERATING:-Generating default configuration file...}"

    # Detect system language and verify if it's supported
    local detected_lang="$DEFAULT_LANG"
    local sys_lang="${LANG%%_*}"
    sys_lang="${sys_lang%%.*}"
    if [ -n "$sys_lang" ] && [ -f "${LANG_DIR}/${sys_lang}.lang" ]; then
        detected_lang="$sys_lang"
    fi

    # SECURITY: Create file with restrictive permissions from the start
    local old_umask=$(umask)
    umask 077
    cat > "$CONFIG_FILE" << EOF
# Autoclean configuration - Auto-generated
# Date: $(date '+%Y-%m-%d %H:%M:%S')

# ============================================================================
# PROFILE
# ============================================================================
# Values: server, desktop, developer, minimal, custom
# custom = uses the STEP_* values defined below
SAVED_PROFILE=custom

# ============================================================================
# LANGUAGE
# ============================================================================
SAVED_LANG=$detected_lang

# ============================================================================
# THEME
# ============================================================================
SAVED_THEME=$DEFAULT_THEME

# ============================================================================
# STEPS CONFIGURATION
# ============================================================================
# (Only applies when SAVED_PROFILE=custom)
# Set to 0 to disable a step, 1 to enable it

# Pre-checks and diagnostics
STEP_CHECK_CONNECTIVITY=1
STEP_CHECK_DEPENDENCIES=1
STEP_CHECK_REPOS=1
STEP_CHECK_SMART=1
STEP_CHECK_DEBSUMS=0
STEP_CHECK_SECURITY=1
STEP_CHECK_PERMISSIONS=0
STEP_AUDIT_SERVICES=0

# Backup
STEP_BACKUP_TAR=1
STEP_SNAPSHOT_TIMESHIFT=1

# System updates
STEP_UPDATE_REPOS=1
STEP_UPGRADE_SYSTEM=1
STEP_UPDATE_FLATPAK=1
STEP_UPDATE_SNAP=0
STEP_CHECK_FIRMWARE=1

# Cleanup
STEP_CLEANUP_APT=1
STEP_CLEANUP_KERNELS=1
STEP_CLEANUP_DISK=1
STEP_CLEANUP_DOCKER=0
STEP_CLEANUP_SESSIONS=0
STEP_CHECK_LOGROTATE=0
STEP_CHECK_INODES=0

# Final
STEP_CHECK_REBOOT=1
EOF

    local result=$?

    # SECURITY: Restore original umask
    umask "$old_umask"

    # Change ownership to the user who ran sudo (not root)
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        chown "$SUDO_USER:$SUDO_USER" "$CONFIG_FILE" 2>/dev/null
    fi

    if [ $result -eq 0 ]; then
        log "INFO" "${MSG_CONFIG_GENERATED:-Default configuration file generated}: $CONFIG_FILE"
    fi

    return $result
}

# ============================================================================
# PREDEFINED PROFILES
# ============================================================================

apply_profile() {
    local profile="$1"

    case "$profile" in
        server)
            # Server: No UI, Docker enabled, SMART active, no Flatpak/Snap
            # Security and audit maximized
            STEP_CHECK_CONNECTIVITY=1
            STEP_CHECK_DEPENDENCIES=1
            STEP_CHECK_REPOS=1           # Verify repository integrity
            STEP_CHECK_SMART=1
            STEP_CHECK_DEBSUMS=1         # Verify package integrity
            STEP_CHECK_SECURITY=1        # Critical security updates
            STEP_CHECK_PERMISSIONS=1     # Audit critical permissions
            STEP_AUDIT_SERVICES=1        # Audit unnecessary services
            STEP_BACKUP_TAR=1
            STEP_SNAPSHOT_TIMESHIFT=0    # Servers don't use Timeshift
            STEP_UPDATE_REPOS=1
            STEP_UPGRADE_SYSTEM=1
            STEP_UPDATE_FLATPAK=0        # Servers don't use Flatpak
            STEP_UPDATE_SNAP=0           # Servers don't use Snap
            STEP_CHECK_FIRMWARE=1
            STEP_CLEANUP_APT=1
            STEP_CLEANUP_KERNELS=1
            STEP_CLEANUP_DISK=1
            STEP_CLEANUP_DOCKER=1        # Docker enabled
            STEP_CLEANUP_SESSIONS=1      # Clean abandoned SSH/tmux sessions
            STEP_CHECK_LOGROTATE=1       # Logs grow a lot on servers
            STEP_CHECK_INODES=1          # Critical for servers with many files
            STEP_CHECK_REBOOT=1
            NO_MENU=true                 # No interactive UI
            UNATTENDED=true              # Unattended mode (accepts everything)
            ;;
        desktop)
            # Desktop: Active UI, no Docker, SMART active, Flatpak enabled
            # Balanced configuration for daily use
            STEP_CHECK_CONNECTIVITY=1
            STEP_CHECK_DEPENDENCIES=1
            STEP_CHECK_REPOS=1           # Verify repos
            STEP_CHECK_SMART=1
            STEP_CHECK_DEBSUMS=0         # Less critical for desktop
            STEP_CHECK_SECURITY=1        # Security updates
            STEP_CHECK_PERMISSIONS=0     # Less critical for desktop
            STEP_AUDIT_SERVICES=0        # Desktop has more legitimate services
            STEP_BACKUP_TAR=1
            STEP_SNAPSHOT_TIMESHIFT=1    # Timeshift recommended
            STEP_UPDATE_REPOS=1
            STEP_UPGRADE_SYSTEM=1
            STEP_UPDATE_FLATPAK=1        # Flatpak enabled
            STEP_UPDATE_SNAP=0
            STEP_CHECK_FIRMWARE=1
            STEP_CLEANUP_APT=1
            STEP_CLEANUP_KERNELS=1
            STEP_CLEANUP_DISK=1
            STEP_CLEANUP_DOCKER=0        # No Docker
            STEP_CLEANUP_SESSIONS=0      # Less relevant for desktop
            STEP_CHECK_LOGROTATE=0       # Less critical
            STEP_CHECK_INODES=0          # Rare problem on desktop
            STEP_CHECK_REBOOT=1
            ;;
        developer)
            # Developer: Active UI, Docker enabled, no SMART, everything active
            # Optimized for speed and development environments
            STEP_CHECK_CONNECTIVITY=1
            STEP_CHECK_DEPENDENCIES=1
            STEP_CHECK_REPOS=1           # Avoid repo problems
            STEP_CHECK_SMART=0           # No SMART (can be slow)
            STEP_CHECK_DEBSUMS=0         # Slow, developers prefer speed
            STEP_CHECK_SECURITY=1        # Security updates
            STEP_CHECK_PERMISSIONS=0     # Less critical in development
            STEP_AUDIT_SERVICES=0        # Developers have many services
            STEP_BACKUP_TAR=1
            STEP_SNAPSHOT_TIMESHIFT=1
            STEP_UPDATE_REPOS=1
            STEP_UPGRADE_SYSTEM=1
            STEP_UPDATE_FLATPAK=1
            STEP_UPDATE_SNAP=1           # Snap enabled
            STEP_CHECK_FIRMWARE=0        # No firmware (avoid interruptions)
            STEP_CLEANUP_APT=1
            STEP_CLEANUP_KERNELS=1
            STEP_CLEANUP_DISK=1
            STEP_CLEANUP_DOCKER=1        # Docker enabled
            STEP_CLEANUP_SESSIONS=1      # Clean abandoned development sessions
            STEP_CHECK_LOGROTATE=0       # Less critical
            STEP_CHECK_INODES=0          # Less critical
            STEP_CHECK_REBOOT=1
            ;;
        minimal)
            # Minimal: Only essential updates, no aggressive cleanup
            # Everything disabled except the absolutely necessary
            STEP_CHECK_CONNECTIVITY=1
            STEP_CHECK_DEPENDENCIES=0
            STEP_CHECK_REPOS=0           # Minimal
            STEP_CHECK_SMART=0
            STEP_CHECK_DEBSUMS=0         # Minimal
            STEP_CHECK_SECURITY=0        # Minimal
            STEP_CHECK_PERMISSIONS=0     # Minimal
            STEP_AUDIT_SERVICES=0        # Minimal
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
            STEP_CLEANUP_SESSIONS=0      # Minimal
            STEP_CHECK_LOGROTATE=0       # Minimal
            STEP_CHECK_INODES=0          # Minimal
            STEP_CHECK_REBOOT=1
            NO_MENU=true                 # No interactive UI
            UNATTENDED=true              # Unattended mode (accepts everything)
            ;;
        custom)
            # Custom: Read configuration from autoclean.conf, no UI
            # Does NOT modify STEP_* variables - uses exactly what's in the file
            if config_exists; then
                load_config
                log "INFO" "${MSG_PROFILE_CUSTOM_LOADED:-Custom profile loaded from configuration file}"
            else
                log "WARN" "${MSG_CONFIG_NOT_FOUND:-Configuration file not found, using defaults}"
            fi
            NO_MENU=true                 # No interactive UI
            UNATTENDED=true              # Unattended mode (accepts everything)
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
# LANGUAGE FUNCTIONS (i18n)
# ============================================================================

# Detect available languages dynamically from the lang/ folder
detect_languages() {
    AVAILABLE_LANGS=()
    LANG_NAMES=()

    # Search for all .lang files
    local lang_file
    for lang_file in "$LANG_DIR"/*.lang; do
        [ -f "$lang_file" ] || continue

        # Extract language code (filename without extension)
        local code
        code=$(basename "$lang_file" .lang)

        # Extract language name from file (LANG_NAME="...")
        local name
        name=$(grep -m1 '^LANG_NAME=' "$lang_file" 2>/dev/null | cut -d'"' -f2)

        # If it doesn't have LANG_NAME, use the code in uppercase
        [ -z "$name" ] && name="${code^^}"

        AVAILABLE_LANGS+=("$code")
        LANG_NAMES+=("$name")
    done

    # If no languages found, use English as fallback
    if [ ${#AVAILABLE_LANGS[@]} -eq 0 ]; then
        AVAILABLE_LANGS=("en")
        LANG_NAMES=("English")
    fi
}

load_language() {
    local lang_to_load="$1"

    # If no language specified, detect automatically
    if [ -z "$lang_to_load" ]; then
        # Priority: 1) Saved config, 2) Environment variable, 3) System, 4) Default
        if [ -n "$SAVED_LANG" ]; then
            lang_to_load="$SAVED_LANG"
        elif [ -n "$AUTOCLEAN_LANG" ]; then
            lang_to_load="$AUTOCLEAN_LANG"
        else
            # Detect system language
            local sys_lang="${LANG%%_*}"
            sys_lang="${sys_lang%%.*}"
            lang_to_load="${sys_lang:-$DEFAULT_LANG}"
        fi
    fi

    # Verify that the language exists
    local lang_file="${LANG_DIR}/${lang_to_load}.lang"
    if [ ! -f "$lang_file" ]; then
        # Fallback to default language
        lang_file="${LANG_DIR}/${DEFAULT_LANG}.lang"
        lang_to_load="$DEFAULT_LANG"
    fi

    # Load language file (with security validation)
    if [ -f "$lang_file" ]; then
        if validate_source_file "$lang_file" "lang"; then
            source "$lang_file"
            CURRENT_LANG="$lang_to_load"
            # Update arrays with loaded language texts
            update_language_arrays
            # Load help content for current language (steps)
            local help_file="${HELP_DIR}/help_${lang_to_load}.lang"
            [ ! -f "$help_file" ] && help_file="${HELP_DIR}/help_en.lang"
            [ -f "$help_file" ] && source "$help_file" 2>/dev/null
            # Load help content for notifiers
            local help_notif_file="${HELP_DIR}/help_notif_${lang_to_load}.lang"
            [ ! -f "$help_notif_file" ] && help_notif_file="${HELP_DIR}/help_notif_en.lang"
            [ -f "$help_notif_file" ] && source "$help_notif_file" 2>/dev/null
            return 0
        else
            echo "ERROR: Language file failed security validation"
            exit 1
        fi
    else
        # Critical fallback: use minimal hardcoded English
        echo "ERROR: No language files found in $LANG_DIR"
        exit 1
    fi
}

show_language_selector() {
    # Detect available languages dynamically
    detect_languages

    local selected=0
    local total=${#AVAILABLE_LANGS[@]}
    local cols=4  # Number of columns in the grid

    # Find index of current language
    for i in "${!AVAILABLE_LANGS[@]}"; do
        if [[ "${AVAILABLE_LANGS[$i]}" == "$CURRENT_LANG" ]]; then
            selected=$i
            break
        fi
    done

    # Hide cursor
    tput civis 2>/dev/null
    trap 'tput cnorm 2>/dev/null' RETURN

    while true; do
        # Calculate current row and column
        local cur_row=$((selected / cols))
        local cur_col=$((selected % cols))
        local total_rows=$(( (total + cols - 1) / cols ))

        clear
        print_box_top
        print_box_center "${BOLD}SELECT LANGUAGE / SELECCIONAR IDIOMA${BOX_NC}"
        print_box_sep
        print_box_line ""

        # Display languages in 4-column grid
        # Each cell: 18 chars (prefix[1] + bracket[1] + check[1] + bracket[1] + space[1] + name[13])
        for row in $(seq 0 $((total_rows - 1))); do
            local line=""
            for col in $(seq 0 $((cols - 1))); do
                local idx=$((row * cols + col))
                if [ $idx -lt $total ]; then
                    # Truncate/pad name to exactly 13 chars
                    local name
                    name=$(printf "%-13.13s" "${LANG_NAMES[$idx]}")

                    # Determine prefix and state
                    local prefix=" "
                    local check=" "
                    [ "${AVAILABLE_LANGS[$idx]}" = "$CURRENT_LANG" ] && check="x"
                    [ $idx -eq $selected ] && prefix=">"

                    # Build cell with consistent format (18 chars)
                    if [ $idx -eq $selected ]; then
                        # Selected: all in bright cyan
                        line+="${BRIGHT_CYAN}${prefix}[${check}]${BOX_NC} ${BRIGHT_CYAN}${name}${BOX_NC}"
                    elif [ "${AVAILABLE_LANGS[$idx]}" = "$CURRENT_LANG" ]; then
                        # Active language: [x] in green
                        line+=" ${GREEN}[x]${BOX_NC} ${name}"
                    else
                        # Inactive: [ ] in dim
                        line+=" ${DIM}[ ]${BOX_NC} ${name}"
                    fi
                else
                    # Empty cell: 18 spaces
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

        # Read key
        local key=""
        IFS= read -rsn1 key

        # Detect escape sequences (arrows or ESC alone)
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            case "$key" in
                '[A') # Up: same column, previous row
                    if [ $cur_row -gt 0 ]; then
                        ((selected-=cols))
                    else
                        # Go to last row of column
                        local last_row=$(( (total - 1) / cols ))
                        local new_idx=$((last_row * cols + cur_col))
                        [ $new_idx -ge $total ] && new_idx=$((new_idx - cols))
                        [ $new_idx -ge 0 ] && selected=$new_idx
                    fi
                    ;;
                '[B') # Down: same column, next row
                    local new_idx=$((selected + cols))
                    if [ $new_idx -lt $total ]; then
                        selected=$new_idx
                    else
                        # Return to first row of column
                        selected=$cur_col
                    fi
                    ;;
                '[C') # Right: next column
                    if [ $cur_col -lt $((cols - 1)) ]; then
                        local new_idx=$((selected + 1))
                        [ $new_idx -lt $total ] && selected=$new_idx
                    else
                        # Go to start of row
                        selected=$((cur_row * cols))
                    fi
                    ;;
                '[D') # Left: previous column
                    if [ $cur_col -gt 0 ]; then
                        ((selected--))
                    else
                        # Go to end of row
                        local new_idx=$((cur_row * cols + cols - 1))
                        [ $new_idx -ge $total ] && new_idx=$((total - 1))
                        selected=$new_idx
                    fi
                    ;;
                '') # ESC alone
                    tput cnorm 2>/dev/null
                    return
                    ;;
            esac
        elif [[ "$key" == "" ]]; then
            # ENTER - select language
            load_language "${AVAILABLE_LANGS[$selected]}"
            tput cnorm 2>/dev/null
            return
        fi
    done
}

# ============================================================================
# THEME SYSTEM
# ============================================================================

# Detect available themes dynamically from the themes/ folder
detect_themes() {
    AVAILABLE_THEMES=()
    THEME_NAMES=()

    # Search for all .theme files
    local theme_file
    for theme_file in "$THEME_DIR"/*.theme; do
        [ -f "$theme_file" ] || continue

        # Extract theme code (filename without extension)
        local code
        code=$(basename "$theme_file" .theme)

        # Extract theme name from file (THEME_NAME="...")
        local name
        name=$(grep -m1 '^THEME_NAME=' "$theme_file" 2>/dev/null | cut -d'"' -f2)

        # If it doesn't have THEME_NAME, use the code with first letter uppercase
        [ -z "$name" ] && name="${code^}"

        AVAILABLE_THEMES+=("$code")
        THEME_NAMES+=("$name")
    done

    # If no themes found, use default as fallback
    if [ ${#AVAILABLE_THEMES[@]} -eq 0 ]; then
        AVAILABLE_THEMES=("default")
        THEME_NAMES=("Default")
    fi
}

load_theme() {
    local theme_to_load="$1"

    # Priority: 1. Parameter, 2. Saved config, 3. Default
    if [ -z "$theme_to_load" ]; then
        if [ -n "$SAVED_THEME" ]; then
            theme_to_load="$SAVED_THEME"
        else
            theme_to_load="$DEFAULT_THEME"
        fi
    fi

    # Verify that the file exists
    local theme_file="${THEME_DIR}/${theme_to_load}.theme"
    if [ ! -f "$theme_file" ]; then
        theme_file="${THEME_DIR}/${DEFAULT_THEME}.theme"
        theme_to_load="$DEFAULT_THEME"
    fi

    # Load theme file (with security validation)
    if [ -f "$theme_file" ]; then
        if validate_source_file "$theme_file" "theme"; then
            # Clear previous theme variables (especially optional ones)
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
    # Map theme variables to script global variables
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

    # Additional semantic variables (used by UI functions)
    BOX_BG="${T_BOX_BG:-}"             # Box background (empty by default, blue for norton)
    BOX_NC="${T_BOX_NC:-$NC}"          # Reset inside boxes (preserves background in norton)
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
    # Detect available themes dynamically
    detect_themes

    local selected=0
    local total=${#AVAILABLE_THEMES[@]}
    local cols=4  # Number of columns in the grid

    # Find index of current theme
    for i in "${!AVAILABLE_THEMES[@]}"; do
        if [[ "${AVAILABLE_THEMES[$i]}" == "$CURRENT_THEME" ]]; then
            selected=$i
            break
        fi
    done

    # Hide cursor
    tput civis 2>/dev/null
    trap 'tput cnorm 2>/dev/null' RETURN

    while true; do
        # Calculate current row and column
        local cur_row=$((selected / cols))
        local cur_col=$((selected % cols))
        local total_rows=$(( (total + cols - 1) / cols ))

        clear
        print_box_top
        print_box_center "${BOLD}${MENU_THEME_TITLE:-SELECT THEME / SELECCIONAR TEMA}${BOX_NC}"
        print_box_sep
        print_box_line ""

        # Display themes in 4-column grid
        # Each cell: 18 chars (prefix[1] + bracket[1] + check[1] + bracket[1] + space[1] + name[13])
        for row in $(seq 0 $((total_rows - 1))); do
            local line=""
            for col in $(seq 0 $((cols - 1))); do
                local idx=$((row * cols + col))
                if [ $idx -lt $total ]; then
                    # Truncate/pad name to exactly 13 chars
                    local name
                    name=$(printf "%-13.13s" "${THEME_NAMES[$idx]}")

                    # Determine prefix and state
                    local prefix=" "
                    local check=" "
                    [ "${AVAILABLE_THEMES[$idx]}" = "$CURRENT_THEME" ] && check="x"
                    [ $idx -eq $selected ] && prefix=">"

                    # Build cell with consistent format (18 chars)
                    if [ $idx -eq $selected ]; then
                        # Selected: all in bright cyan
                        line+="${BRIGHT_CYAN}${prefix}[${check}]${BOX_NC} ${BRIGHT_CYAN}${name}${BOX_NC}"
                    elif [ "${AVAILABLE_THEMES[$idx]}" = "$CURRENT_THEME" ]; then
                        # Active theme: [x] in green
                        line+=" ${GREEN}[x]${BOX_NC} ${name}"
                    else
                        # Inactive: [ ] in dim
                        line+=" ${DIM}[ ]${BOX_NC} ${name}"
                    fi
                else
                    # Empty cell: 18 spaces
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

        # Read key
        local key=""
        IFS= read -rsn1 key

        # Detect escape sequences (arrows or ESC alone)
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            case "$key" in
                '[A') # Up: same column, previous row
                    if [ $cur_row -gt 0 ]; then
                        ((selected-=cols))
                    else
                        # Go to last row of column
                        local last_row=$(( (total - 1) / cols ))
                        local new_idx=$((last_row * cols + cur_col))
                        [ $new_idx -ge $total ] && new_idx=$((new_idx - cols))
                        [ $new_idx -ge 0 ] && selected=$new_idx
                    fi
                    ;;
                '[B') # Down: same column, next row
                    local new_idx=$((selected + cols))
                    if [ $new_idx -lt $total ]; then
                        selected=$new_idx
                    else
                        # Return to first row of column
                        selected=$cur_col
                    fi
                    ;;
                '[C') # Right: next column
                    if [ $cur_col -lt $((cols - 1)) ]; then
                        local new_idx=$((selected + 1))
                        [ $new_idx -lt $total ] && selected=$new_idx
                    else
                        # Go to start of row
                        selected=$((cur_row * cols))
                    fi
                    ;;
                '[D') # Left: previous column
                    if [ $cur_col -gt 0 ]; then
                        ((selected--))
                    else
                        # Go to end of row
                        local new_idx=$((cur_row * cols + cols - 1))
                        [ $new_idx -ge $total ] && new_idx=$((total - 1))
                        selected=$new_idx
                    fi
                    ;;
                '') # ESC alone
                    tput cnorm 2>/dev/null
                    return
                    ;;
            esac
        elif [[ "$key" == "" ]]; then
            # ENTER - select theme
            load_theme "${AVAILABLE_THEMES[$selected]}"
            tput cnorm 2>/dev/null
            return
        fi
    done
}

# ============================================================================
# NOTIFIER SYSTEM (Plugins)
# ============================================================================

detect_notifiers() {
    AVAILABLE_NOTIFIERS=()
    NOTIFIER_NAMES=()
    NOTIFIER_DESCRIPTIONS=()

    # Verify that the directory exists
    [ ! -d "$NOTIFIER_DIR" ] && return

    # Find all .notifier files
    local notifier_file
    for notifier_file in "$NOTIFIER_DIR"/*.notifier; do
        [ -f "$notifier_file" ] || continue

        # Extract notifier code (filename without extension)
        local code
        code=$(basename "$notifier_file" .notifier)

        # Extract metadata from file
        local name desc
        name=$(grep -m1 '^NOTIFIER_NAME=' "$notifier_file" 2>/dev/null | cut -d'"' -f2)
        desc=$(grep -m1 '^NOTIFIER_DESCRIPTION=' "$notifier_file" 2>/dev/null | cut -d'"' -f2)

        # If no NOTIFIER_NAME, use code with first letter capitalized
        [ -z "$name" ] && name="${code^}"
        [ -z "$desc" ] && desc="$name notifier"

        # Try to get translated description (NOTIF_DESC_TELEGRAM, NOTIF_DESC_DESKTOP, etc.)
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

    # Verify that the file exists
    [ ! -f "$notifier_file" ] && return 1

    # Load notifier file (with security validation for notifiers)
    if validate_notifier_file "$notifier_file"; then
        source "$notifier_file"
        NOTIFIER_LOADED["$notifier_code"]=1

        # Verify if it has the required functions
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
    # Load all enabled notifiers
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

    # Don't send if we're in dry-run (unless --notify is active)
    if [ "$DRY_RUN" = true ] && [ "$NOTIFY_ON_DRY_RUN" != true ]; then
        return 0
    fi

    # Add [DRY-RUN] prefix if we're in simulation mode
    if [ "$DRY_RUN" = true ]; then
        title="[DRY-RUN] $title"
    fi

    local any_sent=0

    # Send to all enabled notifiers
    for code in "${AVAILABLE_NOTIFIERS[@]}"; do
        if [ "${NOTIFIER_ENABLED[$code]}" = "1" ]; then
            # Load the notifier to have its functions available
            if load_notifier "$code"; then
                # Verify that it's configured
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
    # Send immediate critical notification (for serious errors)
    local title="$1"
    local message="$2"
    send_notification "$title" "$message" "critical"
}

build_summary_notification() {
    # Build detailed summary message for the final notification
    local hostname
    hostname=$(hostname 2>/dev/null || echo "unknown")

    local duration=$(($(date +%s) - START_TIME))
    local mins=$((duration / 60))
    local secs=$((duration % 60))

    # Calculate freed space
    local space_after_root space_freed_root
    space_after_root=$(df / --output=used 2>/dev/null | tail -1 | awk '{print $1}')
    space_freed_root=$(( (SPACE_BEFORE_ROOT - space_after_root) / 1024 ))
    [ $space_freed_root -lt 0 ] && space_freed_root=0

    # General status
    local status_emoji status_text
    if [ "$REBOOT_NEEDED" = true ]; then
        status_emoji="⚠️"
        status_text="${MSG_REBOOT_REQUIRED:-Reboot Required}"
    else
        status_emoji="✅"
        status_text="${MSG_COMPLETED:-Completed}"
    fi

    # Build list of steps
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

    # Build complete message
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
    # Detect available notifiers
    detect_notifiers

    local selected=0
    local total=${#AVAILABLE_NOTIFIERS[@]}

    # If no notifiers, show message
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

    # Hide cursor
    tput civis 2>/dev/null
    trap 'tput cnorm 2>/dev/null' RETURN

    while true; do
        clear
        print_box_top
        print_box_center "${BOLD}${MENU_NOTIF_TITLE:-NOTIFICATIONS}${BOX_NC}"
        print_box_sep
        print_box_line "${MENU_NOTIF_HELP:-Toggle notifications, configure, or test}"
        print_box_sep

        # Show list of notifiers
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

        # Read key
        local key=""
        IFS= read -rsn1 key

        # Detect escape sequences
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            case "$key" in
                '[A') # Up
                    ((selected--))
                    [ $selected -lt 0 ] && selected=$((total - 1))
                    ;;
                '[B') # Down
                    ((selected++))
                    [ $selected -ge $total ] && selected=0
                    ;;
                '') # ESC alone - return
                    tput cnorm 2>/dev/null
                    return
                    ;;
            esac
        elif [[ "$key" == " " ]]; then
            # Toggle enabled/disabled
            local code="${AVAILABLE_NOTIFIERS[$selected]}"
            if [ "${NOTIFIER_ENABLED[$code]}" = "1" ]; then
                NOTIFIER_ENABLED["$code"]=0
            else
                NOTIFIER_ENABLED["$code"]=1
            fi
        elif [[ "$key" == "c" || "$key" == "C" ]]; then
            # Configure notifier
            show_notifier_config "${AVAILABLE_NOTIFIERS[$selected]}"
        elif [[ "$key" == "t" || "$key" == "T" ]]; then
            # Test notifier
            test_notifier "${AVAILABLE_NOTIFIERS[$selected]}"
        elif [[ "$key" == "h" || "$key" == "H" ]]; then
            # Show help
            show_notifier_help "${AVAILABLE_NOTIFIERS[$selected]}"
        elif [[ "$key" == "s" || "$key" == "S" ]]; then
            # Save configuration
            save_config
            # Show brief confirmation
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

    # Load the notifier to get NOTIFIER_FIELDS
    [ ! -f "$notifier_file" ] && return
    source "$notifier_file" 2>/dev/null

    # Verify if it has configuration fields
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

    # Convert NOTIFIER_FIELDS to indexed arrays for numbered access
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

        # Show fields in 1 column with arrow navigation
        local i
        for ((i=0; i<num_fields; i++)); do
            local var_name="${field_vars[$i]}"
            local label="${field_labels[$i]}"
            local current_value="${!var_name}"
            local display_value="${current_value:-not set}"
            [[ "$var_name" == *"TOKEN"* || "$var_name" == *"PASSWORD"* || "$var_name" == *"KEY"* || "$var_name" == *"AUTH"* ]] && [ -n "$current_value" ] && display_value="${current_value:0:10}..."
            local status_color="${RED}"; [ -n "$current_value" ] && status_color="${GREEN}"

            # Show selection indicator
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

        # Read key
        local key=""
        IFS= read -rsn1 key

        # Detect escape sequences (arrows)
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            case "$key" in
                '[A') # Up
                    if [ $current_index -gt 0 ]; then
                        ((current_index--))
                    else
                        current_index=$((num_fields - 1))
                    fi
                    ;;
                '[B') # Down
                    if [ $current_index -lt $((num_fields - 1)) ]; then
                        ((current_index++))
                    else
                        current_index=0
                    fi
                    ;;
            esac
        elif [[ "$key" == "" ]]; then
            # ENTER - Edit selected field
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
                # Security warning for HTTP URLs (unencrypted)
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
            # Save configuration
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

    # Load the notifier to get NOTIFIER_NAME
    [ ! -f "$notifier_file" ] && return
    source "$notifier_file" 2>/dev/null

    # Search for translated help first (HELP_NOTIF_DESKTOP, HELP_NOTIF_TELEGRAM, etc.)
    local help_var="HELP_NOTIF_${code^^}"  # Convert to uppercase
    local help_text="${!help_var}"

    # Fallback to notifier_help() function from .notifier file
    if [ -z "$help_text" ] && type -t notifier_help &>/dev/null; then
        help_text=$(notifier_help 2>/dev/null)
    fi

    # If no help available, show message
    if [ -z "$help_text" ]; then
        clear
        print_box_top
        print_box_center "${BOLD}${MENU_HELP_TITLE:-HELP}: ${NOTIFIER_NAME}${BOX_NC}"
        print_box_sep
        print_box_center "${DIM}${MENU_NO_HELP:-No help available for this notifier}${BOX_NC}"
        print_box_sep
        print_box_center "${DIM}${MENU_PRESS_ANY:-Press any key to continue}${BOX_NC}"
        print_box_bottom
        read -rsn1
        return
    fi

    # Process text into lines with word-wrap
    local -a help_lines=()
    local max_width=68
    local line=""

    while IFS= read -r line || [ -n "$line" ]; do
        # Skip long separator lines
        if [[ "$line" =~ ^=+$ ]] || [[ "$line" =~ ^-+$ ]]; then
            continue
        fi
        # Empty line
        if [ -z "$line" ]; then
            help_lines+=("")
            continue
        fi
        # Word-wrap long lines
        if [ ${#line} -le $max_width ]; then
            help_lines+=("$line")
        else
            local remaining="$line"
            while [ ${#remaining} -gt $max_width ]; do
                local cut_pos=$max_width
                local segment="${remaining:0:$cut_pos}"
                local last_space=$(echo "$segment" | grep -bo ' ' | tail -1 | cut -d: -f1)
                if [ -n "$last_space" ] && [ "$last_space" -gt 20 ]; then
                    cut_pos=$last_space
                fi
                help_lines+=("${remaining:0:$cut_pos}")
                remaining="${remaining:$cut_pos}"
                remaining="${remaining# }"
            done
            [ -n "$remaining" ] && help_lines+=("$remaining")
        fi
    done <<< "$help_text"

    local total_lines=${#help_lines[@]}
    local scroll_offset=0
    local visible_lines=${HELP_WINDOW_HEIGHT:-12}

    # Hide cursor
    tput civis 2>/dev/null
    trap 'tput cnorm 2>/dev/null' RETURN

    while true; do
        clear
        print_box_top
        print_box_center "${BOLD}${MENU_HELP_TITLE:-HELP}: ${NOTIFIER_NAME}${BOX_NC}"
        print_box_sep

        # Scroll up indicator
        if [ $scroll_offset -gt 0 ]; then
            print_box_center "${DIM}▲ ▲ ▲${BOX_NC}"
        else
            print_box_line ""
        fi

        # Show visible lines
        local end_line=$((scroll_offset + visible_lines))
        [ $end_line -gt $total_lines ] && end_line=$total_lines

        local i
        for ((i = scroll_offset; i < end_line; i++)); do
            print_box_line "  ${help_lines[$i]}"
        done

        # Fill empty lines if needed
        local shown=$((end_line - scroll_offset))
        for ((i = shown; i < visible_lines; i++)); do
            print_box_line ""
        done

        # Scroll down indicator
        if [ $((scroll_offset + visible_lines)) -lt $total_lines ]; then
            print_box_center "${DIM}▼ ▼ ▼${BOX_NC}"
        else
            print_box_line ""
        fi

        print_box_sep
        local max_offset=$((total_lines - visible_lines))
        [ $max_offset -lt 0 ] && max_offset=0
        if [ $total_lines -gt $visible_lines ]; then
            print_box_center "${DIM}${MENU_HELP_SCROLL_HINT:-Use ↑↓ to scroll}${BOX_NC}"
        fi
        print_box_center "${CYAN}[ESC]${BOX_NC} ${MENU_HELP_CLOSE:-Close}  ${CYAN}[Q]${BOX_NC} ${MENU_HELP_CLOSE:-Close}"
        print_box_bottom

        # Read key
        local key=""
        IFS= read -rsn1 key

        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            case "$key" in
                '[A') # Up
                    [ $scroll_offset -gt 0 ] && ((scroll_offset--))
                    ;;
                '[B') # Down
                    [ $scroll_offset -lt $max_offset ] && ((scroll_offset++))
                    ;;
                '') # ESC alone - exit
                    tput cnorm 2>/dev/null
                    return
                    ;;
            esac
        elif [[ "$key" == "q" || "$key" == "Q" ]]; then
            tput cnorm 2>/dev/null
            return
        fi
    done
}

test_notifier() {
    local code="$1"

    clear
    print_box_top
    print_box_center "${BOLD}${MENU_TEST:-TEST}: ${code}${BOX_NC}"
    print_box_sep

    # Load the notifier
    if ! load_notifier "$code"; then
        print_box_center "${RED}${MENU_LOAD_FAILED:-Failed to load notifier}${BOX_NC}"
        print_box_bottom
        read -rsn1
        return
    fi

    # Verify dependencies
    print_box_line "${MENU_CHECKING_DEPS:-Checking dependencies...}"
    if type -t notifier_check_deps &>/dev/null && ! notifier_check_deps; then
        print_box_line "${RED}${MENU_DEPS_MISSING:-Dependencies missing}${BOX_NC}"
        print_box_line "${MENU_DEPS_INSTALL:-Please install:} ${NOTIFIER_DEPS:-N/A}"
        print_box_bottom
        read -rsn1
        return
    fi
    print_box_line "  ${GREEN}${ICON_OK}${BOX_NC} ${MENU_DEPS_OK:-Dependencies OK}"

    # Verify configuration
    print_box_line "${MENU_CHECKING_CONFIG:-Checking configuration...}"
    if type -t notifier_is_configured &>/dev/null && ! notifier_is_configured; then
        print_box_line "${YELLOW}${MENU_NOT_CONFIGURED:-Not configured}${BOX_NC}"
        print_box_line "${MENU_CONFIG_FIRST:-Please configure this notifier first}"
        print_box_bottom
        read -rsn1
        return
    fi
    print_box_line "  ${GREEN}${ICON_OK}${BOX_NC} ${MENU_CONFIG_OK:-Configuration OK}"

    # Send test notification
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
# COLORS AND ICONS (default values, will be overwritten by theme)
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
# UI ENTERPRISE - Additional colors and controls
# ============================================================================

# Bright colors
BRIGHT_GREEN='\033[1;32m'
BRIGHT_YELLOW='\033[1;33m'
BRIGHT_CYAN='\033[1;36m'
DIM='\033[2m'

# Semantic theme variables (default values)
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

# FIXED colors for metrics (do NOT change with theme)
FIXED_GREEN='\033[0;32m'
FIXED_RED='\033[0;31m'
FIXED_YELLOW='\033[1;33m'
FIXED_CYAN='\033[0;36m'

# Cursor control
CURSOR_HIDE='\033[?25l'
CURSOR_SHOW='\033[?25h'
CLEAR_LINE='\033[2K'

# Fixed-width ASCII icons (4 chars) - ensures alignment
ICON_SUM_OK='[OK]'
ICON_SUM_FAIL='[XX]'
ICON_SUM_WARN='[!!]'
ICON_SUM_SKIP='[--]'
ICON_SUM_RUN='[..]'
ICON_SUM_PEND='[  ]'

# Progress bar characters
PROGRESS_FILLED="█"
PROGRESS_EMPTY="░"

# Spinner frames (dots style)
SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
SPINNER_PID=""
SPINNER_ACTIVE=false

# UI design constants (80x24 terminal)
BOX_WIDTH=78
BOX_INNER=76

# Step status arrays for summary
declare -a STEP_STATUS_ARRAY
declare -a STEP_TIME_START
declare -a STEP_TIME_END

# Initialize status arrays
for i in {0..12}; do
    STEP_STATUS_ARRAY[$i]="pending"
    STEP_TIME_START[$i]=0
    STEP_TIME_END[$i]=0
done

# ============================================================================
# UI ENTERPRISE FUNCTIONS
# ============================================================================

# Remove ANSI codes from text - multiple methods for robustness
strip_ansi() {
    local text="$1"
    # Use printf %b to expand and sed to clean
    # This combination is more robust than echo -e
    printf '%b' "$text" | sed 's/\x1b\[[0-9;]*m//g; s/\x1b\[[0-9;]*[A-Za-z]//g'
}

# Calculate visible length - ultra-robust method
# Uses wc -L which calculates real column width
visible_length() {
    local text="$1"
    local clean
    clean=$(strip_ansi "$text")
    # wc -L returns the longest line width (handles Unicode correctly)
    local len
    len=$(printf '%s' "$clean" | wc -L)
    # Fallback to ${#} if wc -L fails
    [ -z "$len" ] || [ "$len" -eq 0 ] && len=${#clean}
    echo "$len"
}

# Generate N spaces
make_spaces() {
    local n="$1"
    [ "$n" -le 0 ] && echo "" && return
    printf '%*s' "$n" ''
}

# Print line with borders - ULTRA-ROBUST METHOD
# Uses ESC[K (clear to EOL) + absolute positioning to ensure alignment
print_box_line() {
    local content="$1"

    # Print left border + space (with background if defined)
    printf '%b' "${BOX_BORDER:-$BLUE}║${NC}${BOX_BG} "

    # Print content
    printf '%b' "$content"

    # Clear to end of line (respects current background color for Norton)
    printf '\033[K'

    # Position cursor at fixed column for right border (independent of Unicode)
    printf '\033[%dG' "$BOX_WIDTH"
    printf '%b\033[K\n' "${BOX_BORDER:-$BLUE}║${NC}"
}

# Print centered line - ULTRA-ROBUST METHOD
# Uses ESC[K (clear to EOL) + absolute positioning to ensure alignment
print_box_center() {
    local content="$1"

    # Calculate visible length for centering (only for left padding)
    local content_len
    content_len=$(visible_length "$content")

    # Calculate left padding for centering
    local total_pad=$((BOX_INNER - content_len))
    [ "$total_pad" -lt 0 ] && total_pad=0
    local left_pad=$((total_pad / 2))

    # Generate left spaces
    local left_spaces
    left_spaces=$(make_spaces "$left_pad")

    # Print: border + left spaces + content
    printf '%b' "${BOX_BORDER:-$BLUE}║${NC}${BOX_BG}"
    printf '%s' "$left_spaces"
    printf '%b' "$content"

    # Clear to end of line (respects current background color)
    printf '\033[K'

    # Position cursor at fixed column for right border
    printf '\033[%dG' "$BOX_WIDTH"
    printf '%b\033[K\n' "${BOX_BORDER:-$BLUE}║${NC}"
}

# Print horizontal separator
print_box_sep() {
    printf '%b' "${BOX_BORDER:-$BLUE}╠"
    printf '═%.0s' $(seq 1 $BOX_INNER)
    printf '%b\n' "╣${NC}"
}

# Print top frame
print_box_top() {
    local color="${1:-${BOX_BORDER:-$BLUE}}"
    printf '%b' "${color}╔"
    printf '═%.0s' $(seq 1 $BOX_INNER)
    printf '%b\n' "╗${NC}"
}

# Print bottom frame
print_box_bottom() {
    local color="${1:-${BOX_BORDER:-$BLUE}}"
    printf '%b' "${color}╚"
    printf '═%.0s' $(seq 1 $BOX_INNER)
    printf '%b\n' "╝${NC}"
}

# Get ASCII icon by status
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

# Update step status
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

# Spinner - Animation during long operations
start_spinner() {
    local message="${1:-Processing...}"
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
# BASE FUNCTIONS AND UTILITIES
# ============================================================================

init_log() {
    mkdir -p "$LOG_DIR"
    chmod 700 "$LOG_DIR"  # SECURITY: Restrict log directory access to root only
    LOG_FILE="$LOG_DIR/sys-update-$(date +%Y%m%d_%H%M%S).log"
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"

    # Clean old logs (keep last 5 executions)
    # Uses find for safe filename handling
    find "$LOG_DIR" -maxdepth 1 -name "sys-update-*.log" -type f -printf '%T@ %p\n' 2>/dev/null | \
        sort -rn | tail -n +6 | cut -d' ' -f2- | xargs -r -d'\n' rm -f
}

log() {
    local level="$1"; shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Only write to log file if it exists (init_log has been called)
    if [[ -n "$LOG_FILE" && -w "$(dirname "$LOG_FILE" 2>/dev/null)" ]]; then
        echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE" 2>/dev/null
    fi

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

    # SECURITY: Use bash -c instead of eval to avoid double expansion
    # Note: safe_run should only be used with internally built commands,
    # NEVER with unsanitized user input
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
    # SECURITY: Close flock file descriptor and remove lock file
    exec 200>&- 2>/dev/null  # Close fd 200 (releases flock automatically)
    # Only log if lock file existed and was removed
    if [[ -f "$LOCK_FILE" ]]; then
        rm -f "$LOCK_FILE" 2>/dev/null
        log "INFO" "Lock file removed"
    fi
}

trap cleanup EXIT INT TERM

# ============================================================================
# VALIDATION AND CHECK FUNCTIONS
# ============================================================================

detect_distro() {
    # Detect distribution using /etc/os-release
    if [ ! -f /etc/os-release ]; then
        die "${MSG_DISTRO_NOT_DETECTED}"
    fi

    # SECURITY: Validate /etc/os-release before sourcing
    # Only allow simple variable assignments (VAR=value or VAR="value")
    if grep -qE '(\$\(|`|\||;|&&|\|\|)' /etc/os-release 2>/dev/null; then
        die "ERROR: /etc/os-release contains unsafe content"
    fi

    # Load os-release variables
    source /etc/os-release

    DISTRO_ID="${ID:-unknown}"
    DISTRO_NAME="${PRETTY_NAME:-$NAME}"
    DISTRO_VERSION="${VERSION_ID:-unknown}"
    DISTRO_CODENAME="${VERSION_CODENAME:-$UBUNTU_CODENAME}"

    # Determine family and mirror server based on distribution
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
            # Linux Mint is based on Ubuntu
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
            # Check if it's a Debian/Ubuntu derivative
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
        print_box_line "${RED}[XX] ERROR: ${MSG_ROOT_REQUIRED:-This script requires root permissions}${NC}"
        print_box_bottom "$RED"
        echo ""
        echo -e "  ${YELLOW}${MSG_CORRECT_USAGE:-Correct usage:}${NC}"
        echo -e "    ${GREEN}sudo ./autoclean.sh${NC}"
        echo ""
        echo -e "  ${CYAN}${MSG_AVAILABLE_OPTIONS:-Available options:}${NC}"
        echo -e "    ${GREEN}sudo ./autoclean.sh --help${NC}      ${MSG_VIEW_HELP:-View full help}"
        echo -e "    ${GREEN}sudo ./autoclean.sh --dry-run${NC}   ${MSG_SIMULATE_CHANGES:-Simulate without changes}"
        echo -e "    ${GREEN}sudo ./autoclean.sh -y${NC}          ${MSG_UNATTENDED_MODE:-Unattended mode}"
        echo ""
        exit 1
    fi
}

check_lock() {
    # SECURITY: Use flock for atomic locking (avoids TOCTOU race conditions)
    # File descriptor 200 is kept open during entire execution
    exec 200>"$LOCK_FILE"
    if ! flock -n 200; then
        # Couldn't obtain the lock, check who has it
        local pid
        pid=$(cat "$LOCK_FILE" 2>/dev/null)
        echo -e "${RED}[XX] Another instance of the script is already running (PID: ${pid:-unknown})${NC}"
        exit 1
    fi
    # Write our PID to the file (for info, the real lock is flock)
    echo $$ >&200

    # Extra verification of APT locks
    if fuser /var/lib/dpkg/lock* /var/lib/apt/lists/lock* 2>/dev/null | grep -q .; then
        echo -e "${RED}[XX] ${MSG_APT_BUSY:-APT is busy. Close Synaptic/Discover and try again.}${NC}"
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
    log "INFO" "${MSG_VALIDATING_DEPS:-Validating step dependencies...}"

    # If system upgrade is enabled, repos MUST be updated
    if [ "$STEP_UPGRADE_SYSTEM" = 1 ] && [ "$STEP_UPDATE_REPOS" = 0 ]; then
        die "${MSG_UPGRADE_WITHOUT_REPOS:-You cannot upgrade the system (STEP_UPGRADE_SYSTEM=1) without updating repos (STEP_UPDATE_REPOS=0). Enable STEP_UPDATE_REPOS.}"
    fi

    # If kernel cleanup is enabled in Testing, recommend snapshot
    if [ "$STEP_CLEANUP_KERNELS" = 1 ] && [ "$STEP_SNAPSHOT_TIMESHIFT" = 0 ]; then
        log "WARN" "${MSG_KERNEL_CLEANUP_RISKY:-Kernel cleanup without Timeshift snapshot may be risky}"
        if [ "$UNATTENDED" = false ]; then
            echo -e "${YELLOW}[!!] ${MSG_KERNEL_CLEANUP_RISKY:-Kernel cleanup without Timeshift snapshot may be risky}${NC}"
            read -p "${MSG_CONTINUE_ANYWAY:-Continue anyway? (y/N):} " -n 1 -r
            echo
            [[ ! $REPLY =~ ^[YySs]$ ]] && die "${MSG_ABORTED_BY_USER:-Aborted by user}"
        fi
    fi
    
    log "SUCCESS" "${MSG_DEPS_VALIDATION_OK:-Dependency validation OK}"
}

show_step_summary() {
    [ "$QUIET" = true ] && return

    local total_items=${#MENU_STEP_VARS[@]}
    local cols=4

    print_box_top
    print_box_center "${BOLD}STEP CONFIGURATION - SUMMARY${NC}"
    print_box_sep
    print_box_center "${DISTRO_NAME} | ${DISTRO_FAMILY^} (${DISTRO_CODENAME:-N/A})"
    print_box_sep
    print_box_line "${BOLD}STEPS TO EXECUTE${NC}"

    # Show in 4 columns (6 rows) - fixed format 18 chars per cell
    for row in {0..5}; do
        local line=""
        for col in {0..3}; do
            local idx=$((row * cols + col))
            if [ $idx -lt $total_items ]; then
                local var_name="${MENU_STEP_VARS[$idx]}"
                local var_value="${!var_name}"
                # Name with fixed width of 13 chars
                local name
                name=$(printf "%-13.13s" "${STEP_SHORT_NAMES[$idx]}")

                if [ "$var_value" = "1" ]; then
                    line+=" ${GREEN}[x]${NC} ${name}"
                else
                    line+=" ${DIM}[--]${NC}${name}"
                fi
            else
                # Empty cell: 18 spaces
                line+="                  "
            fi
        done
        print_box_line "$line"
    done

    print_box_sep
    print_box_line "${MENU_TOTAL}: ${GREEN}${TOTAL_STEPS}${NC}/${total_items} ${MENU_STEPS}    ${MENU_EST_TIME}: ${CYAN}~$((TOTAL_STEPS / 2 + 1)) ${MENU_MIN}${NC}"
    print_box_bottom
    echo ""

    if [ "$UNATTENDED" = false ] && [ "$DRY_RUN" = false ]; then
        read -p "${PROMPT_CONTINUE_CONFIG} " -n 1 -r
        echo
        [[ ! $REPLY =~ $PROMPT_YES_PATTERN ]] && die "${MSG_CANCELLED_BY_USER}"
    fi
}

# ============================================================================
# CONTEXTUAL HELP SYSTEM
# ============================================================================

show_step_help() {
    local step_index="$1"
    local step_number=$((step_index + 1))
    local help_var="HELP_STEP_${step_number}"
    local help_content="${!help_var}"

    # Fallback if no help available
    if [ -z "$help_content" ]; then
        help_content="${HELP_NOT_AVAILABLE:-No help available for this step.}"
    fi

    # Convert content to array of lines with word-wrap at 72 chars
    local -a help_lines=()
    local max_width=$((BOX_INNER - 4))

    while IFS= read -r line || [ -n "$line" ]; do
        if [ -z "$line" ]; then
            help_lines+=("")
        elif [ ${#line} -le $max_width ]; then
            help_lines+=("$line")
        else
            # Word wrap long lines
            local words=($line)
            local current_line=""
            for word in "${words[@]}"; do
                if [ -z "$current_line" ]; then
                    current_line="$word"
                elif [ $((${#current_line} + ${#word} + 1)) -le $max_width ]; then
                    current_line+=" $word"
                else
                    help_lines+=("$current_line")
                    current_line="$word"
                fi
            done
            [ -n "$current_line" ] && help_lines+=("$current_line")
        fi
    done <<< "$help_content"

    local total_lines=${#help_lines[@]}
    local visible_lines=${HELP_WINDOW_HEIGHT:-12}
    local max_scroll=$((total_lines - visible_lines))
    [ $max_scroll -lt 0 ] && max_scroll=0
    local scroll_offset=0

    # Hide cursor
    tput civis 2>/dev/null
    trap 'tput cnorm 2>/dev/null' RETURN

    while true; do
        clear

        # Header with step name
        print_box_top
        print_box_center "${BOLD}${CYAN}${MENU_HELP_TITLE:-HELP}${BOX_NC}: ${STEP_SHORT_NAMES[$step_index]}"
        print_box_sep

        # Scrollable content area
        local visible_end=$((scroll_offset + visible_lines))
        [ $visible_end -gt $total_lines ] && visible_end=$total_lines

        for ((i=scroll_offset; i<visible_end; i++)); do
            print_box_line "  ${help_lines[$i]}"
        done

        # Fill empty lines if content is shorter than window
        local shown_lines=$((visible_end - scroll_offset))
        for ((i=shown_lines; i<visible_lines; i++)); do
            print_box_line ""
        done

        # Scroll indicators (only if scrollable)
        print_box_sep
        if [ $total_lines -gt $visible_lines ]; then
            local scroll_indicator=""
            [ $scroll_offset -gt 0 ] && scroll_indicator+="${CYAN}▲${BOX_NC} "
            scroll_indicator+="${MENU_HELP_SCROLL_HINT:-Use ↑↓ to scroll}"
            [ $scroll_offset -lt $max_scroll ] && scroll_indicator+=" ${CYAN}▼${BOX_NC}"
            print_box_center "$scroll_indicator"
        else
            print_box_line ""
        fi

        # Footer with controls
        print_box_sep
        print_box_center "${CYAN}[ESC]${BOX_NC} ${MENU_HELP_CLOSE:-Close}    ${CYAN}[Q]${BOX_NC} ${MENU_HELP_CLOSE:-Close}"
        print_box_bottom

        # Read key
        local key=""
        IFS= read -rsn1 key

        # Handle keys
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            case "$key" in
                '[A') # UP arrow
                    [ $scroll_offset -gt 0 ] && ((scroll_offset--))
                    ;;
                '[B') # DOWN arrow
                    [ $scroll_offset -lt $max_scroll ] && ((scroll_offset++))
                    ;;
                '') # ESC alone
                    break
                    ;;
            esac
        elif [[ "$key" == "q" || "$key" == "Q" ]]; then
            break
        fi
    done

    tput cnorm 2>/dev/null
}

# ============================================================================
# INTERACTIVE CONFIGURATION MENU
# ============================================================================

show_interactive_menu() {
    local current_index=0
    local total_items=${#MENU_STEP_NAMES[@]}
    local menu_running=true

    # Hide cursor
    tput civis 2>/dev/null
    trap 'tput cnorm 2>/dev/null' RETURN

    while [ "$menu_running" = true ]; do
        # Count active steps
        local active_count=0
        for var_name in "${MENU_STEP_VARS[@]}"; do
            [ "${!var_name}" = "1" ] && ((active_count++))
        done

        # Calculate current row and column (4 columns × 6 rows)
        local cols=4
        local cur_row=$((current_index / cols))
        local cur_col=$((current_index % cols))

        # Clear screen and show enterprise interface
        clear
        print_box_top
        print_box_center "${BOLD}${MENU_TITLE}${BOX_NC}"
        print_box_sep
        print_box_center "${DISTRO_NAME} | ${DISTRO_FAMILY^} (${DISTRO_CODENAME:-N/A})"
        print_box_sep
        print_box_line "${BOLD}${MENU_STEPS_TITLE}${BOX_NC} ${DIM}${MENU_STEPS_HELP}${BOX_NC}"

        # Show steps in 4 columns (6 rows) - 23 total steps
        # Each cell: 18 fixed chars (prefix[1] + bracket[1] + check[1] + bracket[1] + space[1] + name[13])
        for row in {0..5}; do
            local line=""
            for col in {0..3}; do
                local idx=$((row * cols + col))
                if [ $idx -lt $total_items ]; then
                    local var_name="${MENU_STEP_VARS[$idx]}"
                    local var_value="${!var_name}"
                    # Truncate/pad name to exactly 13 chars (adjusted for 4 columns)
                    local name
                    name=$(printf "%-13.13s" "${STEP_SHORT_NAMES[$idx]}")

                    # Determine prefix and state
                    local prefix=" "
                    local check=" "
                    [ "$var_value" = "1" ] && check="x"
                    [ $idx -eq $current_index ] && prefix=">"

                    # Build cell with CONSISTENT format (18 fixed chars)
                    if [ $idx -eq $current_index ]; then
                        # Selected: all in bright cyan
                        line+="${BRIGHT_CYAN}${prefix}[${check}]${BOX_NC} ${BRIGHT_CYAN}${name}${BOX_NC}"
                    elif [ "$var_value" = "1" ]; then
                        # Active: [x] in green
                        line+=" ${GREEN}[x]${BOX_NC} ${name}"
                    else
                        # Inactive: [ ] in dim
                        line+=" ${DIM}[ ]${BOX_NC} ${name}"
                    fi
                else
                    # Empty cell: 18 spaces
                    line+="                  "
                fi
            done
            print_box_line "$line"
        done

        print_box_sep
        print_box_line "${CYAN}>${BOX_NC} ${MENU_STEP_DESCRIPTIONS[$current_index]:0:68}"
        print_box_sep
        print_box_line "${MENU_SELECTED}: ${GREEN}${active_count}${BOX_NC}/${total_items}    ${MENU_PROFILE}: $(config_exists && echo "${GREEN}${MENU_PROFILE_SAVED}${BOX_NC}" || echo "${DIM}${MENU_PROFILE_UNSAVED}${BOX_NC}")"
        print_box_sep
        print_box_center "${CYAN}[ENTER]${BOX_NC} ${MENU_CTRL_ENTER} ${CYAN}[H]${BOX_NC} ${MENU_CTRL_HELP:-Help} ${CYAN}[G]${BOX_NC} ${MENU_CTRL_SAVE} ${CYAN}[Q]${BOX_NC} ${MENU_CTRL_QUIT}"
        print_box_center "${CYAN}[S]${BOX_NC} ${MENU_CTRL_SELECT:-Sel/Desel} ${CYAN}[L]${BOX_NC} ${MENU_CTRL_LANG} ${CYAN}[T]${BOX_NC} ${MENU_CTRL_THEME:-Theme} ${CYAN}[O]${BOX_NC} ${MENU_CTRL_NOTIF:-Notif}"
        print_box_bottom

        # Read key
        local key=""
        IFS= read -rsn1 key

        # Detect escape sequences (arrows) - navigation 4 columns × 6 rows
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            case "$key" in
                '[A') # Up: same column, previous row
                    if [ $cur_row -gt 0 ]; then
                        ((current_index-=cols))
                    else
                        # Go to last row of column
                        local last_row=$(( (total_items - 1) / cols ))
                        local new_idx=$((last_row * cols + cur_col))
                        [ $new_idx -ge $total_items ] && new_idx=$((new_idx - cols))
                        [ $new_idx -ge 0 ] && current_index=$new_idx
                    fi
                    ;;
                '[B') # Down: same column, next row
                    local new_idx=$((current_index + cols))
                    if [ $new_idx -lt $total_items ]; then
                        current_index=$new_idx
                    else
                        # Return to first row of column
                        current_index=$cur_col
                    fi
                    ;;
                '[C') # Right: next column
                    if [ $cur_col -lt $((cols - 1)) ] && [ $((current_index + 1)) -lt $total_items ]; then
                        ((current_index++))
                    else
                        # Go to start of row
                        current_index=$((cur_row * cols))
                    fi
                    ;;
                '[D') # Left: previous column
                    if [ $cur_col -gt 0 ]; then
                        ((current_index--))
                    else
                        # Go to end of row
                        local new_idx=$((cur_row * cols + cols - 1))
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
                's'|'S')
                    # Toggle: if any is deactivated, activate all; if all active, deactivate all
                    local all_active=1
                    for var_name in "${MENU_STEP_VARS[@]}"; do
                        declare -n ref="$var_name"
                        [ "$ref" != "1" ] && all_active=0 && break
                    done
                    if [ "$all_active" = "1" ]; then
                        for var_name in "${MENU_STEP_VARS[@]}"; do declare -n ref="$var_name"; ref=0; done
                    else
                        for var_name in "${MENU_STEP_VARS[@]}"; do declare -n ref="$var_name"; ref=1; done
                    fi
                    ;;
                'g'|'G') save_config ;;
                'd'|'D') config_exists && delete_config ;;
                'l'|'L') show_language_selector ;;
                't'|'T') show_theme_selector ;;
                'o'|'O') show_notification_menu ;;
                'h'|'H') show_step_help "$current_index" ;;
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

    # Save initial space
    SPACE_BEFORE_ROOT=$(df / --output=used | tail -1 | awk '{print $1}')
    SPACE_BEFORE_BOOT=$(df /boot --output=used 2>/dev/null | tail -1 | awk '{print $1}' || echo 0)

    log "SUCCESS" "${MSG_DISK_SPACE_OK}"
}

# ============================================================================
# STEP 1: CHECK CONNECTIVITY
# ============================================================================

step_check_connectivity() {
    [ "$STEP_CHECK_CONNECTIVITY" = 0 ] && return

    print_step "${MSG_CHECKING_CONNECTIVITY}"

    # Use the mirror corresponding to detected distribution
    local mirror_to_check="${DISTRO_MIRROR:-deb.debian.org}"

    echo "→ ${MSG_CHECKING_CONNECTION_TO} $mirror_to_check..."

    if ping -c 1 -W 3 "$mirror_to_check" >/dev/null 2>&1; then
        echo "→ ${MSG_CONNECTION_OK}"
        STAT_CONNECTIVITY="$ICON_OK"
        log "SUCCESS" "${MSG_CONNECTION_OK}"
    else
        # Try with a generic backup server
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
# STEP 2: CHECK AND INSTALL DEPENDENCIES
# ============================================================================

step_check_dependencies() {
    [ "$STEP_CHECK_DEPENDENCIES" = 0 ] && return

    print_step "${MSG_CHECKING_TOOLS}"

    declare -A TOOLS
    declare -A TOOL_STEPS

    # Define tools and which step requires them
    TOOLS[timeshift]="System snapshots (CRITICAL for security)"
    TOOL_STEPS[timeshift]=$STEP_SNAPSHOT_TIMESHIFT

    TOOLS[needrestart]="Smart reboot detection"
    TOOL_STEPS[needrestart]=$STEP_CHECK_REBOOT

    TOOLS[fwupdmgr]="Firmware management"
    TOOL_STEPS[fwupdmgr]=$STEP_CHECK_FIRMWARE

    TOOLS[flatpak]="Flatpak application manager"
    TOOL_STEPS[flatpak]=$STEP_UPDATE_FLATPAK

    TOOLS[snap]="Snap application manager"
    TOOL_STEPS[snap]=$STEP_UPDATE_SNAP

    TOOLS[smartctl]="SMART disk diagnostics"
    TOOL_STEPS[smartctl]=$STEP_CHECK_SMART

    local missing=()
    local missing_names=()
    local skipped_tools=()
    
    for tool in "${!TOOLS[@]}"; do
        # Only verify if the associated step is active
        if [ "${TOOL_STEPS[$tool]}" = "1" ]; then
            if ! command -v "$tool" &>/dev/null; then
                missing+=("$tool")
                missing_names+=("${TOOLS[$tool]}")
            fi
        else
            # Step is disabled, don't verify this tool
            skipped_tools+=("$tool")
            log "INFO" "$(printf "${MSG_SKIPPING_TOOL_CHECK:-Skipping verification of %s (step disabled)}" "$tool")"
        fi
    done

    # Show skipped tools if any
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

                # Determine which packages to install
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
# STEP 3: CHECK APT REPOSITORY INTEGRITY
# ============================================================================

step_check_repos() {
    [ "$STEP_CHECK_REPOS" = 0 ] && return

    print_step "${MSG_CHECKING_REPOS:-Checking APT repositories integrity...}"

    local has_error=false
    local has_warning=false
    local invalid_repos=()
    local unreachable_repos=()

    echo "→ ${MSG_VERIFYING_SOURCES_LIST:-Verifying sources.list files...}"

    # Verify sources.list files syntax
    if [ -f /etc/apt/sources.list ]; then
        if ! apt-cache policy &>/dev/null; then
            has_error=true
            invalid_repos+=("/etc/apt/sources.list")
            log "ERROR" "Invalid syntax in /etc/apt/sources.list"
        fi
    fi

    # Verify files in sources.list.d/
    if [ -d /etc/apt/sources.list.d/ ]; then
        shopt -s nullglob
        for repo_file in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
            [ -f "$repo_file" ] || continue
            # Verify there are no obvious syntax errors
            if grep -qE '^\s*deb\s+[^[:space:]]+\s*$' "$repo_file" 2>/dev/null; then
                has_warning=true
                invalid_repos+=("$repo_file (incomplete entry)")
            fi
        done
        shopt -u nullglob
    fi

    # Verify expired or missing GPG keys
    echo "→ ${MSG_CHECKING_GPG_KEYS:-Checking GPG keys...}"
    local expired_keys=$(apt-key list 2>/dev/null | grep -B1 "expired" | grep -oP '(?<=/)[\w]+(?=\s)' | head -5)
    if [ -n "$expired_keys" ]; then
        has_warning=true
        log "WARN" "Expired GPG keys found: $expired_keys"
        echo -e "${YELLOW}→ ${MSG_EXPIRED_KEYS:-Expired GPG keys found}${NC}"
    fi

    # Verify connectivity to main repositories
    echo "→ ${MSG_TESTING_REPO_CONNECTIVITY:-Testing repository connectivity...}"
    if ! apt-get update -qq --print-uris 2>&1 | head -1 &>/dev/null; then
        has_warning=true
        log "WARN" "Some repositories may be unreachable"
    fi

    # Final result
    if $has_error; then
        STAT_CHECK_REPOS="$ICON_FAIL"
        log "ERROR" "${MSG_REPOS_ERRORS:-Repository configuration errors found}"
        if [ ${#invalid_repos[@]} -gt 0 ]; then
            echo -e "${RED}→ ${MSG_INVALID_REPOS:-Invalid repository files}:${NC}"
            printf '   • %s\n' "${invalid_repos[@]}"
        fi
    elif $has_warning; then
        STAT_CHECK_REPOS="$ICON_WARN"
        log "WARN" "${MSG_REPOS_WARNINGS:-Repository warnings found}"
    else
        STAT_CHECK_REPOS="$ICON_OK"
        echo "→ ${MSG_REPOS_OK:-All repositories configured correctly}"
        log "SUCCESS" "${MSG_REPOS_OK:-All repositories configured correctly}"
    fi
}

# ============================================================================
# STEP 4: BACKUP CONFIGURATIONS (TAR)
# ============================================================================

step_backup_tar() {
    [ "$STEP_BACKUP_TAR" = 0 ] && return

    print_step "${MSG_CREATING_BACKUP}"
    
    mkdir -p "$BACKUP_DIR"
    local backup_date=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/backup_${backup_date}.tar.gz"
    
    # Create APT configurations tarball
    if tar czf "$backup_file" \
        /etc/apt/sources.list* \
        /etc/apt/sources.list.d/ \
        /etc/apt/trusted.gpg.d/ 2>/dev/null; then
        
        # List of installed packages
        dpkg --get-selections > "$BACKUP_DIR/packages_${backup_date}.list" 2>/dev/null
        
        echo "→ ${MSG_BACKUP_CREATED}: $backup_file"
        STAT_BACKUP_TAR="$ICON_OK"
        log "SUCCESS" "${MSG_BACKUP_CREATED}"

        # Clean old backups (keep last 5 runs)
        # Uses find for safe filename handling
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
# STEP 4: SNAPSHOT TIMESHIFT
# ============================================================================

# Verify if Timeshift is correctly configured
check_timeshift_configured() {
    local config_file="/etc/timeshift/timeshift.json"

    # Verify that the configuration file exists
    if [ ! -f "$config_file" ]; then
        return 1
    fi

    # Verify that it has a configured device (not empty)
    if grep -q '"backup_device_uuid" *: *""' "$config_file" 2>/dev/null; then
        return 1
    fi

    # Verify that the device is not "none" or similar
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

    # Verify if Timeshift is CONFIGURED
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

    # Ask if user wants to skip (only in interactive mode)
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

    # Create snapshot
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
            # In unattended mode, abort for safety
            die "${MSG_ABORTED_NO_SNAPSHOT}"
        fi
    fi
}

# ============================================================================
# STEP 5: UPDATE REPOSITORIES
# ============================================================================

step_update_repos() {
    [ "$STEP_UPDATE_REPOS" = 0 ] && return

    print_step "${MSG_UPDATING_REPOS}"

    # Repair dpkg before updating
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
# STEP 6: UPGRADE SYSTEM (APT)
# ============================================================================

step_upgrade_system() {
    [ "$STEP_UPGRADE_SYSTEM" = 0 ] && return

    print_step "${MSG_ANALYZING_UPDATES}"

    # Count available updates
    local updates_output=$(apt list --upgradable 2>/dev/null)
    local updates=$(echo "$updates_output" | grep -c '\[upgradable' || echo 0)
    updates=${updates//[^0-9]/}
    updates=${updates:-0}
    updates=$((updates + 0))

    if [ "$updates" -gt 0 ]; then
        printf "→ ${MSG_PACKAGES_TO_UPDATE}\n" "$updates"

        # Heuristic risk analysis (mass deletions)
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

        # Execute upgrade
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
# STEP 7: UPDATE FLATPAK
# ============================================================================

step_update_flatpak() {
    [ "$STEP_UPDATE_FLATPAK" = 0 ] && return

    print_step "${MSG_UPDATING_FLATPAK}"

    if ! command -v flatpak &>/dev/null; then
        echo "→ ${MSG_FLATPAK_NOT_INSTALLED}"
        STAT_FLATPAK="$ICON_SKIP"
        return
    fi

    # 1. Update appstream metadata (catalog of available apps)
    safe_run "flatpak update --appstream -y" "Error updating appstream"

    # 2. Update installed applications
    if safe_run "flatpak update -y" "Error"; then
        # 3. Clean orphaned refs
        safe_run "flatpak uninstall --unused -y" "Error"

        # 4. Repair installation
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
# STEP 8: UPDATE SNAP
# ============================================================================

step_update_snap() {
    [ "$STEP_UPDATE_SNAP" = 0 ] && return

    print_step "${MSG_UPDATING_SNAP}"

    if ! command -v snap &>/dev/null; then
        echo "→ ${MSG_SNAP_NOT_INSTALLED}"
        STAT_SNAP="$ICON_SKIP"
        return
    fi

    # 1. Update all snaps
    if safe_run "snap refresh" "Error"; then
        # 2. Clean old revisions (disabled snaps) to free disk space
        local disabled_snaps
        disabled_snaps=$(snap list --all 2>/dev/null | awk '/disabled/{print $1, $3}')

        if [[ -n "$disabled_snaps" ]]; then
            echo "→ ${MSG_SNAP_CLEANING_OLD:-Cleaning old snap revisions...}"
            while read -r name rev; do
                [[ -z "$name" ]] && continue
                snap remove "$name" --revision="$rev" &>/dev/null
            done <<< "$disabled_snaps"
        fi

        echo "→ ${MSG_SNAP_UPDATED}"
        STAT_SNAP="$ICON_OK"
        log "SUCCESS" "${MSG_SNAP_UPDATED}"
    else
        STAT_SNAP="$ICON_FAIL"
        log "ERROR" "${MSG_SNAP_ERROR}"
    fi
}

# ============================================================================
# STEP 9: CHECK FIRMWARE
# ============================================================================

step_check_firmware() {
    [ "$STEP_CHECK_FIRMWARE" = 0 ] && return

    print_step "${MSG_CHECKING_FIRMWARE}"

    if ! command -v fwupdmgr &>/dev/null; then
        echo "→ ${MSG_FWUPD_NOT_INSTALLED}"
        STAT_FIRMWARE="$ICON_SKIP"
        return
    fi

    # Check if refresh is needed (more than 7 days)
    local last_refresh=$(stat -c %Y /var/lib/fwupd/metadata.xml 2>/dev/null || echo 0)
    local current_time=$(date +%s)
    local days_old=$(( (current_time - last_refresh) / 86400 ))
    
    if [ "$days_old" -gt 7 ]; then
        safe_run "fwupdmgr refresh --force" "${MSG_FIRMWARE_REFRESH_ERROR}"
        echo "→ ${MSG_FIRMWARE_METADATA_UPDATED}"
    else
        printf "→ ${MSG_FIRMWARE_METADATA_DAYS}\n" "$days_old"
    fi

    # Check if updates are available
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
# STEP 10: APT CLEANUP
# ============================================================================

step_cleanup_apt() {
    [ "$STEP_CLEANUP_APT" = 0 ] && return

    print_step "${MSG_CLEANING_APT}"

    # Autoremove (orphan packages)
    if safe_run "apt autoremove -y" "Error"; then
        echo "→ ${MSG_ORPHANS_REMOVED}"
    else
        STAT_CLEAN_APT="$ICON_FAIL"
        return
    fi

    # Purge (packages with residual config)
    local pkgs_rc=$(dpkg -l 2>/dev/null | grep "^rc" | awk '{print $2}')
    if [ -n "$pkgs_rc" ]; then
        local rc_count=$(echo "$pkgs_rc" | wc -l)
        # SECURITY: xargs -r prevents running with empty args
        if echo "$pkgs_rc" | xargs -r apt purge -y >/dev/null 2>&1; then
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

    # Autoclean or clean
    if safe_run "apt $APT_CLEAN_MODE" "Error"; then
        echo "→ ${MSG_APT_CACHE_CLEANED}"
    fi

    STAT_CLEAN_APT="$ICON_OK"
    log "SUCCESS" "${MSG_APT_CLEANUP_OK}"
}

# ============================================================================
# STEP 11: OLD KERNELS CLEANUP
# ============================================================================

step_cleanup_kernels() {
    [ "$STEP_CLEANUP_KERNELS" = 0 ] && return

    print_step "${MSG_CLEANING_KERNELS}"

    # Get current kernel
    local current_kernel=$(uname -r)
    local current_kernel_pkg="linux-image-${current_kernel}"

    log "INFO" "${MSG_CURRENT_KERNEL}: $current_kernel"
    echo "→ ${MSG_KERNEL_IN_USE}: $current_kernel"

    # Get all installed kernels
    local installed_kernels=$(dpkg -l 2>/dev/null | awk '/^ii.*linux-image-[0-9]/ {print $2}' | grep -v "meta")

    if [ -z "$installed_kernels" ]; then
        echo "→ ${MSG_NO_KERNELS_FOUND}"
        STAT_CLEAN_KERNEL="$ICON_OK"
        return
    fi

    # Count kernels
    local kernel_count=$(echo "$installed_kernels" | wc -l)
    echo "→ ${MSG_INSTALLED_KERNELS}: $kernel_count"
    
    # Keep: current kernel + the N most recent
    local kernels_to_keep=$(echo "$installed_kernels" | sort -V | tail -n "$KERNELS_TO_KEEP")

    # Critical validation: ensure current kernel is in the list
    if ! echo "$kernels_to_keep" | grep -q "$current_kernel_pkg"; then
        log "WARN" "${MSG_KERNEL_FORCING_INCLUSION:-Current kernel not in most recent list, forcing inclusion}"
        kernels_to_keep=$(echo -e "${current_kernel_pkg}\n${kernels_to_keep}" | sort -V | tail -n "$KERNELS_TO_KEEP")
    fi
    
    # Identify kernels to remove
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

        # Confirmation in interactive mode
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

        # Remove kernels
        # SECURITY: xargs -r prevents running with empty args
        if echo "$kernels_to_remove" | xargs -r apt purge -y >> "$LOG_FILE" 2>&1; then
            echo "→ ${MSG_KERNELS_REMOVED}"
            STAT_CLEAN_KERNEL="$ICON_OK"
            log "SUCCESS" "${MSG_KERNELS_REMOVED}"

            # Regenerate GRUB
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
# STEP 12: DISK CLEANUP (LOGS AND CACHE)
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

    # Old temporary files
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
# STEP 13: DOCKER/PODMAN CLEANUP
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
# STEP 14: DISK HEALTH CHECK (SMART)
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

    # Detect SATA/SAS disks
    for disk in /dev/sd?; do
        [ -b "$disk" ] && disks+=("$disk")
    done

    # Detect NVMe disks
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

        # Get health status
        health_status=$(smartctl -H "$disk" 2>/dev/null | grep -E "SMART overall-health|SMART Health Status")

        if echo "$health_status" | grep -qiE "PASSED|OK"; then
            echo "  ${FIXED_GREEN}[OK]${NC} $disk"
        elif echo "$health_status" | grep -qi "FAILED"; then
            echo "  ${FIXED_RED}[FAIL]${NC} $disk - ${MSG_SMART_DISK_FAILING}"
            log "ERROR" "$disk: ${MSG_SMART_DISK_FAILING}"
            has_error=true
        else
            # Verify critical attributes
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
# STEP 5: VERIFY PACKAGE INTEGRITY (DEBSUMS)
# ============================================================================

step_check_debsums() {
    [ "$STEP_CHECK_DEBSUMS" = 0 ] && return

    print_step "${MSG_CHECKING_DEBSUMS:-Verifying package integrity with debsums...}"

    # Verify if debsums is installed
    if ! command -v debsums &>/dev/null; then
        echo -e "${YELLOW}→ ${MSG_DEBSUMS_NOT_INSTALLED:-debsums not installed, skipping integrity check}${NC}"
        STAT_CHECK_DEBSUMS="$ICON_SKIP"
        log "INFO" "debsums not installed, skipping"
        return
    fi

    local has_error=false
    local has_warning=false
    local modified_files=()

    echo "→ ${MSG_VERIFYING_PACKAGES:-Verifying installed packages...}"

    # Run debsums and capture modified files
    # Only verify configuration (-c) to be faster
    local debsums_output
    debsums_output=$(debsums -s 2>/dev/null | head -50)

    if [ -n "$debsums_output" ]; then
        has_warning=true
        while IFS= read -r line; do
            modified_files+=("$line")
        done <<< "$debsums_output"

        log "WARN" "Modified packages detected: ${#modified_files[@]} files"
        echo -e "${YELLOW}→ ${MSG_MODIFIED_PACKAGES:-Modified package files detected}: ${#modified_files[@]}${NC}"

        # Show first 5 files
        if [ ${#modified_files[@]} -gt 0 ] && [ "$QUIET" = false ]; then
            echo "   ${MSG_SAMPLE_FILES:-Sample files}:"
            printf '   • %s\n' "${modified_files[@]:0:5}"
            [ ${#modified_files[@]} -gt 5 ] && echo "   ... ${MSG_AND_MORE:-and} $((${#modified_files[@]} - 5)) ${MSG_MORE_FILES:-more files}"
        fi
    fi

    # Final result
    if $has_error; then
        STAT_CHECK_DEBSUMS="$ICON_FAIL"
        log "ERROR" "${MSG_DEBSUMS_ERRORS:-Package integrity errors found}"
    elif $has_warning; then
        STAT_CHECK_DEBSUMS="$ICON_WARN"
        log "WARN" "${MSG_DEBSUMS_WARNINGS:-Package integrity warnings found}"
    else
        STAT_CHECK_DEBSUMS="$ICON_OK"
        echo "→ ${MSG_DEBSUMS_OK:-All package files verified correctly}"
        log "SUCCESS" "${MSG_DEBSUMS_OK:-All package files verified correctly}"
    fi
}

# ============================================================================
# STEP 6: CHECK SECURITY UPDATES
# ============================================================================

step_check_security() {
    [ "$STEP_CHECK_SECURITY" = 0 ] && return

    print_step "${MSG_CHECKING_SECURITY:-Checking for security updates...}"

    local security_updates=0
    local has_warning=false

    echo "→ ${MSG_SCANNING_SECURITY:-Scanning for security updates...}"

    # Method 1: Use apt-get with grep for security
    if command -v apt-get &>/dev/null; then
        # Count pending security updates
        security_updates=$(apt-get -s upgrade 2>/dev/null | grep -i "^Inst" | grep -ci "security" || echo "0")
        security_updates=${security_updates:-0}
    fi

    # Method 2: If unattended-upgrades exists, verify its status
    if [ -f /var/log/unattended-upgrades/unattended-upgrades.log ]; then
        local last_update=$(stat -c %Y /var/log/unattended-upgrades/unattended-upgrades.log 2>/dev/null || echo "0")
        local now=$(date +%s)
        local days_since=$(( (now - last_update) / 86400 ))

        if [ "$days_since" -gt 7 ]; then
            has_warning=true
            log "WARN" "Unattended upgrades have not run in $days_since days"
            echo -e "${YELLOW}→ ${MSG_UNATTENDED_OLD:-Unattended upgrades have not run in $days_since days}${NC}"
        fi
    fi

    # Check if there are critical security updates
    if [ "$security_updates" -gt 0 ]; then
        has_warning=true
        echo -e "${YELLOW}→ ${MSG_SECURITY_UPDATES_PENDING:-$security_updates security updates pending}${NC}"
        log "WARN" "$security_updates security updates pending"

        # Offer to install security updates
        if [ "$UNATTENDED" = false ] && [ "$DRY_RUN" = false ]; then
            read -p "${PROMPT_INSTALL_SECURITY:-Install security updates now? [y/N]} " -n 1 -r
            echo
            if [[ $REPLY =~ $PROMPT_YES_PATTERN ]]; then
                echo "→ ${MSG_INSTALLING_SECURITY:-Installing security updates...}"
                apt-get -y upgrade -o Dir::Etc::SourceList=/etc/apt/sources.list.d/security.list 2>/dev/null || \
                apt-get -y --only-upgrade install $(apt-get -s upgrade 2>/dev/null | grep -i "security" | grep "^Inst" | cut -d" " -f2) 2>/dev/null
            fi
        fi
    else
        echo "→ ${MSG_NO_SECURITY_UPDATES:-No pending security updates}"
    fi

    # Final result
    if $has_warning; then
        STAT_CHECK_SECURITY="$ICON_WARN"
    else
        STAT_CHECK_SECURITY="$ICON_OK"
        log "SUCCESS" "${MSG_SECURITY_OK:-System security is up to date}"
    fi
}

# ============================================================================
# STEP 7: AUDIT CRITICAL FILE PERMISSIONS
# ============================================================================

step_check_permissions() {
    [ "$STEP_CHECK_PERMISSIONS" = 0 ] && return

    print_step "${MSG_CHECKING_PERMISSIONS:-Auditing critical file permissions...}"

    local has_error=false
    local has_warning=false
    local issues=()

    echo "→ ${MSG_CHECKING_SUID_SGID:-Checking SUID/SGID files...}"

    # Informative mode: count SUID/SGID files without judging
    local suid_count
    suid_count=$(find /usr/bin /usr/sbin /bin /sbin -perm /6000 -type f 2>/dev/null | wc -l)
    suid_count=${suid_count:-0}

    # Report count (normal: 15-40 on desktop, 10-25 on server)
    echo "→ ${MSG_SUID_COUNT:-SUID/SGID files found}: $suid_count"
    log "INFO" "SUID/SGID files count: $suid_count"

    # Only alert if there is an unusually high count (possible problem)
    if [ "$suid_count" -gt 50 ]; then
        has_warning=true
        echo -e "${YELLOW}→ ${MSG_SUID_HIGH_COUNT:-High number of SUID/SGID files, consider reviewing}${NC}"
        echo "   → Run: find /usr -perm /6000 -type f"
    fi

    # Verify critical file permissions
    echo "→ ${MSG_CHECKING_CRITICAL_FILES:-Checking critical file permissions...}"

    local critical_files=(
        "/etc/passwd:644"
        "/etc/shadow:640"
        "/etc/group:644"
        "/etc/gshadow:640"
        "/etc/sudoers:440"
    )

    for entry in "${critical_files[@]}"; do
        local file="${entry%%:*}"
        local expected_perm="${entry##*:}"

        if [ -f "$file" ]; then
            local actual_perm=$(stat -c "%a" "$file" 2>/dev/null)
            if [ "$actual_perm" != "$expected_perm" ]; then
                has_warning=true
                issues+=("$file: expected $expected_perm, got $actual_perm")
                log "WARN" "$file has incorrect permissions: $actual_perm (expected $expected_perm)"
            fi
        fi
    done

    if [ ${#issues[@]} -gt 0 ]; then
        echo -e "${YELLOW}→ ${MSG_PERMISSION_ISSUES:-Permission issues found}:${NC}"
        printf '   • %s\n' "${issues[@]}"
    fi

    # Final result
    if $has_error; then
        STAT_CHECK_PERMISSIONS="$ICON_FAIL"
        log "ERROR" "${MSG_PERMISSIONS_ERRORS:-Critical permission errors found}"
    elif $has_warning; then
        STAT_CHECK_PERMISSIONS="$ICON_WARN"
        log "WARN" "${MSG_PERMISSIONS_WARNINGS:-Permission warnings found}"
    else
        STAT_CHECK_PERMISSIONS="$ICON_OK"
        echo "→ ${MSG_PERMISSIONS_OK:-All critical permissions are correct}"
        log "SUCCESS" "${MSG_PERMISSIONS_OK:-All critical permissions are correct}"
    fi
}

# ============================================================================
# STEP 8: AUDIT UNNECESSARY SERVICES
# ============================================================================

step_audit_services() {
    [ "$STEP_AUDIT_SERVICES" = 0 ] && return

    print_step "${MSG_AUDITING_SERVICES:-Auditing system services...}"

    local has_warning=false
    local suspicious_services=()
    local listening_ports=()

    echo "→ ${MSG_CHECKING_ENABLED_SERVICES:-Checking enabled services...}"

    # Potentially unnecessary services on servers
    local unnecessary_services=(
        "cups"           # Print server
        "avahi-daemon"   # mDNS/Bonjour
        "bluetooth"      # Bluetooth
        "ModemManager"   # Modem support
        "whoopsie"       # Ubuntu error reporting
        "apport"         # Crash reporting
    )

    for service in "${unnecessary_services[@]}"; do
        if systemctl is-enabled "$service" &>/dev/null; then
            suspicious_services+=("$service")
        fi
    done

    if [ ${#suspicious_services[@]} -gt 0 ]; then
        has_warning=true
        echo -e "${YELLOW}→ ${MSG_UNNECESSARY_SERVICES:-Potentially unnecessary services enabled}:${NC}"
        printf '   • %s\n' "${suspicious_services[@]}"
        log "INFO" "Potentially unnecessary services: ${suspicious_services[*]}"
    fi

    # Check listening ports
    echo "→ ${MSG_CHECKING_LISTENING_PORTS:-Checking listening ports...}"

    if command -v ss &>/dev/null; then
        local open_ports=$(ss -tlnp 2>/dev/null | grep LISTEN | wc -l)
        echo "→ ${MSG_OPEN_PORTS:-Open listening ports}: $open_ports"

        # Show non-standard ports (>1024) that are not localhost
        local unusual_ports=$(ss -tlnp 2>/dev/null | grep LISTEN | grep -v "127.0.0.1" | grep -v "::1" | awk '{print $4}' | grep -E ":[0-9]{4,5}$" | head -5)
        if [ -n "$unusual_ports" ]; then
            has_warning=true
            echo -e "${YELLOW}→ ${MSG_UNUSUAL_PORTS:-Unusual ports open}:${NC}"
            echo "$unusual_ports" | sed 's/^/   • /'
        fi
    fi

    # Check failed services
    local failed=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
    failed=${failed//[^0-9]/}
    if [ "${failed:-0}" -gt 0 ]; then
        has_warning=true
        echo -e "${YELLOW}→ ${MSG_FAILED_SERVICES:-Failed services}: $failed${NC}"
    fi

    # Final result
    if $has_warning; then
        STAT_AUDIT_SERVICES="$ICON_WARN"
        log "WARN" "${MSG_SERVICES_AUDIT_WARNINGS:-Service audit found items to review}"
    else
        STAT_AUDIT_SERVICES="$ICON_OK"
        echo "→ ${MSG_SERVICES_OK:-Service configuration looks good}"
        log "SUCCESS" "${MSG_SERVICES_OK:-Service configuration looks good}"
    fi
}

# ============================================================================
# STEP 20: CLEAN ABANDONED SESSIONS
# ============================================================================

step_cleanup_sessions() {
    [ "$STEP_CLEANUP_SESSIONS" = 0 ] && return

    print_step "${MSG_CLEANING_SESSIONS:-Cleaning abandoned sessions...}"

    local cleaned=0
    local has_warning=false

    # Clean orphan tmux sessions
    if command -v tmux &>/dev/null; then
        echo "→ ${MSG_CHECKING_TMUX:-Checking tmux sessions...}"
        local tmux_sessions=$(tmux list-sessions 2>/dev/null | wc -l)
        tmux_sessions=${tmux_sessions:-0}

        if [ "$tmux_sessions" -gt 0 ]; then
            echo "   ${MSG_TMUX_SESSIONS:-Active tmux sessions}: $tmux_sessions"
            # Don't clean automatically, just report
        fi
    fi

    # Clean orphan screen sessions
    if command -v screen &>/dev/null; then
        echo "→ ${MSG_CHECKING_SCREEN:-Checking screen sessions...}"
        local dead_screens=$(screen -ls 2>/dev/null | grep -c "Dead")
        dead_screens=${dead_screens:-0}

        if [ "$dead_screens" -gt 0 ]; then
            echo "→ ${MSG_CLEANING_DEAD_SCREENS:-Cleaning $dead_screens dead screen sessions...}"
            screen -wipe &>/dev/null
            cleaned=$((cleaned + dead_screens))
        fi
    fi

    # Clean orphan lock files in /tmp
    echo "→ ${MSG_CHECKING_LOCK_FILES:-Checking orphan lock files...}"
    local orphan_locks=$(find /tmp -maxdepth 1 -name "*.lock" -mtime +1 2>/dev/null | wc -l)
    orphan_locks=${orphan_locks:-0}

    if [ "$orphan_locks" -gt 0 ]; then
        has_warning=true
        echo -e "${YELLOW}→ ${MSG_ORPHAN_LOCKS:-Orphan lock files found}: $orphan_locks${NC}"
        log "INFO" "Found $orphan_locks orphan lock files in /tmp"
    fi

    # Clean old session files
    echo "→ ${MSG_CLEANING_OLD_SESSIONS:-Cleaning old session files...}"
    local old_sessions=$(find /var/lib/systemd/linger -type f -mtime +30 2>/dev/null | wc -l)
    old_sessions=${old_sessions:-0}

    # Final result
    if [ "$cleaned" -gt 0 ]; then
        STAT_CLEANUP_SESSIONS="$ICON_OK"
        echo "→ ${MSG_SESSIONS_CLEANED:-Cleaned $cleaned abandoned sessions}"
        log "SUCCESS" "Cleaned $cleaned abandoned sessions"
    elif $has_warning; then
        STAT_CLEANUP_SESSIONS="$ICON_WARN"
        log "WARN" "${MSG_SESSIONS_WARNINGS:-Session cleanup warnings}"
    else
        STAT_CLEANUP_SESSIONS="$ICON_OK"
        echo "→ ${MSG_NO_SESSIONS_TO_CLEAN:-No abandoned sessions to clean}"
        log "SUCCESS" "${MSG_NO_SESSIONS_TO_CLEAN:-No abandoned sessions to clean}"
    fi
}

# ============================================================================
# STEP 21: VERIFY/CONFIGURE LOGROTATE
# ============================================================================

step_check_logrotate() {
    [ "$STEP_CHECK_LOGROTATE" = 0 ] && return

    print_step "${MSG_CHECKING_LOGROTATE:-Checking logrotate configuration...}"

    local has_error=false
    local has_warning=false
    local issues=()

    # Check if logrotate is installed
    if ! command -v logrotate &>/dev/null; then
        echo -e "${YELLOW}→ ${MSG_LOGROTATE_NOT_INSTALLED:-logrotate not installed}${NC}"
        STAT_CHECK_LOGROTATE="$ICON_WARN"
        log "WARN" "logrotate not installed"
        return
    fi

    echo "→ ${MSG_VERIFYING_LOGROTATE_CONFIG:-Verifying logrotate configuration...}"

    # Check main configuration
    if [ ! -f /etc/logrotate.conf ]; then
        has_error=true
        issues+=("Missing /etc/logrotate.conf")
    fi

    # Check configuration syntax
    if ! logrotate -d /etc/logrotate.conf &>/dev/null; then
        has_warning=true
        issues+=("Logrotate configuration has warnings")
        log "WARN" "Logrotate configuration has syntax issues"
    fi

    # Check last execution
    if [ -f /var/lib/logrotate/status ]; then
        local last_run=$(stat -c %Y /var/lib/logrotate/status 2>/dev/null || echo "0")
        local now=$(date +%s)
        local days_since=$(( (now - last_run) / 86400 ))

        if [ "$days_since" -gt 2 ]; then
            has_warning=true
            echo -e "${YELLOW}→ ${MSG_LOGROTATE_OLD:-Logrotate has not run in $days_since days}${NC}"
            log "WARN" "Logrotate has not run in $days_since days"
        else
            echo "→ ${MSG_LOGROTATE_RECENT:-Logrotate ran recently (within $days_since days)}"
        fi
    fi

    # Check for large logs that should be rotated
    echo "→ ${MSG_CHECKING_LARGE_LOGS:-Checking for large log files...}"
    local large_logs=$(find /var/log -type f -size +100M 2>/dev/null | head -5)
    if [ -n "$large_logs" ]; then
        has_warning=true
        echo -e "${YELLOW}→ ${MSG_LARGE_LOGS_FOUND:-Large log files found (>100MB)}:${NC}"
        echo "$large_logs" | while read -r logfile; do
            local size=$(du -h "$logfile" 2>/dev/null | cut -f1)
            echo "   • $logfile ($size)"
        done
    fi

    # Final result
    if $has_error; then
        STAT_CHECK_LOGROTATE="$ICON_FAIL"
        log "ERROR" "${MSG_LOGROTATE_ERRORS:-Logrotate configuration errors}"
        printf '   • %s\n' "${issues[@]}"
    elif $has_warning; then
        STAT_CHECK_LOGROTATE="$ICON_WARN"
        log "WARN" "${MSG_LOGROTATE_WARNINGS:-Logrotate warnings found}"
    else
        STAT_CHECK_LOGROTATE="$ICON_OK"
        echo "→ ${MSG_LOGROTATE_OK:-Logrotate configuration is correct}"
        log "SUCCESS" "${MSG_LOGROTATE_OK:-Logrotate configuration is correct}"
    fi
}

# ============================================================================
# STEP 22: VERIFY INODE SPACE
# ============================================================================

step_check_inodes() {
    [ "$STEP_CHECK_INODES" = 0 ] && return

    print_step "${MSG_CHECKING_INODES:-Checking inode usage...}"

    local has_error=false
    local has_warning=false
    local critical_partitions=()
    local warning_partitions=()

    echo "→ ${MSG_ANALYZING_INODES:-Analyzing inode usage on all partitions...}"

    # Get inode usage from all partitions
    while IFS= read -r line; do
        # Skip the header line
        [[ "$line" =~ ^Filesystem ]] && continue

        local filesystem=$(echo "$line" | awk '{print $1}')
        local iuse=$(echo "$line" | awk '{print $5}' | tr -d '%')
        local mountpoint=$(echo "$line" | awk '{print $6}')

        # Skip virtual filesystems
        [[ "$filesystem" =~ ^(tmpfs|devtmpfs|none|udev) ]] && continue

        iuse=${iuse:-0}

        if [ "$iuse" -ge 95 ]; then
            has_error=true
            critical_partitions+=("$mountpoint: ${iuse}%")
        elif [ "$iuse" -ge 80 ]; then
            has_warning=true
            warning_partitions+=("$mountpoint: ${iuse}%")
        fi

        # Show all partitions
        if [ "$iuse" -ge 80 ]; then
            echo -e "  ${FIXED_YELLOW}[!!]${NC} $mountpoint: ${iuse}% ${MSG_INODES_USED:-inodes used}"
        else
            echo -e "  ${FIXED_GREEN}[OK]${NC} $mountpoint: ${iuse}% ${MSG_INODES_USED:-inodes used}"
        fi
    done < <(df -i 2>/dev/null | grep -v "^Filesystem")

    # If there are critical partitions, search for directories with many files
    if $has_error || $has_warning; then
        echo ""
        echo "→ ${MSG_SEARCHING_INODE_HOGS:-Searching for directories with many files...}"

        # Search for directories with many small files
        local inode_hogs=$(find /var /tmp /home -xdev -type d 2>/dev/null | while read -r dir; do
            count=$(find "$dir" -maxdepth 1 -type f 2>/dev/null | wc -l)
            if [ "$count" -gt 1000 ]; then
                echo "$count $dir"
            fi
        done | sort -rn | head -5)

        if [ -n "$inode_hogs" ]; then
            echo -e "${YELLOW}→ ${MSG_DIRS_MANY_FILES:-Directories with many files}:${NC}"
            echo "$inode_hogs" | while read -r count dir; do
                echo "   • $dir ($count files)"
            done
        fi
    fi

    # Final result
    if $has_error; then
        STAT_CHECK_INODES="$ICON_FAIL"
        log "ERROR" "${MSG_INODES_CRITICAL:-Critical inode usage detected}"
        send_critical_notification "INODE SPACE CRITICAL" "One or more partitions on $(hostname) are running out of inodes. Immediate action required."
    elif $has_warning; then
        STAT_CHECK_INODES="$ICON_WARN"
        log "WARN" "${MSG_INODES_WARNING:-High inode usage detected}"
    else
        STAT_CHECK_INODES="$ICON_OK"
        echo "→ ${MSG_INODES_OK:-Inode usage is healthy on all partitions}"
        log "SUCCESS" "${MSG_INODES_OK:-Inode usage is healthy on all partitions}"
    fi
}

# ============================================================================
# STEP 23: VERIFY REBOOT NECESSITY
# ============================================================================

step_check_reboot() {
    [ "$STEP_CHECK_REBOOT" = 0 ] && return

    print_step "${MSG_CHECKING_REBOOT}"

    # Check for reboot-required file
    if [ -f /var/run/reboot-required ]; then
        REBOOT_NEEDED=true
        log "WARN" "${MSG_REBOOT_FILE_DETECTED}"
        echo "→ ${MSG_REBOOT_FILE_DETECTED}"
    fi

    # Check for failed services
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
    
    # Needrestart - Advanced verification
    if command -v needrestart &>/dev/null; then
        echo "→ ${MSG_ANALYZING_NEEDRESTART}"

        # Run needrestart in batch mode
        local needrestart_output=$(needrestart -b 2>/dev/null)

        # Extract kernel information
        local running_kernel=$(echo "$needrestart_output" | grep "NEEDRESTART-KCUR:" | awk '{print $2}')
        local expected_kernel=$(echo "$needrestart_output" | grep "NEEDRESTART-KEXP:" | awk '{print $2}')
        local kernel_status=$(echo "$needrestart_output" | grep "NEEDRESTART-KSTA:" | awk '{print $2}')

        log "INFO" "Running kernel: $running_kernel"
        log "INFO" "Expected kernel: $expected_kernel"
        log "INFO" "KSTA status: $kernel_status"

        # VERIFICATION 1: Outdated kernel (DIRECT COMPARISON)
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

        # VERIFICATION 2: Services that need restart
        local services_restart=$(echo "$needrestart_output" | grep "NEEDRESTART-SVC:" | wc -l)
        services_restart=${services_restart//[^0-9]/}
        services_restart=${services_restart:-0}
        services_restart=$((services_restart + 0))

        if [ "$services_restart" -gt 0 ]; then
            log "INFO" "$(printf "$MSG_SERVICES_NEED_RESTART" "$services_restart")"
            printf "→ ${MSG_SERVICES_NEED_RESTART}\n" "$services_restart"
        fi
        
        # VERIFICATION 3: Critical libraries (REFINED LOGIC)
        local critical_libs=$(echo "$needrestart_output" | grep "NEEDRESTART-UCSTA:" | awk '{print $2}')
        critical_libs=$(echo "$critical_libs" | tr -d '[:space:]')
        
        log "INFO" "${MSG_UCSTA_STATUS:-UCSTA status (critical libraries)}: '$critical_libs'"
        
        # CRITICAL LOGIC:
        # UCSTA=1 can be persistent from a previous update
        # We only mark reboot if:
        # 1. UCSTA=1 (there are critical changes) AND
        # 2. Packages were installed in THIS session AND
        # 3. Those packages include system libraries
        
        if [ -n "$critical_libs" ] && [ "$critical_libs" = "1" ]; then
            # Check if there were SYSTEM updates in this session
            # We use the UPGRADE_PERFORMED flag which is set in step_upgrade_system()
            if [ "$UPGRADE_PERFORMED" = true ]; then
                REBOOT_NEEDED=true
                log "WARN" "${MSG_CRITICAL_LIBS_UPDATED}"
                echo -e "${YELLOW}→ ${MSG_CRITICAL_LIBS_UPDATED}${NC}"
            else
                # UCSTA=1 is from a previous update, not from now
                log "INFO" "UCSTA=1 persistent from previous update (not this session)"
                echo "→ ${MSG_CRITICAL_LIBS_STABLE}"
            fi
        else
            log "INFO" "${MSG_NO_CRITICAL_LIBS_CHANGES}"
            echo "→ ${MSG_NO_CRITICAL_LIBS_CHANGES}"
        fi
        
        # Try to restart services automatically
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
    
    # Set final state
    if [ "$REBOOT_NEEDED" = true ]; then
        STAT_REBOOT="${RED}$ICON_WARN ${MSG_STAT_REQUIRED}${NC}"
        log "WARN" "${MSG_REBOOT_REQUIRED}"
    else
        STAT_REBOOT="${GREEN}$ICON_OK ${MSG_STAT_NOT_NEEDED}${NC}"
        log "INFO" "${MSG_REBOOT_NOT_REQUIRED}"
    fi
}

# ============================================================================
# FINAL SUMMARY
# ============================================================================

show_final_summary() {
    [ "$QUIET" = true ] && exit 0

    # Calculate execution time
    local end_time=$(date +%s)
    local execution_time=$((end_time - START_TIME))
    local minutes=$((execution_time / 60))
    local seconds=$((execution_time % 60))
    local duration_str=$(printf "%02d:%02d" $minutes $seconds)

    # Calculate freed space
    local space_after_root=$(df / --output=used | tail -1 | awk '{print $1}')
    local space_after_boot=$(df /boot --output=used 2>/dev/null | tail -1 | awk '{print $1}' || echo 0)
    local space_freed_root=$(( (SPACE_BEFORE_ROOT - space_after_root) / 1024 ))
    local space_freed_boot=$(( (SPACE_BEFORE_BOOT - space_after_boot) / 1024 ))
    [ $space_freed_root -lt 0 ] && space_freed_root=0
    [ $space_freed_boot -lt 0 ] && space_freed_boot=0
    local total_freed=$((space_freed_root + space_freed_boot))

    # Map STAT_* to STEP_STATUS_ARRAY for summary (23 steps, logical order by phases)
    # Phase 1 (1-8): Connectivity, Dependencies, APT Repos, SMART, Debsums, Security, Permissions, Services
    # Phase 2 (9-10): TAR Backup, Timeshift
    # Phase 3 (11-15): Update Repos, Upgrade, Flatpak, Snap, Firmware
    # Phase 4 (16-22): APT, Kernels, Disk, Docker, Sessions, Logrotate, Inodes
    # Phase 5 (23): Reboot
    local step_vars=(
        "STEP_CHECK_CONNECTIVITY" "STEP_CHECK_DEPENDENCIES" "STEP_CHECK_REPOS"
        "STEP_CHECK_SMART" "STEP_CHECK_DEBSUMS" "STEP_CHECK_SECURITY"
        "STEP_CHECK_PERMISSIONS" "STEP_AUDIT_SERVICES"
        "STEP_BACKUP_TAR" "STEP_SNAPSHOT_TIMESHIFT"
        "STEP_UPDATE_REPOS" "STEP_UPGRADE_SYSTEM" "STEP_UPDATE_FLATPAK"
        "STEP_UPDATE_SNAP" "STEP_CHECK_FIRMWARE"
        "STEP_CLEANUP_APT" "STEP_CLEANUP_KERNELS" "STEP_CLEANUP_DISK"
        "STEP_CLEANUP_DOCKER" "STEP_CLEANUP_SESSIONS" "STEP_CHECK_LOGROTATE"
        "STEP_CHECK_INODES" "STEP_CHECK_REBOOT"
    )
    local stat_vars=(
        "STAT_CONNECTIVITY" "STAT_DEPENDENCIES" "STAT_CHECK_REPOS"
        "STAT_SMART" "STAT_CHECK_DEBSUMS" "STAT_CHECK_SECURITY"
        "STAT_CHECK_PERMISSIONS" "STAT_AUDIT_SERVICES"
        "STAT_BACKUP_TAR" "STAT_SNAPSHOT"
        "STAT_REPO" "STAT_UPGRADE" "STAT_FLATPAK" "STAT_SNAP" "STAT_FIRMWARE"
        "STAT_CLEAN_APT" "STAT_CLEAN_KERNEL" "STAT_CLEAN_DISK"
        "STAT_DOCKER" "STAT_CLEANUP_SESSIONS" "STAT_CHECK_LOGROTATE"
        "STAT_CHECK_INODES" "STAT_REBOOT"
    )

    # Count results and determine states (23 steps: indexes 0-22)
    local success_count=0 error_count=0 skipped_count=0 warning_count=0
    for i in {0..22}; do
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

    # Determine overall state
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

    # Send notification via plugins system
    local notification_severity="success"
    [ $error_count -gt 0 ] && notification_severity="error"
    [ "$REBOOT_NEEDED" = true ] && notification_severity="warning"

    local notification_message
    notification_message=$(build_summary_notification)
    send_notification "Autoclean ${overall_status}" "$notification_message" "$notification_severity"

    log "INFO" "=========================================="
    log "INFO" "$(printf "${MSG_MAINTENANCE_COMPLETED:-Maintenance completed in %dm %ds}" "$minutes" "$seconds")"
    log "INFO" "=========================================="

    # === ENTERPRISE SUMMARY 3 COLUMNS (78 chars) ===
    echo ""
    print_box_top
    print_box_center "${BOLD}${MENU_SUMMARY_TITLE}${BOX_NC}"
    print_box_sep
    print_box_line "${MSG_SUMMARY_STATUS}: ${overall_color}${overall_icon} ${overall_status}${BOX_NC}"
    print_box_line "${MSG_SUMMARY_DURATION}: ${CYAN}${duration_str}${BOX_NC}"
    print_box_sep
    print_box_line "${BOLD}${MSG_SUMMARY_METRICS}${BOX_NC}"
    print_box_line "${MSG_SUMMARY_COMPLETED_COUNT}: ${GREEN}${success_count}${BOX_NC}    ${MSG_SUMMARY_ERRORS}: ${RED}${error_count}${BOX_NC}    ${MSG_SUMMARY_SKIPPED}: ${YELLOW}${skipped_count}${BOX_NC}    ${MSG_SUMMARY_SPACE}: ${CYAN}${total_freed} MB${BOX_NC}"
    print_box_sep
    print_box_line "${BOLD}${MSG_SUMMARY_STEP_DETAIL}${BOX_NC}"

    # Generate lines of 4 columns (6 rows x 4 cols = 24 slots, we use 23)
    # Fixed format: icon[4] + space[1] + name[11] = 16 chars per cell
    local cols=4
    for row in {0..5}; do
        local line=""
        for col in {0..3}; do
            local idx=$((row * cols + col))
            if [ $idx -le 22 ]; then
                local icon=$(get_step_icon_summary "${STEP_STATUS_ARRAY[$idx]}")
                # Name with fixed width of 11 chars
                local name
                name=$(printf "%-11.11s" "${STEP_SHORT_NAMES[$idx]}")
                line+="${icon} ${name}"
            else
                # Empty cell: 16 spaces
                line+="                "
            fi
        done
        print_box_line "$line"
    done

    print_box_sep

    # Reboot state
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

    # Warnings outside the box
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
            # Use -i flag to ignore inhibitors (active sessions, etc.)
            systemctl reboot -i
        fi
    fi
}

# ============================================================================
# SYSTEMD TIMER FUNCTIONS
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
Comprehensive Maintenance for Debian/Ubuntu-based Distributions

Supported distributions:
  • Debian (Stable, Testing, Unstable)
  • Ubuntu (all versions)
  • Linux Mint
  • Pop!_OS, Elementary OS, Zorin OS, Kali Linux
  • Any Debian/Ubuntu derivative

Usage: sudo ./autoclean.sh [options]

Options:
  --dry-run              Simulate execution without making real changes
  -n, --notify           Send notifications in dry-run mode
  -y, --unattended       Unattended mode without confirmations
  --no-backup            Do not create configuration backup
  --no-menu              Skip interactive menu (use default config)
  --quiet                Quiet mode (only logs)
  --lang LANG            Set language (en, es, pt, fr, de, it)
  --profile PROFILE      Use predefined profile (see below)
  --schedule MODE        Create systemd timer (daily, weekly, monthly)
  --unschedule           Remove scheduled systemd timer
  --schedule-status      Show scheduled timer status
  --help                 Show this help

Predefined profiles (--profile):
  server      Unattended, Docker ON, SMART ON, no Flatpak/Snap
  desktop     Interactive, Docker OFF, SMART ON, Flatpak ON, Timeshift ON
  developer   Interactive, Docker ON, Snap ON, no SMART/Firmware
  minimal     Unattended, only apt update/upgrade and APT cleanup
  custom      Unattended, reads all configuration from autoclean.conf

Examples:
  sudo ./autoclean.sh                    # Normal execution (interactive)
  sudo ./autoclean.sh --profile server   # Server profile
  sudo ./autoclean.sh --profile desktop  # Desktop profile
  sudo ./autoclean.sh --profile custom   # Custom profile (reads autoclean.conf)
  sudo ./autoclean.sh --dry-run          # Simulate changes
  sudo ./autoclean.sh --dry-run --notify # Simulate and send notifications
  sudo ./autoclean.sh -y                 # Unattended mode
  sudo ./autoclean.sh --schedule weekly  # Schedule weekly

Configuration:
  - Edit autoclean.conf to configure language, theme and steps
  - If file doesn't exist, it's auto-generated with default values
  - Use --profile custom to run with saved configuration

More information in the script comments.
EOF
            exit 0
            ;;
        *)
            echo "${MSG_UNKNOWN_OPTION:-Unknown option}: $1"
            echo "${MSG_USE_HELP:-Use --help to see available options}"
            exit 1
            ;;
    esac
done

# ============================================================================
# MASTER EXECUTION
# ============================================================================

# Detect available notifiers (before load_config for apply_notifier_config)
detect_notifiers

# Load saved configuration if exists (to get SAVED_LANG before loading language)
# If it doesn't exist, generate file with default values
if config_exists; then
    load_config
else
    generate_default_config
    load_config
fi

# Load language (uses SAVED_LANG if exists, or detects from system)
load_language

# Load theme (uses SAVED_THEME if exists, or uses default)
load_theme

# Load enabled notifiers
load_all_enabled_notifiers

# Handle schedule operations (before main execution)
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

# Verify root permissions BEFORE any operation
check_root

# Initialization
init_log
log "INFO" "=========================================="
log "INFO" "${MSG_STARTING_MAINTENANCE:-Starting Maintenance} v${SCRIPT_VERSION}"
log "INFO" "=========================================="

# Apply profile if specified via CLI (--profile)
# Must be executed after init_log so that log() works correctly
if [ -n "$PROFILE" ]; then
    apply_profile "$PROFILE"
fi

# Mandatory pre-checks
check_lock

# Detect distribution (must be executed before print_header)
detect_distro

# Count initial steps
count_active_steps

# Show configuration according to execution mode
if [ "$UNATTENDED" = false ] && [ "$QUIET" = false ] && [ "$NO_MENU" = false ]; then
    # Interactive mode: show configuration menu
    show_interactive_menu
else
    # Non-interactive mode: show summary and confirm
    print_header
    show_step_summary
fi

# Validate dependencies after configuration
validate_step_dependencies

# Show header before executing (if we used interactive menu it was already cleared)
[ "$QUIET" = false ] && print_header

check_disk_space

# Execute configured steps (23 total steps)

# PHASE 1: Pre-checks and diagnostics (steps 1-8)
step_check_connectivity      # 1. Connectivity
step_check_dependencies      # 2. Dependencies
step_check_repos             # 3. APT repos integrity
step_check_smart             # 4. SMART disks
step_check_debsums           # 5. Package integrity
step_check_security          # 6. Security updates
step_check_permissions       # 7. Critical permissions
step_audit_services          # 8. Unnecessary services

# PHASE 2: Backups (steps 9-10)
step_backup_tar              # 9. TAR Backup
step_snapshot_timeshift      # 10. Timeshift Snapshot

# PHASE 3: Updates (steps 11-15)
step_update_repos            # 11. Update repos
step_upgrade_system          # 12. Upgrade system
step_update_flatpak          # 13. Flatpak
step_update_snap             # 14. Snap
step_check_firmware          # 15. Firmware

# PHASE 4: Cleanup (steps 16-22)
step_cleanup_apt             # 16. APT Cleanup
step_cleanup_kernels         # 17. Old kernels
step_cleanup_disk            # 18. Disk cleanup
step_cleanup_docker          # 19. Docker
step_cleanup_sessions        # 20. Abandoned sessions
step_check_logrotate         # 21. Logrotate
step_check_inodes            # 22. Inodes

# PHASE 5: Final verification (step 23)
step_check_reboot            # 23. Reboot check

# Show final summary
show_final_summary

exit 0
