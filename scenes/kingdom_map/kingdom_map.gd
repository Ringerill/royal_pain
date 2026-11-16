extends Control
# Rediseño v2 (docs/REDISENO.md §1 y §7): pantalla principal. El mapa del reino a pantalla completa con
# sus lugares y caminos, tu ficha que viaja por ellos, el reloj (día, hora, estación), la energía, el oro y
# la fama, la velocidad del tiempo y los accesos (grupo, relaciones, diario, mundo, menú).
# Los sucesos del mes (GameManager) y las noticias (WorldEvents) se muestran aquí.

const PartyPanel = preload("res://scripts/ui/party_panel.gd")
const PLACE_SCENE := "res://scenes/place/place.tscn"
const NODE_ICON := 58.0
const CAPITAL_ICON := 82.0
const PLAYER_FACE := 40
const PLAYER_SPRITE := 92.0   # fotograma de reposo en el mapa
const ROAD_COLOR := Color(0.98, 0.9, 0.7, 0.75)
const ROUTE_COLOR := Color(1.0, 0.82, 0.3, 0.95)
const DAYPART_TINT := [Color(0.05, 0.08, 0.25, 0.45), Color(0.9, 0.5, 0.3, 0.12), Color(0, 0, 0, 0), Color(0.9, 0.4, 0.15, 0.18)]
const SPEED_LABELS := ["⏸", "×1", "×2", "×4"]

var _map: TextureRect
var _roads: Control
var _tint: ColorRect
var _node_buttons: Array[Control] = []
var _player: Control
var _hud_clock: Label
var _hud_energy: ProgressBar
var _hud_energy_label: Label
var _hud_gold: Label
var _hud_fame: Label
var _speed_buttons: Array[Button] = []
var _party_box: HBoxContainer
var _place_panel: PanelContainer
var _selected := -1
var _dialog: Control
var _world: Control
var _pending_fight := {}
var _pending_fight_title := ""
var _pending_duel_rival: Character
var _pending_duel_to_death := false
var _traffic: Control
const TRAFFIC_ICON := 30.0
# Encuentros en el camino (fase 6)
const TOLL_SHARE := 0.15          # bandidos: peaje (parte de tu oro)
const TOLL_MIN := 10
const BRIBE := 60                 # patrulla hostil: soborno
const FLEE_BASE := 0.35
const FLEE_PER_AGI := 0.03
const ESCORT_HOURS := 2.0
const ESCORT_GOLD := 60
const ESCORT_AMBUSH := 0.5
const RAID_GOLD := 150
const RAID_FAME := -5
const TRADER_DISCOUNT := 0.9

func _ready() -> void:
	if not GameManager.is_game_active or GameManager.player_character == null:
		get_tree().change_scene_to_file.call_deferred("res://scenes/main_menu/main_menu.tscn")
		return
	# (La sucesión dinástica se retira en la fase 9; mientras exista, la lleva el mapa antiguo.)
	if DynastyData.needs_succession():
		get_tree().change_scene_to_file.call_deferred(GameManager.OLD_MAP_SCENE)
		return
	if Journey.kingdom < 0 or Journey.names.is_empty():
		Journey.reset()
	# De vuelta de una campaña (campal + asedio): pasan sus meses.
	if GameManager.pending_campaign_months > 0:
		var months := GameManager.pending_campaign_months
		GameManager.pending_campaign_months = 0
		Journey.pass_time(months * Journey.DAYS_PER_MONTH * Journey.HOURS_PER_DAY)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	Journey.changed.connect(_refresh)
	Journey.arrived.connect(_on_arrived)
	Journey.fainted.connect(func(t: String): _message("Desmayo", t))
	Journey.month_passed.connect(_after_month)
	RoadTraffic.encounter.connect(_on_encounter)
	RoadTraffic.moved.connect(_traffic.queue_redraw)
	resized.connect(_layout)
	_layout.call_deferred()
	_refresh()
	_check_events.call_deferred()

func _exit_tree() -> void:
	if Journey.changed.is_connected(_refresh):
		Journey.changed.disconnect(_refresh)
	if RoadTraffic.encounter.is_connected(_on_encounter):
		RoadTraffic.encounter.disconnect(_on_encounter)
	if is_instance_valid(_traffic) and RoadTraffic.moved.is_connected(_traffic.queue_redraw):
		RoadTraffic.moved.disconnect(_traffic.queue_redraw)

