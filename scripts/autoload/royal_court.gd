extends Node
# Autoload "RoyalCourt": audiencias con el gobernante de un reino (cualquier jugador puede pedirlas).
#   - En persona (en su castillo, 1 acción) o por carta (desde cualquier sitio, 2 acciones, menos probable).
#   - Te recibe según tu afinidad con él, tu renombre, tu rango y la suerte. Si te rechaza, esperas REJECT_COOLDOWN meses.
#   - En la asamblea: un gesto para ganarte su favor (respetos, presente, halago) y UN favor
#     (oro, tropas, perdón, clemencia, un cargo con rentas, una boda con su casa o una alianza).
# Depende de GameManager, RelationsData, MapData y TravelData (no al revés).

const PERSON_BASE := 0.35
const LETTER_BASE := 0.2
const LETTER_ACTIONS := 2
const AFFINITY_CHANCE := 0.005        # por punto de afinidad
const RENOWN_CHANCE := 0.004          # por punto de renombre
const RANK_CHANCE := 0.03             # por rango
const REJECT_COOLDOWN := 3
const RESPECT_BASE := 6
const GIFT_COST := 50
const GIFT_AFFINITY := 8
const FLATTER_GAIN := 10
const FLATTER_LOSS := -5
# Favores: [afinidad mínima, coste en afinidad]
const FAVOR_GOLD := [10, -8]
const FAVOR_TROOPS := [20, -10]
const FAVOR_PARDON_COST := 60        # oro para que perdone una ofensa (si te tiene en poca estima)
const FAVOR_CLEMENCY := [30, -10]     # sube tu honor si eres un deshonrado
const FAVOR_POST := [60, -15]         # un cargo en la corte: rentas mensuales
const POST_RENT := 20
const FAVOR_MARRIAGE := 50
const FAVOR_ALLIANCE := 40

var _last_month := {}      # gobernante -> mes de la última audiencia (una al mes)
var _rejected := {}        # gobernante -> mes del último rechazo
var posts := []            # cargos ya concedidos (nombres de gobernantes): uno por corte

func _ready() -> void:
	GameManager.game_started.connect(func(_c: Character): reset())

func reset() -> void:
	_last_month.clear()
	_rejected.clear()
	posts.clear()

## Gobernante de un reino: su rey o reina; si no hay, el señor con más castillos.
func ruler_of(kingdom: int) -> Relationship:
	var best: Relationship = null
	var best_n := -1
	for r: Relationship in RelationsData.lords():
		if r.kingdom != kingdom and not _owns_in(r, kingdom):
			continue
		var crowned := r.person_name.begins_with("Rey ") or r.person_name.begins_with("Reina ")
		var n := _castles_of(r.person_name) + (100 if crowned else 0)
		if n > best_n:
			best_n = n
			best = r
	return best

func _owns_in(r: Relationship, kingdom: int) -> bool:
	for c: Castle in MapData.castles:
		if c.owner_name == r.person_name and c.kingdom == kingdom:
			return true
	return false

func _castles_of(person_name: String) -> int:
	var n := 0
	for c: Castle in MapData.castles:
		if c.owner_name == person_name:
			n += 1
	return n

func ruler_castle(r: Relationship) -> Castle:
	for c: Castle in MapData.castles:
		if r != null and c.owner_name == r.person_name:
			return c
	return null

func in_person(r: Relationship) -> bool:
	var c := ruler_castle(r)
	return c != null and TravelData.is_at(c.castle_id)

## Por qué no puedes pedir la audiencia ("" si puedes). by_letter: por carta.
func blocker(r: Relationship, by_letter: bool) -> String:
	var p: Character = GameManager.player_character
	if p == null or r == null:
		return "Este reino no tiene gobernante."
	if r.person_name == p.full_name():
		return "Eres tú quien gobierna."
	if r.at_war:
		return "Estáis en guerra: no te recibirá."
	var now := GameManager.months_elapsed()
	if int(_last_month.get(r.person_name, -100)) == now:
		return "Ya pediste audiencia este mes."
	if now - int(_rejected.get(r.person_name, -100)) < REJECT_COOLDOWN:
		return "Te rechazó hace poco: espera unos meses."
	if not by_letter and not in_person(r):
		return "Para ir en persona viaja a su castillo (o escríbele)."
	if GameManager.actions_remaining < (LETTER_ACTIONS if by_letter else 1):
		return "No te quedan acciones suficientes."
	return ""

