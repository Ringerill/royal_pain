extends Node
# Autoload "Career" (rediseño v2, fase 8): rango por hitos, soldados, gobierno, alianzas con plazo,
# ejércitos enemigos y piratas.
#   Rangos (RankCatalog): inafiliado → trabajador → soldado → caballero → noble → rey. Cada ascenso
#   pide hitos (encargos, jefes, fama…) y se pide en audiencia en el trono de una capital.
#   Soldados: hasta RankCatalog.max_soldiers. Por debajo de noble, tu comandante te los asigna según
#   tu fama; nobles y reyes los reclutan y les pagan cada mes.
#   Alianzas: duran ALLIANCE_MONTHS (la mitad si eres Conquistador); al vencer, se rompen.
#   Mecánicas de vía con poder: Purga (Tirano) y Ultimátum (Conquistador).

signal changed

const R := RankCatalog.Rank
# Hitos de cada ascenso (al rango indicado).
const MILESTONES := {
	R.TRABAJADOR: {"contracts": 3, "fame": 0, "bosses": 0, "text": "3 encargos cumplidos"},
	R.SOLDADO: {"contracts": 6, "fame": 5, "bosses": 0, "wins": 5, "text": "6 encargos, 5 victorias y fama 5"},
	R.CABALLERO: {"contracts": 12, "fame": 20, "bosses": 2, "wins": 10, "text": "12 encargos, 2 jefes, 10 victorias y fama 20"},
	R.NOBLE: {"contracts": 20, "fame": 40, "bosses": 5, "wins": 20, "gold": 2000, "text": "20 encargos, 5 jefes, 20 victorias, fama 40 y 2000 de oro para el título"},
	R.REY: {"text": "Reclamar el trono (Relaciones) o conquistar la capital de tu reino"},
}
const ROLE_OF := {R.INAFILIADO: Character.Role.INAFILIADO, R.TRABAJADOR: Character.Role.CAMPESINO, R.SOLDADO: Character.Role.SOLDADO,
	R.CABALLERO: Character.Role.CABALLERO, R.NOBLE: Character.Role.NOBLEZA_BAJA, R.REY: Character.Role.REGENTE}
const RECRUIT_COST := 12
const UPKEEP := 1                 # oro por soldado y mes (nobles y reyes)
const ALLIANCE_MONTHS := 12
const PURGE_FAME := -10
const ULTIMATUM_SOLDIERS := 60    # soldados para que un castillo vecino se rinda sin luchar
const PIRATE_CHANCE := 0.35
const ARMY_SOLDIER_LOSS := 0.3

var wins := 0
var pending_pirates := false

func _ready() -> void:
	GameManager.game_started.connect(func(_c): reset())
	GameManager.turn_advanced.connect(func(_m: int, _y: int): monthly())

func reset() -> void:
	wins = 0
	pending_pirates = false

func player() -> Character:
	return GameManager.player_character

func rank() -> int:
	return player().rank_v2()

func note_win() -> void:
	wins += 1

# --- Ascensos ---

func next_rank() -> int:
	return rank() + 1 if rank() < R.REY else -1

## Por qué no puedes ascender ("" si puedes).
func promotion_blocker() -> String:
	var nr := next_rank()
	if nr < 0:
		return "Ya eres rey."
	if nr == R.REY:
		return "La corona no se pide: se reclama o se conquista."
	var m: Dictionary = MILESTONES[nr]
	var p := player()
	var miss := []
	if int(ViaData.counts.get("contracts", 0)) < int(m.get("contracts", 0)):
		miss.append("encargos %d/%d" % [int(ViaData.counts.contracts), int(m.contracts)])
	if int(ViaData.counts.get("bosses", 0)) < int(m.get("bosses", 0)):
		miss.append("jefes %d/%d" % [int(ViaData.counts.bosses), int(m.bosses)])
	if wins < int(m.get("wins", 0)):
		miss.append("victorias %d/%d" % [wins, int(m.wins)])
	if p.fame < int(m.get("fame", 0)):
		miss.append("fama %d/%d" % [p.fame, int(m.fame)])
	if p.gold < int(m.get("gold", 0)):
		miss.append("oro %d/%d" % [p.gold, int(m.gold)])
	if p.via == ViaCatalog.Via.HUMILDE and nr >= R.NOBLE:
		return "Tu vía (Humilde) no acepta cargos de nobleza."
	if not miss.is_empty():
		return "Te falta: " + ", ".join(miss) + "."
	return ""

func promote() -> String:
	var why := promotion_blocker()
	if not why.is_empty():
		return why
	var nr := next_rank()
	var p := player()
	p.gold -= int(MILESTONES[nr].get("gold", 0))
	p.status_rank = nr
	p.role = ROLE_OF.get(nr, p.role)
	assign_soldiers()
	var t := "¡Asciendes a %s! Puedes llevar hasta %d soldados." % [RankCatalog.name_of(nr), max_soldiers()]
	WorldEvents.record(t, "", true)
	changed.emit()
	return t

# --- Soldados ---

func max_soldiers() -> int:
	return RankCatalog.max_soldiers(rank(), player().leadership)

func pays_soldiers() -> bool:
	return rank() in RankCatalog.PAYS_SOLDIERS

## Por debajo de noble, tu comandante te asigna soldados según tu fama.
func assign_soldiers() -> void:
	if pays_soldiers():
		return
	var share := clampf(0.5 + player().fame / 100.0, 0.25, 1.0)
	player().soldiers = maxi(player().soldiers, roundi(max_soldiers() * share))

