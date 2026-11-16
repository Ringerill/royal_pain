extends Node
# Autoload — registrar como "Journey" (después de GameManager y MapData).
# Rediseño v2 (docs/REDISENO.md §1): reloj del mundo y posición del jugador en el mapa del reino.
# - Sin turnos: el reloj corre solo mientras viajas (HOURS_PER_SECOND × velocidad). Parado, no avanza.
# - Meses de 30 días: al cerrar cada mes se ejecuta GameManager.advance_turn() (el mundo de siempre:
#   IA de reinos, economía, sucesos), así los sistemas antiguos siguen vivos mientras se migran.
# - Viajar gasta energía (2 por hora); en 0 te desmayas y despiertas en el lugar de descanso más cercano
#   habiendo perdido dinero. Dormir (8 h) la recupera; descansar en un campamento (4 h) da 40.

const NameCatalog = preload("res://scripts/resources/name_catalog.gd")

signal changed                 # posición, reloj o estado del viaje
signal arrived(index: int)
signal fainted(text: String)
signal month_passed

const HOURS_PER_SECOND := 1.0
const SPEEDS := [0, 1, 2, 4]
const HOURS_PER_DAY := 24.0
const DAYS_PER_MONTH := 30
const START_HOUR := 8.0
const NIGHT_FROM := 20.0
const NIGHT_TO := 6.0
const TRAVEL_ENERGY_PER_HOUR := 2.0
const SLEEP_HOURS := 8.0
const CAMP_REST_HOURS := 4.0
const CAMP_REST_ENERGY := 40
const FAINT_GOLD_LOSS := 0.2
const FAINT_ENERGY := 30
const WORLD_HOURS_PER_UNIT := 160.0   # viaje entre reinos: horas por unidad de distancia en el mapa del mundo
const WORLD_TRAVEL_ENERGY := 30       # un viaje largo incluye sus noches: gasta esto en total
const SEA_FARE := 30                  # pasaje en barco

var hours := START_HOUR               # horas desde el inicio de la partida
var kingdom := -1
var at := 0                           # lugar donde estás (índice en KingdomMaps.nodes) o del que partiste
var leg_to := -1                      # lugar hacia el que vas (-1 = parado)
var leg_progress := 0.0               # 0..1 del tramo actual
var path: Array[int] = []             # lugares que faltan tras el tramo actual
var speed_index := 1                  # índice en SPEEDS (0 = pausa)
var names := {}                       # "reino:índice" -> nombre del lugar en esta partida
var _months_applied := 0
var _energy_debt := 0.0
var _blocked := 0                     # ventanas abiertas que detienen el reloj

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.game_started.connect(func(_c): reset())

## Partida nueva: en la capital del reino de origen, a las 8 de la mañana del día 1.
func reset() -> void:
	hours = START_HOUR
	kingdom = GameManager.player_kingdom if GameManager.player_kingdom >= 0 else KingdomEnums.Kingdom.HIELO
	at = 0
	leg_to = -1
	leg_progress = 0.0
	path.clear()
	speed_index = 1
	_months_applied = 0
	_energy_debt = 0.0
	_generate_names()
	changed.emit()

# --- Reloj ---

func day_index() -> int:
	return int(floor(hours / HOURS_PER_DAY))

func day_of_month() -> int:
	return day_index() % DAYS_PER_MONTH + 1

func hour_of_day() -> float:
	return fmod(hours, HOURS_PER_DAY)

func is_night() -> bool:
	var h := hour_of_day()
	return h >= NIGHT_FROM or h < NIGHT_TO

## Momento del día: 0 noche, 1 amanecer, 2 día, 3 atardecer (para tintes y fondos).
func daypart() -> int:
	var h := hour_of_day()
	if h < 5.0 or h >= 21.0:
		return 0
	if h < 8.0:
		return 1
	if h < 18.0:
		return 2
	return 3

