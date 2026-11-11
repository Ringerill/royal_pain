extends SceneTree
# Tratados propuestos por la IA, divorcio y bodas entre PNJ (prueba compacta).
#   <godot>_console.exe --headless --path . --script tests/treaty_marriage_test.gd

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
	var TD = root.get_node("TreatyData")
	var CL = load("res://scripts/resources/character_loader.gd")
	var p: Character = CL.make_test_character("Sir Tratado", Character.Role.NOBLEZA_ALTA)
	p.gold = 500
	GM.start_new_game(p, MD.castles[0].castle_id)
	await process_frame
	var foreign: Array = RD.lords().filter(func(r): return r.kingdom != GM.player_kingdom)
	var lord: Relationship = foreign[0]
	print("[tratados]")
	for r in RD.lords():
		r.affinity = 0
		r.at_war = false
		r.allied = false
	lord.at_war = true
	lord.affinity = -10
	var offer: Dictionary = TD.make_offer()
	check(offer.get("treaty", {}).get("kind", "") == "peace" and offer.target == lord.person_name, "un enemigo ofrece la paz")
	GM.pending_event = {}
	GM.queue_event(offer)
	GM.resolve_pending_event(0, lord)
	check(not lord.at_war, "aceptar la paz termina la guerra")
	lord.affinity = 60
	offer = TD.make_offer()
	check(offer.get("treaty", {}).get("kind", "") == "alliance", "un señor amistoso ofrece alianza")
	GM.pending_event = {}
	GM.queue_event(offer)
	GM.resolve_pending_event(0, lord)
	check(lord.allied, "aceptar la alianza la sella")
	lord.allied = false
	lord.affinity = -50
	var forced := false
	for k in MD.castles:   # su reino más fuerte que el tuyo
		if k.kingdom != lord.kingdom and k.kingdom != GM.player_kingdom and not forced:
			k.kingdom = lord.kingdom
			forced = true
	for k in MD.castles:
		if k.kingdom != lord.kingdom and k.kingdom != GM.player_kingdom:
			k.kingdom = lord.kingdom
	offer = TD.make_offer()
	check(offer.get("treaty", {}).get("kind", "") == "tribute", "un reino fuerte y hostil exige tributo")
	GM.pending_event = {}
	GM.queue_event(offer)
	GM.resolve_pending_event(1, lord)
	check(lord.at_war, "negarse al tributo trae la guerra")
	var saved: Dictionary = TD.save_state()
	TD.load_state(saved)
	check(TD.save_state() == saved, "se guarda el enfriamiento")
	print("[divorcio]")
	var home_lords: Array = RD.lords().filter(func(r): return r.kingdom == GM.player_kingdom)
	lord = home_lords[0]   # la mano se pide en persona: un señor de tu reino
	lord.at_war = false
	lord.affinity = 80
	var reason: String = RD.propose_marriage(lord)
	var spouse: Relationship = RD.get_relation(RD.spouse_name)
	check(RD.is_married() and spouse != null, "boda política (%s)" % reason.left(40))
	GM.actions_remaining = 3
	var honor := p.honor
	var aff := lord.affinity
	var txt: String = RD.divorce(spouse)
	check(not RD.is_married() and spouse.kind == Relationship.Kind.CORTESANO, "el divorcio disuelve el matrimonio")
	check(p.honor < honor and lord.affinity < aff and not lord.allied, "cuesta honor y rompe la alianza con su casa")
	print("[bodas entre PNJ]")
	var news := ""
	for i in 5:
		news = RD.try_npc_marriage(true)
		if not news.is_empty():
			break
	check(not news.is_empty(), "dos personajes del mundo se casan (%s)" % news.left(60))
	var a: String = RD.npc_marriages.keys()[0]
	var b: String = RD.npc_spouse_of(a)
	check(RD.npc_spouse_of(b) == a, "el matrimonio queda en ambos sentidos")
	check(not RD.courtable(RD.get_relation(a)), "a un casado no se le corteja")
	var st: Dictionary = JSON.parse_string(JSON.stringify(RD.save_state()))
	RD.npc_marriages.clear()
	RD.load_state(st)
	check(RD.npc_spouse_of(a) == b, "se guarda y se carga")
	print("[trono]")
	var AD = root.get_node("AchievementData")
	var liege: Relationship = RD.get_relation(RD.liege_name)
	var peers: Array = RD.lords().filter(func(r): return r.kingdom == GM.player_kingdom and r.person_name != RD.liege_name)
	check(liege != null, "hay rey a quien disputar la corona (%s, %d señores más)" % [RD.liege_name, peers.size()])
	p.role = Character.Role.DUQUE
	p.honor = 70
	GM.actions_remaining = 3
	for r in peers:
		r.affinity = -40
	var claim: String = RD.claim_throne()
	check(RD.civil_war_against == liege.person_name and liege.at_war, "sin apoyos: guerra civil")
	var king_castles: Array = MD.castles.filter(func(c): return c.owner_name == liege.person_name)
	check(not king_castles.is_empty() and RD.is_rebel_target(king_castles[0]), "los castillos del rey son atacables aunque sean de tu reino")
	var AR = root.get_node("ArmyData")
	var home = MD.get_castle_by_id(GM.home_castle_id)
	var royal_army = AR.create_army(liege.person_name, king_castles[0].kingdom, 30, king_castles[0].castle_id)
	check(AR.is_hostile(royal_army, home), "en guerra civil, el ejército del rey ataca tu castillo (no se une a tu guarnición)")
	AR.disband_army(royal_army)
	for c in king_castles:
		c.owner_name = p.full_name()
	var won: String = RD.on_player_conquered(liege.person_name)
	check(p.role == Character.Role.REGENTE and RD.civil_war_against.is_empty(), "tomar sus castillos te corona")
	print("[finales del Regente]")
	AD.ending_done = ""
	AD.reign_start = AD.NOT_REIGNING
	AD.check_endings()
	check(AD.reign_start != AD.NOT_REIGNING and AD.ending_done.is_empty(), "empieza a contar el reinado")
	AD.reign_start = GM.months_elapsed() - AD.REIGN_MONTHS
	p.honor = 80
	var end: Dictionary = AD.check_endings()
	check(end.get("id", "") == AD.ENDING_REIGN, "10 años sin perder castillos: «Una corona en paz»")
	AD.ending_done = ""
	AD.pending_ending = {}
	var heir := Character.new()
	heir.first_name = "Heredero"
	heir.role = Character.Role.REGENTE
	root.get_node("DynastyData").heir_succeeded.emit(Character.Role.REGENTE, heir)
	check(AD.ending_done == AD.ENDING_DYNASTY and not AD.pending_ending.is_empty(), "el heredero hereda la corona: final de dinastía")
	print("FALLAS: %d" % fails if fails else "TODO OK")
	quit(1 if fails else 0)
