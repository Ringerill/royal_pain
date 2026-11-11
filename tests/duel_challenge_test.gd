extends SceneTree
# Retar a duelo: eliges a quién (DuelPicker con la gente de tu zona) y puede rechazarte.
#   <godot>_console.exe --headless --path . --script tests/duel_challenge_test.gd

var fails := 0

func check(cond: bool, what: String) -> void:
	print(("  ok  " if cond else "  FALLA ") + what)
	if not cond:
		fails += 1

func _initialize() -> void:
	_run.call_deferred()

## Cuántas veces de n acepta el reto (con acciones de sobra).
func _accepts(RD, GM, r: Relationship, n: int) -> int:
	var yes := 0
	for i in n:
		GM.actions_remaining = 5
		if RD.challenge(r).get("accepted", false):
			yes += 1
	return yes

func _run() -> void:
	var GM = root.get_node("GameManager")
	var MD = root.get_node("MapData")
	var RD = root.get_node("RelationsData")
	var CL = load("res://scripts/resources/character_loader.gd")
	var p: Character = CL.make_test_character("Sir Retador", Character.Role.CABALLERO)
	GM.start_new_game(p, MD.castles[0].castle_id)
	await process_frame
	print("[a quién puedes retar]")
	var list: Array = RD.duel_candidates()
	check(list.size() >= 3, "hay gente de tu zona a quien retar (%d)" % list.size())
	var ok_list: bool = list.all(func(r): return RD.in_area(r) and r.character.role != Character.Role.CAMPESINO and not r.person_name in RD.retinue and r.kind != Relationship.Kind.CONYUGE)
	check(ok_list, "solo gente de tu zona que se bate (sin campesinos, séquito ni cónyuge)")
	var rival: Relationship = list[0]
	rival.kind = Relationship.Kind.RIVAL_DUELO
	list = RD.duel_candidates()
	check(list[0] == rival, "los rivales salen primero")
	var holder := Control.new()
	root.add_child(holder)
	var picked := []
	var picker = load("res://scripts/ui/duel_picker.gd").open(holder, list, func(r): picked.append(r), func(): picked.append("desconocido"))
	await process_frame
	var buttons: Array = picker.find_children("*", "Button", true, false).filter(func(b): return b.text == "Retar")
	check(buttons.size() == list.size(), "el panel lista a cada uno con su botón «Retar» (%d)" % buttons.size())
	buttons[0].pressed.emit()
	await process_frame
	check(picked == [list[0]] and (not is_instance_valid(picker) or picker.is_queued_for_deletion()), "elegir a alguien lo propone y cierra el panel")
	print("[puede rechazarte]")
	var r: Relationship = list[1] if list.size() > 1 else list[0]
	var c: Character = r.character
	c.role = p.role
	c.personality = Character.Personality.LEAL
	c.combat = p.combat
	c.defense = p.defense
	r.affinity = 0
	r.affection = 0
	check(_accepts(RD, GM, r, 10) == 10, "alguien de tu fuerza y sin motivos acepta siempre")
	GM.actions_remaining = 1
	RD.challenge(r)
	check(GM.actions_remaining == 0, "proponer el reto gasta 1 acción")
	c.personality = Character.Personality.COBARDE
	var yes := _accepts(RD, GM, r, 40)
	check(yes < 30 and yes > 0, "un cobarde suele escabullirse (acepta %d de 40)" % yes)
	c.personality = Character.Personality.LEAL
	r.affinity = 80
	yes = _accepts(RD, GM, r, 40)
	check(yes < 36 and yes > 10, "un amigo a veces no quiere batirse contigo (acepta %d de 40)" % yes)
	r.affinity = 0
	c.personality = Character.Personality.HONORABLE
	p.honor = -30
	GM.actions_remaining = 3
	var res: Dictionary = RD.challenge(r)
	check(not res.accepted and "honor" in res.text, "un honorable rechaza a un deshonrado")
	p.honor = 20
	c.personality = Character.Personality.PRUDENTE
	c.combat = p.combat - 3
	yes = _accepts(RD, GM, r, 40)
	check(yes < 40, "un prudente puede rechazar a alguien más fuerte (acepta %d de 40)" % yes)
	print("FALLAS: %d" % fails if fails else "TODO OK")
	quit(1 if fails else 0)
