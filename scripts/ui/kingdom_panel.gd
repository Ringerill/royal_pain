extends Control
# Información de los reinos (tecla K en el mapa): gobernante, diplomacia, economía, castillos e integrantes.
# Solo muestra lo que sabes: tu reino al completo; de los demás, los castillos que alcanzas a ver
# (MapVision) y la gente con la que has tratado. Desde aquí se pide audiencia a su gobernante (RoyalCourt).
#   KingdomPanel.open(host, ids_de_castillos_visibles)

const RoyalAudiencePanel := preload("res://scripts/ui/royal_audience_panel.gd")
const FACE := 44

var visible_ids: Array = []
var _tabs: TabContainer
var _feedback: Label

static func open(host: Node, visible_castle_ids: Array) -> Control:
	var panel: Control = load("res://scripts/ui/kingdom_panel.gd").new()
	panel.visible_ids = visible_castle_ids
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
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var panel := PanelContainer.new()
	margin.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	_label(col, "Reinos", "HeaderLabel")
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_tabs)
	_feedback = _label(col, "", "MutedLabel")
	var close := Button.new()
	close.text = "Cerrar"
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(queue_free)
	col.add_child(close)
	_rebuild()

func kingdoms() -> Array:
	var out: Array = []
	for c: Castle in MapData.castles:
		if c.kingdom != KingdomEnums.Kingdom.NEUTRAL and not int(c.kingdom) in out:
			out.append(int(c.kingdom))
	out.sort_custom(func(a, b): return a == GameManager.player_kingdom and b != GameManager.player_kingdom)
	return out

func _rebuild() -> void:
	var current := _tabs.current_tab
	for ch in _tabs.get_children():
		_tabs.remove_child(ch)
		ch.queue_free()
	for k in kingdoms():
		_tabs.add_child(_kingdom_page(k))
	_tabs.current_tab = clampi(current, 0, maxi(0, _tabs.get_tab_count() - 1))

func knows_castle(c: Castle) -> bool:
	return c.kingdom == GameManager.player_kingdom or c.castle_id in visible_ids

func _kingdom_page(k: int) -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = KingdomEnums.kingdom_name(k)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 8)
	scroll.add_child(page)
	# Gobernante y audiencia.
	var ruler: Relationship = RoyalCourt.ruler_of(k)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	page.add_child(head)
	if ruler != null and ruler.character != null:
		head.add_child(FaceIcon.make(ruler.character, 64))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(info)
	var player: Character = GameManager.player_character
	if ruler == null:
		_label(info, "Sin gobernante conocido.", "BodyBoldLabel")
	else:
		_label(info, "Gobierna %s · %s · afinidad contigo %d" % [ruler.person_name, ruler.character.role_name() if ruler.character != null else "", ruler.affinity], "BodyBoldLabel")
		var dip := _diplomacy_text(k, ruler)
		if not dip.is_empty():
			_label(info, dip, "MutedLabel")
		var buttons := HBoxContainer.new()
		info.add_child(buttons)
		var chance_p := "%d%%" % roundi(RoyalCourt.acceptance_chance(ruler, false) * 100)
		var chance_l := "%d%%" % roundi(RoyalCourt.acceptance_chance(ruler, true) * 100)
		var in_person := _audience_button("Pedir audiencia en persona (%s)" % chance_p, ruler, false)
		var letter := _audience_button("Pedirla por carta, 2 acciones (%s)" % chance_l, ruler, true)
		buttons.add_child(in_person)
		buttons.add_child(letter)
	# Economía y castillos.
	_label(page, "Economía y castillos", "SubheaderLabel")
	var totals := {"n": 0, "known": 0, "gold": 0, "food": 0, "garrison": 0, "income": 0, "upkeep": 0, "food_net": 0}
	var winter := SkillEffects.is_winter(GameManager.current_month)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 16)
	page.add_child(grid)
	# Cabecera con iconos (el nombre de cada columna, en su ayuda).
	_cell(grid, "Castillo", "MutedLabel")
	_cell(grid, "Señor", "MutedLabel")
	for h: Array in [["soldados", "", "Guarnición"], ["oro", "", "Oro del castillo"], ["comida", "", "Comida"],
			["oro", "+/mes", "Ingresos al mes"], ["soldados", "−oro/mes", "Paga de la tropa al mes"], ["comida", "/mes", "Comida al mes"]]:
		StatIcons.pair(grid, h[0], h[1], 16, h[2]).modulate = Color(1, 1, 1, 0.85)
	for c: Castle in MapData.castles:
		if c.kingdom != k:
			continue
		totals.n += 1
		var seen := knows_castle(c)
		var f := KingdomAI.castle_forecast(c, winter)
		_cell(grid, c.castle_name, "")
		_cell(grid, c.owner_name, "")
		for v in [c.garrison_size, c.gold, c.food]:
			_cell(grid, str(v) if seen else "?", "")
		_cell(grid, "+%d" % f.income if seen else "?", "")
		_cell(grid, "−%d" % f.upkeep if seen else "?", "")
		_cell(grid, "%+d" % f.food if seen else "?", "")
		if seen:
			totals.known += 1
			totals.gold += c.gold
			totals.food += c.food
			totals.garrison += c.garrison_size
			totals.income += f.income
			totals.upkeep += f.upkeep
			totals.food_net += f.food
	var known_txt := "" if totals.known == totals.n else " (conoces %d)" % totals.known
	_label(page, "%d castillos%s · %d soldados · %d de oro en las arcas · %d de comida" % [totals.n, known_txt, totals.garrison, totals.gold, totals.food], "BodyBoldLabel")
	var balance: int = totals.income - totals.upkeep
	_label(page, "Cada mes%s: ingresos +%d, paga de la tropa −%d → balance %+d de oro · comida %+d%s" % [
		" (invierno)" if winter else "", totals.income, totals.upkeep, balance, totals.food_net,
		" · ¡en números rojos!" if balance < 0 or totals.food_net < 0 else ""], "MutedLabel")
	# Integrantes.
	_label(page, "Integrantes", "SubheaderLabel")
	var people: Array = []
	for r: Relationship in RelationsData.relations:
		if r.character == null or r.kingdom != k:
			continue
		if r.kind == Relationship.Kind.SENOR or k == GameManager.player_kingdom or r.affection > 0 or r.person_name in RelationsData.retinue:
			people.append(r)
	people.sort_custom(func(a, b): return a.character.rank() > b.character.rank() or (a.character.rank() == b.character.rank() and a.character.level > b.character.level))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 8)
	page.add_child(flow)
	for r: Relationship in people:
		flow.add_child(_member(r))
	if people.is_empty():
		_label(page, "No conoces a nadie de este reino.", "MutedLabel")
	return scroll

