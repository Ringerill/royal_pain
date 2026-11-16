# Royal Pain — Rediseño v2: lo que se hizo

Resumen detallado de las 9 fases del rediseño (noviembre de 2026, versión **0.11.0**). El diseño
acordado está en `docs/REDISENO.md`; aquí está lo que se programó de verdad, dónde está y cómo
se comprueba. Lo simplificado o pendiente se repite al final de cada fase y, todo junto, en
`docs/REDISENO.md` §10.

## Cómo se juega ahora (en una página)

1. **Creas tu personaje**: personalidad (9), vía (8), tipo de luchador y solo el arma básica.
2. **Mapa del reino** (pantalla principal): pulsas un lugar y viajas. El tiempo corre solo
   mientras viajas y cansa; con poca energía te desmayas y pierdes oro. Duermes en posadas y casas
   (se guarda la partida).
3. **Por los caminos** te cruzas con bandidos, patrullas, caravanas, viajeros y, en guerra,
   ejércitos.
4. **En ciudades, pueblos y puertos** entras a tiendas, herrería, taberna (encargos), iglesia,
   biblioteca, posada, tu casa, el callejón (de noche) y, en las capitales, el salón del trono.
5. **Cuevas, torres y campamentos bandidos** se exploran por salas; **la arena** tiene torneos.
6. **Asciendes** por hitos en el salón del trono y llevas más soldados.
7. **Tu vía tiene una meta** (en el Diario): cumplirla es ganar la partida.

## Piezas nuevas del código

| Pieza | Tipo | Para qué |
|---|---|---|
| `scripts/resources/kingdom_maps.gd` | `KingdomMaps` | Los 12 reinos, sus lugares y caminos |
| `scripts/resources/persona_catalog.gd` | `PersonaCatalog` | 9 personalidades |
| `scripts/resources/via_catalog.gd` | `ViaCatalog` | 8 vías |
| `scripts/resources/rank_catalog.gd` | `RankCatalog` | Rangos y soldados |
| `scripts/resources/sprite_sheets.gd` | `SpriteSheets` | Fotogramas de las hojas de sprites |
| `scripts/ui/sprite_anim.gd` | `SpriteAnim` | Anima las figuras del combate |
| `scripts/resources/gear_catalog.gd` | `GearCatalog` | Armas, escudos, armaduras y accesorios nuevos |
| `scripts/resources/place_art.gd` | `PlaceArt` | Escenas de lugar y expresiones de retratos |
| `scripts/autoload/journey.gd` | autoload `Journey` | Reloj, viajes, energía, casas |
| `scripts/autoload/contract_data.gd` | autoload `ContractData` | Encargos del tablón |
| `scripts/autoload/road_traffic.gd` | autoload `RoadTraffic` | Grupos en los caminos |
| `scripts/autoload/expeditions.gd` | autoload `Expeditions` | Expediciones y arena |
| `scripts/autoload/via_data.gd` | autoload `ViaData` | Metas, actos, mecánicas de vía, prisioneros |
| `scripts/autoload/career.gd` | autoload `Career` | Ascensos, soldados, alianzas, purga, ultimátum, piratas |
| `scenes/kingdom_map/` | escena | Mapa del reino (pantalla principal) |
| `scenes/place/` | escena | Lugar por dentro (novela visual) |
| `scenes/expedition/` | escena | Expedición o arena en curso |

Todos los autoloads nuevos se guardan con la partida (`SaveSystem.MODULES`), salvo `RoadTraffic`,
que repuebla los caminos al cargar.

---

## Fase 1 — Datos

**En el juego:** aún nada visible; es la base del resto. La estadística «Combate» pasa a llamarse
«Ataque».

**En el código:**
- `KingdomMaps`: cada reino con su mapa (`assets/maps/kingdoms/`), su bioma y 8–12 lugares
  colocados sobre lo dibujado (capital primero; pueblos, ciudades, puertos, cuevas, torres,
  puentes, campamentos, campamentos bandidos, arenas). Caminos por vecindad y horas de viaje.
- `PersonaCatalog`: estadísticas, afinidades entre personalidades, nombres del árbol y
  equivalencia con las 12 personalidades antiguas.
- `ViaCatalog`: mecánica, meta, ventajas y desventajas de cada vía.
- `RankCatalog`: rangos de inafiliado a rey y soldados por rango (+5 % por punto de Liderazgo).
- `Character`: campos nuevos `status_rank`, `via`, `persona`, `energy`, `max_energy`,
  `origin_kingdom`, `soldiers`, con equivalencias para personajes y partidas antiguas.