# --- Construcción ---

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0d1a2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_map = TextureRect.new()
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map)
	_roads = Control.new()
	_roads.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_roads.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roads.draw.connect(_draw_roads)
	add_child(_roads)
	_traffic = Control.new()   # grupos en los caminos (RoadTraffic)
	_traffic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_traffic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_traffic.draw.connect(_draw_traffic)
	add_child(_traffic)
	_tint = ColorRect.new()
	_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint)
	_build_nodes()
	# Tu ficha: el primer fotograma de reposo de tu hoja de sprites (o tu rostro si no tienes hoja).
	var idle := SpriteSheets.frame(GameManager.player_character, 1)
	if idle != null:
		var spr := TextureRect.new()
		spr.texture = idle
		spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		spr.custom_minimum_size = Vector2(PLAYER_SPRITE, PLAYER_SPRITE)
		spr.size = spr.custom_minimum_size
		_player = spr
	else:
		_player = FaceIcon.make(GameManager.player_character, PLAYER_FACE, Color("f0d48a"), false)
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player.z_index = 5
	add_child(_player)
	_build_hud()
	_build_place_panel()

func _build_nodes() -> void:
	for b in _node_buttons:
		b.queue_free()
	_node_buttons.clear()
	_map.texture = load(KingdomMaps.map_path(Journey.kingdom))
	for n in Journey.nodes():
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var size := CAPITAL_ICON if n.type == "capital" else NODE_ICON
		var btn := TextureButton.new()
		btn.texture_normal = load(KingdomMaps.ICON_DIR % KingdomMaps.TYPE_ICONS[n.type])
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size = Vector2(size, size)
		btn.tooltip_text = "%s · %s" % [Journey.node_name(n.index), KingdomMaps.TYPE_NAMES[n.type]]
		btn.pressed.connect(_select.bind(n.index))
		box.add_child(btn)
		var lbl := Label.new()
		lbl.text = Journey.node_name(n.index)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 5)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(lbl)
		box.set_meta("index", n.index)
		add_child(box)
		move_child(box, _tint.get_index() + 1)
		_node_buttons.append(box)

func _build_hud() -> void:
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 8
	top.offset_right = -8
	top.offset_top = 6
	add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	top.add_child(row)
	var face := FaceIcon.make(GameManager.player_character, 40, Color("d4af5a"))
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(face)
	_hud_clock = Label.new()
	_hud_clock.theme_type_variation = &"BodyBoldLabel"
	_hud_clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hud_clock.custom_minimum_size.x = 250
	row.add_child(_hud_clock)
	var en := HBoxContainer.new()
	en.add_theme_constant_override("separation", 4)
	en.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	en.tooltip_text = "Energía: se gasta al viajar (2 por hora), combatir y entrenar. Por debajo de 20 tu grupo pierde fuerza; en 0 te desmayas."
	row.add_child(en)
	var el := Label.new()
	el.text = "Energía"
	en.add_child(el)
	_hud_energy = ProgressBar.new()
	_hud_energy.show_percentage = false
	_hud_energy.custom_minimum_size = Vector2(120, 14)
	_hud_energy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	en.add_child(_hud_energy)
	_hud_energy_label = Label.new()
	en.add_child(_hud_energy_label)
	var gold := StatIcons.pair(row, "oro", "0", 18)
	_hud_gold = gold.get_child(gold.get_child_count() - 1)
	var fame := StatIcons.pair(row, "fama", "0", 18)
	_hud_fame = fame.get_child(fame.get_child_count() - 1)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	for i in Journey.SPEEDS.size():
		var b := Button.new()
		b.text = SPEED_LABELS[i]
		b.toggle_mode = true
		b.tooltip_text = "Pausa" if i == 0 else "Velocidad del tiempo al viajar"
		b.pressed.connect(func(): Journey.set_speed(i))
		row.add_child(b)
		_speed_buttons.append(b)
	# Accesos: segunda barra, arriba a la derecha.
	var acc := HBoxContainer.new()
	acc.add_theme_constant_override("separation", 6)
	acc.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	acc.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	acc.offset_top = 70
	acc.offset_right = -10
	add_child(acc)
	for spec in [["Grupo", _open_party], ["Relaciones", _open_relations], ["Diario", _open_journal], ["Mundo", _open_world], ["Menú", _open_menu]]:
		var b := Button.new()
		b.text = spec[0]
		b.pressed.connect(spec[1])
		acc.add_child(b)
	# Abajo a la izquierda: tu grupo.
	var party := PanelContainer.new()
	party.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	party.offset_left = 8
	party.offset_bottom = -8
	party.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(party)
	_party_box = HBoxContainer.new()
	_party_box.add_theme_constant_override("separation", 6)
	party.add_child(_party_box)

