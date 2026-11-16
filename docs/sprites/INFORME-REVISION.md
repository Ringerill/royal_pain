# Revisión final de sprites

Procesados: 151 personajes. Archivos guardados: 144. Sin resultado: 7.

Se rehicieron las primeras 11 hojas usando Woman0 como modelo de proporciones. Los reintentos de woman78 y E-W-Assassin-Leader-01 fallaron; se conserva su versión anterior, con la corrección pendiente. Las otras siete fallidas también se reintentaron sin conseguir archivo.

## Transparencia

Las 144 hojas tienen canal RGBA, pero ninguna cumple por completo el requisito de las dos últimas celdas vacías: todas contienen alfa mayor que cero en esa zona. Cinco hojas no contienen ningún píxel con alfa cero. En 3 hojas más del 1 % de las celdas finales tiene alfa superior a 64/255.

El canal alfa se examinó en todos los archivos. Esto detecta fondos opacos, residuos semitransparentes y celdas finales contaminadas; no garantiza que todo residuo exterior al personaje esté identificado. Los valores exactos están en auditoria-transparencia.json y la vista sobre fondos contrastantes está en revision.html.

No se han limpiado ni umbralizado los originales: hacerlo indiscriminadamente puede borrar pelo, transparencias de ropa y contornos. Estas hojas son resultados de generación pendientes de limpieza y validación, no un lote aprobado para el juego. La anatomía, la pierna oculta y todos los ciclos tampoco tienen una validación exhaustiva.

## Sin archivo

- woman98.png
- woman99.png
- woman104.png
- woman120.png
- woman172.png
- E-W-Executoner.png
- E-W-Soldier-Leader01.png

## Hallazgos específicos de transparencia

En 103 hojas el alfa máximo de las celdas finales es como mucho 16/255: el incumplimiento es leve y no equivale a un fondo opaco.

E-W-Farmer01 presenta un fondo semitransparente visible sobre negro y magenta. E-W-Soldier-Mid02 y E-M-Noblewoman1 presentan contenido de personaje invadiendo las celdas finales; ese alfa alto no debe confundirse con un fondo falso.

Archivos sin ningún píxel completamente transparente:

- Characters/Female/woman115.png
- Characters/Female/woman136.png
- Characters/Female/woman146.png
- Enemies/E-Female/E-W-Farmer01.png
- Enemies/E-Male/E-M-Boss01.png

## Detalle por archivo

