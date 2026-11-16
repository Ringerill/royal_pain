extends Control
# Rediseño v2, fase 5: un lugar habitado (capital, ciudad, pueblo o puerto) por dentro.
# Fuera: la escena del lugar (según estación y noche) con botones de sus edificios.
# Dentro: modo novela visual — fondo del interior, el PNJ en grande con su expresión, su frase y
# las opciones (comprar, mejorar, encargos, rumores, apuestas, curar, donar, estudiar, dormir…).
# El lugar es donde está el viaje (Journey.at). «Salir» vuelve al mapa del reino.

const NameCatalog = preload("res://scripts/resources/name_catalog.gd")

const BUILDINGS := {
	"tienda": {"name": "Tienda", "icon": "two-coins", "bg": "shop", "who": "Tendero", "gender": -1},
	"herreria": {"name": "Herrería", "icon": "upgrade", "bg": "shop", "who": "Herrero", "gender": 0},
	"taberna": {"name": "Taberna", "icon": "beer-stein", "bg": "tavern", "who": "Tabernera", "gender": 1},
	"iglesia": {"name": "Iglesia", "icon": "holy-grail", "bg": "church", "who": "Sacerdotisa", "gender": 1},
	"biblioteca": {"name": "Biblioteca", "icon": "open-book", "bg": "library", "who": "Bibliotecario", "gender": 0},
	"posada": {"name": "Posada", "icon": "bindle", "bg": "room", "who": "Posadero", "gender": 0},
	"casa": {"name": "Tu casa", "icon": "castle", "bg": "home_hallway", "who": "Criada", "gender": 1},
	"callejon": {"name": "Callejón", "icon": "running-ninja", "bg": "back_alley", "who": "Contrabandista", "gender": -1},
}
const BY_TYPE := {
	"capital": ["tienda", "herreria", "taberna", "iglesia", "biblioteca", "posada", "casa", "callejon"],
	"ciudad": ["tienda", "herreria", "taberna", "iglesia", "biblioteca", "posada", "casa", "callejon"],
	"puerto": ["tienda", "herreria", "taberna", "posada", "callejon"],
	"pueblo": ["tienda", "taberna", "iglesia", "posada"],
}
# Nivel máximo de equipo que vende la herrería y nivel de mercado de la tienda.
const FORGE_MAX := {"capital": 6, "ciudad": 5, "puerto": 4, "pueblo": 2}
const MARKET := {"capital": 3, "ciudad": 2, "puerto": 1, "pueblo": 0}
const HOUSE_PRICE := {"capital": 3000, "ciudad": 1800, "puerto": 1200, "pueblo": 700}
const INN_PRICE := 10
const HEAL_PRICE := 25
const DONATION := 50
const DONATION_FAME := 2
const STUDY_HOURS := 4.0
const STUDY_XP_PER_LEVEL := 12
const BET := 20
const BET_WIN := 0.47
const UPGRADE_MARKUP := 1.2
const SELL_SHARE := 0.4

var _k := 0
var _i := 0
var _type := "pueblo"
var _bg: TextureRect
var _shade: ColorRect
var _outside: Control
var _inside: Control
var _clock: Label
var _gold: Label
var _npc: TextureRect
var _npc_name: Label
var _line: RichTextLabel
var _options: VBoxContainer
var _list: VBoxContainer
var _building := ""
var _npcs := {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_k = Journey.kingdom
	_i = Journey.at
	_type = str(Journey.node(_i).type)
	_build()
	_show_outside()
	if not Journey.changed.is_connected(_refresh_hud):
		Journey.changed.connect(_refresh_hud)

# --- Montaje ---

func _build() -> void:
	_bg = TextureRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_bg)
	_shade = ColorRect.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 10
	top.add_theme_constant_override("separation", 14)
	add_child(top)
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = "%s · %s" % [Journey.node_name(_i), KingdomMaps.TYPE_NAMES.get(_type, _type)]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_outline(title)
	top.add_child(title)
	_clock = Label.new()
	_outline(_clock)
	top.add_child(_clock)
	_gold = Label.new()
	_outline(_gold)
	top.add_child(_gold)
	_outside = VBoxContainer.new()
	add_child(_outside)
	_inside = Control.new()
	_inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_inside)
	_build_inside()
	_refresh_hud()

func _outline(l: Label) -> void:
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)

