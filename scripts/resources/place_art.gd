class_name PlaceArt
extends RefCounted
# Rediseño v2, fase 5: escenas de lugar (assets/dialogue/) y expresiones de los retratos.
#   Escenas con variantes: dialogue/<lugar>/<lugar>[_autumn|_winter][_night][_destroyed].png
#   Escenas únicas:        dialogue/places/<lugar>.png
#   Expresiones:           portraits/Expressions/Characters/<Sexo>/<retrato>_expresiones.png (rejilla 5×2)
#                          portraits/Expressions/Enemies/<E-Sexo>/<retrato>_busto.png (un busto)

const DIR := "res://assets/dialogue/"
const VARIANT_PLACES := ["bandit_camp", "bridge", "camp", "castle_hallway", "city_inside", "city_outside",
	"council_meeting", "port", "road"]
const SINGLE_PLACES := ["back_alley", "cave", "cell", "church", "dungeon", "home_hallway", "library", "room",
	"shop", "tavern", "throne", "tower", "wedding"]

# Expresiones (orden de la hoja, de izquierda a derecha y de arriba abajo).
const EXPRESSIONS := ["neutral", "serio", "sorpresa", "enfado", "triste", "furia", "verguenza", "alegre", "dolor", "ternura"]
const EXPR_COLS := 5
const EXPR_ROWS := 2
# Tono de una frase → expresión (palabras clave sencillas; lo demás, neutral).
const TONE_WORDS := {
	"alegre": ["gracias", "bienvenid", "me alegra", "excelente", "estupendo", "¡bien", "jaja", "feliz", "buen viaje"],
	"enfado": ["fuera", "largo", "maldit", "cómo te atreves", "no te metas", "basta"],
	"triste": ["lo siento", "por desgracia", "lamento", "murió", "perd", "triste"],
	"sorpresa": ["¿de verdad", "¡vaya", "¡oh", "no puede ser", "increíble"],
	"serio": ["escucha", "cuidado", "atento", "el precio", "trato", "no hay"],
	"ternura": ["querid", "amor", "cariño"],
	"verguenza": ["perdona", "disculpa", "no sé qué decir"],
}

static var _cache := {}

## Fondo de un lugar con la estación y la noche actuales (cae a la versión base si falta la variante).
static func scene(place: String, season_suffix: String = "", night: bool = false, destroyed: bool = false) -> Texture2D:
	var key := "%s|%s|%s|%s" % [place, season_suffix, night, destroyed]
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	if place in SINGLE_PLACES:
		tex = _try(DIR + "places/%s.png" % place)
	else:
		var tries := []
		var nt := "_night" if night else ""
		var ds := "_destroyed" if destroyed else ""
		tries.append(place + season_suffix + nt + ds)
		tries.append(place + season_suffix + nt)
		tries.append(place + season_suffix)
		tries.append(place + nt)
		tries.append(place)
		for t in tries:
			tex = _try(DIR + "%s/%s.png" % [place, t])
			if tex != null:
				break
	_cache[key] = tex
	return tex

## Fondo según el momento actual del viaje (Journey).
static func scene_now(place: String) -> Texture2D:
	var tree := Engine.get_main_loop() as SceneTree
	var j := tree.root.get_node_or_null("Journey") if tree != null else null
	if j == null:
		return scene(place)
	return scene(place, j.season_suffix(), j.is_night())

static func _try(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null

# --- Expresiones ---

static func expression_path(c: Character) -> String:
	if c == null:
		return ""
	var tex := c.get_portrait()
	if tex == null or tex.resource_path.is_empty():
		return ""
	var src := tex.resource_path
	var file := src.get_file().get_basename()
	var low := src.to_lower()
	var out := ""
	if "/portraits/characters/female/" in low:
		out = "res://assets/portraits/Expressions/Characters/Female/%s_expresiones.png" % file
	elif "/portraits/characters/male/" in low:
		out = "res://assets/portraits/Expressions/Characters/Male/%s_expresiones.png" % file
	elif "/portraits/enemies/e-female/" in low:
		out = "res://assets/portraits/Expressions/Enemies/E-Female/%s_busto.png" % file
	elif "/portraits/enemies/e-male/" in low:
		out = "res://assets/portraits/Expressions/Enemies/E-Male/%s_busto.png" % file
	return out if ResourceLoader.exists(out) else ""

## Busto con la expresión pedida; sin hoja de expresiones, el retrato.
static func expression(c: Character, expr: String = "neutral") -> Texture2D:
	var path := expression_path(c)
	if path.is_empty():
		return c.get_portrait() if c != null else null
	var sheet: Texture2D = load(path)
	if path.ends_with("_busto.png"):
		return sheet
	var key := "%s#%s" % [path, expr]
	if _cache.has(key):
		return _cache[key]
	var i := maxi(0, EXPRESSIONS.find(expr))
	var cw := sheet.get_width() / EXPR_COLS
	var ch := sheet.get_height() / EXPR_ROWS
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = Rect2((i % EXPR_COLS) * cw, (i / EXPR_COLS) * ch, cw, ch)
	_cache[key] = at
	return at

## Expresión que encaja con el tono de una frase.
static func tone(text: String) -> String:
	var low := text.to_lower()
	for expr in TONE_WORDS:
		for w: String in TONE_WORDS[expr]:
			if w in low:
				return expr
	return "neutral"
