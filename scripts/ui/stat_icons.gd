class_name StatIcons
extends RefCounted
# Iconos de recursos, atributos, relaciones y roles (game-icons.net, CC BY 3.0, en
# assets/icons/game-icons/, los copia tools/build_skill_icons.py). Sirven para cambiar texto por
# iconos en toda la interfaz: «[oro] 120» en vez de «Oro 120». El nombre va en la ayuda del icono.
#   StatIcons.icon("oro", 16)                 → TextureRect teñido
#   StatIcons.pair(parent, "oro", "120")      → [icono] 120 (una fila; devuelve el HBox)
#   StatIcons.row(parent, [["oro", "120"], ["honor", "15"]])
#   StatIcons.role_icon(personaje, 16) · StatIcons.relation_icon(relación, 16)
#   StatIcons.bb("oro", 16)                   → «[img]» para RichTextLabel

const ICONS := {
	"oro": "two-coins", "soldados": "spartan-helmet", "honor": "laurel-crown", "fama": "trumpet",
	"comida": "wheat", "vida": "heart-plus", "nivel": "upgrade", "acciones": "sprint",
	"combate": "crossed-swords", "defensa": "checked-shield", "agilidad": "running-ninja",
	"estrategia": "chess-knight", "liderazgo": "flying-flag", "carisma": "conversation",
	"odio": "angry-eyes", "rivalidad": "sword-clash", "amistad": "shaking-hands", "amor": "heart-wings",
	"casados": "linked-rings", "neutral": "person", "castillo": "castle", "batalla": "crossed-swords", "pt": "sparkles",
	"rol_campesino": "farmer", "rol_soldado": "swordman", "rol_caballero": "visored-helm",
	"rol_capitan": "captain-hat-profile", "rol_nobleza_baja": "tiara", "rol_nobleza_alta": "crown",
	"rol_duque": "crown", "rol_regente": "imperial-crown", "rol_inafiliado": "bindle",
}
const NAMES := {
	"oro": "Oro", "soldados": "Soldados", "honor": "Honor", "fama": "Fama", "comida": "Comida",
	"vida": "Vida", "nivel": "Nivel", "acciones": "Acciones", "combate": "Combate", "defensa": "Defensa",
	"agilidad": "Agilidad", "estrategia": "Estrategia", "liderazgo": "Liderazgo", "carisma": "Carisma",
	"odio": "Odio", "rivalidad": "Rivalidad", "amistad": "Amistad", "amor": "Amor", "casados": "Matrimonio", "castillo": "Castillo", "batalla": "Batalla", "pt": "Puntos de técnica",
	"neutral": "Sin lazos",
}
const COLORS := {
	"oro": Color("f0c75a"), "soldados": Color("c8c0b0"), "honor": Color("e8d9a0"), "fama": Color("e0a85a"),
	"comida": Color("d8b870"), "vida": Color("e0645a"), "nivel": Color("9fd08a"), "acciones": Color("9fc4e0"),
	"combate": Color("e8826e"), "defensa": Color("9fc4e0"), "agilidad": Color("9fd08a"),
	"estrategia": Color("c48ae0"), "liderazgo": Color("f0d48a"), "carisma": Color("f0b4c8"),
	"odio": Color("d0453a"), "rivalidad": Color("e8906a"), "amistad": Color("8fd08a"), "amor": Color("f07a9a"),
	"casados": Color("f0c75a"), "neutral": Color("a89a88"), "castillo": Color("e8d9a0"), "batalla": Color("e8826e"), "pt": Color("7fb8e8"),
}
const ROLE_COLOR := Color("e8d9a0")
# Accesorios y monturas: la primera palabra clave del nombre que aparezca elige el icono.
const ITEM_ICONS := [["Sello", "wax-seal"], ["Mapa", "treasure-map"], ["Capa", "cape"],
	["Amuleto de la Suerte", "clover"], ["Amuleto", "tribal-pendant"], ["Estandarte", "knight-banner"],
	["Oriflama", "knight-banner"], ["Anillo", "ring"], ["Cuerno", "hunting-horn"], ["Olifante", "hunting-horn"],
	["Reliqu", "holy-grail"], ["Relicario", "holy-grail"], ["Libro", "open-book"], ["Manual", "open-book"],
	["Epitoma", "open-book"], ["Hierbas", "herbs-bundle"], ["Yelmo", "visored-helm"], ["Bastón", "winged-scepter"],
	["Broche", "gem-pendant"], ["Tablillas", "wax-tablet"], ["Muñequeras", "bracer"], ["Botas", "leather-boot"]]