## Estación según el mes: invierno (12–3), verano (4–7), otoño (8–11). Sufijo de los fondos.
func season() -> String:
	var m := GameManager.current_month
	if m == 12 or m <= 3:
		return "invierno"
	return "verano" if m <= 7 else "otoño"

func season_suffix() -> String:
	return {"invierno": "_winter", "verano": "", "otoño": "_autumn"}[season()]

func clock_text() -> String:
	var h := hour_of_day()
	return "%02d:%02d · Día %d · %s" % [int(h), int(fmod(h, 1.0) * 60.0), day_of_month(), season().capitalize()]

## Hace pasar el tiempo (viajando gasta energía; esperando o durmiendo, no).
func pass_time(h: float, tiring: bool = false) -> void:
	if h <= 0.0:
		return
	hours += h
	var p: Character = GameManager.player_character
	if tiring and p != null:
		_energy_debt += h * TRAVEL_ENERGY_PER_HOUR * (1.0 + float(ViaCatalog.bonus(p.via, "travel_energy", 0.0)))
		var whole := int(_energy_debt)
		if whole > 0:
			_energy_debt -= whole
			p.spend_energy(whole)
	# Meses cumplidos: el mundo avanza (sucesos, IA, economía).
	var months := day_index() / DAYS_PER_MONTH
	while _months_applied < months and GameManager.is_game_active:
		_months_applied += 1
		GameManager.advance_turn()
		month_passed.emit()
	changed.emit()

# --- Lugares y caminos del reino actual ---

func nodes() -> Array[Dictionary]:
	return KingdomMaps.nodes(kingdom)

func node(i: int) -> Dictionary:
	return KingdomMaps.nodes(kingdom)[i]

func node_name(i: int, k: int = -1) -> String:
	if k < 0:
		k = kingdom
	return str(names.get("%d:%d" % [k, i], KingdomMaps.TYPE_NAMES.get(KingdomMaps.nodes(k)[i].type, "Lugar")))

func is_traveling() -> bool:
	return leg_to >= 0

## Posición actual en el mapa del reino (fracción), interpolada en mitad de un tramo.
func position_frac() -> Vector2:
	var a: Vector2 = node(at).pos
	if leg_to < 0:
		return a
	return a.lerp(node(leg_to).pos, leg_progress)

func neighbors(i: int) -> Array[int]:
	var out: Array[int] = []
	for e in KingdomMaps.edges(kingdom):
		if e[0] == i:
			out.append(e[1])
		elif e[1] == i:
			out.append(e[0])
	return out

## Camino más corto (por horas) entre dos lugares del reino: lista de índices sin el de partida.
func route(from: int, to: int) -> Array[int]:
	var dist := {from: 0.0}
	var prev := {}
	var open := [from]
	while not open.is_empty():
		open.sort_custom(func(a, b): return dist[a] < dist[b])
		var u: int = open.pop_front()
		if u == to:
			break
		for v in neighbors(u):
			var d: float = dist[u] + KingdomMaps.travel_hours(kingdom, u, v)
			if not dist.has(v) or d < dist[v]:
				dist[v] = d
				prev[v] = u
				if not v in open:
					open.append(v)
	var out: Array[int] = []
	if from != to and not prev.has(to):
		return out
	var x := to
	while x != from:
		out.push_front(x)
		x = prev[x]
	return out

func route_hours(from: int, to: int) -> float:
	var t := 0.0
	var a := from
	for b in route(from, to):
		t += KingdomMaps.travel_hours(kingdom, a, b)
		a = b
	return t

## Empieza (o redirige al llegar al próximo lugar) un viaje hacia otro lugar del reino.
func travel_to(target: int) -> bool:
	if target == at and leg_to < 0:
		return false
	if leg_to >= 0:   # en marcha: al terminar este tramo, sigue hacia el nuevo destino
		path = route(leg_to, target)
		changed.emit()
		return true
	var r := route(at, target)
	if r.is_empty():
		return false
	leg_to = r.pop_front()
	path = r
	leg_progress = 0.0
	changed.emit()
	return true

