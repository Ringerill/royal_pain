extends Control
# Árbol de habilidades: los tres árboles del personaje (luchador, personalidad, alineamiento) y el de su
# arma. Cada árbol se dibuja como un árbol de verdad: sus tres ramas en columnas, los escalones (I–IV)
# de arriba abajo, y líneas de cada habilidad a las que necesita. Dorado = aprendida, verde = puedes
# aprenderla ya, apagada = bloqueada. Al elegir una, su ficha aparece a la derecha con «Aprender».
# Uso: load("res://scripts/ui/skill_tree_panel.gd").open(nodo, personaje)

const TAB_NAMES := ["Combate", "Personalidad", "Alineación"]
const WEAPON_TAB := "Arma"
const TIER_MARK := ["", "I", "II", "III", "IV"]
const NODE_SIZE := 50
const NODE_ICON := 28
const NODE_W := 78          # ancho de cada habilidad (icono y nombre)
const DETAIL_W := 290
const LEARNED_COLOR := Color("d4af5a")
const AVAILABLE_COLOR := Color("7fcf6a")
const LOCKED_COLOR := Color("5a5048")
const LINE_ON := Color(0.83, 0.69, 0.35, 0.9)    # requisito ya aprendido
const LINE_OFF := Color(0.45, 0.4, 0.35, 0.55)
const LOCKED_ALPHA := 0.45

var character: Character
var _tabs: TabContainer
var _points: Label
var _hint: Label
var _detail_title: Label
var _detail_icon: CenterContainer
var _confirm_row: HBoxContainer
var _confirm_label: Label
var _confirm_btn: Button
var _pending := ""
var _focus_id := ""

## Líneas entre una habilidad y sus requisitos (detrás de los iconos de una rama).
class TreeLines extends Control:
	var links: Array = []        # [[id_hijo, id_requisito, aprendido]]
	var buttons := {}            # id -> Button
	func _draw() -> void:
		for l: Array in links:
			var a: Button = buttons.get(l[0])
			var b: Button = buttons.get(l[1])
			if a == null or b == null or not a.is_inside_tree() or not b.is_inside_tree():
				continue
			var inv := get_global_transform().affine_inverse()
			var pa: Vector2 = inv * a.get_global_rect().get_center()
			var pb: Vector2 = inv * b.get_global_rect().get_center()
			var mid := (pa.y + pb.y) / 2.0
			var col: Color = LINE_ON if l[2] else LINE_OFF
			var w := 3.0 if l[2] else 2.0
			# En escuadra: baja del requisito, cruza y entra por arriba (más legible que en diagonal).
			draw_polyline(PackedVector2Array([pb, Vector2(pb.x, mid), Vector2(pa.x, mid), pa]), col, w, true)

static func open(host: Node, c: Character) -> Control:
	var panel: Control = load("res://scripts/ui/skill_tree_panel.gd").new()
	panel.character = c
	host.add_child(panel)
	return panel

