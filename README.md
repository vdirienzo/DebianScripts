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
  - [Perfiles Predefinidos](#perfiles-predefinidos)
  - [Screenshots](#screenshots)
  - [Menu Interactivo](#menu-interactivo)
  - [Ejemplos de Uso](#ejemplos-de-uso)
- [Solucion de Problemas](#solucion-de-problemas)
- [Contribuir](#contribuir)

---

## Scripts Disponibles

### autoclean.sh - Script Principal 

**Version:** 2025.12
**Ultima revision:** Diciembre 2025
**Autor:** Homero Thompson del Lago del Terror
**Contribuciones UI/UX:** Dreadblitz

Script de mantenimiento integral para distribuciones basadas en Debian/Ubuntu con enfasis en seguridad, control granular, **deteccion automatica de distribucion** y **menu interactivo de configuracion con interfaz enterprise**.

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

### Interfaz de Usuario

- **Interfaz Enterprise 100% ASCII**: UI sin emojis para compatibilidad total con cualquier terminal
- **Menu interactivo en 3 columnas**: Grid 5x3 con los 15 pasos, navegacion con flechas ←/→/↑/↓
- **Resumen de ejecucion en 3 columnas**: Reporte final compacto con estado de cada paso
- **Alineacion robusta con cursor absoluto**: Usa secuencias ANSI `\033[78G` para bordes perfectos
- **Iconos ASCII puros**: `[OK]`, `[XX]`, `[--]`, `[!!]`, `[..]` para alineacion perfecta
- **Configuracion persistente**: Guarda tu configuracion preferida en `autoclean.conf`
- **Descripcion en tiempo real**: Ayuda contextual de cada paso mientras navegas

### Multi-Idioma (i18n)

- **6 idiomas soportados**: Ingles (en), Espanol (es), Portugues (pt), Frances (fr), Aleman (de), Italiano (it)
- **Deteccion dinamica de idiomas**: Los idiomas se detectan automaticamente desde la carpeta `lang/`
- **Selector en grid 4 columnas**: Tecla `[L]` en el menu, navegacion con flechas ←/→/↑/↓
- **Crea tu propio idioma**: Tutorial incluido en `lang/TUTORIAL.md`
- **Deteccion automatica del sistema**: Detecta el idioma del sistema y lo aplica automaticamente
- **Patrones de confirmacion localizados**: S/N, Y/N, O/N, J/N segun el idioma
- **Parametro --lang**: Fuerza un idioma especifico desde linea de comandos
- **Configuracion persistente**: El idioma seleccionado se guarda en `autoclean.conf`

### Temas de Colores

- **9 temas incluidos**: Gran variedad de estilos visuales
- **Deteccion dinamica**: Los temas se detectan automaticamente desde la carpeta `themes/`
- **Selector en grid 4 columnas**: Tecla `[T]` en el menu, navegacion con flechas
- **Crea tu propio tema**: Tutorial incluido en `themes/TUTORIAL.md`
- **Configuracion persistente**: El tema seleccionado se guarda en `autoclean.conf`

### Sistema de Notificaciones Multi-canal

- **Arquitectura de plugins**: Los notificadores se cargan dinamicamente desde `plugins/notifiers/`
- **Notificadores incluidos**: Desktop (notify-send), Telegram Bot API, ntfy.sh, Webhook (Slack/Discord/Teams), Email SMTP
- **Menu dedicado**: Tecla `[O]` en el menu principal para gestionar notificaciones
- **Configuracion por servicio**: Cada notificador tiene su propia pantalla de configuracion
- **Ayuda integrada**: Instrucciones de setup para cada servicio (como crear bot de Telegram, etc.)
- **Notificaciones automaticas**: Se envian al finalizar la ejecucion y en errores criticos
- **Crea tu propio notificador**: Tutorial incluido en `plugins/notifiers/TUTORIAL.md`

| Notificador | Descripcion | Configuracion |
|-------------|-------------|---------------|
| Desktop | Notificaciones de escritorio via notify-send | Ninguna (auto-detecta sesion) |
| Telegram | Mensajes via Telegram Bot API | Bot Token + Chat ID |
| ntfy.sh | Push notifications via ntfy.sh | Topic (+ Server/Token opcional) |
| Webhook | HTTP webhooks (Slack, Discord, Teams, custom) | URL + Preset |
| Email | Email via SMTP (Gmail, Outlook, custom) | SMTP Server + Credentials |

| Tema | Descripcion | Fondo |
|------|-------------|-------|
| Default | Azul/Cyan/Verde - tema original | - |
| Norton Commander | Cyan/Amarillo - estilo clasico NC | Azul |
| Bloody Red | Tonos rojos intensos | - |
| Green Terminal | Monocromo verde retro | - |
| Amber Terminal | Monocromo ambar vintage | - |
| Dracula | Purpura/Rosa/Cyan - tema popular | - |
| Matrix | Verde neon brillante estilo pelicula | Negro |
| Synthwave | Rosa/Cyan neon retro 80s | Purpura |
| Monokai | Naranja/Verde lima - clasico Sublime | - |

### Deteccion y Compatibilidad
- **Deteccion automatica de distribucion**: Identifica Debian, Ubuntu, Mint, Pop!_OS, Elementary, Zorin, Kali y derivadas
- **Adaptacion dinamica**: El script adapta su comportamiento segun la distribucion detectada
- **Mirror inteligente**: Verifica conectividad usando el servidor correspondiente a cada distribucion

### Seguridad

- **Snapshot automatico con Timeshift**: Crea punto de restauracion antes de operaciones criticas
- **Verificacion inteligente de Timeshift**: Detecta si esta instalado pero no configurado
- **Deteccion de riesgos**: Alerta si APT propone eliminar muchos paquetes
- **Validacion de espacio en disco**: Verifica espacio libre antes de actualizar
- **Lock file**: Evita ejecuciones simultaneas
- **Reparacion automatica**: Ejecuta `dpkg --configure -a` antes de actualizar
- **Validacion de archivos de configuracion**: Los archivos `.conf`, `.lang` y `.theme` se validan antes de cargar para prevenir inyeccion de codigo
- **Manejo seguro de archivos**: Usa `find` con delimitadores seguros para limpieza de logs y backups
- **Variables seguras**: Usa `declare -n` (nameref) en lugar de `eval` para manipulacion de variables en el menu

### Control y Modularidad

- **15 pasos independientes**: Cada uno puede activarse/desactivarse individualmente
- **Rotacion automatica de logs**: Mantiene solo las ultimas 5 ejecuciones
- **Rotacion automatica de backups**: Mantiene solo los ultimos 5 backups
- **Modo Dry-Run**: Simula cambios sin ejecutarlos realmente
- **Modo Desatendido**: Perfecto para automatizacion con cron

### Monitoreo y Reportes

- **Resumen detallado**: Estadisticas de espacio liberado y tiempo de ejecucion
- **Verificacion de reinicio avanzada**: Detecta kernel obsoleto y librerias criticas actualizadas
- **Logging completo**: Registro detallado de todas las operaciones en `/var/log/debian-maintenance/`

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
- `smartmontools` - Diagnosticos SMART de discos duros

Instalacion manual de herramientas recomendadas:
```bash
sudo apt install timeshift needrestart fwupd flatpak smartmontools
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

El script incluye 15 pasos modulares que puedes activar/desactivar editando las variables `STEP_*` al inicio del script:

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
| `STEP_CLEANUP_DOCKER` | Limpiar Docker/Podman (images, containers, volumes) | OFF |
| `STEP_CHECK_SMART` | Verificar salud de discos (SMART) | ON |
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

## Perfiles Predefinidos

El script incluye 5 perfiles predefinidos que configuran automaticamente los pasos segun el tipo de sistema:

```bash
sudo ./autoclean.sh --profile PERFIL
```

| Perfil | Descripcion | Pasos Activos |
|--------|-------------|---------------|
| `server` | Servidores (desatendido) | Docker ON, SMART ON, sin Flatpak/Snap/Timeshift, **automatico** |
| `desktop` | Estaciones de trabajo (interactivo) | Flatpak ON, Timeshift ON, SMART ON, sin Docker |
| `developer` | Entornos de desarrollo (interactivo) | Docker ON, Snap ON, Flatpak ON, sin SMART/Firmware |
| `minimal` | Actualizacion minima (desatendido) | Solo apt update/upgrade y limpieza APT, **automatico** |
| `custom` | Configuracion personalizada (desatendido) | Lee toda la configuracion desde `autoclean.conf`, **automatico** |

### Uso de Perfiles

```bash
# Mantenimiento de servidor (automatico, sin interaccion)
sudo ./autoclean.sh --profile server

# Mantenimiento de escritorio (con menu interactivo)
sudo ./autoclean.sh --profile desktop

# Mantenimiento rapido para desarrollador
sudo ./autoclean.sh --profile developer

# Actualizacion minima sin limpieza agresiva
sudo ./autoclean.sh --profile minimal

# Ejecutar con configuracion personalizada desde autoclean.conf
sudo ./autoclean.sh --profile custom
```

### Detalle de Cada Perfil

**server** - Optimizado para servidores:
- Modo desatendido (UNATTENDED=true) - acepta todo automaticamente
- Sin interfaz grafica (NO_MENU=true)
- Docker/Podman habilitado
- SMART habilitado (salud de discos)
- Sin Flatpak/Snap (no hay apps de escritorio)
- Sin Timeshift (servidores usan otros metodos de backup)

**desktop** - Optimizado para escritorio:
- Menu interactivo habilitado
- Flatpak habilitado (apps de escritorio)
- Timeshift habilitado (snapshots recomendados)
- SMART habilitado
- Sin Docker (no es comun en escritorios)

**developer** - Optimizado para desarrollo:
- Menu interactivo habilitado
- Docker habilitado (contenedores de desarrollo)
- Snap habilitado (herramientas de desarrollo)
- Flatpak habilitado
- Sin SMART/Firmware (evita interrupciones)

**minimal** - Actualizacion esencial:
- Modo desatendido (UNATTENDED=true) - acepta todo automaticamente
- Sin interfaz grafica (NO_MENU=true)
- Solo: conectividad, repos, upgrade, limpieza APT, reinicio
- Sin backups, sin snapshots, sin Docker, sin SMART

**custom** - Configuracion personalizada:
- Modo desatendido (UNATTENDED=true) - acepta todo automaticamente
- Sin interfaz grafica (NO_MENU=true)
- Lee TODA la configuracion desde `autoclean.conf`
- Permite personalizar idioma, tema y todos los pasos individualmente
- Si el archivo no existe, se genera automaticamente con valores por defecto

---

## Screenshots

### Resumen de Ejecucion

El script muestra un resumen detallado al finalizar con el estado de cada paso:

![Resumen de Ejecucion 1](screenshots/resumen-ejecucion-1.png)

![Resumen de Ejecucion 2](screenshots/resumen-ejecucion-2.png)

![Resumen de Ejecucion 3](screenshots/resumen-ejecucion-3.png)

![Resumen de Ejecucion 4](screenshots/resumen-ejecucion-4.png)

![Resumen de Ejecucion 5](screenshots/resumen-ejecucion-5.png)

![Resumen de Ejecucion 6](screenshots/resumen-ejecucion-6.png)

---

## Menu Interactivo

Al ejecutar el script sin argumentos, se muestra un menu interactivo en formato grid 5x3 que permite seleccionar que pasos ejecutar:

```
╔════════════════════════════════════════════════════════════════════════════╗
║                    CONFIGURACION DE MANTENIMIENTO                          ║
╠════════════════════════════════════════════════════════════════════════════╣
║                   Debian GNU/Linux | debian (forky)                        ║
╠════════════════════════════════════════════════════════════════════════════╣
║ PASOS (←/→ columnas, ↑/↓ filas, ESPACIO toggle, ENTER ejecutar)            ║
║  [x]Conectivida  [x]Dependencia  [x]Backup                                 ║
║  [x]Snapshot     [x]Repos       >[x]Upgrade                                ║
║  [x]Flatpak      [ ]Snap         [x]Firmware                               ║
║  [x]APT Clean    [x]Kernels      [x]Disco                                  ║
║  [ ]Docker       [x]SMART        [x]Reinicio                               ║
╠════════════════════════════════════════════════════════════════════════════╣
║ > Ejecuta apt full-upgrade para actualizar paquetes                        ║
╠════════════════════════════════════════════════════════════════════════════╣
║ Seleccionados: 13/15    Perfil: Guardado                                   ║
╠════════════════════════════════════════════════════════════════════════════╣
║          [ENTER] Ejecutar [A] Todos [N] Ninguno [G] Guardar [Q] Salir      ║
╚════════════════════════════════════════════════════════════════════════════╝
```

### Controles del Menu

| Tecla | Accion |
|-------|--------|
| ← / → | Navegar entre columnas |
| ↑ / ↓ | Navegar dentro de la columna |
| ESPACIO | Activar/desactivar paso seleccionado |
| ENTER | Ejecutar con la configuracion actual |
| A | Activar todos los pasos |
| N | Desactivar todos los pasos |
| G | Guardar configuracion actual |
| D | Borrar configuracion guardada |
| L | Selector de idioma |
| T | Selector de tema |
| O | Menu de notificaciones |
| Q | Salir sin ejecutar |

### Configuracion Persistente

La configuracion se guarda en `autoclean.conf` en el mismo directorio del script:
- Al presionar **G**, se guarda el estado actual de todos los pasos
- Al iniciar el script, se carga automaticamente la configuracion guardada
- Al presionar **D**, se elimina el archivo de configuracion (vuelve a valores por defecto)
- **Si el archivo no existe, se genera automaticamente con valores por defecto**

El archivo `autoclean.conf` tiene el siguiente formato:
```bash
# Perfil guardado (server, desktop, developer, minimal, custom)
SAVED_PROFILE=custom

# Idioma (en, es, pt, fr, de, it)
SAVED_LANG=es

# Tema (default, norton, turbo, green, amber, dracula, matrix, synthwave, monokai)
SAVED_THEME=default

# Pasos (1=activo, 0=inactivo) - Solo aplica cuando SAVED_PROFILE=custom
STEP_CHECK_CONNECTIVITY=1
STEP_CHECK_DEPENDENCIES=1
STEP_BACKUP_TAR=1
# ... (15 pasos configurables)
```

Para ejecutar el script usando esta configuracion personalizada:
```bash
sudo ./autoclean.sh --profile custom
```

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
  sys-update-YYYYMMDD_HHMMSS.log    # Logs de cada ejecucion (ultimas 5)

/var/backups/debian-maintenance/
  backup_YYYYMMDD_HHMMSS.tar.gz     # Backup configuraciones APT (ultimos 5)
  packages_YYYYMMDD_HHMMSS.list     # Lista de paquetes instalados (ultimos 5)

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
  --dry-run            Simular ejecucion sin hacer cambios reales
  -y, --unattended     Modo desatendido sin confirmaciones
  --no-backup          No crear backup de configuraciones
  --no-menu            Omitir menu interactivo (usar config guardada o por defecto)
  --quiet              Modo silencioso (solo logs)
  --lang CODIGO        Forzar idioma (en, es, pt, fr, de, it)
  --profile PERFIL     Usar perfil predefinido (server, desktop, developer, minimal, custom)
  --schedule MODO      Crear timer systemd (daily, weekly, monthly)
  --unschedule         Eliminar timer systemd programado
  --schedule-status    Mostrar estado del timer programado
  --help               Mostrar ayuda completa
```

### Programacion Automatica con Systemd Timer

El script puede programarse automaticamente usando systemd timers:

```bash
# Programar ejecucion diaria a las 2:00 AM
sudo ./autoclean.sh --schedule daily

# Programar ejecucion semanal (domingos a las 2:00 AM)
sudo ./autoclean.sh --schedule weekly

# Programar ejecucion mensual (dia 1 a las 2:00 AM)
sudo ./autoclean.sh --schedule monthly

# Ver estado del timer programado
sudo ./autoclean.sh --schedule-status

# Eliminar timer programado
sudo ./autoclean.sh --unschedule
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

## Solucion de Problemas

### El script se detiene con error de lock

**Solucion:**
```bash
sudo rm /var/run/debian-maintenance.lock
```

### APT esta ocupado

**Causa:** Otro gestor de paquetes esta en ejecucion (Synaptic, Discover, Software Center)
**Solucion:** Cierra todos los gestores de paquetes y vuelve a intentar

### Timeshift no esta configurado

El script detecta automaticamente si Timeshift esta instalado pero no configurado y muestra:

```
╔═══════════════════════════════════════════════════════════════╗
║  ⚠️  TIMESHIFT NO ESTÁ CONFIGURADO                            ║
╚═══════════════════════════════════════════════════════════════╝

  Para configurarlo, ejecuta:
    sudo timeshift-gtk  (interfaz gráfica)
    sudo timeshift --wizard  (terminal)
```

**Solucion:** Configura Timeshift antes de ejecutar el script:
```bash
# Interfaz grafica (recomendado)
sudo timeshift-gtk

# O por terminal
sudo timeshift --wizard
```

El script continuara sin snapshot si presionas cualquier tecla.

### Error al crear snapshot de Timeshift

Si Timeshift esta configurado pero falla al crear el snapshot:

- **Modo interactivo**: El script pregunta si deseas continuar sin snapshot (debes escribir "SI")
- **Modo desatendido (-y)**: El script aborta por seguridad

**Solucion alternativa:** Omite el paso de Timeshift:
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

---

## Estadisticas del Proyecto

- **Scripts totales:** 1
- **Script principal:** autoclean.sh
- **Version actual:** 2025.12
- **Lineas de codigo:** ~3500+
- **Pasos modulares:** 15
- **Idiomas soportados:** 6 (en, es, pt, fr, de, it) - deteccion dinamica
- **Temas de colores:** 9 (Default, Norton, Turbo, Green, Amber, Dracula, Matrix, Synthwave, Monokai) - deteccion dinamica
- **Notificadores:** 5 (Desktop, Telegram, ntfy.sh, Webhook, Email) - arquitectura de plugins extensible
- **Distribuciones soportadas:** 7+ (auto-deteccion)
- **Compatible con:** Debian, Ubuntu, Mint, Pop!_OS, Elementary, Zorin, Kali y derivadas
- **Interfaz:** Enterprise UI con grid 5x3, navegacion bidimensional, selector de idioma, temas y notificaciones

---

## Changelog v2025.12

### Nuevas Funcionalidades
- **Sistema de Notificaciones Multi-canal** - Arquitectura de plugins para notificaciones con menu dedicado `[O]`
- **Notificador Desktop** - Notificaciones de escritorio via notify-send (funciona con sudo)
- **Notificador Telegram** - Notificaciones via Telegram Bot API con configuracion guiada
- **Notificador ntfy.sh** - Push notifications via ntfy.sh con soporte para servidores self-hosted
- **Notificador Webhook** - HTTP webhooks con presets para Slack, Discord, Microsoft Teams y APIs custom
- **Notificador Email** - Email via SMTP con curl (Gmail, Outlook, Yahoo, custom) sin dependencias extra
- **Tutorial de notificadores** - Documentacion en `plugins/notifiers/TUTORIAL.md` para crear notificadores custom
- **Perfiles Predefinidos** - Nuevo argumento `--profile` con 5 perfiles: server, desktop, developer, minimal, **custom**
- **Perfil Custom** - Nuevo perfil que lee toda la configuracion desde `autoclean.conf` (idioma, tema y pasos)
- **Auto-generacion de configuracion** - Si `autoclean.conf` no existe, se genera automaticamente con valores por defecto
- **Limpieza Docker/Podman** - Nuevo paso para limpiar imagenes, contenedores y volumenes sin usar
- **Verificacion SMART** - Diagnostico de salud de discos duros antes de realizar cambios
- **Programacion Systemd Timer** - Opciones `--schedule`, `--unschedule`, `--schedule-status` para automatizar ejecucion
- **Deteccion dinamica de idiomas** - Los idiomas se detectan automaticamente desde `lang/`, selector en grid 4 columnas
- **Tutorial de idiomas** - Documentacion en `lang/TUTORIAL.md` para crear idiomas personalizados
- **Deteccion dinamica de temas** - Los temas se detectan automaticamente desde `themes/`
- **4 nuevos temas** - Dracula, Matrix (fondo negro), Synthwave (fondo purpura), Monokai
- **Tutorial de temas** - Documentacion en `themes/TUTORIAL.md` para crear temas personalizados

### Mejoras
- **UI de configuracion de notificadores** - Interfaz clara con campos numerados, indicadores de estado y guardado directo
- **Descripciones de notificadores traducidas** - Las descripciones se adaptan al idioma seleccionado
- **Archivo de configuracion mejorado** - Ahora incluye SAVED_PROFILE, idioma, tema, notificadores y todos los pasos
- **Orden logico de pasos** - Reorganizado en 5 fases: Verificaciones, Backups, Actualizaciones, Limpieza, Final
- **SMART en posicion temprana** - Verifica salud de discos ANTES de hacer cambios al sistema
- **Instalacion interactiva de herramientas** - Ofrece instalar smartmontools si no esta disponible
- **EXECUTION SUMMARY completo** - Ahora muestra los 15 pasos correctamente
- **Selectores en grid 4 columnas** - Tanto idiomas como temas usan navegacion con flechas
- **Validacion de archivos de configuracion** - Los archivos `.conf`, `.lang` y `.theme` se validan antes de cargar

### Seguridad
- **Funcion validate_source_file()** - Valida archivos antes de `source` para prevenir inyeccion de codigo
- **Funcion validate_notifier_file()** - Validacion especifica para plugins que permite comandos pero bloquea patrones peligrosos
- **Variables seguras con declare -n** - Usa nameref en lugar de eval para manipulacion de variables en el menu
- **Limpieza segura con find** - Usa find con delimitadores seguros en lugar de ls | xargs rm

### Correcciones
- **Fix Norton Commander theme** - Corregido overflow de fondo azul fuera de los margenes
- **Fix resumen de ejecucion** - Arreglado para mostrar 15/15 pasos en lugar de 13/13

---

**Ultima actualizacion del README:** Diciembre 2025
