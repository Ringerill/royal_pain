class_name PersonalInteractions
extends RefCounted
# Interacciones voluntarias con la gente cercana (botones en Relaciones). Cada una gasta 1 acción y
# solo se puede hacer una por persona al mes. Lo que se gana en intimidad usa la afinidad por honor.
#   PersonalInteractions.for_relation(r) -> [[id, etiqueta, ayuda], ...]
#   PersonalInteractions.blocker(r, id) -> "" si se puede
#   PersonalInteractions.perform(r, id) -> texto del resultado

# Los límites mensuales se guardan con la partida: RelationsData.interaction_months y free_interaction_month.
const XpRulesRef := preload("res://scripts/resources/xp_rules.gd")
const SERF_CARE_COST := 15
const DINNER_COST := 10
const INTRO_MIN_AFFECTION := 30
const TRAIN_XP := 35
const TRAIN_PLAYER_XP := 20

static func kinds(r: Relationship) -> Array:
	var out := []
	if r.kind == Relationship.Kind.CONYUGE:
		out.append("spouse")
	elif r.romance:
		out.append("lover")
	if r.person_name in RelationsData.retinue:
		out.append("retinue")
	if CaptureData.is_serf(r.person_name):
		out.append("serf")
	if CaptureData.is_prisoner(r.person_name):
		out.append("prisoner")
	if r.kind == Relationship.Kind.RIVAL_DUELO:
		out.append("rival")
	if r.kind == Relationship.Kind.CORTESANO and out.is_empty():
		out.append("courtier")
	return out

static func for_relation(r: Relationship) -> Array:
	var out := []
	for k in kinds(r):
		match k:
			"spouse":
				out.append(["velada", "Pasar la velada", "Intimidad con tu cónyuge."])
				out.append(["consejo", "Pedirle consejo", "Experiencia según su Estrategia."])
				out.append(["casa", "Llevar la casa juntos", "Oro según su Estrategia y su Liderazgo."])
			"lover":
				out.append(["encuentro", "Encuentro discreto", "Intimidad; si tienes cónyuge, puede saberse (honor)."])
				out.append(["paseo", "Paseo a caballo", "Recuperas vida y te animas."])
			"retinue":
				out.append(["entrenar", "Entrenar juntos", "Experiencia para los dos."])
				out.append(["recados", "Encargarle recados", "Oro según su nivel."])
				out.append(["ensenar", "Pedirle que te enseñe", "Si te supera en algún atributo, puede enseñártelo (+1)."])
			"serf":
				out.append(["cuidar", "Mejorar su trato (%d oro)" % SERF_CARE_COST, "Más intimidad y lealtad."])
				out.append(["explotar", "Hacerle trabajar duro", "Oro, a costa de su aprecio y algo de honor."])
				out.append(["cultivar", "Ponerle a cultivar", "Comida para tu castillo."])
			"prisoner":
				out.append(["interrogar", "Interrogar", "Según tu Estrategia: te cuenta lo que sabe de su reino."])
				out.append(["interrogar_duro", "Interrogar con dureza", "Casi seguro que habla, pero cuesta honor."])
				out.append(["confianza", "Ganarte su confianza", "Más intimidad: será más fácil que se una a ti."])
			"rival":
				out.append(["provocar", "Provocarle", "Más rencor, y algo de fama si te ven."])
				out.append(["estudiar", "Estudiar su estilo", "Experiencia, y conoces su arma y sus debilidades."])
			"courtier":
				out.append(["cena", "Invitar a cenar (%d oro)" % DINNER_COST, "Intimidad."])
				out.append(["presentar", "Pedirle que te presente", "Con intimidad %d o más: afinidad con el señor de su reino." % INTRO_MIN_AFFECTION])
	return out

## La primera interacción del mes con tu cónyuge o tu séquito no gasta acción.
const FREE_IDS := ["velada", "consejo", "casa", "entrenar", "recados", "ensenar"]

static func is_free(id: String) -> bool:
	return id in FREE_IDS and RelationsData.free_interaction_month != GameManager.months_elapsed()

static func blocker(r: Relationship, id: String) -> String:
	if not is_free(id) and not GameManager.has_actions_remaining():
		return "No te quedan acciones este mes."
	if int(RelationsData.interaction_months.get(r.person_name, -1)) == GameManager.months_elapsed():
		return "Ya tratasteis este mes."
	var p: Character = GameManager.player_character
	match id:
		"cuidar":
			if p.gold < SERF_CARE_COST:
				return "Necesitas %d de oro." % SERF_CARE_COST
		"cena":
			if p.gold < DINNER_COST:
				return "Necesitas %d de oro." % DINNER_COST
			if not RelationsData.in_area(r):
				return "No está en tu zona."
		"presentar":
			if r.affection < INTRO_MIN_AFFECTION:
				return "Necesitas %d de intimidad (tienes %d)." % [INTRO_MIN_AFFECTION, r.affection]
			if _lord_of(r) == null:
				return "Su reino no tiene señor."
		"cultivar":
			if MapData.get_castle_by_id(GameManager.home_castle_id) == null:
				return "No tienes castillo."
	return ""

static func _lord_of(r: Relationship) -> Relationship:
	for lord: Relationship in RelationsData.lords():
		if lord.kingdom == r.kingdom:
			return lord
	return null

static func _gain(r: Relationship, base: int) -> int:
	return maxi(1, roundi(base * RelationsData.honor_affinity_mult(r)))