const ITEM_ICON_FALLBACK := {"Montura": "horse-head", "Accesorio": "gem-pendant"}
const ITEM_COLOR := Color("d8c49a")
# Consumibles (id de ConsumableCatalog) -> icono.
const CONSUMABLE_ICONS := {"venda": "bandage-roll", "unguento": "medicines", "pan_vino": "bread",
	"cerveza": "beer-stein", "aceite": "fire-bottle", "piedra": "stone-block", "agua_bendita": "holy-water",
	"humo": "smoke-bomb", "red": "fishing-net", "tomo_olvido": "evil-book", "hierbas": "herbs-bundle"}
const CONSUMABLE_COLOR := Color("c8d8a0")
# Atributo del personaje (propiedad de Character) -> clave del icono.
const ATTRS := {"combat": "combate", "defense": "defensa", "agility": "agilidad", "strategy": "estrategia",
	"leadership": "liderazgo", "charisma": "carisma"}

## Nombre del icono (archivo) de una clave.
static func icon_name(key: String) -> String:
	return ICONS.get(key, "help")

static func texture(key: String) -> Texture2D:
	return SkillIcons.texture(icon_name(key))

static func icon(key: String, size: int = 16, tip: String = "") -> TextureRect:
	return SkillIcons.make(texture(key), size, COLORS.get(key, ROLE_COLOR), tip if not tip.is_empty() else NAMES.get(key, ""))

## [icono] valor, en una fila compacta.
static func pair(parent: Node, key: String, value: String, size: int = 16, tip: String = "") -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.tooltip_text = tip if not tip.is_empty() else NAMES.get(key, "")
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	var ic := icon(key, size, h.tooltip_text)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := Label.new()
	l.text = value
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(l)
	if parent != null:
		parent.add_child(h)
	return h

