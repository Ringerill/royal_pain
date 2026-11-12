extends SceneTree
# Batalla campal: solo con un ejército de verdad en marcha, una llamada por ejército, y su resultado
# cambia el mapa (bajas, repliegue o marcha que sigue).
#   <godot>_console.exe --headless --path . --script tests/field_battle_test.gd

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
	var AR = root.get_node("ArmyData")
	var CL = load("res://scripts/resources/character_loader.gd")
	var p: Character = CL.make_test_character("Sir Campal", Character.Role.CABALLERO)
	GM.start_new_game(p, MD.castles[0].castle_id)
	await process_frame
	# Un castillo vecino ajeno (X) y un castillo de otro reino junto a él (E), en guerra.
	var home = MD.get_castle_by_id(GM.home_castle_id)
	var x = null
	var e = null
	for id in [home.castle_id] + Array(home.connected_castle_ids):
		var c = MD.get_castle_by_id(id)
		if c.owner_name == p.full_name() or AR.is_player_defended(c):   # tus castillos los defiendes tú (asedio)
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
	RD.liege_name = x.owner_name   # tu señor siempre llama: la prueba no depende del azar
	KingdomDiplomacy.declare_war(RD.kingdom_wars, RD.kingdom_alliances, x.kingdom, e.kingdom, 0)
	for a in AR.armies.duplicate():
		AR.disband_army(a)
	print("[sin ejército no hay batalla]")
	GM.pending_event = {}
	for i in 10:
		AR._maybe_field_invitation()
	check(GM.pending_event.is_empty(), "guerra entre vecinos pero ningún ejército en marcha: nadie te llama")
	check(AR.volunteer_event(x).is_empty(), "ni puedes ofrecerte voluntario")
	print("[con un ejército en marcha]")
	var army = AR.create_army(e.owner_name, e.kingdom, 120, e.castle_id)
	army.origin_castle_id = e.castle_id
	army.destination_castle_id = x.castle_id
	army.turns_remaining = 2
	check(AR.field_target(army) == x, "el ejército marcha sobre %s" % x.castle_name)
	AR._maybe_field_invitation()
	var ev: Dictionary = GM.pending_event
	var fight: Dictionary = ev.get("options", [{}])[0].get("fight", {})
	check(ev.get("title", "") == "Batalla campal" and fight.get("army_id", "") == army.army_id and fight.get("castle_id", "") == x.castle_id,
		"te llaman a salirle al paso (%s)" % str(ev.get("text", "")).left(90))
	GM.pending_event = {}
	AR._maybe_field_invitation()
	check(GM.pending_event.is_empty(), "una sola llamada por ejército")
	check(not AR.volunteer_event(x).is_empty(), "en %s puedes ofrecerte voluntario" % x.castle_name)
	print("[el resultado cambia el mapa]")
	x.garrison_size = 30
	var x_kingdom: int = x.kingdom
	var txt: String = AR.resolve_field_battle(army, x, true, 20, 25)
	check(AR.find_army(army.army_id) == null and not army.is_marching(), "gana el ejército: no sigue en marcha, el asalto se decide ya")
	check(x.kingdom == army.kingdom and x.kingdom != x_kingdom, "con la guarnición rota (5), el castillo cae en el acto")
	# El asedio que sigue, jugado: el ejército espera ante el castillo y el asalto se decide luego.
	x.kingdom = x_kingdom
	x.garrison_size = 30
	army = AR.create_army(e.owner_name, e.kingdom, 120, e.castle_id)
	army.origin_castle_id = e.castle_id
	army.destination_castle_id = x.castle_id
	army.turns_remaining = 2
	AR.resolve_field_battle(army, x, true, 20, 25, false)
	check(AR.find_army(army.army_id) == army and army.pending_battle and army.current_castle_id == x.castle_id and not army.is_marching(),
		"sin asalto inmediato: el ejército queda ante el castillo, listo para el asedio")
	check(x.kingdom == x_kingdom, "el castillo aún no ha caído")
	AR.assault_now(army)
	check(AR.find_army(army.army_id) == null and x.kingdom == army.kingdom, "si no juegas el asedio, se decide al momento")
	# Otro ejército, para probar la derrota.
	x.kingdom = x_kingdom
	x.garrison_size = 75
	army = AR.create_army(e.owner_name, e.kingdom, 90, e.castle_id)
	army.origin_castle_id = e.castle_id
	army.destination_castle_id = x.castle_id
	army.turns_remaining = 2
	var e_garrison: int = e.garrison_size
	var txt2: String = AR.resolve_field_battle(army, x, false, 50, 10)
	check(AR.find_army(army.army_id) == null and e.garrison_size == e_garrison + 40 and x.garrison_size == 65,
		"pierde el ejército: se repliega (40 vuelven a %s) y no hay asedio" % e.castle_name)
	check(AR.turn_events.any(func(t): return "Batalla campal ante" in str(t.get("text", ""))), "queda en las noticias del mes")
	print("  ", txt, " / ", txt2)
	print("FALLAS: %d" % fails if fails else "TODO OK")
	quit(1 if fails else 0)