func _build_place_panel() -> void:
	_place_panel = PanelContainer.new()
	_place_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_place_panel.offset_bottom = -10
	_place_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_place_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_place_panel.visible = false
	add_child(_place_panel)

# --- Colocación ---

## Rectángulo donde se ve el mapa (se mantiene la proporción, centrado).
func _map_rect() -> Rect2:
	var tex := _map.texture
	if tex == null:
		return Rect2(Vector2.ZERO, size)
	var k := minf(size.x / tex.get_width(), size.y / tex.get_height())
	var s := Vector2(tex.get_width(), tex.get_height()) * k
	return Rect2((size - s) * 0.5, s)

func _to_screen(frac: Vector2) -> Vector2:
	var r := _map_rect()
	return r.position + frac * r.size

func _layout() -> void:
	for box in _node_buttons:
		var n: Dictionary = Journey.node(int(box.get_meta("index")))
		var p := _to_screen(n.pos)
		box.reset_size()
		var icon_h := CAPITAL_ICON if n.type == "capital" else NODE_ICON
		box.position = p - Vector2(box.size.x * 0.5, icon_h * 0.5)
	_place_player()
	_roads.queue_redraw()

func _place_player() -> void:
	if _player == null:
		return
	var p := _to_screen(Journey.position_frac())
	if _player is TextureRect:
		_player.position = p - Vector2(PLAYER_SPRITE * 0.5, PLAYER_SPRITE * 0.92)   # los pies sobre el punto
	else:
		_player.position = p - Vector2(PLAYER_FACE * 0.5, PLAYER_FACE + 18)

func _draw_roads() -> void:
	for e in KingdomMaps.edges(Journey.kingdom):
		_roads.draw_line(_to_screen(Journey.node(e[0]).pos), _to_screen(Journey.node(e[1]).pos), ROAD_COLOR, 3.0, true)
	# Ruta en curso.
	if Journey.is_traveling():
		var pts := PackedVector2Array([_to_screen(Journey.position_frac()), _to_screen(Journey.node(Journey.leg_to).pos)])
		for i in Journey.path:
			pts.append(_to_screen(Journey.node(i).pos))
		_roads.draw_polyline(pts, ROUTE_COLOR, 5.0, true)

func _draw_traffic() -> void:
	for g: Dictionary in RoadTraffic.groups:
		var d: Dictionary = RoadTraffic.TYPES[g.type]
		var p := _to_screen(RoadTraffic.position_of(g))
		_traffic.draw_circle(p, TRAFFIC_ICON * 0.55, Color(0, 0, 0, 0.55))
		_traffic.draw_circle(p, TRAFFIC_ICON * 0.5, d.color.darkened(0.35))
		var tex := SkillIcons.texture(d.icon)
		if tex != null:
			var r := Rect2(p - Vector2(TRAFFIC_ICON, TRAFFIC_ICON) * 0.35, Vector2(TRAFFIC_ICON, TRAFFIC_ICON) * 0.7)
			_traffic.draw_texture_rect(tex, r, false, Color(1, 1, 1))

# --- Encuentros en el camino (RoadTraffic) ---

