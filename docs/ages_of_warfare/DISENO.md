# Ages of Warfare — documento de diseño

Juego de conquista territorial con batallas por puntos y combates RPG por turnos, al estilo de
*Dynasty Warriors Empires*. Proyecto aparte, derivado de **Royal Pain** (Godot 4.7, GDScript).
Uso personal, solo PC por ahora.

---

## 1. Visión

Eres un personaje (de soldado a rey) en un mundo de reinos en guerra. Cada mes das órdenes
(gobernar, reclutar, aliarte, invadir) y luchas batallas por los territorios. Las batallas son
un mapa de puntos con grupos que se mueven por turnos; cuando dos grupos chocan, se libra un
combate RPG. Ganas al **unificar todo el mapa**; pierdes si **mueres** o pierdes tu **último
territorio**.

Una partida dura **6–10 horas** (unos 30–60 meses de juego).

---

## 2. Batalla de puntos (núcleo)

### Mapa y estructura
- Mapa de **6–9 puntos** conectados, a partir de **plantillas por terreno** (llanura, río con
  puente, desfiladero, bosque, aldea, asedio, naval…), elegidas según el territorio.
- Tipos de punto: campamento (principal y secundarios), aldea, puente, torre, colina, bosque,
  desfiladero, castillo (asedio), barco/zona de agua (naval).
- Duración objetivo: **5–10 minutos**. Límite: **12–15 turnos** (según plantilla).
- Pantalla: **mapa ilustrado con fichas** (fondo dibujado por plantilla, puntos como iconos,
  grupos como fichas con el rostro del oficial y su número de soldados).

### Turnos y movimiento
- **Turnos alternos**: mueve tu bando entero, luego el enemigo (y los aliados de IA).
- Cada grupo se mueve **1 punto por turno**.
- **Niebla de guerra**: ves los puntos vecinos a los tuyos. La amplían: puntos de vigilancia
  (torre, colina, campamento), la Estrategia del comandante o tener estratega, operaciones
  previas (espiar/explorar) y habilidades en batalla.

### Grupos
- Cada bando tiene **3–5 grupos**. Cada grupo: **oficial al mando + hasta 2 acompañantes** con
  nombre (máx. 3) + **escolta genérica** (1 genérico por cada **10 soldados**), con un máximo de
  **5 combatientes en pantalla** por bando.
- Soldados por grupo según el rango del oficial: **soldado 20, caballero 35,
  comandante/estratega 50, general/rey 70**.
- **Tipo de tropa** según la familia de arma que mejor domina el oficial (infantería, arqueros,
  caballería, piqueros), con ventaja de tipo (piqueros > caballería > arqueros > infantería…).
- Quién mueve: soldado/caballero/inafiliado solo su grupo; comandante/gobernante todos (o IA).
- Ficha del grupo: rostro, soldados, vida y moral, tipo de tropa; al tocarla, ficha completa
  (oficiales, escolta, estados, lo que se sabe).

### Combates
- Al entrar en un punto con enemigos (o cruzarse) → **combate RPG** (la pantalla actual de Royal
  Pain, con sus 4 vistas, efectos y caída). Si coinciden varios grupos → **combate conjunto**
  (los que no caben en pantalla quedan de reserva).
- **Jugables** si interviene tu grupo, un personaje con relación especial contigo o un oficial
  asignado por ti o por el comandante; **los demás se resuelven solos** (auto_fight).
- Los soldados dan algo de fuerza (bonos de tropa) y aparecen como escolta genérica.
- **Vida y PT se conservan** entre combates de la misma batalla; al pasar el turno se
  regeneran según el punto: **campamento 25 %, aldea 15 %, resto 5 %**.
- Grupo que **pierde** un combate: pierde soldados y **retrocede** al punto propio más cercano;
  si se queda sin soldados o cae su oficial, **sale de la batalla**.
- **Eventos en combate/batalla**: reto a duelo (1 contra 1, mueve sobre todo la moral),
  deserción/traición, refuerzo inesperado, cambio de clima.

### Bonos de los puntos (moderados)
| Punto | Efecto |
|---|---|
| Colina | +15 % daño a quien combate allí; vigilancia |
| Bosque | +15 % esquiva |
| Torre | +1 de visión y +10 % defensa |
| Fortificado (obra) | +25 % defensa al defensor |
| Puente / desfiladero | Paso obligado; el atacante −10 % |
| Campamento | Refuerzos y curación 25 % |
| Aldea | Curación 15 % (comida) |

### Moral del bando (0–100)
- Empieza en **70–90** según la fama del comandante.
- Ganar/perder un combate **±8**; tomar/perder un punto **±5**; cae un oficial **−12**; cae el
  comandante **−30**; duelos y eventos la mueven.
- **Moral 0 → huida general**: el bando pierde y sufre bajas extra al huir.

