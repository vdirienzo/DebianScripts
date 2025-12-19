# Como Crear tu Propio Idioma para Autoclean

Este tutorial te guiara paso a paso para agregar un nuevo idioma al script.

---

## Estructura de un Archivo de Idioma

Los idiomas son archivos `.lang` que contienen todas las cadenas de texto traducidas.

```
lang/
├── en.lang      # Ingles (idioma base)
├── es.lang      # Espanol
├── pt.lang      # Portugues
├── fr.lang      # Frances
├── de.lang      # Aleman
├── it.lang      # Italiano
├── ru.lang      # Ruso
└── mi-idioma.lang  # Tu idioma personalizado
```

---

## Variables Obligatorias

Cada archivo `.lang` debe contener estas variables:

### Identificacion

```bash
LANG_NAME="Nombre del Idioma"   # Nombre que aparece en el selector
LANG_CODE="xx"                   # Codigo ISO 639-1 (2 letras)
```

### Patron de Confirmacion

```bash
PROMPT_YES_PATTERN="^[Yy]$"     # Regex para detectar "Si"
```

Ejemplos por idioma:
- Ingles: `^[Yy]$` (Y/y)
- Espanol: `^[SsYy]$` (S/s o Y/y)
- Aleman: `^[JjYy]$` (J/j o Y/y)
- Frances: `^[OoYy]$` (O/o o Y/y)
- Ruso: `^[ДдYy]$` (Д/д o Y/y)

---

## Categorias de Variables

El archivo de idioma contiene varias categorias de variables:

### 1. Titulos de Menu (MENU_*)

```bash
MENU_TITLE="CONFIGURACION DE MANTENIMIENTO"
MENU_SYSTEM_TITLE="MANTENIMIENTO DEL SISTEMA"
MENU_SUMMARY_TITLE="RESUMEN DE EJECUCION"
MENU_STEPS_TITLE="PASOS"
```

### 2. Nombres de Pasos (STEP_NAME_*, STEP_SHORT_*, STEP_DESC_*)

```bash
# Nombres completos (para logs y ayuda)
STEP_NAME_1="Verificar conectividad"
STEP_NAME_2="Verificar dependencias"
...

# Nombres cortos (para el grid del menu - max 11 caracteres)
STEP_SHORT_1="Conectivid."
STEP_SHORT_2="Dependenc."
...

# Descripciones (ayuda contextual)
STEP_DESC_1="Verificar conexion a internet antes de continuar"
...
```

### 3. Controles del Menu (MENU_CTRL_*)

```bash
MENU_CTRL_ENTER="Ejecutar"
MENU_CTRL_ALL="Todos"
MENU_CTRL_NONE="Ninguno"
MENU_CTRL_SAVE="Guardar"
MENU_CTRL_LANG="Idioma"
MENU_CTRL_THEME="Tema"
MENU_CTRL_QUIT="Salir"
```

### 4. Prompts de Confirmacion (PROMPT_*)

```bash
PROMPT_CONTINUE="Continuar? (s/N):"
PROMPT_INSTALL_TOOLS="Desea instalarlas automaticamente? (s/N):"
PROMPT_REBOOT_NOW="Desea reiniciar ahora? (s/N):"
```

### 5. Mensajes Generales (MSG_*)

```bash
MSG_CHECKING="Verificando"
MSG_COMPLETED="Completado"
MSG_FAILED="Fallido"
MSG_SKIPPED="Omitido"
MSG_OK="OK"
MSG_ERROR="ERROR"
MSG_WARNING="ADVERTENCIA"
```

### 6. Mensajes Especificos por Funcion

```bash
# Conectividad
MSG_CONNECTION_OK="Conexion a internet: OK"
MSG_NO_CONNECTION="Sin conexion a internet"

# Backup
MSG_CREATING_BACKUP="Creando backup de configuracion..."
MSG_BACKUP_CREATED="Backup creado"

# Actualizacion
MSG_UPDATING_REPOS="Actualizando lista de repositorios..."
MSG_PACKAGES_UPDATED="%d paquetes actualizados"
```