func recruit_blocker(n: int) -> String:
	if not pays_soldiers():
		return "Solo nobles y reyes reclutan: a ti te asigna soldados tu comandante."
	if player().soldiers + n > max_soldiers():
		return "Tu rango no da para más (%d de %d)." % [player().soldiers, max_soldiers()]
	if player().gold < n * RECRUIT_COST:
		return "Necesitas %d de oro." % (n * RECRUIT_COST)
	return ""

func recruit(n: int) -> String:
	var why := recruit_blocker(n)
	if not why.is_empty():
		return why
	player().gold -= n * RECRUIT_COST
	player().soldiers += n
	changed.emit()
	return "Reclutas %d soldados. Ya tienes %d." % [n, player().soldiers]

func monthly() -> void:
	var p := player()
	if p == null:
		return
	if pays_soldiers() and p.soldiers > 0:
		var cost := p.soldiers * UPKEEP
		if p.gold >= cost:
			p.gold -= cost
		else:
			var lost := p.soldiers - p.gold / maxi(1, UPKEEP)
			p.soldiers -= lost
			p.gold = 0
			WorldEvents.notify("Soldados sin paga", "No tienes oro para pagar: %d soldados se marchan." % lost)
	_check_alliances()

# --- Alianzas con plazo ---

func alliance_months() -> int:
	return roundi(ALLIANCE_MONTHS * (0.5 if player().via == ViaCatalog.Via.CONQUISTADOR else 1.0))

func _check_alliances() -> void:
	var now := GameManager.months_elapsed()
	for r: Relationship in RelationsData.lords():
		if not r.allied:
			r.allied_until = -1
			continue
		if r.allied_until < 0:
			r.allied_until = now + alliance_months()
		elif now >= r.allied_until:
			r.allied = false
			r.allied_until = -1
			WorldEvents.notify("Alianza vencida", "Se acaba el plazo de tu alianza con %s." % r.person_name)

# --- Gobierno y mecánicas de poder ---

## Castillos que gobiernas.
func governed() -> Array:
	var out := []
	for c: Castle in MapData.castles:
		if c.owner_name == player().full_name() or c.owner_name == player().first_name:
			out.append(c)
	return out

func purge_targets() -> Array:
	return RelationsData.lords().filter(func(r: Relationship) -> bool:
		return r.kingdom == GameManager.player_kingdom and r.character != null and r.person_name != player().full_name())

## Tirano: elimina a un noble de tu reino (terror).
func purge(r: Relationship) -> String:
	if rank() < R.NOBLE:
		return "Solo un noble puede purgar a otros nobles."
	RelationsData.relations.erase(r)
	player().add_fame(PURGE_FAME)
	var extra := ViaData.record("execute")
	ViaData.check_goal()
	return "%s desaparece una noche y nadie pregunta. Fama %d.%s" % [r.person_name, PURGE_FAME, ("\n" + extra) if not extra.is_empty() else ""]

## Conquistador: exige la rendición de un castillo de un reino vecino.
func ultimatum(c: Castle) -> String:
	if rank() < R.CABALLERO:
		return "Nadie se rinde ante quien no tiene rango."
	var old := c.kingdom
	if player().soldiers >= ULTIMATUM_SOLDIERS or randf() < float(player().soldiers) / ULTIMATUM_SOLDIERS:
		c.kingdom = GameManager.player_kingdom
		RelationsData.on_castle_taken(c, old, GameManager.player_kingdom)
		var extra := ViaData.record("boss")
		ViaData.check_goal()
		return "%s se rinde sin luchar ante tus %d soldados.%s" % [c.castle_name, player().soldiers, ("\n" + extra) if not extra.is_empty() else ""]
	return "%s se niega. Tendrás que tomarlo por la fuerza." % c.castle_name

# --- Mar: piratas ---

func roll_pirates() -> void:
	pending_pirates = randf() < PIRATE_CHANCE

func pirate_fight() -> Dictionary:
	pending_pirates = false
	return {"type": "duel", "no_rival": true, "context": "camino", "via_deed": ["rescue", "rescues"], "captive": "Capitán pirata",
		"foe": {"name": "Capitán pirata", "role": Character.Role.SOLDADO, "power": 1, "personality": "CRUEL"},
		"win": {"effects": {"gold": 80}, "result": "Los piratas saltan por la borda."},
		"lose": {"effects": {}, "result": "Os roban la carga y os dejan en el puerto."}}

# --- Ejércitos ---

## Combate contra un ejército enemigo en el camino (tus soldados luchan contigo).
func army_fight() -> Dictionary:
	return {"type": "duel", "no_rival": true, "context": "escaramuza", "via_deed": ["boss", "bosses"],
		"foe": {"name": "Comandante enemigo", "role": Character.Role.CAPITAN, "power": 2, "personality": "VALIENTE"},
		"win": {"effects": {"fame": 5, "gold": 100}, "result": "El ejército enemigo se dispersa."},
		"lose": {"effects": {}, "result": "Os retiráis y perdéis parte de la tropa."}}

func lose_soldiers_to_army() -> void:
	player().soldiers = roundi(player().soldiers * (1.0 - ARMY_SOLDIER_LOSS))

func save_state() -> Dictionary:
	return {"wins": wins, "pirates": pending_pirates}

func load_state(d: Dictionary) -> void:
	reset()
	wins = int(d.get("wins", 0))
	pending_pirates = bool(d.get("pirates", false))
