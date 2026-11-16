extends Node
# Autoload "ViaData" (rediseño v2, fase 7): la vía del jugador en marcha.
#   - Contadores de hazañas (rescates, recompensas, saqueos, encargos, jefes…) y la META de su vía
#     (ViaCatalog.DATA[v].goal): al cumplirla, victoria (se puede seguir jugando).
#   - Actos: cada hecho suma a una o varias vías (deeds). Si otra vía supera a la tuya por
#     CHANGE_MARGIN, cambias de vía con aviso.
#   - Mecánicas de vía como acciones (las puede usar cualquiera; su vía las potencia): faenas
#     (Humilde), limosna (Benevolente), extorsión (Villano), sigilo (Reservado, pasivo),
#     colección (Ambicioso, pasivo), carteles de «se busca» (Justiciero, en el tablón).
#   - Prisioneros: tras vencer a bandidos o jefes, queda uno pendiente: reclutar, rescate,
#     liberar, ejecutar o esclavizar.

signal changed

const V := ViaCatalog.Via
const CHANGE_MARGIN := 15
const COUNTERS := ["contracts", "bosses", "rescues", "bounties", "raids", "extortions", "chores", "alms"]
# Hecho -> {vía: puntos}
const DEEDS := {
	"contract": {V.HUMILDE: 1},
	"chore": {V.HUMILDE: 2},
	"alms": {V.BENEVOLENTE: 2},
	"rescue": {V.BENEVOLENTE: 3, V.JUSTICIERO: 1},
	"bounty": {V.JUSTICIERO: 3},
	"boss": {V.JUSTICIERO: 1, V.CONQUISTADOR: 1},
	"raid": {V.VILLANO: 4},
	"extort": {V.VILLANO: 3, V.TIRANO: 1},
	"free": {V.BENEVOLENTE: 3},
	"execute": {V.TIRANO: 3, V.JUSTICIERO: 1},
	"enslave": {V.VILLANO: 3, V.TIRANO: 2},
	"recruit": {V.CONQUISTADOR: 2, V.AMBICIOSO: 1},
	"ransom": {V.AMBICIOSO: 2},
	"quiet": {V.RESERVADO: 1},
}
# Mecánicas
const CHORE_HOURS := 4.0
const CHORE_GOLD := 15
const ALMS_GOLD := 30
const ALMS_FAME := 2
const EXTORT_GOLD := 60
const EXTORT_FAME := -3
const VIA_BOOST := 2.0           # la vía propia duplica el efecto de su mecánica
const STEALTH_SKIP := 0.5        # Reservado: probabilidad de evitar un encuentro hostil
# Prisioneros
const RANSOM_GOLD := 80
const ENSLAVE_GOLD := 120
const ENSLAVE_FAME := -6
const EXECUTE_FAME := -2
const FREE_FAME := 2
const RECRUIT_SOLDIERS := 3
const PRISONER_CHANCE := 0.6
const COLLECTION_TYPES := 5

var counts := {}
var deeds := {}
var collection := {}          # nombres de armas que has tenido (Ambicioso)
var collection_bonus := {}    # tipo -> true (ya dio su +1)
var goal_reached := false
var pending_prisoner := ""
var _last_via := -1

func _ready() -> void:
	GameManager.game_started.connect(func(_c): reset())

func reset() -> void:
	counts.clear()
	for k in COUNTERS:
		counts[k] = 0
	deeds.clear()
	collection.clear()
	collection_bonus.clear()
	goal_reached = false
	pending_prisoner = ""

func player() -> Character:
	return GameManager.player_character

func via() -> int:
	var p := player()
	return p.via if p != null and p.via >= 0 else V.HUMILDE

func boost(v: int) -> float:
	return VIA_BOOST if via() == v else 1.0

# --- Hechos ---

## Registra un hecho: suma contadores y puntos de vía, y comprueba cambio de vía y meta.
func record(deed: String, counter: String = "", n: int = 1) -> String:
	if not counter.is_empty():
		counts[counter] = int(counts.get(counter, 0)) + n
	for v in DEEDS.get(deed, {}):
		deeds[v] = int(deeds.get(v, 0)) + int(DEEDS[deed][v]) * n
	var out := _check_change()
	var g := check_goal()
	changed.emit()
	return (out + ("\n" + g if not g.is_empty() else "")).strip_edges()