### Refuerzos, aliados y retirada
- **Refuerzos** desde los campamentos controlados cada X turnos (si quedan oficiales y soldados
  de reserva). Tomar campamentos enemigos corta sus refuerzos.
- **Aliados**: si el territorio limita con un reino aliado, puede mandar 1–2 grupos (verdes)
  que mueve su IA.
- **Retirada**: un grupo (o el bando) puede retirarse para evitar más pérdidas, **solo si tiene
  un punto propio adyacente** al que huir; rodeado, ya no puede.

### Victoria / derrota en batalla
- Tomar el **campamento enemigo** (o el castillo en un asedio), o derrotar a su **comandante**.
- Si se agotan los turnos, **gana el defensor**.

### IA en batalla
- Según la **personalidad** de cada oficial: agresivo (caza grupos), defensivo (guarda puntos),
  oportunista (toma puntos vacíos). El comandante coordina.

### Habilidades de mando (adaptadas)
- Cada jefe tiene **1 orden por batalla** (por personalidad o habilidad) que afecta al mapa:
  curar grupos, mover dos puntos, revelar niebla, reforzar un punto… (no la moral).

### Batallas navales
- Mismo sistema: cada punto es un **barco o zona de agua**; el abordaje es un combate RPG en
  cubierta (fondo naval). Barco único genérico; el **viento** da +1/−1 de movimiento por turno.
- Los territorios costeros tienen barcos **automáticamente**.

### Muerte al caer
- Oficial: **15 %**, **35 %** si su bando pierde (si no, herido 1–3 meses o capturado).
- Tu personaje: **3 %**, **8 %** si tu bando pierde. Morir = **fin de la partida**.

---

## 3. Mapa estratégico (conquista)

- El mapa de **Royal Pain** (Map.png, 12 castillos) + **~20 territorios intermedios**
  (1–2 por ruta según distancia; 3–4 en fronteras clave), de tipo según el bioma: bosque,
  llanura, pueblo, mar (costa).
- Los intermedios son **paso obligado** (hay que controlarlos para atacar el castillo), dan
  **recursos**, se disputan con **batallas propias** y son **fortificables**.
- Se dibujan **sobre el mapa actual** como marcadores pequeños unidos por rutas.
- Recursos: **oro, comida y soldados**. Cada territorio aporta soldados según su población; la
  orden «reclutar» suma más; cada soldado consume comida (sin comida, desertan).
- **Una invasión por reino y mes**. Un territorio recién conquistado queda **protegido 1 mes**.
- Si hay varias batallas el mismo mes, **solo juegas aquella a la que te asignan** (o la que
  elijas según tu rango); las demás se resuelven solas.
- **Estaciones** (invierno: menos comida y movimientos penalizados) y **clima en batalla**.
- Poder inicial de cada reino **aleatorio** en cada partida (entre **1 y 10 oficiales**).

### Construcciones (1 orden + oro, 1–3 meses; 3–4 huecos por territorio)
| Tipo | Obras (coste orientativo) |
|---|---|
| Defensa | Empalizada 100/1 mes, torre 150/1, muralla 400/3 |
| Economía | Granja 200/2, mercado 200/2, mina 200/2 |
| Militar | Cuartel 250/2 (más soldados), establo (caballería), astillero |
| Oficiales | Forja 300/2 (mejor equipo), biblioteca 300/2 (técnicas), taberna 300/2 (oficiales libres) |

---

## 4. El mes: órdenes, consejo e IA

- **1 orden por mes**, ampliable según estadísticas, nivel y tierras conquistadas.
- Si no gobiernas: **consejo mensual** (sala con retratos): los oficiales proponen planes y tú
  el tuyo; el señor elige según rango, afinidad, fama y aciertos previos. Tu orden propia va
  aparte.
- La **IA de cada reino** actúa según la **personalidad de su gobernante** (ambicioso ataca,
  prudente fortifica, leal respeta alianzas); la dificultad ajusta su eficacia.

### Catálogo de órdenes
| Grupo | Órdenes |
|---|---|
| Interior | Cultivar, comerciar, reclutar, entrenar tropas, fortificar, construir |
| Personal | Buscar oficiales, visitar/regalar, nombrar cargos, prisioneros |
| Diplomacia y operaciones | Alianza/tregua, exigir tributo/vasallaje, espiar/sabotear, sobornar oficiales |
| Estratega / comandante | Planificar operaciones, entrenar al ejército, elegir oficiales, proponer invasión |
| Soldado / caballero | Entrenar, socializar, patrullar/misiones, pedir un ascenso |
| Inafiliado | Viajar, mercenario en batallas, ofrecerse a un reino, reunir seguidores |

### Diplomacia
- **Alianzas y treguas con plazo** (6, 12 o 24 meses), **renovables** pagando o con buena
  relación. Romperlas antes cuesta **fama y confianza**; la IA las rompe si le conviene.
