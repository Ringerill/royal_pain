class_name GearCatalog
extends RefCounted
# Rediseño v2, fase 4: el equipo nuevo, sacado de los assets.
#   assets/weapons/0X_*.png   6 tipos × 10 (rejilla 5×2): las 7 primeras, progresión; las 3 últimas,
#                             definitivas con enfoque (8.ª agilidad, 9.ª ataque, 10.ª defensa).
#   assets/armors/armor.png   cuero, malla y placas × 5 niveles (rejilla 5×3).
#   assets/accesories/        6 atributos × 5 niveles + 15 únicos (rejilla 5×9). Se llevan 2.
#   assets/items/items.png    18 objetos (rejilla 6×3): ver ConsumableCatalog.
# entries() devuelve las entradas en el formato de ContentCatalog.EQUIPMENT (name, slot, tier, price,
# desc, mods, fx) más "gear": {type, level, icon: [hoja, celda]} y "wclass"/"armor"/"dt" según el tipo.
# GameData las añade a su catálogo, así tiendas, botín y SkillEffects las ven igual que las antiguas.

const SLOT_ARMA := "Arma"
const SLOT_ARMADURA := "Armadura"
const SLOT_ESCUDO := "Escudo"
const SLOT_ACCESORIO := "Accesorio"
const UNIQUE_TIER := 4
const MAX_ACCESSORIES := 2

const WC := RpgStats.WeaponClass
const DT := RpgStats.DamageType
const AC := RpgStats.ArmorClass

const WEAPON_SHEETS := {
	"espada": "res://assets/weapons/01_espadas.png", "mandoble": "res://assets/weapons/02_grandes_espadas.png",
	"lanza": "res://assets/weapons/03_lanzas.png", "maza": "res://assets/weapons/04_mazas.png",
	"arco": "res://assets/weapons/05_arcos.png", "escudo": "res://assets/weapons/06_escudos.png",
}
const ARMOR_SHEET := "res://assets/armors/armor.png"
const ACCESSORY_SHEET := "res://assets/accesories/accesories.png"
const ITEM_SHEET := "res://assets/items/items.png"
const GRIDS := {"weapon": Vector2i(5, 2), "armor": Vector2i(5, 3), "accessory": Vector2i(5, 9), "item": Vector2i(6, 3)}

const WEAPON_TYPES := ["espada", "mandoble", "lanza", "maza", "arco"]
const WEAPON_TYPE_NAMES := {"espada": "Espada", "mandoble": "Mandoble", "lanza": "Lanza", "maza": "Maza", "arco": "Arco", "escudo": "Escudo"}
const CLASS_OF := {"espada": WC.ESPADA, "mandoble": WC.MANDOBLE, "lanza": WC.LANZA, "maza": WC.MAZA, "arco": WC.ARCO}
const DAMAGE_OF := {"espada": DT.TAJO, "mandoble": DT.TAJO, "lanza": DT.ESTOCADA, "maza": DT.CONTUNDENTE, "arco": DT.PROYECTIL}
const NAMES := {
	"espada": ["Espada Mellada", "Espada Recta", "Espada de Armas", "Alfanje", "Espada Bastarda", "Sable de Guarda",
		"Espada de Gavilanes", "Hoja Alada", "Colmillo de Bronce", "Espada del Rey"],
	"mandoble": ["Mandoble Oxidado", "Montante", "Espadón", "Mandoble de Guerra", "Mandoble de Lansquenete",
		"Flamígera", "Espadón de Gavilanes", "Mandoble Alado", "Mandoble de Bronce", "Mandoble Real"],
	"lanza": ["Lanza de Fresno", "Lanza de Infante", "Lanza de Hoja Ancha", "Lanza de Guardia", "Lanza de Caballero",
		"Partesana", "Lanza de Aletas", "Lanza Alada", "Lanza de Bronce", "Lanza Real"],
	"maza": ["Garrote Herrado", "Maza de Bola", "Maza de Aletas", "Maza de Pestañas", "Maza Pesada",
		"Maza Coronada", "Maza de Jaula", "Maza Alada", "Maza de Bronce", "Maza Real"],
	"arco": ["Arco de Caza", "Arco de Tejo", "Arco Recurvo", "Arco de Hueso", "Arco de Fresno",
		"Arco Compuesto", "Arco de Guerra", "Arco Alado", "Arco de Bronce", "Arco Real"],
	"escudo": ["Rodela de Tablas", "Rodela Claveteada", "Escudo de Aspa", "Escudo de Lágrima", "Escudo de Lazo",
		"Escudo de Placas", "Escudo Nervado", "Escudo Alado", "Escudo de Bronce", "Escudo Real"],
}
const PROGRESSION := 7
const FOCUS := ["agilidad", "ataque", "defensa"]          # las definitivas (8.ª, 9.ª, 10.ª)
const WEAPON_ATK := [1, 1, 2, 2, 3, 3, 4]
const WEAPON_PRICE := [25, 60, 120, 200, 320, 480, 700]
const DEFINITIVE_PRICE := 1600
const SHIELD_DEF := [1, 1, 2, 2, 3, 3, 4]
const SHIELD_BLOCK_PER_LEVEL := 0.01                   # + a RpgStats.SHIELD_BLOCK
# Detalles por tipo de arma (además del ataque): el mandoble pega más y pesa; la lanza da iniciativa;
# la maza, golpes críticos más duros; el arco, puntería (Estrategia).
const TYPE_EXTRA := {
	"espada": {}, "mandoble": {"fx": {"dmg": 0.06}, "mods": {"agility": -1}},
	"lanza": {"fx": {"initiative": 0.05}}, "maza": {"fx": {"crit_mult": 0.1}}, "arco": {"mods": {"strategy": 1}},
}
const DEFINITIVE := {
	"agilidad": {"mods": {"combat": 4, "agility": 3}, "fx": {"dodge": 0.05}, "d": "Ligera y veloz."},
	"ataque": {"mods": {"combat": 6}, "fx": {"crit": 0.05}, "d": "Hecha para matar."},
	"defensa": {"mods": {"combat": 4, "defense": 3}, "fx": {"dmg_taken": -0.05}, "d": "Protege a quien la empuña."},
}