func _refresh_hud() -> void:
	if _clock == null:
		return
	_clock.text = Journey.clock_text()
	_gold.text = "%d de oro · Energía %d" % [GameManager.player_character.gold, GameManager.player_character.energy]

func _show_outside() -> void:
	_building = ""
	_inside.visible = false
	_bg.texture = PlaceArt.scene_now("port" if _type == "puerto" else ("city_inside" if _type in ["capital", "ciudad"] else "city_outside"))
	_shade.color = Color(0, 0, 0, 0.25 if not Journey.is_night() else 0.45)
	for ch in _outside.get_children():
		ch.queue_free()
	_outside.visible = true
	_outside.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_outside.offset_top = -170
	_outside.offset_left = 24
	_outside.offset_right = -24
	_outside.offset_bottom = -20
	_outside.add_theme_constant_override("separation", 8)
	var hint := Label.new()
	hint.text = "¿A dónde vas?" + ("  (de noche, algunos edificios cierran)" if Journey.is_night() else "")
	_outline(hint)
	_outside.add_child(hint)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	_outside.add_child(row)
	for id: String in buildings():
		var d: Dictionary = BUILDINGS[id]
		var b := Button.new()
		b.text = d.name if id != "casa" or owns_house() else "Casa (en venta)"
		b.icon = SkillIcons.texture(d.icon)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 28)
		b.custom_minimum_size = Vector2(150, 48)
		var why := closed_reason(id)
		b.disabled = not why.is_empty()
		b.tooltip_text = why
		b.pressed.connect(enter.bind(id))
		row.add_child(b)
	var people := RelationsData.people_here()
	if not people.is_empty():
		var pb := Button.new()
		pb.text = "Gente aquí (%d)" % people.size()
		pb.icon = SkillIcons.texture("conversation")
		pb.expand_icon = false
		pb.add_theme_constant_override("icon_max_width", 28)
		pb.custom_minimum_size = Vector2(150, 48)
		pb.pressed.connect(_people)
		row.add_child(pb)
	var out := Button.new()
	out.text = "Salir al mapa"
	out.custom_minimum_size = Vector2(150, 48)
	out.pressed.connect(func(): get_tree().change_scene_to_file(GameManager.MAP_SCENE))
	row.add_child(out)

func buildings() -> Array:
	var list: Array = BY_TYPE.get(_type, BY_TYPE.pueblo).duplicate()
	if not Journey.is_night():
		list.erase("callejon")
	return list

## Por qué un edificio está cerrado ("" si abierto). De noche solo abren taberna, posada, casa y callejón.
func closed_reason(id: String) -> String:
	if Journey.is_night() and not id in ["taberna", "posada", "casa", "callejon"]:
		return "Cerrado de noche."
	return ""

func house_key() -> String:
	return ContractData.node_key(_k, _i)

func owns_house() -> bool:
	return house_key() in Journey.houses

# --- Interior (novela visual) ---

func _build_inside() -> void:
	_npc = TextureRect.new()
	_npc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_npc.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_npc.anchor_left = 0.0
	_npc.anchor_right = 0.45
	_npc.anchor_top = 0.08
	_npc.anchor_bottom = 1.0
	_npc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inside.add_child(_npc)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.42
	panel.anchor_right = 0.98
	panel.anchor_top = 0.12
	panel.anchor_bottom = 0.97
	_inside.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	_npc_name = Label.new()
	_npc_name.theme_type_variation = &"HeaderLabel"
	col.add_child(_npc_name)
	_line = RichTextLabel.new()
	_line.bbcode_enabled = true
	_line.fit_content = true
	_line.scroll_active = false
	_line.add_theme_font_size_override("normal_font_size", 17)
	col.add_child(_line)
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 4)
	col.add_child(_options)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)

## PNJ del edificio: siempre el mismo en este lugar (retrato con hoja de expresiones y nombre propio).
func npc(id: String) -> Character:
	if _npcs.has(id):
		return _npcs[id]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%s" % [house_key(), id])
	var g: int = BUILDINGS[id].gender
	if g < 0:
		g = rng.randi() % 2
	var gender := CharacterEnums.Gender.MASCULINO if g == 0 else CharacterEnums.Gender.FEMENINO
	var c := Character.new()
	c.gender = gender
	c.first_name = NameCatalog.first_name(0, gender, rng)
	c.last_name = ""
	var pics := PortraitGallery.get_portraits_for_gender(gender)
	if not pics.is_empty():
		c.portrait = load(pics[rng.randi() % pics.size()])
	_npcs[id] = c
	return c

