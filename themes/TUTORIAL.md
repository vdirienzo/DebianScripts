# Como Crear tu Propio Tema para Autoclean

Este tutorial te guiara paso a paso para crear un tema personalizado.

---

## Estructura de un Archivo de Tema

Los temas son archivos `.theme` que contienen variables de color usando codigos ANSI.

```
themes/
├── default.theme    # Tema por defecto (azul/cyan)
├── norton.theme     # Estilo Norton Commander
├── amber.theme      # Terminal ambar vintage
├── green.theme      # Terminal verde retro
├── turbo.theme      # Estilo Turbo Pascal
└── mi-tema.theme    # Tu tema personalizado
```

---

## Codigos de Color ANSI

### Formato Basico

```
\033[ESTILO;COLOR;FONDOm
```

| Parte | Descripcion |
|-------|-------------|
| `\033[` | Inicio de secuencia ANSI |
| `ESTILO` | 0=normal, 1=brillante, 2=atenuado |
| `COLOR` | Color del texto (30-37) |
| `FONDO` | Color de fondo (40-47) - opcional |
| `m` | Fin de secuencia |

### Colores Disponibles

| Codigo | Color | Codigo Fondo |
|--------|-------|--------------|
| 30 | Negro | 40 |
| 31 | Rojo | 41 |
| 32 | Verde | 42 |
| 33 | Amarillo/Ambar | 43 |
| 34 | Azul | 44 |
| 35 | Magenta | 45 |
| 36 | Cyan | 46 |
| 37 | Blanco | 47 |

### Ejemplos de Combinaciones

```bash
'\033[0;31m'      # Rojo normal
'\033[1;31m'      # Rojo brillante
'\033[2;31m'      # Rojo atenuado
'\033[0;32;44m'   # Verde sobre fondo azul
'\033[1;33;41m'   # Amarillo brillante sobre fondo rojo
'\033[0m'         # Reset (vuelve a colores por defecto)
```

---

## Variables del Tema

### Variables Obligatorias

```bash
# Identificacion del tema
THEME_NAME="Nombre del Tema"    # Nombre que aparece en el selector
THEME_CODE="codigo"             # Nombre del archivo sin .theme

# Colores base (usados en todo el script)
T_RED='\033[0;31m'              # Rojo - errores criticos
T_GREEN='\033[0;32m'            # Verde - exito
T_YELLOW='\033[1;33m'           # Amarillo - advertencias
T_BLUE='\033[0;34m'             # Azul - informacion
T_CYAN='\033[0;36m'             # Cyan - mensajes secundarios
T_MAGENTA='\033[0;35m'          # Magenta - destacados
T_BRIGHT_GREEN='\033[1;32m'     # Verde brillante
T_BRIGHT_YELLOW='\033[1;33m'    # Amarillo brillante
T_BRIGHT_CYAN='\033[1;36m'      # Cyan brillante
T_DIM='\033[2m'                 # Texto atenuado

# Colores semanticos (elementos de UI)
T_BOX_BORDER='\033[0;34m'       # Color de bordes de cajas
T_BOX_TITLE='\033[1m'           # Color de titulos en cajas
T_TEXT_NORMAL='\033[0m'         # Texto normal
T_TEXT_SELECTED='\033[1;36m'    # Item seleccionado (cursor)
T_TEXT_ACTIVE='\033[0;32m'      # Items activos [x]
T_TEXT_INACTIVE='\033[2m'       # Items inactivos [ ]
T_STATUS_OK='\033[0;32m'        # Estado OK
T_STATUS_ERROR='\033[0;31m'     # Estado Error
T_STATUS_WARN='\033[1;33m'      # Estado Advertencia
T_STATUS_INFO='\033[0;36m'      # Estado Info
T_STEP_HEADER='\033[0;34m'      # Encabezados de pasos
```

### Variables Opcionales (para temas con fondo de color)

```bash
# Solo necesarias si tu tema usa fondo de color (como Norton)
T_BOX_BG='\033[44m'             # Fondo de las cajas
T_BOX_NC='\033[0m\033[44m'      # Reset + fondo (para preservar fondo)
```

---

## Crear tu Tema Paso a Paso

### Paso 1: Copiar un tema base

```bash
cd themes/
cp default.theme mi-tema.theme
```

### Paso 2: Editar la identificacion

```bash
THEME_NAME="Mi Tema Personalizado"
THEME_CODE="mi-tema"
```

### Paso 3: Elegir tu paleta de colores

Decide el estilo que quieres:
- **Monocromo**: Un solo color en diferentes intensidades (como amber/green)
- **Multicolor**: Diferentes colores para cada elemento (como default)
- **Con fondo**: Colores sobre fondo de color (como norton)

### Paso 4: Modificar los colores

Edita cada variable segun tu preferencia.

---

## Ejemplos de Temas

### Ejemplo 1: Tema Monocromo Azul

