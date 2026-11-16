extends SceneTree
# Rediseño v2, fase 8: ascensos por hitos, soldados, alianzas con plazo, purga y ultimátum,
# ejércitos enemigos en los caminos, piratas y el salón del trono.
#   <godot>_console.exe --headless --path . --script tests/v2_kingdoms_test.gd

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
	var J = root.get_node("Journey")
	var RD = root.get_node("RelationsData")
	var VD = root.get_node("ViaData")
	var CA = root.get_node("Career")
	var RT = root.get_node("RoadTraffic")
	var CS = root.get_node("CombatSetup")
	var CL = load("res://scripts/resources/character_loader.gd")
	var p: Character = CL.make_test_character("Sir Ascenso", Character.Role.INAFILIADO)
	p.via = ViaCatalog.Via.CONQUISTADOR
	GM.start_new_game(p, MD.castles[0].castle_id)
	await process_frame
	p.status_rank = RankCatalog.Rank.INAFILIADO

	print("[ascensos]")
	check(not CA.promotion_blocker().is_empty(), "sin hitos no se asciende")
	VD.counts.contracts = 3
	check(CA.promotion_blocker().is_empty(), "con 3 encargos, a trabajador")
	CA.promote()
	check(p.rank_v2() == RankCatalog.Rank.TRABAJADOR, "asciende a trabajador")
	VD.counts.contracts = 6
	p.fame = 10
	check("victorias" in CA.promotion_blocker(), "a soldado le faltan victorias")
	for i in 5:
		CS.begin_event_fight(CA.army_fight(), "prueba")
		CS.apply_outcome(true)
	check(CA.wins >= 5, "las victorias en combate cuentan (%d)" % CA.wins)
	CA.promote()
	check(p.rank_v2() == RankCatalog.Rank.SOLDADO and p.soldiers > 0, "asciende a soldado y su comandante le asigna %d soldados" % p.soldiers)
	check(not CA.recruit_blocker(5).is_empty(), "un soldado no recluta: se los asignan")

	print("[nobleza y soldados]")
	p.status_rank = RankCatalog.Rank.NOBLE
	p.soldiers = 0
	p.gold = 2000
	check(CA.recruit(20).begins_with("Reclutas") and p.soldiers == 20, "un noble recluta y paga")
	var g0: int = p.gold
	CA.monthly()
	check(p.gold == g0 - 20 * CA.UPKEEP, "y paga a su tropa cada mes")

	print("[alianzas con plazo]")
	var lords: Array = RD.lords()
	var ally: Relationship = lords[0]
	ally.allied = true
	ally.allied_until = -1
	CA.monthly()
	check(ally.allied_until == GM.months_elapsed() + CA.alliance_months() and CA.alliance_months() == 6, "la alianza tiene plazo (6 meses para un Conquistador)")
	ally.allied_until = GM.months_elapsed()
	CA.monthly()
	check(not ally.allied, "al vencer, se rompe")

	print("[purga y ultimátum]")
	var targets: Array = CA.purge_targets()
	if not targets.is_empty():
		var n0: int = RD.relations.size()
		CA.purge(targets[0])
		check(RD.relations.size() == n0 - 1, "la purga elimina a un noble")
	var enemy_castle: Castle = null
	for c in MD.castles:
		if c.kingdom != GM.player_kingdom:
			enemy_castle = c
	p.soldiers = CA.ULTIMATUM_SOLDIERS
	var t: String = CA.ultimatum(enemy_castle)
	check(enemy_castle.kingdom == GM.player_kingdom, "con tropa suficiente, el ultimátum rinde el castillo")

	print("[guerra, ejércitos y piratas]")
	var hostile: Array = RD.hostile_kingdoms()
	if hostile.is_empty():
		for r in RD.lords():
			if r.kingdom != GM.player_kingdom:
				r.at_war = true
				break
	RT._populate(GM.player_kingdom)
	check(RT.groups.any(func(g): return g.type == "ejercito") or RD.hostile_kingdoms().is_empty(), "en guerra, un ejército enemigo recorre tu reino")
	var pirates := 0
	for i in 200:
		CA.roll_pirates()
		pirates += 1 if CA.pending_pirates else 0
	check(pirates > 40 and pirates < 110, "por mar, a veces asaltan los piratas (%d/200)" % pirates)
	check(CA.pirate_fight().foe.name == "Capitán pirata" and not CA.pending_pirates, "y se lucha contra su capitán")

	print("[trono]")
	J.at = 0
	J.hours = floor(J.hours / J.HOURS_PER_DAY) * J.HOURS_PER_DAY + 12.0
	change_scene_to_file("res://scenes/place/place.tscn")
	await create_timer(0.5).timeout
	var sc = current_scene
	check("trono" in sc.buildings(), "la capital tiene salón del trono")
	sc.enter("trono")
	var texts: Array = sc._options.get_children().map(func(b): return b.text)
	check(texts.any(func(x): return x.begins_with("Reclutar")), "en audiencia se reclutan soldados")
	var st: Dictionary = CA.save_state()
	CA.reset()
	CA.load_state(st)
	check(CA.wins >= 5, "se guarda y se carga")
	print("FALLAS: %d" % fails if fails else "TODO OK")
	quit(1 if fails else 0)
