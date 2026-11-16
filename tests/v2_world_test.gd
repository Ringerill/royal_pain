extends SceneTree
# Rediseño v2, fase 6: grupos en los caminos (RoadTraffic), expediciones por salas y la arena (Expeditions).
#   <godot>_console.exe --headless --path . --script tests/v2_world_test.gd

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
	var RT = root.get_node("RoadTraffic")
	var EX = root.get_node("Expeditions")
	var CS = root.get_node("CombatSetup")
	var CL = load("res://scripts/resources/character_loader.gd")
	var p: Character = CL.make_test_character("Sir Errante", Character.Role.CABALLERO)
	GM.start_new_game(p, MD.castles[0].castle_id)
	await process_frame
	await process_frame

	print("[caminos]")
	check(RT.groups.size() >= 5, "el reino tiene grupos en sus caminos (%d)" % RT.groups.size())
	var types := {}
	for g in RT.groups:
		types[g.type] = true
	check(types.size() == 4, "bandidos, patrullas, caravanas y viajeros")
	var g0: Dictionary = RT.groups[0]
	var pos0: Vector2 = RT.position_of(g0)
	RT.paused = true
	RT.advance(3.0)
	check(RT.position_of(g0) != pos0, "se mueven con el reloj")
	var met := []
	RT.encounter.connect(func(g): met.append(g))
	RT.paused = false
	var g: Dictionary = RT.groups[1]
	g.a = J.at
	g.b = J.neighbors(J.at)[0]
	g.t = 0.0
	g.met = false
	RT.advance(0.01)
	check(met.size() >= 1, "cruzarte con un grupo dispara el encuentro")
	var n0: int = RT.groups.size()
	RT.remove(met[0])
	check(RT.groups.size() == n0 - 1, "un grupo vencido deja el camino")
	J.hours += RT.RESPAWN_HOURS + 1.0
	RT.advance(0.01)
	check(RT.groups.size() == n0, "y otro aparece más tarde")
	p.fame = -30
	check(RT.patrol_hostile(), "con mala fama las patrullas te persiguen")
	p.fame = 0

	print("[expedición]")
	var cave := -1
	for n in J.nodes():
		if n.type in KingdomMaps.EXPEDITION_TYPES and cave < 0:
			cave = n.index
	check(cave >= 0, "el reino tiene un lugar que explorar")
	check(EX.start_expedition(J.kingdom, cave) and EX.run.layers.size() == EX.LAYERS + 1, "la expedición tiene %d niveles y un jefe" % EX.LAYERS)
	var gold0: int = p.gold
	var guard := 0
	while EX.active() and guard < 20:
		guard += 1
		var ch: Array = EX.choices()
		if ch.is_empty():
			break
		var res: Dictionary = EX.enter(ch[0][0], ch[0][1])
		if res.has("fight"):
			check(res.fight.get("expedition", false), "las salas de combate van ligadas a la expedición") if guard == 1 or EX.room(ch[0][0], ch[0][1]).type == "jefe" else null
			CS.begin_event_fight(res.fight, "prueba")
			CS.apply_outcome(true)
	check(not EX.active() and p.gold > gold0, "superar al jefe acaba la expedición con premio")
	check(not EX.blocker(J.kingdom, cave).is_empty(), "y el lugar queda limpio un tiempo")
	J.hours += J.HOURS_PER_DAY * (EX.RENEW_DAYS + 1)
	check(EX.blocker(J.kingdom, cave).is_empty(), "luego se renueva")
	EX.start_expedition(J.kingdom, cave)
	while EX.active():
		var ch2: Array = EX.choices()
		var r2: Dictionary = EX.enter(ch2[0][0], ch2[0][1])
		if r2.has("fight"):
			CS.begin_event_fight(r2.fight, "prueba")
			CS.apply_outcome(false)
			break
	check(not EX.active(), "perder un combate saca de la expedición")

	print("[arena]")
	check(EX.start_arena(J.kingdom, 0, "jefes") and EX.run.layers.size() == 4, "el desafío de jefes son 4 combates")
	var fame0: int = p.fame
	while EX.active():
		var ch3: Array = EX.choices()
		var r3: Dictionary = EX.enter(ch3[0][0], ch3[0][1])
		CS.begin_event_fight(r3.fight, "prueba")
		CS.apply_outcome(true)
	check(p.fame == fame0 + EX.BOSS_RUSH_PRIZE.fame, "vencerlo da fama")
	check(not EX.arena_blocker(J.kingdom, 0, "jefes").is_empty() and EX.arena_blocker(J.kingdom, 0, "torneo").is_empty(), "una vez al mes cada modalidad")
	var st: Dictionary = EX.save_state()
	EX.reset()
	EX.load_state(st)
	check(not EX.arena_blocker(J.kingdom, 0, "jefes").is_empty() and not EX.cleared.is_empty(), "se guarda y se carga")

	print("[pantallas]")
	EX.start_expedition(J.kingdom, cave) if EX.blocker(J.kingdom, cave).is_empty() else EX.start_arena(J.kingdom, 0, "torneo")
	change_scene_to_file(EX.SCENE)
	await create_timer(0.5).timeout
	check(current_scene != null and current_scene._rooms.get_child_count() == EX.run.layers.size(), "la pantalla muestra los niveles de salas")
	change_scene_to_file(GM.MAP_SCENE)
	await create_timer(0.6).timeout
	check(current_scene._traffic != null, "el mapa dibuja los grupos")
	print("FALLAS: %d" % fails if fails else "TODO OK")
	quit(1 if fails else 0)
