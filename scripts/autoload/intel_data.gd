extends Node
# Autoload "IntelData": lo que el jugador sabe de cada enemigo del combate RPG (un bestiario).
# Se aprende combatiendo (RpgBattleManager avisa por su intel_hook):
#   - "weapon": un enemigo te golpea con su arma → conoces su tipo de daño;
#   - "aff":    le golpeas con un tipo de daño → sabes cómo lo encaja (Débil / Normal / Resiste);
#   - "all":    técnicas de estrategia (estado «analizado») → armadura, escudo, todas sus debilidades y su arma.
# Clave: los enemigos genéricos se recuerdan por tipo y equipo ("e:bandido:Hacha de Guerra:1"); los personajes con nombre, uno a uno
# ("c:<nombre completo>", los nombres del mundo no se repiten).
# Solo se muestra lo que sigue siendo cierto: si un personaje cambia de arma o armadura, lo que ya no
# coincide se olvida al consultarlo (view).
# Depende solo de GameManager (señal game_started) y de RpgStats (clase pura).

signal intel_changed(key: String)

const UNKNOWN := -1

var known := {}   # clave -> {"w": tipo de daño, "armor": clase, "shield": bool, "aff": {"<tipo>": afinidad}}

func _ready() -> void:
	GameManager.game_started.connect(func(_character: Character): reset())

func reset() -> void:
	known.clear()

static func key_of(c: Character) -> String:
	if c == null:
		return ""
	if c.has_meta("enemy_type"):   # genéricos: tipo + el equipo que les tocó (EnemyCatalog.GEAR)
		return "e:%s:%s:%d" % [c.get_meta("enemy_type"), c.get_meta(EnemyCatalog.META_WEAPON, ""), int(c.get_meta(RpgStats.META_ARMOR, -1))]
	return "c:" + c.full_name()

## Gancho para RpgBattleManager.intel_hook. s = estadísticas del combatiente (RpgStats.compute).
func record(kind: String, c: Character, s: Dictionary, dt: int = UNKNOWN, aff: int = UNKNOWN) -> void:
	var key := key_of(c)
	if key.is_empty():
		return
	var e: Dictionary = known.get(key, {})
	var before := e.duplicate(true)
	match kind:
		"weapon":
			e["w"] = dt
		"aff":
			var a: Dictionary = e.get("aff", {})
			a[str(dt)] = aff
			e["aff"] = a
		"all":
			e["w"] = int(s.get("weapon", 0))
			e["armor"] = int(s.get("armor", 0))
			e["shield"] = bool(s.get("shield", false))
			e.erase("aff")   # con la armadura conocida, las afinidades salen de la tabla
	known[key] = e
	if e != before:
		intel_changed.emit(key)

## Lo que se sabe hoy de c (validado contra sus valores reales):
## {"weapon": tipo o -1, "armor": clase o -1, "shield": bool o null, "aff": [afinidad o -1 por tipo de daño]}
func view(c: Character, s: Dictionary) -> Dictionary:
	var out := {"weapon": UNKNOWN, "armor": UNKNOWN, "shield": null, "aff": [UNKNOWN, UNKNOWN, UNKNOWN, UNKNOWN]}
	var key := key_of(c)
	if not known.has(key):
		return out
	var e: Dictionary = known[key]
	var weapon := int(s.get("weapon", 0))
	var armor := int(s.get("armor", 0))
	var shield := bool(s.get("shield", false))
	if e.has("w"):
		if int(e.w) == weapon:
			out.weapon = weapon
		else:
			e.erase("w")
	if e.has("armor"):
		if int(e.armor) == armor and bool(e.get("shield", false)) == shield:
			out.armor = armor
			out.shield = shield
			for dt in 4:
				out.aff[dt] = RpgStats.affinity(dt, armor, shield)
		else:
			e.erase("armor")
			e.erase("shield")
	if out.armor == UNKNOWN and e.has("aff"):
		var a: Dictionary = e.aff
		for k in a.keys():
			var dt := int(k)
			if int(a[k]) == RpgStats.affinity(dt, armor, shield):
				out.aff[dt] = int(a[k])
			else:
				a.erase(k)
	return out

func knows_anything(c: Character) -> bool:
	return known.has(key_of(c))

func save_state() -> Dictionary:
	return {"known": known.duplicate(true)}

func load_state(data: Dictionary) -> void:
	known.clear()
	var k: Dictionary = data.get("known", {})
	for key in k.keys():
		var src: Dictionary = k[key]
		var e := {}
		if src.has("w"):
			e["w"] = int(src.w)
		if src.has("armor"):
			e["armor"] = int(src.armor)
			e["shield"] = bool(src.get("shield", false))
		if src.has("aff"):
			var a := {}
			for dt in (src.aff as Dictionary).keys():
				a[str(dt)] = int(src.aff[dt])
			e["aff"] = a
		known[str(key)] = e