### 7. Texto de Ayuda (HELP_*)

```bash
HELP_TITLE="Mantenimiento Integral para Distribuciones basadas en Debian/Ubuntu"
HELP_USAGE="Uso: sudo ./autoclean.sh [opciones]"
HELP_OPTIONS="Opciones:"
```

### 8. Iconos ASCII

```bash
ICON_OK="[OK]"
ICON_FAIL="[XX]"
ICON_SKIP="[--]"
ICON_WARN="[!!]"
```

---

## Crear tu Idioma Paso a Paso

### Paso 1: Copiar el archivo base (ingles)

```bash
cd lang/
cp en.lang mi-idioma.lang
```

### Paso 2: Editar la identificacion

```bash
LANG_NAME="Mi Idioma"
LANG_CODE="xx"
```

### Paso 3: Traducir todas las cadenas

Edita cada variable con la traduccion correspondiente.

**Importante:**
- Mantene los `%s` y `%d` en su posicion (son marcadores de formato)
- No traduzcas los nombres de comandos (apt, snap, flatpak, etc.)
- Respeta los espacios y formato de los mensajes

### Paso 4: Ajustar el patron de confirmacion

```bash
# Si tu idioma usa "D" para "Da" (Si)
PROMPT_YES_PATTERN="^[DdYy]$"

# Ajusta todos los prompts para usar la letra correcta
PROMPT_CONTINUE="Continuar? (d/N):"
```

---

## Ejemplo: Crear Idioma Holandes

```bash
# lang/nl.lang

LANG_NAME="Nederlands"
LANG_CODE="nl"

# Patron de confirmacion (J = Ja)
PROMPT_YES_PATTERN="^[JjYy]$"
PROMPT_CONTINUE="Doorgaan? (j/N):"

# Titulos
MENU_TITLE="ONDERHOUDSCONFIGURATIE"
MENU_STEPS_TITLE="STAPPEN"

# Mensajes
MSG_CHECKING="Controleren"
MSG_COMPLETED="Voltooid"
MSG_FAILED="Mislukt"
MSG_OK="OK"
MSG_ERROR="FOUT"
...
```

---

## Probar tu Idioma

Los idiomas se detectan automaticamente. No necesitas modificar ningun codigo.

1. Guarda tu archivo `.lang` en la carpeta `lang/`

2. Ejecuta autoclean:
   ```bash
   sudo ./autoclean.sh
   ```

3. Presiona `[L]` en el menu para abrir el selector de idiomas
   - El selector muestra los idiomas en un grid de 4 columnas
   - Navega con las flechas ←/→/↑/↓
   - Tu nuevo idioma aparecera automaticamente

4. Selecciona tu idioma con ENTER

5. Si te gusta, presiona `[G]` para guardar la configuracion

---

## Variables con Formato

Algunas variables usan marcadores de formato:

| Marcador | Tipo | Ejemplo |
|----------|------|---------|
| `%s` | Texto | `MSG_BACKUP_CREATED="Backup en %s"` |
| `%d` | Numero | `MSG_PACKAGES_UPDATED="%d paquetes"` |

**No cambies el orden ni la cantidad de marcadores.**

---

## Consejos

- **Usa en.lang como referencia**: Es el archivo mas completo y actualizado
- **Mantene los nombres cortos**: STEP_SHORT_* debe tener maximo 11 caracteres
- **Prueba todos los flujos**: Ejecuta el script completo para ver todos los mensajes
- **Usa UTF-8**: Guarda el archivo con codificacion UTF-8 para caracteres especiales

---

## Compartir tu Idioma

Si creaste una traduccion completa, podes compartirla:

1. Subila como Pull Request al repositorio
2. O compartila en los Issues

La comunidad agradece nuevas traducciones.

---

## Lista de Variables (Referencia Rapida)

Para ver todas las variables disponibles, consulta el archivo `en.lang` que contiene la lista completa con comentarios.

Total aproximado: ~150 variables organizadas en categorias.
