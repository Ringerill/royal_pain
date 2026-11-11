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
	"casados": "linked-rings", "neutral": "person",
	"rol_campesino": "farmer", "rol_soldado": "swordman", "rol_caballero": "visored-helm",
	"rol_capitan": "captain-hat-profile", "rol_nobleza_baja": "tiara", "rol_nobleza_alta": "crown",
	"rol_duque": "crown", "rol_regente": "imperial-crown", "rol_inafiliado": "bindle",
}
const NAMES := {
	"oro": "Oro", "soldados": "Soldados", "honor": "Honor", "fama": "Fama", "comida": "Comida",
	"vida": "Vida", "nivel": "Nivel", "acciones": "Acciones", "combate": "Combate", "defensa": "Defensa",
	"agilidad": "Agilidad", "estrategia": "Estrategia", "liderazgo": "Liderazgo", "carisma": "Carisma",
	"odio": "Odio", "rivalidad": "Rivalidad", "amistad": "Amistad", "amor": "Amor", "casados": "Matrimonio",
	"neutral": "Sin lazos",
}
const COLORS := {
	"oro": Color("f0c75a"), "soldados": Color("c8c0b0"), "honor": Color("e8d9a0"), "fama": Color("e0a85a"),
	"comida": Color("d8b870"), "vida": Color("e0645a"), "nivel": Color("9fd08a"), "acciones": Color("9fc4e0"),
	"combate": Color("e8826e"), "defensa": Color("9fc4e0"), "agilidad": Color("9fd08a"),
	"estrategia": Color("c48ae0"), "liderazgo": Color("f0d48a"), "carisma": Color("f0b4c8"),
	"odio": Color("d0453a"), "rivalidad": Color("e8906a"), "amistad": Color("8fd08a"), "amor": Color("f07a9a"),
	"casados": Color("f0c75a"), "neutral": Color("a89a88"),
}
const ROLE_COLOR := Color("e8d9a0")
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

## «[img]» de un icono para RichTextLabel (con su color).
static func bb(key: String, size: int = 16) -> String:
	return "[img=%d color=#%s]%s[/img]" % [size, COLORS.get(key, ROLE_COLOR).to_html(false), SkillIcons.DIR % icon_name(key)]
