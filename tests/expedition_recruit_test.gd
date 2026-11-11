extends SceneTree
# Expediciones por pasos (solo el primero gasta acción; combate, botín o rescate) y reclutar o
# encerrar a enemigos genéricos (pasan a ser personas con nombre).
#   <godot>_console.exe --headless --path . --script tests/expedition_recruit_test.gd

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
	var CD = root.get_node("CaptureData")
	var EX = root.get_node("ExplorationData")
	var CL = load("res://scripts/resources/character_loader.gd")
	var RR = load("res://scripts/resources/recruit_rules.gd")
	var p: Character = CL.make_test_character("Sir Explorador", Character.Role.CABALLERO)
	GM.start_new_game(p, MD.castles[0].castle_id)
	await process_frame
	EX.sites.clear()
	print("[expedición por pasos]")
	GM.actions_remaining = 2
	var site: Dictionary = EX.spawn_site("ruinas", MD.castles[0].castle_id)
	var r: Dictionary = EX.visit(site.uid, 0)   # entrar por la puerta principal
	check(r.ok and r.get("continue", false) and EX.find(site.uid).get("step", "") == "patio", "una decisión lleva al siguiente paso (patio)")
	check(GM.actions_remaining == 1, "el primer paso gasta la acción")
	r = EX.visit(site.uid, 1)   # registrar los barracones → cripta
	check(r.ok and r.continue and EX.find(site.uid).step == "cripta" and GM.actions_remaining == 1, "los pasos siguientes no gastan acciones")
	var honor := p.honor
	r = EX.visit(site.uid, 1)   # rezar y salir
	check(r.ok and not r.continue and EX.find(site.uid).is_empty() and p.honor > honor, "la última decisión termina la expedición")
	print("[rescate]")
	site = EX.spawn_site("ruinas", MD.castles[0].castle_id)
	site["step"] = "torre"
	site["started"] = true
	p.gold = 100
	r = EX.visit(site.uid, 2)   # pagar por el cautivo
	check(r.ok and r.rescue is Character and not str(r.rescue.full_name()).is_empty(), "rescatas a alguien con nombre (%s)" % (r.rescue.full_name() if r.rescue else "-"))
	var captive: Character = r.rescue
	var size_before: int = RD.retinue.size()
	var holder := Control.new()
	root.add_child(holder)
	var d = load("res://scripts/ui/recruit_dialog.gd").open(holder, captive, "rescue")
	await process_frame
	d._do_join()
	check(captive.full_name() in RD.retinue and RD.retinue.size() == size_before + 1, "se une a tu séquito")
	print("[guardado]")
	site = EX.spawn_site("campamento_bandido", MD.castles[0].castle_id)
	site["step"] = "espiado"
	site["started"] = true
	var st: Dictionary = JSON.parse_string(JSON.stringify(EX.save_state()))
	EX.load_state(st)
	check(EX.find(site.uid).get("step", "") == "espiado" and EX.find(site.uid).get("started", false), "se guarda en qué paso va")
	print("[enemigos genéricos]")
	var foe: Character = EnemyCatalog.make_enemy("soldado", 3)
	foe.set_meta(EnemyCatalog.META_WEAPON, "Espada Larga")
	foe.set_meta(RpgStats.META_ARMOR, RpgStats.ArmorClass.MALLA)
	var offers: Array = RR.offers_after_fight([foe], 1.0, 0.0)
	check(offers.size() == 1 and offers[0].mode == "join", "un genérico vencido puede querer unirse a ti")
	offers = RR.offers_after_fight([foe], 0.0, 1.0)
	check(offers.size() == 1 and offers[0].mode == "capture", "o puedes encerrarlo")
	var rel: Relationship = RR.make_person(foe, "Ramiro", "del Vado")
	var s := RpgStats.compute(foe)
	check(foe.full_name() == "Ramiro del Vado" and not RR.is_generic(foe) and RD.get_relation("Ramiro del Vado") == rel,
		"con nombre propio pasa a ser una persona del mundo")
	check(int(s.weapon) == RpgStats.DamageType.TAJO and int(s.armor) == RpgStats.ArmorClass.MALLA and foe.equipment.size() >= 2,
		"conserva su arma y armadura como equipo de verdad")
	check(RD.sociable(rel), "puedes tratar con él como con cualquiera")
	var foe2: Character = EnemyCatalog.make_enemy("bandido", 2)
	var d2 = load("res://scripts/ui/recruit_dialog.gd").open(holder, foe2, "capture")
	await process_frame
	d2._first.text = "Gil"
	d2._last.text = "Tuerto"
	d2._do_capture()
	check(CD.is_prisoner("Gil Tuerto"), "encerrado: pasa a ser tu prisionero")
	print("FALLAS: %d" % fails if fails else "TODO OK")
	quit(1 if fails else 0)