func stop_after_leg() -> void:
	path.clear()

func set_speed(i: int) -> void:
	speed_index = clampi(i, 0, SPEEDS.size() - 1)
	changed.emit()

func block() -> void:
	_blocked += 1

func unblock() -> void:
	_blocked = maxi(0, _blocked - 1)

func _process(delta: float) -> void:
	if leg_to < 0 or SPEEDS[speed_index] == 0 or _blocked > 0 or not GameManager.is_game_active:
		return
	if GameManager.has_pending_event():
		return   # un suceso espera respuesta: el viaje se detiene
	var dh: float = delta * HOURS_PER_SECOND * float(SPEEDS[speed_index])
	var leg_h := KingdomMaps.travel_hours(kingdom, at, leg_to)
	leg_progress += dh / leg_h
	pass_time(dh, true)
	var p: Character = GameManager.player_character
	if p != null and p.energy <= 0:
		faint()
		return
	if leg_progress >= 1.0:
		at = leg_to
		leg_progress = 0.0
		leg_to = path.pop_front() if not path.is_empty() else -1
		arrived.emit(at)
		changed.emit()

# --- Descanso ---

func can_sleep() -> bool:
	return leg_to < 0 and node(at).type in ["capital", "ciudad", "pueblo", "puerto"]

func can_camp() -> bool:
	return leg_to < 0 and node(at).type in KingdomMaps.REST_TYPES

func sleep() -> void:
	if not can_sleep():
		return
	pass_time(SLEEP_HOURS)
	var p: Character = GameManager.player_character
	p.restore_energy(p.max_energy)
	SaveSystem.save_game()   # se guarda solo al dormir

func camp_rest() -> void:
	if not can_camp():
		return
	pass_time(CAMP_REST_HOURS)
	GameManager.player_character.restore_energy(CAMP_REST_ENERGY)

func wait_hours(h: float) -> void:
	if leg_to < 0:
		pass_time(h)

## Sin energía: despiertas en el lugar de descanso más cercano, sin parte de tu oro.
func faint() -> void:
	var p: Character = GameManager.player_character
	var here := position_frac()
	var best := 0
	var best_d := INF
	for n in nodes():
		if n.type in KingdomMaps.SETTLEMENT_TYPES and n.pos.distance_to(here) < best_d:
			best_d = n.pos.distance_to(here)
			best = n.index
	at = best
	leg_to = -1
	path.clear()
	leg_progress = 0.0
	var lost := roundi(p.gold * FAINT_GOLD_LOSS)
	p.gold -= lost
	pass_time(SLEEP_HOURS)
	p.energy = FAINT_ENERGY
	var text := "Agotado, caes desmayado en el camino. Despiertas en %s sin %d de oro." % [node_name(best), lost]
	WorldEvents.record(text, "", true)
	fainted.emit(text)
	changed.emit()

# --- Viajes entre reinos (mapa del mundo) ---

func capital_castle(k: int) -> Castle:
	for c: Castle in MapData.castles:
		if c.original_kingdom == k:
			return c
	return null

## Reinos vecinos por tierra (sus capitales están unidas por camino).
func land_neighbors(k: int) -> Array[int]:
	var out: Array[int] = []
	var c := capital_castle(k)
	if c == null:
		return out
	for id in c.connected_castle_ids:
		var o := MapData.get_castle_by_id(id)
		if o != null and o.original_kingdom != k:
			out.append(o.original_kingdom)
	return out

func at_port() -> bool:
	return leg_to < 0 and node(at).type == "puerto"

