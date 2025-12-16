# Debian Scripts Collection

Coleccion de scripts de mantenimiento y actualizacion para distribuciones basadas en Debian/Ubuntu.

## Indices

- [Scripts Disponibles](#scripts-disponibles)
- [autoclean.sh - Script Principal](#autocleansh---script-principal)
  - [Distribuciones Soportadas](#distribuciones-soportadas)
  - [Caracteristicas Principales](#caracteristicas-principales)
  - [Requisitos del Sistema](#requisitos-del-sistema)
  - [Instalacion y Uso](#instalacion-y-uso)
  - [Configuracion Avanzada](#configuracion-avanzada)
  - [Ejemplos de Uso](#ejemplos-de-uso)
- [Otros Scripts](#otros-scripts)
- [Solucion de Problemas](#solucion-de-problemas)
- [Contribuir](#contribuir)

---

## Scripts Disponibles

### autoclean.sh - Script Principal (RECOMENDADO)

**Version:** 2025.8 - "Paranoid Edition - Multi-Distro + Interactive Menu"
**Ultima revision:** Diciembre 2025
**Autor:** Homero Thompson del Lago del Terror (Enhanced by Claude)

Script de mantenimiento integral y paranoico para distribuciones basadas en Debian/Ubuntu con enfasis en seguridad, control granular, **deteccion automatica de distribucion** y **menu interactivo de configuracion**.

---

## Distribuciones Soportadas

El script detecta y soporta automaticamente las siguientes distribuciones:

| Distribucion | Familia | Mirror de Verificacion |
|--------------|---------|------------------------|
| **Debian** (Stable, Testing, Unstable) | debian | deb.debian.org |
| **Ubuntu** (todas las versiones LTS y regulares) | ubuntu | archive.ubuntu.com |
| **Linux Mint** (todas las versiones) | mint | packages.linuxmint.com |
| **Pop!_OS** | ubuntu | apt.pop-os.org |
| **Elementary OS** | ubuntu | packages.elementary.io |
| **Zorin OS** | ubuntu | packages.zorinos.com |
| **Kali Linux** | debian | http.kali.org |
| **Otras derivadas** | auto-detectado | segun ID_LIKE |

La deteccion se realiza automaticamente usando `/etc/os-release` y el script adapta:
- El servidor de verificacion de conectividad
- El comportamiento segun la familia de la distribucion
- Los mensajes mostrados al usuario

---

## Caracteristicas Principales

### Nuevas en v2025.8

- **Menu interactivo de configuracion**: Interfaz TUI con navegacion por flechas para seleccionar que pasos ejecutar
- **Configuracion persistente**: Guarda tu configuracion preferida y se carga automaticamente en cada ejecucion
- **Controles intuitivos**: Usa flechas ↑/↓, ESPACIO para toggle, ENTER para ejecutar
- **Descripcion en tiempo real**: Muestra ayuda contextual de cada paso mientras navegas

### Nuevas en v2025.7

- **Deteccion automatica de distribucion**: Identifica automaticamente Debian, Ubuntu, Mint, Pop!_OS, Elementary, Zorin, Kali y cualquier derivada
- **Adaptacion dinamica**: El script adapta su comportamiento segun la distribucion detectada
- **Mirror inteligente**: Verifica conectividad usando el servidor correspondiente a cada distribucion

### Caracteristicas Core

- **Control Modular**: 13 pasos independientes que pueden activarse/desactivarse individualmente
- **Seguridad Paranoica**: Snapshot automatico con Timeshift antes de operaciones criticas
- **Deteccion Inteligente de Riesgos**: Analiza antes de ejecutar (eliminaciones masivas, espacio en disco)
- **Resumen Detallado**: Estadisticas de espacio liberado y tiempo de ejecucion
- **Verificacion de Reinicio Avanzada**: Detecta kernel obsoleto y librerias criticas actualizadas
- **Logging Completo**: Registro detallado de todas las operaciones
- **Modo Dry-Run**: Simula cambios sin ejecutarlos realmente
- **Modo Desatendido**: Perfecto para automatizacion con cron

---

## Requisitos del Sistema

**OBLIGATORIO:**
- Distribucion basada en Debian o Ubuntu (ver lista de soportadas)
- Permisos de root (sudo)
- Conexion a internet

**RECOMENDADO (instalacion automatica disponible):**
- `timeshift` - Snapshots del sistema (CRITICO para seguridad)
- `needrestart` - Deteccion inteligente de servicios a reiniciar
- `fwupd` - Gestion de actualizaciones de firmware
- `flatpak` - Si usas aplicaciones Flatpak
- `snapd` - Si usas aplicaciones Snap

Instalacion manual de herramientas recomendadas:
```bash
sudo apt install timeshift needrestart fwupd flatpak
```

---

## Instalacion y Uso

**1. Clonar el repositorio:**
```bash
git clone https://github.com/vdirienzo/DebianScripts.git
cd DebianScripts
chmod +x autoclean.sh
```

**2. Ejecucion basica (RECOMENDADA):**
```bash
sudo ./autoclean.sh
```

**3. Modo simulacion (para probar sin hacer cambios):**
```bash
sudo ./autoclean.sh --dry-run
```

**4. Modo desatendido (para automatizacion):**
```bash
sudo ./autoclean.sh -y
```

**5. Ver ayuda completa:**
```bash
./autoclean.sh --help
```

---

## Configuracion Avanzada

El script incluye 13 pasos modulares que puedes activar/desactivar editando las variables `STEP_*` al inicio del script:

| Variable | Descripcion | Default |
|----------|-------------|---------|
| `STEP_CHECK_CONNECTIVITY` | Verificar conexion a internet | ON |
| `STEP_CHECK_DEPENDENCIES` | Verificar e instalar herramientas necesarias | ON |
| `STEP_BACKUP_TAR` | Backup de configuraciones APT | ON |
| `STEP_SNAPSHOT_TIMESHIFT` | Crear snapshot Timeshift (CRITICO) | ON |
| `STEP_UPDATE_REPOS` | Actualizar repositorios (apt update) | ON |
| `STEP_UPGRADE_SYSTEM` | Actualizar paquetes (apt full-upgrade) | ON |
| `STEP_UPDATE_FLATPAK` | Actualizar aplicaciones Flatpak | ON |
| `STEP_UPDATE_SNAP` | Actualizar aplicaciones Snap | OFF |
| `STEP_CHECK_FIRMWARE` | Verificar actualizaciones de firmware | ON |
| `STEP_CLEANUP_APT` | Limpieza de paquetes huerfanos | ON |
| `STEP_CLEANUP_KERNELS` | Eliminar kernels antiguos | ON |
| `STEP_CLEANUP_DISK` | Limpiar logs y cache | ON |
| `STEP_CHECK_REBOOT` | Verificar necesidad de reinicio | ON |

**Ejemplo de configuracion personalizada:**

Para solo actualizar el sistema sin limpiar:
```bash
# Editar autoclean.sh
STEP_CLEANUP_APT=0
STEP_CLEANUP_KERNELS=0
STEP_CLEANUP_DISK=0
```

Para solo limpiar sin actualizar:
```bash
# Editar autoclean.sh
STEP_UPDATE_REPOS=0
STEP_UPGRADE_SYSTEM=0
STEP_UPDATE_FLATPAK=0
STEP_UPDATE_SNAP=0
```

---

## Menu Interactivo

Al ejecutar el script sin argumentos, se muestra un menu interactivo que permite seleccionar que pasos ejecutar:

```
╔═══════════════════════════════════════════════════════════════╗
║           CONFIGURACIÓN DE PASOS - MENÚ INTERACTIVO           ║
╚═══════════════════════════════════════════════════════════════╝

  Usa ↑/↓ para navegar, ESPACIO para activar/desactivar, ENTER para ejecutar

  > [✓] Verificar conectividad
    [✓] Verificar dependencias
    [✓] Backup configuraciones (tar)
    [✓] Snapshot Timeshift 🛡️
    [✓] Actualizar repositorios
    [✓] Actualizar sistema (APT)
    [✓] Actualizar Flatpak
    [ ] Actualizar Snap
    [✓] Verificar firmware
    [✓] Limpieza APT
    [✓] Limpieza kernels
    [✓] Limpieza disco/logs
    [✓] Verificar reinicio

  ─────────────────────────────────────────────────────────────
  💡 Verifica conexión a internet antes de continuar
  ─────────────────────────────────────────────────────────────

  💾 Configuración guardada: Sí (autoclean.conf)

  [ENTER] Ejecutar  [A] Todos  [N] Ninguno  [G] Guardar  [D] Borrar config  [Q] Salir
```

### Controles del Menu

| Tecla | Accion |
|-------|--------|
| ↑ / ↓ | Navegar entre opciones |
| ESPACIO | Activar/desactivar paso seleccionado |
| ENTER | Ejecutar con la configuracion actual |
| A | Activar todos los pasos |
| N | Desactivar todos los pasos |
| G | Guardar configuracion actual |
| D | Borrar configuracion guardada |
| Q | Salir sin ejecutar |

### Configuracion Persistente

La configuracion se guarda en `autoclean.conf` en el mismo directorio del script:
- Al presionar **G**, se guarda el estado actual de todos los pasos
- Al iniciar el script, se carga automaticamente la configuracion guardada
- Al presionar **D**, se elimina el archivo de configuracion (vuelve a valores por defecto)

---

## Ejemplos de Uso

**Escenario 1: Mantenimiento completo semanal**
```bash
sudo ./autoclean.sh
```

**Escenario 2: Mantenimiento rapido sin snapshot**
```bash
# Editar autoclean.sh y configurar:
STEP_SNAPSHOT_TIMESHIFT=0
STEP_BACKUP_TAR=0

sudo ./autoclean.sh -y
```

**Escenario 3: Solo limpieza de espacio en disco**
```bash
# Editar autoclean.sh y configurar:
STEP_UPDATE_REPOS=0
STEP_UPGRADE_SYSTEM=0
STEP_UPDATE_FLATPAK=0
STEP_UPDATE_SNAP=0
STEP_CHECK_FIRMWARE=0
STEP_SNAPSHOT_TIMESHIFT=0

sudo ./autoclean.sh
```

**Escenario 4: Automatizacion con cron (diario a las 2 AM)**
```bash
sudo crontab -e

# Anadir:
0 2 * * * /ruta/a/autoclean.sh -y --quiet >> /var/log/maintenance-cron.log 2>&1
```

**Escenario 5: Probar antes de ejecutar**
```bash
sudo ./autoclean.sh --dry-run
```

---

## Archivos Generados

```
/var/log/debian-maintenance/
  sys-update-YYYYMMDD_HHMMSS.log    # Logs de cada ejecucion

/var/backups/debian-maintenance/
  backup_YYYYMMDD_HHMMSS.tar.gz     # Backup configuraciones APT
  packages_YYYYMMDD_HHMMSS.list     # Lista de paquetes instalados

/var/run/
  debian-maintenance.lock            # Lock file para evitar ejecuciones simultaneas
```

---

## Caracteristicas de Seguridad

1. **Validacion de Espacio**: Verifica espacio libre antes de actualizar
2. **Deteccion de Riesgos**: Alerta si APT propone eliminar muchos paquetes (`MAX_REMOVALS_ALLOWED=0`)
3. **Snapshot Automatico**: Crea punto de restauracion con Timeshift
4. **Backup de Configuraciones**: Guarda configuracion APT antes de cambios
5. **Lock File**: Evita ejecuciones simultaneas
6. **Reparacion Automatica**: Ejecuta `dpkg --configure -a` antes de actualizar
7. **Modo Dry-Run**: Prueba sin hacer cambios reales
8. **Deteccion de Reinicio**:
   - Comparacion de kernel actual vs esperado
   - Deteccion de librerias criticas actualizadas (glibc, systemd)
   - Reinicio automatico de servicios con needrestart

---

## Opciones de Linea de Comandos

```
sudo ./autoclean.sh [opciones]

Opciones:
  --dry-run          Simular ejecucion sin hacer cambios reales
  -y, --unattended   Modo desatendido sin confirmaciones
  --no-backup        No crear backup de configuraciones
  --no-menu          Omitir menu interactivo (usar config guardada o por defecto)
  --quiet            Modo silencioso (solo logs)
  --help             Mostrar ayuda completa
```

---

## Variables de Configuracion

```bash
# Archivos y directorios
BACKUP_DIR="/var/backups/debian-maintenance"
LOG_DIR="/var/log/debian-maintenance"

# Parametros de sistema
DIAS_LOGS=7                    # Dias de logs a conservar
KERNELS_TO_KEEP=3              # Numero de kernels a mantener
MIN_FREE_SPACE_GB=5            # Espacio minimo requerido en /
MIN_FREE_SPACE_BOOT_MB=200     # Espacio minimo requerido en /boot
APT_CLEAN_MODE="autoclean"     # Modo de limpieza APT (autoclean/clean)

# Seguridad paranoica
MAX_REMOVALS_ALLOWED=0         # Maximo de paquetes a eliminar sin confirmacion
ASK_TIMESHIFT_RUN=true         # Preguntar antes de crear snapshot
```

---

## Otros Scripts

### cleannew.sh
Version anterior del script principal. Funcionalidad similar pero sin soporte multi-distro.

### gemini.sh
Script de actualizacion generado con asistencia de Gemini AI.

### grok2.sh
Script de actualizacion generado con asistencia de Grok AI.

> **Nota:** Estos scripts son versiones anteriores. Se recomienda usar `autoclean.sh` para mantenimiento completo.

---

## Solucion de Problemas

### El script se detiene con error de lock

**Solucion:**
```bash
sudo rm /var/run/debian-maintenance.lock
```

### APT esta ocupado

**Causa:** Otro gestor de paquetes esta en ejecucion (Synaptic, Discover, Software Center)
**Solucion:** Cierra todos los gestores de paquetes y vuelve a intentar

### Error al crear snapshot de Timeshift

**Solucion 1:** Configura Timeshift primero:
```bash
sudo timeshift --setup
```

**Solucion 2:** Omite el paso de Timeshift:
```bash
# Editar autoclean.sh
STEP_SNAPSHOT_TIMESHIFT=0
```

### Espacio insuficiente en disco

**Solucion:** Libera espacio manualmente:
```bash
# Limpiar paquetes descargados
sudo apt clean

# Limpiar logs antiguos
sudo journalctl --vacuum-time=3d

# Eliminar kernels antiguos manualmente
sudo apt autoremove --purge
```

### No se detecta necesidad de reinicio correctamente

**Solucion:** Instala needrestart:
```bash
sudo apt install needrestart
```

### Revisar logs de una ejecucion

```bash
# Ver ultimo log
ls -lt /var/log/debian-maintenance/ | head -2

# Leer log
less /var/log/debian-maintenance/sys-update-YYYYMMDD_HHMMSS.log
```

### Restaurar sistema desde snapshot

Si algo salio mal despues de ejecutar el script:
```bash
# Listar snapshots disponibles
sudo timeshift --list

# Restaurar snapshot especifico
sudo timeshift --restore --snapshot 'YYYY-MM-DD_HH-MM-SS'
```

---

## Contribuir

Las contribuciones son bienvenidas. Por favor:

1. Fork el repositorio
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

---

## Notas Importantes

**ADVERTENCIAS PARA TESTING/UNSTABLE:**

- Testing/Unstable pueden tener cambios disruptivos: **SIEMPRE revisa los logs**
- El snapshot de Timeshift es tu seguro de vida: **no lo omitas**
- `MAX_REMOVALS_ALLOWED=0` evita eliminaciones automaticas masivas
- En modo desatendido (`-y`), el script **ABORTA** si detecta riesgo
- Los kernels se mantienen segun `KERNELS_TO_KEEP` (default: 3)
- Los logs se conservan segun `DIAS_LOGS` (default: 7 dias)

---

## Enlaces Utiles

- [Debian Testing FAQ](https://wiki.debian.org/DebianTesting)
- [Ubuntu Documentation](https://help.ubuntu.com/)
- [Linux Mint Documentation](https://linuxmint.com/documentation.php)
- [Timeshift Documentation](https://github.com/teejee2008/timeshift)
- [APT Documentation](https://wiki.debian.org/Apt)

---

## Licencia

Este proyecto esta bajo licencia libre. Sientete libre de usar, modificar y distribuir segun tus necesidades.

---

## Autor

**Homero Thompson del Lago del Terror**
Enhanced by Claude AI

---

## Estadisticas del Proyecto

- **Scripts totales:** 4
- **Script principal:** autoclean.sh
- **Version actual:** 2025.8
- **Lineas de codigo:** ~1700+
- **Pasos modulares:** 13
- **Distribuciones soportadas:** 7+ (auto-deteccion)
- **Compatible con:** Debian, Ubuntu, Mint, Pop!_OS, Elementary, Zorin, Kali y derivadas

---

## Roadmap Futuro

- [ ] Soporte para notificaciones por email
- [ ] Integracion con Discord/Slack para notificaciones
- [ ] Dashboard web para visualizar logs
- [ ] Sistema de plugins para extensibilidad
- [x] ~~Interfaz TUI (Terminal User Interface) con dialogos interactivos~~ **Completado en v2025.8**

---

**Ultima actualizacion del README:** Diciembre 2025
