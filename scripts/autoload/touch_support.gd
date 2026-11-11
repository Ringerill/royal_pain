extends Node
# Autoload "TouchSupport": lo que el ratón da gratis y el dedo no.
#   - Mantener pulsado LONG_PRESS segundos sobre cualquier control muestra su ayuda (tooltip_text, suyo o
#     de un contenedor). Al levantar el dedo no se pulsa el botón; el siguiente toque cierra la ayuda.
#   - Las ventanas centradas (CenterContainer > panel) que no caben en la pantalla se encogen hasta caber,
#     para que sus botones siempre se puedan pulsar. Esto actúa también en PC (ventanas pequeñas).
#   - El gesto «atrás» de Android equivale a Esc (no cierra el juego).
# La pulsación larga solo actúa en dispositivos táctiles.

const LONG_PRESS := 0.5
const MOVE_TOLERANCE := 14.0          # píxeles que el dedo puede moverse sin cancelar la pulsación larga
const FIT_MARGIN := 0.96              # fracción de la pantalla que puede ocupar una ventana
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
	get_tree().node_added.connect(_on_node_added)
	get_viewport().size_changed.connect(_refit_all)
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

# --- Ventanas que no caben -------------------------------------------------------------------------

var _fitted: Array[Control] = []

func _on_node_added(n: Node) -> void:
	if not (n is Control and n.get_parent() is CenterContainer):
		return
	var center: CenterContainer = n.get_parent()
	# Solo ventanas: un CenterContainer a pantalla completa (no los pequeños dentro de un panel).
	if center.anchor_right < 1.0 or center.anchor_bottom < 1.0 or center.anchor_left > 0.0 or center.anchor_top > 0.0:
		return
	var c: Control = n
	# Si el panel es más grande, el contenedor crece por igual a ambos lados (no solo hacia abajo)
	# y así el centro sigue siendo el de la pantalla.
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	if c in _fitted:
		return
	_fitted.append(c)
	# El contenedor devuelve la escala a 1 cada vez que ordena: se vuelve a encoger después.
	# Al salir del árbol se desconecta (si no, la señal llamaría con el panel ya liberado).
	var refit := func(): fit.call_deferred(c)
	center.sort_children.connect(refit)
	c.tree_exiting.connect(func():
		_fitted.erase(c)
		if is_instance_valid(center) and center.sort_children.is_connected(refit):
			center.sort_children.disconnect(refit), CONNECT_ONE_SHOT)
	fit.call_deferred(c)

func _refit_all() -> void:
	for c in _fitted:
		fit.call_deferred(c)

## Encoge (escala) la ventana si es más grande que la pantalla; la CenterContainer la sigue centrando.
func fit(c: Control) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree():
		return
	var vp := c.get_viewport_rect().size * FIT_MARGIN
	var k := 1.0
	if c.size.x > 0.0 and c.size.y > 0.0:
		k = minf(1.0, minf(vp.x / c.size.x, vp.y / c.size.y))
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2(k, k)

## Gesto «atrás» de Android: en vez de cerrar el juego (quit_on_go_back = false), hace lo que Esc
## (ui_cancel): cerrar un panel, volver al menú anterior del combate, cancelar un objetivo…
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _bubble != null and _bubble.visible:
			_hide()
			return
		var ev := InputEventAction.new()
		ev.action = &"ui_cancel"
		ev.pressed = true
		Input.parse_input_event(ev)
		var up := InputEventAction.new()
		up.action = &"ui_cancel"
		up.pressed = false
		Input.parse_input_event.call_deferred(up)

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