func _ready() -> void:
	if character == null:
		character = GameManager.player_character
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
	panel.custom_minimum_size = Vector2(1080, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var head := HBoxContainer.new()
	box.add_child(head)
	var title := _label("Habilidades de %s · nivel %d" % [character.full_name(), character.level], &"BodyBoldLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_points = _label("", &"BodyBoldLabel")
	_points.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(_points)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	box.add_child(body)
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(0, 430)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.tab_changed.connect(func(_i: int):
		cancel_learn(false)
		_focus_first_node()
		_redraw_lines.call_deferred())
	body.add_child(_tabs)
	body.add_child(_build_detail())

	var close := Button.new()
	close.text = "Cerrar"
	close.theme_type_variation = &"FlatButton"
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.custom_minimum_size = Vector2(180, 0)
	close.pressed.connect(queue_free)
	box.add_child(close)

	_rebuild()
	UiAnim.fade_in(panel, 0.15)
	_focus_first_node()

## Ficha de la habilidad elegida (a la derecha): icono, nombre, descripción, coste y «Aprender».
func _build_detail() -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(DETAIL_W, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	_detail_icon = CenterContainer.new()
	_detail_icon.custom_minimum_size = Vector2(0, 64)
	v.add_child(_detail_icon)
	_detail_title = _label("Elige una habilidad", &"BodyBoldLabel")
	_detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_detail_title)
	_hint = _label("Dorado: aprendida · verde: puedes aprenderla · apagada: bloqueada.", &"MutedLabel")
	_hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_hint)
	_confirm_row = HBoxContainer.new()
	_confirm_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_confirm_row.add_theme_constant_override("separation", 8)
	_confirm_row.visible = false
	v.add_child(_confirm_row)
	_confirm_label = _label("", &"MutedLabel")   # coste (oculto: va en el botón)
	_confirm_label.visible = false
	_confirm_row.add_child(_confirm_label)
	_confirm_btn = Button.new()
	_confirm_btn.text = "Aprender"
	_confirm_btn.custom_minimum_size = Vector2(130, 0)
	_confirm_btn.pressed.connect(confirm_learn)
	_confirm_row.add_child(_confirm_btn)
	var cancel := Button.new()
	cancel.text = "Cancelar"
	cancel.theme_type_variation = &"FlatButton"
	cancel.pressed.connect(cancel_learn)
	_confirm_row.add_child(cancel)
	return card

func _label(text: String, variation: StringName = &"") -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if variation != &"":
		l.theme_type_variation = variation
	return l

# --- Construcción ---

func _rebuild() -> void:
	var current := _tabs.current_tab
	for child in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()
	var trees := SkillTreeCatalog.trees_for(character)
	for i in trees.size():
		_tabs.add_child(_tree_page(TAB_NAMES[i], trees[i]))
	# Técnicas del arma que lleva: no cuestan puntos, se desbloquean con el nivel.
	_tabs.add_child(_tree_page(WEAPON_TAB, SkillTreeCatalog.weapon_tree_of(character)))
	_tabs.current_tab = clampi(current, 0, _tabs.get_tab_count() - 1)
	_points.text = "Puntos libres: %d" % SkillTreeCatalog.points_free(character)
	_redraw_lines.call_deferred()

func _tree_page(tab_name: String, tree_id: String) -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 6)
	scroll.add_child(page)
	var t := SkillTreeCatalog.tree(tree_id)
	var cols := HBoxContainer.new()
	cols.name = "Ramas"
	cols.add_theme_constant_override("separation", 10)
	page.add_child(cols)
	for br: Dictionary in t.get("branches", []):
		cols.add_child(_branch(br))
	return scroll

## Una rama: su nombre arriba y sus habilidades por escalones, unidas por líneas a sus requisitos.
func _branch(br: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	var bl := _label(br.name, &"SubheaderLabel")
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(bl)
	var area := MarginContainer.new()   # las líneas y los iconos, superpuestos
	col.add_child(area)
	var lines := TreeLines.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(lines)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	area.add_child(rows)
	var by_tier := {}
	for id: String in br.nodes:
		var tier := int(SkillTreeCatalog.node(id).get("tier", 1))
		if not by_tier.has(tier):
			by_tier[tier] = []
		by_tier[tier].append(id)
	var tiers := by_tier.keys()
	tiers.sort()
	for tier: int in tiers:
		var row := HFlowContainer.new()
		row.alignment = FlowContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("h_separation", 6)
		row.add_theme_constant_override("v_separation", 6)
		rows.add_child(row)
		for id: String in by_tier[tier]:
			row.add_child(_node_widget(id, lines))
	for id: String in br.nodes:
		var n := SkillTreeCatalog.node(id)
		for r: String in n.get("req", []):
			lines.links.append([id, r, SkillTreeCatalog.knows(character, r)])
		for r: String in n.get("req_any", []):
			lines.links.append([id, r, SkillTreeCatalog.knows(character, r)])
	area.resized.connect(lines.queue_redraw)
	return col

## Una habilidad: icono redondo (con el borde de su estado) y su nombre debajo.
func _node_widget(id: String, lines: TreeLines) -> Control:
	var n := SkillTreeCatalog.node(id)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(NODE_W, 0)
	v.add_theme_constant_override("separation", 2)
	var holder := CenterContainer.new()
	v.add_child(holder)
	var b := Button.new()
	b.set_meta("skill_id", id)
	b.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	b.focus_mode = Control.FOCUS_ALL
	b.tooltip_text = "%s %s" % [TIER_MARK[clampi(int(n.tier), 0, 4)], n.name]
	var state := node_state(id)
	var color: Color = LEARNED_COLOR if state == "aprendida" else (AVAILABLE_COLOR if state == "disponible" else LOCKED_COLOR)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, _circle(color, st))
	holder.add_child(b)
	var icon := SkillIcons.node_icon(id, NODE_ICON, character)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	var pad := (NODE_SIZE - NODE_ICON) / 2.0   # centrado en el círculo
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = pad
	icon.offset_top = pad
	icon.offset_right = -pad
	icon.offset_bottom = -pad
	var name_l := _label(n.name, &"MutedLabel")
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 11)
	name_l.max_lines_visible = 2
	v.add_child(name_l)
	if state == "bloqueada":
		v.modulate.a = LOCKED_ALPHA
	elif state == "aprendida":
		name_l.add_theme_color_override("font_color", LEARNED_COLOR)
	lines.buttons[id] = b
	b.focus_entered.connect(func(): _show_hint(id))
	b.mouse_entered.connect(func(): _show_hint(id))
	b.pressed.connect(func(): request_learn(id))
	return v

