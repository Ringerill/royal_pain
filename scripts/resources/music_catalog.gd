extends RefCounted
# Qué música suena en cada contexto. Uso: const MusicCatalog = preload("res://scripts/resources/music_catalog.gd")
# Las pistas están en assets/music/. Las «mk_» son de Kevin MacLeod (incompetech.com, CC BY 4.0; créditos en
# assets/music/CREDITOS.txt); las demás, generadas (tools/generate_music.py y tools/generate_music_extra.py).
# En el mapa y el castillo se suma la variación de la cultura del lugar: map_<cultura>, castle_<cultura>.

# Orden = NameCatalog.Culture.
const CULTURE_KEYS := ["franca", "inglesa", "castellana", "imperial", "romana", "prusiana", "italiana", "borgonona", "aragonesa"]
const CULTURE_WEIGHT := 1   # la pieza de la cultura del lugar, una más entre las demás

const POOLS := {
	"menu": ["mk_teller"],
	"map": ["mk_achaidh", "mk_angevin"],
	"travel": ["mk_folk_round", "mk_lord_land"],
	"castle": ["mk_feast", "mk_thatched"],
	"court": ["mk_pippin", "mk_minstrel"],
	"duel": ["mk_clash", "mk_celtic"],
	"battle": ["mk_five_armies", "mk_heroic_age", "mk_prelude"],
	"mourning": ["mk_dark_times", "mourning_a", "mourning_b"],
	"captivity": ["mk_dark_times", "captivity_a", "captivity_b"],
}
# Estilo «Original» (Settings.audio_style = 1): las pistas generadas por el juego.
const ORIGINAL_POOLS := {
	"menu": ["menu"],
	"map": ["map", "map_b"],
	"travel": ["travel_a", "travel_b", "travel_c"],
	"castle": ["castle", "castle_b"],
	"court": ["court_a", "court_b"],
	"duel": ["duel", "duel_b", "duel_c"],
	"battle": ["battle", "battle_b", "battle_c"],
	"mourning": ["mourning_a", "mourning_b"],
	"captivity": ["captivity_a", "captivity_b"],
}
static var original := false   # lo pone Music según Settings.audio_style

# Contextos que suman la pieza de la cultura: contexto -> prefijo del archivo.
const CULTURE_PREFIX := {"map": "map_", "travel": "map_", "castle": "castle_"}
# Contextos de combate: la pista no cambia a mitad de pelea (su capa de tensión va a tempo).
const NO_ROTATION := ["menu", "duel", "battle"]
const STINGS := ["sting_victory_a", "sting_victory_b", "sting_victory_c"]

# Escena -> contexto. Las escenas que no aparecen conservan lo que suena.
const SCENE_CONTEXT := {
	"main_menu": "menu", "new_game": "menu", "character_creation": "menu", "character_summary": "menu",
	"save_slots": "menu", "fighter_select": "menu",
	"map": "map", "relations": "court", "castle_interior": "castle",
	"combat": "duel", "rpg_battle": "duel", "battle": "battle", "succession": "mourning",
}

static func culture_key(culture: int) -> String:
	return CULTURE_KEYS[culture] if culture >= 0 and culture < CULTURE_KEYS.size() else ""

## Pistas candidatas (con repeticiones como peso). exists filtra las que no están en disco.
static func pool(context: String, culture: int, exists: Callable = Callable()) -> Array[String]:
	var out: Array[String] = []
	var ck := culture_key(culture)
	if CULTURE_PREFIX.has(context) and not ck.is_empty():
		var name: String = CULTURE_PREFIX[context] + ck
		for i in CULTURE_WEIGHT:
			out.append(name)
	for t: String in (ORIGINAL_POOLS if original else POOLS).get(context, []):
		out.append(t)
	if exists.is_valid():
		out = out.filter(func(t: String) -> bool: return exists.call(t))
	return out

## Elige una pista del contexto sin repetir la última (si hay alternativa).
static func pick(context: String, culture: int, last: String, exists: Callable = Callable()) -> String:
	var candidates := pool(context, culture, exists)
	if candidates.is_empty():
		return ""
	var fresh := candidates.filter(func(t: String) -> bool: return t != last)
	var from: Array = fresh if not fresh.is_empty() else candidates
	return from[randi() % from.size()]
