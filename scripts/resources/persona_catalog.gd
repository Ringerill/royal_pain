class_name PersonaCatalog
extends RefCounted
# Personalidades del rediseño v2 (docs/REDISENO.md §2). Solo influyen en su árbol de técnicas,
# sus diálogos, las afinidades y algo de estadísticas. Sustituyen a Character.Personality (12)
# cuando se migre cada sistema; mientras tanto conviven (Character.persona).

enum Persona { VALIENTE, PRAGMATICO, FRIO, GENTIL, EGOCENTRICO, RESERVADO, INGENUO, ALEGRE, IRASCIBLE }

const NAMES := {
	Persona.VALIENTE: "Valiente", Persona.PRAGMATICO: "Pragmático", Persona.FRIO: "Frío",
	Persona.GENTIL: "Gentil", Persona.EGOCENTRICO: "Egocéntrico", Persona.RESERVADO: "Reservado",
	Persona.INGENUO: "Ingenuo", Persona.ALEGRE: "Alegre", Persona.IRASCIBLE: "Irascible",
}

# Ajuste de estadísticas (Character.ATTRIBUTES: combat=Ataque, defense, agility, strategy, charisma, leadership).
const STATS := {
	Persona.VALIENTE: {"combat": 2, "defense": 1, "strategy": -2, "leadership": 1},
	Persona.PRAGMATICO: {"defense": 1, "strategy": 3, "charisma": -2, "leadership": -1},
	Persona.FRIO: {"combat": 1, "defense": 2, "strategy": 1, "charisma": -3},
	Persona.GENTIL: {"combat": -2, "defense": 1, "charisma": 3},
	Persona.EGOCENTRICO: {"combat": 2, "defense": -2, "charisma": 1, "leadership": 1},
	Persona.RESERVADO: {"agility": 3, "strategy": 1, "charisma": -2, "leadership": -1},
	Persona.INGENUO: {"defense": -1, "agility": 2, "strategy": -2, "charisma": 2},
	Persona.ALEGRE: {"defense": -1, "agility": 1, "charisma": 1, "leadership": 1},
	Persona.IRASCIBLE: {"combat": 3, "defense": -2, "agility": 1, "strategy": -1},
}

# Afinidad: multiplicador de lo que sube la afinidad entre dos personalidades (simétrico salvo matices).
# Positivo = congenian (+30 % → 1.30), negativo = chocan (−20 % → 0.80). Lo que no aparece: 1.0.
const AFFINITY := {
	Persona.VALIENTE: {Persona.ALEGRE: 0.30, Persona.IRASCIBLE: 0.15, Persona.RESERVADO: -0.20, Persona.FRIO: -0.10},
	Persona.PRAGMATICO: {Persona.FRIO: 0.25, Persona.RESERVADO: 0.15, Persona.INGENUO: -0.30, Persona.EGOCENTRICO: -0.15},
	Persona.FRIO: {Persona.PRAGMATICO: 0.25, Persona.RESERVADO: 0.20, Persona.ALEGRE: -0.25, Persona.GENTIL: -0.15},
	Persona.GENTIL: {Persona.INGENUO: 0.35, Persona.ALEGRE: 0.20, Persona.FRIO: -0.15, Persona.EGOCENTRICO: -0.25},
	Persona.EGOCENTRICO: {Persona.IRASCIBLE: 0.10, Persona.GENTIL: -0.25, Persona.PRAGMATICO: -0.15, Persona.EGOCENTRICO: -0.20},
	Persona.RESERVADO: {Persona.FRIO: 0.20, Persona.PRAGMATICO: 0.15, Persona.ALEGRE: -0.30, Persona.VALIENTE: -0.20},
	Persona.INGENUO: {Persona.GENTIL: 0.35, Persona.ALEGRE: 0.25, Persona.PRAGMATICO: -0.30, Persona.FRIO: -0.20},
	Persona.ALEGRE: {Persona.VALIENTE: 0.30, Persona.INGENUO: 0.25, Persona.GENTIL: 0.20, Persona.RESERVADO: -0.30, Persona.FRIO: -0.25},
	Persona.IRASCIBLE: {Persona.VALIENTE: 0.15, Persona.EGOCENTRICO: 0.10, Persona.GENTIL: -0.20, Persona.RESERVADO: -0.15, Persona.IRASCIBLE: -0.25},
}

# Árbol de técnicas de cada personalidad: 3 escalones + definitiva (las técnicas se implementan en la fase 4).
const TREE := {
	Persona.VALIENTE: ["Provocar", "Carga", "Último aliento", "Estandarte"],
	Persona.PRAGMATICO: ["Golpe medido", "Aprovechar", "Reciclar", "Plan B"],
	Persona.FRIO: ["Calcular", "Desarmar", "Paralizar", "Sin piedad"],
	Persona.GENTIL: ["Cubrir", "Alivio", "Ánimo", "Juramento"],
	Persona.EGOCENTRICO: ["Lucirse", "Robar el golpe", "Presumir", "Protagonista"],
	Persona.RESERVADO: ["Guardia", "Observar", "Golpe en las sombras", "Momento justo"],
	Persona.INGENUO: ["Golpe de suerte", "Torpeza afortunada", "Confianza", "Milagro"],
	Persona.ALEGRE: ["Canción de marcha", "Broma", "Inspirar", "Fiesta"],
	Persona.IRASCIBLE: ["Rabia", "Golpe salvaje", "Rugido", "Berserker"],
}

# Personalidad antigua que se guarda junto a la nueva (diálogos e IA que aún usan las 12).
const TO_OLD := {
	Persona.VALIENTE: 6, Persona.PRAGMATICO: 2, Persona.FRIO: 5, Persona.GENTIL: 1, Persona.EGOCENTRICO: 3,
	Persona.RESERVADO: 9, Persona.INGENUO: 10, Persona.ALEGRE: 8, Persona.IRASCIBLE: 7,
}

## Resumen para la creación: estadísticas y técnicas de su árbol.
static func summary(p: int) -> String:
	var parts := []
	for k in STATS.get(p, {}):
		parts.append("%s %+d" % [GameData.STAT_LABELS.get(k, k), int(STATS[p][k])])
	return "%s.\nÁrbol: %s." % [", ".join(parts), ", ".join(TREE.get(p, []))]

# Equivalencia desde las 12 personalidades antiguas (para personajes y guardados existentes).
const FROM_OLD := {
	0: Persona.EGOCENTRICO,   # AMBICIOSO
	1: Persona.GENTIL,        # LEAL
	2: Persona.PRAGMATICO,    # PRUDENTE
	3: Persona.EGOCENTRICO,   # ARROGANTE
	4: Persona.GENTIL,        # PIADOSO
	5: Persona.FRIO,          # ASTUTO
	6: Persona.VALIENTE,      # VALIENTE
	7: Persona.IRASCIBLE,     # CRUEL
	8: Persona.ALEGRE,        # GENEROSO
	9: Persona.RESERVADO,     # COBARDE
	10: Persona.INGENUO,      # ROMANTICO
	11: Persona.VALIENTE,     # HONORABLE
}

static func name_of(p: int) -> String:
	return NAMES.get(p, "?")

## Multiplicador de afinidad de «a» hacia «b» (1.0 = neutro).
static func affinity_factor(a: int, b: int) -> float:
	return 1.0 + float(AFFINITY.get(a, {}).get(b, 0.0))

static func stat_bonus(p: int, attr: String) -> int:
	return int(STATS.get(p, {}).get(attr, 0))
