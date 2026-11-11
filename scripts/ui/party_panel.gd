extends Control
# Gestor de grupo: tú y tu gente (PartyData). Activos (hasta 4, tú siempre) y reserva; subir, bajar,
# activar y reservar; abre la ficha de cada uno (CompanionPanel) y su mejora (árbol de habilidades o
# LevelUpPanel). Se abre encima de cualquier pantalla:
#   const PartyPanel = preload("res://scripts/ui/party_panel.gd")
#   PartyPanel.open(self)

signal finished

const CompanionPanel = preload("res://scripts/ui/companion_panel.gd")
const LevelUpPanel = preload("res://scripts/ui/level_up_panel.gd")
const OccupationRules = preload("res://scripts/resources/occupation_rules.gd")
# Gancho: panel del árbol de habilidades del combate RPG (si existe, sustituye a LevelUpPanel).
const SKILL_TREE_PANEL := "res://scripts/ui/skill_tree_panel.gd"
const FACE_SIZE := 56
const ACTIVE_COLOR := Color("d4af5a")

var _body: VBoxContainer
var _focus_name := ""
var _focus_text := ""

static func open(host: Node) -> Control:
	var panel: Control = load("res://scripts/ui/party_panel.gd").new()
	host.add_child(panel)
	return panel

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 560)
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)
	_label(root, "Grupo", "HeaderLabel")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 470)
	root.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 6)
	scroll.add_child(_body)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(bottom)
	var close := Button.new()
	close.text = "Cerrar"
	close.theme_type_variation = &"PrimaryButton"
	close.pressed.connect(_close)
	bottom.add_child(close)
	_rebuild()
	UiAnim.fade_in(panel, 0.15)

func _rebuild() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var act := PartyData.active()
	var res := PartyData.reserve()
	_label(_body, "Activos (%d/%d)" % [act.size(), PartyData.MAX_ACTIVE], "HeaderLabel")
	for i in act.size():
		_row(act[i], true, i, act.size())
	_label(_body, "Reserva (%d)" % res.size(), "HeaderLabel")
	if res.is_empty():
		_label(_body, "Nadie. Invita gente a tu séquito.", "MutedLabel")
	for c in res:
		_row(c, false, 0, 0)
	_restore_focus()

func _row(c: Character, is_active: bool, index: int, count: int) -> void:
	var player := PartyData.is_player(c)
	var r := PartyData.relation_of(c)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.set_meta("who", c.full_name())
	_body.add_child(row)
	row.add_child(FaceIcon.make(c, FACE_SIZE, ACTIVE_COLOR if is_active else FaceIcon.FRAME_COLOR, false))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)
	StatIcons.named(info, c, c.full_name(), 16)
	# A la vista, solo lo esencial: nivel, arma, armadura, vida y estado. El resto, en la ayuda.
	var s := RpgStats.compute(c)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	info.add_child(line)
	StatIcons.pair(line, "nivel", str(c.level), STAT_ICON, "Nivel").modulate = Color(1, 1, 1, 0.85)
	line.add_child(SkillIcons.damage_icon(int(s.weapon), STAT_ICON))
	_tag(line, "%s ·" % RpgStats.DAMAGE_NAMES[int(s.weapon)])
	line.add_child(SkillIcons.armor_icon(int(s.armor), STAT_ICON))
	_tag(line, "%s ·" % RpgStats.ARMOR_NAMES[int(s.armor)])
	StatIcons.pair(line, "vida", "%d/%d" % [c.current_health, c.max_health], STAT_ICON).modulate = Color(1, 1, 1, 0.85)
	_tag(line, "· %s" % _state_text(c))
	var techs: Variant = _techniques(c)
	var loyal := "—" if player or r == null else LoyaltyData.bar_text(r.person_name)
	var job := "—"
	if r != null and RelationsData.has_occupation(r):
		job = OccupationRules.name_of(RelationsData.occupation_of(r))
	row.tooltip_text = "%s
