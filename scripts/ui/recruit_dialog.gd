extends Control
# Ventana para quien puede pasar a ser «de los tuyos»: un enemigo vencido que quiere unirse a ti
# ("join"), uno al que puedes encerrar ("capture") o alguien que rescatas en una expedición ("rescue").
# A los genéricos se les pone nombre (propuesto, editable); se puede guardar entre tus personajes.
# Al cerrarse emite `done(texto)`.
#   var d = load("res://scripts/ui/recruit_dialog.gd").open(host, personaje, "join")
#   var text: String = await d.done

signal done(text: String)

const RecruitRules = preload("res://scripts/resources/recruit_rules.gd")
const PORTRAIT := Vector2(120, 170)

var character: Character
var mode := "join"
var _first: LineEdit
var _last: LineEdit
var _save: CheckBox

static func open(host: Node, c: Character, how: String) -> Control:
	var d: Control = load("res://scripts/ui/recruit_dialog.gd").new()
	d.character = c
	d.mode = how
	host.add_child(d)
	return d

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 80
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	panel.add_child(body)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = PORTRAIT
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = character.get_portrait()
	body.add_child(portrait)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	body.add_child(v)
	var generic := RecruitRules.is_generic(character)
	var who := "Un enemigo vencido" if generic else character.full_name()
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	match mode:
		"join": title.text = "%s quiere unirse a ti" % who
		"capture": title.text = "%s está a tu merced" % who
		_: title.text = "Rescatas a %s" % who
	v.add_child(title)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 10)
	v.add_child(stats)
	StatIcons.pair(stats, "nivel", str(character.level), 16)
	StatIcons.pair(stats, "vida", "%d/%d" % [character.current_health, character.max_health], 16)
	StatIcons.pair(stats, "combate", str(character.combat), 16)
	StatIcons.pair(stats, "defensa", str(character.defense), 16)
	if generic:   # hay que darle un nombre para que sea alguien
		var names := RecruitRules.suggested_name(character)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		v.add_child(row)
		_first = LineEdit.new()
		_first.text = names[0]
		_first.placeholder_text = "Nombre"
		_first.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(_first)
		_last = LineEdit.new()
		_last.text = names[1]
		_last.placeholder_text = "Apellido"
		_last.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(_last)
	_save = CheckBox.new()
	_save.text = "Guardar entre mis personajes"
	_save.tooltip_text = "Aparecerá en «Mis personajes», Nueva partida y Duelo de práctica."
	v.add_child(_save)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 6)
	buttons.add_theme_constant_override("v_separation", 6)
	v.add_child(buttons)
	match mode:
		"join":
			_button(buttons, "Aceptarlo en tu séquito", _do_join, true)
			_button(buttons, "Rechazarlo", _do_leave)
		"capture":
			_button(buttons, "Encerrarlo", _do_capture, true)
			_button(buttons, "Dejarlo ir", _do_leave)
		_:
			_button(buttons, "Que se una a tu séquito", _do_join, true)
			_button(buttons, "Hacerlo siervo", _do_enslave).tooltip_text = "Cuesta honor."
			_button(buttons, "Liberarlo", _do_free).tooltip_text = "Honor +%d, fama +%d." % [RecruitRules.FREE_HONOR, RecruitRules.FREE_FAME]

func _button(parent: Node, text: String, cb: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	if primary:
		b.theme_type_variation = &"PrimaryButton"
		b.grab_focus.call_deferred()
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

## Le pone nombre (si es un genérico) y le abre una ficha en el mundo.
func _person() -> Relationship:
	if RecruitRules.is_generic(character):
		return RecruitRules.make_person(character, _first.text, _last.text)
	var RD := get_node("/root/RelationsData")
	var r: Relationship = RD.get_relation(character.full_name())
	if r == null:
		r = Relationship.new()
		r.person_name = character.full_name()
		r.kind = Relationship.Kind.PUEBLO
		r.kingdom = -1
		r.character = character
		RD.relations.append(r)
	return r

func _saved_note() -> String:
	if _save.button_pressed and not CharacterLoader.save_npc(character).is_empty():
		return " Lo guardas entre tus personajes."
	return ""

func _do_join() -> void:
	var r := _person()
	var affection := RecruitRules.RESCUE_AFFECTION if mode == "rescue" else RecruitRules.JOIN_AFFECTION
	_finish(RecruitRules.join(r, affection) + _saved_note())

func _do_capture() -> void:
	_person()
	_finish(RecruitRules.imprison(character) + _saved_note())

func _do_enslave() -> void:
	_person()
	_finish(RecruitRules.enslave(character) + _saved_note())

func _do_free() -> void:
	_finish(RecruitRules.release(character) + _saved_note())

func _do_leave() -> void:
	_finish("")

func _finish(text: String) -> void:
	done.emit(text)
	queue_free()