## Varias parejas seguidas: [[clave, valor], ...]. Devuelve el HBox.
static func row(parent: Node, items: Array, size: int = 16, gap: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", gap)
	for it: Array in items:
		pair(h, it[0], str(it[1]), size, str(it[2]) if it.size() > 2 else "")
	if parent != null:
		parent.add_child(h)
	return h

## Los seis atributos de un personaje como iconos con su valor.
static func attributes(parent: Node, c: Character, size: int = 16) -> HBoxContainer:
	var items := []
	for prop: String in ATTRS:
		items.append([ATTRS[prop], c.get(prop)])
	return row(parent, items, size, 10)

# --- Roles ---

static func role_key(role: int) -> String:
	match role:
		Character.Role.CAMPESINO: return "rol_campesino"
		Character.Role.SOLDADO, Character.Role.MERCENARIO: return "rol_soldado"
		Character.Role.CABALLERO: return "rol_caballero"
		Character.Role.CAPITAN, Character.Role.CONDOTIERO: return "rol_capitan"
		Character.Role.NOBLEZA_BAJA: return "rol_nobleza_baja"
		Character.Role.NOBLEZA_ALTA: return "rol_nobleza_alta"
		Character.Role.DUQUE: return "rol_duque"
		Character.Role.REGENTE: return "rol_regente"
		Character.Role.INAFILIADO: return "rol_inafiliado"
	return "rol_soldado"

## Icono del rol (al lado del nombre); su ayuda dice el título.
static func role_icon(c: Character, size: int = 16) -> TextureRect:
	if c == null:
		return SkillIcons.make(null, size)
	return SkillIcons.make(texture(role_key(c.role)), size, ROLE_COLOR, c.role_title())

## [rol] Nombre, en una fila.
static func named(parent: Node, c: Character, text: String = "", size: int = 16) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var ic := role_icon(c, size)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := Label.new()
	l.text = text if not text.is_empty() else (c.full_name() if c != null else "")
	h.add_child(l)
	if parent != null:
		parent.add_child(h)
	return h

# --- Relaciones ---

## Lazo más fuerte con el jugador: casados, amor, amistad, rivalidad u odio (o ninguno).
static func relation_key(r: Relationship) -> String:
	if r == null:
		return "neutral"
	if r.kind == Relationship.Kind.CONYUGE:
		return "casados"
	if r.romance and r.affection >= Relationship.ROMANCE_COURTSHIP:
		return "amor"
	if r.kind == Relationship.Kind.RIVAL_DUELO and r.rivalry_stage() in [Relationship.RivalryStage.RIVAL, Relationship.RivalryStage.NEMESIS]:
		return "odio" if r.rivalry_stage() == Relationship.RivalryStage.NEMESIS else "rivalidad"
	if r.at_war or r.affinity <= -60:
		return "odio"
	if r.affinity >= 20 or r.affection >= 40:
		return "amistad"
	if r.is_hostile() or r.kind == Relationship.Kind.RIVAL_DUELO:
		return "rivalidad"
	return "neutral"

static func relation_icon(r: Relationship, size: int = 16) -> TextureRect:
	var key := relation_key(r)
	var tip: String = NAMES.get(key, "")
	if r != null:
		tip += " · afinidad %+d · intimidad %d" % [r.affinity, r.affection]
	return icon(key, size, tip)

## Una pieza de equipo con iconos: el tipo de daño (arma) o la clase de armadura, el escudo, y sus
## bonos como iconos de atributo («[combate] +1»). Devuelve el HBox (sin el nombre).
const ITEM_MODS := {"combat_mod": "combate", "defense_mod": "defensa", "agility_mod": "agilidad",
	"leadership_mod": "liderazgo", "charisma_mod": "carisma", "strategy_mod": "estrategia"}

static func item_badges(parent: Node, e: Equipment, size: int = 16, with_mods: bool = true) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var type_icon: TextureRect = null
	if RpgStats.WEAPON_BY_ITEM.has(e.equipment_name):
		var dt: int = RpgStats.WEAPON_BY_ITEM[e.equipment_name]
		type_icon = SkillIcons.damage_icon(dt, size)
		type_icon.tooltip_text = "Daño: " + RpgStats.DAMAGE_NAMES[dt]
	elif RpgStats.ARMOR_BY_ITEM.has(e.equipment_name):
		var ac: int = RpgStats.ARMOR_BY_ITEM[e.equipment_name]
		type_icon = SkillIcons.armor_icon(ac, size)
		type_icon.tooltip_text = "Armadura: " + RpgStats.ARMOR_NAMES[ac]
	elif e.slot == "Escudo":
		type_icon = SkillIcons.make(SkillIcons.texture(SkillIcons.SHIELD), size, SkillIcons.ARMOR_COLOR, "Escudo")
	else:
		type_icon = item_icon(e, size)
	if type_icon != null:
		type_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		type_icon.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(type_icon)
	for prop: String in (ITEM_MODS if with_mods else {}):
		var v := int(e.get(prop))
		if v != 0:
			pair(h, ITEM_MODS[prop], "%+d" % v, size - 2)
	if parent != null:
		parent.add_child(h)
	return h

## Texto con iconos en vez de palabras, para un RichTextLabel con bbcode: «+30 oro», «20 de oro»,
## «Honor +3», «+3 favor», «15 soldados»… pasan a ser el número con su icono. Los corchetes del
## texto original se escapan para que no se lean como bbcode.
const RICH_WORDS := {"oro": "oro", "honor": "honor", "fama": "fama", "vida": "vida", "comida": "comida",
	"soldados": "soldados", "favor": "amistad", "afinidad": "amistad", "intimidad": "amor", "exp\\.": "nivel",
	"experiencia": "nivel", "pv": "vida", "pt": "pt", "combate": "combate", "defensa": "defensa",
	"agilidad": "agilidad", "estrategia": "estrategia", "liderazgo": "liderazgo", "carisma": "carisma"}
static var _rich_res := []
static var _rich_with: RegEx
static var _rich_hit: RegEx

static func richify(text: String, size: int = 16) -> String:
	if _rich_res.is_empty():
		for word: String in RICH_WORDS:
			var after := RegEx.new()   # «+30 oro», «20 de oro», «+3 favor de quien encarga»
			after.compile("(?i)([+−\\-]?\\d+)\\s+(?:de\\s+)?" + word + "(?![\\wáéíóúñ])")
			var before := RegEx.new()   # «Honor +3», «Oro: 100»
			before.compile("(?i)(?<![\\wáéíóúñ])" + word + "\\s*:?\\s*([+−\\-]?\\d+)")
			_rich_res.append([after, before, RICH_WORDS[word]])
	if _rich_with == null:   # «Afinidad con Lord X +5», «intimidad con Ana −3»: icono, nombre y número
		_rich_with = RegEx.new()
		_rich_with.compile("(?i)(?<![\\wáéíóúñ])(afinidad|intimidad) con ([^+−\\-\\d(),.;\\n]+?)\\s*([+−\\-]\\d+)")
	var s := text.replace("[", "[lb]")
	if _rich_hit == null:   # combate: «Ana recibe 21» → «Ana −21 [vida]»
		_rich_hit = RegEx.new()
		_rich_hit.compile("(?i)recibe (\\d+)(?!\\s*(?:de\\s+)?(?:oro|honor|fama))")
	s = _rich_hit.sub(s, "−$1 " + bb("vida", size), true)
	for m: RegExMatch in _rich_with.search_all(s):
		var key := "amistad" if m.get_string(1).to_lower() == "afinidad" else "amor"
		s = s.replace(m.get_string(), "%s %s %s" % [bb(key, size), m.get_string(2), m.get_string(3)])
	for r: Array in _rich_res:
		var icon := bb(r[2], size)
		s = (r[0] as RegEx).sub(s, "$1 " + icon, true)
		s = (r[1] as RegEx).sub(s, icon + " $1", true)
	return s

## Un RichTextLabel «gemelo» de un Label ya existente (mismo sitio y tamaño), para mostrar texto con
## iconos sin cambiar la escena: el Label se oculta pero conserva su texto (pruebas, accesibilidad).
## Uso: var rich := StatIcons.rich_twin(label) · luego set_rich(label, texto).
static func rich_twin(label: Label) -> RichTextLabel:
	if label.has_meta("rich_twin"):
		return label.get_meta("rich_twin")
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.size_flags_horizontal = label.size_flags_horizontal
	r.size_flags_vertical = label.size_flags_vertical
	r.custom_minimum_size = label.custom_minimum_size
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	var fs := label.get_theme_font_size("font_size")
	r.add_theme_font_size_override("normal_font_size", fs)
	r.add_theme_color_override("default_color", label.get_theme_color("font_color"))
	label.get_parent().add_child(r)
	label.get_parent().move_child(r, label.get_index() + 1)
	label.visible = false
	label.set_meta("rich_twin", r)
	return r

## Pone el texto en el Label (oculto) y, con iconos, en su gemelo.
static func set_rich(label: Label, text: String) -> void:
	label.text = text
	rich_twin(label).text = richify(text)

## Icono de un accesorio o una montura (por su nombre); null si no lleva.
static func item_icon(e: Equipment, size: int = 16) -> TextureRect:
	var name := item_icon_name(e.equipment_name, e.slot)
	if name.is_empty():
		return null
	return SkillIcons.make(SkillIcons.texture(name), size, ITEM_COLOR, e.slot)

static func item_icon_name(item_name: String, slot: String) -> String:
	for pair: Array in ITEM_ICONS:
		if item_name.contains(pair[0]):
			return pair[1]
	return ITEM_ICON_FALLBACK.get(slot, "")

## Icono de un consumible (por su id).
static func consumable_texture(id: String) -> Texture2D:
	return SkillIcons.texture(CONSUMABLE_ICONS.get(id, "help"))

static func consumable_icon(id: String, size: int = 16) -> TextureRect:
	return SkillIcons.make(consumable_texture(id), size, CONSUMABLE_COLOR, ConsumableCatalog.item_name(id))

## «[img]» de un icono para RichTextLabel (con su color).
static func bb(key: String, size: int = 16) -> String:
	return "[img=%d color=#%s]%s[/img]" % [size, COLORS.get(key, ROLE_COLOR).to_html(false), SkillIcons.DIR % icon_name(key)]
