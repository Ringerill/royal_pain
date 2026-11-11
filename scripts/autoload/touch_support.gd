extends Node
# Autoload "TouchSupport": lo que el ratón da gratis y el dedo no.
#   - Mantener pulsado LONG_PRESS segundos sobre cualquier control muestra su ayuda (tooltip_text, suyo o
#     de un contenedor). Al levantar el dedo no se pulsa el botón; el siguiente toque cierra la ayuda.
#   - En pantallas pequeñas (móvil) la interfaz se amplía un poco (SMALL_SCREEN_SCALE).
# Solo actúa en dispositivos táctiles; en PC no hace nada.

const LONG_PRESS := 0.5
const MOVE_TOLERANCE := 14.0          # píxeles que el dedo puede moverse sin cancelar la pulsación larga
const SMALL_SCREEN_INCHES := 7.0      # por debajo (diagonal), es un móvil...
const SMALL_SCREEN_SCALE := 1.2       # ...y la interfaz se amplía
const MAX_WIDTH := 420.0

var enabled := false
var _press_pos := Vector2.ZERO
var _pressing := false
var _timer: Timer
var _layer: CanvasLayer
var _bubble: PanelContainer
var _label: Label
var _swallow_release := false

func _ready() -> void:
	enabled = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	if not enabled:
		return
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = LONG_PRESS
	_timer.timeout.connect(_on_long_press)
	add_child(_timer)
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child(_layer)
	_bubble = PanelContainer.new()
	_bubble.visible = false
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = MAX_WIDTH
	_bubble.add_child(_label)
	_layer.add_child(_bubble)
	_apply_scale.call_deferred()

## Amplía la interfaz en móviles: con «canvas_items» la ventana se escala; el factor extra agranda textos y botones.
func _apply_scale() -> void:
	var dpi := float(DisplayServer.screen_get_dpi())
	if dpi <= 0.0:
		return
	var inches := Vector2(DisplayServer.screen_get_size()).length() / dpi
	if inches < SMALL_SCREEN_INCHES:
		get_window().content_scale_factor = SMALL_SCREEN_SCALE

func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			if _bubble.visible:   # un toque con la ayuda abierta solo la cierra
				_hide()
				_swallow_release = true
				get_viewport().set_input_as_handled()
				return
			_press_pos = event.position
			_pressing = true
			_timer.start()
		else:
			_pressing = false
			_timer.stop()
			if _swallow_release:
				_swallow_release = false
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == 0 and _pressing:
		if event.position.distance_to(_press_pos) > MOVE_TOLERANCE:
			_pressing = false
			_timer.stop()
	elif event is InputEventMouseButton and _swallow_release:
		get_viewport().set_input_as_handled()   # el clic emulado del toque tampoco debe pulsar nada

func _on_long_press() -> void:
	if not _pressing:
		return
	var text := help_at()
	if text.is_empty():
		return
	_swallow_release = true   # al levantar el dedo no se pulsa el botón
	_show(text)

## La ayuda del control bajo el dedo (o de algún contenedor suyo), "" si no hay.
func help_at() -> String:
	var c: Control = get_viewport().gui_get_hovered_control()
	while c != null:
		if not c.tooltip_text.is_empty():
			return c.tooltip_text
		c = c.get_parent() as Control
	return ""

func _show(text: String) -> void:
	_label.text = text
	_bubble.reset_size()
	_bubble.visible = true
	var vp := get_viewport().get_visible_rect().size
	var size := _bubble.get_combined_minimum_size()
	var pos := _press_pos + Vector2(-size.x / 2.0, -size.y - 40.0)
	pos.x = clampf(pos.x, 8.0, vp.x - size.x - 8.0)
	if pos.y < 8.0:
		pos.y = _press_pos.y + 40.0
	_bubble.position = pos

func _hide() -> void:
	_bubble.visible = false