func _diplomacy_text(k: int, ruler: Relationship) -> String:
	var parts: Array[String] = []
	if k != GameManager.player_kingdom:
		if ruler.at_war:
			parts.append("En guerra contigo")
		elif ruler.allied:
			parts.append("Aliado tuyo")
	for other in kingdoms():
		if other == k:
			continue
		if KingdomDiplomacy.at_war(RelationsData.kingdom_wars, k, other):
			parts.append("⚔ " + KingdomEnums.kingdom_name(other))
		elif KingdomDiplomacy.allied(RelationsData.kingdom_alliances, k, other):
			parts.append("Aliado de " + KingdomEnums.kingdom_name(other))
	return " · ".join(parts)

func _member(r: Relationship) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.x = 300
	row.add_theme_constant_override("separation", 6)
	row.add_child(FaceIcon.make(r.character, FACE))
	var c := r.character
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	StatIcons.named(info, c, r.person_name, 16)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	info.add_child(stats)
	StatIcons.pair(stats, "nivel", str(c.level), 14)
	StatIcons.pair(stats, "honor", str(c.honor), 14)
	var rel := StatIcons.relation_icon(r, 14)
	rel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stats.add_child(rel)
	return row

func _audience_button(text: String, ruler: Relationship, by_letter: bool) -> Button:
	var b := Button.new()
	b.text = text
	var reason := RoyalCourt.blocker(ruler, by_letter)
	b.disabled = not reason.is_empty()
	b.tooltip_text = reason if b.disabled else "Te recibe según tu afinidad, tu renombre, tu rango y la suerte."
	b.pressed.connect(func():
		var res: Dictionary = RoyalCourt.request(ruler, by_letter)
		_feedback.text = res.text
		if res.ok:
			var p := RoyalAudiencePanel.open(self, ruler)
			p.tree_exited.connect(func():
				if is_inside_tree():
					_feedback.text = str(p.get_meta("result", res.text))
					_rebuild())
		else:
			_rebuild())
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

func _cell(parent: Node, text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	if not variation.is_empty():
		label.theme_type_variation = StringName(variation)
	parent.add_child(label)
	return label
