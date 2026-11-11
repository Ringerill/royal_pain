extends SceneTree
# Tipos de daño de las técnicas (el del arma salvo excepciones), conocimiento del enemigo (IntelData)
# e iconos de habilidades/tipos de daño. Ejecutar:
#   <godot>_console.exe --headless --path . --script tests/intel_icons_test.gd

const EXCEPTIONS := ["ase_disparo", "pcob_piedras", "ahum_honda", "ase_dardos", "tan_golpe_escudo", "tan_empujon"]

var fails := 0

func check(cond: bool, what: String) -> void:
	print(("  ok  " if cond else "  FALLA ") + what)
	if not cond:
		fails += 1

func _initialize() -> void:
	_run.call_deferred()

func _char(ft: int, name_: String) -> Character:
	var c := Character.new()
	c.first_name = name_
	c.fighter_type = ft
	c.level = 3
	for a in ["combat", "defense", "strategy", "leadership", "charisma", "agility"]:
		c.set(a, 6)
	return c

func _run() -> void:
	var intel: Node = root.get_node("IntelData")
	var DT := RpgStats.DamageType
	var AF := RpgStats.Affinity
	print("[tipo de daño de las técnicas]")
	var fixed := []
	for n: Dictionary in SkillTreeCatalog.all_nodes():
		if int(n.get("dt", -1)) >= 0:
			fixed.append(n.id)
	fixed.sort()
	var want := EXCEPTIONS.duplicate()
	want.sort()
	check(fixed == want, "solo las excepciones fijan el tipo (%s)" % ", ".join(fixed))
	# Un duelista con espada (Tajo) usa «Estocada al corazón» como Tajo.
	var due := _char(CharacterEnums.FighterType.DUELISTA, "Espadachín")
	var sword := Equipment.new()
	sword.equipment_name = "Espada Larga"
	sword.slot = "Arma"
	due.equipment.append(sword)
	var foe := EnemyCatalog.make_enemy("soldado", 3)
	var bm := RpgBattleManager.new()
	var log := []
	bm.setup([due], [foe], {"seed": 5, "intel_hook": func(k, c, s, dt, aff): log.append([k, c, dt, aff])})
	var f: RpgBattleManager.Fighter = bm.fighters[0]
	check(int(f.s.weapon) == DT.TAJO, "la espada da Tajo")
	var info := {"good": 0, "bad": 0, "hits": []}
	var n := SkillTreeCatalog.node("due_corazon").duplicate(true)
	n["pow"] = 1.0
	bm.rng.seed = 1
	bm._technique(f, n, bm.fighters[1], info)
	var landed: Array = info.hits.filter(func(h): return h.hit)
	if landed.is_empty():   # si falló, se repite con otra semilla
		bm.rng.seed = 99
		bm._technique(f, n, bm.fighters[1], info)
		landed = info.hits.filter(func(h): return h.hit)
	check(not landed.is_empty() and log.any(func(e): return e[0] == "aff" and e[2] == DT.TAJO), "«Estocada al corazón» golpea con Tajo (tipo del arma)")
	print("[descubrimientos]")
	intel.reset()
	var s_foe: Dictionary = bm.fighters[1].s
	var v: Dictionary = intel.view(foe, s_foe)
	check(v.weapon == -1 and v.armor == -1 and v.aff == [-1, -1, -1, -1], "al principio no se sabe nada")
	intel.record("aff", foe, s_foe, DT.TAJO, RpgStats.affinity(DT.TAJO, s_foe.armor, s_foe.shield))
	v = intel.view(foe, s_foe)
	check(v.aff[DT.TAJO] == RpgStats.affinity(DT.TAJO, s_foe.armor, s_foe.shield) and v.aff.count(-1) == 3 and v.weapon == -1, "golpearle revela solo ese tipo")
	intel.record("weapon", foe, s_foe, int(s_foe.weapon), -1)
	check(intel.view(foe, s_foe).weapon == int(s_foe.weapon), "recibir su golpe revela su tipo de daño")
	var foe2 := EnemyCatalog.make_enemy("soldado", 7)
	for m in [EnemyCatalog.META_WEAPON, RpgStats.META_ARMOR, RpgStats.META_DAMAGE]:   # mismo equipo que foe
		foe2.set_meta(m, foe.get_meta(m))
	check(intel.view(foe2, RpgStats.compute(foe2)).weapon == int(s_foe.weapon), "los genéricos se recuerdan por tipo y equipo")
	var other := EnemyCatalog.make_enemy("soldado", 7)
	other.set_meta(RpgStats.META_ARMOR, (int(foe.get_meta(RpgStats.META_ARMOR)) + 1) % 4)
	check(intel.view(other, RpgStats.compute(other)).aff.count(-1) == 4, "otro equipo no comparte lo sabido")
	intel.record("all", foe, s_foe)
	v = intel.view(foe, s_foe)
	check(v.armor == int(s_foe.armor) and not -1 in v.aff, "analizar lo revela todo")
	# Un personaje con nombre que cambia de armadura: lo sabido deja de valer.
	var lord := _char(CharacterEnums.FighterType.TANQUE, "Señor")
	var s_lord := RpgStats.compute(lord)
	intel.record("all", lord, s_lord)
	var s_changed := s_lord.duplicate()
	s_changed.armor = (int(s_lord.armor) + 1) % 4
	v = intel.view(lord, s_changed)
	check(v.armor == -1 and intel.view(_char(CharacterEnums.FighterType.TANQUE, "Otro"), s_lord).armor == -1, "si cambia de armadura se olvida; otro personaje no hereda lo sabido")
	# Estados temporales no ensucian lo aprendido (se guarda la afinidad base).
	var bm2 := RpgBattleManager.new()
	var log2 := []
	var heavy := EnemyCatalog.make_enemy("infanteria_pesada", 3)
	heavy.set_meta(RpgStats.META_ARMOR, RpgStats.ArmorClass.PLACAS)   # el equipo es al azar: se fija Placas
	bm2.setup([due], [heavy], {"seed": 2, "intel_hook": func(k, c, s, dt, aff): log2.append([k, dt, aff])})
	bm2._add_status(bm2.fighters[1], "analizado", 2, bm2.fighters[0])
	check(log2.size() == 1 and log2[0][0] == "all", "el estado «analizado» avisa de un análisis completo")
	var info2 := {"good": 0, "bad": 0, "hits": []}
	for i in 6:
		bm2._strike(bm2.fighters[0], bm2.fighters[1], 1.0, DT.TAJO, {}, info2, false)
	var affs: Array = log2.filter(func(e): return e[0] == "aff").map(func(e): return e[2])
	check(not affs.is_empty() and affs.all(func(a): return a == AF.RESISTE), "con «analizado» se aprende la afinidad base (Placas resiste Tajo)")
	print("[guardado]")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(intel.save_state()))
	intel.reset()
	intel.load_state(saved)
	check(intel.view(foe, s_foe).armor == int(s_foe.armor), "se guarda y se carga (JSON)")
	print("[iconos]")
	var missing := []
	var per_cat := [0, 0, 0, 0, 0, 0, 0]
	for nd: Dictionary in SkillTreeCatalog.all_nodes():
		per_cat[SkillIcons.category_of(nd.id)] += 1
		if SkillIcons.texture(SkillIcons.node_icon_name(nd.id, due)) == null:
			missing.append(nd.id)
	check(missing.is_empty(), "todas las habilidades tienen icono (%d sin icono)" % missing.size())
	var cat_txt := []
	for i in per_cat.size():
		cat_txt.append("%s %d" % [SkillIcons.CAT_NAMES[i], per_cat[i]])
	check(not per_cat.has(0), "las 7 categorías se usan (%s)" % ", ".join(cat_txt))
	# El icono de una técnica de daño sigue al arma; las excepciones conservan el suyo.
	var mace_user := _char(CharacterEnums.FighterType.DUELISTA, "Mazo")
	var mace := Equipment.new()
	mace.equipment_name = "Maza de Armas"
	mace.slot = "Arma"
	mace_user.equipment.append(mace)
	check(SkillIcons.node_icon_name("due_corazon", due) == SkillIcons.DAMAGE[DT.TAJO] and SkillIcons.node_icon_name("due_corazon", mace_user) == SkillIcons.DAMAGE[DT.CONTUNDENTE], "«Estocada al corazón»: espada con espada, maza con maza")
	check(SkillIcons.node_icon_name("ase_disparo", due) == SkillIcons.DAMAGE[DT.PROYECTIL], "«Disparo» lleva siempre el arco")
	check(SkillIcons.category_of("est_analizar") == SkillIcons.Cat.DEBILITACION and SkillIcons.category_of("def_vendaje") == SkillIcons.Cat.CURACION, "Analizar = Debilitación; Vendaje = Curación")
	var fixed_ok := true
	for nm in SkillIcons.DAMAGE + SkillIcons.ARMOR + SkillIcons.CAT_ICONS + [SkillIcons.SHIELD, SkillIcons.UNKNOWN, SkillIcons.DAMAGE_GENERIC]:
		fixed_ok = fixed_ok and SkillIcons.texture(nm) != null
	check(fixed_ok, "iconos de tipos de daño, armaduras y desconocido")
	var tex := SkillIcons.texture(SkillIcons.DAMAGE[0])
	check(tex != null and tex.get_width() <= 128, "los SVG se importan pequeños (%d px)" % (tex.get_width() if tex else -1))
	print("[pantalla de combate]")
	intel.reset()
	var RS = load("res://scenes/rpg_battle/rpg_battle.gd")
	RS.test_delay = 0.0
	var scene: Node = load("res://scenes/rpg_battle/rpg_battle.tscn").instantiate()
	scene.side_a = [due]
	scene.side_b = [EnemyCatalog.make_enemy("bandido", 2)]
	scene.player_character = due
	root.add_child(scene)
	await create_timer(0.3).timeout
	var card: Dictionary = {}
	for fi in scene.mgr.fighters:
		if fi.side == 1:
			card = scene._cards[fi]
	check(card.has("intel") and card.intel.get_child_count() == 6, "la tarjeta del rival muestra arma + separador + 4 tipos")
	check("Arma: ?" in str(card.root.tooltip_text), "el texto del rival oculta su arma al principio")
	scene.queue_free()
	await process_frame
	print("FALLAS: %d" % fails if fails else "TODO OK")
	quit(1 if fails else 0)
