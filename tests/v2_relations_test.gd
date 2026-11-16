extends SceneTree
# Rediseño v2, fase 7: presencia por lugar, hermandad, afinidad por personalidad, vías (metas,
# mecánicas, cambio por los actos), colección y prisioneros.
#   <godot>_console.exe --headless --path . --script tests/v2_relations_test.gd

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
	var CD = root.get_node("ContractData")
	var CL = load("res://scripts/resources/character_loader.gd")
	var PI = load("res://scripts/resources/personal_interactions.gd")
	var p: Character = CL.make_test_character("Sir Justo", Character.Role.CABALLERO)
	p.via = ViaCatalog.Via.BENEVOLENTE
	p.persona = PersonaCatalog.Persona.GENTIL
	GM.start_new_game(p, MD.castles[0].castle_id)
	await process_frame

	print("[presencia]")
	var court: Array = RD.courtiers(J.kingdom).filter(func(r): return RD.sociable(r))
	check(not court.is_empty(), "hay gente en el reino")
	var r: Relationship = court[0]
	J.at = RD.node_of(r)
	check(RD.person_present(r) and r in RD.people_here(), "está en su lugar y la ves allí")
	var other := -1
	for n in J.nodes():
		if n.index != RD.node_of(r):
			other = n.index
	J.at = other
	check(not RD.person_present(r), "en otro lugar no la tienes delante")
	RD.road_company = r.person_name
	check(RD.person_present(r), "salvo que la cruces en el camino")
	RD.road_company = ""

	print("[hermandad y afinidad]")
	J.at = RD.node_of(r)
	r.affection = 85
	r.romance = false
	var opts: Array = PI.for_relation(r).map(func(o): return o[0])
	check("hermandad" in opts, "con mucha intimidad se puede jurar hermandad")
	GM.actions_remaining = 3 if "actions_remaining" in GM else 0
	PI.perform(r, "hermandad")
	check(r.sworn, "y queda jurada")
	r.character.persona = PersonaCatalog.Persona.INGENUO
	var g_like: int = PI._gain(r, 10)
	r.character.persona = PersonaCatalog.Persona.EGOCENTRICO
	var g_clash: int = PI._gain(r, 10)
	check(g_like > g_clash, "una Gentil congenia más con un Ingenuo que con un Egocéntrico (%d > %d)" % [g_like, g_clash])

	print("[vías]")
	for i in 14:
		VD.record("rescue", "rescues")
	check(not VD.goal_reached and int(VD.progress()[0]) == 14, "el contador de la meta avanza (14/15)")
	var t: String = VD.record("rescue", "rescues")
	check(VD.goal_reached and GM.victory_achieved and "Meta" in t, "a los 15 grupos, la meta del Benevolente da la victoria")
	var g0: int = p.gold
	VD.chore()
	check(p.gold > g0 and int(VD.counts.chores) == 1, "las faenas dan oro")
	VD.extort()
	VD.extort()
	for i in 20:   # superar los 45 puntos de Benevolente por más de 15
		VD.record("raid", "raids")
	check(p.via == ViaCatalog.Via.VILLANO, "saquear y extorsionar mucho te lleva a la vía Villano")
	p.gold = 500
	p.via = ViaCatalog.Via.JUSTICIERO
	CD._boards.clear()
	check(CD.board(J.kingdom, 0).any(func(c): return c.kind == "recompensa"), "el justiciero siempre encuentra un «se busca» en el tablón")

	print("[colección]")
	var c0: int = p.combat
	for i in 10:
		VD.note_weapon(GearCatalog.weapon_name("lanza", i + 1))
	check(p.combat == c0 + 1 and VD.collection_bonus.has("lanza"), "completar las 10 lanzas da +1 de Ataque")

	print("[prisioneros]")
	VD.pending_prisoner = "Cabecilla bandido"
	var s0: int = p.soldiers
	var txt: String = VD.resolve_prisoner("reclutar")
	check(p.soldiers == s0 + VD.RECRUIT_SOLDIERS and VD.pending_prisoner.is_empty(), "reclutar al prisionero suma soldados")
	VD.pending_prisoner = "Otro"
	var gold1: int = p.gold
	VD.resolve_prisoner("esclavizar")
	check(p.gold == gold1 + VD.ENSLAVE_GOLD, "venderlo da oro (y quita fama)")
	var st: Dictionary = VD.save_state()
	VD.reset()
	VD.load_state(st)
	check(VD.goal_reached and VD.collection_bonus.has("lanza") and int(VD.counts.rescues) == 15, "se guarda y se carga")
	print("FALLAS: %d" % fails if fails else "TODO OK")
	quit(1 if fails else 0)