func enter(id: String) -> void:
	_building = id
	_outside.visible = false
	_inside.visible = true
	_bg.texture = PlaceArt.scene_now(BUILDINGS[id].bg)
	_shade.color = Color(0, 0, 0, 0.15)
	var who := npc(id)
	_npc_name.text = "%s, %s" % [who.first_name, BUILDINGS[id].who.to_lower()]
	match id:
		"tienda": _shop()
		"herreria": _forge()
		"taberna": _tavern()
		"iglesia": _church()
		"biblioteca": _library()
		"posada": _inn()
		"casa": _house()
		"callejon": _alley()

func say(text: String, expr: String = "") -> void:
	if expr.is_empty():
		expr = PlaceArt.tone(text)
	_npc.texture = PlaceArt.expression(npc(_building), expr)
	_line.text = StatIcons.richify(text, 17)
	_refresh_hud()

func _clear() -> void:
	for box in [_options, _list]:
		for ch in box.get_children():
			box.remove_child(ch)
			ch.queue_free()

func option(text: String, cb: Callable, disabled := false, tip := "") -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = disabled
	b.tooltip_text = tip
	b.pressed.connect(cb)
	_options.add_child(b)
	return b

func _leave_option() -> void:
	option("Salir", _show_outside)

func _row(text: String, icon: Texture2D, btn: String, cb: Callable, disabled := false, tip := "") -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	if icon != null:
		var t := TextureRect.new()
		t.texture = icon
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = Vector2(36, 36)
		h.add_child(t)
	var l := Label.new()
	l.text = text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.tooltip_text = tip
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(l)
	var b := Button.new()
	b.text = btn
	b.disabled = disabled
	b.pressed.connect(cb)
	h.add_child(b)
	_list.add_child(h)

func _player() -> Character:
	return GameManager.player_character

## Precios: la vía Humilde paga menos (ViaCatalog: prices −30 %).
static func price(amount: int) -> int:
	var p: Character = GameManager.player_character
	var mult := 1.0 + float(ViaCatalog.bonus(p.via, "prices", 0.0)) if p != null and p.via >= 0 else 1.0
	return maxi(1, roundi(amount * mult))

func _pay(amount: int) -> bool:
	amount = price(amount)
	if _player().gold < amount:
		say("No te llega el oro.", "serio")
		return false
	_player().gold -= amount
	return true

# --- Tienda: objetos y accesorios ---

func _shop(msg: String = "") -> void:
	_clear()
	say(msg if not msg.is_empty() else "¡Bienvenido! Mira lo que tengo; todo es de fiar.")
	var bag: Dictionary = _player().consumables
	for id: String in ConsumableCatalog.shop_items(int(MARKET.get(_type, 0))):
		if id == "tomo_olvido":
			continue
		var price := int(ConsumableCatalog.item(id).price)
		var have := ConsumableCatalog.count(bag, id)
		_row("%s — %d de oro (llevas %d)" % [ConsumableCatalog.item_name(id), price, have], ConsumableCatalog.icon_texture(id),
			"Comprar", func():
				if have >= ConsumableCatalog.MAX_STACK:
					_shop("No te caben más.")
				elif _pay(price):
					ConsumableCatalog.add(bag, id)
					_shop("Buena elección."),
			false, str(ConsumableCatalog.item(id).desc))
	var top := int(FORGE_MAX.get(_type, 2))
	for e: Dictionary in GearCatalog.entries():
		if e.slot == "Accesorio" and not e.get("unique_gear", false) and int(e.gear.level) <= mini(top, 5):
			_gear_row(e, _shop)
	_leave_option()

func _gear_row(e: Dictionary, back: Callable) -> void:
	var price := int(e.price)
	_row("%s — %d de oro" % [e.name, price], GearCatalog.icon(e.name), "Comprar", func():
		if _pay(price):
			var item := _make(e.name)
			PartyData.stash.append(item)
			back.call("Ahí lo tienes. Lo dejo en el almacén del grupo; equípalo desde Grupo."),
		false, GearCatalog.describe(e.name))

func _make(name: String) -> Equipment:
	for it: Equipment in GameData.equipment_catalog:
		if it.equipment_name == name:
			return it.duplicate()
	return null

# --- Herrería: armas, escudos y armaduras; mejorar y vender ---