func _check_change() -> String:
	var p := player()
	if p == null or p.via < 0:
		return ""
	var mine := int(deeds.get(p.via, 0))
	var best := p.via
	for v in deeds:
		if int(deeds[v]) >= mine + CHANGE_MARGIN and int(deeds[v]) > int(deeds.get(best, 0)):
			best = int(v)
	if best == p.via:
		return ""
	var old := ViaCatalog.name_of(p.via)
	p.via = best
	p.alignment = ViaCatalog.TO_ALIGNMENT.get(best, p.alignment)
	deeds[best] = int(deeds[best])   # se queda como referencia
	var t := "Tus actos hablan por ti: dejas la vía %s y sigues la vía %s." % [old, ViaCatalog.name_of(best)]
	WorldEvents.notify("Cambio de vía", t)
	return t

# --- Metas ---

## Progreso de la meta: [actual, objetivo, texto].
func progress(v: int = -1) -> Array:
	if v < 0:
		v = via()
	var p := player()
	match v:
		V.TIRANO:
			return [0 if _royals_left() == 0 else 1, 1, "Cargos de realeza rivales en tu reino: %d" % _royals_left()]
		V.CONQUISTADOR:
			return [_capitals(), 6, "Capitales bajo tu reino: %d de 6" % _capitals()]
		V.HUMILDE:
			var ok := int(counts.bosses) >= 5 and int(counts.contracts) >= 30 and p.rank_v2() < RankCatalog.Rank.NOBLE
			return [1 if ok else 0, 1, "Jefes %d/5 · encargos %d/30 · sin cargo noble" % [int(counts.bosses), int(counts.contracts)]]
		V.BENEVOLENTE:
			return [int(counts.rescues), 15, "Grupos hostiles derrotados: %d de 15" % int(counts.rescues)]
		V.RESERVADO:
			var ok2: bool = p.rank_v2() >= RankCatalog.Rank.CABALLERO and absi(p.fame) <= 20
			return [1 if ok2 else 0, 1, "Caballero con fama entre −20 y 20 (rango %s, fama %d)" % [RankCatalog.name_of(p.rank_v2()), p.fame]]
		V.AMBICIOSO:
			var types := _collection_types()
			var ok3 := p.gold >= 20000 and types >= COLLECTION_TYPES
			return [1 if ok3 else 0, 1, "Oro %d/20000 · colección %d/%d tipos" % [p.gold, types, COLLECTION_TYPES]]
		V.JUSTICIERO:
			return [int(counts.bounties), 10, "Forajidos y tiranos vencidos: %d de 10" % int(counts.bounties)]
		V.VILLANO:
			return [int(counts.raids), 10, "Saqueos: %d de 10" % int(counts.raids)]
	return [0, 1, ""]

func check_goal() -> String:
	if goal_reached or player() == null:
		return ""
	var pr := progress()
	if int(pr[0]) < int(pr[1]):
		return ""
	goal_reached = true
	GameManager.victory_achieved = true
	var t := "¡Meta de tu vía cumplida! %s. Has ganado la partida (puedes seguir jugando)." % ViaCatalog.DATA[via()].goal
	WorldEvents.record(t, "", true)
	WorldEvents.notify("¡Victoria!", t)
	return t

func _capitals() -> int:
	var n := 0
	for c: Castle in MapData.castles:
		if c.kingdom == GameManager.player_kingdom and Journey.capital_castle(c.original_kingdom) == c and c.original_kingdom != GameManager.player_kingdom:
			n += 1
	return n + 1

func _royals_left() -> int:
	var n := 0
	for r: Relationship in RelationsData.lords():
		if r.character != null and r.kingdom == GameManager.player_kingdom and r.character.rank_v2() >= RankCatalog.Rank.NOBLE:
			n += 1
	return n

# --- Mecánicas ---

func chore() -> String:
	var gold := roundi(CHORE_GOLD * boost(V.HUMILDE))
	Journey.wait_hours(CHORE_HOURS)
	player().gold += gold
	player().spend_energy(10)
	var t := "Echas una mano en lo que hace falta. +%d de oro." % gold
	var extra := record("chore", "chores")
	return t + ("\n" + extra if not extra.is_empty() else "")

func alms() -> String:
	if player().gold < ALMS_GOLD:
		return "No te llega el oro."
	player().gold -= ALMS_GOLD
	var fame := roundi(ALMS_FAME * boost(V.BENEVOLENTE))
	player().add_fame(fame)
	var extra := record("alms", "alms")
	return "Repartes limosna entre los necesitados. Fama %+d.%s" % [fame, ("\n" + extra) if not extra.is_empty() else ""]

