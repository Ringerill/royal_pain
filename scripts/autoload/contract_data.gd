extends Node
# Autoload "ContractData" (rediseño v2, fase 5): encargos del tablón de las tabernas.
# Cada lugar habitado ofrece unos cuantos (se renuevan cada semana). Aceptas hasta MAX_ACTIVE;
# cada uno tiene destino en el reino y plazo en días. Al llegar al destino se resuelve: entregas
# y escoltas se cobran (con riesgo de emboscada), cazas, despejes y rescates piden combate.
# Fallar el plazo o abandonarlo cuesta fama.
# Tipos: entregar, escoltar, cazar, despejar, rescatar, turbio (solo de noche, en el callejón).

signal changed

const MAX_ACTIVE := 3
const BOARD_SIZE := 4
const REFRESH_DAYS := 7
const SLACK_DAYS := [2, 4]          # días de margen sobre lo que dura el camino
const FAIL_FAME := 3
const ABANDON_FAME := 2
const AMBUSH_CHANCE := 0.3          # escoltas: probabilidad de pelea al llegar
const KINDS := {
	"entregar": {"name": "Entrega", "fight": false, "gold": [40, 90], "fame": 1,
		"text": "Lleva un paquete sellado a %s antes del día %d."},
	"escoltar": {"name": "Escolta", "fight": false, "gold": [70, 140], "fame": 2,
		"text": "Acompaña a un mercader hasta %s antes del día %d. Puede haber asaltantes."},
	"cazar": {"name": "Caza", "fight": true, "gold": [90, 170], "fame": 3,
		"text": "Unos salteadores acechan cerca de %s. Acaba con ellos antes del día %d."},
	"despejar": {"name": "Despeje", "fight": true, "gold": [120, 220], "fame": 4,
		"text": "Despeja el camino de %s, tomado por forajidos, antes del día %d."},
	"rescatar": {"name": "Rescate", "fight": true, "gold": [110, 200], "fame": 5,
		"text": "Han secuestrado a la hija de un tendero. La retienen en %s: tráela antes del día %d."},
	"turbio": {"name": "Turbio", "fight": false, "gold": [150, 260], "fame": -4, "night": true,
		"text": "Nadie debe saber qué hay en esta caja. Déjala en %s antes del día %d."},
	"recompensa": {"name": "Se busca", "fight": true, "gold": [220, 320], "fame": 5,
		"text": "Se busca a un cabecilla forajido escondido en %s. Recompensa si cae antes del día %d."},
}
const DAY_KINDS := ["entregar", "escoltar", "cazar", "despejar", "rescatar"]

var active: Array = []          # contratos aceptados
var completed := 0
var failed := 0
var _boards := {}               # "k:i" -> {week, offers}
var _taken := {}                # uid -> true (aceptados o hechos: no vuelven al tablón)

func _ready() -> void:
	GameManager.game_started.connect(func(_c): reset())

func reset() -> void:
	active.clear()
	_boards.clear()
	_taken.clear()
	completed = 0
	failed = 0

static func node_key(k: int, i: int) -> String:
	return "%d:%d" % [k, i]

# --- Tablón ---

## Ofertas del lugar (k, i). night: el callejón ofrece los turbios.
func board(k: int, i: int, night: bool = false) -> Array:
	var week := Journey.day_index() / REFRESH_DAYS
	var key := node_key(k, i) + (":n" if night else "")
	var b: Dictionary = _boards.get(key, {})
	if b.is_empty() or int(b.week) != week:
		b = {"week": week, "offers": _generate(k, i, week, night)}
		_boards[key] = b
	return (b.offers as Array).filter(func(o: Dictionary) -> bool: return not _taken.has(o.uid))

func _generate(k: int, i: int, week: int, night: bool) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:%s" % [node_key(k, i), week, night])
	var nodes := KingdomMaps.nodes(k)
	var out := []
	var n := 1 if night else BOARD_SIZE
	var bounty_slot := -1   # «se busca»: siempre para los justicieros; a veces para los demás
	if not night and (GameManager.player_character.via == ViaCatalog.Via.JUSTICIERO or rng.randf() < 0.25):
		bounty_slot = n - 1
	for j in n:
		var kind: String = "turbio" if night else ("recompensa" if j == bounty_slot else DAY_KINDS[rng.randi() % DAY_KINDS.size()])
		var candidates := nodes.filter(func(x: Dictionary) -> bool: return x.index != i)
		if kind in ["despejar", "rescatar", "recompensa"]:
			var wild := candidates.filter(func(x: Dictionary) -> bool: return not x.type in KingdomMaps.SETTLEMENT_TYPES)
			if not wild.is_empty():
				candidates = wild
		if candidates.is_empty():
			continue
		var target: Dictionary = candidates[rng.randi() % candidates.size()]
		var hours := KingdomMaps.travel_hours(k, i, target.index) if KingdomMaps.edges(k).size() > 0 else 24.0
		hours = Journey.route_hours(i, target.index) if k == Journey.kingdom else hours
		var days := ceili(hours / Journey.HOURS_PER_DAY) + rng.randi_range(SLACK_DAYS[0], SLACK_DAYS[1])
		var d: Dictionary = KINDS[kind]
		out.append({
			"uid": "%s:%d:%d" % [node_key(k, i), week, j] + (":n" if night else ""),
			"kind": kind, "origin": node_key(k, i), "k": k, "target": int(target.index),
			"days": days, "gold": rng.randi_range(d.gold[0], d.gold[1]), "fame": int(d.fame),
		})
	return out