func _forge(msg: String = "") -> void:
	_clear()
	say(msg if not msg.is_empty() else "Acero honrado. Si traes tu arma, te la mejoro.")
	var top := int(FORGE_MAX.get(_type, 2))
	var weapon := _weapon()
	if weapon != null:
		var e := GearCatalog.entry(weapon.equipment_name)
		var lvl := int(e.get("gear", {}).get("level", 0))
		if not e.is_empty() and lvl < GearCatalog.PROGRESSION and lvl < top:
			var next := GearCatalog.weapon_name(str(e.gear.type), lvl + 1)
			var cost := upgrade_cost(weapon.equipment_name)
			option("Mejorar %s → %s (%d de oro)" % [weapon.equipment_name, next, cost], func():
				if _pay(cost):
					var item := _make(next)
					var old := _player().equip(item)
					if old != null:
						pass   # el arma vieja se funde en la mejora
					_forge("Listo. Nota el peso: %s." % next), false, GearCatalog.describe(next))
	for e: Dictionary in GearCatalog.entries():
		if e.slot in ["Arma", "Escudo", "Armadura"] and int(e.gear.level) <= top and e.tier != GearCatalog.UNIQUE_TIER:
			_gear_row(e, _forge)
	for item: Equipment in PartyData.stash.duplicate():
		var gain := roundi(item.price * SELL_SHARE)
		_row("Vender %s — %d de oro" % [item.equipment_name, gain], item.icon, "Vender", func():
			PartyData.stash.erase(item)
			_player().gold += gain
			_forge("Te doy %d por ella. Ni una moneda más." % gain))
	_leave_option()

func _weapon() -> Equipment:
	for e: Equipment in _player().equipment:
		if e != null and e.slot == "Arma":
			return e
	return null

## Precio de subir un nivel el arma: la diferencia de precio, con recargo.
static func upgrade_cost(name: String) -> int:
	var e := GearCatalog.entry(name)
	if e.is_empty():
		return 0
	var lvl := int(e.gear.level)
	var next := GearCatalog.entry(GearCatalog.weapon_name(str(e.gear.type), lvl + 1))
	return maxi(10, roundi((int(next.price) - int(e.price)) * UPGRADE_MARKUP))

# --- Taberna: rumores, tablón de encargos, apuestas ---

func _tavern(msg: String = "") -> void:
	_clear()
	say(msg if not msg.is_empty() else "¡Pasa, pasa! ¿Cerveza, rumores o trabajo?")
	option("Escuchar rumores", func():
		_clear()
		say(PlaceArt.rumor(), "neutral")
		option("Volver", _tavern))
	option("Tablón de encargos", _board.bind(false))
	option("Hacer faenas (%d h)" % int(ViaData.CHORE_HOURS), func(): _tavern(ViaData.chore()), _player().energy < 15, "Trabajo honrado: oro y fama de buena gente (vía Humilde).")
	option("Apostar a los dados (%d de oro)" % BET, func():
		if not _pay(BET):
			return
		if randf() < BET_WIN:
			_player().gold += BET * 2
			_tavern("¡Seis y seis! Te llevas %d." % (BET * 2))
		else:
			_tavern("Mala suerte, forastero. La casa gana."), _player().gold < BET)
	_leave_option()

func _board(night: bool, msg: String = "") -> void:
	_clear()
	var offers := ContractData.board(_k, _i, night)
	say(msg if not msg.is_empty() else ("Si buscas trabajo, aquí lo hay." if not night else "Discreción. Y nada de preguntas."))
	var why := ContractData.can_accept()
	for c: Dictionary in offers:
		_row("%s\n%s" % [ContractData.title(c), ContractData.describe(c)], SkillIcons.texture("treasure-map"), "Aceptar", func():
			ContractData.accept(c)
			_board(night, "Trato hecho. No me falles."), not why.is_empty(), why)
	if offers.is_empty():
		_row("No queda nada en el tablón esta semana.", null, "—", func(): pass, true)
	for c: Dictionary in ContractData.active:
		_row("En curso: %s (%d días)" % [ContractData.title(c), int(c.deadline) - Journey.day_index()], null, "Abandonar", func():
			_board(night, ContractData.abandon(c.uid)), false, "Abandonar cuesta fama.")
	option("Volver", _alley if night else _tavern)

# --- Iglesia: curar y donar ---

