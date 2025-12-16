# ============================================================================
# Script de Mantenimiento Integral para Debian 13 (Testing/Trixie)
# ============================================================================
# Versión: 2025.12
# Última revisión: Diciembre 2025 - Corrección de Bugs y Numeración
# Autor: Homero Thompson del Lago del Terror
#
# Filosofía de Ejecución: Máxima seguridad para la rama Testing.
#   1.  Verificar dependencias y espacio libre.
#   2.  Asegurar un punto de retorno (Backup Tar + Timeshift Snapshot).
#   3.  Analizar riesgos de APT (detener si se proponen borrados masivos).
#   4.  Actualizar solo si es seguro.
#   5.  Limpieza profunda post-actualización.

NOTA: son distintas versiones y mas o menos todas hacen lo mismo las voy a ir actualizando
