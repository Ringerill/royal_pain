extends Node
# Autoload "Expeditions" (rediseño v2, fase 6): expediciones por salas y la arena.
#   Expedición (cueva, torre olvidada, campamento bandido): 4 niveles de 2 salas a elegir (combate,
#   tesoro, descanso, trampa) y un jefe al final. Vencida, el lugar queda limpio RENEW_DAYS días.
#   Arena: torneo (3 rondas, curas entre rondas) y desafío de jefes (4 jefes seguidos, sin curas),
#   una vez al mes cada uno.
# Una partida en curso: run = {kind, key, place, title, layers: [[{type, done}]], layer, room, prize}.
# Los combates vuelven a la escena de la expedición (CombatSetup.return_scene) y se resuelven por
# CombatSetup.apply_outcome → resolve_fight.

signal changed

const SCENE := "res://scenes/expedition/expedition.tscn"
const LAYERS := 4
const ROOMS_PER_LAYER := 2
const RENEW_DAYS := 20
const ROOM_WEIGHTS := {"combate": 50, "tesoro": 20, "descanso": 15, "trampa": 15}
const ROOM_NAMES := {"combate": "Combate", "tesoro": "Tesoro", "descanso": "Descanso", "trampa": "Trampa", "jefe": "Jefe"}
const ROOM_ICONS := {"combate": "crossed-swords", "tesoro": "treasure-map", "descanso": "bindle", "trampa": "knockout", "jefe": "crown"}
const TREASURE_GOLD := [40, 120]
const REST_HEAL := 0.35
const REST_ENERGY := 20
const TRAP_DMG := 0.15
const TRAP_ENERGY := 10
const TRAP_AVOID_PER_AGI := 0.04
const PLACES := {   # tipo de lugar → escena, contexto de enemigos y jefe
	"cueva": {"bg": "cave", "context": "exploracion", "boss": "Jefe forajido", "foe": "Forajido"},
	"torre": {"bg": "tower", "context": "exploracion", "boss": "Guardián de la torre", "foe": "Cultista"},
	"campamento_bandido": {"bg": "bandit_camp", "context": "camino", "boss": "Capitán bandido", "foe": "Bandido"},
}
const EXPEDITION_PRIZE := {"gold": 250, "fame": 4}
const TOURNEY_PRIZE := {"gold": 200, "fame": 5}
const BOSS_RUSH_PRIZE := {"gold": 600, "fame": 10}

var run := {}
var cleared := {}       # "k:i" -> día en que se renueva
var arena_done := {}    # "k:i:torneo" / "k:i:jefes" -> mes (día/30) en que se hizo

func _ready() -> void:
	GameManager.game_started.connect(func(_c): reset())

func reset() -> void:
	run = {}
	cleared.clear()
	arena_done.clear()

func active() -> bool:
	return not run.is_empty()

static func _month() -> int:
	return Journey.day_index() / Journey.DAYS_PER_MONTH

# --- Empezar ---

## Por qué no se puede explorar ahora ("" si se puede).
func blocker(k: int, i: int) -> String:
	var key := ContractData.node_key(k, i)
	if cleared.has(key) and Journey.day_index() < int(cleared[key]):
		return "Ya lo despejaste: vuelve en %d días." % (int(cleared[key]) - Journey.day_index())
	return ""

func start_expedition(k: int, i: int) -> bool:
	var t := str(KingdomMaps.nodes(k)[i].type)
	if not PLACES.has(t) or not blocker(k, i).is_empty():
		return false
	var layers := []
	for l in LAYERS:
		var row := []
		for r in ROOMS_PER_LAYER:
			row.append({"type": _pick_room(), "done": false})
		layers.append(row)
	layers.append([{"type": "jefe", "done": false}])
	run = {"kind": "expedicion", "key": ContractData.node_key(k, i), "place": t,
		"title": "%s · %s" % [KingdomMaps.TYPE_NAMES.get(t, t), Journey.node_name(i)],
		"layers": layers, "layer": -1, "room": -1, "prize": EXPEDITION_PRIZE}
	changed.emit()
	return true

func arena_blocker(k: int, i: int, kind: String) -> String:
	if int(arena_done.get("%s:%s" % [ContractData.node_key(k, i), kind], -1)) == _month():
		return "Ya lo hiciste este mes."
	return ""

## kind: "torneo" (3 rondas con curas) o "jefes" (4 jefes seguidos).
func start_arena(k: int, i: int, kind: String) -> bool:
	if not arena_blocker(k, i, kind).is_empty():
		return false
	var layers := []
	var n := 3 if kind == "torneo" else 4
	for l in n:
		layers.append([{"type": "combate" if kind == "torneo" and l < n - 1 else "jefe", "done": false}])
	run = {"kind": kind, "key": ContractData.node_key(k, i), "place": "arena",
		"title": ("Torneo de la arena" if kind == "torneo" else "Desafío de jefes") + " · " + Journey.node_name(i),
		"layers": layers, "layer": -1, "room": -1, "prize": TOURNEY_PRIZE if kind == "torneo" else BOSS_RUSH_PRIZE}
	changed.emit()
	return true