const ARMOR_ROWS := [["cuero", AC.CUERO], ["malla", AC.MALLA], ["placas", AC.PLACAS]]
const ARMOR_NAMES := {
	"cuero": ["Jubón Raído", "Coraza de Cuero", "Cuero Tachonado", "Cuero Endurecido", "Escamas de Cuero"],
	"malla": ["Cota de Anillas", "Cota con Hombreras", "Brigantina Tachonada", "Cota y Peto", "Lorica Laminada"],
	"placas": ["Peto de Hierro", "Coraza de Placas", "Arnés de Batalla", "Arnés Estriado", "Arnés Dorado"],
}
const ARMOR_DEF := {"cuero": [1, 1, 2, 2, 3], "malla": [1, 2, 3, 3, 4], "placas": [2, 3, 4, 5, 6]}
const ARMOR_PRICE := {"cuero": [20, 50, 100, 170, 260], "malla": [60, 120, 200, 300, 430], "placas": [140, 240, 360, 520, 750]}

const ACCESSORY_ROWS := ["combat", "defense", "agility", "strategy", "charisma", "leadership"]
const ACCESSORY_NAMES := {
	"combat": ["Muñequera Anudada", "Muñequera Tachonada", "Brazal de Hierro", "Brazal de Correas", "Brazal de Acero"],
	"defense": ["Vendas Acolchadas", "Avambrazo de Cuero", "Avambrazo de Malla", "Avambrazo de Placa", "Avambrazo de Láminas"],
	"agility": ["Cinta de Cuero", "Cinta Trenzada", "Correa con Hebilla", "Correa de Plata", "Ceñidor de Plata"],
	"strategy": ["Cartera de Fieltro", "Rollo de Mapas", "Estuche de Cartas", "Brújula de Latón", "Brújula de Plata"],
	"charisma": ["Alfiler de Cobre", "Fíbula de Cobre", "Fíbula de Plata", "Broche Oval", "Fíbula Dorada"],
	"leadership": ["Bolsa de Cinto", "Zurrón de Mando", "Cartuchera de Oficial", "Morral de Capitán", "Morral de Señor"],
}
const ACCESSORY_PRICE := [40, 90, 160, 260, 400]
# Únicos (filas 7–9). fx: claves de SkillEffects/RpgStats (crit, dmg, dodge, dmg_taken, crit_mult,
# initiative) y del mundo (social, heal, income, event_luck, fame_gain, morale_start, xp_study).
const UNIQUES := [
	["Anillo de Hierro", {"defense": 2}, {"dmg_taken": -0.05}, "Un anillo sin adorno que nunca se rompe."],
	["Brazalete Torcido", {"combat": 2}, {"crit": 0.04}, "Hierro retorcido de un herrero del norte."],
	["Rosario de Cuentas", {"charisma": 1}, {"heal": 15}, "Rezar calma el cuerpo: curas más al descansar."],
	["Fíbula de Bronce", {"charisma": 3}, {"social": 0.1}, "Cierra la capa de quien sabe hablar."],
	["Cuerno de Bebida", {"leadership": 2}, {"morale_start": 5}, "Un brindis antes de la batalla."],
	["Gancho de Cinturón", {"agility": 2}, {"initiative": 0.1}, "Todo a mano: actúas antes."],
	["Silbato de Hueso", {"leadership": 1, "strategy": 1}, {"initiative": 0.05}, "Las órdenes llegan lejos."],
	["Estuche de Pergamino", {"strategy": 3}, {"xp_study": 0.2}, "Notas de un viejo maestro."],
	["Pañuelo de Lino", {"agility": 1}, {"dodge": 0.05}, "El recuerdo de alguien que te espera."],
	["Bolsa de Monedas", {"charisma": 1}, {"income": 0.15}, "Siempre suena a algo."],
	["Morral de Cuero", {"defense": 1}, {"heal": 10}, "Vendas y ungüentos de viaje."],
	["Pulsera de Cordel", {"agility": 1}, {"event_luck": 0.1}, "Trenzada por una adivina del camino."],
	["Calientamuñecas de Lana", {"combat": 1, "defense": 1}, {}, "El frío no entumece tus manos."],
	["Relicario de Hierro", {"defense": 2}, {"dmg_taken": -0.08}, "Guarda una reliquia que nadie ha visto."],
	["Medallón de Bronce", {"charisma": 2}, {"fame_gain": 0.2}, "Tu nombre corre más que tú."],
]
const UNIQUE_PRICE := 900

