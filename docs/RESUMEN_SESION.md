# Royal Pain — resumen de la sesión (11–16 de noviembre de 2026)

Lo hecho desde que se retomó el proyecto en este equipo. Lo que viene después está en
`docs/PENDIENTE.md` (sección «Lo que viene») y el diseño del juego nuevo en
`docs/ages_of_warfare/DISENO.md`.

## Versiones subidas a git

### Hasta la 0.10.3 (commit `f54b79f`)
- **APK:** ventanas que se ajustan solas, retratos bien recortados, botón «atrás» de Android =
  Esc, «Volver» el primero en el combate.
- **Icono de la app:** el escudo de armas, sin fondo.
- **Batallas campales:** solo con ejércitos reales en marcha; el resultado cambia el mundo;
  enemigos más duros (`ENEMY_EDGE`, `ENEMY_GRIT`).
- **Combate:** cada acción se anuncia con flecha al objetivo y embestida; daño rebajado
  (`DMG_SCALE` 2.2); retirada en vez de rendición; bajas proporcionales al daño.
- **Duelos:** eliges a quién retar y te pueden rechazar.
- **Interfaz:** creación sin pergamino, árbol de habilidades como árbol, Grupo/Relaciones/Reinos
  con menos texto, iconos en todo el juego, accesos rápidos (castillo, batalla), panel de equipo.
- **Mundo:** expediciones por pasos con rescates, reclutar o encerrar enemigos, eventos coherentes
  con la personalidad, jornal que cuesta vida, fondos por bioma; fuera la caza furtiva, la tregua
  con rivales y los pretendientes rivales.
- **Habilidades:** una vía por árbol, Tomo del olvido, 14 habilidades y 42 técnicas de arma nuevas.

### Fase 2 de sprites (descartada)
Se probaron tres caminos (deformar los retratos, IA local con ComfyUI, vestir la base de
hiddenone). Ninguno convenció; se borró todo, ComfyUI incluido. Las hojas de sprites que llegaron
después (`assets/battle/sprite_sheets/`) son trabajo del usuario, con sus reglas en `docs/sprites/`.

### 0.10.4 – 0.10.14 (commit `beb40f1`)
- **Móvil:** pantalla completa siempre; desplazar la lista de técnicas y objetos.
- **Iconos** en el resultado de las batallas y en accesorios, monturas y consumibles.
- **Campal → asedio:** si el invasor gana la campal, «Continuar al asedio» en el mismo bando; la
  campaña completa se lleva 2 meses.
- **Tablero:** los pelotones se deslizan al moverse; el tablero se ajusta al espacio libre.
- **Chantaje:** solo con mala fama (honor ≤ 10) y sin repetirse con el mismo secreto.
- **Combate:** 4 vistas (Escenario, Clásica, Enfocada, Primera persona) y Opciones desde el
  combate; destellos de color en vez de bordes (blanco turno, rojo daño, verde cura, azul a
  favor, morado en contra); X al caer que se va a negro.

### 0.10.15 – 0.10.19 (commit `6c18f78`)
- **Combate:** icono de papel (comandante, oficial, soldado), rostros en la franja de aliados,
  ficha al tocar a un personaje, Opciones arriba a la derecha, caída visible al morir.
- **Campal:** iconos por tipo de tropa, oficiales al tocar un pelotón, órdenes de mando según el
  carácter (también de oficiales), crónica tras un botón.
- **Mapa:** ejércitos con icono de tropa y rostro del comandante; rostros de los personajes
  nombrados en noticias, sucesos y comentarios (`MentionedFaces`).
- **Recursos libres** (créditos en cada carpeta):
  - terreno del tablero — Kenney «RTS Pack: Medieval» (CC0), `assets/battle/terrain/`;
  - música — Kevin MacLeod (CC BY 4.0), `assets/music/mk_*.ogg`;
  - efectos — Kenney «RPG Audio», «Impact Sounds», «Interface Sounds» (CC0), `assets/sfx/*.ogg`;
  - ambientes — OpenGameArt (CC0), `assets/music/rec_amb_*.ogg`;
  - efectos de impacto — Kenney «Particle Pack» (CC0), `assets/fx/`.
- **Transición de telones** al entrar en combates y batallas.
- **Opción «Estilo de sonido»** (Grabado / Original): cambia música, efectos y ambiente al momento.

## En el equipo, sin subir todavía (0.10.20 – 0.10.21)
- Batallas y duelos aceptados que no se lanzaban (la ventana quedaba en modo «noticia»): arreglado.
- Llamadas a filas que cambian por el camino: la campal pasa a asedio (o al revés); si ya no hay
  batalla, se avisa con una noticia.
- Combate sin historial (la franja de comandos ocupa todo el ancho).
- Técnicas, objetos y cambios: la franja crece y la lista va en dos columnas.
- Campal: ventana «Habilidades de mando» con el rostro y cargo de cada jefe y sus órdenes.

## Actualización de recursos del usuario (commits `c0bae65` y `a64a33c`, 13 y 16/11)
- Reorganización de `assets/` (ver `assets/LEEME.md`): fondos de combate con estaciones
  (pradera, bosque, costa, desierto, aldea, muralla de asedio, torneo, patio de armas, barco),
  escenas de diálogo por lugar, fondos de interfaz, iconos de lugares y de nodos de mapa.
- Retratos nuevos y expresiones de cada personaje.
- Hojas de sprites animadas de 34 fotogramas (`assets/battle/sprite_sheets/`).
- Al bajarla se detectaron referencias rotas (pendiente de arreglar, ver `docs/PENDIENTE.md`).

## Juego nuevo: Ages of Warfare
Tras varias rondas de preguntas quedó el diseño completo de un juego de conquista al estilo
*Dynasty Warriors Empires*: batallas por puntos con combates RPG, mapa estratégico con
territorios intermedios, roles de soldado a rey, consejo, oficiales, relaciones y alianzas con
plazo. Ver `docs/ages_of_warfare/DISENO.md`. Todavía no tiene código.
