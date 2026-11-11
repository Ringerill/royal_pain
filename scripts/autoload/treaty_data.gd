extends Node
# Autoload "TreatyData": los señores de la IA te proponen tratados por su cuenta (un evento con opciones).
#   - Paz: un señor en guerra contigo que no te odia demasiado ofrece la paz. Si su reino es más débil
#     que el tuyo, paga él un tributo; si no, lo pide.
#   - Alianza: un señor con buena afinidad te la ofrece (desde Nobleza Baja).
#   - Tributo: un señor hostil de un reino más fuerte exige oro; si te niegas, te declara la guerra.
# Como mucho una propuesta cada COOLDOWN meses. Rechazar enfría la relación.
# Depende de GameManager, RelationsData y MapData (no al revés).

const EVENT_KEY := "treaty"
const MONTHLY_CHANCE := 0.1
const COOLDOWN := 4
const ALLY_OFFER_AFFINITY := 45        # afinidad mínima para que te ofrezcan alianza
const TRIBUTE_DEMAND_AFFINITY := -30   # por debajo, un reino más fuerte te exige tributo
const PEACE_GOLD := 100                # lo que paga (o pide) quien ofrece la paz
const TRIBUTE_GOLD := 80
const REJECT_AFFINITY := -6
const ACCEPT_AFFINITY := 8

var last_offer_month := -100

func _ready() -> void:
	GameManager.game_started.connect(func(_c: Character): reset())
	GameManager.turn_advanced.connect(_on_month_passed)
	GameManager.event_option_chosen.connect(_on_option_chosen)

func reset() -> void:
	last_offer_month = -100

func _on_month_passed(_m: int, _y: int) -> void:
	var now := GameManager.months_elapsed()
	if now - last_offer_month < COOLDOWN or randf() >= MONTHLY_CHANCE:
		return
	var offer := make_offer()
	if offer.is_empty():
		return
	last_offer_month = now
	GameManager.queue_event(offer)

static func _kingdom_strength(kingdom: int) -> int:
	var n := 0
	for c: Castle in MapData.castles:
		if c.kingdom == kingdom:
			n += 1
	return n

## La propuesta más urgente de algún señor ({} si nadie tiene nada que ofrecer). Prioridad: paz, tributo, alianza.
func make_offer() -> Dictionary:
	var player: Character = GameManager.player_character
	if player == null or not GameManager.is_game_active:
		return {}
	var mine := _kingdom_strength(GameManager.player_kingdom)
	var noble := player.rank() >= Character.rank_of(Character.Role.NOBLEZA_BAJA)
	var peace := []
	var tribute := []
	var alliance := []
	for r: Relationship in RelationsData.lords():
		if r.kingdom == GameManager.player_kingdom or r.character == null:
			continue
		if r.at_war and r.affinity >= RelationsData.PEACE_MIN_AFFINITY:
			peace.append(r)
		elif noble and not r.at_war and not r.allied and r.affinity <= TRIBUTE_DEMAND_AFFINITY and _kingdom_strength(r.kingdom) > mine:
			tribute.append(r)
		elif noble and not r.at_war and not r.allied and r.affinity >= ALLY_OFFER_AFFINITY and not RelationsData.refuses_dishonored(r):
			alliance.append(r)
	if not peace.is_empty():
		var r: Relationship = peace.pick_random()
		return _peace_offer(r, _kingdom_strength(r.kingdom) < mine)
	if not tribute.is_empty():
		return _tribute_demand(tribute.pick_random())
	if not alliance.is_empty():
		return _alliance_offer(alliance.pick_random())
	return {}

func _event(r: Relationship, kind: String, title: String, text: String, options: Array) -> Dictionary:
	return {"title": title, "text": text, "speaker": r.person_name, "target": r.person_name,
		"options": options, EVENT_KEY: {"kind": kind, "lord": r.person_name}}

func _peace_offer(r: Relationship, they_pay: bool) -> Dictionary:
	var text := "Un heraldo de %s trae una propuesta: poner fin a la guerra. " % r.person_name
	var accept := {"label": "Aceptar la paz", "treaty": "peace", "effects": {"affinity": RelationsData.PEACE_AFFINITY}}
	if they_pay:
		text += "Su reino está agotado: ofrece %d de oro como compensación." % PEACE_GOLD
		accept.effects["gold"] = PEACE_GOLD
		accept["result"] = "Firmas la paz y cobras la compensación."
	else:
		text += "Pide %d de oro como tributo para retirar sus ejércitos." % PEACE_GOLD
		accept.effects["gold"] = -PEACE_GOLD
		accept["requires"] = {"gold": PEACE_GOLD}
		accept["result"] = "Pagas el tributo y firmas la paz."
	return _event(r, "peace", "Propuesta de paz", text, [accept,
		{"label": "Seguir la guerra", "treaty": "reject", "effects": {"affinity": REJECT_AFFINITY}, "result": "Despides al heraldo: la guerra sigue."}])

func _tribute_demand(r: Relationship) -> Dictionary:
	var text := "%s, cuyo reino es más poderoso que el tuyo, exige %d de oro como muestra de respeto. Si te niegas, lo tomará como un insulto." % [r.person_name, TRIBUTE_GOLD]
	return _event(r, "tribute", "Exigencia de tributo", text, [
		{"label": "Pagar el tributo", "treaty": "tribute_paid", "requires": {"gold": TRIBUTE_GOLD}, "effects": {"gold": -TRIBUTE_GOLD, "affinity": ACCEPT_AFFINITY, "honor": -2}, "result": "Pagas. Se calma, por ahora."},
		{"label": "Negarte", "treaty": "tribute_refused", "effects": {"affinity": REJECT_AFFINITY, "honor": 2}, "result": "Te niegas con orgullo. %s te declara la guerra." % r.person_name}])

func _alliance_offer(r: Relationship) -> Dictionary:
	var text := "%s te propone una alianza: sus ejércitos no atacarán tus castillos y espera lo mismo de ti." % r.person_name
	return _event(r, "alliance", "Oferta de alianza", text, [
		{"label": "Aceptar la alianza", "treaty": "alliance", "effects": {"affinity": ACCEPT_AFFINITY}, "result": "Sellas la alianza con %s." % r.person_name},
		{"label": "Rechazarla", "treaty": "reject", "effects": {"affinity": REJECT_AFFINITY}, "result": "Declinas con cortesía."}])

## Aplica el tratado elegido (los efectos de oro, honor y afinidad los aplica EventCatalog).
func _on_option_chosen(event: Dictionary, option: Dictionary) -> void:
	if not event.has(EVENT_KEY) or not option.has("treaty"):
		return
	var r := RelationsData.get_relation(str(event[EVENT_KEY].get("lord", "")))
	if r == null:
		return
	match str(option.treaty):
		"peace":
			r.at_war = false
		"alliance":
			r.allied = true
		"tribute_refused":
			r.at_war = true
			r.allied = false
	RelationsData.relations_changed.emit()

func save_state() -> Dictionary:
	return {"last_offer_month": last_offer_month}

func load_state(data: Dictionary) -> void:
	last_offer_month = int(data.get("last_offer_month", -100))
