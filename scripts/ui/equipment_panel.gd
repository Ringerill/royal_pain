extends Control
# Equipo del grupo: a la izquierda quién (tú, tu cónyuge y tu séquito); a la derecha sus ranuras con
# lo que lleva (tipo de daño o armadura y bonos, con iconos) y, debajo, el almacén del grupo.
# «Quitar» guarda la pieza en el almacén; «Equipar» se la pone (la que llevaba vuelve al almacén).
#   load("res://scripts/ui/equipment_panel.gd").open(host, personaje_inicial)

const SLOTS := ["Arma", "Armadura", "Escudo", "Montura", "Accesorio"]
const FACE := 40

var selected: Character
var _people: VBoxContainer
var _slots: VBoxContainer
var _stash: VBoxContainer
var _title: HBoxContainer
var _feedback: Label

static func open(host: Node, who: Character = null) -> Control:
	var panel: Control = load("res://scripts/ui/equipment_panel.gd").new()
	panel.selected = who
	host.add_child(panel)
	return panel

func _ready() -> void:
	if selected == null:
		selected = GameManager.player_character
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
	panel.custom_minimum_size = Vector2(980, 520)
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)
	var head := Label.new()
	head.text = "Equipo"
	head.theme_type_variation = &"HeaderLabel"
	root.add_child(head)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)
	var left := ScrollContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(left)
	_people = VBoxContainer.new()
	_people.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_people.add_theme_constant_override("separation", 4)
	left.add_child(_people)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	body.add_child(right)
	_title = HBoxContainer.new()
	right.add_child(_title)
	_slots = VBoxContainer.new()
	_slots.add_theme_constant_override("separation", 4)
	right.add_child(_slots)
	var store_head := Label.new()
	store_head.text = "Almacén del grupo"
	store_head.theme_type_variation = &"SubheaderLabel"
	right.add_child(store_head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_stash = VBoxContainer.new()
	_stash.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stash.add_theme_constant_override("separation", 4)
	scroll.add_child(_stash)
	var bottom := HBoxContainer.new()
	root.add_child(bottom)
	_feedback = Label.new()
	_feedback.theme_type_variation = &"MutedLabel"
	_feedback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_feedback)
	var close := Button.new()
	close.text = "Cerrar"
	close.pressed.connect(queue_free)
	bottom.add_child(close)
	_rebuild()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()

func _rebuild() -> void:
	for box: Node in [_people, _slots, _stash, _title]:
		for ch in box.get_children():
			ch.queue_free()
	var members: Array[Character] = PartyData.gear_members()
	if not selected in members:
		selected = members[0]
	for c: Character in members:
		var b := Button.new()
		b.text = c.full_name()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_pressed = c == selected
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var tex := c.get_face()
		if tex != null:
			b.icon = tex
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", FACE)
		b.pressed.connect(func():
			selected = c
			_rebuild())
		_people.add_child(b)
	StatIcons.named(_title, selected, selected.full_name(), 18)
	var stats := StatIcons.attributes(null, selected, 16)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.alignment = BoxContainer.ALIGNMENT_END
	_title.add_child(stats)
	for slot: String in SLOTS:
		_slots.add_child(_slot_row(slot))
	if PartyData.stash.is_empty():
		var empty := Label.new()
		empty.text = "Vacío. Lo que quites a alguien queda aquí."
		empty.theme_type_variation = &"MutedLabel"
		_stash.add_child(empty)
	for e: Equipment in PartyData.stash:
		_stash.add_child(_stash_row(e))

func _item_in(c: Character, slot: String) -> Equipment:
	for e: Equipment in c.equipment:
		if e.slot == slot:
			return e
	return null

func _slot_row(slot: String) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var slot_l := Label.new()
	slot_l.text = slot
	slot_l.custom_minimum_size = Vector2(90, 0)
	slot_l.theme_type_variation = &"MutedLabel"
	row.add_child(slot_l)
	var e := _item_in(selected, slot)
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_l := Label.new()
	name_l.text = e.equipment_name if e != null else "—"
	info.add_child(name_l)
	if e != null:
		StatIcons.item_badges(info, e, 16)
		var take := Button.new()
		take.text = "Quitar"
		take.tooltip_text = "Al almacén del grupo."
		take.pressed.connect(func():
			_feedback.text = PartyData.store(selected, e)
			_rebuild())
		row.add_child(take)
	return card

func _stash_row(e: Equipment) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var slot_l := Label.new()
	slot_l.text = e.slot
	slot_l.custom_minimum_size = Vector2(90, 0)
	slot_l.theme_type_variation = &"MutedLabel"
	row.add_child(slot_l)
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_l := Label.new()
	name_l.text = e.equipment_name
	info.add_child(name_l)
	StatIcons.item_badges(info, e, 16)
	var put := Button.new()
	put.text = "Equipar a %s" % selected.first_name
	var current := _item_in(selected, e.slot)
	put.tooltip_text = ("Cambia %s por esta pieza." % current.equipment_name) if current != null else "Ranura libre."
	put.pressed.connect(func():
		_feedback.text = PartyData.equip_from_stash(selected, e)
		_rebuild())
	row.add_child(put)
	return card
