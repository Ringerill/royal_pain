# Royal Pain — rediseño completo (versión 2)

Cambio masivo de Royal Pain definido en noviembre de 2026, **basado en los assets nuevos**
(`assets/LEEME.md`): cuando un asset y una mecánica antigua chocan, manda el asset. Se trabaja
**sobre `main`**, solo PC hasta estabilizar, por fases; commit y push al cerrar cada fase; revisión
del usuario al terminar todo.

---

## 1. Mundo

### Mapas (dos niveles)
- **Mundo** (`assets/maps/world_map.png`): los 12 reinos. Viaje entre reinos vecinos por tierra
  (caminos, puentes) y a reinos lejanos o islas **por mar** desde un puerto (pasaje pagado; más
  adelante barco propio; riesgo de piratas = combate en `warship`).
- **Reino** (`assets/maps/kingdoms/01…12`): **8–12 lugares** por reino colocados sobre lo dibujado,
  unidos por caminos. Es la pantalla principal del juego.
- **Reinos**: los 12 mapas (Nieve, Verde del norte, Dorado, Púrpura, Azul, Desierto, Carmesí,
  Central, Turquesa, Naranja, Gris, Verde del sur). Cultura **al azar** y nombre generado en cada
  partida, como hasta ahora. Cada uno con su capital (castillo central del mapa).

### Lugares (nodos con función)
Iconos en `assets/icons/locations/` y `assets/icons/map_tiles/`.

| Lugar | Función |
|---|---|
| Ciudad / capital / castillo | Escena + edificios: taberna, tienda, herrería, iglesia, biblioteca, posada; en la capital trono, consejo, celda y mazmorra |
| Pueblo | Escena + edificios (menos), reclutar, casas |
| Puerto | Viaje por mar, piratas, comercio |
| Cueva, torre olvidada, campamento bandido | **Expediciones: mazmorras con nodos** (mapa propio dentro, jefe al final) |
| Campamento | Descanso (energía), tropas |
| Arena | Torneos periódicos y **boss rush** |
| Casa | Casa propia (dormir, guardar, vida en pareja) |
| Puente, camino, muralla de asedio, barco | Puntos de paso y escenarios |

### Tiempo
- **Sin turnos.** El reloj corre **solo al viajar** (~1 h de juego por segundo, velocidades
  ×1/×2/×4 y pausa). Parado en un lugar, el reloj no avanza.
- Al moverte de A a B la ficha recorre el camino; por el camino pueden saltar **peleas al azar y
  eventos según la zona**, o un **encuentro** si te cruzas con otro que va por el mismo camino.
- **Acciones que gastan tiempo:** entrenar, estudiar, batirse (y dormir/esperar). El resto no.
- **Meses de 30 días**, estaciones de 3 meses (verano, otoño, invierno: cambian fondos y reglas),
  **día y noche** (fondos nocturnos, eventos y lugares de noche). Lugares **destruidos** por
  saqueos o asedios hasta repararlos (fondos `_destroyed`).
- El botón «Avanzar turno» se sustituye por **esperar / dormir**.

### Energía (0–100)
- Viajar **2/h**, combatir **10**, entrenar/estudiar **20**.
- Dormir 8 h recupera 100 (posada, casa, castillo); descansar 4 h en campamento recupera 40.
- **Por debajo de 20**: estadísticas del grupo muy reducidas (estado *agotamiento*).
- **En 0**: te desmayas y reapareces en el edificio no hostil más cercano, **perdiendo dinero**.

### Mundo vivo
Se mueven por los caminos: **viajeros con nombre, ejércitos, bandidos y patrullas, caravanas y
barcos**. Al cruzarte con alguien: **hablar/comerciar, desafiar/atacar, evitar/huir, viajar juntos**.
Solo se puede interactuar con personajes **con los que te cruzas o que están en tu mismo lugar**
(la pantalla de Relaciones es de consulta).

### Política
IA de reinos viva: guerras, **alianzas y treguas con plazo** (renovables), tratados, ejércitos que
marchan por los mapas. Comercio **simple** (precios casi fijos).

---

## 2. Personaje