static var _entries: Array = []
static var _by_name := {}
static var _icons := {}

static func entries() -> Array:
	if not _entries.is_empty():
		return _entries
	for t: String in WEAPON_TYPES + ["escudo"]:
		for i in 10:
			_add(_weapon(t, i))
	for r in ARMOR_ROWS.size():
		var kind: String = ARMOR_ROWS[r][0]
		for i in 5:
			_add({"name": ARMOR_NAMES[kind][i], "slot": SLOT_ARMADURA, "tier": _tier_of(i + 1, 5), "price": ARMOR_PRICE[kind][i],
				"desc": "Armadura de %s, nivel %d." % [kind, i + 1], "mods": {"defense": ARMOR_DEF[kind][i]},
				"armor": ARMOR_ROWS[r][1], "gear": {"type": kind, "level": i + 1, "icon": ["armor", r * 5 + i]}})
	for r in ACCESSORY_ROWS.size():
		var stat: String = ACCESSORY_ROWS[r]
		for i in 5:
			_add({"name": ACCESSORY_NAMES[stat][i], "slot": SLOT_ACCESORIO, "tier": _tier_of(i + 1, 5), "price": ACCESSORY_PRICE[i],
				"desc": "%s +%d." % [GameData.STAT_LABELS.get(stat, stat), i + 1], "mods": {stat: i + 1},
				"gear": {"type": "accesorio", "level": i + 1, "icon": ["accessory", r * 5 + i]}})
	for u in UNIQUES.size():
		var spec: Array = UNIQUES[u]
		_add({"name": spec[0], "slot": SLOT_ACCESORIO, "tier": UNIQUE_TIER, "price": UNIQUE_PRICE, "desc": spec[3],
			"mods": spec[1], "fx": spec[2], "unique_gear": true,
			"gear": {"type": "unico", "level": 6, "icon": ["accessory", 30 + u]}})
	return _entries

static func _add(e: Dictionary) -> void:
	_entries.append(e)
	_by_name[e.name] = e

static func _tier_of(level: int, top: int) -> int:
	return clampi(1 + (level - 1) * 3 / top, 1, 3)

static func _weapon(t: String, i: int) -> Dictionary:
	var shield := t == "escudo"
	var e := {"name": NAMES[t][i], "slot": SLOT_ESCUDO if shield else SLOT_ARMA,
		"gear": {"type": t, "level": i + 1, "icon": ["weapon:" + t, i]}}
	var mods := {}
	var fx := {}
	if i < PROGRESSION:
		e.tier = _tier_of(i + 1, PROGRESSION)
		e.price = WEAPON_PRICE[i]
		if shield:
			mods["defense"] = SHIELD_DEF[i]
			e.desc = "Escudo de nivel %d: defensa y más probabilidad de bloquear." % (i + 1)
		else:
			mods["combat"] = WEAPON_ATK[i]
			e.desc = "%s de nivel %d." % [WEAPON_TYPE_NAMES[t], i + 1]
	else:
		var focus: String = FOCUS[i - PROGRESSION]
		var d: Dictionary = DEFINITIVE[focus]
		e.tier = UNIQUE_TIER
		e.price = DEFINITIVE_PRICE
		e.focus = focus
		if shield:
			mods = {"defense": 5}
			match focus:
				"agilidad": mods["agility"] = 2
				"ataque": mods["combat"] = 2
				"defensa": mods["defense"] = 7
		else:
			mods = (d.mods as Dictionary).duplicate()
			fx = (d.fx as Dictionary).duplicate()
		e.desc = "Definitiva (%s). %s" % [focus, d.d]
	if not shield:
		var extra: Dictionary = TYPE_EXTRA[t]
		for k in extra.get("mods", {}):
			mods[k] = int(mods.get(k, 0)) + int(extra.mods[k])
		for k in extra.get("fx", {}):
			fx[k] = float(fx.get(k, 0.0)) + float(extra.fx[k])
		e.wclass = CLASS_OF[t]
		e.dt = DAMAGE_OF[t]
	else:
		e.block = SHIELD_BLOCK_PER_LEVEL * (i + 1)
	e.mods = mods
	if not fx.is_empty():
		e.fx = fx
	return e