func _circle(color: Color, st: String) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.075, 0.05) if st != "hover" else Color(0.17, 0.13, 0.08)
	sb.set_corner_radius_all(NODE_SIZE / 2)
	var w := 3 if st in ["focus", "pressed"] else 2
	sb.set_border_width_all(w)
	sb.border_color = color.lightened(0.3) if st in ["focus", "hover"] else color
	if st == "focus":
		sb.shadow_color = Color(color, 0.5)
		sb.shadow_size = 6
	return sb

func _redraw_lines() -> void:
	var page := _tabs.get_current_tab_control()
	if page == null:
		return
	for l in page.find_children("*", "Control", true, false):
		if l is TreeLines:
			l.queue_redraw()

# --- Ficha de la habilidad ---

func node_state(id: String) -> String:
	if SkillTreeCatalog.knows(character, id):
		return "aprendida"
	return "disponible" if SkillTreeCatalog.can_learn(character, id) else "bloqueada"

func _lock_reason(id: String) -> String:
	var n := SkillTreeCatalog.node(id)
	if SkillTreeCatalog.knows(character, id):
		return "Ya aprendida."
	if character.level < SkillTreeCatalog.required_level(n):
		return "Requiere nivel %d." % SkillTreeCatalog.required_level(n)
	var missing := []
	for r: String in n.req:
		if not SkillTreeCatalog.knows(character, r):
			missing.append(SkillTreeCatalog.node(r).get("name", r))
	if not missing.is_empty():
		return "Requiere %s." % ", ".join(missing)
	if not n.req_any.is_empty() and not n.req_any.any(func(r: String) -> bool: return SkillTreeCatalog.knows(character, r)):
		return "Requiere una habilidad básica de la rama."
	if SkillTreeCatalog.points_free(character) < SkillTreeCatalog.cost_for(character, id):
		return "Faltan puntos."
	return ""