### Creación
- Personaje **con hoja de sprites** (solo esos son jugables o luchan).
- **Reino de origen** (donde empiezas; da una pasiva de origen).
- **Arma inicial**: solo la más básica de cada tipo.
- **Personalidad**, **vía** y reparto de **atributos**.

### Estadísticas
**Ataque, Defensa, Agilidad, Estrategia, Carisma, Liderazgo** (las de los accesorios) + **Vida,
PT, Energía**. Sin honor: solo **fama (−100 a 100)**, que suben/bajan combates y batallas,
encargos y metas, actos, torneos y duelos.

### Rango (estatus)
**Inafiliado → trabajador → soldado → caballero → noble → rey**, por hitos:
trabajador = pedir empleo; soldado = alistarse; caballero y noble = nombrado por el rey;
inafiliado = renunciar a todo. Los enemigos genéricos encajan: bandidos = inafiliados (stats
variables por tipo), soldados mid/heavy = soldados, soldier leader = caballeros.
Mercenario, comerciante, cultista y forajido son **roles de PNJ**, no del jugador.

### Personalidades (9)
Solo influyen en **su árbol de técnicas, diálogos, afinidades y algo de estadísticas**.

| Personalidad | Atq | Def | Agi | Est | Car | Lid | Congenia | Choca |
|---|---|---|---|---|---|---|---|---|
| Valiente | +2 | +1 | | −2 | | +1 | Alegre +30 %, Irascible +15 % | Reservado −20 %, Frío −10 % |
| Pragmático | | +1 | | +3 | −2 | −1 | Frío +25 %, Reservado +15 % | Ingenuo −30 %, Egocéntrico −15 % |
| Frío | +1 | +2 | | +1 | −3 | | Pragmático +25 %, Reservado +20 % | Alegre −25 %, Gentil −15 % |
| Gentil | −2 | +1 | | | +3 | | Ingenuo +35 %, Alegre +20 % | Frío −15 %, Egocéntrico −25 % |
| Egocéntrico | +2 | −2 | | | +1 | +1 | Irascible +10 % | Gentil −25 %, Pragmático −15 %, Egocéntrico −20 % |
| Reservado | | | +3 | +1 | −2 | −1 | Frío +20 %, Pragmático +15 % | Alegre −30 %, Valiente −20 % |
| Ingenuo | | −1 | +2 | −2 | +2 | | Gentil +35 %, Alegre +25 % | Pragmático −30 %, Frío −20 % |
| Alegre | | −1 | +1 | | +1 | +1 | Valiente +30 %, Ingenuo +25 %, Gentil +20 % | Reservado −30 %, Frío −25 % |
| Irascible | +3 | −2 | +1 | −1 | | | Valiente +15 %, Egocéntrico +10 % | Gentil −20 %, Reservado −15 %, Irascible −25 % |

**Árboles de personalidad** (3 escalones + definitiva):
- Valiente: Provocar, Carga, Último aliento · *Estandarte*.
- Pragmático: Golpe medido, Aprovechar, Reciclar · *Plan B*.
- Frío: Calcular, Desarmar, Paralizar · *Sin piedad*.
- Gentil: Cubrir, Alivio, Ánimo · *Juramento*.
- Egocéntrico: Lucirse, Robar el golpe, Presumir · *Protagonista*.
- Reservado: Guardia, Observar, Golpe en las sombras · *Momento justo*.
- Ingenuo: Golpe de suerte, Torpeza afortunada, Confianza · *Milagro*.
- Alegre: Canción de marcha, Broma, Inspirar · *Fiesta*.
- Irascible: Rabia, Golpe salvaje, Rugido · *Berserker*.

### Vías (motivación)
Se elige al crear y **cambia por tus actos** (con aviso): saquear/asesinar/extorsionar → villano;
gobernando, matar a la corte o arruinar el reino → tirano; perdonar y liberar → benevolente; cazar
buscados → justiciero; invasiones seguidas → conquistador; ascender y enriquecerse → ambicioso;
fama entre −20 y 20 → reservado; activo con ganancias bajas → humilde.

Las **8 mecánicas son acciones disponibles para todos**; su vía las potencia (más éxito, menos
coste, más recompensa) y usarlas empuja hacia esa vía. Completar la meta da la **pantalla de
victoria** (se puede seguir jugando).