static func entry(name: String) -> Dictionary:
	entries()
	return _by_name.get(name, {})

static func is_gear(name: String) -> bool:
	return not entry(name).is_empty()

## Nombre del arma de un tipo y nivel (1..10).
static func weapon_name(t: String, level: int) -> String:
	return NAMES.get(t, NAMES.espada)[clampi(level, 1, 10) - 1]

static func armor_name(kind: String, level: int) -> String:
	return ARMOR_NAMES.get(kind, ARMOR_NAMES.cuero)[clampi(level, 1, 5) - 1]

## Icono (AtlasTexture) de una pieza del catálogo nuevo; null si no es de él.
static func icon(name: String) -> Texture2D:
	var e := entry(name)
	if e.is_empty():
		return null
	if _icons.has(name):
		return _icons[name]
	var spec: Array = e.gear.icon
	var kind: String = spec[0]
	var path := ARMOR_SHEET
	var grid: Vector2i = GRIDS.armor
	if kind.begins_with("weapon:"):
		path = WEAPON_SHEETS[kind.substr(7)]
		grid = GRIDS.weapon
	elif kind == "accessory":
		path = ACCESSORY_SHEET
		grid = GRIDS.accessory
	var tex := sheet_cell(path, grid, int(spec[1]))
	_icons[name] = tex
	return tex

static func sheet_cell(path: String, grid: Vector2i, index: int) -> AtlasTexture:
	var sheet: Texture2D = load(path)
	var cw := float(sheet.get_width()) / grid.x
	var ch := float(sheet.get_height()) / grid.y
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = Rect2((index % grid.x) * cw, (index / grid.x) * ch, cw, ch)
	return at

## Pone en la pieza lo que el combate necesita saber (clase de arma, tipo de daño, armadura, bloqueo).
static func tag(item: Equipment) -> void:
	var e := entry(item.equipment_name)
	if e.is_empty():
		return
	item.icon = icon(item.equipment_name)
	item.set_meta("gear_type", e.gear.type)
	item.set_meta("gear_level", int(e.gear.level))
	if e.has("wclass"):
		item.set_meta(RpgStats.META_WCLASS, int(e.wclass))
		item.set_meta(RpgStats.META_DAMAGE, int(e.dt))
	if e.has("armor"):
		item.set_meta(RpgStats.META_ARMOR, int(e.armor))
	if e.has("block"):
		item.set_meta("block", float(e.block))

## Arma básica (nivel 1) de un tipo: lo único que se elige al crear el personaje.
static func starter_weapon(t: String) -> String:
	return weapon_name(t, 1)

## Texto de ayuda: tipo, clase y lo que da.
static func describe(name: String) -> String:
	var e := entry(name)
	if e.is_empty():
		return name
	var lines := [name]
	if e.has("wclass"):
		var wc := int(e.wclass)
		lines.append("%s · gana a %s y %s" % [RpgStats.WCLASS_NAMES[wc], RpgStats.WCLASS_NAMES[(wc + 1) % 5], RpgStats.WCLASS_NAMES[(wc + 2) % 5]])
		if wc in [WC.MANDOBLE, WC.ARCO]:
			lines.append("A dos manos: sin escudo.")
	if e.has("block"):
		lines.append("Bloqueo +%d %%" % roundi(float(e.block) * 100))
	var parts := []
	for k in e.get("mods", {}):
		parts.append("%s %+d" % [GameData.STAT_LABELS.get(k, k), int(e.mods[k])])
	if not parts.is_empty():
		lines.append(", ".join(parts))
	lines.append(str(e.desc))
	return "\n".join(lines)