func _on_encounter(g: Dictionary) -> void:
	if is_instance_valid(_dialog) or GameManager.has_pending_event():
		g.met = false   # ahora no: volverá a intentarlo
		return
	var p := GameManager.player_character
	match str(g.type):
		"bandidos":
			var toll := maxi(TOLL_MIN, roundi(p.gold * TOLL_SHARE))
			_choices("Bandidos en el camino", "«¡La bolsa o la vida!» Un grupo armado os corta el paso.", [
				["Luchar", func(): _road_fight(g, "Bandido", "camino", 0, {"gold": 30}, "Los bandidos huyen o caen.")],
				["Pagar el peaje (%d de oro)" % toll, func():
					p.gold = maxi(0, p.gold - toll)
					RoadTraffic.remove(g)
					_message("Bandidos", "Pagas %d de oro y os dejan pasar." % toll)],
				["Huir", func():
					if randf() < clampf(FLEE_BASE + p.agility * FLEE_PER_AGI, 0.1, 0.9):
						_message("Bandidos", "Escapáis por el bosque.")
					else:
						_road_fight(g, "Bandido", "camino", 0, {"gold": 30}, "No había escapatoria, pero vencéis.")],
			])
		"patrulla":
			if RoadTraffic.patrol_hostile():
				_choices("Patrulla", "«¡Alto! Se te busca por tus fechorías.»", [
					["Luchar", func(): _road_fight(g, "Sargento de patrulla", "historia", 1, {"fame": -3}, "La patrulla cae.")],
					["Sobornar (%d de oro)" % BRIBE, func():
						if p.gold >= BRIBE:
							p.gold -= BRIBE
							_message("Patrulla", "El sargento se guarda el oro y mira hacia otro lado.")
						else:
							_road_fight(g, "Sargento de patrulla", "historia", 1, {"fame": -3}, "Sin oro, solo quedaban las armas.")],
				])
			else:
				_message("Patrulla", "Una patrulla del reino os saluda: «Los caminos están más seguros con gente como vos.»")
		"caravana":
			_choices("Caravana", "Una caravana de mercaderes avanza despacio, con pocos guardias.", [
				["Escoltarla un tramo (%d h)" % int(ESCORT_HOURS), func():
					Journey.wait_hours(ESCORT_HOURS)
					if randf() < ESCORT_AMBUSH:
						_road_fight(g, "Asaltante de caminos", "camino", 0, {"gold": ESCORT_GOLD, "fame": 1}, "Los asaltantes huyen. El mercader paga.", false)
					else:
						p.gold += ESCORT_GOLD
						p.add_fame(1)
						_message("Caravana", "Tramo tranquilo. El mercader te paga %d de oro." % ESCORT_GOLD)],
				["Comerciar", func(): _trader("Caravana")],
				["Asaltarla", func(): _road_fight(g, "Guardia de caravana", "historia", 0, {"gold": RAID_GOLD, "fame": RAID_FAME}, "La caravana es tuya.")],
				["Seguir", func(): pass],
			])
		"viajero":
			_choices("Viajero", "Un viajero solitario te saluda desde el borde del camino.", [
				["Conversar", func(): _message("Viajero", PlaceArt.rumor())],
				["Comerciar", func(): _trader("Viajero")],
				["Seguir", func(): pass],
			])

func _choices(title_text: String, text: String, specs: Array) -> void:
	var box := _dialog_box(title_text)
	_rich(box, text)
	for spec in specs:
		var b := Button.new()
		b.text = spec[0]
		var cb: Callable = spec[1]
		b.pressed.connect(func():
			_dialog.queue_free()
			_dialog = null
			cb.call()
			if not is_instance_valid(_dialog):
				_check_events.call_deferred())
		box.add_child(b)

func _road_fight(g: Dictionary, foe_name: String, context: String, power: int, win_effects: Dictionary, win_text: String, remove_group := true) -> void:
	if remove_group:
		RoadTraffic.remove(g)
	var fight := {"type": "duel", "no_rival": true, "context": context,
		"foe": {"name": foe_name, "role": Character.Role.SOLDADO, "power": power, "personality": "CRUEL"},
		"win": {"effects": win_effects, "result": win_text}, "lose": {"effects": {}, "result": "Os retiráis como podéis."}}
	var scene := CombatSetup.begin_event_fight(fight, RoadTraffic.TYPES[g.type].name)
	if not scene.is_empty():
		get_tree().change_scene_to_file(scene)