Técnicas: %s%s%s" % [_equipment_text(c),
		"—" if techs == null or techs.is_empty() else ", ".join(techs.map(func(t): return str(t))),
		"" if player else "
Lealtad: %s" % loyal, "" if job == "—" else "
Oficio: %s" % job]
	info.tooltip_text = row.tooltip_text
	if is_active:
		_button(row, "Subir", c, index > 0, func(): PartyData.move(c, -1))
		_button(row, "Bajar", c, index < count - 1, func(): PartyData.move(c, 1))
		_button(row, "Reservar", c, not player, func(): PartyData.to_reserve(c))
	else:
		_button(row, "Activar", c, PartyData.active().size() < PartyData.MAX_ACTIVE, func(): PartyData.activate(c))
	if not player:
		var off := _button(row, "Oficial", c, true, func(): PartyData.set_officer(c, not PartyData.is_officer(c)))
		off.toggle_mode = true
		off.set_pressed_no_signal(PartyData.is_officer(c))
		off.tooltip_text = "Va de oficial en tu pelotón en las batallas campales."
	_button(row, "Gestionar", c, r != null, func(): _open_companion(r), false)
	_button(row, "Mejorar", c, player or ResourceLoader.exists(SKILL_TREE_PANEL), func(): _open_upgrade(c), false)

func _button(parent: Node, text: String, c: Character, enabled: bool, action: Callable, rebuild: bool = true) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.disabled = not enabled
	btn.focus_mode = Control.FOCUS_ALL
	btn.pressed.connect(func():
		_focus_name = c.full_name()
		_focus_text = text
		action.call()
		if rebuild:
			_rebuild())
	parent.add_child(btn)
	return btn

func _restore_focus() -> void:
	var first: Button = null
	for row in _body.get_children():
		if not row is HBoxContainer:
			continue
		for b in row.get_children():
			if b is Button and not b.disabled:
				if first == null:
					first = b
				if row.get_meta("who", "") == _focus_name and b.text == _focus_text:
					b.call_deferred("grab_focus")
					return
	if first != null:
		first.call_deferred("grab_focus")

# Técnicas del combate RPG (nombres) que conoce el personaje.
func _techniques(c: Character) -> Variant:
	return SkillTreeCatalog.available_techniques(c).map(func(n: Dictionary) -> String: return str(n.name))

const STAT_ICON := 16

## Estado: herido (con los meses que le quedan), cansado si le falta vida, o en forma.
func _state_text(c: Character) -> String:
	if c.is_wounded():
		return "herido (%d %s)" % [c.wound_months, "mes" if c.wound_months == 1 else "meses"]
	if c.current_health < c.max_health:
		return "magullado"
	return "en forma"

func _equipment_text(c: Character) -> String:
	var names: Array[String] = []
	for e in c.equipment:
		if e != null:
			names.append(e.equipment_name)
	return "Equipo: " + (", ".join(names) if not names.is_empty() else "nada")

func _open_companion(r: Relationship) -> void:
	if r == null:
		return
	var p := CompanionPanel.open(self, r)
	p.finished.connect(func(_t: String): _rebuild())

func _open_upgrade(c: Character) -> void:
	var p: Control
	if ResourceLoader.exists(SKILL_TREE_PANEL):
		var script: Script = load(SKILL_TREE_PANEL)
		p = script.call("open", self, c)
	elif PartyData.is_player(c):
		p = LevelUpPanel.open(self)
	if p != null:
		p.z_index = z_index + 10
		p.tree_exited.connect(func(): if is_inside_tree(): _rebuild())

func _close() -> void:
	finished.emit()
	queue_free()

## Texto de una sola línea dentro de una fila (sin ajuste: si no, se parte letra a letra).
func _tag(parent: Node, text: String) -> Label:
	var l := _label(parent, text, "MutedLabel")
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l

func _label(parent: Node, text: String, variation: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not variation.is_empty():
		l.theme_type_variation = variation
	parent.add_child(l)
	return l

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and get_child_count() > 0 and get_child(get_child_count() - 1) is CenterContainer:
		get_viewport().set_input_as_handled()
		_close()
