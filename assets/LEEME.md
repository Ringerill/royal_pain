# Organización de assets

Nombres en minúsculas y `snake_case`. Las variantes se añaden al final en este orden:
`_autumn` (otoño), `_winter` (invierno), `_night` (noche), `_destroyed` (destruido).
Ejemplo: `camp_winter_night_destroyed.png`. Sin sufijo = verano/día/intacto.

| Carpeta | Contenido |
|---|---|
| `maps/` | `world_map.png` (mundo completo con los 12 reinos) y `kingdoms/01…12` (un mapa por reino, nombrados por color). |
| `ui/backgrounds/` | Fondos de pantallas de interfaz: menú principal, creación de personaje, ajustes (armería), sala del consejo, game over y victoria. |
| `dialogue/<lugar>/` | Escenas de lugar para diálogos y eventos, con variantes de estación/noche/destrucción: `camp`, `bandit_camp`, `castle_hallway`, `bridge`, `city_inside`, `city_outside`, `port`, `road`, `council_meeting`. |
| `dialogue/places/` | Escenas únicas sin variantes: callejón, iglesia, cueva, celda, mazmorra, pasillo de casa, habitación, tienda, taberna, trono, torre, biblioteca, boda. |
| `battle/backgrounds/` | Fondos de combate lateral (suelo plano al frente): `meadow`, `forest`, `seaside`, `desert`, `town`, `siege_wall`, `tournament`, `training_ground`, `warship` (+ estaciones). |
| `battle/backgrounds/biomes/<bioma>/` | Carpetas para añadir fondos por bioma (se elige uno al azar; ver `biome_backgrounds.gd`). |
| `battle/sprite_sheets/` | Hojas de sprites de combate (reposo, ataque, golpe, caída). |
| `battle/terrain/` | Tiles del tablero táctico (Kenney). |
| `icons/locations/` | Iconos de tipos de lugar (pueblo, casa, castillo, cueva, puerto, camino, puente, torre, campamento, ciudad, muralla, barco, arena). |
| `icons/map_tiles/` | Iconos de nodo de mapa en estilo isla isométrica (campo de batalla, campamento, castillo, campo, pueblo). |
| `icons/game-icons/`, `icons/app/` | Iconos SVG de habilidades/objetos e iconos de la aplicación. |
| `fx/`, `music/`, `sfx/`, `portraits/` | Sin cambios. |

## Correcciones de nombre respecto al original

- `TurnFight-Celling` → `dialogue/places/cell` (es una celda)
- `TurnFight-Tabern` → `dialogue/places/tavern`
- `TurnFight-Trining_Ground` → `battle/backgrounds/training_ground`
- `Config` → `ui/backgrounds/settings_armory` (es una armería, no una pantalla «Config» genérica)
- `Council-Castle` → `ui/backgrounds/council_hall` (es la sala del consejo, no un castillo)
- `TurnFight-Game-Over` → `game_over_banner` (estandarte ardiendo) y `-dead` → `game_over_graveyard`
- `TurnFight-Meadow_Winter` / `Forest-Winter` / `Meadow-autumn`: ahora todos con el mismo patrón `_winter` / `_autumn`.