**Prueba:** `tests/v2_data_test.gd`.

---

## Fase 2 — Mapa del reino, reloj y viajes

**En el juego:**
- Pantalla principal nueva: el mapa del reino a pantalla completa, con sus lugares, caminos, tu
  ruta y tu personaje (primer fotograma de su hoja de sprites).
- HUD: hora, día, estación, energía, oro, fama y velocidad del tiempo (pausa, ×1, ×2, ×4).
  Accesos: Grupo, Relaciones, Diario, Mundo y Menú.
- El tiempo solo corre al viajar (≈1 hora por segundo). Meses de 30 días: cada mes se ejecuta el
  mes del mundo de siempre. Estaciones (invierno, verano, otoño), día y noche (tinte del mapa).
- Energía: viajar gasta 2 por hora. A 0 te desmayas: despiertas en el lugar habitado más cercano
  sin el 20 % del oro. Dormir (8 h) la recupera y guarda la partida; en campamentos se descansa.
- Viajes entre reinos: por tierra a los vecinos, por mar desde un puerto (pagando pasaje).
- Cada partida pone nombres propios a los lugares según la cultura del reino.

**En el código:** `Journey` (reloj, rutas, energía, viajes), `scenes/kingdom_map/`,
`SpriteSheets`. Todo «volver al mapa» va a `GameManager.MAP_SCENE`.

**Prueba:** `tests/v2_journey_test.gd`.

---

## Fase 3 — Combate con sprites

**En el juego:**
- **Vista «Sprites»** (la de por defecto): lateral, enemigos a la izquierda y tu grupo a la
  derecha, en zigzag. Hasta 8 por bando.
- Las figuras se animan: reposo (cansado si va mal), ataque, disparo, golpe, esquiva, bloqueo,
  derrota y caída del caballo. El jinete va sobre su caballo.
- **Ciclo de armas:** Espada → Lanza → Arco → Mandoble → Maza → Espada. Cada clase gana a las dos
  siguientes (×1,4) y pierde ante las dos anteriores (×0,6). La armadura solo da números.
- **Escudo:** anula la ventaja del atacante y a veces bloquea el golpe entero.
- **Estados nuevos:** veneno (daño fijo, 3 turnos), parálisis (50 % de perder el turno, 3 turnos),
  miedo (menos acierto, sin técnicas), agotamiento (menos Fuerza y Defensa; también si entras con
  poca energía) y derribado (al caer del caballo: pierde un turno). Los estados antiguos se
  traducen a estos.
- **Montura:** el caballo encaja parte de cada golpe; si se queda sin vida, el jinete cae.
- **Soldados:** 1 figura por cada 10 soldados (máx. 4); con más de 40, son más fuertes. Los mueve
  la IA.
- Las 4 vistas antiguas siguen en Opciones, marcadas «(antigua)».

**En el código:** `RpgStats` (clases de arma, afinidades, escudo, montura), `RpgBattleManager`
(estados, bloqueo, caballo, hasta 8 activos), `scenes/rpg_battle/rpg_battle.gd` (vista Sprites),
`SpriteAnim`, `RankCatalog.soldier_party`.

**Prueba:** `tests/v2_combat_test.gd`.

**Simplificado:** el fondo usa el bioma pero no cambia con la noche; los enemigos genéricos nunca
van montados.

---

## Fase 4 — Equipo, objetos, árboles y creación

**En el juego:**
- **Armas** (5 tipos × 10, con su dibujo): las 7 primeras son una progresión; las 3 últimas,
  definitivas con enfoque en agilidad, ataque o defensa.
- **Escudos** (10): defensa y probabilidad de bloqueo. No sirven con mandoble ni arco.
- **Armaduras** (15): cuero, malla y placas en 5 niveles.
- **Accesorios** (45): uno por atributo en 5 niveles y 15 únicos. **Se llevan dos.**
- **Objetos** (18, de `items.png`): pociones, tónicos y resurrección en 3 niveles; bomba,
  cuchillo, cuchillo envenenado, kunai y shuriken; antídoto y remedios de parálisis, miedo y
  agotamiento.
- **Árboles:** un árbol de puntos, el de tu personalidad. El del arma se desbloquea por nivel según
  la clase que llevas. El tipo de luchador conserva sus pasivas base.
- **Creación:** eliges personalidad y vía (con su descripción) y solo el arma básica de cada tipo.
  Las monturas se consiguen después.