## Cómo se puede ir a otro reino desde aquí: {ok, sea, hours, cost, why}
func world_route(k: int) -> Dictionary:
	if k == kingdom:
		return {"ok": false, "why": "Ya estás en este reino."}
	var a := capital_castle(kingdom)
	var b := capital_castle(k)
	if a == null or b == null:
		return {"ok": false, "why": "No hay camino."}
	var d := a.position_on_map.distance_to(b.position_on_map) / MapData.MAP_WIDTH
	if k in land_neighbors(kingdom):
		return {"ok": true, "sea": false, "hours": maxf(24.0, d * WORLD_HOURS_PER_UNIT), "cost": 0}
	if at_port() and KingdomMaps.has_port(k):
		return {"ok": true, "sea": true, "hours": maxf(24.0, d * WORLD_HOURS_PER_UNIT * 0.6), "cost": SEA_FARE}
	return {"ok": false, "why": "No limita por tierra. Ve a un puerto y toma un barco."}

func travel_to_kingdom(k: int) -> String:
	var r := world_route(k)
	if not r.ok or leg_to >= 0:
		return str(r.get("why", "Ahora no puedes viajar."))
	var p: Character = GameManager.player_character
	if p.gold < int(r.cost):
		return "No te llega para el pasaje (%d de oro)." % int(r.cost)
	p.gold -= int(r.cost)
	var from := kingdom
	pass_time(float(r.hours))
	p.spend_energy(mini(WORLD_TRAVEL_ENERGY, p.energy - 1))
	kingdom = k
	at = _arrival_node(from, k, bool(r.sea))
	leg_to = -1
	path.clear()
	changed.emit()
	return ""

# Al llegar por mar, al puerto; por tierra, al lugar del reino más cercano a la frontera de origen.
func _arrival_node(from: int, to: int, by_sea: bool) -> int:
	var ns := KingdomMaps.nodes(to)
	if by_sea:
		for n in ns:
			if n.type == "puerto":
				return n.index
	var a := capital_castle(from)
	var b := capital_castle(to)
	var dir := (a.position_on_map - b.position_on_map).normalized() if a != null and b != null else Vector2.ZERO
	var best := 0
	var best_s := -INF
	for n in ns:
		if not n.type in KingdomMaps.SETTLEMENT_TYPES and n.type != "campamento":
			continue
		var s: float = (n.pos - Vector2(0.5, 0.5)).dot(dir)
		if s > best_s:
			best_s = s
			best = n.index
	return best

# --- Nombres de los lugares (por partida, según la cultura del reino) ---

const NAME_TEMPLATES := {
	"puerto": "Puerto de %s", "cueva": "Cueva de %s", "torre": "Torre de %s", "puente": "Puente de %s",
	"campamento": "Campamento de %s", "campamento_bandido": "Guarida de %s", "arena": "Arena de %s", "ciudad": "%s",
	"pueblo": "%s",
}

func _generate_names() -> void:
	names.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for k in KingdomEnums.Kingdom.values():
		var culture := MapData.culture_of_kingdom(k)
		var used := {}
		for n in KingdomMaps.nodes(k):
			var nm := ""
			if n.type == "capital":
				var c := capital_castle(k)
				nm = c.castle_name if c != null else "Capital"
			else:
				for _i in 6:
					nm = NAME_TEMPLATES.get(n.type, "%s") % NameCatalog.place(culture, rng)
					if not used.has(nm):
						break
			used[nm] = true
			names["%d:%d" % [k, n.index]] = nm

# --- Guardado ---

func save_state() -> Dictionary:
	return {"hours": hours, "kingdom": kingdom, "at": at, "names": names, "months": _months_applied,
		"speed": speed_index}

func load_state(d: Dictionary) -> void:
	hours = float(d.get("hours", START_HOUR))
	kingdom = int(d.get("kingdom", GameManager.player_kingdom))
	at = int(d.get("at", 0))
	names = d.get("names", {})
	_months_applied = int(d.get("months", day_index() / DAYS_PER_MONTH))
	speed_index = int(d.get("speed", 1))
	leg_to = -1
	path.clear()
	leg_progress = 0.0
	if names.is_empty():
		_generate_names()
	changed.emit()
