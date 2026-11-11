extends RefCounted
# Lugares del mapa para explorar: aparecen cerca de un castillo, duran unos meses y desaparecen.
# Visitar uno gasta una acción y plantea una serie de decisiones (pasos) con el formato de los eventos
# (ver EventCatalog: options con requires/chance/fight; efectos extra "xp", "item" = calidad 1..3
# y "unique" = % de probabilidad de una pieza única).
# Uso: const SiteCatalog = preload("res://scripts/resources/site_catalog.gd")

const R := Character.Role

const SITES := {
	"ruinas": {"name": "Ruinas antiguas", "color": "b9a37a", "months": [3, 5],
		"text": "Entre zarzas asoman los muros de una fortaleza olvidada. Los pastores dicen que de noche se ven luces en la torre.",
		"steps": {
			"start": {"options": [
				{"label": "Entrar por la puerta principal", "effects": {}, "result": "Cruzas el arco derruido.", "next": "patio"},
				{"label": "Rodear los muros y buscar otra entrada", "chance": 0.6, "chance_stat": "strategy",
					"success": {"effects": {}, "result": "Tras la hiedra hay una grieta que baja a las entrañas de la fortaleza.", "next": "cripta"},
					"failure": {"effects": {"health": -10}, "result": "Resbalas por el terraplén y acabas, magullado, en el patio.", "next": "patio"}},
				{"label": "Dar media vuelta", "effects": {}, "result": "Prefieres no tentar a la suerte."},
			]},
			"patio": {"text": "En el patio, los restos de una hoguera reciente. De la torre llegan voces… y un lamento ahogado.", "options": [
				{"label": "Subir a la torre sin hacer ruido", "chance": 0.55, "chance_stat": "agility",
					"success": {"effects": {}, "result": "Llegas arriba sin que nadie te vea.", "next": "torre"},
					"failure": {"effects": {}, "result": "Un escalón cede con estrépito: ¡te han oído!",
						"fight": {"type": "duel", "no_rival": true, "foe": {"name": "Cabecilla de los saqueadores", "role": R.SOLDADO, "power": 0, "personality": "CRUEL"},
							"win": {"effects": {"gold": 50, "xp": 15}, "result": "Los saqueadores huyen y dejan atrás su botín."},
							"lose": {"effects": {"gold": -15}, "result": "Te echan de las ruinas a golpes."}}}},
				{"label": "Registrar los barracones derruidos", "effects": {"gold": 25, "item": 1}, "result": "Entre los escombros, unas monedas y algo de equipo. Bajo una trampilla, una escalera.", "next": "cripta"},
				{"label": "Salir con lo puesto", "effects": {}, "result": "Te alejas antes de que te descubran."},
			]},
			"torre": {"text": "Unos saqueadores duermen junto a la lumbre. En un rincón, alguien maniatado te mira suplicante.", "options": [
				{"label": "Liberar al cautivo sin despertarlos", "chance": 0.55, "chance_stat": "strategy",
					"success": {"effects": {"honor": 3}, "result": "Cortas sus ataduras y bajáis en silencio.", "rescue": "campesino"},
					"failure": {"effects": {}, "result": "Uno de ellos abre los ojos y grita.",
						"fight": {"type": "duel", "no_rival": true, "foe": {"name": "Cabecilla de los saqueadores", "role": R.SOLDADO, "power": 0, "personality": "CRUEL"},
							"win": {"effects": {"gold": 40, "honor": 4, "xp": 20}, "result": "Vences, pero el cautivo aprovechó el tumulto para huir por su cuenta."},
							"lose": {"effects": {"gold": -15}, "result": "Te reducen y te echan de la torre."}}}},
				{"label": "Atacar a los saqueadores dormidos", "effects": {}, "result": "Caes sobre ellos antes de que se pongan en pie.",
					"fight": {"type": "duel", "no_rival": true, "foe": {"name": "Cabecilla de los saqueadores", "role": R.SOLDADO, "power": -1, "personality": "CRUEL"},
						"win": {"effects": {"gold": 60, "honor": 2, "xp": 20}, "result": "Los saqueadores caen. El cautivo, libre, corre a darte las gracias."},
						"lose": {"effects": {"gold": -15}, "result": "Pese a la sorpresa, te superan."}}},
				{"label": "Ofrecerles oro por el cautivo", "requires": {"gold": 40}, "effects": {"gold": -40}, "result": "Cuentan las monedas entre risas y te entregan al cautivo.", "rescue": "campesino"},
			]},
			"cripta": {"text": "La cripta guarda los sepulcros de antiguos señores. Uno tiene la losa entreabierta.", "options": [
				{"label": "Abrir el sepulcro", "chance": 0.55, "chance_stat": "strategy",
					"success": {"effects": {"gold": 80, "item": 2, "unique": 8}, "result": "Entre los huesos del señor, un cofre con su ajuar."},
					"failure": {"effects": {"health": -15}, "result": "Una trampa de los antiguos: una lluvia de piedras te alcanza."}},
				{"label": "Rezar por los muertos y salir", "effects": {"honor": 2}, "result": "Dejas en paz a los difuntos."},
			]},
		}},
	"campamento_bandido": {"name": "Campamento bandido", "color": "a84a3a", "months": [2, 4],
		"text": "Humo entre los árboles: una banda de forajidos ha levantado su campamento junto al camino real y cobra peaje a quien pasa.",
		"steps": {
			"start": {"options": [
				{"label": "Acercarte a espiar el campamento", "chance": 0.6, "chance_stat": "strategy",
					"success": {"effects": {}, "result": "Te arrastras entre los helechos hasta ver el campamento.", "next": "espiado"},
					"failure": {"effects": {"health": -5}, "result": "Pisas una rama seca.", "next": "descubierto"}},
				{"label": "Asaltar el campamento con tus hombres (escaramuza)", "requires": {"garrison": 25}, "effects": {},
					"result": "Reúnes a una partida de la guarnición y caéis sobre el campamento al alba.",
					"fight": {"type": "battle", "no_rival": true, "enemy_name": "Los forajidos", "enemy_ratio": 0.9, "garrison_share": 0.2,
						"foe": {"name": "Jefe de los forajidos", "role": R.SOLDADO, "power": 0, "personality": "CRUEL"},
						"win": {"effects": {"gold": 90, "honor": 5, "fame": 6, "xp": 20}, "result": "El campamento arde y el camino vuelve a ser seguro. Su botín es tuyo."},
						"lose": {"effects": {"honor": -3}, "result": "Los forajidos os rechazan y se burlan desde la empalizada."}}},
				{"label": "Pagar el peaje y seguir", "requires": {"gold": 20}, "effects": {"gold": -20, "honor": -2}, "result": "Pagas. Los bandidos ríen a tu espalda."},
			]},
			"espiado": {"text": "Una docena de forajidos, un carro cargado de botín… y una jaula con un cautivo.", "options": [
				{"label": "Liberar al cautivo al caer la noche", "chance": 0.55, "chance_stat": "agility",
					"success": {"effects": {"honor": 3, "fame": 2}, "result": "Fuerzas la jaula y os perdéis en la oscuridad.", "rescue": "soldado"},
					"failure": {"effects": {}, "result": "La jaula chirría y el campamento entero despierta.",
						"fight": {"type": "duel", "no_rival": true, "foe": {"name": "Jefe de los forajidos", "role": R.SOLDADO, "power": 0, "personality": "CRUEL"},
							"win": {"effects": {"gold": 50, "honor": 4, "xp": 20}, "result": "El jefe cae y su banda se dispersa. El cautivo, libre, huye monte arriba."},
							"lose": {"effects": {"gold": -20}, "result": "Te arrojan al barro del camino con la bolsa más ligera."}}}},
				{"label": "Robar el carro del botín", "chance": 0.5, "chance_stat": "strategy",
					"success": {"effects": {"gold": 90, "item": 1}, "result": "Te llevas el carro sin que nadie lo note hasta el alba."},
					"failure": {"effects": {}, "result": "Los mulos rebuznan y te rodean.",
						"fight": {"type": "duel", "no_rival": true, "foe": {"name": "Jefe de los forajidos", "role": R.SOLDADO, "power": 0, "personality": "CRUEL"},
							"win": {"effects": {"gold": 70, "xp": 20}, "result": "Vences y el carro es tuyo."},
							"lose": {"effects": {"gold": -20}, "result": "Pierdes el carro y algo más."}}}},
				{"label": "Retar al jefe en duelo singular", "requires": {"healthy": true}, "effects": {},
					"result": "Entras solo en el campamento y exiges ver al jefe.",
					"fight": {"type": "duel", "no_rival": true, "foe": {"name": "Jefe de los forajidos", "role": R.SOLDADO, "power": 0, "personality": "CRUEL"},
						"win": {"effects": {"gold": 60, "honor": 6, "fame": 5, "unique": 5}, "result": "El jefe cae y su banda se dispersa por los montes."},
						"lose": {"effects": {"honor": -3, "gold": -20}, "result": "Te arrojan al barro del camino con la bolsa más ligera."}}},
			]},
			"descubierto": {"text": "Un centinela te ve y da la voz de alarma.", "options": [
				{"label": "Plantar cara", "effects": {}, "result": "Desenvainas mientras te rodean.",
					"fight": {"type": "duel", "no_rival": true, "foe": {"name": "Jefe de los forajidos", "role": R.SOLDADO, "power": 0, "personality": "CRUEL"},
						"win": {"effects": {"gold": 50, "honor": 3, "xp": 20}, "result": "Los forajidos huyen dejando atrás sus cosas."},
						"lose": {"effects": {"gold": -20}, "result": "Te dejan tirado en el camino."}}},
				{"label": "Huir al bosque", "chance": 0.6, "chance_stat": "agility",
					"success": {"effects": {}, "result": "Los despistas entre los árboles."},
					"failure": {"effects": {"health": -15}, "result": "Una flecha te roza antes de que logres escapar."}},
			]},
		}},
	"cueva": {"name": "Cueva del lobo", "color": "6f6a62", "months": [3, 6],
		"text": "Una cueva honda en la ladera. Los aldeanos juran que una bestia se lleva el ganado, y que dentro guarda los huesos de quienes fueron a cazarla.",
		"steps": {
			"start": {"options": [
				{"label": "Entrar con antorcha y espada", "requires": {"healthy": true}, "effects": {}, "result": "La luz de la antorcha baila en las paredes.", "next": "galeria"},
				{"label": "Tapiar la entrada", "effects": {"honor": 1}, "result": "Los aldeanos te agradecen el gesto, aunque nadie duerme tranquilo."},
			]},
			"galeria": {"text": "Huesos roídos y un rastro de sangre fresca. Desde el fondo llegan gemidos: alguien sigue vivo.", "options": [
				{"label": "Seguir los gemidos", "effects": {}, "result": "Avanzas hacia la oscuridad.", "next": "fondo"},
				{"label": "Buscar entre los huesos", "effects": {"gold": 20, "item": 1}, "result": "El equipo de un cazador desafortunado, y su bolsa."},
				{"label": "Volver a la luz", "effects": {}, "result": "Sales de la cueva con el corazón en un puño."},
			]},
			"fondo": {"text": "La bestia vigila a un cazador malherido en el fondo de la cueva.", "options": [
				{"label": "Enfrentarte a la bestia", "chance": 0.55, "chance_stat": "combat",
					"success": {"effects": {"fame": 8, "honor": 4, "gold": 30, "unique": 6}, "result": "Abates a la bestia y cargas con el cazador hasta la salida.", "rescue": "soldado"},
					"failure": {"effects": {"health": -30, "honor": 1}, "result": "La bestia te hiere y huyes a la luz. Al menos lo intentaste."}},
				{"label": "Distraerla y sacar al herido", "chance": 0.45, "chance_stat": "agility",
					"success": {"effects": {"honor": 3}, "result": "Le lanzas la antorcha y sacas al cazador a rastras.", "rescue": "soldado"},
					"failure": {"effects": {"health": -20}, "result": "La bestia te alcanza antes de llegar al herido."}},
			]},
		}},
	"monasterio": {"name": "Monasterio en el monte", "color": "d8cfae", "months": [4, 6],
		"text": "Unos monjes han abierto su hospedería en lo alto del monte. Ofrecen pan, cura y consejo a quien sube la cuesta.",
		"options": [
			{"label": "Descansar y orar con los monjes", "effects": {"health": 40, "honor": 3}, "result": "Sales del monasterio con el cuerpo y el alma en paz."},
			{"label": "Estudiar sus crónicas de guerra", "effects": {"strategy": 1}, "result": "Los viejos pergaminos guardan lecciones que ningún maestro te dio."},
			{"label": "Donar a la hospedería", "requires": {"gold": 50}, "effects": {"gold": -50, "honor": 6, "fame": 3}, "result": "Los monjes rezarán por tu nombre en cada misa."},
		]},
	"mina": {"name": "Mina abandonada", "color": "8a6d4a", "months": [3, 5],
		"text": "Una vieja mina de plata, cerrada desde la última peste. Dicen que aún quedan vetas para quien se atreva a bajar.",
		"options": [
			{"label": "Bajar a buscar plata", "chance": 0.5, "chance_stat": "defense",
				"success": {"effects": {"gold": 120}, "result": "Encuentras una veta que los mineros dejaron atrás. Sales cargado de plata."},
				"failure": {"effects": {"health": -20, "gold": 15}, "result": "Un derrumbe te atrapa media jornada. Solo sacas unas pepitas."}},
			{"label": "Enviar a unos soldados a trabajarla", "requires": {"garrison": 30}, "effects": {"castle_gold": 80, "garrison": -3},
				"result": "Tus hombres sacan plata para el castillo, aunque no todos vuelven."},
		]},
	"torre_negra": {"name": "Torre del Desafío", "color": "3a3540", "months": [2, 3],
		"text": "En una torre en ruinas aguarda un guerrero sin nombre. No acepta rescate: solo se bate a muerte. A sus pies, los escudos de los que cayeron.",
		"options": [
			{"label": "Aceptar el duelo a muerte", "requires": {"healthy": true}, "effects": {},
				"result": "Desenvainas. El guardián inclina la cabeza: esto solo termina con uno de los dos en el suelo para siempre.",
				"fight": {"type": "duel", "no_rival": true, "to_death": true,
					"foe": {"name": "El Guardián de la Torre", "role": R.CABALLERO, "power": 2, "personality": "HONORABLE"},
					"win": {"effects": {"fame": 15, "honor": 8, "gold": 100, "unique": 100, "xp": 40}, "result": "El guardián cae. Nadie recordará su nombre, pero su reliquia legendaria y su fama son ahora tuyas."},
					"lose": {"effects": {}, "result": "El guardián limpia su espada y vuelve a esperar."}}},
		]},
}

const ORDER := ["ruinas", "campamento_bandido", "cueva", "monasterio", "mina", "torre_negra"]

static func site_def(type: String) -> Dictionary:
	return SITES.get(type, {})

## Un paso de la expedición: {text, options}. Los lugares de una sola decisión tienen solo "start".
## Cada opción puede llevar (o su success/failure): "next" (otro paso), "fight" (combate y fin),
## "rescue" (rol de alguien que rescatas) y los efectos de siempre.
static func step(type: String, step_id: String = "start") -> Dictionary:
	var d := site_def(type)
	if d.has("steps"):
		var st: Dictionary = d.steps.get(step_id, {})
		return {"text": st.get("text", d.get("text", "") if step_id == "start" else ""), "options": st.get("options", [])}
	return {"text": d.get("text", ""), "options": d.get("options", [])}

## El lugar visto como un evento (para EventCatalog.apply_option, can_choose...): su paso actual.
static func as_event(type: String, step_id: String = "start") -> Dictionary:
	var d := site_def(type)
	var st := step(type, step_id)
	return {"id": type, "title": d.get("name", type), "text": st.text, "options": st.options}
