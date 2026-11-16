class_name ViaCatalog
extends RefCounted
# Vías (motivación) del rediseño v2 (docs/REDISENO.md §2). Se elige al crear y cambia por los actos
# (con aviso). Sus mecánicas son acciones para todos; la vía las potencia. Cada una tiene una meta
# con contador que da la victoria.

enum Via { TIRANO, CONQUISTADOR, HUMILDE, BENEVOLENTE, RESERVADO, AMBICIOSO, JUSTICIERO, VILLANO }

const DATA := {
	Via.TIRANO: {"name": "Tirano", "mechanic": "Purga y Terror",
		"goal": "Ser el único con cargo de realeza en tu reino", "goal_key": "royals_left", "goal_target": 0,
		"bonus": {"tax_loot": 0.5}, "malus": {"fame_gain": -0.5, "fame_loss": 1.0, "recruit": -0.5, "betrayal_affinity": 30}},
	Via.CONQUISTADOR: {"name": "Conquistador", "mechanic": "Ultimátum",
		"goal": "Controlar las capitales de 6 reinos", "goal_key": "capitals", "goal_target": 6,
		"bonus": {"invasion_cooldown": 0, "recruit": 0.3, "siege_attack_dmg": 0.15}, "malus": {"target_of_neighbors": true, "alliance_length": -0.5}},
	Via.HUMILDE: {"name": "Humilde", "mechanic": "Hospitalidad y faenas",
		"goal": "Vencer 5 jefes y completar 30 encargos sin cargo noble", "goal_key": "humble", "goal_target": 1,
		"bonus": {"prices": -0.3, "travel_energy": -0.25}, "malus": {"no_noble": true, "salary": -0.3}},
	Via.BENEVOLENTE: {"name": "Benevolente", "mechanic": "Clemencia y liberar",
		"goal": "Derrotar 15 grupos hostiles que atacan lugares o caravanas", "goal_key": "rescues", "goal_target": 15,
		"bonus": {"healing": 0.25, "recruit_after_win": 0.5}, "malus": {"loot": -0.3}},
	Via.RESERVADO: {"name": "Reservado", "mechanic": "Sigilo",
		"goal": "Alcanzar caballero con la fama entre −20 y 20", "goal_key": "quiet_knight", "goal_target": 1,
		"bonus": {"vision": 1, "first_turn_dmg": 0.2}, "malus": {"fame_gain": -0.3, "talk_affinity": -0.5}},
	Via.AMBICIOSO: {"name": "Ambicioso", "mechanic": "Colección y favores",
		"goal": "Reunir una fortuna de 20.000 y completar la colección de armas", "goal_key": "fortune", "goal_target": 20000,
		"bonus": {"merit_cost": -0.3, "xp": 0.2}, "malus": {"rival_per_rank": true, "failed_proposal_affinity": -10}},
	Via.JUSTICIERO: {"name": "Justiciero", "mechanic": "Cazarrecompensas",
		"goal": "Derrotar 10 líderes o jefes forajidos, o personajes tiranos o villanos", "goal_key": "bounties", "goal_target": 10,
		"bonus": {"boss_dmg": 0.2, "bounty_gold": 0.5}, "malus": {"ambush": 0.5}},
	Via.VILLANO: {"name": "Villano", "mechanic": "Saqueo, asesinato y extorsión",
		"goal": "Saquear 10 lugares o caravanas y asesinar a 3 benevolentes o justicieros", "goal_key": "villainy", "goal_target": 1,
		"bonus": {"loot": 1.0, "outlaw_friendly": true, "enemy_morale": -10}, "malus": {"patrols": true, "city_closed_below_fame": 0}},
}

# Alineamiento antiguo que se guarda junto a la vía (sistemas que aún lo usan).
const TO_ALIGNMENT := {
	Via.TIRANO: 5, Via.CONQUISTADOR: 0, Via.HUMILDE: 3, Via.BENEVOLENTE: 1, Via.RESERVADO: 4,
	Via.AMBICIOSO: 2, Via.JUSTICIERO: 1, Via.VILLANO: 5,
}

static func summary(v: int) -> String:
	var d: Dictionary = DATA.get(v, {})
	return "Mecánica: %s.\nMeta: %s." % [d.get("mechanic", "?"), d.get("goal", "?")]

static func name_of(v: int) -> String:
	return DATA.get(v, {}).get("name", "?")

static func bonus(v: int, key: String, default = 0.0):
	return DATA.get(v, {}).get("bonus", {}).get(key, default)

static func malus(v: int, key: String, default = 0.0):
	return DATA.get(v, {}).get("malus", {}).get(key, default)
