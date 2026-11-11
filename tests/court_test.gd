extends SceneTree
# Audiencias con el gobernante, panel de reinos e interacciones voluntarias (prueba compacta).
#   <godot>_console.exe --headless --path . --script tests/court_test.gd

var fails := 0

func check(cond: bool, what: String) -> void:
	print(("  ok  " if cond else "  FALLA ") + what)
	if not cond:
		fails += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var GM = root.get_node("GameManager")
	var MD = root.get_node("MapData")
	var RD = root.get_node("RelationsData")
	var RC = root.get_node("RoyalCourt")
	var CL = load("res://scripts/resources/character_loader.gd")
	var p: Character = CL.make_test_character("Juan Labriego", Character.Role.CAMPESINO)
	p.gold = 300
	GM.start_new_game(p, MD.castles[0].castle_id)
	await process_frame
	print("[gobernantes]")
	var other := -1
	for c in MD.castles:
		if c.kingdom != GM.player_kingdom and c.kingdom != KingdomEnums.Kingdom.NEUTRAL:
			other = c.kingdom
			break
	var mine: Relationship = RC.ruler_of(GM.player_kingdom)
	var theirs: Relationship = RC.ruler_of(other)
	check(mine != null and theirs != null and mine != theirs, "cada reino tiene gobernante (%s, %s)" % [mine.person_name if mine else "—", theirs.person_name if theirs else "—"])
	print("[audiencia]")
	GM.actions_remaining = 5
	check(RC.blocker(mine, true).is_empty(), "hasta un campesino puede escribir al gobernante")
	mine.affinity = -50
	var low: float = RC.acceptance_chance(mine, true)
	mine.affinity = 80
	p.fame = 60
	var high: float = RC.acceptance_chance(mine, true)
	check(high > low + 0.3, "la aceptación sube con afinidad y renombre (%.2f → %.2f)" % [low, high])
	var got := false
	var rejected := false
	for i in 30:
		RC.reset()
		GM.actions_remaining = 5
		var res: Dictionary = RC.request(mine, true)
		got = got or res.ok
		rejected = rejected or not res.ok
	check(got, "a veces te recibe")
	RC.reset()
	mine.affinity = -100
	p.fame = 0
	GM.actions_remaining = 5
	var r2: Dictionary = {}
	for i in 20:
		RC._last_month.clear()
		RC._rejected.clear()
		GM.actions_remaining = 5
		r2 = RC.request(mine, true)
		if not r2.ok:
			break
	check(not r2.ok and not RC.blocker(mine, true).is_empty(), "si te rechaza, toca esperar")
	print("[favores]")
	mine.affinity = 70
	var favors: Array = RC.favors(mine)
	var names: Array = favors.map(func(f): return f[0])
	check("Pedir oro" in names and "Pedir tropas" in names and "Pedir un cargo en la corte" in names and "Pedir la mano de alguien de su casa" in names, "favores: %s" % ", ".join(names))
	var gold0 := p.gold
	var aff0 := mine.affinity
	for f in favors:
		if f[0] == "Pedir oro":
			f[3].call()
	check(p.gold > gold0 and mine.affinity < aff0, "pedir oro da oro y cuesta afinidad")
	var rent0 := p.rent
	for f in RC.favors(mine):
		if f[0] == "Pedir un cargo en la corte" and f[2] == "":
			f[3].call()
	check(p.rent > rent0, "un cargo en la corte da rentas")
	check(RC.respects(mine).begins_with("Presentas"), "gesto: presentar respetos")
	print("[panel de reinos]")
	var KP = load("res://scripts/ui/kingdom_panel.gd")
	var panel: Control = KP.open(root, [])
	await process_frame
	check(panel._tabs.get_tab_count() >= 2, "una pestaña por reino (%d)" % panel._tabs.get_tab_count())
	panel.queue_free()
	var RAP = load("res://scripts/ui/royal_audience_panel.gd")
	var ap: Control = RAP.open(root, mine)
	await process_frame
	check(ap._favors.get_child_count() >= 5, "la asamblea muestra los favores")
	ap.queue_free()
	print("[interacciones voluntarias]")
	var PI = load("res://scripts/resources/personal_interactions.gd")
	var friend: Relationship = null
	for r: Relationship in RD.relations:
		if r.character != null and r.kind == Relationship.Kind.CORTESANO and RD.in_area(r):
			friend = r
			break
	var acts: Array = PI.for_relation(friend)
	check(not acts.is_empty() and acts[0][0] == "cena", "con un conocido: invitar a cenar")
	GM.actions_remaining = 3
	var aff_before: int = friend.affection
	var txt: String = PI.perform(friend, "cena")
	check(friend.affection > aff_before and not PI.blocker(friend, "cena").is_empty(), "%s (y una vez al mes)" % txt)
	RD.retinue.append(friend.person_name)
	check(PI.for_relation(friend).any(func(a): return a[0] == "entrenar"), "con el séquito: entrenar juntos")
	print("[interacciones beneficiosas]")
	var ok_all := true
	var told := []
	for id in ["recados", "ensenar", "cultivar", "consejo", "casa", "paseo", "estudiar", "confianza", "presentar"]:
		RD.interaction_months.erase(friend.person_name)
		friend.affection = 60
		GM.actions_remaining = 3
		var t: String = PI.perform(friend, id)
		ok_all = ok_all and not t.is_empty() and not t.begins_with("No ")
		told.append(id)
	check(ok_all, "todas dan su resultado (%s)" % ", ".join(told))
	print("[diálogos sueltos]")
	friend.affection = 60
	var said := ""
	for i in 10:
		said = root.get_node("SocialEvents").ambient_chatter(true)
		if not said.is_empty():
			break
	check(not said.is_empty() and not "{" in said, "alguien cercano te habla: %s" % said.left(90))
	print("[acciones]")
	var p2: Character = GM.player_character
	p2.role = Character.Role.CABALLERO
	p2.leadership = 5
	p2.level = 1
	RC.posts.clear()
	GM._recalculate_actions_per_turn()
	var base_actions: int = GM.actions_per_turn
	p2.level = 10
	RC.posts.append("alguien")
	var home = MD.get_castle_by_id(GM.home_castle_id)
	home.buildings["cancilleria"] = 1
	GM._recalculate_actions_per_turn()
	check(GM.actions_per_turn == base_actions + 2 + 1 + 1, "nivel 10 (+2), cargo (+1) y cancillería (+1): %d → %d" % [base_actions, GM.actions_per_turn])
	GM.actions_remaining = 0
	RD.free_interaction_month = -1
	RD.retinue.append(friend.person_name)
	RD.interaction_months.erase(friend.person_name)
	check(PI.blocker(friend, "entrenar").is_empty(), "sin acciones, la primera interacción con el séquito es gratis")
	PI.perform(friend, "entrenar")
	RD.interaction_months.erase(friend.person_name)
	check(not PI.blocker(friend, "recados").is_empty(), "solo una gratis al mes")
	print("FALLAS: %d" % fails if fails else "TODO OK")
	quit(1 if fails else 0)
