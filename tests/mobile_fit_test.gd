extends SceneTree
# Móvil: las ventanas caben en una pantalla baja (se encogen si hace falta) y el recorte de las caras
# sigue bien aunque los retratos se importen más pequeños (size_limit).
#   <godot>_console.exe --headless --path . --script tests/mobile_fit_test.gd

const SCREEN := Vector2i(1200, 540)

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
	var p: Character = CL.make_test_character("Sir Pantalla", Character.Role.NOBLEZA_ALTA)
	GM.start_new_game(p, MD.castles[0].castle_id)
	await process_frame
	print("[caras]")
	var bad := []
	var FR = load("res://scripts/resources/face_rects.gd")
	for path: String in FR.RECTS:
		var c := Character.new()
		c.portrait = load(path)
		var face := c.get_face() as AtlasTexture
		var tex := c.get_portrait()
		if face == null or tex == null:
			bad.append(path)
			continue
		var full := Rect2(Vector2.ZERO, tex.get_size())
		if not full.encloses(face.region) or face.region.size.x < tex.get_width() * 0.15:
			bad.append("%s %s en %s" % [path.get_file(), face.region, tex.get_size()])
	check(bad.is_empty(), "%d caras dentro del retrato %s" % [FR.RECTS.size(), bad.slice(0, 3)])
	print("[ventanas en %dx%d]" % [SCREEN.x, SCREEN.y])
	var vp := SubViewport.new()
	vp.size = SCREEN
	root.add_child(vp)
	var host := Control.new()
	host.size = Vector2(SCREEN)
	vp.add_child(host)
	var lord: Relationship = RD.lords()[0]
	var castle = MD.castles[0]
	var panels := {
		"grupo": func(): return load("res://scripts/ui/party_panel.gd").open(host),
		"tienda": func(): return load("res://scripts/ui/shop_panel.gd").open(host),
		"ficha": func(): return load("res://scripts/ui/character_profile.gd").open(host, lord),
		"conversación": func(): return load("res://scripts/ui/conversation_panel.gd").open(host, lord),
		"audiencia real": func(): return load("res://scripts/ui/royal_audience_panel.gd").open(host, lord),
		"árbol": func(): return load("res://scripts/ui/skill_tree_panel.gd").open(host, p),
		"logros": func(): return load("res://scripts/ui/achievements_panel.gd").open(host),
		"misiones": func(): return load("res://scripts/ui/missions_panel.gd").open(host),
		"opciones": func(): return load("res://scripts/ui/options_panel.gd").open(host),
		"obras": func(): return load("res://scripts/ui/works_panel.gd").open(host, castle),
		"consejo de guerra": func(): return load("res://scripts/ui/war_council_panel.gd").open(host),
		"retrato": func(): return load("res://scripts/ui/portrait_viewer.gd").open(host, p),
	}
	var screen := Rect2(Vector2.ZERO, Vector2(SCREEN)).grow(1.0)
	for name_: String in panels:
		var panel: Control = panels[name_].call()
		for i in 4:
			await process_frame
		var outside := []
		var shrunk := 1.0
		for n in _all(panel):
			if n is Control and n.get_parent() is CenterContainer and n.is_visible_in_tree():
				var r: Rect2 = n.get_global_rect()
				r.size *= n.scale.x   # get_global_rect no incluye la escala
				var center: Vector2 = n.get_global_transform() * (n.size / 2.0)
				r.position = center - r.size / 2.0
				shrunk = minf(shrunk, n.scale.x)
				if not screen.encloses(r):
					outside.append(str(r))
		check(outside.is_empty(), "%s cabe (escala %.2f) %s" % [name_, shrunk, outside])
		if is_instance_valid(panel):
			panel.queue_free()
		await process_frame
	print("[combate: volver atrás]")
	vp.queue_free()
	var RS = load("res://scenes/rpg_battle/rpg_battle.gd")
	RS.test_delay = 0.0
	var sc = load("res://scenes/rpg_battle/rpg_battle.tscn").instantiate()
	sc.side_a = [p]
	sc.side_b = [EnemyCatalog.make_enemy("bandido", 2)]
	sc.player_character = p
	root.add_child(sc)
	var guard := 0
	while sc._acting == null and guard < 100:
		await create_timer(0.05).timeout
		guard += 1
	sc._show_techniques()
	await process_frame
	check(sc._menu == "tech" and "Volver" in sc.cmd_box.get_child(0).text, "en Técnicas, «Volver» es lo primero de la lista")
	root.get_node("TouchSupport").notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)   # gesto «atrás» de Android
	for i in 3:
		await process_frame
	check(sc._menu == "main", "el gesto «atrás» vuelve a las órdenes (no cierra el juego: %s)" % (not ProjectSettings.get_setting("application/config/quit_on_go_back", true)))
	sc.queue_free()
	print("FALLAS: %d" % fails if fails else "TODO OK")
	quit(1 if fails else 0)

func _all(n: Node) -> Array:
	var out := [n]
	for ch in n.get_children():
		out.append_array(_all(ch))
	return out
