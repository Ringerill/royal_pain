class_name ConsumableCatalog
extends RefCounted
# Consumibles del combate RPG (sin magia): vendas, ungüentos, aceite, redes… La bolsa del grupo vive en
# el jugador (Character.consumables: id -> cantidad). Usar uno gasta el turno de quien lo usa.
# Fuentes: tienda del castillo (pestaña Consumibles; el Mercado desbloquea más), botín y sucesos.

const MAX_STACK := 5
const HEAL_SMALL := 0.2          # Venda: fracción de los PV máximos
const HEAL_MEDIUM := 0.4         # Ungüento
const HEAL_HERBS := 0.1          # Hierbas
const PT_RESTORE := 0.5          # Pan y vino: fracción de los PT máximos
const ALE_MORALE := 20           # Cerveza fuerte
const ALE_WILL := 2.0            # Voluntad extra mientras dura
const ALE_HIT := 0.1             # puntería perdida (ebrio)
const ALE_TURNS := 3
const OIL_DMG := 0.12            # Aceite: fracción de los PV máximos del objetivo
const BURN_FRAC := 0.05          # quemadura por turno
const BURN_TURNS := 3
const SHARPEN_DMG := 0.2         # Piedra de afilar: +20 % de daño
const SHARPEN_TURNS := 3
const HOLY_MORALE := 15          # Agua bendita
const SMOKE_EVASION := 0.15      # Bomba de humo: evasión del grupo
const SMOKE_RETREAT := 0.25      # y más fácil retirarse
const SMOKE_TURNS := 2
const NET_CHANCE := 0.85         # Red de caza: probabilidad base de derribar
# IA enemiga: pocos objetos y uso ocasional.
const ENEMY_BAG_CHANCE := 0.4    # probabilidad de que el bando rival lleve objetos
const ENEMY_BAG_MAX := 2         # 1–2 objetos en total
const ENEMY_POOL := ["pocion1", "pocion2", "cuchillo", "cuchillo_veneno", "bomba"]
# Rediseño v2 (assets/items/items.png, rejilla 6×3): curación, PT y resurrección en 3 niveles,
# arrojadizas y remedios de los estados nuevos. Los antiguos quedan como «legacy» (bolsas guardadas).
const POTION_HEAL := [0.25, 0.45, 0.7]
const TONIC_PT := [0.3, 0.6, 1.0]
const REVIVE_HP := [0.2, 0.45, 0.8]
const BOMB_DMG := 0.12           # a todos los rivales (fracción de sus PV máximos)
const KNIFE_DMG := 0.12
const POISON_KNIFE_DMG := 0.06
const KUNAI_DMG := 0.16
const SHURIKEN_DMG := 0.08       # dos golpes al azar
const CURES := {"antidoto": "veneno", "remedio_paralisis": "paralisis", "remedio_miedo": "miedo", "remedio_agotamiento": "agotamiento"}
const AI_ITEM_CHANCE := 0.35
const AI_HEAL_HP := 0.4
const LOOT_CHANCE := 0.5         # tras ganar: probabilidad de encontrar objetos
const LOOT_MAX := 2

