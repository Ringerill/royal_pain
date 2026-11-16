class_name KingdomMaps
extends RefCounted
# Mapas de reino (rediseño v2, docs/REDISENO.md §1). Cada reino de KingdomEnums tiene su mapa
# (assets/maps/kingdoms/NN_*.png, 1536×1024) con 8–12 lugares colocados sobre lo dibujado.
# Posiciones en fracción del mapa (0..1). Los caminos se generan uniendo cada lugar con sus vecinos
# más cercanos (ver edges()), así que basta con colocar bien los lugares.
#
# Tipos de lugar (icono en assets/icons/locations/):
#   capital, pueblo, ciudad, puerto, cueva, torre, puente, campamento, campamento_bandido, arena

const K := KingdomEnums.Kingdom
const MAP_SIZE := Vector2(1536, 1024)
const MAP_DIR := "res://assets/maps/kingdoms/%s.png"

const TYPE_NAMES := {
	"capital": "Capital", "ciudad": "Ciudad", "pueblo": "Pueblo", "puerto": "Puerto", "cueva": "Cueva",
	"torre": "Torre olvidada", "puente": "Puente", "campamento": "Campamento",
	"campamento_bandido": "Campamento bandido", "arena": "Arena",
}
const TYPE_ICONS := {
	"capital": "03_castillo", "ciudad": "11_ciudad", "pueblo": "01_pueblo", "puerto": "05_puerto",
	"cueva": "04_cueva", "torre": "08_torre_olvidada", "puente": "07_puente", "campamento": "09_campamento",
	"campamento_bandido": "10_campamento_bandidos", "arena": "14_arena",
}
const ICON_DIR := "res://assets/icons/locations/%s.png"
# Lugares de expedición (mazmorra con nodos) y de descanso.
const EXPEDITION_TYPES := ["cueva", "torre", "campamento_bandido"]
const REST_TYPES := ["capital", "ciudad", "pueblo", "puerto", "campamento"]
const SETTLEMENT_TYPES := ["capital", "ciudad", "pueblo", "puerto"]

