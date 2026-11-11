extends RefCounted
# Catálogo de sucesos sociales (ver SocialEvents): lazos según la intimidad, rivalidades, señores y facción.
# Uso: const SocialEventCatalog = preload("res://scripts/resources/social_event_catalog.gd")
#
# Mismo formato que EventCatalog (id, title, text, options) más:
#   min_tier  — nivel de intimidad mínimo (0 Desconocido … 4 Íntimo; ver DialogueCatalog.intimacy_tier)
#   kinds     — clases de lazo a las que sirve ([] = cualquiera): spouse, lover, friend, courtier, serf, prisoner, retinue
#   stages    — etapas de rivalidad en las que puede ocurrir (Relationship.RivalryStage)
#   deed      — hazaña del jugador a la que reacciona un señor: victoria, deshonra, boda ("" = ninguna)
#   bias      — {Personality: peso} del protagonista (los no listados pesan poco: SocialEvents.UNLISTED_WEIGHT)
#   avoid     — personalidades a las que nunca les pasa; only — solo a estas
# Marcadores: {name} protagonista, {player}, {lord}, {comrade}, {third}, {castle}; {a:m|f} concuerda con el
# jugador y {s:m|f} con el protagonista. "social" en una opción: efectos que no caben en EventCatalog
# (group: intimidad con toda la facción, adjust: {marcador: n}, schedule_duel, third_grudge) — los aplica SocialEvents.

const P := Character.Personality
const ST := Relationship.RivalryStage