# tgt: ally (1 aliado activo), enemy (1 rival), allies (todo el grupo). market: nivel de Mercado necesario.
const ITEMS := {
	"venda": {"name": "Venda", "price": 15, "tgt": "ally", "market": 0, "desc": "Cura un poco (%d%% PV)." % roundi(HEAL_SMALL * 100)},
	"unguento": {"name": "Ungüento", "price": 35, "tgt": "ally", "market": 1, "desc": "Cura (%d%% PV) y corta el Sangrado." % roundi(HEAL_MEDIUM * 100)},
	"pan_vino": {"name": "Pan y vino", "price": 20, "tgt": "ally", "market": 0, "desc": "Recupera la mitad de los PT."},
	"cerveza": {"name": "Cerveza fuerte", "price": 12, "tgt": "ally", "market": 0, "desc": "Moral y Voluntad, pero menos puntería."},
	"aceite": {"name": "Aceite de lámpara", "price": 30, "tgt": "enemy", "market": 1, "desc": "Lo arrojas: daño y Ardiendo."},
	"piedra": {"name": "Piedra de afilar", "price": 25, "tgt": "ally", "market": 0, "desc": "+%d%% de daño unos turnos." % roundi(SHARPEN_DMG * 100)},
	"agua_bendita": {"name": "Agua bendita", "price": 40, "tgt": "ally", "market": 2, "desc": "Quita Aturdido y Provocado; da moral."},
	"humo": {"name": "Bomba de humo", "price": 45, "tgt": "allies", "market": 2, "desc": "El grupo esquiva más y huye mejor."},
	"red": {"name": "Red de caza", "price": 30, "tgt": "enemy", "market": 1, "desc": "Puede paralizar al objetivo."},
	"tomo_olvido": {"name": "Tomo del olvido", "price": 260, "tgt": "none", "market": 3, "rare": true,
		"desc": "Fuera de combate (en Habilidades): olvidas lo aprendido en tus árboles, recuperas los puntos y eliges vía de nuevo."},
	"hierbas": {"name": "Hierbas", "price": 18, "tgt": "ally", "market": 0, "desc": "Purgan Debilitado, Cegado y Ardiendo; curan algo."},
	# --- v2 ---
	"pocion1": {"name": "Poción menor", "price": 20, "tgt": "ally", "market": 0, "icon": 0, "v2": true, "desc": "Cura un 25 % de la vida."},
	"pocion2": {"name": "Poción", "price": 45, "tgt": "ally", "market": 1, "icon": 1, "v2": true, "desc": "Cura un 45 % de la vida."},
	"pocion3": {"name": "Poción mayor", "price": 90, "tgt": "ally", "market": 2, "icon": 2, "v2": true, "desc": "Cura un 70 % de la vida."},
	"tonico1": {"name": "Tónico menor", "price": 20, "tgt": "ally", "market": 0, "icon": 3, "v2": true, "desc": "Recupera un 30 % de los PT."},
	"tonico2": {"name": "Tónico", "price": 45, "tgt": "ally", "market": 1, "icon": 4, "v2": true, "desc": "Recupera un 60 % de los PT."},
	"tonico3": {"name": "Tónico mayor", "price": 90, "tgt": "ally", "market": 2, "icon": 5, "v2": true, "desc": "Recupera todos los PT."},
	"despertar1": {"name": "Sales de despertar", "price": 60, "tgt": "ko_ally", "market": 1, "icon": 6, "v2": true, "desc": "Levanta a un aliado caído con un 20 % de vida."},
	"despertar2": {"name": "Tintura de vida", "price": 120, "tgt": "ko_ally", "market": 2, "icon": 7, "v2": true, "desc": "Levanta a un aliado caído con un 45 % de vida."},
	"despertar3": {"name": "Elixir de vida", "price": 240, "tgt": "ko_ally", "market": 3, "icon": 8, "v2": true, "desc": "Levanta a un aliado caído con un 80 % de vida."},
	"bomba": {"name": "Bomba", "price": 50, "tgt": "enemies", "market": 2, "icon": 9, "v2": true, "desc": "Daña a todos los rivales."},
	"cuchillo": {"name": "Cuchillo arrojadizo", "price": 15, "tgt": "enemy", "market": 0, "icon": 10, "v2": true, "desc": "Daño a un rival."},
	"cuchillo_veneno": {"name": "Cuchillo envenenado", "price": 30, "tgt": "enemy", "market": 1, "icon": 11, "v2": true, "desc": "Algo de daño y veneno."},
	"kunai": {"name": "Kunai", "price": 35, "tgt": "enemy", "market": 1, "icon": 12, "v2": true, "desc": "Daño alto a un rival."},
	"shuriken": {"name": "Shuriken", "price": 30, "tgt": "enemies", "market": 1, "icon": 13, "v2": true, "desc": "Dos golpes a rivales al azar."},
	"antidoto": {"name": "Antídoto", "price": 15, "tgt": "ally", "market": 0, "icon": 14, "v2": true, "desc": "Quita el veneno."},
	"remedio_paralisis": {"name": "Remedio de parálisis", "price": 20, "tgt": "ally", "market": 0, "icon": 15, "v2": true, "desc": "Quita la parálisis."},
	"remedio_miedo": {"name": "Remedio de miedo", "price": 20, "tgt": "ally", "market": 0, "icon": 16, "v2": true, "desc": "Quita el miedo."},
	"remedio_agotamiento": {"name": "Remedio de agotamiento", "price": 25, "tgt": "ally", "market": 1, "icon": 17, "v2": true, "desc": "Quita el agotamiento."},
}

## Icono del objeto (v2: su dibujo en items.png); null para los antiguos.
static func icon_texture(id: String) -> Texture2D:
	if not item(id).has("icon"):
		return null
	return GearCatalog.sheet_cell(GearCatalog.ITEM_SHEET, GearCatalog.GRIDS.item, int(item(id).icon))

static func item(id: String) -> Dictionary:
	return ITEMS.get(id, {})

static func item_name(id: String) -> String:
	return str(ITEMS.get(id, {}).get("name", id))