func _show_hint(id: String) -> void:
	_focus_id = id
	var n := SkillTreeCatalog.node(id)
	if n.is_empty():
		return
	_detail_title.text = n.name
	for ch in _detail_icon.get_children():
		ch.queue_free()
	_detail_icon.add_child(SkillIcons.node_icon(id, 48, character))
	var parts := []
	if n.kind == "act":
		parts.append("Técnica · %d PT" % int(n.get("pt", 0)))
		if float(n.get("pow", 0.0)) > 0.0:
			var dt := int(n.get("dt", -1))
			if dt >= 0 and dt < RpgStats.DAMAGE_NAMES.size():
				parts.append("Daño: " + RpgStats.DAMAGE_NAMES[dt])
			else:
				parts.append("Daño: el de tu arma (%s)" % RpgStats.DAMAGE_NAMES[RpgStats.weapon_type(character)])
	else:
		parts.append("Pasiva")
	if SkillTreeCatalog.is_weapon_node(id):   # técnicas de arma: sin puntos, por nivel
		var lv := SkillTreeCatalog.required_level(n)
		var have := SkillTreeCatalog.knows(character, id)
		parts.append("Técnica de arma · nivel %d" % lv)
		_hint.text = "%s\n\n%s\n\n%s" % [n.desc, "\n".join(parts),
			"La tienes mientras lleves esta arma." if have else "Se desbloquea sola al llegar al nivel %d." % lv]
		return
	var cost := SkillTreeCatalog.cost_for(character, id)
	parts.append("Escalón %s · nivel %d" % [TIER_MARK[clampi(int(n.tier), 0, 4)], SkillTreeCatalog.required_level(n)])
	parts.append("Coste: gratis" if cost == 0 else "Coste: %d punto%s" % [cost, "" if cost == 1 else "s"])
	var reqs := []
	for r: String in n.req:
		reqs.append(SkillTreeCatalog.node(r).get("name", r))
	if not n.req_any.is_empty():
		reqs.append("una básica de la rama")
	if not reqs.is_empty():
		parts.append("Requiere: " + ", ".join(reqs))
	var state := node_state(id)
	var tail := "Aprendida." if state == "aprendida" else ("Puedes aprenderla." if state == "disponible" else _lock_reason(id))
	_hint.text = "%s\n\n%s\n\n%s" % [n.desc, "\n".join(parts), tail]

# --- Aprender ---

func request_learn(id: String) -> void:
	_show_hint(id)
	if not SkillTreeCatalog.can_learn(character, id):
		_confirm_row.visible = false
		_pending = ""
		return
	_pending = id
	var cost := SkillTreeCatalog.cost_for(character, id)
	var price := "gratis" if cost == 0 else "%d punto%s" % [cost, "" if cost == 1 else "s"]
	_confirm_label.text = "¿Aprender «%s» por %s?" % [SkillTreeCatalog.node(id).name, price]
	_confirm_btn.text = "Aprender (%s)" % price
	_confirm_row.visible = true
	_focus_later(_confirm_btn)

func confirm_learn() -> bool:
	var id := _pending
	cancel_learn(false)
	if id == "" or not SkillTreeCatalog.learn(character, id):
		return false
	_rebuild()
	_show_hint(id)
	_hint.text = "Aprendes «%s».\n\n%s" % [SkillTreeCatalog.node(id).name, _hint.text]
	_refocus(id)
	return true

func cancel_learn(refocus := true) -> void:
	var id := _pending
	_pending = ""
	_confirm_row.visible = false
	if refocus and id != "":
		_refocus(id)

func _refocus(id: String) -> void:
	(func():
		for b in _buttons():
			if b.get_meta("skill_id") == id:
				_focus_later(b)
				return).call_deferred()

func _buttons() -> Array:
	var out := []
	var page := _tabs.get_current_tab_control()
	if page == null:
		return out
	var stack := [page]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and n.has_meta("skill_id") and not n.is_queued_for_deletion():
			out.append(n)
		stack.append_array(n.get_children())
	out.sort_custom(func(a: Button, b: Button) -> bool:
		var ra := a.get_global_rect()
		var rb := b.get_global_rect()
		return ra.position.y < rb.position.y if absf(ra.position.y - rb.position.y) > 4.0 else ra.position.x < rb.position.x)
	return out

func _focus_first_node() -> void:
	(func():
		var list := _buttons()
		if not list.is_empty():
			_focus_later(list[0])).call_deferred()

func _focus_later(c: Control) -> void:
	(func(): if is_instance_valid(c) and c.is_inside_tree() and c.is_visible_in_tree(): c.grab_focus()).call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _confirm_row.visible:
			cancel_learn()
		else:
			queue_free()
		return
	var step := 0
	if event is InputEventKey and event.pressed and not event.echo:
		step = -1 if event.keycode == KEY_Q else (1 if event.keycode == KEY_E else 0)
	elif event is InputEventJoypadButton and event.pressed:
		step = -1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else (1 if event.button_index == JOY_BUTTON_RIGHT_SHOULDER else 0)
	if step != 0 and _tabs.get_tab_count() > 0:
		get_viewport().set_input_as_handled()
		_tabs.current_tab = posmod(_tabs.current_tab + step, _tabs.get_tab_count())