# reino -> {map, biome, nodes: [[tipo, x, y], …]}  (el primero siempre es la capital)
const DATA := {
	K.HIELO: {"map": "01_nieve", "biome": "hielo", "nodes": [
		["capital", 0.50, 0.35], ["cueva", 0.22, 0.22], ["puerto", 0.63, 0.13], ["pueblo", 0.75, 0.36],
		["torre", 0.28, 0.49], ["puerto", 0.14, 0.61], ["pueblo", 0.64, 0.67], ["puente", 0.58, 0.69],
		["campamento", 0.42, 0.60], ["campamento_bandido", 0.83, 0.57]]},
	K.BOSQUE: {"map": "02_verde_del_norte", "biome": "bosque", "nodes": [
		["capital", 0.42, 0.38], ["pueblo", 0.44, 0.13], ["cueva", 0.70, 0.22], ["torre", 0.60, 0.30],
		["puente", 0.50, 0.52], ["pueblo", 0.23, 0.60], ["pueblo", 0.64, 0.61], ["campamento", 0.35, 0.75],
		["puerto", 0.52, 0.85], ["campamento_bandido", 0.80, 0.45]]},
	K.DORADO: {"map": "03_dorado", "biome": "desierto", "nodes": [
		["capital", 0.48, 0.38], ["pueblo", 0.25, 0.17], ["pueblo", 0.75, 0.35], ["torre", 0.26, 0.50],
		["cueva", 0.70, 0.55], ["pueblo", 0.36, 0.73], ["puente", 0.52, 0.47], ["puerto", 0.08, 0.70],
		["campamento", 0.60, 0.25], ["campamento_bandido", 0.30, 0.58], ["arena", 0.56, 0.66]]},
	K.CUMBRES: {"map": "04_purpura", "biome": "montana", "nodes": [
		["capital", 0.45, 0.38], ["pueblo", 0.67, 0.22], ["pueblo", 0.18, 0.48], ["torre", 0.66, 0.47],
		["puente", 0.35, 0.58], ["cueva", 0.61, 0.67], ["pueblo", 0.45, 0.75], ["puerto", 0.88, 0.68],
		["campamento", 0.28, 0.30]]},
	K.AZUL: {"map": "05_azul", "biome": "costa", "nodes": [
		["capital", 0.52, 0.40], ["pueblo", 0.21, 0.37], ["pueblo", 0.80, 0.30], ["torre", 0.77, 0.49],
		["cueva", 0.29, 0.68], ["pueblo", 0.52, 0.74], ["puente", 0.56, 0.59], ["torre", 0.88, 0.11],
		["puerto", 0.08, 0.47], ["campamento", 0.38, 0.55]]},
	K.CARMESI: {"map": "07_carmesi", "biome": "llanura", "nodes": [
		["capital", 0.50, 0.36], ["pueblo", 0.72, 0.23], ["pueblo", 0.25, 0.38], ["cueva", 0.27, 0.61],
		["puente", 0.55, 0.58], ["torre", 0.73, 0.52], ["puerto", 0.83, 0.52], ["puerto", 0.55, 0.86],
		["pueblo", 0.43, 0.77], ["campamento", 0.62, 0.62], ["arena", 0.38, 0.48]]},
	K.NEUTRAL: {"map": "08_central", "biome": "llanura", "nodes": [
		["capital", 0.47, 0.42], ["pueblo", 0.52, 0.20], ["torre", 0.37, 0.22], ["puerto", 0.63, 0.32],
		["puerto", 0.63, 0.57], ["pueblo", 0.33, 0.62], ["puente", 0.47, 0.61], ["pueblo", 0.59, 0.71],
		["campamento_bandido", 0.38, 0.72], ["campamento", 0.51, 0.74]]},
	K.ESMERALDA: {"map": "09_turquesa", "biome": "bosque", "nodes": [
		["capital", 0.52, 0.42], ["pueblo", 0.28, 0.27], ["cueva", 0.73, 0.28], ["pueblo", 0.82, 0.42],
		["torre", 0.25, 0.53], ["puente", 0.55, 0.54], ["pueblo", 0.60, 0.68], ["puerto", 0.12, 0.70],
		["campamento", 0.40, 0.63], ["campamento_bandido", 0.75, 0.62]]},
	K.DESIERTO: {"map": "06_desierto", "biome": "desierto", "nodes": [
		["capital", 0.34, 0.42], ["pueblo", 0.20, 0.23], ["pueblo", 0.58, 0.24], ["torre", 0.73, 0.42],
		["puente", 0.52, 0.52], ["pueblo", 0.63, 0.67], ["campamento", 0.25, 0.72], ["puerto", 0.10, 0.86],
		["campamento_bandido", 0.78, 0.30], ["arena", 0.45, 0.68]]},
	K.AMBAR: {"map": "10_naranja", "biome": "desierto", "nodes": [
		["capital", 0.40, 0.38], ["pueblo", 0.25, 0.22], ["cueva", 0.70, 0.18], ["torre", 0.22, 0.54],
		["campamento", 0.68, 0.53], ["pueblo", 0.85, 0.42], ["puente", 0.57, 0.54], ["pueblo", 0.64, 0.72],
		["puerto", 0.40, 0.88], ["campamento_bandido", 0.30, 0.62]]},
	K.GRIS: {"map": "11_gris", "biome": "montana", "nodes": [
		["capital", 0.48, 0.42], ["pueblo", 0.55, 0.14], ["torre", 0.25, 0.33], ["campamento", 0.76, 0.37],
		["pueblo", 0.28, 0.57], ["pueblo", 0.66, 0.60], ["puente", 0.65, 0.42], ["cueva", 0.20, 0.42],
		["puerto", 0.08, 0.85], ["campamento_bandido", 0.45, 0.70]]},
	K.OLIVA: {"map": "12_verde_del_sur", "biome": "llanura", "nodes": [
		["capital", 0.46, 0.38], ["pueblo", 0.18, 0.36], ["pueblo", 0.64, 0.27], ["cueva", 0.28, 0.62],
		["pueblo", 0.58, 0.58], ["puente", 0.52, 0.60], ["torre", 0.70, 0.40], ["puerto", 0.45, 0.80],
		["campamento", 0.40, 0.52], ["arena", 0.75, 0.62]]},
}