- Durante la alianza: no hay ataques y el aliado puede mandar grupos a tus batallas.

---

## 5. Roles, cargos y progresión

- **Eliges el rol al crear el personaje**; cada uno empieza en una posición acorde.

| Cargo / rol | Qué es |
|---|---|
| Inafiliado | Sin señor (al empezar o exiliado). Se mueve entre reinos y lucha en batallas del territorio como parte de un pelotón, no como comandante |
| Soldado | Como el inafiliado pero con sueldo, sin moverse, y con batallas obligatorias |
| Caballero | Manda su grupo y un pequeño séquito |
| Estratega / Consejero | Operaciones, visión y propuestas en el consejo |
| Comandante / General | Dirige los ejércitos, elige oficiales e invasiones |
| Almirante | Manda en las batallas navales |
| Regente | Designado por el gobernador para administrar un territorio; puede rebelarse |
| Gobernador | El rey: manda en todo el reino |

- **Méritos** (escala media): ganar combate +10, tomar punto +5, vencer a un oficial +15, al
  comandante +40, ganar batalla +20. Ascensos a **100 / 250 / 500**.
- Progresión de oficiales: **experiencia de combate** (niveles y árboles), **méritos**,
  **entrenamiento**. El **rango** limita el tamaño de la tropa y da acceso a cargos.
- Cambiar de situación: **ascenso por méritos**, **desertar** (quedas inafiliado), **ser
  exiliado/despedido**, **rebelarte siendo regente**, **ofertas de otros reinos** (según fama).
- **Sueldo mensual por rango**; si el reino no puede pagar, baja la lealtad.

---

## 6. Oficiales y relaciones

- **Reclutamiento**: capturados en batalla, oficiales libres (taberna, «buscar oficiales»),
  desertores (afinidad, mal trato, soborno).
- **Lealtad** depende de: trato y cargos, personalidad, paga.
- **Alineación** según la personalidad: bondadoso (Honorable, Generoso, Leal, Piadoso,
  Romántico), malvado (Cruel, Ambicioso, Cobarde), neutral (el resto).
- **El honor desaparece**; queda la **fama**, que influye en: que un reino te reclute, ascensos,
  ofertas de otros reinos, eventos de duelo, algo de moral inicial, atención de otros oficiales
  y propuestas de matrimonio de alianza.
- **Relaciones especiales**:
  - **Hermandad de armas**: ataque conjunto en el mismo combate; nunca se traicionan.
  - **Romance y matrimonio**: el cónyuge puede protegerte de un golpe y da moral; su muerte
    pesa mucho. **Matrimonios de alianza**: sellan o alargan alianzas, te los pueden proponer,
    el cónyuge se une a tu bando y da derecho de herencia (línea de sucesión).
  - **Rivalidad**: te reta a duelo en eventos, compite por ascensos, méritos extra si le superas.
  - **Afinidad general**: con afinidad alta, cualquier oficial lucha algo mejor a tu lado.
- **Prisioneros**: reclutar, liberar, rescate o ejecutar. **Ejecutar** baja la fama, pone a sus
  allegados (hermanos de armas, cónyuge…) en **odio total (afinidad −100)** y hace que tus
  oficiales bondadosos pierdan lealtad o afinidad.

---

## 7. Lo que se conserva de Royal Pain

- **Combate RPG** completo (4 vistas, efectos, caída, ficha al tocar, papeles).
- **Árboles y técnicas** (vías, técnicas de arma, Tomo del olvido).
- **Equipo y tienda** (armas, armaduras, accesorios, consumibles).
- **Eventos con personalidad** (de oficiales, del territorio, del mundo, en batalla).
- Mapa de castillos, culturas, retratos, música, sonidos (estilo grabado/original), fondos,
  iconos, transiciones, opciones, guardado.
- **Se quitan**: tablero de casillas, honor, vida de personaje (jornal, cortejo genérico,
  misiones sueltas, expediciones), duelos y torneos fuera de batalla.

---

## 8. Opciones, guardado y ayuda

- Al empezar: **dificultad**, **reino inicial**, **velocidad de combate**, **batallas
  automáticas**.
- Guardado **libre en el mapa estratégico + automático cada mes**; no se guarda en batalla.
- Ayuda: **tutorial de batalla** y **glosario**.

---

## 9. Fondos a crear (para assets/backgrounds/<nombre>/)

**Imprescindibles (hito 1):** bosque, aldea, puente, campamento militar, muralla de asedio,
y un fondo de **mapa de batalla** (campo dibujado neutro donde se pintan los puntos).

**Siguientes:** montaña/paso rocoso, torre de vigía, patio de castillo en llamas, cubierta de
barco (naval), mar abierto (mapa naval), sala del consejo, sala del trono, calabozo, cuartel,
variantes de noche/atardecer, desierto con ruinas, pantano.