# --- 1) Lazos personales, de menos a más intimidad ---
const BOND := [
	{"id": "soc_pide_ayuda", "title": "Una mano tendida", "min_tier": 1, "kinds": [], "avoid": [P.PIADOSO, P.HONORABLE, P.PRUDENTE], "bias": {P.COBARDE: 1.5, P.ROMANTICO: 1.2},
		"text": "{name} llega con la mirada baja: unas deudas de juego le quitan el sueño. No pide mucho, solo que alguien {s:le|la} saque del apuro antes de que sus acreedores pierdan la paciencia.",
		"options": [
			{"label": "Prestarle 30", "requires": {"gold": 30}, "effects": {"gold": -30, "affection": 10, "honor": 2}, "result": "{name} jura que no lo olvidará."},
			{"label": "Negarte", "effects": {"affection": -5}, "result": "{name} se marcha sin decir palabra."},
		]},
	{"id": "soc_rina", "title": "Palabras gruesas", "min_tier": 1, "kinds": [], "avoid": [P.COBARDE, P.PIADOSO], "bias": {P.ARROGANTE: 2.0, P.CRUEL: 1.5, P.PRUDENTE: 0.5},
		"text": "Una discusión por una minucia se enciende delante de los criados. {name} alza la voz y te reprocha tu orgullo. El salón entero espera tu respuesta.",
		"options": [
			{"label": "Disculparte", "effects": {"affection": 5, "honor": -1}, "result": "La tormenta pasa. {name} acepta tu mano."},
			{"label": "Sostenerle la mirada", "chance": 0.5, "chance_stat": "charisma",
				"success": {"effects": {"affection": 3, "honor": 2}, "result": "{name} acaba riéndose: tenías razón."},
				"failure": {"effects": {"affection": -10}, "result": "La herida tardará en cerrarse."}},
		]},
	{"id": "soc_favor_cortesano", "title": "Una recomendación", "min_tier": 1, "kinds": ["courtier", "friend"], "bias": {P.AMBICIOSO: 2.0},
		"text": "{name} aspira a un cargo en la corte y te pide que hables en su favor. Si sale bien, te deberá el puesto; si sale mal, tu palabra valdrá un poco menos.",
		"options": [
			{"label": "Avalarle", "chance": 0.6, "chance_stat": "charisma",
				"success": {"effects": {"affection": 10, "fame": 2}, "result": "{name} obtiene el cargo y lo pregona con tu nombre."},
				"failure": {"effects": {"affection": 4, "honor": -2}, "result": "Rechazan la petición. {name} agradece el intento."}},
			{"label": "No meterte", "effects": {"affection": -3}, "result": "{name} buscará otro valedor."},
		]},
	{"id": "soc_siervo_tierra", "title": "Un pedazo de tierra", "min_tier": 1, "kinds": ["serf"], "bias": {},
		"text": "{name}, que te sirve sin paga ni libertad, te pide un rincón de huerta para cultivar lo suyo. Promete que nunca descuidará su trabajo.",
		"options": [
			{"label": "Concedérselo", "effects": {"castle_food": -10, "affection": 10, "honor": 2}, "result": "{name} besa la tierra que le das."},
			{"label": "Denegarlo", "effects": {"affection": -6}, "result": "{name} vuelve al trabajo, más callad{s:o|a} que nunca."},
		]},
	{"id": "soc_preso_habla", "title": "Lo que sabe un preso", "min_tier": 1, "kinds": ["prisoner"], "bias": {P.ASTUTO: 1.5},
		"text": "Entre los barrotes, {name} te ofrece lo que sabe de los caminos y las guardias de su antiguo señor. A cambio solo pide mejor pan y una manta.",
		"options": [
			{"label": "Aceptar el trato", "effects": {"gold": -5, "affection": 6, "xp": 15}, "result": "Lo que cuenta {name} vale cada migaja."},
			{"label": "No negociar", "effects": {"affection": -4}, "result": "{name} se encoge en su rincón."},
		]},
	{"id": "soc_regalo", "title": "Un regalo sin motivo", "min_tier": 2, "kinds": [], "avoid": [P.CRUEL], "bias": {P.GENEROSO: 2.5, P.ROMANTICO: 1.5, P.CRUEL: 0.4},
		"text": "{name} te sorprende con un presente envuelto en paño fino. «No es nada», dice, aunque se nota que lo ha elegido con cuidado.",
		"options": [
			{"label": "Aceptarlo", "effects": {"item": 1, "affection": 3}, "result": "Un regalo digno y un lazo más fuerte."},
			{"label": "Devolver el gesto", "requires": {"gold": 20}, "effects": {"gold": -20, "affection": 8, "honor": 1}, "result": "{name} sonríe: no esperaba nada a cambio."},
		]},
	{"id": "soc_celebracion", "title": "Día de fiesta", "min_tier": 2, "kinds": [], "bias": {P.GENEROSO: 1.5, P.PIADOSO: 1.3},
		"text": "Es el día del santo de {name}, y la gente de la casa espera ver qué haces. Una fiesta cuesta dinero; un olvido cuesta más.",
		"options": [
			{"label": "Dar un banquete", "requires": {"gold": 25}, "effects": {"gold": -25, "affection": 8, "fame": 2}, "result": "Se canta hasta el alba en honor de {name}."},
			{"label": "Un brindis sencillo", "effects": {"affection": 3}, "result": "Basta con el gesto."},
		]},
	{"id": "soc_confidencia", "title": "Una confidencia", "min_tier": 3, "kinds": [], "bias": {P.LEAL: 1.5, P.ASTUTO: 1.2},
		"text": "A solas, {name} te cuenta un secreto que podría arruinar a una familia de la corte. Te lo dice porque confía en ti más que en nadie.",
		"options": [
			{"label": "Guardarlo", "effects": {"affection": 8, "honor": 2}, "result": "El secreto queda entre los dos. {name} no lo olvidará."},
			{"label": "Venderlo", "effects": {"gold": 50, "affection": -15, "honor": -4}, "result": "El oro tintinea; {name} sabrá de dónde salió."},
		]},
	{"id": "soc_consejo_sequito", "title": "Consejo de armas", "min_tier": 3, "kinds": ["retinue", "spouse"], "bias": {P.VALIENTE: 1.5, P.PRUDENTE: 1.5},
		"text": "{name} lleva días observándote entrenar y por fin se atreve: «Bajas la guardia al girar». Propone corregirlo juntos cada mañana.",
		"options": [
			{"label": "Entrenar juntos", "chance": 0.55, "chance_stat": "combat",
				"success": {"effects": {"combat": 1, "affection": 5}, "result": "Al final de la semana ya no bajas la guardia."},
				"failure": {"effects": {"affection": 4, "xp": 10}, "result": "Buenas mañanas, aunque la costumbre es terca."}},
			{"label": "Agradecerlo", "effects": {"affection": 2}, "result": "Quizá en otra ocasión."},
		]},
	{"id": "soc_cuentas", "title": "Las cuentas de la casa", "min_tier": 3, "kinds": ["spouse"], "bias": {P.PRUDENTE: 2.0, P.ASTUTO: 1.5},
		"text": "{name} ha revisado los libros del castillo y ha encontrado a un mayordomo que se queda con lo que no es suyo. Pregunta qué quieres hacer.",
		"options": [
			{"label": "Recuperarlo todo", "effects": {"castle_gold": 40, "affection": 4, "honor": 1}, "result": "El mayordomo devuelve hasta la última moneda."},
			{"label": "Dejarlo en sus manos", "effects": {"castle_gold": 25, "affection": 8}, "result": "{name} lo resuelve con discreción."},
		]},
	{"id": "soc_juramento", "title": "Un juramento", "min_tier": 4, "kinds": ["retinue", "friend", "lover"], "avoid": [P.CRUEL, P.COBARDE, P.ASTUTO], "bias": {P.LEAL: 2.5, P.HONORABLE: 1.5},
		"text": "{name} se arrodilla sin que nadie lo pida y jura seguirte hasta donde vayas, en la guerra y en la desgracia. Lo dice ante testigos.",
		"options": [
			{"label": "Aceptarlo", "effects": {"affection": 6, "honor": 3, "fame": 1}, "result": "La corte habla de esa lealtad durante semanas."},
			{"label": "Levantarl{s:o|a}", "effects": {"affection": 4, "honor": 1}, "result": "«Entre nosotros no hacen falta juramentos.»"},
		]},
	{"id": "soc_momento_intimo", "title": "Una noche en vela", "min_tier": 4, "kinds": [], "bias": {P.ROMANTICO: 2.5},
		"text": "La tormenta corta los caminos y os quedáis junto al fuego hasta tarde. {name} te habla de su infancia, de sus miedos y de lo que espera de ti.",
		"options": [
			{"label": "Abrirte también", "effects": {"affection": 10, "xp": 10}, "result": "Al alba, algo ha cambiado entre los dos."},
			{"label": "Escuchar en silencio", "effects": {"affection": 4}, "result": "{name} agradece que la escuches."},
		]},
	# --- Cónyuge ---
	{"id": "soc2_conyuge_suegros", "title": "Visita de los parientes", "min_tier": 1, "kinds": ["spouse"], "bias": {P.GENEROSO: 1.5, P.ARROGANTE: 1.2},
		"text": "Los parientes de {name} anuncian visita por San Martín: llegan con tres carros, muchos criados y más opiniones aún sobre cómo gobiernas tu casa.",
		"options": [
			{"label": "Recibirlos con largueza", "effects": {"castle_food": -15, "affection": 8}, "result": "Comen como lobos, pero {name} te lo agradece con la mirada."},
			{"label": "Ganártelos con palabras", "chance": 0.5, "chance_stat": "charisma",
				"success": {"effects": {"affection": 6, "fame": 1}, "result": "Al tercer día el suegro ya brinda por ti."},
				"failure": {"effects": {"affection": -4}, "result": "Se marchan murmurando, y {name} paga tu torpeza."}},
			{"label": "Recibirlos con frialdad", "effects": {"affection": -6}, "result": "La visita dura poco. El silencio de {name}, bastante más."},
		]},
	{"id": "soc2_conyuge_retrato", "title": "Un retrato de familia", "min_tier": 2, "kinds": ["spouse"], "bias": {P.ROMANTICO: 1.5, P.ARROGANTE: 1.3},
		"text": "Un pintor flamenco de paso por la comarca ofrece retratar a los señores de la casa. {name} ya ha elegido el vestido y te pregunta si posarás a su lado.",
		"options": [
			{"label": "Encargar el retrato", "requires": {"gold": 30}, "effects": {"gold": -30, "affection": 8, "fame": 1}, "result": "El cuadro preside el salón, y {name} se detiene a mirarlo cada tarde."},
			{"label": "Quizá otro año", "effects": {"affection": -3}, "result": "{name} guarda el vestido sin decir nada."},
		]},
	{"id": "soc2_conyuge_feria", "title": "La feria de la cosecha", "min_tier": 3, "kinds": ["spouse"], "bias": {P.PRUDENTE: 1.5, P.AMBICIOSO: 1.3},
		"text": "Se acerca la feria de la cosecha y {name} quiere organizarla en persona: tasas justas para los mercaderes, puestos bien ordenados y nada de alborotos.",
		"options": [
			{"label": "Dejarlo en sus manos", "effects": {"castle_gold": 20, "affection": 6}, "result": "Una feria tranquila y unas arcas algo más llenas."},
			{"label": "Organizarla tú", "chance": 0.5, "chance_stat": "strategy",
				"success": {"effects": {"castle_gold": 30, "affection": -2}, "result": "La feria es un éxito, aunque {name} se siente apartad{s:o|a}."},
				"failure": {"effects": {"castle_gold": -10, "affection": -4}, "result": "Dos gremios se pelean por los puestos y la feria acaba en trifulca."}},
		]},
	{"id": "soc2_conyuge_fiebres", "title": "Fiebres de otoño", "min_tier": 4, "kinds": ["spouse"], "bias": {P.LEAL: 1.5, P.ROMANTICO: 1.5},
		"text": "{name} cae con unas fiebres que no ceden. El físico habla de sangrías; la vieja del pueblo, de caldo y paciencia. Todos esperan a ver qué dispones.",
		"options": [
			{"label": "Velarl{s:o|a} tú mism{a:o|a}", "effects": {"health": -5, "affection": 10}, "result": "Tres noches sin dormir. Cuando la fiebre baja, tu mano sigue en la suya."},
			{"label": "Traer un físico de la ciudad", "requires": {"gold": 25}, "effects": {"gold": -25, "affection": 6}, "result": "El físico cobra caro, pero {name} se recupera."},
		]},
	# --- Séquito ---
	{"id": "soc2_sequito_espada", "title": "Una hoja partida", "min_tier": 1, "kinds": ["retinue"], "bias": {P.VALIENTE: 1.5},
		"text": "Durante la práctica, la espada de {name} se parte por la mitad contra un poste. Es la única que tiene, y el herrero no fía.",
		"options": [
			{"label": "Pagarle una nueva", "requires": {"gold": 15}, "effects": {"gold": -15, "affection": 6}, "result": "{name} prueba el filo y sonríe como un niño."},
			{"label": "Que se apañe", "effects": {"affection": -4}, "result": "{name} entrena con un palo durante semanas."},
		]},
	{"id": "soc2_sequito_guardia", "title": "Dormid{s:o|a} en la guardia", "min_tier": 2, "kinds": ["retinue"], "avoid": [P.HONORABLE, P.LEAL], "bias": {P.COBARDE: 1.5, P.PRUDENTE: 0.6},
		"text": "Al alba encuentras a {name} dormid{s:o|a} sobre su lanza en el adarve. Los demás hombres miran de reojo: esperan ver si hay castigo.",
		"options": [
			{"label": "Castigarl{s:o|a} ante todos", "effects": {"honor": 1, "affection": -6}, "result": "La guardia no vuelve a cabecear en mucho tiempo."},
			{"label": "Perdonarl{s:o|a} en privado", "effects": {"affection": 6, "honor": -1}, "result": "{name} no olvidará que le ahorraste la vergüenza."},
		]},
	{"id": "soc2_sequito_reclutas", "title": "Mozos sin instrucción", "min_tier": 3, "kinds": ["retinue"], "bias": {P.VALIENTE: 1.3, P.LEAL: 1.3},
		"text": "{name} se ofrece a instruir a los mozos que han llegado de las aldeas. Dice que en un mes sabrán cerrar filas, si les das de comer como a soldados.",
		"options": [
			{"label": "Aceptar su oferta", "effects": {"garrison": 3, "castle_food": -10, "affection": 4}, "result": "Al mes, los mozos ya marchan al paso."},
			{"label": "No hace falta", "effects": {"affection": -2}, "result": "{name} vuelve a sus tareas, algo decepcionad{s:o|a}."},
		]},
	{"id": "soc2_sequito_golpe", "title": "Un golpe ajeno", "min_tier": 4, "kinds": ["retinue"], "avoid": [P.COBARDE, P.CRUEL], "bias": {P.LEAL: 2.0, P.VALIENTE: 1.5},
		"text": "En una emboscada en el camino, {name} se interpuso entre tú y un hachazo. Ahora tiene el brazo vendado y quita importancia a la herida.",
		"options": [
			{"label": "Curarle tú mism{a:o|a}", "effects": {"health": -3, "affection": 10, "honor": 2}, "result": "Cambias sus vendas cada noche. Nadie en el séquito lo olvida."},
			{"label": "Recompensarl{s:o|a}", "requires": {"gold": 30}, "effects": {"gold": -30, "affection": 8, "fame": 1}, "result": "La bolsa se comenta en todo el campamento."},
		]},
	# --- Siervos ---
	{"id": "soc2_siervo_boda", "title": "Licencia para casarse", "min_tier": 1, "kinds": ["serf"], "bias": {P.ROMANTICO: 2.0},
		"text": "{name} quiere casarse con alguien de la aldea vecina, de otro señor. Sin tu licencia y el pago de la mercheta, no hay boda.",
		"options": [
			{"label": "Pagar la mercheta", "requires": {"gold": 10}, "effects": {"gold": -10, "affection": 10, "honor": 1}, "result": "En la boda brindan por ti con vino aguado."},
			{"label": "Negar la licencia", "effects": {"affection": -8}, "result": "{name} acata, con los ojos enrojecidos."},
		]},
	{"id": "soc2_siervo_lobo", "title": "El lobo del redil", "min_tier": 1, "kinds": ["serf"], "bias": {P.VALIENTE: 1.5, P.COBARDE: 0.5},
		"text": "Un lobo viejo se lleva una oveja cada semana del redil que cuida {name}. Te pide ayuda antes de que su familia se quede sin lana para el invierno.",
		"options": [
			{"label": "Cazarlo tú", "chance": 0.55, "chance_stat": "combat",
				"success": {"effects": {"affection": 8, "xp": 15, "castle_food": 5}, "result": "Cuelgas la piel del lobo en la puerta del redil."},
				"failure": {"effects": {"health": -8, "affection": 4}, "result": "El lobo te muerde y escapa, pero {name} valora que lo intentaras."}},
			{"label": "Mandar a los monteros", "effects": {"affection": -2}, "result": "Los monteros tardan una semana. Otra oveja menos."},
		]},
	{"id": "soc2_siervo_letras", "title": "Las letras del capellán", "min_tier": 2, "kinds": ["serf"], "bias": {P.PIADOSO: 1.5, P.AMBICIOSO: 1.3},
		"text": "{name} te pide que su hijo pequeño aprenda a leer con el capellán del castillo. Ofrece trabajar los domingos para pagarlo.",
		"options": [
			{"label": "Pagarlo tú", "requires": {"gold": 10}, "effects": {"gold": -10, "affection": 10, "honor": 1}, "result": "El niño ya deletrea los salmos."},
			{"label": "Aceptar sus domingos", "effects": {"affection": 4, "castle_food": 5}, "result": "{name} trabaja de sol a sol, pero el niño aprende."},
			{"label": "Las letras no son para siervos", "effects": {"affection": -5}, "result": "{name} baja la cabeza y no insiste."},
		]},
	{"id": "soc2_siervo_granero", "title": "Goteras en el granero", "min_tier": 3, "kinds": ["serf"], "bias": {P.PRUDENTE: 1.5},
		"text": "{name} te lleva aparte: el tejado del granero gotea y el grano de abajo ya huele a moho. Los mayordomos no le han hecho caso.",
		"options": [
			{"label": "Reparar el tejado", "effects": {"castle_gold": -15, "castle_food": 15, "affection": 5}, "result": "Se salva casi todo el grano, y {name} gana tu confianza."},
			{"label": "Ya se verá", "effects": {"castle_food": -15, "affection": -3}, "result": "Con las lluvias se pudren varios sacos."},
		]},
	# --- Prisioneros ---
	{"id": "soc2_preso_carta", "title": "Una carta a casa", "min_tier": 1, "kinds": ["prisoner"], "bias": {P.ROMANTICO: 1.5, P.LEAL: 1.3},
		"text": "{name} te pide pluma y pergamino para escribir a su familia: no saben si vive. Promete que no dirá nada de tus muros ni de tus guardias.",
		"options": [
			{"label": "Permitirlo", "effects": {"affection": 8, "honor": 1}, "result": "{name} escribe despacio, borrando más de lo que deja."},
			{"label": "Leerla antes de enviarla", "chance": 0.5, "chance_stat": "strategy",
				"success": {"effects": {"affection": 2, "xp": 10}, "result": "Descubres una clave sencilla entre líneas y la corriges a tiempo."},
				"failure": {"effects": {"affection": -6}, "result": "{name} nota el sello roto y no vuelve a escribir."}},
			{"label": "Negarlo", "effects": {"affection": -5}, "result": "{name} se da la vuelta hacia la pared."},
		]},
	{"id": "soc2_preso_fiebre", "title": "Fiebre en la mazmorra", "min_tier": 1, "kinds": ["prisoner"], "bias": {P.PIADOSO: 1.3},
		"text": "La humedad de la mazmorra ha hecho mella: {name} tose sangre y apenas toca el pan. El carcelero dice que no pasará del mes.",
		"options": [
			{"label": "Llamar al físico", "requires": {"gold": 10}, "effects": {"gold": -10, "affection": 8, "honor": 2}, "result": "Con caldo y una celda seca, {name} sale adelante."},
			{"label": "Que aguante", "effects": {"affection": -6, "honor": -1}, "result": "Los otros presos cuentan que dejaste a {name} pudrirse."},
		]},
	{"id": "soc2_preso_ajedrez", "title": "Una partida entre rejas", "min_tier": 2, "kinds": ["prisoner"], "bias": {P.ASTUTO: 2.0, P.ARROGANTE: 1.3},
		"text": "{name} ha tallado un tablero de ajedrez con huesos de la comida y te reta a una partida. Dice que juega mejor que cualquier señor que conozca.",
		"options": [
			{"label": "Aceptar el reto", "chance": 0.5, "chance_stat": "strategy",
				"success": {"effects": {"xp": 15, "affection": 4}, "result": "Le das jaque con un peón. {name} se ríe por primera vez desde que llegó."},
				"failure": {"effects": {"xp": 10, "affection": 6}, "result": "{name} gana, y te explica la jugada con paciencia de maestro."}},
			{"label": "No juegas con presos", "effects": {"affection": -3}, "result": "{name} guarda las piezas en silencio."},
		]},
	{"id": "soc2_preso_fuga", "title": "Una fuga en ciernes", "min_tier": 3, "kinds": ["prisoner"], "bias": {P.ASTUTO: 1.5, P.LEAL: 1.2},
		"text": "{name} te avisa en voz baja: los presos de la celda vecina han sobornado a un carcelero y piensan huir con la luna nueva.",
		"options": [
			{"label": "Reforzar la guardia", "effects": {"castle_gold": -10, "affection": 6, "xp": 10}, "result": "La fuga se frustra antes de empezar. Nadie sabe quién habló."},
			{"label": "Desconfiar del aviso", "effects": {"affection": -6, "garrison": -1}, "result": "Esa noche un guardia aparece con la cabeza abierta."},
		]},
	# --- Amantes ---
	{"id": "soc2_amante_carta", "title": "Una carta extraviada", "min_tier": 2, "kinds": ["lover"], "bias": {P.ROMANTICO: 2.0, P.COBARDE: 1.2},
		"text": "Una de tus cartas a {name} ha acabado en manos de una criada charlatana. Por ahora solo ha leído el encabezamiento, o eso asegura.",
		"options": [
			{"label": "Comprar su silencio", "requires": {"gold": 15}, "effects": {"gold": -15, "affection": 6}, "result": "La criada jura no saber leer. {name} respira tranquil{s:o|a}."},
			{"label": "Convencerla con buenas palabras", "chance": 0.5, "chance_stat": "charisma",
				"success": {"effects": {"affection": 4}, "result": "La criada te devuelve la carta y una sonrisa cómplice."},
				"failure": {"effects": {"affection": -4, "honor": -2}, "result": "En la cocina ya circulan rumores."}},
		]},
	{"id": "soc2_amante_huerto", "title": "Cita en el huerto", "min_tier": 3, "kinds": ["lover"], "bias": {P.ROMANTICO: 2.5},
		"text": "Un recado escrito con prisa: {name} te esperará a medianoche junto al pozo del huerto, cuando la guardia cambie de turno.",
		"options": [
			{"label": "Acudir", "effects": {"affection": 10, "health": -2}, "result": "La noche es fría y el rocío cala, pero vale cada minuto."},
			{"label": "No arriesgarte", "effects": {"affection": -6}, "result": "{name} espera junto al pozo hasta que canta el gallo."},
		]},
	{"id": "soc2_amante_prenda", "title": "Una prenda", "min_tier": 3, "kinds": ["lover"], "bias": {P.ROMANTICO: 2.0, P.GENEROSO: 1.3},
		"text": "{name} te entrega una cinta bordada con vuestras iniciales escondidas en el dibujo y te pide algo tuyo para llevarlo siempre encima.",
		"options": [
			{"label": "Darle tu anillo", "effects": {"affection": 8, "gold": -10}, "result": "{name} lo cuelga de un cordón, bajo la ropa."},
			{"label": "Prometerle algo mejor", "effects": {"affection": 3}, "result": "{name} sonríe, aunque esperaba otra cosa."},
		]},
	{"id": "soc2_amante_celos", "title": "Celos", "min_tier": 4, "kinds": ["lover"], "bias": {P.ARROGANTE: 1.5, P.ROMANTICO: 1.5, P.PRUDENTE: 0.6},
		"text": "{name} te vio bailar dos veces con la misma persona en el último banquete y no ha dormido desde entonces. Exige saber qué hay entre vosotros.",
		"options": [
			{"label": "Tranquilizarl{s:o|a}", "chance": 0.6, "chance_stat": "charisma",
				"success": {"effects": {"affection": 8}, "result": "{name} acaba riéndose de sus propios miedos."},
				"failure": {"effects": {"affection": -6}, "result": "Cuanto más explicas, menos te cree."}},
			{"label": "Tomarlo a broma", "effects": {"affection": -4}, "result": "{name} no le ve la gracia."},
		]},
	# --- Cortesanos (conocidos) ---
	{"id": "soc2_corte_chisme", "title": "Chismes del chambelán", "min_tier": 1, "kinds": ["courtier"], "bias": {P.ASTUTO: 2.0, P.AMBICIOSO: 1.3},
		"text": "{name} se te acerca en la galería con aire de conspiración: sabe por qué el chambelán ha perdido el favor del rey, y está deseando contártelo.",
		"options": [
			{"label": "Escuchar con interés", "effects": {"xp": 10, "affection": 4, "honor": -1}, "result": "Un chisme jugoso, y quizá útil algún día."},
			{"label": "Cortar la conversación", "effects": {"honor": 1, "affection": -3}, "result": "{name} busca otros oídos."},
		]},
	{"id": "soc2_corte_halcon", "title": "Una jornada de cetrería", "min_tier": 1, "kinds": ["courtier"], "bias": {P.ARROGANTE: 1.3, P.VALIENTE: 1.2},
		"text": "{name} te invita a probar su nuevo halcón peregrino en las riberas del río. Media corte irá, y todos querrán ver qué tal sostienes el ave.",
		"options": [
			{"label": "Ir de caza", "chance": 0.55, "chance_stat": "combat",
				"success": {"effects": {"fame": 2, "affection": 6}, "result": "Tu halcón trae una garza al primer vuelo."},
				"failure": {"effects": {"affection": 2, "honor": -1}, "result": "El ave se te escapa y hay que buscarla entre los juncos."}},
			{"label": "Excusarte", "effects": {"affection": -3}, "result": "{name} va sin ti y cuenta otra historia."},
		]},
	{"id": "soc2_corte_asiento", "title": "Cuestión de precedencia", "min_tier": 1, "kinds": ["courtier"], "bias": {P.ARROGANTE: 2.0, P.HONORABLE: 1.2},
		"text": "En el banquete, el maestresala os ha asignado el mismo asiento a ti y a {name}. Nadie quiere ceder, y la sala ya mira la escena.",
		"options": [
			{"label": "Ceder el asiento", "effects": {"honor": 2, "affection": 6, "fame": -1}, "result": "{name} te lo agradece con una reverencia."},
			{"label": "Reclamar tu lugar", "effects": {"affection": -6, "fame": 1}, "result": "Te sientas. {name} cena dos sitios más abajo, con la cara encendida."},
		]},
	{"id": "soc2_corte_potro", "title": "Un potro codiciado", "min_tier": 1, "kinds": ["courtier"], "bias": {P.AMBICIOSO: 1.5, P.GENEROSO: 1.2},
		"text": "{name} ha visto el potro tordo de tus cuadras y quiere comprarlo para regalárselo a su señor. Ofrece un precio justo, ni más ni menos.",
		"options": [
			{"label": "Vendérselo", "effects": {"gold": 40, "affection": 4}, "result": "{name} se lleva el potro y una buena impresión de ti."},
			{"label": "Regalárselo", "effects": {"affection": 10, "fame": 1}, "result": "{name} presume ante la corte de tu generosidad."},
			{"label": "No está en venta", "effects": {"affection": -2}, "result": "{name} acepta la negativa con una sonrisa forzada."},
		]},
	# --- Amigos ---
	{"id": "soc2_amigo_taberna", "title": "Gresca en la taberna", "min_tier": 2, "kinds": ["friend"], "bias": {P.VALIENTE: 1.5, P.ARROGANTE: 1.3},
		"text": "En la taberna del puente, unos carreteros borrachos acorralan a {name} por una partida de dados mal contada. Te mira buscando ayuda.",
		"options": [
			{"label": "Meterte en la pelea", "chance": 0.55, "chance_stat": "combat",
				"success": {"effects": {"affection": 8, "fame": 1}, "result": "Salís los dos por la puerta, riendo y con los nudillos pelados."},
				"failure": {"effects": {"health": -10, "affection": 6}, "result": "Os echan a la calle con un ojo morado cada uno."}},
			{"label": "Pagar los daños", "requires": {"gold": 15}, "effects": {"gold": -15, "affection": 4}, "result": "El tabernero calma los ánimos a cambio de tu bolsa."},
		]},
	{"id": "soc2_amigo_jabali", "title": "La montería del jabalí", "min_tier": 2, "kinds": ["friend"], "avoid": [P.COBARDE], "bias": {P.VALIENTE: 2.0, P.COBARDE: 0.4},
		"text": "{name} ha visto huellas de un jabalí enorme en el robledal y propone salir a por él al amanecer, solo vosotros dos y un par de lebreles.",
		"options": [
			{"label": "Salir de montería", "effects": {"xp": 15, "affection": 6, "health": -3}, "result": "El jabalí os da guerra, pero esa noche cenáis como reyes."},
			{"label": "Declinar", "effects": {"affection": -3}, "result": "{name} va con otros y vuelve con el colmillo."},
		]},
	{"id": "soc2_amigo_versos", "title": "Unos versos terribles", "min_tier": 3, "kinds": ["friend"], "bias": {P.ROMANTICO: 2.0},
		"text": "{name} te lee, muy seri{s:o|a}, los versos que ha compuesto para conquistar un corazón de la corte. Son, sin exagerar, espantosos.",
		"options": [
			{"label": "Decirle la verdad", "chance": 0.5, "chance_stat": "charisma",
				"success": {"effects": {"affection": 6, "honor": 1}, "result": "Os pasáis la tarde corrigiéndolos juntos, entre carcajadas."},
				"failure": {"effects": {"affection": -5}, "result": "{name} enrolla el pergamino, ofendid{s:o|a}."}},
			{"label": "Alabarlos", "effects": {"affection": 4, "honor": -1}, "result": "Nadie contesta a los versos, pero {name} te sigue apreciando."},
		]},
	{"id": "soc2_amigo_padrino", "title": "Padrino de duelo", "min_tier": 4, "kinds": ["friend"], "avoid": [P.COBARDE], "bias": {P.HONORABLE: 2.0, P.LEAL: 1.5, P.PRUDENTE: 0.6},
		"text": "Un caballero ha insultado a la familia de {name} y el duelo es inevitable. Te pide que seas su padrino: que midas las armas y estés a su lado si cae.",
		"options": [
			{"label": "Aceptar", "effects": {"honor": 3, "fame": 1, "affection": 10, "health": -5}, "result": "{name} vence, y tú recibes un corte al separar a los padrinos."},
			{"label": "Intentar disuadirl{s:o|a}", "chance": 0.5, "chance_stat": "charisma",
				"success": {"effects": {"affection": 4, "honor": 1}, "result": "Consigues una disculpa pública y nadie derrama sangre."},
				"failure": {"effects": {"affection": -6}, "result": "{name} busca otro padrino y no te lo perdona."}},
		]},
	# --- Sucesos propios de cada carácter (only): lo que solo haría alguien así ---
	{"id": "soc3_ambicion_tierras", "title": "Hambre de tierras", "min_tier": 1, "kinds": [], "only": [P.AMBICIOSO],
		"text": "{name} ha puesto los ojos en un señorío sin dueño y quiere pedirlo al señor. Te propone ir a medias: tu palabra a cambio de una parte de las rentas.",
		"options": [
			{"label": "Respaldarle ante el señor", "chance": 0.55, "chance_stat": "charisma",
				"success": {"effects": {"gold": 40, "affection": 8}, "result": "Le conceden el señorío y {name} cumple: te envía tu parte."},
				"failure": {"effects": {"affection": 3, "honor": -1}, "result": "El señor se ríe de la petición. {name} no te lo reprocha."}},
			{"label": "Aconsejarle paciencia", "effects": {"affection": -4}, "result": "{name} frunce el ceño: no ha nacido para esperar."},
		]},
	{"id": "soc3_leal_aviso", "title": "Un aviso a tiempo", "min_tier": 2, "kinds": [], "only": [P.LEAL],
		"text": "{name} llega de noche, sin aliento: ha oído en la taberna a dos hombres que planean robar tus caballos camino de la feria.",
		"options": [
			{"label": "Doblar la guardia y agradecérselo", "effects": {"affection": 6, "gold": 15}, "result": "Los ladrones encuentran las cuadras vigiladas y se marchan con las manos vacías."},
			{"label": "Tenderles una trampa", "chance": 0.55, "chance_stat": "strategy",
				"success": {"effects": {"fame": 3, "honor": 2, "affection": 6}, "result": "Caen en la trampa y los entregas a la justicia del señor."},
				"failure": {"effects": {"gold": -20}, "result": "Huelen la trampa y se llevan un potro en la confusión."}},
		]},
	{"id": "soc3_prudente_grano", "title": "Antes del invierno", "min_tier": 1, "kinds": [], "only": [P.PRUDENTE],
		"text": "{name} ha hecho cuentas: si el invierno es largo, el grano no llegará a la primavera. Propone comprar ahora, mientras está barato.",
		"options": [
			{"label": "Comprar grano (30)", "requires": {"gold": 30}, "effects": {"gold": -30, "castle_food": 60, "affection": 5}, "result": "Los graneros se llenan. {name} duerme tranquil{s:o|a}."},
			{"label": "Ya veremos", "effects": {"affection": -2}, "result": "{name} anota algo en su cuaderno y no dice nada."},
		]},
	{"id": "soc3_arrogante_desaire", "title": "Un desaire en tu mesa", "min_tier": 1, "kinds": [], "only": [P.ARROGANTE],
		"text": "{name} se niega a compartir mesa con tu escudero, «hijo de un herrero». El muchacho, rojo de vergüenza, espera a ver qué haces.",
		"options": [
			{"label": "Defender a tu escudero", "effects": {"affection": -6, "honor": 3}, "result": "{name} se levanta ofendid{s:o|a}; tu gente te mira con otros ojos."},
			{"label": "Mandar al escudero a otra mesa", "effects": {"affection": 6, "honor": -2}, "result": "{name} sonríe satisfech{s:o|a}. El muchacho no olvida."},
		]},
	{"id": "soc3_piadoso_peregrinacion", "title": "Camino del santuario", "min_tier": 2, "kinds": [], "only": [P.PIADOSO],
		"text": "{name} va a peregrinar al santuario del monte y te invita a acompañar{s:le|la}: tres días de camino, ayuno y oración.",
		"options": [
			{"label": "Acompañar{s:le|la}", "effects": {"affection": 10, "honor": 4, "health": 10}, "result": "Volvéis con los pies llagados y el alma en paz."},
			{"label": "Darle una limosna para el santuario (15)", "requires": {"gold": 15}, "effects": {"gold": -15, "affection": 4, "honor": 1}, "result": "{name} promete rezar por ti ante el altar."},
			{"label": "Excusarte", "effects": {"affection": -3}, "result": "{name} se marcha sin ti, rezando también por tu alma."},
		]},
	{"id": "soc3_astuto_negocio", "title": "Un negocio discreto", "min_tier": 1, "kinds": [], "only": [P.ASTUTO],
		"text": "{name} conoce a unos mercaderes de sal que pagarían bien por pasar sin peaje por tus caminos. Nadie tendría por qué enterarse.",
		"options": [
			{"label": "Aceptar el trato", "effects": {"gold": 50, "honor": -4, "affection": 6}, "result": "La sal pasa de noche y las monedas llegan puntuales."},
			{"label": "Negarte", "effects": {"affection": -4, "honor": 1}, "result": "{name} se encoge de hombros: «Otro sabrá aprovecharlo»."},
		]},
	{"id": "soc3_valiente_combate", "title": "Acero contra acero", "min_tier": 1, "kinds": [], "only": [P.VALIENTE],
		"text": "{name} te reta a un asalto de práctica en el patio, delante de todos: «Quiero ver si eres tan bueno como dicen».",
		"options": [
			{"label": "Aceptar el asalto", "chance": 0.55, "chance_stat": "combat",
				"success": {"effects": {"xp": 15, "fame": 2, "affection": 6}, "result": "Le desarmas con un giro limpio y {name} ríe, encantad{s:o|a}."},
				"failure": {"effects": {"xp": 10, "health": -8, "affection": 4}, "result": "Acabas en el suelo con la espada de {name} en el cuello. Te tiende la mano."}},
			{"label": "Declinar", "effects": {"affection": -4}, "result": "{name} no oculta su decepción."},
		]},
	{"id": "soc3_cruel_castigo", "title": "La vara en las cuadras", "min_tier": 1, "kinds": [], "only": [P.CRUEL],
		"text": "Encuentras a {name} azotando a un mozo de cuadra por dejar suelta una yegua. El chico sangra y nadie se atreve a intervenir.",
		"options": [
			{"label": "Detener{s:le|la}", "effects": {"affection": -8, "honor": 4}, "result": "{name} arroja la vara a tus pies. El mozo te mira como a un santo."},
			{"label": "Dejar que siga", "effects": {"affection": 4, "honor": -4}, "result": "Los gritos se oyen hasta el patio."},
		]},
	{"id": "soc3_generoso_limosna", "title": "Pan para los pobres", "min_tier": 1, "kinds": [], "only": [P.GENEROSO],
		"text": "{name} ha repartido en tu nombre un carro de pan entre los pobres del arrabal. Ahora te trae la cuenta, algo avergonzad{s:o|a}.",
		"options": [
			{"label": "Pagarla con gusto (25)", "requires": {"gold": 25}, "effects": {"gold": -25, "honor": 3, "fame": 3, "affection": 6}, "result": "En el arrabal bendicen tu nombre."},
			{"label": "Reprenderle por gastar lo ajeno", "effects": {"affection": -6, "honor": -1}, "result": "{name} paga de su bolsa, dolid{s:o|a}."},
		]},
	{"id": "soc3_cobarde_excusa", "title": "Una excusa mal hilada", "min_tier": 1, "kinds": [], "only": [P.COBARDE],
		"text": "{name} te pide que digas que estaba contigo anoche: le tocaba la ronda por los caminos y no se presentó. Han robado a un mercader.",
		"options": [
			{"label": "Cubrir{s:le|la}", "effects": {"affection": 8, "honor": -3}, "result": "{name} respira aliviad{s:o|a}. Te debe una."},
			{"label": "Decir la verdad", "effects": {"affection": -8, "honor": 2}, "result": "El capitán le retira la paga de un mes."},
		]},
	{"id": "soc3_romantico_cantar", "title": "Un cantar sobre ti", "min_tier": 2, "kinds": [], "only": [P.ROMANTICO],
		"text": "En el banquete, {name} se levanta con un laúd y canta unas coplas sobre tus hazañas, adornadas con más gloria de la que hubo.",
		"options": [
			{"label": "Brindar por el cantar", "effects": {"fame": 4, "affection": 6}, "result": "Al día siguiente, medio castillo tararea tus coplas."},
			{"label": "Corregir lo exagerado", "effects": {"honor": 2, "affection": -3}, "result": "{name} se sonroja; la corte aprecia tu modestia."},
		]},
	{"id": "soc3_honorable_verdad", "title": "Una verdad incómoda", "min_tier": 2, "kinds": [], "only": [P.HONORABLE],
		"text": "{name} te habla sin rodeos: tus soldados saquean las aldeas por donde pasáis, y tu nombre se mancha con ello.",
		"options": [
			{"label": "Escuchar y poner orden", "effects": {"honor": 4, "affection": 8, "gold": -10}, "result": "Pagas a las aldeas lo robado. {name} asiente en silencio."},
			{"label": "Mandarle callar", "effects": {"affection": -10}, "result": "{name} no vuelve a sacar el tema, pero algo se ha roto."},
		]},
]

