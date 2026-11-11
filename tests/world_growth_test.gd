extends SceneTree
# Crecimiento del mundo: niveles iniciales, experiencia mensual, séquito y niveles de los rivales.
#   <godot>_console.exe --headless --path . --script tests/world_growth_test.gd

var fails := 0

func check(cond: bool, what: String) -> void:
	print(("  ok  " if cond else "  FALLA ") + what)
	if not cond:
		fails += 1

func _initialize() -> void:
	_run.call_deferred()

func _avg_level(RD, kind: int) -> float:
	var t := 0.0
	var n := 0
	for r: Relationship in RD.relations:
		if r.character != null and r.kind == kind:
			t += r.character.level
			n += 1
	return t / maxf(1, n)

func _run() -> void:
	var GM = root.get_node("GameManager")
	var MD = root.get_node("MapData")
	var RD = root.get_node("RelationsData")
	var WG = root.get_node("WorldGrowth")
	var CL = load("res://scripts/resources/character_loader.gd")
	var p: Character = CL.make_test_character("Sir Crecido", Character.Role.CABALLERO)
	GM.start_new_game(p, MD.castles[0].castle_id)
	await process_frame
	await process_frame
	print("[niveles iniciales]")
	var lords0 := _avg_level(RD, Relationship.Kind.SENOR)
	var court0 := _avg_level(RD, Relationship.Kind.CORTESANO)
	check(WG.initialized and lords0 > court0 and lords0 >= 3.0, "los señores empiezan más arriba (%.1f) que la corte (%.1f)" % [lords0, court0])
	print("[con el tiempo]")
	for m in 24:
		GM.pending_event = {}
		GM.event_queue.clear()
		GM.advance_turn()
	var lords2 := _avg_level(RD, Relationship.Kind.SENOR)
	var court2 := _avg_level(RD, Relationship.Kind.CORTESANO)
	check(court2 > court0 + 0.5 and lords2 > lords0, "en 2 años el mundo sube (corte %.1f → %.1f, señores %.1f → %.1f)" % [court0, court2, lords0, lords2])
	var spread := {}
	for r: Relationship in RD.relations:
		if r.character != null and r.kind == Relationship.Kind.CORTESANO:
			spread[r.character.level] = true
	check(spread.size() >= 3, "hay variedad de niveles (%d distintos)" % spread.size())
	var unspent := 0
	for r: Relationship in RD.relations:
		if r.character != null:
			unspent += r.character.unspent_points
	check(unspent == 0, "los PNJ reparten sus puntos al subir")
	print("[séquito]")
	var mate: Relationship = null
	for r: Relationship in RD.relations:
		if r.character != null and r.kind == Relationship.Kind.CORTESANO:
			mate = r
			break
	RD.retinue.append(mate.person_name)
	var xp0: int = mate.character.xp + mate.character.level * 1000
	GM.player_character.gain_xp(200)
	check(mate.character.xp + mate.character.level * 1000 > xp0, "el séquito gana experiencia contigo")
	print("[rivales de encuentros]")
	p = GM.player_character
	p.level = 8
	var CS = root.get_node("CombatSetup")
	var easy: Character = CS.make_event_foe({"power": -1}, p)
	var hard: Character = CS.make_event_foe({"power": 2}, p)
	check(easy.level >= 6 and easy.level <= 8 and hard.level >= 9, "rival a tu altura según la dificultad (fácil %d, difícil %d)" % [easy.level, hard.level])
	print("FALLAS: %d" % fails if fails else "TODO OK")
	quit(1 if fails else 0)
