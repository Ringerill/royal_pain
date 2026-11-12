extends Node
## Grupo del jugador: tú y la gente que viaja contigo (séquito y cónyuges, ver
## RelationsData.occupation_people). Hasta MAX_ACTIVE activos (tú siempre dentro) y el resto en reserva.
## Se valida sola al consultarla: quien se va, muere o cae preso desaparece del grupo.
## Mientras no lo ordenes a mano, los activos son los MAX_ACTIVE - 1 compañeros más fuertes.
## Guarda su estado en la partida (SaveSystem.MODULES).

signal party_changed

const MAX_ACTIVE := 4
const PLAYER_KEY := "@jugador"

var _order: Array[String] = []   # claves de los activos, en orden (PLAYER_KEY = tú)
var officers: Array[String] = []   # claves de quienes van de oficial en tu pelotón (campales)
var _customized := false         # true en cuanto el jugador ordena el grupo a mano
var stash: Array[Equipment] = []   # almacén del grupo: piezas que nadie lleva puestas

func _ready() -> void:
	GameManager.game_started.connect(func(_c: Character): reset())
	RelationsData.relations_changed.connect(func(): party_changed.emit())

func reset() -> void:
	_order.clear()
	_customized = false
	stash.clear()

# --- Consultas ---

## Compañeros que pueden formar parte del grupo (sin ti), como relaciones.
func member_relations() -> Array[Relationship]:
	var result: Array[Relationship] = []
	for r: Relationship in RelationsData.occupation_people():
		if r.character != null and r.character.is_alive() and not CaptureData.is_prisoner(r.person_name):
			result.append(r)
	return result

## Todos: tú primero y después tus compañeros.
func members() -> Array[Character]:
	var result: Array[Character] = []
	if GameManager.player_character != null:
		result.append(GameManager.player_character)
	for r in member_relations():
		result.append(r.character)
	return result

func active() -> Array[Character]:
	_validate()
	var result: Array[Character] = []
	for k in _order:
		var c := _char(k)
		if c != null:
			result.append(c)
	return result

func reserve() -> Array[Character]:
	var act := active()
	var result: Array[Character] = []
	for c in members():
		if not c in act:
			result.append(c)
	return result

func is_active(c: Character) -> bool:
	return c in active()

func is_player(c: Character) -> bool:
	return c != null and c == GameManager.player_character

func relation_of(c: Character) -> Relationship:
	for r in member_relations():
		if r.character == c:
			return r
	return null

# --- Cambios ---

## Fija los activos (Characters, en orden). Tú entras siempre; se recorta a MAX_ACTIVE.
func set_active(list: Array) -> void:
	var keys: Array[String] = []
	for c in list:
		var k := _key(c)
		if not k.is_empty() and not k in keys:
			keys.append(k)
	if not PLAYER_KEY in keys:
		keys.push_front(PLAYER_KEY)
	while keys.size() > MAX_ACTIVE:
		keys.remove_at(keys.size() - 1 if keys.back() != PLAYER_KEY else keys.size() - 2)
	_order = keys
	_customized = true
	party_changed.emit()

## Intercambia a dos personas: dos activos cambian de puesto; un activo y uno de reserva, de zona.
func swap(a: Character, b: Character) -> void:
	_validate()
	var ka := _key(a)
	var kb := _key(b)
	if ka.is_empty() or kb.is_empty() or ka == kb:
		return
	var ia := _order.find(ka)
	var ib := _order.find(kb)
	if ia < 0 and ib < 0:
		return
	if ia >= 0 and ib >= 0:
		_order[ia] = kb
		_order[ib] = ka
	elif ia >= 0:
		if ka == PLAYER_KEY:
			return
		_order[ia] = kb
	else:
		if kb == PLAYER_KEY:
			return
		_order[ib] = ka
	_customized = true
	party_changed.emit()

## Mueve a un activo un puesto arriba (dir -1) o abajo (dir 1).
func move(c: Character, dir: int) -> void:
	_validate()
	var i := _order.find(_key(c))
	var j := i + dir
	if i < 0 or j < 0 or j >= _order.size():
		return
	swap(c, _char(_order[j]))

