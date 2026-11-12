extends SceneTree
# Encargos de «dedicar acciones»: la acción del castillo que corresponde cuenta (la siega con
# «Trabajar la Tierra»). Y la recompensa se muestra con iconos.
#   <godot>_console.exe --headless --path . --script tests/mission_credit_test.gd

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
	var MS = root.get_node("MissionData")
	var CL = load("res://scripts/resources/character_loader.gd")
	var CAT = load("res://scripts/resources/mission_catalog.gd")
	var p: Character = CL.make_test_character("Juan Labriego", Character.Role.CAMPESINO)
	GM.start_new_game(p, MD.castles[0].castle_id)
	await process_frame
	MS.active.clear()
	var tpl: Dictionary = {}
	for t in CAT.TEMPLATES:
		if t.id == "cosecha":
			tpl = t
	MS.accept(tpl)
	var done_before: int = MS.completed_count
	var t1: String = MS.credit_action("cosecha")
	check(int(MS.active[0].get("progress", 0)) == 1 and "1/2" in t1, "trabajar la tierra cuenta para la siega (%s)" % t1)
	var t2: String = MS.credit_action("cosecha")
	check(MS.active.is_empty() and MS.completed_count == done_before + 1, "a la segunda, encargo cumplido (%s)" % t2)
	check(MS.credit_action("cosecha").is_empty(), "sin encargo, no pasa nada")
	var rich: String = StatIcons.richify("Recompensa: +30 oro, +3 honor, +3 favor de quien encarga.")
	check("two-coins" in rich and "laurel-crown" in rich and not " oro" in rich and not " honor" in rich, "la recompensa lleva iconos y no palabras")
	print("FALLAS: %d" % fails if fails else "TODO OK")
	quit(1 if fails else 0)