const NEIGHBORS := 2   # cada lugar se une a sus N vecinos más cercanos (y al menos uno, para que todo esté conectado)

static func map_path(kingdom: int) -> String:
	return MAP_DIR % DATA[kingdom].map

static func biome(kingdom: int) -> String:
	return DATA[kingdom].biome

## Lugares del reino: [{id, kingdom, type, pos (fracción), index}]
static func nodes(kingdom: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var counts := {}
	for i in DATA[kingdom].nodes.size():
		var n: Array = DATA[kingdom].nodes[i]
		var t: String = n[0]
		counts[t] = int(counts.get(t, 0)) + 1
		out.append({"id": "%d_%s_%d" % [kingdom, t, counts[t]], "kingdom": kingdom, "type": t,
			"pos": Vector2(n[1], n[2]), "index": i})
	return out

static func capital(kingdom: int) -> Dictionary:
	return nodes(kingdom)[0]

## Caminos del reino: pares [i, j] de índices (sin repetir). Vecinos más cercanos + unión mínima.
static func edges(kingdom: int) -> Array:
	var ns := nodes(kingdom)
	var pairs := {}
	for i in ns.size():
		var others := range(ns.size()).filter(func(j): return j != i)
		others.sort_custom(func(a, b): return ns[i].pos.distance_to(ns[a].pos) < ns[i].pos.distance_to(ns[b].pos))
		for j in others.slice(0, NEIGHBORS):
			pairs[_key(i, j)] = [mini(i, j), maxi(i, j)]
	# Unir componentes sueltas por el par más cercano entre ellas.
	while true:
		var comp := _components(ns.size(), pairs.values())
		if comp.size() <= 1:
			break
		var best := []
		var best_d := INF
		for a in comp[0]:
			for c in range(1, comp.size()):
				for b in comp[c]:
					var d: float = ns[a].pos.distance_to(ns[b].pos)
					if d < best_d:
						best_d = d
						best = [mini(a, b), maxi(a, b)]
		pairs[_key(best[0], best[1])] = best
	return pairs.values()

## Tiempo de viaje (horas de juego) entre dos lugares del mismo reino: la distancia en el mapa.
const HOURS_PER_MAP_WIDTH := 30.0
static func travel_hours(kingdom: int, a: int, b: int) -> float:
	var ns := nodes(kingdom)
	return maxf(1.0, ns[a].pos.distance_to(ns[b].pos) * HOURS_PER_MAP_WIDTH)

static func _key(i: int, j: int) -> String:
	return "%d-%d" % [mini(i, j), maxi(i, j)]

static func _components(n: int, edge_list: Array) -> Array:
	var adj := {}
	for i in n:
		adj[i] = []
	for e: Array in edge_list:
		adj[e[0]].append(e[1])
		adj[e[1]].append(e[0])
	var seen := {}
	var out := []
	for i in n:
		if seen.has(i):
			continue
		var comp := []
		var stack := [i]
		seen[i] = true
		while not stack.is_empty():
			var x: int = stack.pop_back()
			comp.append(x)
			for y in adj[x]:
				if not seen.has(y):
					seen[y] = true
					stack.append(y)
		out.append(comp)
	return out

## Reinos con puerto (se puede viajar por mar entre ellos).
static func has_port(kingdom: int) -> bool:
	return nodes(kingdom).any(func(n): return n.type == "puerto")