## Pasa a activos (si hay hueco) o a reserva (nunca a ti).
func activate(c: Character) -> bool:
	var act := active()
	if c in act or act.size() >= MAX_ACTIVE or _key(c).is_empty():
		return false
	act.append(c)
	set_active(act)
	return true

func to_reserve(c: Character) -> bool:
	var act := active()
	if is_player(c) or not c in act:
		return false
	act.erase(c)
	set_active(act)
	return true

# --- Internos ---

func _key(c: Variant) -> String:
	if not c is Character:
		return ""
	if is_player(c):
		return PLAYER_KEY
	var r := relation_of(c)
	return r.person_name if r != null else ""

func _char(k: String) -> Character:
	if k == PLAYER_KEY:
		return GameManager.player_character
	for r in member_relations():
		if r.person_name == k:
			return r.character
	return null

func _validate() -> void:
	var valid: Array[String] = []
	for k in _order:
		if not k in valid and _char(k) != null:
			valid.append(k)
	if not PLAYER_KEY in valid:
		valid.push_front(PLAYER_KEY)
	if not _customized:
		valid = [PLAYER_KEY]
		var rels := member_relations()
		rels.sort_custom(func(a: Relationship, b: Relationship) -> bool: return _strength(a.character) > _strength(b.character))
		for r in rels.slice(0, MAX_ACTIVE - 1):
			valid.append(r.person_name)
	_order = valid.slice(0, MAX_ACTIVE)

static func _strength(c: Character) -> int:
	return c.level * 10 + c.combat + c.defense

# --- Guardado ---

## Oficial: en las campales va contigo en tu pelotón en vez de llevar uno propio.
func is_officer(c: Character) -> bool:
	return c != null and _key(c) in officers

func set_officer(c: Character, on: bool) -> void:
	var k := _key(c)
	officers.erase(k)
	if on:
		officers.append(k)

func save_state() -> Dictionary:
	return {"order": _order.duplicate(), "customized": _customized, "officers": officers.duplicate(),
		"stash": DataCodec.encode(stash)}

func load_state(data: Dictionary) -> void:
	_order.clear()
	for k in data.get("order", []):
		_order.append(str(k))
	_customized = bool(data.get("customized", false))
	officers.clear()
	for k in data.get("officers", []):
		officers.append(str(k))
	stash.clear()
	var items = DataCodec.decode(data.get("stash", []))
	if items is Array:
		for e in items:
			if e is Equipment:
				stash.append(e)

# --- Equipo y almacén ---

## Quién puedes equipar: tú, tu cónyuge y tu séquito.
func gear_members() -> Array[Character]:
	var out: Array[Character] = [GameManager.player_character]
	if RelationsData.is_married():
		var sp := RelationsData.spouse_relation()
		if sp != null and sp.character != null and not sp.character in out:
			out.append(sp.character)
	for r: Relationship in RelationsData.retinue_members():
		if r.character != null and not r.character in out and not CaptureData.is_serf(r.person_name):
			out.append(r.character)
	return out

## Le quitas una pieza y va al almacén.
func store(c: Character, item: Equipment) -> String:
	if c == null or item == null or not c.equipment.has(item):
		return ""
	c.unequip(item)
	stash.append(item)
	party_changed.emit()
	return "%s deja %s en el almacén." % [c.first_name, item.equipment_name]

## Se pone una pieza del almacén; la que llevaba en esa ranura vuelve al almacén.
func equip_from_stash(c: Character, item: Equipment) -> String:
	if c == null or item == null or not stash.has(item):
		return ""
	stash.erase(item)
	var replaced := c.equip(item)
	if replaced != null:
		stash.append(replaced)
	party_changed.emit()
	return "%s se equipa %s%s." % [c.first_name, item.equipment_name, (" (guarda %s)" % replaced.equipment_name) if replaced != null else ""]
