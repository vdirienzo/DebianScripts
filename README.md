# 🐧 Debian Scripts Collection

Colección de scripts de mantenimiento y actualización para sistemas Debian Testing (Trixie) y derivados.

## 📋 Índice

- [Scripts Disponibles](#scripts-disponibles)
- [cleannew.sh - Script Principal](#cleannewsh---script-principal)
  - [Características Principales](#características-principales)
  - [Requisitos del Sistema](#requisitos-del-sistema)
  - [Instalación y Uso](#instalación-y-uso)
  - [Configuración Avanzada](#configuración-avanzada)
  - [Ejemplos de Uso](#ejemplos-de-uso)
- [Otros Scripts](#otros-scripts)
- [Solución de Problemas](#solución-de-problemas)
- [Contribuir](#contribuir)

---

## 🚀 Scripts Disponibles

### cleannew.sh - Script Principal ⭐ RECOMENDADO

**Versión:** 2025.6 - "Paranoid Edition with Modular Steps"
**Última revisión:** Diciembre 2025
**Autor:** Homero Thompson del Lago del Terror (Enhanced by Claude)

Script de mantenimiento integral y paranoico para Debian 13 (Testing/Trixie) con énfasis en seguridad y control granular.

#### ✨ Características Principales

- ✅ **Control Modular**: 13 pasos independientes que pueden activarse/desactivarse individualmente
- 🛡️ **Seguridad Paranoica**: Snapshot automático con Timeshift antes de operaciones críticas
- 🔍 **Detección Inteligente**: Analiza riesgos antes de ejecutar (eliminaciones masivas, espacio en disco)
- 📊 **Resumen Detallado**: Estadísticas de espacio liberado y tiempo de ejecución
- 🔄 **Verificación de Reinicio Avanzada**: Detecta kernel obsoleto y librerías críticas actualizadas
- 📝 **Logging Completo**: Registro detallado de todas las operaciones
- 🧪 **Modo Dry-Run**: Simula cambios sin ejecutarlos realmente
- ⚡ **Modo Desatendido**: Perfecto para automatización con cron

#### 🔧 Requisitos del Sistema

**OBLIGATORIO:**
- Debian 13 (Testing/Trixie) o compatible
- Permisos de root (sudo)
- Conexión a internet

**RECOMENDADO (instalación automática disponible):**
- `timeshift` - Snapshots del sistema (CRÍTICO para seguridad)
- `needrestart` - Detección inteligente de servicios a reiniciar
- `fwupd` - Gestión de actualizaciones de firmware
- `flatpak` - Si usas aplicaciones Flatpak
- `snapd` - Si usas aplicaciones Snap

Instalación manual de herramientas recomendadas:
```bash
sudo apt install timeshift needrestart fwupd flatpak
```

#### 📦 Instalación y Uso

**1. Clonar el repositorio:**
```bash
git clone https://github.com/yourusername/DebianScripts.git
cd DebianScripts
chmod +x cleannew.sh
```

**2. Ejecución básica (RECOMENDADA):**
```bash
sudo ./cleannew.sh
```

**3. Modo simulación (para probar sin hacer cambios):**
```bash
sudo ./cleannew.sh --dry-run
```

**4. Modo desatendido (para automatización):**
```bash
sudo ./cleannew.sh -y
```

**5. Ver ayuda completa:**
```bash
./cleannew.sh --help
```

#### ⚙️ Configuración Avanzada

El script incluye 13 pasos modulares que puedes activar/desactivar editando las variables `STEP_*` al inicio del script:

| Variable | Descripción | Default |
|----------|-------------|---------|
| `STEP_CHECK_CONNECTIVITY` | Verificar conexión a internet | ✅ |
| `STEP_CHECK_DEPENDENCIES` | Verificar e instalar herramientas necesarias | ✅ |
| `STEP_BACKUP_TAR` | Backup de configuraciones APT | ✅ |
| `STEP_SNAPSHOT_TIMESHIFT` | Crear snapshot Timeshift (🛡️ CRÍTICO) | ✅ |
| `STEP_UPDATE_REPOS` | Actualizar repositorios (apt update) | ✅ |
| `STEP_UPGRADE_SYSTEM` | Actualizar paquetes (apt full-upgrade) | ✅ |
| `STEP_UPDATE_FLATPAK` | Actualizar aplicaciones Flatpak | ✅ |
| `STEP_UPDATE_SNAP` | Actualizar aplicaciones Snap | ✅ |
| `STEP_CHECK_FIRMWARE` | Verificar actualizaciones de firmware | ✅ |
| `STEP_CLEANUP_APT` | Limpieza de paquetes huérfanos | ✅ |
| `STEP_CLEANUP_KERNELS` | Eliminar kernels antiguos | ✅ |
| `STEP_CLEANUP_DISK` | Limpiar logs y caché | ✅ |
| `STEP_CHECK_REBOOT` | Verificar necesidad de reinicio | ✅ |

**Ejemplo de configuración personalizada:**

Para solo actualizar el sistema sin limpiar:
```bash
# Editar cleannew.sh
STEP_CLEANUP_APT=0
STEP_CLEANUP_KERNELS=0
STEP_CLEANUP_DISK=0
```

Para solo limpiar sin actualizar:
```bash
# Editar cleannew.sh
STEP_UPDATE_REPOS=0
STEP_UPGRADE_SYSTEM=0
STEP_UPDATE_FLATPAK=0
STEP_UPDATE_SNAP=0
```

#### 📚 Ejemplos de Uso

**Escenario 1: Mantenimiento completo semanal**
```bash
sudo ./cleannew.sh
```

**Escenario 2: Mantenimiento rápido sin snapshot**
```bash
# Editar cleannew.sh y configurar:
STEP_SNAPSHOT_TIMESHIFT=0
STEP_BACKUP_TAR=0

sudo ./cleannew.sh -y
```

**Escenario 3: Solo limpieza de espacio en disco**
```bash
# Editar cleannew.sh y configurar:
STEP_UPDATE_REPOS=0
STEP_UPGRADE_SYSTEM=0
STEP_UPDATE_FLATPAK=0
STEP_UPDATE_SNAP=0
STEP_CHECK_FIRMWARE=0
STEP_SNAPSHOT_TIMESHIFT=0

sudo ./cleannew.sh
```

**Escenario 4: Automatización con cron (diario a las 2 AM)**
```bash
sudo crontab -e

# Añadir:
0 2 * * * /ruta/a/cleannew.sh -y --quiet >> /var/log/maintenance-cron.log 2>&1
```

**Escenario 5: Probar antes de ejecutar**
```bash
sudo ./cleannew.sh --dry-run
```

#### 📁 Archivos Generados

```
/var/log/debian-maintenance/
├── sys-update-YYYYMMDD_HHMMSS.log    # Logs de cada ejecución

/var/backups/debian-maintenance/
├── backup_YYYYMMDD_HHMMSS.tar.gz     # Backup configuraciones APT
└── packages_YYYYMMDD_HHMMSS.list     # Lista de paquetes instalados

/var/run/
└── debian-maintenance.lock            # Lock file para evitar ejecuciones simultáneas
```

#### 🔒 Características de Seguridad

1. **Validación de Espacio**: Verifica espacio libre antes de actualizar
2. **Detección de Riesgos**: Alerta si APT propone eliminar muchos paquetes (`MAX_REMOVALS_ALLOWED=0`)
3. **Snapshot Automático**: Crea punto de restauración con Timeshift
4. **Backup de Configuraciones**: Guarda configuración APT antes de cambios
5. **Lock File**: Evita ejecuciones simultáneas
6. **Reparación Automática**: Ejecuta `dpkg --configure -a` antes de actualizar
7. **Modo Dry-Run**: Prueba sin hacer cambios reales
8. **Detección de Reinicio**:
   - Comparación de kernel actual vs esperado
   - Detección de librerías críticas actualizadas (glibc, systemd)
   - Reinicio automático de servicios con needrestart

#### 🎯 Opciones de Línea de Comandos

```
sudo ./cleannew.sh [opciones]

Opciones:
  --dry-run          Simular ejecución sin hacer cambios reales
  -y, --unattended   Modo desatendido sin confirmaciones
  --no-backup        No crear backup de configuraciones
  --quiet            Modo silencioso (solo logs)
  --help             Mostrar ayuda completa
```

#### ⚡ Variables de Configuración

```bash
# Archivos y directorios
BACKUP_DIR="/var/backups/debian-maintenance"
LOG_DIR="/var/log/debian-maintenance"

# Parámetros de sistema
DIAS_LOGS=7                    # Días de logs a conservar
KERNELS_TO_KEEP=3              # Número de kernels a mantener
MIN_FREE_SPACE_GB=5            # Espacio mínimo requerido en /
MIN_FREE_SPACE_BOOT_MB=200     # Espacio mínimo requerido en /boot
APT_CLEAN_MODE="autoclean"     # Modo de limpieza APT (autoclean/clean)

# Seguridad paranoica
MAX_REMOVALS_ALLOWED=0         # Máximo de paquetes a eliminar sin confirmación
ASK_TIMESHIFT_RUN=true         # Preguntar antes de crear snapshot
```

---

## 📦 Otros Scripts

### autoclean.sh
Script de limpieza básica más antiguo. Funcionalidad básica de actualización y limpieza.

**Uso:**
```bash
sudo ./autoclean.sh
```

### gemini.sh
Script de actualización generado con asistencia de Gemini AI.

### grok2.sh
Script de actualización generado con asistencia de Grok AI.

> **Nota:** Estos scripts son versiones anteriores. Se recomienda usar `cleannew.sh` para mantenimiento completo.

---

## 🔧 Solución de Problemas

### El script se detiene con error de lock

**Solución:**
```bash
sudo rm /var/run/debian-maintenance.lock
```

### APT está ocupado

**Causa:** Otro gestor de paquetes está en ejecución (Synaptic, Discover, Software Center)
**Solución:** Cierra todos los gestores de paquetes y vuelve a intentar

### Error al crear snapshot de Timeshift

**Solución 1:** Configura Timeshift primero:
```bash
sudo timeshift --setup
```

**Solución 2:** Omite el paso de Timeshift:
```bash
# Editar cleannew.sh
STEP_SNAPSHOT_TIMESHIFT=0
```

### Espacio insuficiente en disco

**Solución:** Libera espacio manualmente:
```bash
# Limpiar paquetes descargados
sudo apt clean

# Limpiar logs antiguos
sudo journalctl --vacuum-time=3d

# Eliminar kernels antiguos manualmente
sudo apt autoremove --purge
```

### No se detecta necesidad de reinicio correctamente

**Solución:** Instala needrestart:
```bash
sudo apt install needrestart
```

### Revisar logs de una ejecución

```bash
# Ver último log
ls -lt /var/log/debian-maintenance/ | head -2

# Leer log
less /var/log/debian-maintenance/sys-update-YYYYMMDD_HHMMSS.log
```

### Restaurar sistema desde snapshot

Si algo salió mal después de ejecutar el script:
```bash
# Listar snapshots disponibles
sudo timeshift --list

# Restaurar snapshot específico
sudo timeshift --restore --snapshot 'YYYY-MM-DD_HH-MM-SS'
```

---

## 🤝 Contribuir

Las contribuciones son bienvenidas. Por favor:

1. Fork el repositorio
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

---

## 📝 Notas Importantes

⚠️ **ADVERTENCIAS PARA DEBIAN TESTING:**

- Testing puede tener cambios disruptivos: **SIEMPRE revisa los logs**
- El snapshot de Timeshift es tu seguro de vida: **no lo omitas**
- `MAX_REMOVALS_ALLOWED=0` evita eliminaciones automáticas masivas
- En modo desatendido (`-y`), el script **ABORTA** si detecta riesgo
- Los kernels se mantienen según `KERNELS_TO_KEEP` (default: 3)
- Los logs se conservan según `DIAS_LOGS` (default: 7 días)

---

## 🔗 Enlaces Útiles

- [Debian Testing FAQ](https://wiki.debian.org/DebianTesting)
- [Timeshift Documentation](https://github.com/teejee2008/timeshift)
- [APT Documentation](https://wiki.debian.org/Apt)

---

## 📜 Licencia

Este proyecto está bajo licencia libre. Siéntete libre de usar, modificar y distribuir según tus necesidades.

---

## 👤 Autor

**Homero Thompson del Lago del Terror**
Enhanced by Claude AI

---

## 📊 Estadísticas del Proyecto

- **Scripts totales:** 4
- **Script principal:** cleannew.sh
- **Versión actual:** 2025.6
- **Líneas de código (cleannew.sh):** ~1900+
- **Pasos modulares:** 13
- **Compatible con:** Debian 13 Testing (Trixie)

---

## 🎯 Roadmap Futuro

- [ ] Soporte para notificaciones por email
- [ ] Integración con Discord/Slack para notificaciones
- [ ] Dashboard web para visualizar logs
- [ ] Soporte para múltiples distribuciones (Ubuntu, Linux Mint)
- [ ] Sistema de plugins para extensibilidad
- [ ] Interfaz TUI (Terminal User Interface) con diálogos interactivos

---

**Última actualización del README:** Diciembre 2025