func extort() -> String:
	var gold := roundi(EXTORT_GOLD * boost(V.VILLANO))
	player().gold += gold
	player().add_fame(EXTORT_FAME)
	var extra := record("extort", "extortions")
	return "Los comerciantes pagan por su «protección». +%d de oro, fama %d.%s" % [gold, EXTORT_FAME, ("\n" + extra) if not extra.is_empty() else ""]

## Reservado: a veces evitas un encuentro hostil sin que te vean.
func stealth_avoids() -> bool:
	var chance := STEALTH_SKIP * (1.0 if via() == V.RESERVADO else 0.3)
	if randf() < chance:
		record("quiet")
		return true
	return false

## Ambicioso: apunta un arma en la colección; cada tipo completo (sus 10 armas) da +1 a un atributo.
func note_weapon(weapon_name: String) -> String:
	if not GearCatalog.is_gear(weapon_name) or collection.has(weapon_name):
		return ""
	collection[weapon_name] = true
	var t := str(GearCatalog.entry(weapon_name).gear.type)
	if collection_bonus.has(t) or not t in GearCatalog.WEAPON_TYPES:
		return ""
	for i in 10:
		if not collection.has(GearCatalog.weapon_name(t, i + 1)):
			return ""
	collection_bonus[t] = true
	player().combat = mini(20, player().combat + 1)
	return "¡Colección de %s completa! Ataque +1." % GearCatalog.WEAPON_TYPE_NAMES[t]

func _collection_types() -> int:
	var n := 0
	for t in GearCatalog.WEAPON_TYPES:
		for i in 10:
			if collection.has(GearCatalog.weapon_name(t, i + 1)):
				n += 1
				break
	return n

# --- Prisioneros ---

func maybe_capture(who: String) -> void:
	if randf() < PRISONER_CHANCE:
		pending_prisoner = who

func prisoner_options() -> Array:
	return [["reclutar", "Reclutarlo (+%d soldados)" % RECRUIT_SOLDIERS], ["rescate", "Pedir rescate (+%d de oro)" % RANSOM_GOLD],
		["liberar", "Liberarlo (fama +%d)" % FREE_FAME], ["ejecutar", "Ejecutarlo (fama %d)" % EXECUTE_FAME],
		["esclavizar", "Venderlo como esclavo (+%d de oro, fama %d)" % [ENSLAVE_GOLD, ENSLAVE_FAME]]]

func resolve_prisoner(choice: String) -> String:
	var who := pending_prisoner
	pending_prisoner = ""
	var p := player()
	var t := ""
	match choice:
		"reclutar":
			var cap := RankCatalog.max_soldiers(p.rank_v2(), p.leadership)
			p.soldiers = mini(maxi(cap, p.soldiers), p.soldiers + RECRUIT_SOLDIERS)
			t = "%s y los suyos se unen a ti. Soldados: %d." % [who, p.soldiers]
			t += _tail(record("recruit"))
		"rescate":
			p.gold += RANSOM_GOLD
			t = "Su gente paga %d de oro por %s." % [RANSOM_GOLD, who] + _tail(record("ransom"))
		"liberar":
			p.add_fame(FREE_FAME)
			t = "Liberas a %s, que se marcha agradecido." % who + _tail(record("free"))
		"ejecutar":
			p.add_fame(EXECUTE_FAME)
			t = "%s no volverá a asaltar a nadie." % who + _tail(record("execute"))
		"esclavizar":
			p.gold += ENSLAVE_GOLD
			p.add_fame(ENSLAVE_FAME)
			t = "Vendes a %s a unos tratantes. +%d de oro." % [who, ENSLAVE_GOLD] + _tail(record("enslave"))
	return t

func _tail(extra: String) -> String:
	return ("\n" + extra) if not extra.is_empty() else ""

# --- Guardado ---

func save_state() -> Dictionary:
	return {"counts": counts.duplicate(), "deeds": deeds.duplicate(), "collection": collection.keys(),
		"bonus": collection_bonus.keys(), "goal": goal_reached, "prisoner": pending_prisoner}

func load_state(d: Dictionary) -> void:
	reset()
	for k in d.get("counts", {}):
		counts[str(k)] = int(d.counts[k])
	for k in d.get("deeds", {}):
		deeds[int(k)] = int(d.deeds[k])
	for n in d.get("collection", []):
		collection[str(n)] = true
	for t in d.get("bonus", []):
		collection_bonus[str(t)] = true
	goal_reached = bool(d.get("goal", false))
	pending_prisoner = str(d.get("prisoner", ""))