| Vía | Mecánica | Meta | Ventaja | Desventaja |
|---|---|---|---|---|
| Tirano | **Purga** (duelo a muerte o ejecución de corte y compañeros) y **Terror** (más obediencia, conjuras) | Ser el único con cargo de realeza en su reino | +50 % impuestos y botín | Fama ×0,5 al ganar y ×2 al perder; recluta −50 %; compañeros con afinidad < 30 pueden traicionar en batalla; la corte es competente y tiene ejércitos |
| Conquistador | **Ultimátum** (rendición sin batalla si su fuerza es muy superior; si no, el asedio empieza con moral enemiga baja) | Controlar las capitales de 6 reinos | Sin espera entre invasiones; recluta +30 %; +15 % daño atacando asedios | Blanco preferido de los vecinos; alianzas a la mitad |
| Humilde | **Hospitalidad y faenas** (dormir gratis en pueblos; faenas que dan voluntarios y afinidad; los pueblos le esconden) | Vencer 5 jefes y completar 30 encargos sin cargo noble | Mercenarios, posada y tienda −30 %; −25 % energía al viajar | Sin tierras ni cargos nobles; sueldo −30 % |
| Benevolente | **Clemencia** (perdonar al enemigo a poca vida: se une, informa o vuelve como aliado) y **liberar** prisioneros y lugares | Derrotar 15 grupos hostiles que atacan lugares o caravanas | Curas +25 %; +50 % de reclutas tras ganar | Ejecutar o saquear le hace perder la vía; botín −30 % |
| Reservado | **Sigilo** (viajar sin encuentros ni ser visto; espiar lugares y ejércitos; grupos invisibles en batalla hasta atacar) | Alcanzar caballero con fama entre −20 y 20 | +1 nodo de visión; +20 % daño el primer turno | Fama −30 %; afinidad de charlas y regalos a la mitad |
| Ambicioso | **Colección** (registro de armas; +1 a un atributo por tipo completo) y **favores** (comprar afinidad, audiencias, ascensos, monturas) | Fortuna (p. ej. 20.000 de oro entre dinero y propiedades) y colección completa | Asciende con −30 % de méritos; +20 % experiencia | Un rival nuevo por ascenso; propuesta fallida = −afinidad con su señor |
| Justiciero | **Cazarrecompensas** (tablón de buscados en la taberna; rastrear objetivos en el mapa) | Derrotar 10 líderes/jefes bandidos, piratas o personajes tirano/villano | +20 % daño contra líderes y jefes; +50 % de recompensas | Encargos turbios le hacen perder la vía; +50 % emboscadas |
| Villano | **Saqueo** (lugares y caravanas quedan destruidos), **asesinato** (emboscada a muerte en un camino) y **extorsión** (oro mensual de pueblos) | Saquear 10 lugares o caravanas y asesinar 3 personajes benevolentes o justicieros | Botín ×2; bandidos y piratas no le atacan y se le unen; enemigo −10 de moral | Patrullas le persiguen; con fama negativa, ciudades sin tiendas ni posadas |

### Metas de victoria (mundo abierto)
Rey o unificador, leyenda (fama), fortuna, y la meta de la vía.
**Morir termina la partida** (sin dinastía ni herencia).

---

## 3. Combate (sprites)

- **Sprites animados** (`assets/battle/sprite_sheets/`, 34 fotogramas: reposo, ataque, distancia,
  golpe, defensa, cansancio, derrota, cabalgar, ataque/distancia montada, caída, dash) en **vista
  lateral JRPG**: enemigos a la izquierda y tu grupo a la derecha, filas escalonadas.
- Retratos y **expresiones** (10 por personaje, según el tono de la frase) en fichas, menús y
  diálogos. Las **4 vistas antiguas** (Escenario, Clásica, Enfocada, Primera persona) se conservan
  como opción histórica.
- Pantalla: escena del lugar (según bioma, estación y noche), barras de vida sobre los sprites,
  abajo línea de turnos, menú y ficha compacta de quien actúa.
- **Hasta 8 por bando**, mezcla libre de personajes y soldados. Fuera de ejércitos: **tú + 3**.
  Los **soldados genéricos los mueve la IA** con órdenes tuyas.
