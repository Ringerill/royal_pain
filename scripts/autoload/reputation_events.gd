extends Node
# Autoload "ReputationEvents": sucesos que dependen de tu honor y tu fama.
#   - Intento de asesinato: con mala fama o enemigos poderosos. Puedes luchar, llamar a la guardia o pagar;
#     si vences, sabes quién lo envió.
#   - Mala fama (camino villano): encargos sucios, campesinos que huyen, bandidos que ofrecen tributo.
#   - Buena fama (héroe): te piden justicia, llegan voluntarios, los bardos cantan tus hazañas.
#   - Conflictos: alguien de honor opuesto al tuyo te desprecia en público (puedes retarle).
# Como mucho uno cada COOLDOWN meses. Depende de GameManager y RelationsData (no al revés).

const MONTHLY_CHANCE := 0.1
const COOLDOWN := 3
const ASSASSIN_INFAMY := 30           # mala fama a partir de la cual pueden mandarte un asesino
const ASSASSIN_ENEMY_AFFINITY := -40  # ...o si tienes señores tan enemistados
const VILLAIN_INFAMY := 20
const HERO_FAME := 30
const HERO_HONOR := 30
const CONFLICT_HONOR_GAP := 100       # diferencia de honor que basta para un choque

var last_month := -100

func _ready() -> void:
	GameManager.game_started.connect(func(_c: Character): last_month = -100)
	GameManager.turn_advanced.connect(_on_month_passed)

func _on_month_passed(_m: int, _y: int) -> void:
	var now := GameManager.months_elapsed()
	if not GameManager.is_game_active or now - last_month < COOLDOWN or randf() >= MONTHLY_CHANCE:
		return
	var e := make_event()
	if e.is_empty():
		return
	last_month = now
	GameManager.queue_event(e)

## Un suceso según tu reputación ({} si no toca ninguno). kind fuerza el tipo (pruebas).
func make_event(kind: String = "") -> Dictionary:
	var p: Character = GameManager.player_character
	if p == null:
		return {}
	var options := {}
	var sender := _worst_enemy()
	if p.infamy() >= ASSASSIN_INFAMY or (sender != null and sender.affinity <= ASSASSIN_ENEMY_AFFINITY):
		options["asesinato"] = 1.0
	if p.infamy() >= VILLAIN_INFAMY:
		options["villano"] = 2.0
	if p.fame >= HERO_FAME and p.honor >= HERO_HONOR:
		options["heroe"] = 2.0
	var foe := _opposite_honor_person()
	if foe != null:
		options["conflicto"] = 1.5
	if not kind.is_empty():
		if not options.has(kind):
			return {}
		options = {kind: 1.0}
	if options.is_empty():
		return {}
	var total := 0.0
	for k in options:
		total += float(options[k])
	var roll := randf() * total
	var chosen := ""
	for k in options:
		roll -= float(options[k])
		if roll <= 0.0:
			chosen = k
			break
	if chosen.is_empty():
		chosen = options.keys().back()
	match chosen:
		"asesinato":
			return _assassination(sender)
		"villano":
			return _villain()
		"heroe":
			return _hero()
		"conflicto":
			return _conflict(foe)
	return {}

## El señor que peor te quiere (o null).
func _worst_enemy() -> Relationship:
	var worst: Relationship = null
	for r: Relationship in RelationsData.lords():
		if worst == null or r.affinity < worst.affinity:
			worst = r
	return worst

## Alguien de tu zona con honor opuesto al tuyo (o null).
func _opposite_honor_person() -> Relationship:
	var p: Character = GameManager.player_character
	var pool: Array = []
	for r: Relationship in RelationsData.relations:
		if r.character == null or r.kind == Relationship.Kind.CONYUGE or r.kind == Relationship.Kind.PUEBLO:
			continue
		if not RelationsData.in_area(r) or absi(p.honor - r.character.honor) < CONFLICT_HONOR_GAP:
			continue
		pool.append(r)
	return pool.pick_random() if not pool.is_empty() else null