func acceptance_chance(r: Relationship, by_letter: bool) -> float:
	var p: Character = GameManager.player_character
	var c := (LETTER_BASE if by_letter else PERSON_BASE) + r.affinity * AFFINITY_CHANCE + p.renown() * RENOWN_CHANCE + p.rank() * RANK_CHANCE
	return clampf(c + SkillEffects.event_luck(p), 0.05, 0.95)

## Pide la audiencia. Devuelve {ok, text}.
func request(r: Relationship, by_letter: bool) -> Dictionary:
	var reason := blocker(r, by_letter)
	if not reason.is_empty():
		return {"ok": false, "text": reason}
	for i in (LETTER_ACTIONS if by_letter else 1):
		GameManager.consume_action()
	var now := GameManager.months_elapsed()
	_last_month[r.person_name] = now
	if randf() >= acceptance_chance(r, by_letter):
		_rejected[r.person_name] = now
		return {"ok": false, "text": "%s %s" % [r.person_name, "no responde a tu carta." if by_letter else "no tiene tiempo para ti: su chambelán te despide en la puerta."]}
	return {"ok": true, "text": "%s te recibe%s." % [r.person_name, " (te cita por carta)" if by_letter else " en su salón"]}

# --- Gestos para ganarte su favor ---

func respects(r: Relationship) -> String:
	var gain := RESPECT_BASE + GameManager.player_character.charisma / 3
	r.adjust(gain)
	RelationsData.relations_changed.emit()
	return "Presentas tus respetos a %s. Afinidad %+d." % [r.person_name, gain]

func gift_blocker() -> String:
	return "" if GameManager.player_character.gold >= GIFT_COST else "Necesitas %d de oro." % GIFT_COST

func gift(r: Relationship) -> String:
	var p: Character = GameManager.player_character
	p.gold -= GIFT_COST
	var gain := GIFT_AFFINITY + p.charisma / 4
	r.adjust(gain)
	RelationsData.relations_changed.emit()
	return "Le ofreces un presente de %d de oro. Afinidad %+d." % [GIFT_COST, gain]

func flatter(r: Relationship) -> String:
	var p: Character = GameManager.player_character
	var ok := randf() < clampf(0.35 + p.charisma * 0.025, 0.1, 0.9)
	r.adjust(FLATTER_GAIN if ok else FLATTER_LOSS)
	RelationsData.relations_changed.emit()
	return ("Tus palabras le agradan. Afinidad %+d." % FLATTER_GAIN) if ok else ("Le suenan a adulación. Afinidad %+d." % FLATTER_LOSS)

# --- Favores (uno por audiencia) ---
# Cada uno: [nombre, ayuda, motivo si no se puede ("" = se puede), acción].