**En el código:** `GearCatalog`, `GameData` (catálogo nuevo; de lo antiguo quedan monturas y
piezas únicas), `ConsumableCatalog`, `SkillTreeCatalog` (árboles por personalidad y por clase),
`scenes/character_creation/`.

**Prueba:** `tests/v2_gear_test.gd` (y `creation_rules_test` adaptada).

**Simplificado:** los árboles de personalidad reutilizan los antiguos más parecidos; las técnicas
con los nombres nuevos (Provocar, Carga, Calcular…) están por hacer.

---

## Fase 5 — Lugares, interiores y encargos

**En el juego:**
- **«Entrar»** en capitales, ciudades, pueblos y puertos: escena del lugar según estación y noche,
  con un botón por edificio. De noche solo abren taberna, posada, casa y callejón.
- **Interiores en novela visual:** fondo del interior y el PNJ del lugar en grande (siempre el
  mismo, con nombre), cuya cara cambia según el tono de lo que dice (10 expresiones).
  - **Tienda:** objetos y accesorios.
  - **Herrería:** armas, escudos y armaduras según el tamaño del lugar; mejora tu arma al siguiente
    nivel; compra lo que tengas en el almacén.
  - **Taberna:** rumores, tablón de encargos, dados.
  - **Iglesia:** curar al grupo, donar (fama).
  - **Biblioteca:** estudiar 4 horas (experiencia).
  - **Posada:** dormir por 10 de oro. **Casa:** se compra y luego duermes gratis.
  - **Callejón** (de noche): encargos turbios.
- **Encargos:** entregas, escoltas, cazas, despejes, rescates y turbios, con destino y plazo en
  días. Al llegar se cobran o hay combate; las escoltas pueden sufrir una emboscada. Vencer el
  plazo o abandonar cuesta fama. Aparecen en el Diario.

**En el código:** `scenes/place/`, `PlaceArt`, `ContractData`, `Journey` (casas, donaciones,
estudios).

**Prueba:** `tests/v2_places_test.gd`.

**Simplificado:** los nombres de los PNJ salen de una sola cultura.

---

## Fase 6 — Mundo vivo, expediciones y arena

**En el juego:**
- **Caminos vivos:** bandidos, patrullas, caravanas y viajeros se mueven con el reloj y se ven en
  el mapa. Al cruzarte con uno, el viaje se detiene:
  - **Bandidos:** luchar, pagar peaje o huir (según tu Agilidad).
  - **Patrulla:** solo ataca si tienes mala fama o eres Villano; luchar o sobornar.
  - **Caravana:** escoltarla un tramo (puede haber emboscada), comerciar o asaltarla.
  - **Viajero:** charlar o comprarle objetos más baratos.
  Un grupo vencido desaparece y otro aparece 12 horas después.
- **Expediciones** (cueva, torre olvidada, campamento bandido): 4 niveles de salas a elegir
  (combate, tesoro, descanso, trampa) y un jefe. Premio en oro y fama; el lugar se renueva a los
  20 días. Si pierdes un combate, sales.
- **Arena:** torneo de 3 rondas (curas entre rondas) y desafío de 4 jefes (sin curas), una vez al
  mes cada uno.

**En el código:** `RoadTraffic`, `Expeditions`, `scenes/expedition/`. Los combates de expedición
vuelven a su pantalla vía `CombatSetup.apply_outcome`.

**Prueba:** `tests/v2_world_test.gd`.

**Simplificado:** los grupos solo se simulan en el reino donde estás.

---

## Fase 7 — Relaciones, vías y prisioneros

**En el juego:**
- **Presencia por lugar:** cada persona vive en un lugar de su reino (los señores, en la capital).
  Solo tratas con quien está donde tú estás («Gente aquí» en la ciudad) o con quien te cruzas en
  el camino.
- **Hermandad:** con mucha intimidad y sin romance puedes jurarla; tu grupo lucha con más moral.
- **Afinidad:** lo que ganas al tratar con alguien depende de cómo congenian vuestras
  personalidades.
- **Vías:** las 8 tienen su meta con contador (en el Diario); cumplirla es ganar la partida y se
  puede seguir jugando. Tus actos suman a unas vías u otras; si otra supera claramente a la tuya,
  cambias de vía con aviso.