func _assassination(sender: Relationship) -> Dictionary:
	var who := sender.person_name if sender != null else "alguien que no se deja ver"
	var e := {"title": "Un puñal en la noche", "reputation": "asesinato",
		"text": "Un asesino se cuela en tus aposentos cuando duermes. Tu mala fama y tus enemigos tienen un precio.",
		"options": [
			{"label": "Luchar", "requires": {"healthy": true}, "effects": {}, "result": "Saltas del lecho con la espada en la mano.",
				"fight": {"type": "duel", "foe": {"name": "Asesino a sueldo", "role": Character.Role.SOLDADO, "power": 1, "personality": "CRUEL"},
					"win": {"effects": {"fame": 3, "affinity": -10}, "result": "Lo reduces. Antes de morir confiesa quién lo envió: %s." % who},
					"lose": {"effects": {"health": -40}, "result": "Te hiere y escapa por la ventana."}}},
			{"label": "Gritar a la guardia", "chance": 0.55, "chance_stat": "strategy",
				"success": {"effects": {}, "result": "La guardia lo atrapa en el pasillo. Nadie sabe quién lo envió."},
				"failure": {"effects": {"health": -30}, "result": "La guardia llega tarde: el asesino te hiere y huye."}},
			{"label": "Ofrecerle el doble", "requires": {"gold": 80}, "effects": {"gold": -80}, "result": "Se marcha con tu oro y la promesa de no volver."},
		]}
	if sender != null:
		e["target"] = sender.person_name
	return e

func _villain() -> Dictionary:
	match randi() % 6:
		3:
			return {"title": "Un usurero agradecido", "reputation": "villano",
				"text": "Un usurero de la ciudad te propone un trato: tú le prestas a tus hombres para cobrar sus deudas en la comarca y él te da una parte. Dice que nadie se atreverá a no pagarte.",
				"options": [
					{"label": "Prestarle tus hombres", "effects": {"gold": 80, "honor": -6, "garrison": -2}, "result": "Las deudas se cobran. Algunos de tus hombres no vuelven de las aldeas."},
					{"label": "Echarlo a patadas", "effects": {"honor": 2}, "result": "El usurero recoge su sombrero del barro y se marcha."}]}
		4:
			return {"title": "Nadie quiere venderte", "reputation": "villano",
				"text": "Tu fama ha llegado a los mercados: los tratantes de grano suben sus precios para ti o, directamente, cierran el puesto cuando ven tus colores.",
				"options": [
					{"label": "Pagar lo que piden", "requires": {"gold": 40}, "effects": {"gold": -40, "castle_food": 30}, "result": "Compras grano caro, pero los graneros se llenan."},
					{"label": "Requisarlo por la fuerza", "effects": {"castle_food": 30, "honor": -6, "fame": -1}, "result": "Tus hombres vacían los puestos. Nadie se atreve a protestar en voz alta."},
					{"label": "Arreglártelas sin ellos", "effects": {"castle_food": -10}, "result": "Este invierno se comerá menos en el castillo."}]}
		5:
			return {"title": "Un mercenario sin escrúpulos", "reputation": "villano",
				"text": "Un capitán de mercenarios expulsado de tres reinos se presenta a tu puerta. Dice que ha oído que aquí no se hacen preguntas, y trae veinte lanzas con él.",
				"options": [
					{"label": "Contratarlos", "requires": {"gold": 50}, "effects": {"gold": -50, "garrison": 8, "honor": -4}, "result": "Tu guarnición crece. Las mozas del pueblo dejan de salir de noche."},
					{"label": "Rechazarlos", "effects": {"honor": 2}, "result": "El capitán escupe en tu umbral y sigue camino."}]}
		0:
			return {"title": "Un encargo sucio", "reputation": "villano",
				"text": "Un mercader que conoce tu fama te ofrece oro por arruinar a un competidor. Nadie hace preguntas.",
				"options": [
					{"label": "Aceptar", "effects": {"gold": 120, "honor": -8}, "result": "El trabajo se hace. El oro, también."},
					{"label": "Rechazarlo", "effects": {"honor": 2}, "result": "Lo echas. Quizá aún te quede algo de dignidad."}]}
		1:
			return {"title": "Los campesinos huyen", "reputation": "villano",
				"text": "Corre la voz de tu crueldad: familias enteras abandonan tus tierras de noche.",
				"options": [
					{"label": "Dejarlos ir", "effects": {"castle_food": -20, "garrison": -3}, "result": "Los campos quedan a medio segar."},
					{"label": "Prometer clemencia", "requires": {"gold": 40}, "effects": {"gold": -40, "honor": 3}, "result": "Pagas sus deudas y vuelven, recelosos."}]}
	return {"title": "Bandidos a tu servicio", "reputation": "villano",
		"text": "Una banda de salteadores ofrece pagarte tributo a cambio de que no los persigas: dicen que eres de los suyos.",
		"options": [
			{"label": "Cobrar su tributo", "effects": {"gold": 60, "honor": -5}, "result": "Cobras. Los caminos serán menos seguros."},
			{"label": "Echarlos de tus tierras", "effects": {"honor": 3, "fame": 2}, "result": "Huyen. Algunos empiezan a dudar de tu leyenda negra."}]}