func _church(msg: String = "") -> void:
	_clear()
	say(msg if not msg.is_empty() else "La paz sea contigo. ¿En qué puedo ayudarte?")
	var hurt := _group().any(func(c: Character) -> bool: return c.current_health < c.max_health)
	option("Curar al grupo (%d de oro)" % HEAL_PRICE, func():
		if _pay(HEAL_PRICE):
			for c: Character in _group():
				c.current_health = c.max_health
			_church("Que tus heridas sanen. Ve con cuidado."), not hurt, "Nadie está herido." if not hurt else "")
	option("Repartir limosna (%d de oro)" % ViaData.ALMS_GOLD, func(): _church(ViaData.alms()), _player().gold < ViaData.ALMS_GOLD, "Clemencia con los necesitados (vía Benevolente).")
	var donated := Journey.day_index() / ContractData.REFRESH_DAYS == int(Journey.donations.get(house_key(), -1))
	option("Donar %d de oro (fama +%d)" % [DONATION, DONATION_FAME], func():
		if _pay(DONATION):
			_player().add_fame(DONATION_FAME)
			Journey.donations[house_key()] = Journey.day_index() / ContractData.REFRESH_DAYS
			_church("Gracias. Tu nombre se recordará en las oraciones."), donated, "Ya donaste esta semana." if donated else "")
	_leave_option()

func _group() -> Array:
	var out: Array = [_player()]
	for c: Character in PartyData.members():
		if not c in out:
			out.append(c)
	return out

# --- Biblioteca: estudiar ---

func _library(msg: String = "") -> void:
	_clear()
	say(msg if not msg.is_empty() else "Silencio, por favor. Los libros no muerden… casi nunca.")
	var studied := int(Journey.studies.get(house_key(), -1)) == Journey.day_index()
	option("Estudiar (%d h)" % int(STUDY_HOURS), func():
		Journey.wait_hours(STUDY_HOURS)
		var xp := STUDY_XP_PER_LEVEL * _player().level
		_player().gain_xp(xp, "study")
		Journey.studies[house_key()] = Journey.day_index()
		_library("Has aprovechado bien las horas: +%d de experiencia." % xp), studied, "Ya estudiaste hoy aquí." if studied else "")
	_leave_option()

# --- Posada y casa: dormir ---

func _inn(msg: String = "") -> void:
	_clear()
	say(msg if not msg.is_empty() else "Cama limpia y sopa caliente, %d de oro la noche." % INN_PRICE)
	option("Dormir (8 h, %d de oro)" % INN_PRICE, func():
		if _pay(INN_PRICE):
			Journey.sleep()
			_inn("Buenos días. Has dormido como un tronco."))
	_leave_option()

func _house(msg: String = "") -> void:
	_clear()
	if owns_house():
		say(msg if not msg.is_empty() else "Bienvenido a casa. Todo está en orden.", "alegre")
		option("Dormir (8 h, gratis)", func():
			Journey.sleep()
			_house("Buenos días. La casa sigue en pie."))
	else:
		var price := int(HOUSE_PRICE.get(_type, 1000))
		say("Esta casa está en venta: %d de oro. Dormirías gratis y a salvo cuando pases por aquí." % price, "serio")
		option("Comprarla (%d de oro)" % price, func():
			if _pay(price):
				Journey.houses.append(house_key())
				_house("¡Enhorabuena! La casa es tuya."), _player().gold < price)
	_leave_option()

# --- Gente del lugar (rediseño v2: solo se trata con quien está aquí) ---

func _people() -> void:
	_building = "taberna"
	enter("taberna")
	_clear()
	say("Hoy hay buena gente por aquí. ¿Con quién quieres hablar?")
	for r: Relationship in RelationsData.people_here():
		_row("%s — %s" % [r.person_name, RelationsData.intimacy_label(r)], r.character.get_face() if r.character != null else null, "Hablar", func():
			load("res://scripts/ui/conversation_panel.gd").open(self, r))
	_leave_option()

# --- Callejón (de noche): encargos turbios ---

func _alley(msg: String = "") -> void:
	_clear()
	say(msg if not msg.is_empty() else "¿Buscas algo que no se vende a la luz del día?", "serio")
	option("Encargos turbios", _board.bind(true))
	option("Extorsionar a los comerciantes", func(): _alley(ViaData.extort()), false, "Oro fácil a cambio de fama (vía Villano).")
	_leave_option()