# --- 2) Rivalidades (el protagonista es un rival de duelo) ---
const RIVALRY := [
	{"id": "soc_apuesta", "title": "Una apuesta", "stages": [ST.CONOCIDO, ST.RIVAL, ST.RESPETO], "avoid": [P.PIADOSO], "bias": {P.AMBICIOSO: 1.5, P.ARROGANTE: 1.5},
		"text": "{name} te propone una apuesta delante de la corte: tres flechas al blanco, cincuenta monedas al que acierte más. Los cortesanos ya cruzan sus propias apuestas.",
		"options": [
			{"label": "Apostar 50", "requires": {"gold": 50}, "chance": 0.5, "chance_stat": "combat",
				"success": {"effects": {"gold": 50, "fame": 2, "grudge": 5}, "result": "Tu última flecha parte la de {name}."},
				"failure": {"effects": {"gold": -50, "grudge": -3}, "result": "{name} cobra con una sonrisa."}},
			{"label": "Declinar", "effects": {}, "result": "No todo se resuelve apostando."},
		]},
	{"id": "soc_humillacion", "title": "Humillación pública", "stages": [ST.RIVAL, ST.NEMESIS], "avoid": [P.HONORABLE, P.PIADOSO], "bias": {P.ARROGANTE: 2.0, P.CRUEL: 1.5, P.HONORABLE: 0.4},
		"text": "En pleno banquete, {name} brinda «por {player}, que lucha mejor con la lengua que con la espada». Las risas recorren las mesas.",
		"options": [
			{"label": "Responder con ingenio", "chance": 0.5, "chance_stat": "charisma",
				"success": {"effects": {"honor": 4, "fame": 1, "grudge": 5}, "result": "Tu réplica deja a {name} sin palabras."},
				"failure": {"effects": {"honor": -4}, "result": "Tu réplica muere en un silencio incómodo."}},
			{"label": "Retarl{s:o|a} ahora", "requires": {"healthy": true}, "start_duel": true, "effects": {}, "result": "Te levantas y arrojas el guante."},
			{"label": "Aguantar", "effects": {"honor": -3, "grudge": -3}, "result": "Tragas saliva. Hay quien lo llama templanza."},
		]},
	{"id": "soc_sabotaje", "title": "Un cortejo saboteado", "stages": [ST.RIVAL, ST.NEMESIS], "needs": "beloved", "avoid": [P.HONORABLE], "bias": {P.ASTUTO: 2.0, P.AMBICIOSO: 1.5},
		"text": "{name} ha empezado a rondar a {third} con regalos y mentiras sobre ti. Sabes que no lo hace por amor, sino para quitártelo todo.",
		"options": [
			{"label": "Redoblar el cortejo", "requires": {"gold": 30}, "effects": {"gold": -30, "affection": 8}, "result": "{third} aprecia el gesto y se ríe de los cuentos."},
			{"label": "Retar a {name}", "requires": {"healthy": true}, "start_duel": true, "effects": {}, "result": "Que la espada decida quién miente."},
			{"label": "Dejarlo estar", "effects": {"affection": -8}, "result": "{third} empieza a dudar de ti."},
		]},
	{"id": "soc_duelo_concertado", "title": "Un duelo de honor", "stages": [ST.RIVAL, ST.NEMESIS], "avoid": [P.COBARDE], "bias": {P.HONORABLE: 2.0, P.VALIENTE: 1.5, P.COBARDE: 0.2},
		"text": "Un heraldo trae el cartel de {name}: te emplaza a un duelo de honor ante testigos, en el palenque y dentro de dos meses. Rechazarlo se sabrá en todo el reino.",
		"options": [
			{"label": "Aceptar la cita", "social": {"schedule_duel": true}, "effects": {"fame": 1}, "result": "Fijas la fecha. La corte ya cuenta los días."},
			{"label": "Rechazar el cartel", "effects": {"honor": -5, "grudge": 5}, "result": "El heraldo se marcha con tu negativa."},
		]},
	{"id": "soc_reconciliacion", "title": "Una tregua", "stages": [ST.RIVAL, ST.RESPETO], "avoid": [P.CRUEL], "bias": {P.PIADOSO: 2.0, P.GENEROSO: 1.5, P.LEAL: 1.3, P.CRUEL: 0.3},
		"text": "{name} se presenta sin armas y te ofrece la mano. Dice que ya ha habido bastante rencor entre los dos y que el reino necesita a ambos.",
		"options": [
			{"label": "Estrecharla", "effects": {"grudge": -25, "honor": 2}, "result": "La corte respira: la vieja rivalidad se apaga."},
			{"label": "Rechazarla", "effects": {"grudge": 5}, "result": "{name} baja la mano despacio."},
		]},
	{"id": "soc_alianza_rival", "title": "El enemigo de mi enemigo", "stages": [ST.RIVAL, ST.RESPETO, ST.NEMESIS], "needs": "third", "bias": {P.ASTUTO: 1.5, P.AMBICIOSO: 1.5},
		"text": "{name} te propone olvidar vuestras cuentas por un tiempo: {third} os ha ofendido a ambos y juntos podéis bajarle los humos en la corte.",
		"options": [
			{"label": "Unir fuerzas", "social": {"third_grudge": 10}, "effects": {"grudge": -15, "fame": 2}, "result": "{third} pronto nota que tiene dos enemigos."},
			{"label": "Avisar a {third}", "social": {"third_grudge": -10}, "effects": {"grudge": 10, "honor": 2}, "result": "{third} te lo agradece; {name} no."},
		]},
	{"id": "soc2_rival_justa", "title": "Cruce de lanzas", "stages": [ST.CONOCIDO, ST.RIVAL, ST.RESPETO], "avoid": [P.COBARDE], "bias": {P.VALIENTE: 2.0, P.ARROGANTE: 1.3, P.COBARDE: 0.3},
		"text": "En el torneo de las fiestas, el sorteo te empareja con {name} en la justa. Al cruzaros junto a la liza, alza la lanza hacia ti con una media sonrisa.",
		"options": [
			{"label": "Justar con todo", "chance": 0.5, "chance_stat": "combat",
				"success": {"effects": {"fame": 3, "grudge": 5}, "result": "Tu lanza revienta en su escudo y {name} besa la arena."},
				"failure": {"effects": {"health": -10, "fame": -1, "grudge": -3}, "result": "Sales despedid{a:o|a} de la silla entre el griterío."}},
			{"label": "Retirarte alegando una lesión", "effects": {"honor": -2}, "result": "{name} recorre la liza sin rival, saludando a las gradas."},
		]},
	{"id": "soc2_rival_rumor", "title": "Un rumor en las tabernas", "stages": [ST.RIVAL, ST.NEMESIS], "avoid": [P.HONORABLE, P.PIADOSO], "bias": {P.ASTUTO: 2.0, P.CRUEL: 1.3, P.HONORABLE: 0.5},
		"text": "En las tabernas se cuenta que huiste en tu última batalla. Todos los hilos llevan al mismo sitio: un criado de {name} paga las rondas a quien repite la historia.",
		"options": [
			{"label": "Desmentirlo en la plaza", "chance": 0.5, "chance_stat": "charisma",
				"success": {"effects": {"honor": 3, "grudge": 5}, "result": "Los testigos de la batalla hablan por ti. El rumor muere."},
				"failure": {"effects": {"honor": -3}, "result": "Cuanto más lo niegas, más gente lo cree."}},
			{"label": "Pagar a un juglar", "requires": {"gold": 20}, "effects": {"gold": -20, "fame": 2, "grudge": 3}, "result": "Pronto se canta otra versión, y {name} sale peor parad{s:o|a}."},
			{"label": "Callar", "effects": {"fame": -1}, "result": "El rumor se apaga solo, aunque deja poso."},
		]},
	{"id": "soc2_rival_herradura", "title": "Una herradura floja", "stages": [ST.RIVAL, ST.NEMESIS], "avoid": [P.HONORABLE, P.PIADOSO, P.LEAL], "bias": {P.CRUEL: 1.5, P.ASTUTO: 1.5},
		"text": "Tu caballo amanece cojo: alguien le aflojó una herradura por la noche. El mozo de cuadras jura que vio al escudero de {name} rondando los establos.",
		"options": [
			{"label": "Denunciarlo ante la corte", "effects": {"honor": 2, "grudge": 10}, "result": "{name} lo niega con indignación, pero la sospecha queda."},
			{"label": "Pagarle con la misma moneda", "effects": {"honor": -4, "grudge": 5, "xp": 5}, "result": "A la semana, la silla de {name} aparece con la cincha cortada."},
			{"label": "Herrar de nuevo y olvidarlo", "requires": {"gold": 10}, "effects": {"gold": -10, "grudge": -3}, "result": "No tienes pruebas, y lo sabes."},
		]},
	{"id": "soc2_rival_lecho", "title": "Rival en el lecho", "stages": [ST.RIVAL, ST.RESPETO, ST.NEMESIS], "bias": {P.PIADOSO: 1.5, P.GENEROSO: 1.5, P.CRUEL: 0.5},
		"text": "Llega la noticia de que {name} ha caído del caballo y guarda cama con las costillas rotas. Media corte se pregunta si irás a visitarl{s:o|a}.",
		"options": [
			{"label": "Enviarle tu físico", "requires": {"gold": 20}, "effects": {"gold": -20, "grudge": -15, "honor": 3}, "result": "{name} recibe al físico con desconfianza, y después con algo parecido a la gratitud."},
			{"label": "Visitarl{s:o|a} para regodearte", "effects": {"honor": -3, "grudge": 10}, "result": "Le deseas pronta mejoría con una sonrisa que lo dice todo."},
			{"label": "No darte por enterad{a:o|a}", "effects": {}, "result": "Tienes asuntos más urgentes."},
		]},
]

