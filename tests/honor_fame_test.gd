extends SceneTree
# Honor y fama de −100 a 100 y camino villano (prueba compacta).
#   <godot>_console.exe --headless --path . --script tests/honor_fame_test.gd

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
	var CL = load("res://scripts/resources/character_loader.gd")
	var p: Character = CL.make_test_character("Sir Villano", Character.Role.CABALLERO)
	GM.start_new_game(p, MD.castles[0].castle_id)
	await process_frame
	print("[rangos]")
	p.honor = 10
	p.gain_honor(-200)
	check(p.honor == -100, "el honor baja hasta −100 (%d)" % p.honor)
	p.honor = -20
	p.fame = 0
	p.add_fame(10)
	check(p.fame < 0 and p.infamy() > 0 and p.renown() == -p.fame, "con honor negativo las hazañas dan mala fama (%d)" % p.fame)
	p.honor = 30
	var f0 := p.fame
	p.add_fame(10)
	check(p.fame > f0, "con honor positivo la fama sube")
	p.fame = -150
	p.add_fame(-10)
	check(p.fame == -100, "la fama no baja de −100")
	print("[deshonra]")
	p.honor = -10
	check(not RoleProgression.check_dishonor_demotion(p), "un caballero con −10 de honor conserva su rango")
	p.honor = -60
	check(RoleProgression.check_dishonor_demotion(p), "con menos de −50 desciende")
	p.honor = -100
	check(RoleProgression.is_disgraced(p), "la deshonra total llega a −100")
	p.role = Character.Role.CABALLERO
	GM.check_disgrace()
	check(p.honor == RoleProgression.DISGRACE_HONOR_RESET and p.honor < 0, "tras tocar fondo el honor se rehace en negativo (%d)" % p.honor)
	print("[camino villano]")
	p.honor = -30
	p.fame = -100
	var base := SkillEffects.income_multiplier(CL.make_test_character("Neutro", Character.Role.CABALLERO))
	check(SkillEffects.income_multiplier(p) > base, "la mala fama hace recaudar más (%.2f > %.2f)" % [SkillEffects.income_multiplier(p), base])
	var foe := EnemyCatalog.make_enemy("bandido", 3)
	var bm := RpgBattleManager.new()
	bm.setup([p], [foe], {"seed": 1})
	var feared: int = bm.fighters[1].morale
	p.fame = 0
	var bm2 := RpgBattleManager.new()
	bm2.setup([p], [EnemyCatalog.make_enemy("bandido", 3)], {"seed": 1})
	check(feared < bm2.fighters[1].morale, "la mala fama baja la moral enemiga (%d < %d)" % [feared, bm2.fighters[1].morale])
	var honorable: Relationship = null
	for r: Relationship in RD.lords():
		if r.character != null:
			honorable = r
			break
	honorable.character.personality = Character.Personality.HONORABLE
	p.honor = -5
	check(RD.refuses_dishonored(honorable), "un señor honorable rechaza a quien no tiene honor")
	p.honor = 5
	check(not RD.refuses_dishonored(honorable), "con honor positivo sí trata contigo")
	print("[afinidad por honor]")
	var someone: Relationship = honorable
	someone.character.honor = 80
	p.honor = 80
	var close: float = RD.honor_affinity_mult(someone)
	p.honor = -80
	var far: float = RD.honor_affinity_mult(someone)
	check(is_equal_approx(close, 1.5) and far < 0.8, "honor parecido ×%.2f, opuesto ×%.2f" % [close, far])
	var cruel := 0.0
	var pious := 0.0
	for i in 40:
		cruel += CL.honor_for_personality(Character.Personality.CRUEL)
		pious += CL.honor_for_personality(Character.Personality.PIADOSO)
	check(cruel / 40.0 < 0 and pious / 40.0 > 50, "el honor de los PNJ sale de su carácter (cruel %.0f, piadoso %.0f)" % [cruel / 40.0, pious / 40.0])
	print("[eventos de reputación]")
	var REP = root.get_node("ReputationEvents")
	p.honor = -40
	p.fame = -60
	for k in ["asesinato", "villano"]:
		var e: Dictionary = REP.make_event(k)
		check(e.get("reputation", "") == k and e.options.size() >= 2, "evento «%s»: %s" % [k, e.get("title", "—")])
	check(REP.make_event("heroe").is_empty(), "un villano no recibe eventos de héroe")
	p.honor = 60
	p.fame = 50
	var h: Dictionary = REP.make_event("heroe")
	check(h.get("reputation", "") == "heroe", "un héroe famoso: %s" % h.get("title", "—"))
	GM.pending_event = {}
	GM.queue_event(h)
	var txt: String = GM.resolve_pending_event(0)
	check(not txt.is_empty() and GM.pending_event.is_empty(), "se resuelve como un evento normal")
	var opp: Relationship = null
	for r: Relationship in RD.relations:
		if r.character != null and r.kind == Relationship.Kind.CORTESANO and RD.in_area(r):
			opp = r
			break
	opp.character.honor = -70
	p.honor = 70
	var c: Dictionary = REP.make_event("conflicto")
	check(c.get("reputation", "") == "conflicto" and c.get("duel_with", "") != "", "honor opuesto: %s con %s" % [c.get("title", "—"), c.get("speaker", "—")])
	print("FALLAS: %d" % fails if fails else "TODO OK")
	quit(1 if fails else 0)
