class_name SkillIcons
extends RefCounted
# Iconos de habilidades, tipos de daño y armaduras (game-icons.net, CC BY 3.0: ver
# assets/icons/game-icons/CREDITOS.txt). Los SVG son blancos: se tiñen con modulate.
# Las habilidades NO tienen icono propio: llevan el de su categoría (category_of).
#   - Daño: el icono del tipo de daño con que golpea quien la usa (el de su arma, o el fijo de la
#     técnica: proyectiles y golpes de escudo). Sin personaje conocido, un icono genérico de daño.
#   - Curación, Mejora, Protección, Debilitación, Mando y moral, Pasiva: un icono por categoría.
#   SkillIcons.node_icon(id, 24, personaje)    → TextureRect
#   SkillIcons.set_node_button_icon(b, id, personaje)
#   SkillIcons.affinity_badge(dt, afinidad, 22) → tipo de daño con marco según Débil/Normal/Resiste/desconocido

const DIR := "res://assets/icons/game-icons/%s.svg"
const DAMAGE := ["broadsword", "barbed-spear", "spiked-mace", "high-shot"]   # Tajo, Estocada, Contundente, Proyectil
const ARMOR := ["shirt", "leather-vest", "chain-mail", "breastplate"]
const SHIELD := "round-shield"
const UNKNOWN := "help"
const DAMAGE_GENERIC := "crossed-swords"   # daño sin saber el arma (glosario, PNJ sin datos)

enum Cat { DANO, CURACION, MEJORA, PROTECCION, DEBILITACION, MANDO, PASIVA }
const CAT_NAMES := ["Daño", "Curación", "Mejora", "Protección", "Debilitación", "Mando y moral", "Pasiva"]
const CAT_ICONS := ["crossed-swords", "heart-plus", "muscle-up", "checked-shield", "knockout", "flying-flag", "beveled-star"]
const CAT_COLORS := [Color("e8826e"), Color("8fd08a"), Color("f0b45a"), Color("9fc4e0"), Color("c48ae0"), Color("f0d48a"), Color("b8ac98")]

const DAMAGE_COLORS := [Color("e8826e"), Color("e6e0c8"), Color("d9a45a"), Color("9fd08a")]
const ARMOR_COLOR := Color("c8c0b0")
const UNKNOWN_COLOR := Color("8a7f70")
const WEAK_COLOR := Color("ffd25a")
const RESIST_COLOR := Color("6f8fb0")
const NORMAL_COLOR := Color("5a4a34")

const PROTECT_STATUSES := ["guardia", "fortaleza", "cubierto", "guardia_esgrima", "oculto", "provocado"]
const ALLY_TARGETS := ["ally", "allies", "self", "ko_ally"]

static var _cache := {}

static func texture(icon_name: String) -> Texture2D:
	if _cache.has(icon_name):
		return _cache[icon_name]
	var path := DIR % icon_name
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[icon_name] = tex
	return tex

## Categoría de un nodo del árbol (Cat). Reglas en orden: pasiva, daño, curación, protección,
## mando y moral, debilitación (contra rivales sin daño) y, si no, mejora.
static func category_of(id: String) -> int:
	var n := SkillTreeCatalog.node(id)
	if n.is_empty() or n.get("kind", "") != "act":
		return Cat.PASIVA
	if float(n.get("pow", 0.0)) > 0.0:
		return Cat.DANO
	var fx: Dictionary = n.get("fx", {})
	var tgt: String = n.get("tgt", "enemy")
	if n.has("heal") or fx.has("revive") or fx.has("cleanse"):
		return Cat.CURACION
	var statuses: Array = n.get("st", []).map(func(s): return str(s[0]))
	statuses.append_array(fx.get("self_st", []).map(func(s): return str(s[0])))
	if fx.has("cover") or statuses.any(func(s): return s in PROTECT_STATUSES):
		return Cat.PROTECCION
	if (tgt in ALLY_TARGETS and float(fx.get("morale", 0)) > 0) or "inspirado" in statuses:
		return Cat.MANDO
	if not tgt in ALLY_TARGETS:
		return Cat.DEBILITACION
	return Cat.MEJORA

## Tipo de daño con que golpea la técnica en manos de c (-1 si no hace daño o no se sabe el arma).
static func damage_type_of(id: String, c: Character = null) -> int:
	var n := SkillTreeCatalog.node(id)
	if float(n.get("pow", 0.0)) <= 0.0:
		return -1
	var dt := int(n.get("dt", -1))
	if dt >= 0:
		return dt
	return RpgStats.weapon_type(c) if c != null else -1