## Vendedor ambulante: pociones y remedios algo más baratos.
func _trader(title_text: String) -> void:
	var p := GameManager.player_character
	var box := _dialog_box(title_text)
	_rich(box, "Tiene algunas cosas a buen precio. Llevas %d de oro." % p.gold)
	for id in ["pocion1", "tonico1", "antidoto", "remedio_paralisis", "cuchillo"]:
		var price := roundi(int(ConsumableCatalog.item(id).price) * TRADER_DISCOUNT)
		var b := Button.new()
		b.text = "%s — %d de oro" % [ConsumableCatalog.item_name(id), price]
		b.icon = ConsumableCatalog.icon_texture(id)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 24)
		b.disabled = p.gold < price or ConsumableCatalog.count(p.consumables, id) >= ConsumableCatalog.MAX_STACK
		b.pressed.connect(func():
			p.gold -= price
			ConsumableCatalog.add(p.consumables, id)
			_dialog.queue_free()
			_dialog = null
			_trader(title_text))
		box.add_child(b)
	var done := Button.new()
	done.text = "Seguir el camino"
	done.pressed.connect(func():
		_dialog.queue_free()
		_dialog = null)
	box.add_child(done)

func _process(_delta: float) -> void:
	if Journey.is_traveling():
		_place_player()
		_roads.queue_redraw()

# --- Estado ---

func _refresh() -> void:
	if _hud_clock == null:
		return
	var p: Character = GameManager.player_character
	_hud_clock.text = "%s · %s" % [Journey.clock_text(), GameManager.get_date_string()]
	_hud_clock.tooltip_text = "El tiempo corre solo mientras viajas."
	_hud_energy.max_value = p.max_energy
	_hud_energy.value = p.energy
	_hud_energy_label.text = "%d" % p.energy
	_hud_energy.modulate = Color(1, 0.45, 0.4) if p.is_exhausted() else Color.WHITE
	_hud_gold.text = str(p.gold)
	_hud_fame.text = str(p.fame) if "fame" in p else "0"
	for i in _speed_buttons.size():
		_speed_buttons[i].set_pressed_no_signal(i == Journey.speed_index)
	_tint.color = DAYPART_TINT[Journey.daypart()]
	_refresh_party()
	_place_player()
	_roads.queue_redraw()
	if _place_panel.visible and _selected >= 0:
		_show_place(_selected)

func _refresh_party() -> void:
	for ch in _party_box.get_children():
		ch.queue_free()
	var members: Array[Character] = [GameManager.player_character]
	for nm in RelationsData.retinue:
		var c := RelationsData.character_of(nm)
		if c != null and members.size() < 4:
			members.append(c)
	for c in members:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		col.add_child(FaceIcon.make(c, 44, Color("d4af5a")))
		var hp := ProgressBar.new()
		hp.show_percentage = false
		hp.custom_minimum_size = Vector2(44, 5)
		hp.max_value = maxi(1, c.max_health)
		hp.value = c.current_health
		col.add_child(hp)
		_party_box.add_child(col)

# --- Lugares ---

func _select(i: int) -> void:
	_selected = i
	_show_place(i)

