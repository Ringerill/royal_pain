extends CanvasLayer
# Autoload — registrar como "SceneFade"
# Cada pantalla nueva aparece con un fundido corto desde negro, en vez de un corte seco.
# Al entrar en un combate o una batalla, en cambio, se abren dos telones (izquierda y derecha) con un
# choque de acero: se nota que empieza la pelea.

const FADE_TIME := 0.3
const CURTAIN_TIME := 0.45
const CURTAIN_SCENES := ["rpg_battle", "battle", "combat"]

var _rect: ColorRect
var _left: ColorRect
var _right: ColorRect
var _tween: Tween

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = _panel()
	_left = _panel()
	_right = _panel()
	get_tree().scene_changed.connect(_on_scene_changed)

func _panel() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color("0d0906")
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.modulate.a = 0.0
	add_child(r)
	return r

func _on_scene_changed() -> void:
	if _tween:
		_tween.kill()
	var scene := get_tree().current_scene
	var key := scene.scene_file_path.get_file().get_basename() if scene != null else ""
	if key in CURTAIN_SCENES and not _reduced():
		_curtains()
		return
	_left.modulate.a = 0.0
	_right.modulate.a = 0.0
	_rect.modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_property(_rect, "modulate:a", 0.0, FADE_TIME).set_trans(Tween.TRANS_SINE)

## Dos telones que se abren hacia los lados.
func _curtains() -> void:
	var w := get_viewport().get_visible_rect().size.x
	_rect.modulate.a = 0.0
	for r: ColorRect in [_left, _right]:
		r.modulate.a = 1.0
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.offset_top = 0
		r.offset_bottom = 0
	_left.anchor_right = 0.5
	_left.offset_left = 0
	_left.offset_right = 0
	_right.anchor_left = 0.5
	_right.offset_left = 0
	_right.offset_right = 0
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.play("clash", -8.0)   # un choque de acero (la batalla ya toca su cuerno)
	_tween = create_tween().set_parallel()
	_tween.tween_property(_left, "offset_left", -w * 0.5, CURTAIN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(_left, "offset_right", -w * 0.5, CURTAIN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(_right, "offset_left", w * 0.5, CURTAIN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(_right, "offset_right", w * 0.5, CURTAIN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

func _reduced() -> bool:
	var s := get_node_or_null("/root/Settings")
	return s != null and s.reduced_effects
