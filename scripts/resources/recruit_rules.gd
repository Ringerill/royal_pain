extends RefCounted
# Reclutar o encerrar a enemigos genéricos (y a quien rescatas en una expedición): pasan a ser
# personas del mundo con nombre propio, con las que se interactúa como con cualquier otra; se pueden
# guardar entre tus personajes creados (CharacterLoader.save_npc).
# Uso: const RecruitRules = preload("res://scripts/resources/recruit_rules.gd")

const JOIN_CHANCE := 0.18        # tras vencerle, un genérico puede querer unirse a ti...
const CAPTURE_CHANCE := 0.3      # ...o puedes encerrarle (si no quiere unirse)
const MAX_OFFERS := 2            # como mucho, tantas ofertas por combate
const JOIN_AFFECTION := 45       # intimidad con la que llega quien se une a ti
const RESCUE_AFFECTION := 60     # quien rescatas te está agradecido
const FREE_HONOR := 3            # liberar a quien rescatas
const FREE_FAME := 2
# Clase de armadura (RpgStats.ArmorClass) -> pieza real equivalente (para que no dependa de metadatos).
const ARMOR_ITEM := ["Ropas de Viaje", "Gambesón", "Cota de Malla", "Peto de Placas"]
const GENERIC_METAS := ["enemy_type", "rpg_pv_mult", "rpg_weapon_tier", "rpg_actions"]

static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

static func _node(n: String) -> Node:
	return _tree().root.get_node_or_null(n)

static func is_generic(c: Character) -> bool:
	return c != null and c.has_meta("enemy_type")

## Ofertas tras un combate ganado: [{c, mode: "join" | "capture"}] de los genéricos vencidos que siguen vivos.
static func offers_after_fight(defeated: Array, rng_join: float = JOIN_CHANCE, rng_capture: float = CAPTURE_CHANCE) -> Array:
	var out := []
	for c in defeated:
		if not is_generic(c) or not c.is_alive() or out.size() >= MAX_OFFERS:
			continue
		if randf() < rng_join:
			out.append({"c": c, "mode": "join"})
		elif randf() < rng_capture:
			out.append({"c": c, "mode": "capture"})
	return out

## Nombre propuesto para un genérico (puedes cambiarlo): uno de su cultura y su género.
static func suggested_name(c: Character) -> Array:
	fix_gender(c)
	var culture := CharacterLoader.current_culture()
	return [CharacterLoader.random_first_name(c.gender, culture), CharacterLoader.random_last_name(culture, c.gender)]

## Los genéricos no guardan su género: se deduce del retrato (los de mujer se llaman «woman…»).
static func fix_gender(c: Character) -> void:
	var path := str(c.get_meta("portrait_path", c.portrait.resource_path if c.portrait != null else ""))
	var file := path.get_file().to_lower()
	c.gender = CharacterEnums.Gender.FEMENINO if file.begins_with("woman") or "female" in path.to_lower() else CharacterEnums.Gender.MASCULINO

## Convierte a un genérico en una persona: nombre, equipo de verdad (su arma y armadura), sin los
## ajustes de enemigo, y una ficha en el mundo. Devuelve su relación.
static func make_person(c: Character, first: String, last: String) -> Relationship:
	fix_gender(c)
	var wtree := SkillTreeCatalog.weapon_tree_of(c)
	var wpath := SkillTreeCatalog.weapon_path(c, wtree)   # la vía de arma con la que luchaba se queda
	var weapon := str(c.get_meta(EnemyCatalog.META_WEAPON, ""))
	var armor := int(c.get_meta(RpgStats.META_ARMOR, -1))
	c.first_name = first.strip_edges() if not first.strip_edges().is_empty() else "Sin Nombre"
	c.last_name = last.strip_edges()
	var gear: Array = []
	if not weapon.is_empty():
		var w := Equipment.new()
		w.equipment_name = weapon
		w.slot = "Arma"
		gear.append(w)
	if armor >= 0 and armor < ARMOR_ITEM.size():
		var a := Equipment.new()
		a.equipment_name = ARMOR_ITEM[armor]
		a.slot = "Armadura"
		gear.append(a)
	for e in c.equipment:
		if e != null and not e.slot in ["Arma", "Armadura"]:
			gear.append(e)
	c.equipment.assign(gear)
	for m in GENERIC_METAS + [EnemyCatalog.META_WEAPON, EnemyCatalog.META_WEAPON_TIER, RpgStats.META_ARMOR, RpgStats.META_DAMAGE,
			RpgStats.META_PV_MULT, RpgStats.META_ACTIONS]:
		if c.has_meta(m):
			c.remove_meta(m)
	if c.has_meta("rpg_weapon_path"):
		c.remove_meta("rpg_weapon_path")
	if wtree in SkillTreeCatalog.WEAPON_TREES:
		SkillTreeCatalog.choose_weapon_path(c, wtree, wpath)
	c.honor = CharacterLoader.honor_for_personality(c.personality)
	c.current_health = maxi(1, c.current_health)
	var RD := _node("RelationsData")
	var r := Relationship.new()
	r.person_name = c.full_name()
	r.kind = Relationship.Kind.PUEBLO
	r.kingdom = -1
	r.character = c
	RD.relations.append(r)
	RD.relations_changed.emit()
	return r

## Se une a tu séquito (si cabe; si no, queda como conocido). Devuelve el texto.
static func join(r: Relationship, affection: int = JOIN_AFFECTION) -> String:
	var RD := _node("RelationsData")
	r.affection = maxi(r.affection, affection)
	var counts: Dictionary = RD.retinue_counts()
	if not RD._retinue_fits(counts.others + 1, counts.intimates):
		RD.relations_changed.emit()
		return "%s quiere seguirte, pero tu séquito está lleno: queda entre tus conocidos." % r.person_name
	RD.retinue.append(r.person_name)
	RD.relations_changed.emit()
	return "%s se une a tu séquito." % r.person_name

## Lo encierras: pasa a ser tu prisionero (ver Relaciones › Prisioneros).
static func imprison(c: Character) -> String:
	var CD := _node("CaptureData")
	return CD.capture(c, GameManager.player_character, true)

## Lo haces siervo (como a un prisionero: cuesta honor). Devuelve el texto.
static func enslave(c: Character) -> String:
	var CD := _node("CaptureData")
	CD.capture(c, GameManager.player_character, true)
	var p = CD._find(c.full_name())
	return CD.enslave(p) if p != null else ""

## Lo dejas libre: algo de honor y fama.
static func release(c: Character) -> String:
	var p: Character = GameManager.player_character
	p.honor = clampi(p.honor + FREE_HONOR, Character.HONOR_MIN, Character.HONOR_MAX)
	p.add_fame(FREE_FAME)
	return "%s se marcha libre, agradecido (honor +%d, fama +%d)." % [c.full_name(), FREE_HONOR, FREE_FAME]

## Alguien cautivo en una expedición: una persona nueva con nombre (no un genérico).
static func make_captive(role: int = Character.Role.CAMPESINO) -> Character:
	var gender: int = [CharacterEnums.Gender.MASCULINO, CharacterEnums.Gender.FEMENINO].pick_random()
	var RD := _node("RelationsData")
	var portrait: String = RD._take_portrait(PortraitPool.new(RD.used_portraits), gender)
	var c := CharacterLoader.make_random_character(role, gender, portrait)
	c.level = maxi(1, GameManager.player_character.level - 1 + randi_range(-1, 1)) if GameManager.player_character != null else 1
	c.current_health = maxi(1, c.max_health / 2)   # sale maltrecho del cautiverio
	return c