# El duelo concertado llega a su fecha.
const DUEL_DAY := {"id": "soc_dia_duelo", "title": "El día del duelo",
	"text": "Ha llegado el día fijado. {name} te espera en el palenque, y la corte entera se ha reunido para ver quién tiene razón.",
	"options": [
		{"label": "Batirte", "requires": {"healthy": true}, "start_duel": true, "effects": {}, "result": "Entras en el palenque."},
		{"label": "No presentarte", "effects": {"honor": -8, "fame": -2, "grudge": 10}, "result": "Tu ausencia dice más que cualquier derrota."},
	]}

# --- 3) Señores: tu señor y los vecinos reaccionan a lo que haces ---
const LORD := [
	{"id": "soc_elogio", "title": "Carta de tu señor", "deed": "victoria", "liege": true,
		"text": "Un mensajero trae una carta sellada de {name}: ha sabido de tu victoria y quiere que todo el reino sepa que sirves bien. Al final añade que espera más.",
		"options": [
			{"label": "Responder con humildad", "effects": {"honor": 2, "affinity": 5}, "result": "{name} guarda tu carta."},
			{"label": "Pedir una recompensa", "chance": 0.5, "chance_stat": "charisma",
				"success": {"effects": {"gold": 60, "affinity": 2}, "result": "{name} envía una bolsa con el siguiente correo."},
				"failure": {"effects": {"affinity": -5}, "result": "{name} no responde."}},
		]},
	{"id": "soc_envidia_vecino", "title": "Un vecino receloso", "deed": "victoria", "liege": false,
		"text": "{name} escribe felicitándote por tu victoria, pero entre líneas se lee el miedo: pregunta qué piensas hacer con tantos hombres armados cerca de sus tierras.",
		"options": [
			{"label": "Tranquilizarl{s:o|a}", "effects": {"affinity": 6}, "result": "{name} duerme más tranquil{s:o|a}."},
			{"label": "Dejarle con la duda", "effects": {"affinity": -4, "fame": 1}, "result": "Que tema. El miedo también es respeto."},
		]},
	{"id": "soc_reproche", "title": "Un reproche", "deed": "deshonra", "liege": true,
		"text": "{name} te escribe con dureza: las historias sobre tu conducta llegan hasta su mesa y manchan su casa. Exige reparación antes de que la vergüenza crezca.",
		"options": [
			{"label": "Pagar una multa", "requires": {"gold": 40}, "effects": {"gold": -40, "affinity": 6, "honor": 2}, "result": "La multa calma a {name}."},
			{"label": "Pedir perdón", "effects": {"affinity": 2, "honor": 1}, "result": "{name} acepta, sin entusiasmo."},
			{"label": "Ignorar la carta", "effects": {"affinity": -10}, "result": "{name} no olvidará el desplante."},
		]},
	{"id": "soc_boda_regalo", "title": "Regalo de bodas", "deed": "boda", "liege": false,
		"text": "Llega un carro con el emblema de {name}: telas, vino y una carta que felicita tu matrimonio. Es cortesía, pero también un mensaje: quiere tenerte de amigo.",
		"options": [
			{"label": "Agradecerlo", "effects": {"gold": 30, "affinity": 6}, "result": "Un vecino amigo vale más que el vino."},
			{"label": "Devolver el presente", "effects": {"honor": 2, "affinity": -6}, "result": "Prefieres no deber nada a nadie."},
		]},
	{"id": "soc_orden", "title": "Órdenes de tu señor", "deed": "", "liege": true,
		"text": "{name} ordena que patrulles los caminos del norte, donde han visto jinetes extraños. No es una petición, aunque la carta sea cortés.",
		"options": [
			{"label": "Obedecer", "effects": {"affinity": 8, "fame": 2, "health": -5}, "result": "Dos semanas de barro, pero el camino queda limpio."},
			{"label": "Excusarte", "effects": {"affinity": -6}, "result": "{name} toma nota de tu excusa."},
		]},
	{"id": "soc_peticion_grano", "title": "Petición de grano", "deed": "", "liege": false, "premise": {"governs": true},
		"text": "{name} pide ayuda: una plaga ha arruinado sus cosechas y su gente pasa hambre. Ofrece pagar el grano en cuanto pueda, aunque ambos sabéis que tardará.",
		"options": [
			{"label": "Enviar grano", "effects": {"castle_food": -30, "affinity": 10, "honor": 2}, "result": "{name} no olvidará quién le ayudó."},
			{"label": "Negarte", "effects": {"affinity": -5}, "result": "Cada cual cuida de los suyos."},
		]},
	{"id": "soc_visita", "title": "Una visita de alcurnia", "deed": "", "liege": false, "premise": {"governs": true},
		"text": "{name} se presenta en tu castillo con su séquito, de paso hacia otras tierras. Cómo le recibas se comentará en todas las cortes vecinas.",
		"options": [
			{"label": "Agasajarl{s:o|a}", "requires": {"gold": 30}, "effects": {"gold": -30, "affinity": 10, "fame": 3}, "result": "{name} parte hablando bien de tu casa."},
			{"label": "Recibirl{s:o|a} con sencillez", "effects": {"affinity": 2}, "result": "Una visita correcta, sin más."},
		]},
	{"id": "soc_banquete", "title": "Banquete en la corte", "deed": "", "liege": true,
		"text": "{name} celebra un gran banquete y te sienta cerca de su mesa. Es un honor y una prueba: todos miran quién habla con quién.",
		"options": [
			{"label": "Lucirte", "chance": 0.55, "chance_stat": "charisma",
				"success": {"effects": {"affinity": 8, "fame": 3}, "result": "Tu brindis es el más aplaudido."},
				"failure": {"effects": {"affinity": -2, "honor": -1}, "result": "Un comentario desafortunado enfría la mesa."}},
			{"label": "Mantenerte discret{a:o|a}", "effects": {"affinity": 3}, "result": "Nadie te recuerda, nadie te reprocha."},
		]},
]

