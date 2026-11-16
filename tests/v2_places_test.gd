extends SceneTree
# Rediseño v2, fase 5: escenas de lugar, expresiones, encargos y la pantalla de ciudad (novela visual).
#   <godot>_console.exe --headless --path . --script tests/v2_places_test.gd

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
	var CD = root.get_node("ContractData")
	var CL = load("res://scripts/resources/character_loader.gd")
	var p: Character = CL.make_test_character("Sir Andante", Character.Role.CABALLERO)
	p.portrait = load("res://assets/portraits/Characters/Male/male1.png")
	GM.start_new_game(p, MD.castles[0].castle_id)
	await process_frame

	print("[escenas y expresiones]")
	var all_ok := true
	for pl in PlaceArt.VARIANT_PLACES + PlaceArt.SINGLE_PLACES:
		all_ok = all_ok and PlaceArt.scene(pl) != null
	check(all_ok, "todos los lugares tienen escena")
	check(PlaceArt.scene("city_outside", "_winter") != PlaceArt.scene("city_outside"), "la escena cambia con la estación")
	check(PlaceArt.scene("bridge", "", true).resource_path.ends_with("bridge_night.png"), "y de noche")
	var happy := PlaceArt.expression(p, "alegre")
	var angry := PlaceArt.expression(p, "enfado")
	check(happy is AtlasTexture and angry is AtlasTexture and happy.region != angry.region, "10 expresiones por retrato (alegre ≠ enfado)")
	check(PlaceArt.tone("¡Gracias, amigo!") == "alegre" and PlaceArt.tone("Lo siento mucho.") == "triste", "el tono de la frase elige la expresión")

	print("[encargos]")
	var board: Array = CD.board(J.kingdom, 0)
	check(board.size() >= 3, "el tablón ofrece encargos (%d)" % board.size())
	var c: Dictionary = board.filter(func(x): return x.kind in ["entregar"]).front() if board.any(func(x): return x.kind == "entregar") else board[0]
	check(CD.accept(c) and CD.active.size() == 1 and not CD.board(J.kingdom, 0).any(func(x): return x.uid == c.uid), "aceptar lo saca del tablón")
	var gold0: int = p.gold
	var r: Dictionary = CD.on_arrived(J.kingdom, int(c.target))
	if r.has("fight"):
		check(r.fight.get("contract_uid", "") == c.uid, "al llegar hay pelea ligada al encargo")
		var t: String = CD.resolve_fight(c.uid, true)
		check(CD.active.is_empty() and p.gold == gold0 + int(c.gold), "ganar la pelea cumple el encargo")
	else:
		check(CD.active.is_empty() and p.gold == gold0 + int(c.gold), "al llegar al destino se cobra (%s)" % c.kind)
	var c2: Dictionary = CD.board(J.kingdom, 0)[0]
	CD.accept(c2)
	var fame0: int = p.fame
	J.hours += J.HOURS_PER_DAY * (int(c2.days) + 1)
	var lapsed: Array = CD.check_deadlines()
	check(lapsed.size() == 1 and CD.active.is_empty() and p.fame == fame0 - CD.FAIL_FAME, "si vence el plazo se pierde fama")
	var night: Array = CD.board(J.kingdom, 0, true)
	check(night.size() == 1 and night[0].kind == "turbio", "de noche, el callejón ofrece un turbio")
	var st: Dictionary = CD.save_state()
	CD.reset()
	CD.load_state(st)
	check(CD.failed == 1 and CD.completed == 1, "se guarda y se carga")

	print("[ciudad]")
	J.at = 0
	J.hours = floor(J.hours / J.HOURS_PER_DAY) * J.HOURS_PER_DAY + 12.0   # mediodía
	p.gold = 5000
	change_scene_to_file("res://scenes/place/place.tscn")
	await create_timer(0.5).timeout
	var sc = current_scene
	check(sc != null and sc.buildings().size() >= 6, "la capital tiene sus edificios (%d)" % sc.buildings().size())
	sc.enter("taberna")
	await process_frame
	check(sc._inside.visible and sc._npc.texture != null and sc._options.get_child_count() >= 3, "la taberna se ve como novela visual")
	sc.enter("herreria")
	var w: Equipment = sc._weapon()
	var lvl0 := int(GearCatalog.entry(w.equipment_name).gear.level) if w != null and GearCatalog.is_gear(w.equipment_name) else -1
	if lvl0 < 0:   # el personaje de prueba trae arma antigua: le damos una del catálogo nuevo
		for it: Equipment in root.get_node("GameData").equipment_catalog:
			if it.equipment_name == "Espada Mellada":
				p.equip(it.duplicate())
		sc.enter("herreria")
		w = sc._weapon()
		lvl0 = 1
	var up_btn: Button = null
	for b in sc._options.get_children():
		if b is Button and b.text.begins_with("Mejorar"):
			up_btn = b
	check(up_btn != null, "la herrería ofrece mejorar el arma")
	if up_btn != null:
		up_btn.pressed.emit()
		check(int(GearCatalog.entry(sc._weapon().equipment_name).gear.level) == lvl0 + 1, "mejorar sube un nivel el arma")
	sc.enter("casa")
	var buy: Button = null
	for b in sc._options.get_children():
		if b is Button and b.text.begins_with("Comprarla"):
			buy = b
	buy.pressed.emit()
	check(sc.owns_house(), "se puede comprar casa")
	p.energy = 10
	sc.enter("casa")
	for b in sc._options.get_children():
		if b is Button and b.text.begins_with("Dormir"):
			b.pressed.emit()
	check(p.energy == p.max_energy, "y dormir en ella")
	print("FALLAS: %d" % fails if fails else "TODO OK")
	quit(1 if fails else 0)
