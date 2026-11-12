extends SceneTree
# Diagnóstico de dificultad de las campales: el jugador solo pasa el turno (no mueve nada).
# Si gana a menudo así, la IA enemiga es demasiado blanda. Con choques (use_encounters) y sin ellos.
#   <godot>_console.exe --headless --path . --script tests/campal_passive_sim.gd

const N := 12
const A := BattleEnums.Side.ATACANTE
const D := BattleEnums.Side.DEFENSOR

var CL
var _reasons := {}
var CH

func _initialize() -> void:
	_run.call_deferred()

func _cmd(lvl: int) -> Character:
	var c: Character = CL.make_test_character("Cmd%d" % randi(), CH.Role.NOBLEZA_ALTA)
	c.leadership = 8
	c.strategy = 8
	c.level = lvl
	return c

## Una batalla: el jugador (atacante o defensor) solo pasa. Devuelve [ganó, turnos].
func _battle(my_side: int, mine: int, theirs: int, encounters: bool, difficulty: int, allies: int = 0) -> Array:
	var b := BattleManager.new()
	b.player_side = my_side
	b.ally_soldiers = allies
	var att := mine if my_side == A else theirs
	var def := theirs if my_side == A else mine
	b.start_battle(att, def, false, _cmd(5), _cmd(5), "X")
	b.use_encounters = encounters
	b.ai_difficulty = difficulty
	var out := {"w": -1, "why": ""}
	b.battle_ended.connect(func(w: int, rep: Dictionary): out.w = w; out.why = str(rep.reason).left(40))
	var guard := 0
	while not b.is_over and guard < 60:
		if not b.pending_challenge.is_empty():
			b.answer_challenge(false)   # rehúsa los duelos (no juega)
		elif b.pending_retreat:
			b.answer_retreat(false)
		else:
			b.end_player_turn()   # el jugador no hace nada
		guard += 1
	var won: bool = b.is_over and int(out.w) == my_side
	_reasons[out.why] = int(_reasons.get(out.why, 0)) + 1
	return [won, b.turn]

func _run() -> void:
	CL = load("res://scripts/resources/character_loader.gd")
	CH = load("res://scripts/resources/character.gd")
	var GM = root.get_node("GameManager")
	GM.start_new_game(CL.make_test_character("Sir Pasivo", CH.Role.CABALLERO), root.get_node("MapData").castles[0].castle_id)
	await process_frame
	print("  lado      tropa      choques  dificultad  victorias  turnos")
	for setup in [[A, 80, 80, 60], [D, 80, 80, 60], [A, 100, 80, 80], [D, 60, 80, 45]]:
		for enc in [true]:
			for dif in [1, 2]:
				var wins := 0
				var turns := 0
				for i in N:
					var r := _battle(setup[0], setup[1], setup[2], enc, dif, setup[3])
					wins += 1 if r[0] else 0
					turns += int(r[1])
				print("  %-9s %3d (aliados %d) vs %3d  %-7s  %-10s  %3d%%       %.1f" % ["atacante" if setup[0] == A else "defensor", setup[1], setup[3],
					setup[2], "sí" if enc else "no", ["fácil", "normal", "difícil"][dif], roundi(100.0 * wins / N), float(turns) / N])
	print("  motivos: ", _reasons)
	quit()