static func count(bag: Dictionary, id: String) -> int:
	return int(bag.get(id, 0))

## Añade n unidades (hasta MAX_STACK). Devuelve cuántas cupieron.
static func add(bag: Dictionary, id: String, n: int = 1) -> int:
	if not ITEMS.has(id):
		return 0
	var room := maxi(0, MAX_STACK - count(bag, id))
	var added := mini(room, n)
	if added > 0:
		bag[id] = count(bag, id) + added
	return added

static func take(bag: Dictionary, id: String) -> bool:
	if count(bag, id) <= 0:
		return false
	bag[id] = count(bag, id) - 1
	if int(bag[id]) <= 0:
		bag.erase(id)
	return true

## Objetos que vende la tienda según el nivel del Mercado del castillo.
const TOME_LOOT_CHANCE := 0.04   # tras ganar, rara vez aparece un Tomo del olvido

## Objetos que se usan en combate (el Tomo del olvido no).
static func combat_item(id: String) -> bool:
	return str(item(id).get("tgt", "")) != "none"

## Objetos comunes (para botín y sucesos): sin los raros.
static func common_ids() -> Array:
	return ITEMS.keys().filter(func(id: String) -> bool: return ITEMS[id].get("v2", false) and int(ITEMS[id].market) <= 1)

static func shop_items(market_level: int) -> Array:
	return ITEMS.keys().filter(func(id: String) -> bool: return (ITEMS[id].get("v2", false) or id == "tomo_olvido") and int(ITEMS[id].market) <= market_level)

static func summary(bag: Dictionary) -> String:
	var parts := []
	for id in bag:
		parts.append("%s ×%d" % [item_name(id), int(bag[id])])
	return ", ".join(parts)

## Bolsa al azar para el bando rival (vacía la mayoría de las veces).
static func enemy_bag() -> Dictionary:
	var bag := {}
	if randf() < ENEMY_BAG_CHANCE:
		for i in randi_range(1, ENEMY_BAG_MAX):
			add(bag, ENEMY_POOL.pick_random())
	return bag

## Botín tras ganar: añade a la bolsa y deja la lista en result.loot.
static func grant_loot(bag: Dictionary, result: Dictionary) -> void:
	if randf() >= LOOT_CHANCE:
		return
	var loot: Array = result.get("loot", [])
	if randf() < TOME_LOOT_CHANCE and add(bag, "tomo_olvido") > 0:
		loot.append("tomo_olvido")
	for i in randi_range(1, LOOT_MAX):
		var id: String = common_ids().pick_random()
		if add(bag, id) > 0:
			loot.append(id)
	result["loot"] = loot

## Suceso: entrega n objetos al azar. Devuelve el texto.
static func grant_random(bag: Dictionary, n: int) -> String:
	var got := []
	for i in n:
		var id: String = common_ids().pick_random()
		if add(bag, id) > 0:
			got.append(item_name(id))
	return ("Consigues: " + ", ".join(got)) if not got.is_empty() else ""

# --- En combate ---

static func targets(mgr: RpgBattleManager, f, id: String) -> Array:
	match str(item(id).get("tgt", "ally")):
		"enemy":
			return mgr.active_of(1 - f.side)
		"allies":
			return [f]
		"enemies":
			return [f]
		"ko_ally":
			return mgr.side_fighters(f.side).filter(func(o) -> bool: return o.down and not o.dead)
	return mgr.active_of(f.side)

