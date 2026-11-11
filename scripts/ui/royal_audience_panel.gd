extends Control
# Asamblea con el gobernante de un reino (RoyalCourt). La audiencia ya está concedida: un gesto para
# ganarte su favor y un favor que pedirle.
#   RoyalAudiencePanel.open(self, gobernante)   # al cerrarse deja el resultado en get_meta("result")

const PORTRAIT_SIZE := Vector2(150, 210)

var ruler: Relationship
var _gestures: VBoxContainer
var _favors: VBoxContainer
var _reply: Label
var _close: Button
var _log: Array[String] = []
var _favor_used := false

static func open(host: Node, r: Relationship) -> Control:
	var panel: Control = load("res://scripts/ui/royal_audience_panel.gd").new()
	panel.ruler = r
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
	panel.custom_minimum_size = Vector2(860, 460)
	center.add_child(panel)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	panel.add_child(body)
	var c: Character = ruler.character
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(PORTRAIT_SIZE.x, 0)
	body.add_child(left)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = c.get_portrait() if c != null else null
	left.add_child(portrait)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	body.add_child(right)
	_label(right, "Asamblea con %s" % ruler.person_name, "HeaderLabel")
	_label(right, "%s · afinidad contigo %d" % [KingdomEnums.kingdom_name(ruler.kingdom), ruler.affinity], "MutedLabel")
	_label(right, "Gánate su favor (un gesto):", "SubheaderLabel")
	_gestures = VBoxContainer.new()
	right.add_child(_gestures)
	_gestures.add_child(_button("Presentar tus respetos", "Afinidad +%d." % (RoyalCourt.RESPECT_BASE + GameManager.player_character.charisma / 3), "",
		func(): return RoyalCourt.respects(ruler), _gestures))
	_gestures.add_child(_button("Ofrecer un presente (%d oro)" % RoyalCourt.GIFT_COST, "Afinidad según tu Carisma.", RoyalCourt.gift_blocker(),
		func(): return RoyalCourt.gift(ruler), _gestures))
	_gestures.add_child(_button("Halagarle", "Depende de tu Carisma: puede sonar a adulación.", "",
		func(): return RoyalCourt.flatter(ruler), _gestures))
	_label(right, "Pídele un favor (uno):", "SubheaderLabel")
	_favors = VBoxContainer.new()
	right.add_child(_favors)
	_build_favors()
	_reply = _label(right, "", "")
	_reply.visible = false
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	_close = Button.new()
	_close.text = "Retirarte"
	_close.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close.pressed.connect(queue_free)
	right.add_child(_close)
	UiAnim.fade_in(panel, 0.2)

func _build_favors() -> void:
	for ch in _favors.get_children():
		ch.queue_free()
	for f: Array in RoyalCourt.favors(ruler):
		_favors.add_child(_button(f[0], f[1], f[2], f[3], _favors))

## Un botón que, al pulsarse, ejecuta la acción y cierra su grupo (un gesto y un favor por asamblea).
func _button(text: String, hint: String, reason: String, action: Callable, group: VBoxContainer) -> Button:
	var b := Button.new()
	b.text = text if reason.is_empty() else "%s — %s" % [text, reason]
	b.tooltip_text = hint
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = not reason.is_empty()
	b.pressed.connect(func():
		_log.append(str(action.call()))
		set_meta("result", "\n".join(_log))
		_reply.text = "\n".join(_log)
		_reply.visible = true
		for ch in group.get_children():
			ch.queue_free()
		if group == _favors:
			_favor_used = true
		elif not _favor_used:
			_build_favors.call_deferred())   # la afinidad nueva puede abrir favores
	return b

func _label(parent: Node, text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not variation.is_empty():
		label.theme_type_variation = StringName(variation)
	parent.add_child(label)
	return label

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
