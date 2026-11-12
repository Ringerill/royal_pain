extends SceneTree
# Campaña: si el ejército invasor gana la batalla campal, el asedio empieza en el acto («Continuar al
# asedio», mismo bando) y, al volver al mapa, la campaña se ha llevado unos meses.
#   <godot>_console.exe --headless --path . --script tests/campaign_siege_test.gd

var fails := 0

func check(cond: bool, what: String) -> void:
	print(("  ok  " if cond else "  FALLA ") + what)
	if not cond:
		fails += 1

func _initialize() -> void:
	_run.call_deferred()

# Termina la batalla: deja al bando contrario sin tropas y pasa turnos (rehusando los retos).
func _finish(scene, b) -> void:
	for u in b.units:
		if u.side != b.player_side and u.is_active():
			u.soldiers = 1
			u.morale = 1
	var guard := 0
	while not b.is_over and guard < 30:
		if not b.pending_challenge.is_empty():
			scene._answer_challenge(false)
		else:
			scene._on_end_turn_pressed()
		await process_frame
		guard += 1
	await create_timer(1.5).timeout

func _run() -> void:
	var GM = root.get_node("GameManager")
	var MD = root.get_node("MapData")
	var RD = root.get_node("RelationsData")
	var AR = root.get_node("ArmyData")
	var CS = root.get_node("CombatSetup")
	var CL = load("res://scripts/resources/character_loader.gd")
	var p: Character = CL.make_test_character("Sir Campaña", Character.Role.CABALLERO)
	GM.start_new_game(p, MD.castles[0].castle_id)
	await process_frame
	var home = MD.get_castle_by_id(GM.home_castle_id)
	var x = null
	var e = null
	for id in [home.castle_id] + Array(home.connected_castle_ids):
		var c = MD.get_castle_by_id(id)
		if c.owner_name == p.full_name() or AR.is_player_defended(c):
			continue
		for id2 in c.connected_castle_ids:
			var c2 = MD.get_castle_by_id(id2)
			if c2.kingdom != c.kingdom and c2.kingdom != GM.player_kingdom and not AR.is_player_defended(c2):
				x = c
				e = c2
		if x != null:
			break
	check(x != null, "hay un castillo junto a ti con un vecino de otro reino")
	if x == null:
		quit(1)
		return
	KingdomDiplomacy.declare_war(RD.kingdom_wars, RD.kingdom_alliances, x.kingdom, e.kingdom, 0)
	for a in AR.armies.duplicate():
		AR.disband_army(a)
	x.garrison_size = 60
	var army = AR.create_army(e.owner_name, e.kingdom, 150, e.castle_id)
	army.origin_castle_id = e.castle_id
	army.destination_castle_id = x.castle_id
	army.turns_remaining = 2
	var month0: int = GM.months_elapsed()

	print("[batalla campal con el ejército invasor]")
	var fight := {"type": "invited", "kind": "field", "side": BattleEnums.Side.ATACANTE, "lord": e.owner_name,
		"inviter": e.owner_name, "army_id": army.army_id, "castle_id": x.castle_id}
	change_scene_to_file(CS.begin_event_fight(fight, "Batalla campal"))
	await create_timer(0.6).timeout
	var scene = current_scene
	var b = scene.battle
	check(not b.has_walls, "en campo abierto, sin murallas")
	await _finish(scene, b)
	check(b.is_over, "la campal termina")
	check(not scene._siege_next.is_empty(), "el ejército gana: el asedio viene en el acto")
	check(army.pending_battle and army.current_castle_id == x.castle_id, "el ejército espera ante %s" % x.castle_name)
	var cont: Button = null
	for ch in scene.btn_back_to_map.get_parent().get_children():
		if ch is Button and ch.text == "Continuar al asedio":
			cont = ch
	check(cont != null, "el cartel ofrece «Continuar al asedio»")
	check(GM.months_elapsed() == month0, "la campal sola no pasa meses")

	print("[el asedio, en el mismo bando]")
	scene._continue_to_siege()
	await create_timer(0.8).timeout
	scene = current_scene
	b = scene.battle
	check(scene.invited.get("kind", "") == "army" and scene.invited.get("campaign", false), "es el asedio de la campaña")
	check(b.has_walls and b.player_side == BattleEnums.Side.ATACANTE, "con murallas, y atacas con el ejército")
	await _finish(scene, b)
	check(b.is_over, "el asedio termina")
	check(AR.find_army(army.army_id) == null, "el asedio queda resuelto en el mapa")
	check(x.kingdom == e.kingdom, "%s cae en manos del invasor" % x.castle_name)
	check(scene.result_label.text.contains("meses"), "el cartel dice que la campaña se llevó meses")
	print("  cartel: ", scene.result_label.text.replace("\n", " / ").left(400))
	scene._on_back_to_map_pressed()
	await create_timer(1.0).timeout
	check(GM.months_elapsed() == month0 + GM.CAMPAIGN_MONTHS, "al volver al mapa han pasado %d meses (%d)" % [GM.CAMPAIGN_MONTHS, GM.months_elapsed() - month0])
	print("FALLAS: %d" % fails if fails else "TODO OK")
	quit(1 if fails else 0)