- **Soldados en combate**: 1 en pantalla por cada **10 soldados** del grupo (máx. 4); con 40 o
  más, cada soldado extra sube sus estadísticas; por debajo de 40 hay menos en pantalla.
- **Clase = el arma que llevas.** Ciclo de 5 (cada una gana a las dos siguientes):
  **Espada → Lanza → Arco → Mandoble → Maza → Espada**. Tipos de daño: espada Tajo, mandoble Tajo
  pesado, lanza Estocada, maza Contundente, arco Proyectil. **Solo el arma** define fortalezas y
  debilidades.
- **Escudo** en la mano libre (con espada, lanza o maza): probabilidad de bloqueo y defensa.
- **Armadura** (cuero, malla, placas; 5 niveles): solo estadísticas.
- **Montura equipable** (4 caballos, solo estética): +daño y +velocidad. El caballo **absorbe un %
  de cada golpe**; al llegar a 0, desmontas (derribado: pierdes 1 turno) y queda fuera.
  **Difíciles de conseguir**: muy caras o regaladas por la nobleza.
- **Estados**: veneno (daño fijo 3 turnos), parálisis (50 % de perder el turno, 3 turnos), miedo
  (menos acierto y sin técnicas), agotamiento (ligado a la energía, o por técnicas como una
  zancada; baja estadísticas), derribado (solo al caer del caballo; pierde 1 turno).
- **Arrojadizas** (bomba, cuchillos, envenenado, kunai, shuriken): objetos de un uso.
- **Cultistas** (solo PNJ): sanadores y venenos de una orden pública; gastan PT para usar objetos
  sin consumirlos. No hay magos.
- **Enemigos**: temáticos por lugar y bioma (caminos: bandidos y patrullas; puertos y mar: piratas;
  campamento bandido: bandidos y jefe; cuevas: asesinos y forajidos; torre: cultistas; callejón de
  noche: asesinos; guerra: soldados). Rangos raso, líder (más fuerte, técnica propia) y jefe (2
  acciones por ronda). **Dificultad por zona y tiempo de partida**: se estima cuántos niveles sube
  el jugador por periodo y los enemigos acompañan esa curva.
- Los oficios (herrero, tendero, mendigo, campesino…) son también **PNJ de los lugares** y algunos
  **reclutables**.

---

## 4. Equipo y árboles

- **Armas** (`assets/weapons/`, 6 tipos × 10): las **7 primeras** son una progresión (cada una mejor
  que la anterior); las **3 últimas**, definitivas con enfoque **ataque, agilidad o defensa**.
- **Armaduras** (`assets/armors/`): cuero, malla y placas en 5 niveles.
- **Accesorios** (`assets/accesories/`): **2 huecos**; 6 atributos × 5 niveles + 15 únicos (sustituyen
  a las piezas únicas actuales).
- **Objetos** (`assets/items/`): curación, PT y resurrección (3 niveles), bomba, cuchillos, kunai,
  shuriken, antídoto y remedios de parálisis, miedo y agotamiento.
- **Árboles**: uno **por arma** y uno **por personalidad**. Las **pasivas** las dan el tipo de
  combatiente, el equipo, el origen y la vía.
- Valores numéricos: se proponen en la fase 4 y se ajustan con pruebas.

---

## 5. Lugares, encargos y vida

- **Ciudad/pueblo**: escena del lugar con **botones con icono** de sus edificios. **Interiores** en
  modo **novela visual**: fondo del interior, PNJ en grande con su expresión, diálogo y opciones.
  - Taberna y callejón: rumores, reclutar, apuestas, encargos (tablón), turbios de noche.
  - Tienda y herrería: comprar y vender; el herrero vende y mejora armas y armaduras.
  - Iglesia: curar, bodas, donar. Biblioteca: estudiar técnicas (gasta tiempo).
  - Trono, consejo, celda y mazmorra: audiencias, consejo, prisioneros, cautiverio.
- **Casa propia** y **posada** (dormir). **Pareja**: citas, boda (escena de boda), varios cónyuges
  según rango; **sin hijos**.
- **Encargos del tablón**: escoltar/entregar, cazar/despejar, rescatar/buscar y turbios; **plazo en
  días**; fallar o abandonar cuesta fama y afinidad.