static func perform(r: Relationship, id: String) -> String:
	var reason := blocker(r, id)
	if not reason.is_empty():
		return reason
	var p: Character = GameManager.player_character
	var free := is_free(id)
	if free:
		RelationsData.free_interaction_month = GameManager.months_elapsed()
	else:
		GameManager.consume_action()
	RelationsData.interaction_months[r.person_name] = GameManager.months_elapsed()
	var text := ""
	match id:
		"velada":
			var g := _gain(r, 7)
			r.adjust_affection(g)
			text = "Pasáis la velada junto al fuego. Intimidad %+d." % g
		"encuentro":
			var g := _gain(r, 8)
			r.adjust_affection(g)
			text = "Os veis a escondidas. Intimidad %+d." % g
			if RelationsData.is_married() and randf() < 0.15:
				p.honor = clampi(p.honor - 3, Character.HONOR_MIN, Character.HONOR_MAX)
				text += " Alguien os vio: corren rumores (honor −3)."
		"entrenar":
			r.character.gain_xp(TRAIN_XP, XpRulesRef.SOURCE_TRAINING)
			WorldGrowth.spend_points(r.character)
			p.gain_xp(TRAIN_PLAYER_XP, XpRulesRef.SOURCE_TRAINING)
			r.adjust_affection(3)
			text = "Cruzáis armas toda la mañana. Experiencia para los dos; intimidad +3."
		"cuidar":
			p.gold -= SERF_CARE_COST
			var g := _gain(r, 8)
			r.adjust_affection(g)
			text = "Mejoras su comida y su techo. Intimidad %+d." % g
		"explotar":
			var gold := 15 + p.leadership
			p.gold += gold
			r.adjust_affection(-8)
			p.honor = clampi(p.honor - 1, Character.HONOR_MIN, Character.HONOR_MAX)
			text = "Le haces trabajar de sol a sol: %d de oro. Intimidad −8, honor −1." % gold
		"interrogar", "interrogar_duro":
			var hard := id == "interrogar_duro"
			var chance := 0.9 if hard else clampf(0.3 + p.strategy * 0.03, 0.2, 0.85)
			if hard:
				p.honor = clampi(p.honor - 4, Character.HONOR_MIN, Character.HONOR_MAX)
				r.adjust_affection(-15)
			if randf() < chance:
				var parts: Array[String] = []
				for c: Castle in MapData.castles:
					if c.kingdom == r.kingdom:
						parts.append("%s: %d soldados" % [c.castle_name, c.garrison_size])
				text = "%s habla: %s." % [r.person_name, "; ".join(parts) if not parts.is_empty() else "su reino ya no existe"]
				WorldEvents.record("Interrogatorio a %s: %s" % [r.person_name, "; ".join(parts)], "", true)
			else:
				text = "%s no suelta palabra." % r.person_name
			if hard:
				text += " (honor −4)"
		"provocar":
			r.adjust_grudge(15)
			if randf() < 0.5:
				p.add_fame(2)
				text = "Le provocas delante de testigos. Rencor +15; fama +2."
			else:
				text = "Le provocas. Rencor +15."
		"cena":
			p.gold -= DINNER_COST
			var g := _gain(r, 6)
			r.adjust_affection(g)
			text = "Cenáis juntos en la posada. Intimidad %+d." % g
		"consejo":
			var xp := 15 + r.character.strategy * 2
			p.gain_xp(xp, XpRulesRef.SOURCE_STUDY)
			r.adjust_affection(2)
			text = "%s te ayuda a ver las cosas con calma. +%d de experiencia." % [r.person_name, p.last_xp_gained]
		"casa":
			var gold := SkillEffects.income(10 + r.character.strategy + r.character.leadership, p)
			p.gold += gold
			text = "Repasáis cuentas y arriendos: %d de oro." % gold
		"paseo":
			var heal := 20
			p.current_health = mini(p.max_health, p.current_health + heal)
			p.current_morale = mini(p.max_morale, p.current_morale + 10)
			r.adjust_affection(3)
			text = "Cabalgáis hasta el río. Vida +%d y ánimo renovado." % heal
		"recados":
			var gold := 15 + r.character.level * 3
			p.gold += gold
			text = "%s vuelve de sus recados con %d de oro." % [r.person_name, gold]
		"ensenar":
			var best := ""
			var gap := 0
			for a in ["combat", "defense", "strategy", "leadership", "charisma", "agility"]:
				var d := int(r.character.get(a)) - int(p.get(a))
				if d > gap:
					gap = d
					best = a
			if best != "" and randf() < clampf(0.15 + gap * 0.08, 0.15, 0.7) and int(p.get(best)) < PointAllocator.STAT_MAX:
				p.set(best, int(p.get(best)) + 1)
				text = "%s te enseña lo que sabe: %s +1." % [r.person_name, EventCatalog._stat_label(best)]
			else:
				p.gain_xp(15, XpRulesRef.SOURCE_STUDY)
				text = "Aprendes algo, aunque no lo bastante (+%d de experiencia)." % p.last_xp_gained
		"cultivar":
			var home: Castle = MapData.get_castle_by_id(GameManager.home_castle_id)
			home.food += 15
			text = "%s trabaja la huerta del castillo: comida +15." % r.person_name
		"confianza":
			var g := _gain(r, 10)
			r.adjust_affection(g)
			text = "Le das mejor trato y conversación. Intimidad %+d: quizá acabe uniéndose a ti." % g
		"estudiar":
			p.gain_xp(20, XpRulesRef.SOURCE_STUDY)
			IntelData.record("all", r.character, RpgStats.compute(r.character))
			text = "Observas sus combates: conoces su arma y sus debilidades (+%d de experiencia)." % p.last_xp_gained
		"presentar":
			var lord := _lord_of(r)
			lord.adjust(8)
			r.adjust_affection(2)
			text = "%s te presenta a %s. Afinidad con %s +8." % [r.person_name, lord.person_name, lord.person_name]
	if free:
		text += " (Sin gastar acción: la primera del mes con tu familia o tu séquito.)"
	RelationsData.relations_changed.emit()
	return text
