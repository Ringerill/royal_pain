extends Node
# Autoload "WorldGrowth": los personajes del mundo también suben de nivel.
#   - Al crear el mundo: nivel inicial según rango, edad y poder de su reino, con algo de azar
#     (un señor veterano de un reino fuerte no empieza en nivel 1).
#   - Cada mes: experiencia según rango × poder del reino × azar.
#   - Tu séquito gana experiencia contigo: una parte de toda la que ganas tú (Character.xp_hook).
#   - Al subir de nivel, los PNJ reparten solos sus puntos de atributo (los de árbol se gastan al combatir).
# Partidas anteriores: la primera vez que se cargan, el mundo se pone al día con los meses ya jugados.
# Depende de GameManager, RelationsData y MapData (no al revés).

const MONTHLY_XP := 25                 # base mensual (×rango, ×poder del reino, ×azar)
const RANK_XP := [0.6, 0.8, 1.0, 1.1, 1.2, 1.3, 1.4]   # por rango: campesino .. regente
const RANDOM_XP := [0.5, 1.5]
const START_LEVEL_BY_RANK := [1, 1, 2, 3, 4, 5, 6]   # el jugador empieza en 1: la corte, poco por encima
const AGE_LEVEL_STEP := 15             # +1 nivel inicial por cada 15 años por encima de 20
const POWER_LEVEL_BONUS := 2.0         # nivel inicial extra de un reino con el doble de castillos que la media
const RETINUE_XP_SHARE := 0.5          # tu séquito gana la mitad de lo que ganas tú
const ATTRS := ["combat", "defense", "strategy", "leadership", "charisma", "agility"]
const META_SEEN := "wg_seen"           # ya recibió su nivel inicial (solo sube; tras cargar se comprueba otra vez sin efecto)

var initialized := false

func _ready() -> void:
	GameManager.game_started.connect(func(_c: Character): _on_new_world.call_deferred())
	GameManager.turn_advanced.connect(_on_month_passed)
	Character.xp_hook = _on_xp_gained

func _on_new_world() -> void:
	initialized = false
	initialize_world()

## Niveles iniciales de todos los personajes del mundo (una sola vez por partida).
func initialize_world() -> void:
	if initialized:
		return
	initialized = true
	for r: Relationship in RelationsData.relations:
		if r.character != null and not r.person_name in RelationsData.retinue:
			_ensure_start_level(r)

func start_level(c: Character, kingdom: int) -> int:
	var rank := clampi(c.rank(), 0, START_LEVEL_BY_RANK.size() - 1)
	var lv := float(START_LEVEL_BY_RANK[rank]) + maxf(0.0, (c.age - 20) / float(AGE_LEVEL_STEP))
	lv += (kingdom_power(kingdom) - 1.0) * POWER_LEVEL_BONUS + randi_range(-1, 1)
	return clampi(roundi(lv), 1, Character.MAX_LEVEL)

## Poder de un reino: sus castillos frente a la media de los reinos en pie (1 = media).
func kingdom_power(kingdom: int) -> float:
	if kingdom < 0:
		return 1.0
	var counts := {}
	for c: Castle in MapData.castles:
		if c.kingdom != KingdomEnums.Kingdom.NEUTRAL:
			counts[c.kingdom] = int(counts.get(c.kingdom, 0)) + 1
	if counts.is_empty():
		return 1.0
	var avg := 0.0
	for k in counts:
		avg += counts[k]
	avg /= counts.size()
	return clampf(float(counts.get(kingdom, 0)) / maxf(1.0, avg), 0.3, 2.5)

func monthly_xp(c: Character, kingdom: int) -> int:
	var rank := clampi(c.rank(), 0, RANK_XP.size() - 1)
	return roundi(MONTHLY_XP * RANK_XP[rank] * kingdom_power(kingdom) * randf_range(RANDOM_XP[0], RANDOM_XP[1]))

func _on_month_passed(_m: int, _y: int) -> void:
	if not GameManager.is_game_active:
		return
	initialize_world()
	for r: Relationship in RelationsData.relations:
		if r.character != null and not r.person_name in RelationsData.retinue:
			_ensure_start_level(r)
			grow(r.character, monthly_xp(r.character, r.kingdom))

## Quien aparece más tarde (señores nuevos, herederos, cortesanos) recibe su nivel inicial una vez.
func _ensure_start_level(r: Relationship) -> void:
	var c := r.character
	if c.has_meta(META_SEEN):
		return
	c.set_meta(META_SEEN, true)
	var target := start_level(c, r.kingdom)
	if c.level < target:
		level_to(c, target)

## Suma experiencia a un PNJ y reparte sus puntos de atributo si sube de nivel.
func grow(c: Character, amount: int, source: String = "") -> int:
	var levels := c.gain_xp(amount, source)
	if levels > 0:
		spend_points(c)
	return levels

func level_to(c: Character, target: int) -> void:
	var guard := 0
	while c.level < target and guard < 40:
		grow(c, c.xp_to_next() - c.xp)
		guard += 1

static func spend_points(c: Character) -> void:
	var guard := 0
	while c.unspent_points > 0 and guard < 200:
		guard += 1
		var options: Array = ATTRS.filter(func(a): return int(c.get(a)) < PointAllocator.STAT_MAX)
		if options.is_empty():
			break
		var a: String = options.pick_random()
		c.set(a, int(c.get(a)) + 1)
		c.unspent_points -= 1

## Toda la experiencia que gana el jugador alimenta también a su séquito.
func _on_xp_gained(c: Character, amount: int, source: String) -> void:
	if c == null or c != GameManager.player_character or amount <= 0:
		return
	var share := roundi(amount * RETINUE_XP_SHARE)
	if share <= 0:
		return
	for person_name in RelationsData.retinue:
		var r := RelationsData.get_relation(person_name)
		if r != null and r.character != null and r.character != c:
			grow(r.character, share, source)

func save_state() -> Dictionary:
	return {"initialized": initialized}

## Partidas anteriores a este sistema: el mundo se pone al día con los meses jugados.
func load_state(data: Dictionary) -> void:
	initialized = bool(data.get("initialized", false))
	if not initialized and GameManager.is_game_active:
		initialize_world()
		var months := GameManager.months_elapsed()
		for r: Relationship in RelationsData.relations:
			if r.character != null and not r.person_name in RelationsData.retinue:
				var total := 0
				for i in months:
					total += monthly_xp(r.character, r.kingdom)
				grow(r.character, total)