# --- 4) Facción: la gente de tu reino como un solo ejército ---
const FACTION := [
	{"id": "soc_brindis", "title": "Brindis tras la victoria", "after_battle": true,
		"text": "Esa noche, quienes lucharon a tu lado alzan las copas. {name} brinda por ti y por los que no volvieron, y el campamento entero responde con un rugido.",
		"options": [
			{"label": "Pagar otra ronda", "requires": {"gold": 10}, "social": {"group": 4}, "effects": {"gold": -10, "affection": 4, "fame": 1}, "result": "La noche es larga y la hermandad, más."},
			{"label": "Brindar por los caídos", "social": {"group": 2}, "effects": {"honor": 2}, "result": "Un silencio solemne, y luego las canciones."},
		]},
	{"id": "soc_camaraderia", "title": "Junto al fuego", "after_battle": false,
		"text": "Los de tu reino comparten fuego y cuentos: viejas batallas, señores tacaños y amores perdidos. {name} te hace sitio en el banco.",
		"options": [
			{"label": "Contar tus hazañas", "social": {"group": 3}, "effects": {"xp": 10}, "result": "Ríen, discuten y beben. Sois uno."},
			{"label": "Retirarte pronto", "effects": {}, "result": "Mañana hay trabajo."},
		]},
	{"id": "soc_rivalidad_interna", "title": "Disputa entre camaradas", "after_battle": false,
		"text": "{name} y {comrade} se disputan el mando de la vanguardia y ya han llegado a las manos. Ambos esperan que les des la razón.",
		"options": [
			{"label": "Apoyar a {name}", "social": {"adjust": {"comrade": -6}}, "effects": {"affection": 6}, "result": "{comrade} acata, de mala gana."},
			{"label": "Mediar", "chance": 0.5, "chance_stat": "charisma",
				"success": {"social": {}, "effects": {"affection": 3, "honor": 2}, "result": "Los dos acaban dándose la mano."},
				"failure": {"effects": {"affection": -3, "honor": -1}, "result": "Ninguno queda content{a:o|a} contigo."}},
		]},
	{"id": "soc_camarada_apuros", "title": "Un camarada en apuros", "after_battle": false,
		"text": "{name} ha caído en manos de un usurero que amenaza con quedarse su caballo y sus armas. Sin ellos no podrá volver a filas. Pide ayuda a quien lucha a su lado.",
		"options": [
			{"label": "Pagar su deuda", "requires": {"gold": 40}, "social": {"group": 2}, "effects": {"gold": -40, "affection": 12, "honor": 3}, "result": "{name} vuelve a filas gracias a ti."},
			{"label": "No es asunto tuyo", "effects": {"affection": -8}, "result": "{name} vende su caballo."},
		]},
	{"id": "soc_honor_grupo", "title": "El señor honra a los suyos", "after_battle": true, "liege": true,
		"text": "{name} reúne a quienes defendieron el reino y nombra a cada uno ante la corte. Cuando llega tu turno, te entrega una copa de plata.",
		"options": [
			{"label": "Aceptar con orgullo", "social": {"group": 2}, "effects": {"fame": 3, "honor": 2, "affinity": 3}, "result": "La copa pasa de mano en mano."},
			{"label": "Cederla a los caídos", "social": {"group": 4}, "effects": {"honor": 4}, "result": "Tus camaradas no lo olvidan."},
		]},
]

## Plantilla rellena: textos con nombres y género, sin claves de catálogo que el mapa no entiende.
static func build(t: Dictionary, speaker: Character, player: Character, names: Dictionary) -> Dictionary:
	var e: Dictionary = _fill(t.duplicate(true), speaker, player, names)
	for k in ["min_tier", "kinds", "stages", "deed", "bias", "avoid", "only", "liege", "after_battle", "needs", "premise"]:
		e.erase(k)
	return e

static func _fill(v: Variant, speaker: Character, player: Character, names: Dictionary) -> Variant:
	if v is String:
		var s: String = v
		for k: String in names:
			s = s.replace("{%s}" % k, str(names[k]))
		return DialogueCatalog._apply_gender(s, speaker, player)
	if v is Array:
		return v.map(func(x: Variant) -> Variant: return _fill(x, speaker, player, names))
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = v[k] if str(k) == "social" else _fill(v[k], speaker, player, names)
		return d
	return v

static func by_id(id: String) -> Dictionary:
	for list in [BOND, RIVALRY, LORD, FACTION]:
		for t: Dictionary in list:
			if t.id == id:
				return t
	return DUEL_DAY if id == DUEL_DAY.id else {}
