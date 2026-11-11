class_name DuelPicker
extends Control
# Elegir a quién retar a duelo: la gente de tu zona (rivales primero) con su fuerza comparada con la
# tuya, y la opción de buscar a un desconocido de tu nivel. Elegir a alguien solo propone el reto:
# puede rechazarlo (RelationsData.challenge).
#   DuelPicker.open(host, RelationsData.duel_candidates(), func(r): ..., func(): ...)

const FACE := 44

var candidates: Array[Relationship] = []
var on_pick: Callable
var on_stranger: Callable

static func open(host: Node, list: Array[Relationship], pick: Callable, stranger: Callable) -> Control:
	var panel: DuelPicker = load("res://scripts/ui/duel_picker.gd").new()
	panel.candidates = list
	panel.on_pick = pick
	panel.on_stranger = stranger
	host.add_child(panel)
	return panel

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 60
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_label(box, "Retar a duelo", "HeaderLabel")
	_label(box, "Elige a quién retar. Puede rechazarte (por rango, miedo, prudencia, amistad o tu deshonra); proponerlo gasta 1 acción.", "MutedLabel")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 330)
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	if candidates.is_empty():
		_label(list, "No hay nadie en esta zona con quien batirse.", "MutedLabel")
	var player: Character = GameManager.player_character
	for r in candidates:
		list.add_child(_row(r, player))
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	box.add_child(bottom)
	var stranger := Button.new()
	stranger.text = "Buscar a un desconocido de tu nivel"
	stranger.tooltip_text = "Un aspirante que busca fama: siempre acepta."
	stranger.disabled = not GameManager.has_actions_remaining()
	stranger.pressed.connect(func():
		queue_free()
		on_stranger.call())
	bottom.add_child(stranger)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	var close := Button.new()
	close.text = "Cancelar"
	close.pressed.connect(queue_free)
	bottom.add_child(close)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()

func _row(r: Relationship, player: Character) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(FaceIcon.make(r.character, FACE, Color("c9584c") if r.kind == Relationship.Kind.RIVAL_DUELO else Color("8a7a5a"), false))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)
	var c := r.character
	var tag := " · rival" if r.kind == Relationship.Kind.RIVAL_DUELO else ""
	_label(info, "%s%s" % [r.person_name, tag], "")
	var gap: int = (c.combat + c.defense) - (player.combat + player.defense)
	var force := "parecida a la tuya"
	if gap >= 4:
		force = "mucho más fuerte"
	elif gap >= 2:
		force = "algo más fuerte"
	elif gap <= -4:
		force = "mucho más débil"
	elif gap <= -2:
		force = "algo más débil"
	_label(info, "%s · Nv %d · fuerza %s · afinidad %+d" % [c.role_title(), c.level, force, r.affinity], "MutedLabel")
	var btn := Button.new()
	btn.text = "Retar"
	var reason: String = RelationsData.can_challenge(r)
	btn.disabled = not reason.is_empty()
	btn.tooltip_text = reason if not reason.is_empty() else "Le propones el duelo: puede aceptarlo o rechazarlo."
	btn.pressed.connect(func():
		queue_free()
		on_pick.call(r))
	row.add_child(btn)
	return row

func _label(parent: Node, text: String, variation: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not variation.is_empty():
		l.theme_type_variation = variation
	parent.add_child(l)
	return l