- **Expediciones**: mazmorras con nodos en cuevas, torre olvidada y campamentos bandidos; jefe y
  botín; se renuevan con el tiempo.
- **Arena**: torneos periódicos y boss rush.
- **Caravanas y barcos**: escoltar o asaltar.
- **Prisioneros**: reclutar, rescate, liberar, ejecutar, esclavizar.
- **Relaciones especiales**: amistad y hermandad, romance y matrimonio, rivalidad y enemistad.
  Hermandad: bonos de estadísticas, te recomienda a nobles, se ofrece a tu grupo, a veces te
  defiende sola. Rivales: te buscan, traicionan más si comparten ejército, bonos contra ti.
- **Gobierno de un lugar** (noble o rey): impuestos, guarnición, reparar y mejorar, nombrar
  encargados.

---

## 6. Ejércitos y batallas de nodos

- **Soldados que puedes llevar**: según rango (inafiliado 0–5, trabajador 5, soldado 10, caballero
  30, noble 100, rey 300) +5 % por punto de Liderazgo.
- **Pago**: nobles y reyes pagan a sus soldados; los demás no pagan: su comandante se los asigna
  según su fama.
- **Grupos**: tú + 3 personajes (prioridad a tu grupo propio); asignados solos si eres soldado o
  menos, los administras desde caballero.
- Los **ejércitos se mueven por los caminos** como el jugador, a gran escala.
- **Batalla de nodos sobre el propio mapa del reino** (zoom a la zona), **en tiempo real con
  pausa**: órdenes **ir a / mantener, perseguir / interceptar, retirarse / reagrupar**. Choque en un
  camino: **combate en el sitio** (con sprites); quien está en un **nodo propio tiene bonificación**.
  Estrategia por posición (dejar avanzar, perseguir, cortar el paso).
- **Victoria**: conquistar puntos clave, aniquilación, retirada enemiga o aguantar hasta el final.

---

## 7. Pantallas

- **Mapa de reino** a pantalla completa con HUD: hora, día y estación; energía, oro y fama;
  rostros del grupo y soldados; velocidad del tiempo. Accesos fijos: **grupo e inventario,
  relaciones, diario** (encargos, metas, crónica) y **mundo**.
- **Fondos de interfaz** (`assets/ui/backgrounds/`): menú, creación, opciones (armería), consejo,
  game over (estandarte y cementerio), victoria.
- **Guardado** libre estando en un lugar y automático al dormir.

---

## 8. Se descarta

Dinastía (herencia e hijos), honor, tablero de casillas, complots y ambiciones, edictos y obras
actuales, misiones actuales, turnos mensuales con acciones, los estados antiguos (salvo derribado)
y la orden cultista como opción del jugador.

---

## 9. Fases (sobre `main`, commit y push al cerrar cada una)

1. **Datos**: 12 reinos de los mapas y sus 8–12 lugares; nuevas estadísticas; rangos, vías y
   personalidades.
2. **Mapa y tiempo**: mundo y reino, viajes con reloj, día/noche, estaciones, energía y desmayo,
   HUD, guardado.
3. **Combate con sprites**: vista lateral, hasta 8 por bando, animaciones, ciclo de 5, estados,
   montura; vistas antiguas como opción.
4. **Equipo y árboles**: armas, armaduras, accesorios, objetos, árboles por arma y personalidad,
   creación de personaje.
5. **Lugares e interiores**: ciudades, novela visual con expresiones, tienda, herrería, taberna,
   iglesia, biblioteca, posada, casa, encargos.
6. **Mundo vivo**: viajeros, bandidos, patrullas, caravanas; encuentros; expediciones con nodos;
   arena.
7. **Relaciones y vías**: interacción por cercanía, afinidades, hermandad, rivalidad, romance,
   mecánicas y metas de las vías, prisioneros.
8. **Reinos y ejércitos**: IA con alianzas con plazo, ejércitos que marchan, batallas de nodos,
   ascensos por hitos, gobierno, mar y piratas.
9. **Limpieza y pulido**: quitar lo descartado, valores y equilibrio, tutorial y glosario.

Revisión del usuario **al terminar todo**.
