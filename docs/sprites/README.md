# Sprites de combate

Importados 144 spritesheets y dos plantillas el 16 de noviembre de 2026.
Destino: `assets/battle/sprite_sheets/`.

Los archivos conservan los identificadores de los portraits, normalizados a minúsculas y snake_case. `import_manifest.json` relaciona cada nombre original con su ruta en el repositorio y su SHA-256. Las carpetas son `characters/female`, `characters/male`, `enemies/female` y `enemies/male`.

Plantillas en `templates/`:
- `template_original_dash.png`: plantilla original con dash.
- `template_woman0.png`: Woman0 aprobada como referencia común de proporciones.

Formato vigente: 34 fotogramas en una cuadrícula 6×6. Tres fotogramas por acción: reposo, ataque genérico, distancia, recibir daño, defender, cansancio, derrota, cabalgar, distancia montada, ataque montada y caída. Dash es el fotograma 34; 35 y 36 vacíos. Sin caminar ni correr. Ver REGLAS.md.

Estado: archivos generados, pendientes de las correcciones expresamente solicitadas; no están todos validados para juego. Faltan siete personajes. La cola vigente es PENDIENTES-SOLICITADOS.md: generar esas siete hojas y corregir solo woman78, transparencia de woman115/136/146/46/E-W-Farmer01/E-M-Boss01 y diseño de E-W-Assassin-boss01. El resto de hallazgos de la auditoría se conserva como información, fuera de esta cola.

Los cinco sprites antiguos que ya estaban sueltos en esta carpeta no fueron sustituidos. La versión importada de cada personaje se encuentra en las subcarpetas indicadas por el manifiesto.

Este repositorio es el destino de los próximos resultados terminados. Los portraits y expresiones existentes no se modificaron. Los informes de auditoría conservan nombres de origen: consultar el manifiesto para traducirlos a rutas del repositorio.
