extends SceneTree
# Rediseño v2, fase 4: equipo nuevo (armas, armaduras, accesorios), objetos, árboles y creación.
#   <godot>_console.exe --headless --path . --script tests/v2_gear_test.gd

var fails := 0

func check(cond: bool, what: String) -> void:
	print(("  ok  " if cond else "  FALLA ") + what)
	if not cond:
		fails += 1

func _initialize() -> void:
	_run.call_deferred()

func _item(n: String) -> Equipment:
	for e: Equipment in root.get_node("GameData").equipment_catalog:
		if e.equipment_name == n:
			return e.duplicate()
	return null

func _run() -> void:
	var GD = root.get_node("GameData")
	print("[catálogo]")
	var all: Array = GearCatalog.entries()
	var weapons := all.filter(func(e): return e.slot == "Arma")
	var shields := all.filter(func(e): return e.slot == "Escudo")
	var armors := all.filter(func(e): return e.slot == "Armadura")
	var accs := all.filter(func(e): return e.slot == "Accesorio")
	check(weapons.size() == 50 and shields.size() == 10, "5 tipos de arma y escudos, 10 de cada (7 de progresión + 3 definitivas)")
	check(armors.size() == 15 and accs.size() == 45, "15 armaduras y 45 accesorios (30 por atributo + 15 únicos)")
	var names := {}
	for e in all:
		names[e.name] = true
	check(names.size() == all.size(), "sin nombres repetidos")
	var icons_ok := all.all(func(e): return GearCatalog.icon(e.name) != null)
	check(icons_ok, "cada pieza tiene su dibujo")
	var prog := true
	for t in GearCatalog.WEAPON_TYPES:
		var atk := []
		for i in 7:
			atk.append(int(GearCatalog.entry(GearCatalog.weapon_name(t, i + 1)).mods.get("combat", 0)))
		for i in 6:
			prog = prog and atk[i + 1] >= atk[i]
	check(prog, "las 7 primeras armas de cada tipo van a mejor")
	check(GearCatalog.entry("Espada del Rey").get("focus") == "defensa" and GearCatalog.entry("Hoja Alada").get("focus") == "agilidad",
		"las definitivas tienen enfoque (agilidad, ataque, defensa)")
	var in_catalog: int = GD.equipment_catalog.filter(func(e: Equipment): return GearCatalog.is_gear(e.equipment_name)).size()
	check(in_catalog == all.size(), "todo está en el catálogo de GameData (%d)" % in_catalog)
	check(not GD.equipment_catalog.any(func(e: Equipment): return e.equipment_name == "Espada Larga"), "las armas antiguas ya no se venden")

	print("[combate]")
	var CL = load("res://scripts/resources/character_loader.gd")
	var c: Character = CL.make_test_character("Prueba", Character.Role.SOLDADO)
	c.equipment.clear()
	c.equip(_item("Lanza de Caballero"))
	check(RpgStats.weapon_class(c) == RpgStats.WeaponClass.LANZA and RpgStats.weapon_type(c) == RpgStats.DamageType.ESTOCADA, "la lanza es clase Lanza y da Estocada")
	check(SkillTreeCatalog.weapon_tree_of(c) == "w_asta", "y usa el árbol de lanza")
	c.equip(_item("Escudo de Placas"))
	var s := RpgStats.compute(c)
	check(s.shield and float(s.block) > 0.0, "el escudo da bloqueo (%.2f)" % float(s.block))
	c.equip(_item("Mandoble de Guerra"))
	check(RpgStats.weapon_class(c) == RpgStats.WeaponClass.MANDOBLE and not RpgStats.compute(c).shield, "con mandoble el escudo no cuenta")
	c.equip(_item("Arnés de Batalla"))
	check(RpgStats.armor_class(c) == RpgStats.ArmorClass.PLACAS, "las armaduras nuevas tienen su clase")
	c.equip(_item("Brazal de Acero"))
	c.equip(_item("Fíbula Dorada"))
	var acc := c.equipment.filter(func(e: Equipment): return e.slot == "Accesorio")
	check(acc.size() == 2, "se llevan dos accesorios")
	var third: Equipment = c.equip(_item("Brújula de Plata"))
	check(third != null and c.equipment.filter(func(e: Equipment): return e.slot == "Accesorio").size() == 2, "un tercero sustituye a uno")

	print("[objetos]")
	var v2 := ConsumableCatalog.ITEMS.keys().filter(func(id): return ConsumableCatalog.ITEMS[id].get("v2", false))
	check(v2.size() == 18 and v2.all(func(id): return ConsumableCatalog.icon_texture(id) != null), "18 objetos nuevos con su dibujo")
	var a: Character = CL.make_test_character("A", Character.Role.SOLDADO)
	var b: Character = CL.make_test_character("B", Character.Role.SOLDADO)
	var bm := RpgBattleManager.new()
	bm.setup([a, b], [CL.make_test_character("Rival", Character.Role.SOLDADO)], {"bag": {"despertar2": 1, "antidoto": 1, "bomba": 1}, "seed": 1})
	var fa: RpgBattleManager.Fighter = bm.fighter_of(a)
	var fb: RpgBattleManager.Fighter = bm.fighter_of(b)
	var foe: RpgBattleManager.Fighter = bm.fighters[2]
	bm._damage(fb, 9999, null)
	fa.next_time = -1.0
	bm.next_turn()
	bm.act(fa, {"type": "objeto", "item": "despertar2", "target": fb})
	check(fb.up() and fb.hp > 0, "la Tintura de vida levanta a un caído")
	bm._add_status(fa, "veneno", 3, foe)
	fa.next_time = -1.0
	bm.current = null
	bm.next_turn()
	if bm.current == fa:
		bm.act(fa, {"type": "objeto", "item": "antidoto", "target": fa})
	check(not fa.has("veneno"), "el antídoto quita el veneno")

	print("[árboles y creación]")
	var p := Character.new()
	p.persona = PersonaCatalog.Persona.IRASCIBLE
	check(Array(SkillTreeCatalog.trees_for(p)) == ["p_cruel"], "un árbol: el de su personalidad")
	check(PersonaCatalog.TO_OLD.size() == 9 and ViaCatalog.TO_ALIGNMENT.size() == 8, "personalidad y vía guardan su equivalente antiguo")
	check(GD.ContentCatalog.CREATION_WEAPONS.values().all(func(n): return int(GearCatalog.entry(n).gear.level) == 1), "al crear, solo armas de nivel 1")
	print("FALLAS: %d" % fails if fails else "TODO OK")
	quit(1 if fails else 0)