```bash
# Autoclean Theme: Blue Mono
THEME_NAME="Blue Mono"
THEME_CODE="blue-mono"

# Todo en azul
T_RED='\033[0;34m'
T_GREEN='\033[0;34m'
T_YELLOW='\033[1;34m'
T_BLUE='\033[0;34m'
T_CYAN='\033[0;34m'
T_MAGENTA='\033[0;34m'
T_BRIGHT_GREEN='\033[1;34m'
T_BRIGHT_YELLOW='\033[1;34m'
T_BRIGHT_CYAN='\033[1;34m'
T_DIM='\033[2;34m'

T_BOX_BORDER='\033[0;34m'
T_BOX_TITLE='\033[1;34m'
T_TEXT_NORMAL='\033[0;34m'
T_TEXT_SELECTED='\033[1;34;44m'
T_TEXT_ACTIVE='\033[1;34m'
T_TEXT_INACTIVE='\033[2;34m'
T_STATUS_OK='\033[1;34m'
T_STATUS_ERROR='\033[0;34m'
T_STATUS_WARN='\033[1;34m'
T_STATUS_INFO='\033[0;34m'
T_STEP_HEADER='\033[1;34m'
```

### Ejemplo 2: Tema Rojo sobre Negro

```bash
# Autoclean Theme: Blood Red
THEME_NAME="Blood Red"
THEME_CODE="blood-red"

T_RED='\033[1;31m'
T_GREEN='\033[0;31m'
T_YELLOW='\033[1;31m'
T_BLUE='\033[0;31m'
T_CYAN='\033[0;31m'
T_MAGENTA='\033[1;35m'
T_BRIGHT_GREEN='\033[1;31m'
T_BRIGHT_YELLOW='\033[1;31m'
T_BRIGHT_CYAN='\033[1;31m'
T_DIM='\033[2;31m'

T_BOX_BORDER='\033[0;31m'
T_BOX_TITLE='\033[1;31m'
T_TEXT_NORMAL='\033[0;31m'
T_TEXT_SELECTED='\033[1;37;41m'  # Blanco sobre rojo
T_TEXT_ACTIVE='\033[1;31m'
T_TEXT_INACTIVE='\033[2;31m'
T_STATUS_OK='\033[1;31m'
T_STATUS_ERROR='\033[1;37;41m'
T_STATUS_WARN='\033[1;31m'
T_STATUS_INFO='\033[0;31m'
T_STEP_HEADER='\033[1;31m'
```

### Ejemplo 3: Tema con Fondo Verde (estilo Matrix)

```bash
# Autoclean Theme: Matrix
THEME_NAME="Matrix"
THEME_CODE="matrix"

T_RED='\033[1;32;40m'
T_GREEN='\033[1;32;40m'
T_YELLOW='\033[1;32;40m'
T_BLUE='\033[0;32;40m'
T_CYAN='\033[1;32;40m'
T_MAGENTA='\033[1;32;40m'
T_BRIGHT_GREEN='\033[1;32;40m'
T_BRIGHT_YELLOW='\033[1;32;40m'
T_BRIGHT_CYAN='\033[1;32;40m'
T_DIM='\033[2;32;40m'

T_BOX_BG='\033[40m'
T_BOX_NC='\033[0m\033[40m'

T_BOX_BORDER='\033[1;32;40m'
T_BOX_TITLE='\033[1;32;40m'
T_TEXT_NORMAL='\033[0;32;40m'
T_TEXT_SELECTED='\033[1;37;42m'  # Blanco sobre verde
T_TEXT_ACTIVE='\033[1;32;40m'
T_TEXT_INACTIVE='\033[2;32;40m'
T_STATUS_OK='\033[1;32;40m'
T_STATUS_ERROR='\033[1;31;40m'
T_STATUS_WARN='\033[1;33;40m'
T_STATUS_INFO='\033[0;32;40m'
T_STEP_HEADER='\033[1;32;40m'
```

---

## Probar tu Tema

Los temas se detectan automaticamente desde la carpeta `themes/`. No necesitas modificar ningun codigo.

1. Guarda tu archivo `.theme` en la carpeta `themes/`
   ```bash
   # Ejemplo: crear tema "mi-tema"
   cp themes/default.theme themes/mi-tema.theme
   nano themes/mi-tema.theme
   ```

2. Ejecuta autoclean:
   ```bash
   sudo ./autoclean.sh
   ```

3. Presiona `[T]` en el menu para abrir el selector de temas
   - El selector muestra los temas en un grid de 4 columnas
   - Navega con las flechas ←/→/↑/↓
   - Tu nuevo tema aparecera automaticamente en la lista

4. Selecciona tu tema con ENTER y verifica como se ve

5. Si te gusta, presiona `[G]` para guardar la configuracion

---

## Consejos

- **Contraste**: Asegurate de que el texto sea legible sobre el fondo de tu terminal
- **Consistencia**: Usa la misma intensidad (0, 1, 2) para elementos relacionados
- **Prueba en diferentes terminales**: Los colores pueden verse distintos en cada emulador
- **Fondo de terminal**: Ten en cuenta si tu terminal tiene fondo claro u oscuro

---

## Compartir tu Tema

Si creaste un tema que te gusta, podes compartirlo:

1. Subilo como Pull Request al repositorio
2. O compartilo en los Issues con el codigo

La comunidad agradece nuevos temas.