func title(c: Dictionary) -> String:
	return "%s · %s" % [KINDS[c.kind].name, _place_name(int(c.k), int(c.target))]

func describe(c: Dictionary) -> String:
	var deadline := int(c.get("deadline", Journey.day_index() + int(c.days))) % Journey.DAYS_PER_MONTH + 1
	var t: String = KINDS[c.kind].text % [_place_name(int(c.k), int(c.target)), deadline]
	return "%s\nPaga: %d de oro · Fama %+d · Plazo: %d días." % [t, int(c.gold), int(c.fame), _days_left(c)]

func _days_left(c: Dictionary) -> int:
	if c.has("deadline"):
		return int(c.deadline) - Journey.day_index()
	return int(c.days)

func _place_name(k: int, i: int) -> String:
	if k == Journey.kingdom:
		return Journey.node_name(i)
	return KingdomMaps.TYPE_NAMES.get(KingdomMaps.nodes(k)[i].type, "?")

func can_accept() -> String:
	if active.size() >= MAX_ACTIVE:
		return "Ya llevas %d encargos." % MAX_ACTIVE
	return ""

func accept(c: Dictionary) -> bool:
	if not can_accept().is_empty() or _taken.has(c.uid):
		return false
	var a := c.duplicate()
	a["deadline"] = Journey.day_index() + int(c.days)
	active.append(a)
	_taken[c.uid] = true
	changed.emit()
	return true

func abandon(uid: String) -> String:
	for c: Dictionary in active:
		if c.uid == uid:
			active.erase(c)
			GameManager.player_character.add_fame(-ABANDON_FAME)
			failed += 1
			changed.emit()
			return "Abandonas el encargo: %s. Fama −%d." % [title(c), ABANDON_FAME]
	return ""

# --- Resolución ---

## Al llegar a (k, i): el primer encargo con ese destino. Devuelve
## {} si no hay; {"text"} si se cobró; {"fight": dict de CombatSetup, "title"} si hay que pelear.
func on_arrived(k: int, i: int) -> Dictionary:
	for c: Dictionary in active:
		if int(c.k) != k or int(c.target) != i:
			continue
		var d: Dictionary = KINDS[c.kind]
		var fight: bool = d.fight or (c.kind == "escoltar" and randf() < AMBUSH_CHANCE)
		if fight:
			return {"title": title(c), "fight": _fight_for(c), "uid": c.uid}
		return {"title": title(c), "text": _complete(c, true)}
	return {}

func _fight_for(c: Dictionary) -> Dictionary:
	var foe_name: String = {"cazar": "Salteador", "despejar": "Cabecilla forajido", "rescatar": "Secuestrador",
		"escoltar": "Asaltante de caminos", "recompensa": "Forajido buscado"}.get(c.kind, "Bandido")
	return {"type": "duel", "no_rival": true, "context": "camino", "contract_uid": c.uid,
		"foe": {"name": foe_name, "role": Character.Role.SOLDADO, "power": 2 if c.kind == "recompensa" else 1, "personality": "CRUEL"},
		"win": {"effects": {}, "result": "El camino queda libre."},
		"lose": {"effects": {}, "result": "Tienes que retirarte."}}

## Lo llama CombatSetup.apply_outcome al acabar el combate de un encargo.
func resolve_fight(uid: String, won: bool) -> String:
	for c: Dictionary in active:
		if c.uid == uid:
			if won:
				return _complete(c, true)
			return "Pierdes el combate. El encargo sigue pendiente mientras quede plazo."
	return ""

func _complete(c: Dictionary, ok: bool) -> String:
	active.erase(c)
	var p: Character = GameManager.player_character
	if ok:
		p.gold += int(c.gold)
		p.add_fame(int(c.fame))
		completed += 1
		WorldEvents.record("Encargo cumplido: %s." % title(c), "", true)
		ViaData.record("contract", "contracts")
		match str(c.kind):
			"rescatar", "cazar", "despejar":
				ViaData.record("rescue", "rescues")
			"recompensa":
				ViaData.record("bounty", "bounties")
			"turbio":
				ViaData.record("extort")
	changed.emit()
	return "Encargo cumplido: %s.\n+%d de oro · Fama %+d." % [title(c), int(c.gold), int(c.fame)]

## Encargos cuyo plazo venció: se pierden con fama. Devuelve los textos.
func check_deadlines() -> Array:
	var out := []
	var today := Journey.day_index()
	for c: Dictionary in active.duplicate():
		if today > int(c.deadline):
			active.erase(c)
			failed += 1
			GameManager.player_character.add_fame(-FAIL_FAME)
			out.append("Se acabó el plazo de «%s». Fama −%d." % [title(c), FAIL_FAME])
	if not out.is_empty():
		changed.emit()
	return out

# --- Guardado ---

func save_state() -> Dictionary:
	return {"active": active.duplicate(true), "completed": completed, "failed": failed, "taken": _taken.keys()}

func load_state(data: Dictionary) -> void:
	reset()
	for c in data.get("active", []):
		var d: Dictionary = c
		for key in ["k", "target", "days", "gold", "fame", "deadline"]:
			if d.has(key):
				d[key] = int(d[key])
		active.append(d)
	completed = int(data.get("completed", 0))
	failed = int(data.get("failed", 0))
	for u in data.get("taken", []):
		_taken[str(u)] = true
