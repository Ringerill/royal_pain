class_name SpriteAnim
extends Node
# Anima la figura de un combatiente con su hoja de sprites (SpriteSheets) sobre un TextureRect.
# Reposo en bucle (cansancio si está agotado, cabalgar si va montado); las acciones se reproducen
# una vez y vuelven al reposo (o se quedan en el último fotograma: derrota).
# Montado: dibuja el caballo (assets/horses/, rejilla 3×4 de 512×256) detrás del jinete.

const FPS := 7.0
const HORSE_COLS := 3
const HORSE_ROWS := 4
const HORSE_IDLE := [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]     # paso
const HORSE_RUN := [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]      # galope
const HORSE_W := 1.55          # ancho del caballo respecto a la celda del jinete
const HORSE_Y := 0.6           # dónde empieza el caballo (fracción del alto del jinete)
const MOUNT_LIFT := 0.36       # cuánto sube la figura montada para que los cascos toquen el suelo
const MOUNTED := {"reposo": "cabalgar", "cansancio": "cabalgar", "ataque": "ataque_montado",
	"distancia": "distancia_montada", "golpe": "cabalgar", "defensa": "cabalgar", "dash": "cabalgar"}

var c: Character
var tex: TextureRect
var horse: TextureRect
var active := false: set = set_active
var mounted := false
var tired := false
var _action := "reposo"
var _loop := true
var _hold := false
var _t := 0.0
var _frames: Array[Texture2D] = []
var _horse_frames := {}

static func attach(t: TextureRect, ch: Character) -> SpriteAnim:
	var a := SpriteAnim.new()
	a.c = ch
	a.tex = t
	a.name = "SpriteAnim"
	t.add_child(a)
	a.set_process(false)
	return a

func set_active(on: bool) -> void:
	active = on
	set_process(on)
	if horse != null:
		horse.visible = on and mounted
	if on:
		_start(_idle(), true, false)
		_apply(0)

func set_mounted(on: bool) -> void:
	mounted = on and not RpgStats.horse_sheet(c).is_empty()
	if mounted and horse == null:
		var sheet: Texture2D = load(RpgStats.horse_sheet(c))
		var cw := sheet.get_width() / HORSE_COLS
		var ch := sheet.get_height() / HORSE_ROWS
		for cell in HORSE_IDLE + HORSE_RUN:
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(cell.x * cw, cell.y * ch, cw, ch)
			_horse_frames[cell] = at
		horse = TextureRect.new()
		horse.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		horse.stretch_mode = TextureRect.STRETCH_SCALE
		horse.mouse_filter = Control.MOUSE_FILTER_IGNORE
		horse.show_behind_parent = true
		tex.add_child(horse)
		tex.resized.connect(_place_horse)
	if horse != null:
		horse.visible = active and mounted
		_place_horse()
	if active:
		_start(_idle(), true, false)

## Reproduce una acción (SpriteSheets.ACTIONS) una vez; hold = quedarse en el último fotograma.
func play(action: String, hold := false) -> void:
	if not active:
		return
	_start(action, false, hold)

func is_idle() -> bool:
	return _loop

func _idle() -> String:
	if mounted:
		return "cabalgar"
	return "cansancio" if tired else "reposo"

func _start(action: String, loop: bool, hold: bool) -> void:
	if mounted:
		action = MOUNTED.get(action, action)
	_action = action
	_loop = loop
	_hold = hold
	_t = 0.0
	_frames = SpriteSheets.action_frames(c, action)

func _process(delta: float) -> void:
	if _frames.is_empty():
		return
	if _loop and _action != _idle() and _action in ["reposo", "cansancio", "cabalgar"]:
		_start(_idle(), true, false)   # cambió el cansancio o la montura
	_t += delta
	var i := int(_t * FPS)
	if i >= _frames.size():
		if _loop:
			i %= _frames.size()
		elif _hold:
			i = _frames.size() - 1
		else:
			_start(_idle(), true, false)
			i = 0
	_apply(i)

func _apply(i: int) -> void:
	if _frames.is_empty():
		return
	tex.texture = _frames[clampi(i, 0, _frames.size() - 1)]
	if horse != null and horse.visible:
		var run: bool = not _loop or _action.ends_with("montada") or _action == "ataque_montado"
		var cells: Array = HORSE_RUN if run else HORSE_IDLE
		horse.texture = _horse_frames[cells[int(_t * FPS) % cells.size()]]
		horse.flip_h = tex.flip_h

func _place_horse() -> void:
	if horse == null:
		return
	var s := tex.size
	var w := s.x * HORSE_W
	horse.size = Vector2(w, w * 0.5)
	horse.position = Vector2((s.x - w) * 0.5, s.y * HORSE_Y)
