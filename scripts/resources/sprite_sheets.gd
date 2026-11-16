class_name SpriteSheets
extends RefCounted
# Hojas de sprites de combate (assets/battle/sprite_sheets/, reglas en docs/sprites/REGLAS.md):
# 6×6 celdas, 34 fotogramas (35 y 36 vacíos), mirando a la izquierda en vista tres cuartos.
# La hoja de un personaje se deduce de su retrato:
#   portraits/Characters/Female/woman1.png   -> sprite_sheets/characters/female/woman1.png
#   portraits/Enemies/E-Male/E-M-Bandit01.png -> sprite_sheets/enemies/male/e_m_bandit01.png

const DIR := "res://assets/battle/sprite_sheets/"
const COLS := 6
const ROWS := 6
# Acción -> fotogramas (numerados desde 1, de izquierda a derecha y de arriba abajo).
const ACTIONS := {
	"reposo": [1, 2, 3], "ataque": [4, 5, 6], "distancia": [7, 8, 9], "golpe": [10, 11, 12],
	"defensa": [13, 14, 15], "cansancio": [16, 17, 18], "derrota": [19, 20, 21], "cabalgar": [22, 23, 24],
	"distancia_montada": [25, 26, 27], "ataque_montado": [28, 29, 30], "caida": [31, 32, 33], "dash": [34],
}
static var _sheet_cache := {}
static var _frame_cache := {}

## Ruta de la hoja de sprites de un personaje ("" si no tiene).
static func sheet_path(c: Character) -> String:
	if c == null:
		return ""
	var tex := c.get_portrait()
	if tex == null or tex.resource_path.is_empty():
		return ""
	var src := tex.resource_path
	if _sheet_cache.has(src):
		return _sheet_cache[src]
	var out := ""
	var file := src.get_file().to_lower()
	var low := src.to_lower()
	var sub := ""
	if "/portraits/characters/female/" in low:
		sub = "characters/female/"
	elif "/portraits/characters/male/" in low:
		sub = "characters/male/"
	elif "/portraits/enemies/e-female/" in low:
		sub = "enemies/female/"
		file = file.replace("-", "_")
	elif "/portraits/enemies/e-male/" in low:
		sub = "enemies/male/"
		file = file.replace("-", "_")
	if not sub.is_empty() and ResourceLoader.exists(DIR + sub + file):
		out = DIR + sub + file
	_sheet_cache[src] = out
	return out

static func has_sheet(c: Character) -> bool:
	return not sheet_path(c).is_empty()

## Un fotograma (1..34) de la hoja del personaje como AtlasTexture; null si no tiene hoja.
static func frame(c: Character, n: int) -> Texture2D:
	var path := sheet_path(c)
	if path.is_empty():
		return null
	var key := "%s#%d" % [path, n]
	if _frame_cache.has(key):
		return _frame_cache[key]
	var sheet: Texture2D = load(path)
	var cw := sheet.get_width() / COLS
	var ch := sheet.get_height() / ROWS
	var i := clampi(n, 1, COLS * ROWS) - 1
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = Rect2((i % COLS) * cw, (i / COLS) * ch, cw, ch)
	_frame_cache[key] = at
	return at

static func action_frames(c: Character, action: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for n in ACTIONS.get(action, [1]):
		var t := frame(c, n)
		if t != null:
			out.append(t)
	return out