func _hero() -> Dictionary:
	match randi() % 6:
		3:
			return {"title": "Un niño con tu nombre", "reputation": "heroe",
				"text": "En la aldea del molino han bautizado a un recién nacido con tu nombre, y los padres te invitan a ser su padrino ante el altar.",
				"options": [
					{"label": "Apadrinarlo", "requires": {"gold": 15}, "effects": {"gold": -15, "honor": 3, "fame": 2}, "result": "El cura no ha visto la iglesia tan llena en años."},
					{"label": "Enviar un presente", "effects": {"castle_food": -5, "fame": 1}, "result": "Un queso y una bendición escrita. La familia lo guarda como reliquia."}]}
		4:
			return {"title": "Los gremios te honran", "reputation": "heroe",
				"text": "Los gremios de la villa, agradecidos por los caminos seguros, ofrecen una colecta en tu honor. Solo piden que asistas a su fiesta patronal.",
				"options": [
					{"label": "Aceptar la colecta", "effects": {"castle_gold": 40, "fame": 1}, "result": "Asistes, comes y bebes, y las arcas lo notan."},
					{"label": "Devolverla para el hospital", "effects": {"honor": 4, "fame": 2}, "result": "El hospital de peregrinos lleva desde entonces tu escudo en la puerta."}]}
		5:
			return {"title": "Un caballero errante", "reputation": "heroe",
				"text": "Un caballero errante, maltrecho por mil caminos, llega a tu castillo y se arrodilla: dice que solo quiere servir a alguien digno de su espada antes de morir.",
				"options": [
					{"label": "Tomarlo a tu servicio", "effects": {"garrison": 3, "castle_food": -10, "fame": 1}, "result": "El viejo caballero instruye a tus hombres con una paciencia infinita."},
					{"label": "Darle cama y descanso", "effects": {"castle_food": -5, "honor": 2, "health": 3}, "result": "Antes de partir, te enseña un par de viejos trucos de esgrima."}]}
		0:
			return {"title": "Te piden justicia", "reputation": "heroe",
				"text": "Unos aldeanos recorren leguas para que, tú que tienes fama de justo, resuelvas su pleito.",
				"options": [
					{"label": "Impartir justicia", "effects": {"honor": 4, "fame": 2}, "result": "Tu sentencia se cuenta en todas las tabernas."},
					{"label": "No tienes tiempo", "effects": {"honor": -2}, "result": "Se marchan decepcionados."}]}
		1:
			return {"title": "Llegan voluntarios", "reputation": "heroe",
				"text": "Mozos de las aldeas quieren servir a tus órdenes: han oído hablar de tus hazañas.",
				"options": [
					{"label": "Aceptarlos", "effects": {"garrison": 6}, "result": "Tu guarnición crece con gente entusiasta."},
					{"label": "Mandarlos a casa", "effects": {"honor": 1}, "result": "Les dices que sus familias los necesitan más."}]}
	return {"title": "Los bardos cantan", "reputation": "heroe",
		"text": "Un bardo ha compuesto una canción sobre tus hazañas y quiere cantarla en tu salón.",
		"options": [
			{"label": "Pagarle bien", "requires": {"gold": 20}, "effects": {"gold": -20, "fame": 5}, "result": "La canción corre de castillo en castillo."},
			{"label": "Que cante gratis", "effects": {"fame": 2}, "result": "Canta, aunque con menos ganas."}]}

func _conflict(r: Relationship) -> Dictionary:
	var p: Character = GameManager.player_character
	var text: String
	if p.honor > r.character.honor:
		text = "%s se burla en público de tu rectitud: «Los escrupulosos mueren pobres»." % r.person_name
	else:
		text = "%s te acusa en público de no tener honor ni palabra." % r.person_name
	return {"title": "Un choque de caracteres", "reputation": "conflicto", "speaker": r.person_name, "target": r.person_name,
		"duel_with": r.person_name, "text": text,
		"options": [
			{"label": "Retarle", "requires": {"healthy": true}, "start_duel": true, "effects": {}, "result": "Arrojas el guante."},
			{"label": "Responder con ingenio", "chance": 0.5, "chance_stat": "charisma",
				"success": {"effects": {"fame": 2, "grudge": 5}, "result": "Tu réplica hace reír a todos, menos a él."},
				"failure": {"effects": {"honor": -2, "grudge": 5}, "result": "Te quedas sin palabras."}},
			{"label": "Ignorarle", "effects": {"honor": -1, "grudge": 10}, "result": "Le das la espalda. Esto no ha terminado."}]}

func save_state() -> Dictionary:
	return {"last_month": last_month}

func load_state(data: Dictionary) -> void:
	last_month = int(data.get("last_month", -100))
