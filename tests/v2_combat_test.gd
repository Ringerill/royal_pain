extends SceneTree
# Rediseño v2, fase 3: ciclo de armas, escudo, estados nuevos, montura, soldados y la vista con sprites.
#   <godot>_console.exe --headless --path . --script tests/v2_combat_test.gd

const SCENE := "res://scenes/rpg_battle/rpg_battle.tscn"
const WC := RpgStats.WeaponClass
const AF := RpgStats.Affinity
var fails := 0

func check(cond: bool, what: String) -> void:
	print(("  ok  " if cond else "  FALLA ") + what)
	if not cond:
		fails += 1

func _initialize() -> void:
	_run.call_deferred()

func _char(n: String, wc: int) -> Character:
	var CL = load("res://scripts/resources/character_loader.gd")
	var c: Character = CL.make_test_character(n, Character.Role.SOLDADO)
	c.set_meta(RpgStats.META_WCLASS, wc)
	return c

func _bm(a: Array, b: Array, opts := {}) -> RpgBattleManager:
	var bm := RpgBattleManager.new()
	bm.setup(a, b, opts)
	return bm

func _run() -> void:
	print("[ciclo de armas]")
	var cyc_ok := true
	for a in 5:
		for d in 5:
			var want := AF.NORMAL if a == d else (AF.DEBIL if posmod(d - a, 5) <= 2 else AF.RESISTE)
			if RpgStats.matchup(a, d) != want:
				cyc_ok = false
	check(cyc_ok, "cada clase gana a las dos siguientes y pierde ante las dos anteriores")
	check(RpgStats.matchup(WC.ESPADA, WC.LANZA) == AF.DEBIL and RpgStats.matchup(WC.MAZA, WC.ESPADA) == AF.DEBIL and RpgStats.matchup(WC.ESPADA, WC.MANDOBLE) == AF.RESISTE,
		"Espada > Lanza, Maza > Espada, Mandoble resiste a la Espada")
	check(RpgStats.affinity_vs(RpgStats.DamageType.TAJO, WC.ESPADA, RpgStats.DamageType.TAJO, WC.LANZA, true) == AF.NORMAL, "el escudo anula la ventaja del atacante")
	var berserk := _char("Bersérker", WC.ESPADA)
	berserk.remove_meta(RpgStats.META_WCLASS)
	var big := Equipment.new()
	big.equipment_name = "Mandoble"
	big.slot = "Arma"
	berserk.equipment.append(big)
	check(RpgStats.weapon_class(berserk) == WC.MANDOBLE, "un mandoble es su propia clase (aunque dé Tajo)")

	print("[estados]")
	var a := _char("Ana", WC.ESPADA)
	var b := _char("Beto", WC.LANZA)
	var bm := _bm([a], [b], {"seed": 3})
	var fa: RpgBattleManager.Fighter = bm.fighter_of(a)
	var fb: RpgBattleManager.Fighter = bm.fighter_of(b)
	bm._add_status(fb, "sangrado", 2, fa)
	check(fb.has("veneno") and not fb.has("sangrado") and int(fb.statuses.veneno.turns) >= 3, "el sangrado antiguo es ahora veneno (3 turnos)")
	var dmg := int(fb.statuses.veneno.dmg)
	var hp0 := fb.hp
	fb.next_time = -1.0
	bm.next_turn()
	check(hp0 - fb.hp == dmg, "el veneno quita una cantidad fija al empezar el turno (%d)" % dmg)
	bm._add_status(fa, "cegado", 2, fb)
	check(fa.has("miedo") and bm.usable_techniques(fa).is_empty(), "con miedo no hay técnicas")
	var h_fear := bm.hit_chance(fa, fb)
	fa.statuses.erase("miedo")
	check(bm.hit_chance(fa, fb) > h_fear, "y se acierta menos")
	bm._add_status(fb, "marcado", 2, fa)
	check(not fb.has("marcado"), "los estados antiguos sin equivalente se ignoran")
	var tired := _char("Cansado", WC.MAZA)
	tired.energy = 5
	var bm2 := _bm([tired], [_char("Otro", WC.ARCO)])
	check(bm2.fighter_of(tired).has("agotamiento"), "con poca energía se entra al combate agotado")
	var skips := 0
	for i in 40:
		var x := _char("P%d" % i, WC.ESPADA)
		var y := _char("Q%d" % i, WC.ESPADA)
		var bm3 := _bm([x], [y], {"seed": i})
		var fx_: RpgBattleManager.Fighter = bm3.fighter_of(x)
		bm3._add_status(fx_, "aturdido", 1, bm3.fighter_of(y))
		fx_.statuses.paralisis.turns = 1
		fx_.next_time = -1.0
		bm3.fighter_of(y).next_time = 99.0
		var said := [false]
		bm3.log_line.connect(func(t: String): said[0] = said[0] or "paralizado" in t)
		bm3.next_turn()
		if said[0]:
			skips += 1
	check(skips >= 10 and skips <= 30, "la parálisis hace perder el turno la mitad de las veces (%d/40)" % skips)

	print("[escudo y montura]")
	var shielded := _char("Escudado", WC.LANZA)
	var sh := Equipment.new()
	sh.equipment_name = "Escudo de prueba"
	sh.slot = "Escudo"
	shielded.equipment.append(sh)
	var blocks := 0
	var bm4 := _bm([_char("Atacante", WC.ESPADA)], [shielded], {"seed": 7})
	for i in 200:
		var info := {"good": 0, "bad": 0, "hits": []}
		bm4.fighter_of(shielded).hp = 999
		bm4._strike(bm4.fighters[0], bm4.fighters[1], 0.1, RpgStats.DamageType.TAJO, {}, info, false)
		if info.hits[0].get("blocked", false):
			blocks += 1
	check(blocks >= 15 and blocks <= 50, "el escudo bloquea a veces el golpe entero (%d/200)" % blocks)
	var rider := _char("Jinete", WC.LANZA)
	var horse := Equipment.new()
	horse.equipment_name = "Corcel de Guerra"
	horse.slot = "Montura"
	rider.equipment.append(horse)
	var bm5 := _bm([_char("Infante", WC.ESPADA)], [rider], {"seed": 1})
	var fr: RpgBattleManager.Fighter = bm5.fighter_of(rider)
	check(fr.mounted and fr.horse_hp == fr.horse_max and fr.horse_max > 0, "montado: el caballo tiene sus propios PV (%d)" % fr.horse_max)
	var hp1 := fr.hp
	var got := bm5._horse_absorb(fr, 100)
	check(got < 100 and fr.horse_hp == fr.horse_max - (100 - got) and fr.hp == hp1, "el caballo encaja parte del golpe (%d de 100)" % (100 - got))
	var fell := [false]
	bm5.dismounted.connect(func(_f): fell[0] = true)
	bm5._hurt_horse(fr, 9999)
	check(not fr.mounted and fr.has("derribado") and fell[0], "sin PV, el caballo cae y el jinete queda derribado")
	fr.next_time = -1.0
	bm5.fighters[0].next_time = 99.0
	var lost := [false]
	bm5.log_line.connect(func(t: String): lost[0] = lost[0] or "pierde el turno" in t)
	var nxt = bm5.next_turn()
	check(lost[0] and nxt == fr and not fr.has("derribado"), "derribado: pierde un turno y se levanta")

	print("[hasta 8 por bando y soldados]")
	var many_a: Array = []
	var many_b: Array = []
	for i in 10:
		many_a.append(_char("A%d" % i, i % 5))
		many_b.append(_char("B%d" % i, (i + 2) % 5))
	var bm6 := _bm(many_a, many_b, {"max_active": RpgBattleManager.MAX_ACTIVE_V2})
	check(bm6.active_of(0).size() == 8 and bm6.active_of(1).size() == 8 and bm6.reserve_of(0).size() == 2, "8 activos por bando y el resto en reserva")
	check(RankCatalog.soldier_figures(9) == 0 and RankCatalog.soldier_figures(25) == 2 and RankCatalog.soldier_figures(300) == 4, "1 figura por cada 10 soldados (máx. 4)")
	var weak: Character = RankCatalog.soldier_party(40, 3)[0]
	var strong: Character = RankCatalog.soldier_party(90, 3)[0]
	check(RankCatalog.soldier_party(90, 3).size() == 4 and float(strong.get_meta(RpgStats.META_PV_MULT, 1.0)) > float(weak.get_meta(RpgStats.META_PV_MULT, 1.0)),
		"con más de 40 soldados, las figuras son más fuertes")

	print("[vista con sprites]")
	print("  (preparando partida)")
	var GM = root.get_node("GameManager")
	var MD = root.get_node("MapData")
	var ST = root.get_node("Settings")
	var CL = load("res://scripts/resources/character_loader.gd")
	var p: Character = CL.make_test_character("Sir Prueba", Character.Role.CABALLERO)
	p.portrait = load("res://assets/portraits/Characters/Female/woman1.png")
	GM.start_new_game(p, MD.castles[0].castle_id)
	ST.combat_view = ST.COMBAT_VIEW_SPRITES
	var mine: Array = [p]
	for i in 3:
		var c: Character = CL.make_test_character("Compañera %d" % i, Character.Role.SOLDADO)
		c.portrait = p.portrait
		mine.append(c)
	var foes: Array = Array(EnemyCatalog.make_party("escaramuza", 6, 2))
	while foes.size() < 8:
		foes.append(EnemyCatalog.make_enemy("bandido", 3))
	var sc = load(SCENE).instantiate()
	sc.side_a = mine
	sc.side_b = foes
	sc.test_delay = 0.0
	print("  (escena)")
	root.add_child(sc)
	await create_timer(0.4).timeout
	print("  (lista)")
	check(sc.mgr.max_active == 8 and sc.mgr.active_of(1).size() == 8, "en la vista de sprites luchan 8 enemigos a la vez")
	var shown_e: int = sc._cards.keys().filter(func(f): return f.side == 1 and (sc._cards[f].root.visible or sc._gone.has(f) or sc._dying.has(f))).size()
	check(shown_e == 8, "y se ven los 8 (%d)" % shown_e)
	var me = sc.mgr.fighter_of(p)
	var d: Dictionary = sc._cards[me]
	check(d.has("anim") and d.anim.active and d.portrait.texture is AtlasTexture, "tu figura se anima con su hoja de sprites")
	var lefts: Array = sc._cards.keys().filter(func(f): return f.side == 1 and sc._cards[f].root.visible).map(func(f): return sc._cards[f].root.get_global_rect().get_center().x)
	var rights: Array = sc._cards.keys().filter(func(f): return f.side == 0 and sc._cards[f].root.visible).map(func(f): return sc._cards[f].root.get_global_rect().get_center().x)
	check(not lefts.is_empty() and not rights.is_empty() and lefts.max() < rights.min(), "enemigos a la izquierda y tu grupo a la derecha")
	d.anim.play("ataque")
	check(not d.anim.is_idle(), "las acciones cambian la animación")
	sc.queue_free()
	print("FALLAS: %d" % fails if fails else "TODO OK")
	quit(1 if fails else 0)
