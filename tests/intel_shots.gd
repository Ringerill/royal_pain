extends SceneTree
# Capturas (sin --headless) de los iconos: combate con lo descubierto de cada rival, menú de técnicas
# y panel del árbol de habilidades. Se guardan en tests/_shots/.

const DIR := "res://tests/_shots"

func _initialize() -> void:
	_run.call_deferred()

func _shot(name_: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var path := ProjectSettings.globalize_path("%s/%s.png" % [DIR, name_])
	root.get_texture().get_image().save_png(path)
	print("captura: ", path)

func _run() -> void:
	var GM = root.get_node("GameManager")
	var MD = root.get_node("MapData")
	var intel = root.get_node("IntelData")
	var CL = load("res://scripts/resources/character_loader.gd")
	var CH = load("res://scripts/resources/character.gd")
	var p: Character = CL.make_test_character("Sir Bartolomé", CH.Role.CABALLERO)
	p.fighter_type = CharacterEnums.FighterType.ESTRATEGA
	GM.start_new_game(p, MD.castles[0].castle_id)
	SkillTreeCatalog.ensure_kit(p)
	SkillTreeCatalog.auto_learn(p)
	await process_frame
	var foes: Array = [EnemyCatalog.make_enemy("soldado", 3), EnemyCatalog.make_enemy("infanteria_pesada", 3), EnemyCatalog.make_enemy("arquero", 3)]
	# Soldado: solo se sabe cómo encaja el Tajo; infante pesado: analizado; arquero: nada.
	var s0 := RpgStats.compute(foes[0])
	intel.record("aff", foes[0], s0, RpgStats.DamageType.TAJO, RpgStats.affinity(RpgStats.DamageType.TAJO, s0.armor, s0.shield))
	intel.record("weapon", foes[0], s0, int(s0.weapon))
	intel.record("all", foes[1], RpgStats.compute(foes[1]))
	var RS = load("res://scenes/rpg_battle/rpg_battle.gd")
	RS.test_delay = 0.0
	var sc = load("res://scenes/rpg_battle/rpg_battle.tscn").instantiate()
	sc.side_a = [p]
	sc.side_b = foes
	sc.player_character = p
	root.add_child(sc)
	var guard := 0
	while sc._acting == null and guard < 200:
		await create_timer(0.05).timeout
		guard += 1
	await create_timer(0.5).timeout
	_shot("iconos_combate")
	if sc._acting != null:
		sc._show_techniques()
		await create_timer(0.4).timeout
		_shot("iconos_tecnicas")
	sc.queue_free()
	await process_frame
	var panel_script = load("res://scripts/ui/skill_tree_panel.gd")
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)
	p.level = 8
	var panel = panel_script.open(holder, p)
	await create_timer(0.6).timeout
	_shot("iconos_arbol")
	panel._tabs.current_tab = 3
	await create_timer(0.3).timeout
	_shot("iconos_arma")
	quit()