func _show_place(i: int) -> void:
	for ch in _place_panel.get_children():
		ch.queue_free()
	var n := Journey.node(i)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_place_panel.add_child(box)
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = Journey.node_name(i)
	box.add_child(title)
	var sub := Label.new()
	sub.theme_type_variation = &"MutedLabel"
	sub.text = "%s · %s" % [KingdomMaps.TYPE_NAMES[n.type], _kingdom_name()]
	box.add_child(sub)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var here := i == Journey.at and not Journey.is_traveling()
	if not here:
		var h := Journey.route_hours(Journey.at if not Journey.is_traveling() else Journey.leg_to, i)
		var b := Button.new()
		b.text = "Viajar (≈%d h, −%d energía)" % [roundi(h), roundi(h * Journey.TRAVEL_ENERGY_PER_HOUR)]
		b.pressed.connect(func():
			Journey.travel_to(i)
			_place_panel.visible = false)
		row.add_child(b)
	else:
		if n.type in KingdomMaps.SETTLEMENT_TYPES:
			var enter := Button.new()
			enter.text = "Entrar"
			enter.tooltip_text = "Tiendas, herrería, taberna (encargos), iglesia, posada…"
			enter.pressed.connect(func(): get_tree().change_scene_to_file(PLACE_SCENE))
			row.add_child(enter)
		if n.type in KingdomMaps.EXPEDITION_TYPES:
			var exp := Button.new()
			exp.text = "Explorar"
			var why := Expeditions.blocker(Journey.kingdom, i)
			exp.disabled = not why.is_empty()
			exp.tooltip_text = why if not why.is_empty() else "Salas con combates, tesoros y trampas; un jefe al final."
			exp.pressed.connect(func():
				if Expeditions.start_expedition(Journey.kingdom, i):
					get_tree().change_scene_to_file(Expeditions.SCENE))
			row.add_child(exp)
		if n.type == "arena":
			for spec in [["torneo", "Torneo (3 rondas)"], ["jefes", "Desafío de jefes"]]:
				var ab := Button.new()
				ab.text = spec[1]
				var aw := Expeditions.arena_blocker(Journey.kingdom, i, spec[0])
				ab.disabled = not aw.is_empty()
				ab.tooltip_text = aw if not aw.is_empty() else "Una vez al mes. Premio en oro y fama."
				ab.pressed.connect(func():
					if Expeditions.start_arena(Journey.kingdom, i, spec[0]):
						get_tree().change_scene_to_file(Expeditions.SCENE))
				row.add_child(ab)
		if Journey.can_sleep():
			var s := Button.new()
			s.text = "Dormir (8 h)"
			s.tooltip_text = "Recuperas toda la energía. Se guarda la partida."
			s.pressed.connect(func():
				Journey.sleep()
				_check_events())
			row.add_child(s)
		elif Journey.can_camp():
			var c := Button.new()
			c.text = "Descansar (4 h, +%d)" % Journey.CAMP_REST_ENERGY
			c.pressed.connect(func():
				Journey.camp_rest()
				_check_events())
			row.add_child(c)
		var w := Button.new()
		w.text = "Esperar 1 h"
		w.pressed.connect(func():
			Journey.wait_hours(1.0)
			_check_events())
		row.add_child(w)
	var close := Button.new()
	close.text = "✕"
	close.pressed.connect(func(): _place_panel.visible = false)
	row.add_child(close)
	_place_panel.visible = true

func _kingdom_name() -> String:
	var c := Journey.capital_castle(Journey.kingdom)
	return c.castle_name if c != null else KingdomEnums.kingdom_name(Journey.kingdom)

func _on_arrived(i: int) -> void:
	Sfx.play("travel_hop", -6.0)
	if not Journey.is_traveling():
		_select(i)
		_contract_arrival(i)

## Fase 5: al llegar al destino de un encargo, se resuelve (o hay pelea).
func _contract_arrival(i: int) -> void:
	var r: Dictionary = ContractData.on_arrived(Journey.kingdom, i)
	if r.is_empty():
		return
	if r.has("fight"):
		var fight: Dictionary = r.fight
		_message(str(r.title), "Al llegar, te cortan el paso. ¡Hay que pelear!", func():
			var scene := CombatSetup.begin_event_fight(fight, str(r.title))
			if not scene.is_empty():
				get_tree().change_scene_to_file(scene))
	else:
		_message(str(r.title), str(r.text))

func _after_month() -> void:
	_check_events()

# --- Sucesos y noticias ---