Formato: 16:9 (1920×1080), con el suelo en el tercio inferior para las figuras.

---

## 10. Plan de desarrollo

1. **Hito 1 — Batalla de puntos suelta** (ver abajo).
2. Hito 2 — Mapa estratégico: territorios (castillos + intermedios), recursos, invasión →
   batalla, conquista, captura, protección de 1 mes.
3. Hito 3 — Oficiales: reclutamiento, lealtad, sueldos, cargos, prisioneros.
4. Hito 4 — Diplomacia: alianzas/treguas con plazo, tributo, espionaje, soborno.
5. Hito 5 — Roles, consejo, méritos, ascensos, exilio, rebelión.
6. Hito 6 — Relaciones especiales, matrimonios de alianza, eventos.
7. Hito 7 — Batallas navales, construcciones, estaciones.
8. Hito 8 — Pulido: tutorial, glosario, dificultad, equilibrio, guardado.

### Hito 1 — batalla de puntos jugable
**Objetivo:** desde un menú de prueba, «Batalla rápida» con dos bandos generados (retratos
actuales), jugable de principio a fin.

1. **Crear el proyecto** `ages_of_warfare` a partir de Royal Pain, conservando:
   - Combate: `scenes/rpg_battle/rpg_battle.gd`, `scripts/resources/rpg_battle_manager.gd`,
     `fight_results.gd` (reducido a `apply_start_health`, `sync_health`, `finish_embedded`),
     `campal_encounters.gd` (solo `apply_troop_bonus`, `technique_allowed`, `is_generic`,
     `auto_fight`/`apply_hp` reescritos sobre datos simples).
   - Clases: Character (+ enums, equipment, skill, trait), RpgStats, SkillTreeCatalog,
     SkillEffects, ConsumableCatalog, EnemyCatalog, BattleEnums, CombatFx, StatIcons,
     SkillIcons, FaceIcon, LogView, OptionsPanel, BiomeBackgrounds, UniqueItems, XpRules,
     RoleProgression, CharacterLoader.
   - Autoloads: Settings, Sfx, Music, Ambience, SceneFade, IntelData y un **CombatSetup mínimo**.
   - Recursos: retratos, fondos, iconos, música, sonidos, fx.
   - Quitar las referencias de `rpg_battle.gd` a RelationsData, PartyData, GameManager y la
     oferta de reclutamiento (o sustituirlas por versiones mínimas).
2. **Datos de la batalla**: `PointMap` (puntos, conexiones, tipo, dueño), `BattleGroup`
   (oficiales, escolta, soldados, tipo de tropa, vida/PT, punto), 2–3 **plantillas** iniciales
   (llanura, río con puente, asedio simple).
3. **Pantalla de puntos**: fondo, puntos e iconos, fichas de grupo, niebla, movimiento por
   turnos, captura, regeneración, moral, refuerzos, retirada, fin por turnos.
4. **Combates**: lanzar `rpg_battle` embebido con los grupos (escolta 1/10 soldados, máx. 5),
   aplicar resultado (bajas, retroceso, salida, muerte 15/35 %), y resolución automática para
   los no jugables.
5. **IA enemiga básica** por personalidad (agresivo / defensivo / oportunista).
6. **Victoria/derrota**: campamento, comandante, moral 0, límite de turnos.
7. **Pruebas automáticas**: batalla completa en automático; medir duración (turnos y combates
   jugados), tamaño de grupo y escolta, tasa de victoria; ajustar cifras.

### Verificación del hito 1
- Prueba headless que juega una batalla entera en automático sin errores y termina por alguna
  de las condiciones de victoria.
- Capturas de la pantalla de puntos y de un combate desde ella.
- Una partida manual: 5–10 minutos, 3–5 combates jugados.

---

## 11. Cifras iniciales (a ajustar en pruebas)

| Parámetro | Valor |
|---|---|
| Puntos por mapa | 6–9 |
| Turnos por batalla | 12–15 |
| Grupos por bando | 3–5 |
| Personajes con nombre por grupo | hasta 3 |
| Escolta | 1 genérico / 10 soldados; máx. 5 en pantalla |
| Soldados por rango | 20 / 35 / 50 / 70 |
| Regeneración por turno | campamento 25 %, aldea 15 %, resto 5 % |
| Moral | 100; inicio 70–90; combate ±8, punto ±5, oficial −12, comandante −30 |
| Muerte al caer | oficial 15 % (35 % si pierde); jugador 3 % (8 % si pierde) |
| Méritos para ascender | 100 / 250 / 500 |
| Territorios | 12 castillos + ~20 intermedios |
| Oficiales iniciales por reino | 1–10 (aleatorio) |
| Alianzas | 6 / 12 / 24 meses, renovables |
