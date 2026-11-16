extends Node
# Autoload "RoadTraffic" (rediseño v2, fase 6): grupos que recorren los caminos del reino donde estás,
# al ritmo del reloj (Journey.hours): bandidos, patrullas, caravanas y viajeros. Si te cruzas con
# uno (mismo tramo y cerca, o en el mismo lugar) avisa con encounter(group) y el mapa del reino
# plantea el encuentro. Al cambiar de reino se repueblan sus caminos.
# Grupo: {id, type, a, b, t (0..1 de a hacia b), speed (tramo por hora), met}

signal encounter(group: Dictionary)
signal moved

const TYPES := {
	"bandidos": {"name": "Bandidos", "icon": "crossed-swords", "count": 2, "speed": 1.0, "color": Color("d0503c")},
	"patrulla": {"name": "Patrulla", "icon": "knight-banner", "count": 1, "speed": 1.2, "color": Color("5b8fd0")},
	"caravana": {"name": "Caravana", "icon": "two-coins", "count": 1, "speed": 0.7, "color": Color("d4af5a")},
	"viajero": {"name": "Viajero", "icon": "person", "count": 2, "speed": 0.9, "color": Color("9fd08a")},
	"ejercito": {"name": "Ejército enemigo", "icon": "flying-flag", "count": 0, "speed": 0.8, "color": Color("8a2a2a")},
}
const MEET_DIST := 0.12          # fracción del tramo
const NIGHT_BANDIT_BONUS := 1    # de noche hay un grupo de bandidos más
const RESPAWN_HOURS := 12.0      # un grupo deshecho reaparece tras este tiempo

var groups: Array = []
var _kingdom := -1
var _last_hours := -1.0
var _next_id := 1
var _respawn: Array = []         # [{type, at_hours}]
var paused := false

func _ready() -> void:
	GameManager.game_started.connect(func(_c): reset())

func reset() -> void:
	groups.clear()
	_respawn.clear()
	_kingdom = -1
	_last_hours = -1.0

func _process(_delta: float) -> void:
	if not GameManager.is_game_active or GameManager.player_character == null:
		return
	if Journey.kingdom != _kingdom:
		_populate(Journey.kingdom)
	if _last_hours < 0.0:
		_last_hours = Journey.hours
	var dh := Journey.hours - _last_hours
	if dh <= 0.0:
		return
	_last_hours = Journey.hours
	advance(dh)

## Mueve los grupos dh horas y comprueba encuentros.
func advance(dh: float) -> void:
	for g: Dictionary in groups:
		var h := maxf(0.5, KingdomMaps.travel_hours(_kingdom, int(g.a), int(g.b)))
		g.t = float(g.t) + dh * float(g.speed) / h
		while float(g.t) >= 1.0:
			var prev := int(g.a)
			g.a = g.b
			g.b = _next_node(int(g.a), prev)
			g.t = float(g.t) - 1.0
			g.met = false
	for r in _respawn.duplicate():
		if Journey.hours >= float(r.at):
			_respawn.erase(r)
			_spawn(str(r.type))
	moved.emit()
	if not paused:
		_check_meet()

func _populate(k: int) -> void:
	groups.clear()
	_respawn.clear()
	_kingdom = k
	_last_hours = Journey.hours
	for t: String in TYPES:
		for n in int(TYPES[t].count) + (NIGHT_BANDIT_BONUS if t == "bandidos" else 0):
			_spawn(t)
	# En guerra, un ejército enemigo recorre tu reino o el reino enemigo en el que estés.
	var hostile: Array = RelationsData.hostile_kingdoms()
	if not hostile.is_empty() and (k == GameManager.player_kingdom or k in hostile):
		_spawn("ejercito")

func _spawn(t: String) -> void:
	var nodes := KingdomMaps.nodes(_kingdom)
	if nodes.size() < 2:
		return
	var a := randi() % nodes.size()
	if a == Journey.at:
		a = (a + 1) % nodes.size()
	var g := {"id": _next_id, "type": t, "a": a, "b": _next_node(a, -1), "t": randf(),
		"speed": float(TYPES[t].speed) * randf_range(0.8, 1.2), "met": false}
	_next_id += 1
	groups.append(g)

func _next_node(at: int, avoid: int) -> int:
	var nb := Journey.neighbors(at) if _kingdom == Journey.kingdom else []
	if nb.is_empty():
		return at
	var opts := nb.filter(func(x): return x != avoid)
	if opts.is_empty():
		opts = nb
	return opts[randi() % opts.size()]

## Posición (fracción del mapa) de un grupo.
func position_of(g: Dictionary) -> Vector2:
	var pa: Vector2 = Journey.node(int(g.a)).pos
	var pb: Vector2 = Journey.node(int(g.b)).pos
	return pa.lerp(pb, clampf(float(g.t), 0.0, 1.0))

## ¿Coincide el grupo con el jugador?
func meets_player(g: Dictionary) -> bool:
	var ga := int(g.a)
	var gb := int(g.b)
	var gt := float(g.t)
	if Journey.is_traveling():
		var pa := Journey.at
		var pb := Journey.leg_to
		var pt := Journey.leg_progress
		if ga == pa and gb == pb:
			return absf(gt - pt) < MEET_DIST
		if ga == pb and gb == pa:
			return absf((1.0 - gt) - pt) < MEET_DIST
		return false
	# Parado en un lugar: te encuentra quien pasa por él.
	return (ga == Journey.at and gt < MEET_DIST) or (gb == Journey.at and gt > 1.0 - MEET_DIST)

func _check_meet() -> void:
	for g: Dictionary in groups:
		if not g.met and meets_player(g):
			g.met = true
			encounter.emit(g)
			return

## El grupo deja el camino (vencido, ahuyentado o robado); vuelve a aparecer otro más tarde.
func remove(g: Dictionary) -> void:
	groups.erase(g)
	_respawn.append({"type": g.type, "at": Journey.hours + RESPAWN_HOURS})
	moved.emit()

## ¿Te persigue la patrulla? (mala fama o vía de Villano)
func patrol_hostile() -> bool:
	var p: Character = GameManager.player_character
	return p != null and (p.fame <= -20 or p.via == ViaCatalog.Via.VILLANO)

func save_state() -> Dictionary:
	return {}   # los grupos se repueblan al cargar

func load_state(_d: Dictionary) -> void:
	reset()
