extends SceneTree
# Rediseño v2, fase 2: reloj y viajes (Journey) y la pantalla del mapa del reino.
#   <godot>_console.exe --headless --path . --script tests/v2_journey_test.gd

var fails := 0

func check(cond: bool, what: String) -> void:
	print(("  ok  " if cond else "  FALLA ") + what)
	if not cond:
		fails += 1

func _initialize() -> void:
	_run.call_deferred()

func _step(J, seconds: float) -> void:
	var t := 0.0
	while t < seconds and J.is_traveling():
		J._process(0.1)
		t += 0.1

func _run() -> void:
	var GM = root.get_node("GameManager")
	var MD = root.get_node("MapData")
	var J = root.get_node("Journey")
	var CL = load("res://scripts/resources/character_loader.gd")
	var p: Character = CL.make_test_character("Sir Viajero", Character.Role.CABALLERO)
	GM.start_new_game(p, MD.castles[0].castle_id)
	await process_frame
	print("[inicio]")
	check(J.kingdom == GM.player_kingdom and J.at == 0, "empiezas en la capital de tu reino")
	check(J.node_name(0) == J.capital_castle(J.kingdom).castle_name, "la capital lleva el nombre del castillo")
	check(J.node_name(1) != "" and J.node_name(1) != J.node_name(2), "los lugares tienen nombres propios")
	check(J.day_of_month() == 1 and int(J.hour_of_day()) == 8, "día 1, 8:00")

	print("[viaje]")
	var target: int = J.neighbors(0)[0]
	var h0: float = J.hours
	var e0: int = p.energy
	check(J.travel_to(target), "empiezas a viajar")
	J.set_speed(3)
	_step(J, 60.0)
	check(not J.is_traveling() and J.at == target, "llegas al destino")
	var spent: float = J.hours - h0
	check(absf(spent - KingdomMaps.travel_hours(J.kingdom, 0, target)) < 1.0, "el reloj avanzó lo que dura el camino (%.1f h)" % spent)
	check(p.energy < e0 and absi((e0 - p.energy) - roundi(spent * 2.0)) <= 1, "la energía bajó 2 por hora (%d)" % (e0 - p.energy))
	var far: int = J.nodes().size() - 1
	var r: Array = J.route(J.at, far)
	check(not r.is_empty() and r[-1] == far, "ruta por caminos hasta un lugar lejano (%d tramos)" % r.size())
	var h1: float = J.hours
	J.wait_hours(3.0)
	check(is_equal_approx(J.hours, h1 + 3.0), "esperar no gasta energía pero pasa el tiempo")

	print("[descanso y desmayo]")
	J.at = 0
	p.energy = 10
	J.sleep()
	check(p.energy == p.max_energy, "dormir en la capital recupera toda la energía")
	p.energy = 3
	p.gold = 100
	J.travel_to(far)
	_step(J, 60.0)
	check(not J.is_traveling() and p.energy == J.FAINT_ENERGY and p.gold == 80, "sin energía te desmayas: despiertas con 30 y sin el 20 % del oro")
	check(J.node(J.at).type in KingdomMaps.SETTLEMENT_TYPES, "despiertas en un lugar habitado (%s)" % J.node_name(J.at))

	print("[meses]")
	var m0: int = GM.months_elapsed()
	J.pass_time(J.HOURS_PER_DAY * 31)
	check(GM.months_elapsed() == m0 + 1, "a los 30 días, el mundo avanza un mes")
	check(J.season() in ["invierno", "verano", "otoño"], "estación: %s" % J.season())

	print("[entre reinos]")
	var nb: Array = J.land_neighbors(J.kingdom)
	check(not nb.is_empty(), "el reino tiene vecinos por tierra")
	var k0: int = J.kingdom
	p.energy = 100
	var why: String = J.travel_to_kingdom(nb[0])
	check(why.is_empty() and J.kingdom == nb[0], "viajas por tierra al reino vecino")
	var far_k := -1
	for k in KingdomEnums.Kingdom.values():
		if k != J.kingdom and not k in J.land_neighbors(J.kingdom) and KingdomMaps.has_port(k):
			far_k = k
	check(not J.world_route(far_k).ok, "a un reino lejano no se va por tierra")
	for n in J.nodes():
		if n.type == "puerto":
			J.at = n.index
	var sea: Dictionary = J.world_route(far_k)
	check(sea.ok and sea.sea, "desde un puerto, sí por mar")

	print("[guardado]")
	var st: Dictionary = J.save_state()
	var k_saved: int = J.kingdom
	J.kingdom = k0
	J.load_state(st)
	check(J.kingdom == k_saved and J.names.size() > 50, "guardar y cargar conserva reino, lugar y nombres")

	print("[sprites]")
	var c2: Character = CL.make_test_character("Dama", Character.Role.CABALLERO)
	c2.portrait = load("res://assets/portraits/Characters/Female/woman1.png")
	var f1: Texture2D = SpriteSheets.frame(c2, 1)
	check(f1 != null and f1.get_width() == 209, "el primer fotograma de reposo sale de su hoja (%s)" % SpriteSheets.sheet_path(c2))
	var en: Character = CL.make_test_character("Bandida", Character.Role.SOLDADO)
	en.portrait = load("res://assets/portraits/Enemies/E-Female/E-W-Bandit01.png")
	check(SpriteSheets.has_sheet(en), "los enemigos también tienen hoja (%s)" % SpriteSheets.sheet_path(en))
	p.portrait = c2.portrait

	print("[pantalla]")
	change_scene_to_file(GM.MAP_SCENE)
	await create_timer(0.8).timeout
	var sc = current_scene
	check(sc != null and sc.get_script() != null and sc._node_buttons.size() == J.nodes().size(), "la pantalla del reino muestra sus %d lugares" % J.nodes().size())
	print("FALLAS: %d" % fails if fails else "TODO OK")
	quit(1 if fails else 0)