func _pick_room() -> String:
	var total := 0
	for k in ROOM_WEIGHTS:
		total += int(ROOM_WEIGHTS[k])
	var r := randi() % total
	for k in ROOM_WEIGHTS:
		r -= int(ROOM_WEIGHTS[k])
		if r < 0:
			return k
	return "combate"

# --- Avanzar ---

## Salas a las que se puede ir ahora: [[nivel, sala], ...].
func choices() -> Array:
	if run.is_empty():
		return []
	var next := int(run.layer) + 1
	if next >= run.layers.size():
		return []
	var out := []
	for r in run.layers[next].size():
		out.append([next, r])
	return out

func room(l: int, r: int) -> Dictionary:
	return run.layers[l][r]

## Entra en una sala. Devuelve {"text"} para salas sin combate o {"fight": dict} para combates.
func enter(l: int, r: int) -> Dictionary:
	if not [l, r] in choices():
		return {}
	run.layer = l
	run.room = r
	var rm: Dictionary = room(l, r)
	var p: Character = GameManager.player_character
	match str(rm.type):
		"tesoro":
			rm.done = true
			var gold := randi_range(TREASURE_GOLD[0], TREASURE_GOLD[1])
			p.gold += gold
			var extra := ""
			if randf() < 0.5:
				var ids := ConsumableCatalog.common_ids()
				var id: String = ids[randi() % ids.size()]
				if ConsumableCatalog.add(p.consumables, id) > 0:
					extra = " y %s" % ConsumableCatalog.item_name(id)
			changed.emit()
			return {"text": "Un cofre olvidado: %d de oro%s." % [gold, extra]}
		"descanso":
			rm.done = true
			for c: Character in _group():
				c.current_health = mini(c.max_health, c.current_health + roundi(c.max_health * REST_HEAL))
			p.restore_energy(REST_ENERGY)
			changed.emit()
			return {"text": "Un rincón seguro. Os vendáis y recuperáis el aliento."}
		"trampa":
			rm.done = true
			if randf() < clampf(p.agility * TRAP_AVOID_PER_AGI, 0.1, 0.8):
				changed.emit()
				return {"text": "Ves la trampa a tiempo y la esquivas."}
			for c: Character in _group():
				c.current_health = maxi(1, c.current_health - roundi(c.max_health * TRAP_DMG))
			p.spend_energy(TRAP_ENERGY)
			changed.emit()
			return {"text": "¡Una trampa! Os hiere a todos y te deja agotado."}
	return {"fight": _fight_for(rm, l)}

func _fight_for(rm: Dictionary, l: int) -> Dictionary:
	var spec: Dictionary = PLACES.get(run.place, {"context": "camino", "boss": "Campeón de la arena", "foe": "Gladiador"})
	var boss := str(rm.type) == "jefe"
	var foe_name: String = spec.boss if boss else spec.foe
	if run.place == "arena":
		foe_name = ("Campeón de la arena" if boss else "Gladiador") + (" %d" % (l + 1) if run.kind == "jefes" else "")
	var power := (2 + l / 2) if boss else l / 2
	return {"type": "duel", "no_rival": true, "context": spec.get("context", "historia"), "expedition": true,
		"foe": {"name": foe_name, "role": Character.Role.SOLDADO, "power": power, "personality": "CRUEL"},
		"win": {"effects": {}, "result": ""}, "lose": {"effects": {}, "result": ""}}

## Lo llama CombatSetup.apply_outcome.
func resolve_fight(won: bool) -> String:
	if run.is_empty():
		return ""
	if not won:
		var t := "Os retiráis maltrechos de %s." % run.title
		run = {}
		changed.emit()
		return t
	var rm: Dictionary = room(int(run.layer), int(run.room))
	rm.done = true
	if run.kind == "torneo":   # entre rondas os curan
		for c: Character in _group():
			c.current_health = c.max_health
	if int(run.layer) >= run.layers.size() - 1:
		return _finish()
	changed.emit()
	return "Sala superada."

func _finish() -> String:
	var p: Character = GameManager.player_character
	var prize: Dictionary = run.prize
	p.gold += int(prize.gold)
	p.add_fame(int(prize.fame))
	if run.kind == "expedicion":
		cleared[run.key] = Journey.day_index() + RENEW_DAYS
	else:
		arena_done["%s:%s" % [run.key, run.kind]] = _month()
	var t := "¡%s superado! +%d de oro · Fama %+d." % [run.title, int(prize.gold), int(prize.fame)]
	WorldEvents.record(t, "", true)
	run = {}
	changed.emit()
	return t

func retreat() -> void:
	run = {}
	changed.emit()

func finished() -> bool:
	return not run.is_empty() and choices().is_empty()

func _group() -> Array:
	var out: Array = [GameManager.player_character]
	for c: Character in PartyData.members():
		if not c in out:
			out.append(c)
	return out

func save_state() -> Dictionary:
	return {"run": run.duplicate(true), "cleared": cleared.duplicate(), "arena": arena_done.duplicate()}

func load_state(d: Dictionary) -> void:
	reset()
	run = d.get("run", {})
	for k in d.get("cleared", {}):
		cleared[str(k)] = int(d.cleared[k])
	for k in d.get("arena", {}):
		arena_done[str(k)] = int(d.arena[k])
	if not run.is_empty():
		run.layer = int(run.layer)
		run.room = int(run.room)