| Archivo | Transparente total | Alfa máximo en celdas vacías | Área de celdas vacías con alfa >64 |
|---|---:|---:|---:|
| Characters/Female/Woman0.png | 56.2% | 244 | 0.1% |
| Characters/Female/woman1.png | 0.9% | 5 | 0.0% |
| Characters/Female/woman103.png | 53.4% | 8 | 0.0% |
| Characters/Female/woman108.png | 43.6% | 2 | 0.0% |
| Characters/Female/woman112.png | 37.1% | 249 | 0.1% |
| Characters/Female/woman115.png | 0.0% | 244 | 0.3% |
| Characters/Female/woman119.png | 53.8% | 3 | 0.0% |
| Characters/Female/woman123.png | 28.3% | 3 | 0.0% |
| Characters/Female/woman124.png | 42.8% | 251 | 0.1% |
| Characters/Female/woman13.png | 47.0% | 3 | 0.0% |
| Characters/Female/woman134.png | 34.2% | 5 | 0.0% |
| Characters/Female/woman136.png | 0.0% | 46 | 0.0% |
| Characters/Female/woman14.png | 41.3% | 3 | 0.0% |
| Characters/Female/woman143.png | 50.2% | 245 | 0.1% |
| Characters/Female/woman146.png | 0.0% | 35 | 0.0% |
| Characters/Female/woman150.png | 42.8% | 1 | 0.0% |
| Characters/Female/woman154.png | 45.6% | 35 | 0.0% |
| Characters/Female/woman156.png | 39.6% | 8 | 0.0% |
| Characters/Female/woman161.png | 1.2% | 5 | 0.0% |
| Characters/Female/woman166.png | 32.4% | 255 | 0.6% |
| Characters/Female/woman168.png | 4.4% | 71 | 0.0% |
| Characters/Female/woman169.png | 21.1% | 6 | 0.0% |
| Characters/Female/woman170.png | 53.1% | 234 | 0.1% |
| Characters/Female/woman173.png | 47.8% | 10 | 0.0% |
| Characters/Female/woman174.png | 47.6% | 119 | 0.0% |
| Characters/Female/woman175.png | 46.2% | 35 | 0.0% |
| Characters/Female/woman176.png | 34.7% | 3 | 0.0% |
| Characters/Female/woman177.png | 35.2% | 197 | 0.0% |
| Characters/Female/woman2.png | 40.4% | 188 | 0.0% |
| Characters/Female/woman20.png | 52.5% | 2 | 0.0% |
| Characters/Female/woman21.png | 42.7% | 1 | 0.0% |
| Characters/Female/woman27.png | 44.2% | 251 | 0.1% |
| Characters/Female/woman29.png | 45.4% | 5 | 0.0% |
| Characters/Female/woman3.png | 46.1% | 11 | 0.0% |
| Characters/Female/woman32.png | 1.4% | 7 | 0.0% |
| Characters/Female/woman34.png | 54.2% | 58 | 0.0% |
| Characters/Female/woman35.png | 39.7% | 3 | 0.0% |
| Characters/Female/woman36.png | 30.3% | 8 | 0.0% |
| Characters/Female/woman37.png | 4.0% | 4 | 0.0% |
| Characters/Female/woman39.png | 24.0% | 1 | 0.0% |
| Characters/Female/woman46.png | 0.3% | 130 | 0.0% |
| Characters/Female/woman47.png | 42.8% | 1 | 0.0% |
| Characters/Female/woman5.png | 52.5% | 10 | 0.0% |
| Characters/Female/woman50.png | 33.7% | 2 | 0.0% |
| Characters/Female/woman57.png | 51.5% | 154 | 0.0% |
| Characters/Female/woman59.png | 38.6% | 54 | 0.0% |
| Characters/Female/woman65.png | 26.3% | 2 | 0.0% |
| Characters/Female/woman71.png | 33.5% | 1 | 0.0% |
| Characters/Female/woman72.png | 46.8% | 255 | 0.6% |
| Characters/Female/woman74.png | 36.5% | 1 | 0.0% |
| Characters/Female/woman75.png | 35.0% | 239 | 0.0% |
| Characters/Female/woman78.png | 40.8% | 242 | 0.0% |
| Characters/Female/woman79.png | 39.6% | 1 | 0.0% |
| Characters/Female/woman81.png | 18.1% | 16 | 0.0% |
| Characters/Female/woman82.png | 38.2% | 246 | 0.1% |
| Enemies/E-Female/E-W-Assassin-boss01.png | 50.0% | 252 | 0.1% |
| Enemies/E-Female/E-W-Assassin-Leader-01.png | 53.0% | 251 | 0.1% |
| Enemies/E-Female/E-W-Assassin02.png | 54.1% | 152 | 0.0% |
| Enemies/E-Female/E-W-Bandit-Leader01.png | 34.0% | 250 | 0.1% |
| Enemies/E-Female/E-W-Bandit01.png | 57.8% | 255 | 0.3% |
| Enemies/E-Female/E-W-Bandit02.png | 55.4% | 10 | 0.0% |
| Enemies/E-Female/E-W-Beggar01.png | 55.3% | 249 | 0.1% |
| Enemies/E-Female/E-W-Berserker.png | 51.0% | 4 | 0.0% |
| Enemies/E-Female/E-W-Blacksmith.png | 51.5% | 1 | 0.0% |
| Enemies/E-Female/E-W-Boss01.png | 44.5% | 4 | 0.0% |
| Enemies/E-Female/E-W-commoner.png | 45.2% | 1 | 0.0% |
| Enemies/E-Female/E-W-commoner2.png | 36.3% | 247 | 0.1% |
| Enemies/E-Female/E-W-Explorer01.png | 58.8% | 59 | 0.0% |
| Enemies/E-Female/E-W-Farmer01.png | 0.0% | 236 | 100.0% |
| Enemies/E-Female/E-W-Farmer02.png | 43.7% | 4 | 0.0% |
| Enemies/E-Female/E-W-Mage-Damage01.png | 45.2% | 1 | 0.0% |
| Enemies/E-Female/E-W-Mage-Healer01.png | 5.4% | 4 | 0.0% |
| Enemies/E-Female/E-W-Noblewoman1.png | 53.2% | 255 | 0.1% |
| Enemies/E-Female/E-W-Noblewoman2.png | 49.7% | 1 | 0.0% |
| Enemies/E-Female/E-W-Old-Hero.png | 65.2% | 1 | 0.0% |
| Enemies/E-Female/E-W-Pirate-1.png | 52.3% | 3 | 0.0% |
| Enemies/E-Female/E-W-Pirate-leader.png | 53.9% | 1 | 0.0% |
| Enemies/E-Female/E-W-Shopkeeper.png | 38.3% | 4 | 0.0% |
| Enemies/E-Female/E-W-Soldier-Boss01.png | 63.1% | 16 | 0.0% |
| Enemies/E-Female/E-W-Soldier-Heavy01.png | 67.0% | 3 | 0.0% |
| Enemies/E-Female/E-W-Soldier-Mid01.png | 55.6% | 1 | 0.0% |
| Enemies/E-Female/E-W-Soldier-Mid02.png | 47.0% | 255 | 1.1% |
| Characters/Male/male1.png | 48.6% | 3 | 0.0% |
| Characters/Male/male10.png | 57.4% | 2 | 0.0% |
| Characters/Male/male14.png | 48.1% | 2 | 0.0% |
| Characters/Male/male16.png | 3.4% | 3 | 0.0% |
| Characters/Male/male18.png | 53.0% | 1 | 0.0% |
| Characters/Male/male2.png | 45.7% | 2 | 0.0% |
| Characters/Male/male29.png | 53.9% | 2 | 0.0% |
| Characters/Male/male31.png | 60.0% | 1 | 0.0% |
| Characters/Male/male35.png | 51.4% | 1 | 0.0% |
| Characters/Male/male36.png | 8.1% | 4 | 0.0% |
| Characters/Male/male37.png | 4.9% | 3 | 0.0% |
| Characters/Male/male4.png | 5.6% | 4 | 0.0% |
| Characters/Male/male40.png | 30.1% | 200 | 0.0% |
| Characters/Male/male45.png | 25.2% | 2 | 0.0% |
| Characters/Male/male48.png | 46.2% | 2 | 0.0% |
| Characters/Male/male5.png | 43.4% | 2 | 0.0% |
| Characters/Male/male53.png | 39.0% | 1 | 0.0% |
| Characters/Male/male55.png | 56.8% | 2 | 0.0% |
| Characters/Male/male59.png | 0.1% | 14 | 0.0% |
| Characters/Male/male62.png | 47.7% | 3 | 0.0% |
| Characters/Male/male63.png | 22.1% | 2 | 0.0% |
| Characters/Male/male67.png | 51.4% | 6 | 0.0% |
| Characters/Male/male69.png | 31.3% | 2 | 0.0% |
| Characters/Male/male7.png | 47.0% | 2 | 0.0% |
| Characters/Male/male70.png | 51.5% | 2 | 0.0% |
| Characters/Male/male71.png | 53.5% | 1 | 0.0% |
| Characters/Male/male72.png | 54.6% | 1 | 0.0% |
| Characters/Male/male73.png | 41.1% | 2 | 0.0% |
| Characters/Male/male74.png | 42.2% | 199 | 0.0% |
| Characters/Male/male75.png | 48.6% | 1 | 0.0% |
| Characters/Male/male76.png | 46.0% | 4 | 0.0% |
| Characters/Male/male77.png | 44.0% | 2 | 0.0% |
| Characters/Male/male78.png | 52.3% | 1 | 0.0% |
| Enemies/E-Male/E-M-Assassin-boss01.png | 55.0% | 2 | 0.0% |
| Enemies/E-Male/E-M-Assassin-Leader-01.png | 52.6% | 1 | 0.0% |
| Enemies/E-Male/E-M-Assassin02.png | 66.5% | 234 | 0.0% |
| Enemies/E-Male/E-M-Bandit-Leader01.png | 60.7% | 1 | 0.0% |
| Enemies/E-Male/E-M-Bandit01.png | 50.0% | 3 | 0.0% |
| Enemies/E-Male/E-M-Bandit02.png | 54.9% | 1 | 0.0% |
| Enemies/E-Male/E-M-Beggar01.png | 62.7% | 3 | 0.0% |
| Enemies/E-Male/E-M-Berserker.png | 46.1% | 2 | 0.0% |
| Enemies/E-Male/E-M-Blacksmith.png | 53.1% | 1 | 0.0% |
| Enemies/E-Male/E-M-Boss01.png | 0.0% | 71 | 0.4% |
| Enemies/E-Male/E-M-commoner.png | 10.4% | 3 | 0.0% |
| Enemies/E-Male/E-M-commoner2.png | 19.1% | 2 | 0.0% |
| Enemies/E-Male/E-M-Executoner.png | 62.7% | 2 | 0.0% |
| Enemies/E-Male/E-M-Explorer01.png | 40.7% | 2 | 0.0% |
| Enemies/E-Male/E-M-Farmer01.png | 39.0% | 1 | 0.0% |
| Enemies/E-Male/E-M-Farmer02.png | 46.2% | 1 | 0.0% |
| Enemies/E-Male/E-M-Mage-Damage01.png | 40.8% | 2 | 0.0% |
| Enemies/E-Male/E-M-Mage-Healer01.png | 31.7% | 192 | 0.0% |
| Enemies/E-Male/E-M-Noblewoman1.png | 60.4% | 255 | 5.2% |
| Enemies/E-Male/E-M-Noblewoman2.png | 63.6% | 1 | 0.0% |
| Enemies/E-Male/E-M-Old-Hero.png | 28.9% | 2 | 0.0% |
| Enemies/E-Male/E-M-Pirate-1.png | 57.7% | 1 | 0.0% |
| Enemies/E-Male/E-M-Pirate-leader.png | 44.7% | 1 | 0.0% |
| Enemies/E-Male/E-M-Shopkeeper.png | 5.1% | 3 | 0.0% |
| Enemies/E-Male/E-M-Soldier-Boss01.png | 66.7% | 1 | 0.0% |
| Enemies/E-Male/E-M-Soldier-Heavy01.png | 1.9% | 3 | 0.0% |
| Enemies/E-Male/E-M-Soldier-Leader01.png | 41.8% | 2 | 0.0% |
| Enemies/E-Male/E-M-Soldier-Mid01.png | 47.5% | 2 | 0.0% |
| Enemies/E-Male/E-M-Soldier-Mid02.png | 40.3% | 2 | 0.0% |
