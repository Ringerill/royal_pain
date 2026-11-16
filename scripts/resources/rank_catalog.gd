class_name RankCatalog
extends RefCounted
# Rangos (estatus) del rediseño v2 (docs/REDISENO.md §2 y §6). Se consiguen por hitos, no por puntos:
# trabajador = pedir empleo; soldado = alistarse; caballero y noble = nombrado por el rey;
# inafiliado = renunciar a todo.

enum Rank { INAFILIADO, TRABAJADOR, SOLDADO, CABALLERO, NOBLE, REY }

const NAMES := {
	Rank.INAFILIADO: "Inafiliado", Rank.TRABAJADOR: "Trabajador", Rank.SOLDADO: "Soldado",
	Rank.CABALLERO: "Caballero", Rank.NOBLE: "Noble", Rank.REY: "Rey",
}
# Soldados que se pueden llevar (antes del +5 % por punto de Liderazgo).
const SOLDIERS := {
	Rank.INAFILIADO: 5, Rank.TRABAJADOR: 5, Rank.SOLDADO: 10, Rank.CABALLERO: 30, Rank.NOBLE: 100, Rank.REY: 300,
}
const LEADERSHIP_BONUS := 0.05
# Quien paga a sus soldados (los demás reciben los que les asigna su comandante según su fama).
const PAYS_SOLDIERS := [Rank.NOBLE, Rank.REY]
# Desde este rango administras tus grupos en batalla (antes se asignan solos).
const COMMANDS_FROM := Rank.CABALLERO

const HOW := {
	Rank.INAFILIADO: "Renunciar a todos los rangos.",
	Rank.TRABAJADOR: "Pedir empleo en un lugar.",
	Rank.SOLDADO: "Alistarse en el ejército de un reino.",
	Rank.CABALLERO: "Ser nombrado por el rey.",
	Rank.NOBLE: "Ser nombrado por el rey.",
	Rank.REY: "Gobernar un reino.",
}

# Equivalencia desde los roles antiguos (Character.Role) para personajes y guardados existentes.
static func from_role(role: int) -> int:
	match role:
		Character.Role.CAMPESINO: return Rank.TRABAJADOR
		Character.Role.SOLDADO, Character.Role.MERCENARIO: return Rank.SOLDADO
		Character.Role.CABALLERO, Character.Role.CAPITAN, Character.Role.CONDOTIERO: return Rank.CABALLERO
		Character.Role.NOBLEZA_BAJA, Character.Role.NOBLEZA_ALTA, Character.Role.DUQUE: return Rank.NOBLE
		Character.Role.REGENTE: return Rank.REY
		Character.Role.INAFILIADO: return Rank.INAFILIADO
	return Rank.INAFILIADO

static func name_of(r: int) -> String:
	return NAMES.get(r, "?")

static func max_soldiers(r: int, leadership: int) -> int:
	return roundi(SOLDIERS.get(r, 0) * (1.0 + LEADERSHIP_BONUS * leadership))

# --- Soldados en combate ---
const SOLDIERS_PER_FIGURE := 10      # una figura en pantalla por cada 10 soldados
const MAX_SOLDIER_FIGURES := 4
const SOLDIER_BOOST_FROM := 40       # a partir de 40, cada soldado extra fortalece a las figuras
const SOLDIER_BOOST_PER := 0.01      # +1 % de PV y Fuerza por soldado por encima de 40
const SOLDIER_BOOST_MAX := 1.0

static func soldier_figures(count: int) -> int:
	return clampi(count / SOLDIERS_PER_FIGURE, 0, MAX_SOLDIER_FIGURES)

static func soldier_boost(count: int) -> float:
	return clampf((count - SOLDIER_BOOST_FROM) * SOLDIER_BOOST_PER, 0.0, SOLDIER_BOOST_MAX)

## Figuras de soldado para el combate (genéricas: las mueve la IA).
static func soldier_party(count: int, level: int) -> Array[Character]:
	var out: Array[Character] = []
	var boost := soldier_boost(count)
	for i in soldier_figures(count):
		var c := EnemyCatalog.make_enemy("soldado", level)
		c.first_name = "Soldado"
		c.set_meta("ally_soldier", true)
		if boost > 0.0:
			c.set_meta(RpgStats.META_PV_MULT, float(c.get_meta(RpgStats.META_PV_MULT, 1.0)) * (1.0 + boost))
			c.combat = mini(EnemyCatalog.ATTR_MAX, roundi(c.combat * (1.0 + boost)))
		out.append(c)
	return out