- **Mecánicas de vía** (las usa cualquiera; la tuya las potencia): faenas (taberna), limosna
  (iglesia), extorsión (callejón), sigilo (a veces evitas encuentros hostiles), colección de armas
  (+1 de Ataque por tipo completo) y carteles de «se busca» en el tablón (siempre para el
  Justiciero). El Humilde paga un 30 % menos en las tiendas.
- **Prisioneros:** tras vencer a bandidos o jefes puede rendirse uno: reclutarlo (+soldados),
  pedir rescate, liberarlo, ejecutarlo o venderlo.

**En el código:** `ViaData`, `RelationsData` (`node_of`, `people_here`, `road_company`,
`person_present`), `PersonalInteractions` (hermandad y afinidad), `Relationship.sworn`.

**Prueba:** `tests/v2_relations_test.gd`.

**Simplificado:** la hermandad solo da moral (no «te defiende sola»); los rivales no dan bonos
contra ti.

---

## Fase 8 — Rangos, soldados, reinos, ejércitos y mar

**En el juego:**
- **Salón del trono** (capitales): pides los ascensos, consigues soldados, gobiernas tus castillos
  y usas la Purga (Tirano) y el Ultimátum (Conquistador).
- **Ascensos por hitos:**

  | Rango | Requisitos |
  |---|---|
  | Trabajador | 3 encargos |
  | Soldado | 6 encargos, 5 victorias y fama 5 |
  | Caballero | 12 encargos, 2 jefes, 10 victorias y fama 20 |
  | Noble | 20 encargos, 5 jefes, 20 victorias, fama 40 y 2000 de oro |
  | Rey | Se reclama o se conquista |

- **Soldados:** por debajo de noble te los asigna tu comandante según tu fama; nobles y reyes los
  reclutan (12 de oro cada uno) y les pagan cada mes; si no hay oro, se marchan.
- **Alianzas con plazo:** 12 meses (6 si eres Conquistador); al vencer, se rompen.
- **Guerra:** un ejército enemigo recorre los caminos; puedes presentar batalla (con tus
  soldados) o apartarte.
- **Mar:** al viajar por mar pueden asaltarte piratas: luchar o entregar parte del oro.

**En el código:** `Career`, `RoadTraffic` (tipo «ejercito»), `scenes/place/place.gd` (trono),
`Relationship.allied_until`.

**Prueba:** `tests/v2_kingdoms_test.gd`.

**Simplificado:** **la batalla de nodos en tiempo real con órdenes sobre el mapa no está hecha**;
contra los ejércitos se lucha con el combate de siempre. El gobierno usa la pantalla del castillo
antigua.

---

## Fase 9 — Limpieza y pulido

**En el juego:**
- Complots y ambiciones, misiones antiguas y herencia dinástica ya no corren. **Al morir, la
  partida termina.**
- El menú del mapa ya no lleva al mapa antiguo; abre el glosario.
- Tutorial breve la primera vez que entras al mapa del reino.
- Glosario con cinco secciones nuevas: vías y metas, rangos y soldados, combate con sprites,
  lugares y encargos, caminos y expediciones.
- Arreglo: en las expediciones, una sala de combate solo cuenta como superada al ganarla.
- Versión 0.11.0 (código 33).

**En el código:** `GameManager.v2_retired` apaga los sistemas descartados (su código sigue en el
proyecto); las pruebas del sistema antiguo lo vuelven a encender.

**Simplificado:** el honor sigue existiendo por dentro (el HUD nuevo solo muestra la fama). Los
valores son una primera propuesta, sin ajustar con partidas largas.

---

## Pruebas

Cada fase tiene la suya: `tests/v2_data_test.gd`, `v2_journey_test`, `v2_combat_test`,
`v2_gear_test`, `v2_places_test`, `v2_world_test`, `v2_relations_test` y `v2_kingdoms_test`.
Todas pasan.

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/v2_combat_test.gd
```

En la batería completa fallan cinco pruebas que **ya fallaban antes del rediseño** o no dependen
de él: `build_test` («campamento: escaramuza»), `fights_test` (busca la escena de duelo antigua),
`c2_combat_test` (3 fallos de repliegue), `phase1_test` (un sorteo al azar) y `phase2b_test` (la
partida nueva genera 2 cortesanos en tu reino y la prueba pide 3; sin revisar).

## Otros cambios de la sesión

- Los retratos quedaron en `assets/portraits/Characters/Female` y `Characters/Male` (una sola
  carpeta, con sus `.import` correctos).
- Ejecutable de revisión: `builds/windows/RoyalPain.exe` (no va a git; hay copia en el Escritorio).
