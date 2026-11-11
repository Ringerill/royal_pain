extends SceneTree
# Sucesos de personajes coherentes con su personalidad: exclusiones (avoid), propios (only) y pesos.
#   <godot>_console.exe --headless --path . --script tests/personality_events_test.gd

var fails := 0

func check(cond: bool, what: String) -> void:
	print(("  ok  " if cond else "  FALLA ") + what)
	if not cond:
		fails += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var SE = root.get_node("SocialEvents")
	var CAT = load("res://scripts/resources/social_event_catalog.gd")
	var P := Character.Personality
	var deudas: Dictionary = CAT.by_id("soc_pide_ayuda")
	check(SE.weight_for(deudas, P.PIADOSO) == 0.0 and SE.weight_for(deudas, P.COBARDE) > 1.0, "deudas de juego: nunca a un piadoso, más a un cobarde")
	check(SE.weight_for(CAT.by_id("soc_rina"), P.LEAL) < 1.0, "un suceso pensado para otros caracteres es poco probable")
	var own := 0
	for p in P.values():
		var mine: Array = CAT.BOND.filter(func(t): return p in t.get("only", []))
		own += 1 if not mine.is_empty() else 0
		for t in mine:
			for q in P.values():
				if q != p and SE.weight_for(t, q) > 0.0:
					fails += 1
					print("  FALLA %s también le pasa a %d" % [t.id, q])
	check(own == P.size(), "cada personalidad tiene sucesos propios (%d/%d)" % [own, P.size()])
	var CL = load("res://scripts/resources/character_loader.gd")
	var GM = root.get_node("GameManager")
	var MD = root.get_node("MapData")
	var RD = root.get_node("RelationsData")
	GM.start_new_game(CL.make_test_character("Sir Social", Character.Role.CABALLERO), MD.castles[0].castle_id)
	await process_frame
	var r: Relationship = RD.courtiers()[0]
	r.affection = 50
	r.character.personality = P.PIADOSO
	var seen := {}
	for i in 200:
		var e: Dictionary = SE.bond_event(r)
		seen[e.get("id", "")] = true
	check(not seen.has("soc_pide_ayuda") and not seen.has("soc3_cruel_castigo"), "a un piadoso nunca le llegan deudas de juego ni azotes")
	check(seen.has("soc3_piadoso_peregrinacion"), "y sí su peregrinación")
	print("FALLAS: %d" % fails if fails else "TODO OK")
	quit(1 if fails else 0)