func _check_events() -> void:
	if not is_inside_tree() or is_instance_valid(_dialog):
		return
	if not GameManager.game_over_reason.is_empty() or not GameManager.is_game_active:
		_message("Fin de la partida", GameManager.game_over_reason, func(): get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn"))
		return
	var lapsed: Array = ContractData.check_deadlines()
	if not lapsed.is_empty():
		_message("Encargos", "
".join(lapsed))
		return
	if GameManager.has_pending_event():
		_show_event(GameManager.pending_event)
	elif WorldEvents.has_notifications():
		var n := WorldEvents.pop_notification()
		_message(str(n.title), str(n.text))

func _dialog_box(title_text: String) -> VBoxContainer:
	Journey.block()
	_dialog = Control.new()
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog.z_index = 30
	_dialog.tree_exited.connect(Journey.unblock)
	add_child(_dialog)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	return box

func _rich(box: Node, text: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.text = StatIcons.richify(text)
	box.add_child(r)
	return r

func _message(title_text: String, text: String, then: Callable = Callable()) -> void:
	if is_instance_valid(_dialog):
		_dialog.queue_free()
	var box := _dialog_box(title_text)
	var faces := MentionedFaces.row(text, 56)
	if faces != null:
		box.add_child(faces)
	_rich(box, text)
	var ok := Button.new()
	ok.text = "Continuar"
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(func():
		_dialog.queue_free()
		_dialog = null
		if then.is_valid():
			then.call()
		else:
			_check_events.call_deferred())
	box.add_child(ok)
	ok.grab_focus.call_deferred()

func _show_event(e: Dictionary) -> void:
	var box := _dialog_box(str(e.get("title", "Suceso")))
	var speaker: Relationship = RelationsData.get_relation(e.get("speaker", ""))
	if speaker != null and speaker.character != null:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(FaceIcon.make(speaker.character, 72, Color("d4af5a")))
		var q := Label.new()
		q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		q.text = "%s\n«%s»" % [speaker.person_name, e.get("quote", "")] if not str(e.get("quote", "")).is_empty() else speaker.person_name
		row.add_child(q)
		box.add_child(row)
	else:
		var faces := MentionedFaces.row(str(e.get("text", "")), 56)
		if faces != null:
			box.add_child(faces)
	_rich(box, str(e.get("text", "")))
	var player: Character = GameManager.player_character
	var castle := MapData.get_castle_by_id(GameManager.home_castle_id)
	var opts := VBoxContainer.new()
	opts.add_theme_constant_override("separation", 4)
	box.add_child(opts)
	for i in e.options.size():
		var o: Dictionary = e.options[i]
		var b := Button.new()
		b.text = o.label
		if o.has("chance"):
			b.text += " (%d%% de éxito)" % roundi(EventCatalog.success_chance(o, player) * 100)
		if not EventCatalog.can_choose(o, player, castle):
			b.disabled = true
			b.tooltip_text = EventCatalog.requirement_text(o)
		b.pressed.connect(_choose.bind(i, box, opts))
		opts.add_child(b)

func _choose(index: int, box: VBoxContainer, opts: Control) -> void:
	var e: Dictionary = GameManager.pending_event
	var target: Relationship = RelationsData.get_relation(e.get("target", e.get("speaker", "")))
	var duel_rival: Relationship = RelationsData.get_relation(e.get("duel_with", e.get("speaker", "")))
	var o: Dictionary = e.options[index]
	_pending_duel_to_death = o.get("to_death", false)
	_pending_fight = CombatSetup.tag_fight(o.get("fight", {}), "historia" if o.get("effects", {}).has("story") else "camino")
	_pending_fight_title = e.get("title", "Combate")
	var result := GameManager.resolve_pending_event(index, target)
	WorldEvents.record("%s: %s. %s" % [e.get("title", "Suceso"), o.get("label", ""), result.get_slice("\n", 0)], "", true)
	_pending_duel_rival = duel_rival.character if o.get("start_duel", false) and duel_rival != null else null
	opts.queue_free()
	_rich(box, result)
	var go := Button.new()
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.text = "¡Al duelo!" if _pending_duel_rival != null else ("¡Al combate!" if not _pending_fight.is_empty() else "Continuar")
	go.pressed.connect(_after_choice)
	box.add_child(go)
	go.grab_focus.call_deferred()
	_refresh()

func _after_choice() -> void:
	_dialog.queue_free()
	_dialog = null
	var talk_to := RelationsData.get_relation(TravelerData.take_conversation())
	if talk_to != null:
		load("res://scripts/ui/conversation_panel.gd").open(self, talk_to)
	if not _pending_fight.is_empty():
		var scene := CombatSetup.begin_event_fight(_pending_fight, _pending_fight_title)
		_pending_fight = {}
		if not scene.is_empty():
			get_tree().change_scene_to_file(scene)
			return
	if _pending_duel_rival != null:
		var rival := _pending_duel_rival
		_pending_duel_rival = null
		rival.current_health = rival.max_health
		CombatSetup.start_campaign_duel(GameManager.player_character, rival)
		CombatSetup.duel_to_death = _pending_duel_to_death
		CombatSetup.return_scene = GameManager.MAP_SCENE
		get_tree().change_scene_to_file(CombatSetup.RPG_SCENE)
		return
	AchievementData.check_all()
	_check_events.call_deferred()

# --- Accesos ---

func _open_party() -> void:
	PartyPanel.open(self)

func _open_relations() -> void:
	if Journey.is_traveling():
		return
	get_tree().change_scene_to_file("res://scenes/relations/relations.tscn")

func _open_journal() -> void:
	var lines: Array[String] = []
	for c: Dictionary in ContractData.active:
		lines.append("Encargo: %s · quedan %d días" % [ContractData.title(c), int(c.deadline) - Journey.day_index()])
	if not lines.is_empty():
		lines.append("")
	for e: Dictionary in WorldEvents.chronicle.slice(maxi(0, WorldEvents.chronicle.size() - 30)):
		lines.push_front("• " + str(e.get("text", "")))
	_message("Diario", "\n".join(lines) if not lines.is_empty() else "Nada que contar todavía.")

func _open_menu() -> void:
	var box := _dialog_box("Menú")
	var specs := [
		["Guardar partida", func():
			if Journey.is_traveling():
				return
			SaveSystem.slots_mode = "save"
			SaveSystem.slots_return_scene = GameManager.MAP_SCENE
			get_tree().change_scene_to_file("res://scenes/save_slots/save_slots.tscn")],
		["Opciones", func(): OptionsPanel.open(self)],
		["Mapa antiguo (provisional)", func(): get_tree().change_scene_to_file(GameManager.OLD_MAP_SCENE)],
		["Salir al menú principal", func():
			SaveSystem.save_game()
			GameManager.change_state(GameStateEnums.State.MENU)
			get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")],
		["Volver", func():
			_dialog.queue_free()
			_dialog = null],
	]
	for s in specs:
		var b := Button.new()
		b.text = s[0]
		b.pressed.connect(s[1])
		box.add_child(b)

# --- Mapa del mundo ---

func _open_world() -> void:
	if is_instance_valid(_world):
		return
	Journey.block()
	_world = Control.new()
	_world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world.z_index = 20
	_world.tree_exited.connect(Journey.unblock)
	add_child(_world)
	var bg := ColorRect.new()
	bg.color = Color("0d1a2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world.add_child(bg)
	var map := TextureRect.new()
	map.texture = load("res://assets/maps/world_map.png")
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world.add_child(map)
	var tex_size := Vector2(MapData.MAP_WIDTH, MapData.MAP_HEIGHT)
	var k := minf(size.x / tex_size.x, size.y / tex_size.y)
	var origin := (size - tex_size * k) * 0.5
	for kd in KingdomEnums.Kingdom.values():
		var c := Journey.capital_castle(kd)
		if c == null:
			continue
		var r := Journey.world_route(kd)
		var b := Button.new()
		b.text = ("★ " if kd == Journey.kingdom else "") + c.castle_name
		if kd != Journey.kingdom:
			b.tooltip_text = ("%s · ≈%d h%s" % ["Por mar" if r.sea else "Por tierra", roundi(r.hours), (" · pasaje %d de oro" % r.cost) if r.cost > 0 else ""]) if r.ok else str(r.why)
			b.disabled = not r.ok
			b.pressed.connect(func():
				var why := Journey.travel_to_kingdom(kd)
				if why.is_empty():
					_world.queue_free()
					_build_nodes()
					_layout.call_deferred()
					_refresh()
					_check_events.call_deferred()
				else:
					b.tooltip_text = why)
		else:
			b.disabled = true
		_world.add_child(b)
		b.reset_size()
		b.position = origin + c.position_on_map * k - b.size * 0.5
	var close := Button.new()
	close.text = "Cerrar"
	close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close.offset_left = -110
	close.offset_top = 12
	close.offset_right = -12
	close.pressed.connect(_world.queue_free)
	_world.add_child(close)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(_world):
			_world.queue_free()
		elif _place_panel.visible:
			_place_panel.visible = false
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and false:
		pass
