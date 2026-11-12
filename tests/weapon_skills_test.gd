extends SceneTree
# Técnicas de arma: familias, desbloqueo por nivel, sin puntos, conversión de partidas antiguas y panel.
#   <godot>_console.exe --headless --path . --script tests/weapon_skills_test.gd

var fails := 0

func check(cond: bool, what: String) -> void:
	print(("  ok  " if cond else "  FALLA ") + what)
	if not cond:
		fails += 1

func _initialize() -> void:
	_run.call_deferred()

func _char(ft: int, lvl: int, weapon: String = "") -> Character:
	var c := Character.new()
	c.first_name = "Prueba%d" % randi()
	c.fighter_type = ft
	c.level = lvl
	for a in ["combat", "defense", "strategy", "leadership", "charisma", "agility"]:
		c.set(a, 6)
	if weapon != "":
		var e := Equipment.new()
		e.equipment_name = weapon
		e.slot = "Arma"
		c.equipment.append(e)
	return c

func _techs(c: Character) -> Array:
	return SkillTreeCatalog.available_techniques(c).map(func(n): return str(n.id))

func _run() -> void:
	var F := CharacterEnums.FighterType
	var STC := SkillTreeCatalog
	print("[familias y niveles]")
	var all_ok := true
	for tid: String in STC.WEAPON_TREES:
		var nodes := STC.nodes_of_tree(tid)
		var tiers := {}
		for n: Dictionary in nodes:
			tiers[int(n.tier)] = true
			all_ok = all_ok and n.kind == "act" and int(n.cost) == 0 and n.req.is_empty()
		all_ok = all_ok and nodes.size() >= 4 and tiers.size() == 4
	check(all_ok, "7 familias con 4 escalones, solo técnicas, sin coste ni requisitos")
	var sw1 := _char(F.BERSERKER, 1, "Espada Larga")
	var sw12 := _char(F.BERSERKER, 12, "Espada Larga")
	check(STC.weapon_tree_of(sw1) == "w_espada" and "esp_tajo" in _techs(sw1) and not "due_tendon" in _techs(sw1), "nivel 1 con espada: solo el escalón I")
	check(["esp_tajo", "due_tendon", "ber_tajo_bajo", "esp_media_luna"].all(func(i): return i in _techs(sw12)), "nivel 12: los cuatro escalones")
	var pts_before := STC.points_free(sw12)
	check(pts_before == STC.points_total(sw12), "las técnicas de arma no gastan puntos")
	var axe := _char(F.BERSERKER, 12, "Hacha de Guerra")
	check("ber_hachazo" in _techs(axe) and not "esp_tajo" in _techs(axe), "cambiar de arma cambia las técnicas (hacha)")
	check(STC.weapon_tree_of(_char(F.TANQUE, 1)) == "w_maza" and STC.weapon_tree_of(_char(F.ASESINO, 1)) == "w_estoque", "sin arma: la familia del tipo de luchador")
	check(not STC.can_learn(sw12, "esp_tajo"), "no se aprenden con puntos")
	print("[enemigos genéricos: equipo al azar]")
	var foe := EnemyCatalog.make_enemy("explorador", 8)
	var tree := STC.weapon_tree_of(foe)
	check(tree != "" and STC.weapon_ids(foe).size() == 2 and "ase_hoja" in _techs(foe), "nivel 8: técnicas de su arma hasta el escalón II (%s) y conservan su kit" % tree)
	check(STC.weapon_ids(EnemyCatalog.make_enemy("explorador", 12)).size() == 3, "desde el nivel 10 suben al escalón III")
	check(STC.weapon_ids(EnemyCatalog.make_enemy("explorador", 12, 2)).size() >= 4, "los de élite llegan al escalón IV")
	var weapons := {}
	var armors := {}
	var type_ok := true
	for i in 60:
		var b := EnemyCatalog.make_enemy("bandido", 5)
		var w: String = b.get_meta(EnemyCatalog.META_WEAPON)
		weapons[w] = true
		armors[int(b.get_meta(RpgStats.META_ARMOR))] = true
		type_ok = type_ok and int(RpgStats.compute(b).weapon) == int(RpgStats.WEAPON_BY_ITEM[w])
	check(weapons.size() >= 4 and armors.size() == 2, "variedad: %d armas y %d armaduras en 60 bandidos" % [weapons.size(), armors.size()])
	check(type_ok, "el tipo de daño sale del arma que les tocó")
	var ranged := true
	for i in 30:
		ranged = ranged and STC.weapon_tree_of(EnemyCatalog.make_enemy("arquero", 3)) in ["w_arco"]
	check(ranged, "los arqueros siempre llevan arco")
	check(STC.weapon_tree_of(EnemyCatalog.make_enemy("guardian_torre", 8)) == "w_maza", "los jefes llevan su arma fija")
	print("[árboles de luchador]")
	var moved_ok := true
	for old: String in STC.MOVED_TO_WEAPON:
		var repl: String = STC.MOVED_TO_WEAPON[old]
		moved_ok = moved_ok and STC.is_weapon_node(old) and not STC.node(repl).is_empty() and not STC.is_weapon_node(repl)
	check(moved_ok, "las 13 técnicas movidas están en armas y su sitio lo ocupa un nodo nuevo")
	var branches_ok := true
	for tid: String in STC.FIGHTER_TREES:
		for br: Dictionary in STC.tree(tid).branches:
			branches_ok = branches_ok and br.nodes.size() >= 7
	check(branches_ok, "las ramas de luchador siguen completas")
	print("[partidas antiguas]")
	var old := _char(F.DUELISTA, 12, "Estoque")
	old.learned_skills.assign(["due_estocada", "due_certero", "due_punto", "due_corazon", "due_tendon"])
	STC.ensure_kit(old)
	check("due_lectura" in old.learned_skills and "due_medido" in old.learned_skills and not "due_corazon" in old.learned_skills, "lo aprendido se pasa al nodo que ocupa su sitio")
	check(STC.points_spent(old) == 6, "cuestan lo mismo que antes: 1 + 3 + 2 = 6 puntos (%d)" % STC.points_spent(old))
	check("due_corazon" in _techs(old), "y con estoque a nivel 12 conserva «Estocada al corazón» como técnica de arma")
	print("[combate]")
	var bm := RpgBattleManager.new()
	bm.setup([sw12], [EnemyCatalog.make_enemy("bandido", 6)], {"seed": 4})
	var ids: Array = bm.techniques_of(bm.fighters[0]).map(func(n): return str(n.id))
	check("esp_media_luna" in ids, "el combate ofrece las técnicas de arma")
	var r := bm.run_auto()
	check(bm.ended, "un combate con técnicas de arma termina")
	print("[panel]")
	var holder := Control.new()
	root.add_child(holder)
	var panel = load("res://scripts/ui/skill_tree_panel.gd").open(holder, sw12)
	await process_frame
	await process_frame
	var tabs: TabContainer = panel._tabs
	check(tabs.get_tab_count() == 4 and tabs.get_tab_title(3) == "Arma", "el panel tiene la pestaña «Arma»")
	panel._show_hint("esp_media_luna")
	check("nivel 12" in str(panel._hint.text), "la ayuda dice el nivel del escalón")
	holder.queue_free()
	await process_frame
	print("[vías del arma]")
	var S := SkillTreeCatalog
	var wv := Character.new()
	wv.first_name = "Vía"
	wv.level = 12
	var sword := Equipment.new()
	sword.equipment_name = "Espada Larga"
	sword.slot = "Arma"
	wv.equipment.append(sword)
	var wt: String = S.weapon_tree_of(wv)
	check(wt == "w_espada" and S.tree(wt).branches.size() == 3, "cada arma tiene tres vías")
	check(S.knows(wv, "esp_tajo") and S.knows(wv, "esp_media_luna") and not S.knows(wv, "esp_maestro"), "sin elegir: la raíz y la primera vía")
	check(S.choose_weapon_path(wv, wt, 1) and S.knows(wv, "esp_tajo") and S.knows(wv, "esp_maestro") and not S.knows(wv, "esp_media_luna"),
		"eliges «Esgrima»: la raíz y sus técnicas, no las de «Filo»")
	check(S.branch_locked(wv, "esp_muro") and not S.choose_weapon_path(wv, wt, 2), "las otras dos vías quedan cerradas")
	wv.level = 4
	check(S.knows(wv, "esp_finta") and not S.knows(wv, "esp_paso"), "las técnicas de la vía siguen llegando por nivel")
	S.forget_trees(wv)
	check(not S.weapon_path_chosen(wv, wt) and S.choose_weapon_path(wv, wt, 2), "el Tomo del olvido deja elegir otra vía")
	var paths := {}
	for i in 12:
		var g: Character = EnemyCatalog.make_enemy("soldado", 12)
		paths[S.weapon_path(g, S.weapon_tree_of(g))] = true
	check(paths.size() >= 2, "los enemigos genéricos usan vías distintas (%d)" % paths.size())
	print("FALLAS: %d" % fails if fails else "TODO OK")
	quit(1 if fails else 0)