func favors(r: Relationship) -> Array:
	var p: Character = GameManager.player_character
	var out := []
	var gold_amount := 40 + maxi(0, r.affinity) * 2
	out.append(["Pedir oro", "Unos %d de oro para tu casa (afinidad %d)." % [gold_amount, FAVOR_GOLD[1]],
		_need(r, FAVOR_GOLD[0]), func(): return _favor_gold(r, gold_amount)])
	var home: Castle = MapData.get_castle_by_id(GameManager.home_castle_id)
	var troops := 10 + maxi(0, r.affinity) / 5
	out.append(["Pedir tropas", "%d soldados para tu castillo (afinidad %d)." % [troops, FAVOR_TROOPS[1]],
		_need(r, FAVOR_TROOPS[0]) if home != null else "No tienes castillo donde alojarlos.", func(): return _favor_troops(r, home, troops)])
	out.append(["Pedir perdón", "Olvida tus ofensas: afinidad hasta 0 y sin rencor, a cambio de %d de oro." % FAVOR_PARDON_COST,
		"" if r.affinity < 0 or r.grudge > 0 else "No tiene nada que perdonarte.",
		func(): return _favor_pardon(r)])
	out.append(["Pedir clemencia", "Que te rehabilite ante la corte: honor +10 (afinidad %d)." % FAVOR_CLEMENCY[1],
		("" if p.honor < 0 else "Tu honor no necesita clemencia.") if r.affinity >= FAVOR_CLEMENCY[0] else _need(r, FAVOR_CLEMENCY[0]),
		func(): return _favor_clemency(r)])
	out.append(["Pedir un cargo en la corte", "Un puesto que te rinde %d de oro al mes (afinidad %d)." % [POST_RENT, FAVOR_POST[1]],
		("Ya tienes un cargo en esta corte." if r.person_name in posts else _need(r, FAVOR_POST[0])),
		func(): return _favor_post(r)])
	var wed := _need(r, FAVOR_MARRIAGE)
	if wed.is_empty():
		wed = RelationsData.spouse_cap_blocker()
	if wed.is_empty() and RelationsData.refuses_dishonored(r):
		wed = "No casaría a los suyos con alguien sin honor."
	out.append(["Pedir la mano de alguien de su casa", "Boda política con su familia (sin dote).", wed,
		func(): return RelationsData.arrange_political_marriage(r.person_name)])
	if r.kingdom != GameManager.player_kingdom:
		out.append(["Proponer una alianza", "Sus ejércitos no atacarán tus castillos.",
			"Ya sois aliados." if r.allied else _need(r, FAVOR_ALLIANCE),
			func(): return _favor_alliance(r)])
	return out

func _need(r: Relationship, minimum: int) -> String:
	return "" if r.affinity >= minimum else "Necesitas %d de afinidad (tienes %d)." % [minimum, r.affinity]

func _favor_gold(r: Relationship, amount: int) -> String:
	GameManager.player_character.gold += amount
	r.adjust(FAVOR_GOLD[1])
	RelationsData.relations_changed.emit()
	return "%s te concede %d de oro." % [r.person_name, amount]

func _favor_troops(r: Relationship, home: Castle, troops: int) -> String:
	home.garrison_size += troops
	r.adjust(FAVOR_TROOPS[1])
	RelationsData.relations_changed.emit()
	return "%s envía %d soldados a %s." % [r.person_name, troops, home.castle_name]

func _favor_pardon(r: Relationship) -> String:
	var p: Character = GameManager.player_character
	if p.gold < FAVOR_PARDON_COST:
		return "No llevas los %d de oro que pide para olvidar la ofensa." % FAVOR_PARDON_COST
	p.gold -= FAVOR_PARDON_COST
	r.affinity = maxi(r.affinity, 0)
	r.adjust_grudge(-100)
	RelationsData.relations_changed.emit()
	return "%s acepta tu oro y tus disculpas: lo pasado, pasado está." % r.person_name

func _favor_clemency(r: Relationship) -> String:
	var p: Character = GameManager.player_character
	p.honor = clampi(p.honor + 10, Character.HONOR_MIN, Character.HONOR_MAX)
	r.adjust(FAVOR_CLEMENCY[1])
	RelationsData.relations_changed.emit()
	return "%s te rehabilita ante su corte. Honor +10." % r.person_name

func _favor_post(r: Relationship) -> String:
	var p: Character = GameManager.player_character
	p.rent += POST_RENT
	posts.append(r.person_name)
	r.adjust(FAVOR_POST[1])
	RelationsData.relations_changed.emit()
	return "%s te nombra consejero de su corte: rentas de %d de oro al mes." % [r.person_name, POST_RENT]

func _favor_alliance(r: Relationship) -> String:
	if RelationsData.refuses_dishonored(r):
		return "%s no pacta con alguien sin honor." % r.person_name
	r.allied = true
	RelationsData.relations_changed.emit()
	return "%s sella una alianza contigo." % r.person_name

func save_state() -> Dictionary:
	return {"last": _last_month.duplicate(), "rejected": _rejected.duplicate(), "posts": posts.duplicate()}

func load_state(data: Dictionary) -> void:
	reset()
	for k in data.get("last", {}):
		_last_month[str(k)] = int(data.last[k])
	for k in data.get("rejected", {}):
		_rejected[str(k)] = int(data.rejected[k])
	for k in data.get("posts", []):
		posts.append(str(k))