static func node_icon_name(id: String, c: Character = null) -> String:
	var cat := category_of(id)
	if cat == Cat.DANO:
		var dt := damage_type_of(id, c)
		return DAMAGE[dt] if dt >= 0 else DAMAGE_GENERIC
	return CAT_ICONS[cat]

static func node_color(id: String, c: Character = null) -> Color:
	var cat := category_of(id)
	if cat == Cat.DANO:
		var dt := damage_type_of(id, c)
		return DAMAGE_COLORS[dt] if dt >= 0 else CAT_COLORS[Cat.DANO]
	return CAT_COLORS[cat]

## Texto corto para ayudas: «Daño · Tajo», «Curación»…
static func node_label(id: String, c: Character = null) -> String:
	var cat := category_of(id)
	var dt := damage_type_of(id, c)
	return CAT_NAMES[cat] + (" · " + RpgStats.DAMAGE_NAMES[dt] if cat == Cat.DANO and dt >= 0 else "")

static func node_icon(id: String, size: int, c: Character = null, color: Variant = null) -> TextureRect:
	var r := make(texture(node_icon_name(id, c)), size, node_color(id, c) if color == null else color)
	r.tooltip_text = node_label(id, c)
	return r

static func damage_icon(dt: int, size: int) -> TextureRect:
	if dt < 0 or dt >= DAMAGE.size():
		return make(texture(UNKNOWN), size, UNKNOWN_COLOR, "Tipo de daño desconocido")
	return make(texture(DAMAGE[dt]), size, DAMAGE_COLORS[dt], RpgStats.DAMAGE_NAMES[dt])

static func armor_icon(armor: int, size: int) -> TextureRect:
	if armor < 0 or armor >= ARMOR.size():
		return make(texture(UNKNOWN), size, UNKNOWN_COLOR, "Armadura desconocida")
	return make(texture(ARMOR[armor]), size, ARMOR_COLOR, RpgStats.ARMOR_NAMES[armor])

## Tipo de daño dentro de un marco que dice cómo lo encaja el objetivo (afinidad -1 = no se sabe).
static func affinity_badge(dt: int, aff: int, size: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.set_corner_radius_all(3)
	st.set_border_width_all(2)
	st.set_content_margin_all(1)
	var label := "?"
	match aff:
		RpgStats.Affinity.DEBIL:
			st.bg_color = Color(WEAK_COLOR, 0.25)
			st.border_color = WEAK_COLOR
			label = "Débil (×%s)" % str(RpgStats.WEAK_MULT).replace(".", ",")
		RpgStats.Affinity.RESISTE:
			st.bg_color = Color(RESIST_COLOR, 0.25)
			st.border_color = RESIST_COLOR
			label = "Resiste (×%s)" % str(RpgStats.RESIST_MULT).replace(".", ",")
		RpgStats.Affinity.NORMAL:
			st.bg_color = Color(0, 0, 0, 0.45)
			st.border_color = NORMAL_COLOR
			label = "Normal"
		_:
			st.bg_color = Color(0, 0, 0, 0.3)
			st.border_color = Color(NORMAL_COLOR, 0.5)
			label = "sin descubrir"
	panel.add_theme_stylebox_override("panel", st)
	var icon := make(texture(DAMAGE[dt]), size - 6, DAMAGE_COLORS[dt] if aff >= 0 else Color(UNKNOWN_COLOR, 0.6))
	panel.add_child(icon)
	panel.tooltip_text = "%s: %s" % [RpgStats.DAMAGE_NAMES[dt], label]
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	return panel

## Pone un icono teñido a un botón (a la izquierda del texto).
static func set_button_icon(b: Button, tex: Texture2D, color: Color, size: int = 22) -> void:
	if tex == null:
		return
	b.icon = tex
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", size)
	for k in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(k, color)
	b.add_theme_color_override("icon_disabled_color", Color(color, 0.35))

static func set_node_button_icon(b: Button, id: String, c: Character = null, size: int = 22) -> void:
	set_button_icon(b, texture(node_icon_name(id, c)), node_color(id, c), size)

static func make(tex: Texture2D, size: int, color: Color = Color.WHITE, tip: String = "") -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.modulate = color
	r.tooltip_text = tip
	r.mouse_filter = Control.MOUSE_FILTER_PASS if not tip.is_empty() else Control.MOUSE_FILTER_IGNORE
	return r
