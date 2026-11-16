# Correcciones solicitadas el 16 de noviembre de 2026

Alcance exclusivo de esta nueva pasada; no corregir otros personajes.

## Generar siete hojas faltantes

- Characters/Female/woman98.png
- Characters/Female/woman99.png
- Characters/Female/woman104.png
- Characters/Female/woman120.png
- Characters/Female/woman172.png
- Enemies/E-Female/E-W-Executoner.png
- Enemies/E-Female/E-W-Soldier-Leader01.png

## Editar hojas existentes

- Characters/Female/woman78.png: retirar el brazo sobrante en la caída de montura, especialmente fila 6 columna 2. Exactamente dos brazos y dos manos, cada uno unido a su hombro; conservar identidad y demás dibujos. Solo una pierna visible hasta fila 6 columna 1 inclusive.
- Characters/Female/woman115.png: eliminar falsa transparencia/fondo residual conservando dibujos.
- Characters/Female/woman136.png: eliminar falsa transparencia/fondo residual conservando dibujos.
- Characters/Female/woman146.png: eliminar falsa transparencia/fondo residual conservando dibujos.
- Characters/Female/woman46.png: eliminar falsa transparencia/fondo residual conservando dibujos.
- Enemies/E-Female/E-W-Farmer01.png: eliminar falsa transparencia/fondo residual conservando dibujos.
- Enemies/E-Male/E-M-Boss01.png: eliminar falsa transparencia/fondo residual conservando dibujos.
- Enemies/E-Female/E-W-Assassin-boss01.png: restaurar diseño de su retrato original: capucha oscura con forro rojo, máscara metálica plateada que cubre toda la cara, bufanda oscura, correas y armadura originales. No mostrar el rostro, ojos ni peinado de Woman0. Woman0 solo sirve como referencia de proporciones y poses. No confundir con Assassin-Leader-01.

Usar las reglas de 34 fotogramas, 6×6, sin caminar/correr, dash en fila 6 columna 4 y últimas dos celdas transparentes. No modificar los retratos fuente ni progreso.json. Preservar copias anteriores en work antes de sustituir resultados.

## Bloqueo de ejecución

El primer intento de edición de woman78 devolvió HTTP 429, usage_limit_reached: límite de uso de generación de imágenes agotado. El servicio indicó resets_at=1794889214. No se produjo ni sustituyó ninguna imagen en esta pasada. Las otras llamadas no se enviaron porque comparten ese mismo límite.
