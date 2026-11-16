extends SceneTree
# Rediseño v2, fase 1: datos (mapas de reino, personalidades, vías, rangos, campos nuevos del personaje).
#   <godot>_console.exe --headless --path . --script tests/v2_data_test.gd

var fails := 0

func check(cond: bool, what: String) -> void:
	print(("  ok  " if cond else "  FALLA ") + what)
	if not cond:
		fails += 1

func _initialize() -> void:
	print("[mapas de reino]")
	var all_ok := true
	for k in KingdomEnums.Kingdom.values():
		if not KingdomMaps.DATA.has(k):
			check(false, "el reino %d tiene mapa" % k)
			continue
		var ns := KingdomMaps.nodes(k)
		var es := KingdomMaps.edges(k)
		var ok: bool = ns.size() >= 8 and ns.size() <= 12 and ns[0].type == "capital"
		ok = ok and ns.all(func(n): return n.pos.x > 0.0 and n.pos.x < 1.0 and n.pos.y > 0.0 and n.pos.y < 1.0)
		ok = ok and ns.all(func(n): return KingdomMaps.TYPE_ICONS.has(n.type))
		ok = ok and KingdomMaps._components(ns.size(), es).size() == 1
		ok = ok and ResourceLoader.exists(KingdomMaps.map_path(k))
		ok = ok and ns.filter(func(n): return n.type == "capital").size() == 1
		if not ok:
			all_ok = false
			print("    reino %d: %d lugares, %d caminos" % [k, ns.size(), es.size()])
	check(all_ok, "12 reinos con mapa, 8–12 lugares, una capital y todo conectado")
	var icons_ok := KingdomMaps.TYPE_ICONS.values().all(func(i): return ResourceLoader.exists(KingdomMaps.ICON_DIR % i))
	check(icons_ok, "cada tipo de lugar tiene su icono")
	var ports := KingdomEnums.Kingdom.values().filter(func(k): return KingdomMaps.has_port(k)).size()
	check(ports >= 10, "casi todos los reinos tienen puerto (%d)" % ports)
	check(KingdomMaps.travel_hours(KingdomEnums.Kingdom.HIELO, 0, 1) >= 1.0, "viajar entre lugares lleva horas")

	print("[personalidades, vías y rangos]")
	check(PersonaCatalog.Persona.size() == 9, "9 personalidades")
	var tot_ok := true
	for p in PersonaCatalog.Persona.values():
		var t := 0
		for v in PersonaCatalog.STATS[p].values():
			t += int(v)
		if t < 1 or t > 2 or PersonaCatalog.TREE[p].size() != 4:
			tot_ok = false
	check(tot_ok, "cada personalidad suma +1 o +2 y tiene árbol de 4")
	check(is_equal_approx(PersonaCatalog.affinity_factor(PersonaCatalog.Persona.GENTIL, PersonaCatalog.Persona.INGENUO), 1.35), "Gentil congenia con Ingenuo (+35 %)")
	check(PersonaCatalog.affinity_factor(PersonaCatalog.Persona.IRASCIBLE, PersonaCatalog.Persona.IRASCIBLE) < 1.0, "dos irascibles chocan")
	check(ViaCatalog.Via.size() == 8 and ViaCatalog.DATA.size() == 8, "8 vías con sus datos")
	check(RankCatalog.max_soldiers(RankCatalog.Rank.CABALLERO, 10) == 45, "caballero con Liderazgo 10 lleva 45 soldados")

	print("[personaje]")
	var c := Character.new()
	c.role = Character.Role.NOBLEZA_ALTA
	c.personality = Character.Personality.CRUEL
	check(c.rank_v2() == RankCatalog.Rank.NOBLE, "rango deducido del rol antiguo")
	check(c.persona_v2() == PersonaCatalog.Persona.IRASCIBLE, "personalidad deducida de la antigua")
	c.spend_energy(85)
	check(c.energy == 15 and c.is_exhausted(), "gastar energía; por debajo de 20, agotado")
	c.restore_energy(500)
	check(c.energy == c.max_energy, "la energía no pasa del máximo")
	print("FALLAS: %d" % fails if fails else "TODO OK")
	quit(1 if fails else 0)