## Aplica el objeto action.item sobre action.target. false si no se pudo (no gasta el turno).
static func use(mgr: RpgBattleManager, f, action: Dictionary) -> bool:
	var id := str(action.get("item", ""))
	var bag: Dictionary = mgr.bags[f.side]
	if not ITEMS.has(id) or count(bag, id) <= 0:
		return false
	var t = action.get("target", null)
	var tg := targets(mgr, f, id)
	if t == null or not t in tg:
		t = f if f in tg else (tg[0] if not tg.is_empty() else null)
	if t == null:
		return false
	take(bag, id)
	mgr._log("%s usa %s%s." % [f.name(), item_name(id), (" con %s" % t.name()) if t != f and item(id).tgt != "allies" else ""])
	match id:
		"pocion1", "pocion2", "pocion3":
			var i := int(id.right(1)) - 1
			t.hp = mini(t.max_hp, t.hp + maxi(1, roundi(t.max_hp * POTION_HEAL[i])))
		"tonico1", "tonico2", "tonico3":
			var i := int(id.right(1)) - 1
			t.pt = mini(t.max_pt, t.pt + maxi(1, roundi(t.max_pt * TONIC_PT[i])))
		"despertar1", "despertar2", "despertar3":
			var i := int(id.right(1)) - 1
			t.down = false
			t.hp = maxi(1, roundi(t.max_hp * REVIVE_HP[i]))
			t.active = mgr.active_of(f.side).size() < mgr.max_active
			t.next_time = mgr.now + t.interval()
			mgr._log("  ¡%s se levanta!" % t.name())
		"bomba":
			for o in mgr.active_of(1 - f.side):
				_throw(mgr, f, o, BOMB_DMG)
		"cuchillo":
			_throw(mgr, f, t, KNIFE_DMG)
		"kunai":
			_throw(mgr, f, t, KUNAI_DMG)
		"cuchillo_veneno":
			_throw(mgr, f, t, POISON_KNIFE_DMG)
			if t.up():
				mgr._add_status(t, "veneno", 3, f)
				mgr._log("  %s: Veneno." % t.name())
		"shuriken":
			for k in 2:
				var foes: Array = mgr.active_of(1 - f.side)
				if not foes.is_empty():
					_throw(mgr, f, foes.pick_random(), SHURIKEN_DMG)
		"antidoto", "remedio_paralisis", "remedio_miedo", "remedio_agotamiento":
			t.statuses.erase(CURES[id])
		"venda", "unguento", "hierbas":
			var frac: float = {"venda": HEAL_SMALL, "unguento": HEAL_MEDIUM, "hierbas": HEAL_HERBS}[id]
			t.hp = mini(t.max_hp, t.hp + maxi(1, roundi(t.max_hp * frac)))
			if id == "unguento":
				t.statuses.erase("sangrado")
				t.statuses.erase("veneno")
			if id == "hierbas":
				for st in ["debilitado", "cegado", "ardiendo", "veneno", "miedo", "agotamiento"]:
					t.statuses.erase(st)
		"pan_vino":
			t.pt = mini(t.max_pt, t.pt + maxi(1, roundi(t.max_pt * PT_RESTORE)))
		"cerveza":
			t.morale = mini(100, t.morale + ALE_MORALE)
			if not t.has("ebrio"):
				t.s.voluntad = float(t.s.voluntad) + ALE_WILL
			mgr._add_status(t, "ebrio", ALE_TURNS, null)
		"aceite":
			var dmg := maxi(1, roundi(t.max_hp * OIL_DMG))
			mgr._log("  %s arde (−%d)." % [t.name(), dmg])
			mgr._damage(t, dmg, f)
			if t.up():
				mgr._add_status(t, "ardiendo", BURN_TURNS, null)
		"piedra":
			mgr._add_status(t, "afilado", SHARPEN_TURNS, null)
		"agua_bendita":
			t.statuses.erase("aturdido")
			t.statuses.erase("provocado")
			t.statuses.erase("paralisis")
			t.statuses.erase("miedo")
			t.morale = mini(100, t.morale + HOLY_MORALE)
		"humo":
			for o in mgr.active_of(f.side):
				mgr._add_status(o, "humo", SMOKE_TURNS, null)
		"red":
			if mgr._try_status(f, t, "paralisis", NET_CHANCE, 1):
				mgr._log("  %s queda enredado." % t.name())
			else:
				mgr._log("  %s esquiva la red." % t.name())
	return true

static func _throw(mgr: RpgBattleManager, f, t, frac: float) -> void:
	if t == null or not t.up():
		return
	var dmg := maxi(1, roundi(t.max_hp * frac))
	mgr._log("  %s recibe %d." % [t.name(), dmg])
	mgr._damage(t, dmg, f)

## IA: a veces usa un objeto de su bolsa ({} si no).
static func ai_pick(mgr: RpgBattleManager, f) -> Dictionary:
	var bag: Dictionary = mgr.bags[f.side]
	if bag.is_empty() or mgr.rng.randf() >= AI_ITEM_CHANCE:
		return {}
	if f.hp_ratio() < AI_HEAL_HP:
		for id in ["pocion3", "pocion2", "pocion1", "unguento", "venda", "hierbas"]:
			if count(bag, id) > 0:
				return {"type": "objeto", "item": id, "target": f}
	var foes := mgr.active_of(1 - f.side)
	if foes.is_empty():
		return {}
	var strongest = foes[0]
	for o in foes:
		if o.hp > strongest.hp:
			strongest = o
	for id in ["red", "aceite"]:
		if count(bag, id) > 0 and not strongest.has("derribado"):
			return {"type": "objeto", "item": id, "target": strongest}
	for id in ["bomba", "kunai", "cuchillo_veneno", "cuchillo", "shuriken"]:
		if count(bag, id) > 0:
			return {"type": "objeto", "item": id, "target": strongest}
	return {}
