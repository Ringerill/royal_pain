extends Control
# Combate RPG con vista frontal: enemigos arriba (retratos grandes), tu grupo abajo (caras, PV y PT),
# línea de turnos arriba y menú de órdenes del que actúa. La lógica es RpgBattleManager; el desenlace
# de campaña (honor, experiencia, capturas, muerte, torneo, práctica…) lo aplica FightResults.
#
# Entradas: CombatSetup (duelo de honor 1v1, combate de grupo, torneo, práctica) o, incrustada en una
# batalla campal, player_character + enemy_character + embedded = true (emite embedded_finished).

signal embedded_finished(winner: Character)

const UniqueItems = preload("res://scripts/resources/unique_items.gd")
const LOG_HEIGHT := 58.0
const TURN_DELAY := 0.75
# Ritmo de cada acción: pensar → anunciar (nombre y flecha al objetivo) → embestida → golpe.
const THINK_TIME := 0.45        # s: la IA «piensa» antes de decidir
const TELEGRAPH_TIME := 0.75    # s: anuncia su acción y a quién va antes de ejecutarla
const PLAYER_TELEGRAPH := 0.35  # ...más breve para tus órdenes (ya sabes lo que has elegido)
const STRIKE_DELAY := 0.12      # s: el golpe llega cuando la embestida alcanza al objetivo
const LUNGE_DISTANCE := 38.0
const AIM_WIDTH := 5.0
const AIM_HOSTILE := Color(1.0, 0.42, 0.3, 0.9)
const AIM_FRIENDLY := Color(0.55, 0.9, 0.55, 0.9)
const INTENT_COLOR := Color(1.0, 0.9, 0.6)
const TIMELINE_N := 8
const ENEMY_MAX := 5
const PARTY_MAX := 4
const ENEMY_CARD_W := 168   # (antiguas tarjetas; hoy, ancho mínimo de cada figura: FIGURE_MIN_W)
const PARTY_CARD_W := 172
# Escenario (opción A): figuras de cuerpo entero sin marco, que llenan el alto disponible.
const FIGURE_MIN_W := 96
const FIGURE_MIN_H := 150
const FIGURE_GAP := 6
const STAGE_GAP := 40
const BOTTOM_H := 206   # cabe el menú principal (3 filas) sin desplazar
const FIGURE_FRAME := Color(0, 0, 0, 0)   # sin marco salvo al actuar o ser objetivo
const KO_SLOW_MO := 0.5
const SIDE_COLORS := [Color("5b8fd0"), Color("c9584c")]
const CARD_BORDER := Color(0.29, 0.23, 0.14, 0.0)   # transparente: las figuras van sin marco
const ACTING_BORDER := Color("f0d48a")
const TARGET_BORDER := Color("ff7a5a")
const ALLY_TARGET_BORDER := Color("8ee08a")
const HP_COLOR := Color("b0392d")
const PT_COLOR := Color("3f78a8")
const TO_DEATH_COLOR := Color("e0503c")
const WEAK_COLOR := Color("ffd25a")
const RESIST_COLOR := Color("9fb4c8")
const CMD_SCROLL_DEADZONE := 12   # px que el dedo puede moverse antes de que el toque pase a desplazar la lista
const CMD_SCROLLBAR_WIDTH := 16
const CMD_SCROLL_GRACE_MS := 180   # tras desplazar la lista, un instante en que soltar no pulsa
var _last_scroll_ms := -100000
const MENU_ICON := 16   # icono de las órdenes y técnicas (más grande alargaría los botones)
const TGT_NAMES := {"enemy": "1 enemigo", "enemies": "todos", "random3": "al azar", "ally": "1 aliado",
	"allies": "aliados", "self": "tú", "ko_ally": "caído"}

## Pruebas: la IA juega también por ti y las ventanas previas se saltan; retardo entre turnos.
static var test_auto := false
static var test_delay := -1.0
var _aim: Array = []            # objetivos anunciados de la acción en curso (borde y flecha)
var _aim_layer: Control

var player_character: Character
var enemy_character: Character
var side_a: Array = []        # bandos a medida (tutorial, pruebas); vacíos = los de CombatSetup
var side_b: Array = []
var embedded := false
var title_text := ""

var mgr: RpgBattleManager
var results: FightResults
var is_campaign := false
var group := false
var _owner: Character
var _champion: Character
var _practice := false
var _cards := {}              # Fighter -> {root, style, portrait, name, hp, hp_label, pt, pt_label, status, tag}
var _acting = null            # Fighter al que el jugador da órdenes
var _targeting := {}          # {action, targets, idx, dt, fx}
var _last_target = null
var _menu := ""               # "main", "tech", "swap", "abandon", "target"
var _busy := false
var _ended := false
var _pending_next_round := false
var _embedded_winner: Character
var last_result := {}          # resultado completo (choques de las campales)
var _log_text := ""
var _keys := {}               # keycode -> Callable

var background: TextureRect
var screen: MarginContainer
var title_label: Label
var round_label: Label
var timeline_box: HBoxContainer
var btn_back: Button
var enemy_row: HBoxContainer
var party_row: HBoxContainer
var log_label: RichTextLabel   # registro con iconos (daño, oro, honor…)
var log_panel: PanelContainer
# Vistas (Settings.combat_view): los mismos combatientes, colocados de otra forma (ver _apply_view).
enum View { ESCENARIO, CLASICA, ENFOCADA, PRIMERA }
# Primera persona: enemigos arriba (75% del alto), comandos abajo (25%) y, a la derecha, el retrato de
# quien tiene el turno o es objetivo, con el resto de tu grupo en una franja bajo él.
const FP_ENEMY_SHARE := 3.4     # enemigos : comandos en alto (algo más de 3 : 1)
const FP_LEFT_SHARE := 2.0      # zona izquierda : columna del retrato = 2 : 1 en ancho
const FP_ZOOM := 1.3            # el personaje activo, más grande que su hueco…
const FP_DROP := 0.14           # …y algo más abajo (fracción de su alto): las piernas pueden salirse de la pantalla
const FP_BOTTOM_MIN := 156
const FP_STRIP_W := 80          # aliados sin retrato: solo nombre y barras
var _fp_main: HBoxContainer
var _fp_left: VBoxContainer
var _fp_spot: HBoxContainer
var _cmd_panel: PanelContainer
const FP_CMD_W := 500           # Primera persona: el menú, más ancho (3 columnas, 2 filas)
var _fp_ready := false          # Primera persona: el foco ya se colocó una vez
const FOCUS_RATIO := 4.0        # cuánto más ancho es quien está en foco (vista Enfocada)
const FOCUS_MIN_W := 64
const FOCUS_DIM := Color(0.72, 0.72, 0.72)
const CLASSIC_BOTTOM_H := 206
const CLASSIC_PARTY_PORTRAIT_H := 96
const CLASSIC_ENEMY_PORTRAIT_H := 196
const CLASSIC_BG := Color(0.06, 0.045, 0.03, 0.85)
const CLASSIC_BORDER := Color("4a3a24")
# Sin bordes de color: lo que pasa se ve en el propio personaje, con un destello.
const GLOW_ACT := Color(1.45, 1.45, 1.45)      # blanco: empieza su turno (un destello, no dura todo el turno)
const GLOW_HEAL := Color(0.6, 1.7, 0.65)       # verde: se cura
const GLOW_BUFF := Color(0.6, 0.9, 1.9)        # azul: un efecto a favor
const GLOW_DEBUFF := Color(1.5, 0.55, 1.8)     # morado: un efecto en contra
# (rojo al recibir daño: CombatFx.flash por defecto, en _impact)
const DEBUFFS := ["ardiendo"]                  # además de RpgBattleManager.NEGATIVE
# Todo en un segundo como mucho: aparece la X, se ve, se va a negro y desaparece.
const KO_DELAY := 0.1
const KO_IN_TIME := 0.1
const KO_MARK_TIME := 0.35
const KO_BLACK_TIME := 0.25
const KO_FADE_TIME := 0.2
var _glow_f = null
var _glow_tw: Tween
var _dying := {}    # combatiente → true mientras se ve su X y se apaga
var _gone := {}     # combatientes derrotados que ya no se muestran
var _view := -1
var _root_box: VBoxContainer
var _stage: HBoxContainer
var _bottom: HBoxContainer
var _focus: Array = []
var actor_label: Label
var hint_label: Label
var cmd_box: VBoxContainer

func _ready() -> void:
	_build_ui()
	if player_character == null:
		player_character = CombatSetup.player_character if CombatSetup.player_character != null \
			else CharacterLoader.make_test_character("Sir Alaric", Character.Role.CABALLERO)
	if enemy_character == null:
		enemy_character = CombatSetup.enemy_character if CombatSetup.enemy_character != null \
			else CharacterLoader.make_test_character("Bandido Renco", Character.Role.SOLDADO)
	_owner = player_character
	is_campaign = CombatSetup.is_campaign and not embedded
	group = is_campaign and CombatSetup.group_fight and side_a.is_empty()
	_practice = is_campaign and RelationsData.is_practice() and enemy_character.full_name() == RelationsData.practice_partner
	if CombatSetup.duel_to_death and is_campaign and not test_auto:
		await _warn_to_death()
	# Duelo de honor en campaña (no torneo, práctica ni grupo): un campeón del séquito puede batirse por ti.
	if is_campaign and not group and not CombatSetup.is_tournament() and GameManager.is_game_active and not _practice and not test_auto:
		var champions: Array[Character] = RelationsData.duel_champions()
		if not champions.is_empty():
			var chosen: Character = await _ask_champion(champions)
			if chosen != _owner:
				_champion = chosen
				_champion.set_meta("champion", true)
				player_character = chosen
	_begin()

func _exit_tree() -> void:
	Engine.time_scale = 1.0   # por si se sale durante una pausa de impacto

func _delay() -> float:
	return test_delay if test_delay >= 0.0 else TURN_DELAY

## Un tiempo del ritmo de combate (en las pruebas, con test_delay = 0, todo es inmediato).
func _pace(t: float) -> float:
	return t * _delay() / TURN_DELAY

# --- Montaje ---

func _begin() -> void:
	var a: Array = side_a.duplicate()
	if a.is_empty():
		if group:
			a = Array(PartyData.active())
			if not player_character in a:
				a.push_front(player_character)
			for r in PartyData.reserve():
				if not r in a:
					a.append(r)
		else:
			a = [player_character]
	var b: Array = side_b.duplicate()
	if b.is_empty():
		b = Array(CombatSetup.enemy_party) if group and not CombatSetup.enemy_party.is_empty() else [enemy_character]
	if not enemy_character in b:
		enemy_character = b[0]
	mgr = RpgBattleManager.new()
	# Bolsa de consumibles del grupo (la del jugador); en práctica se gasta una copia.
	var keeper: Character = _owner if _owner != null else player_character
	var bag: Dictionary = {} if keeper == null else (keeper.consumables.duplicate() if _practice else keeper.consumables)
	var opts := {"to_the_death": CombatSetup.duel_to_death and is_campaign and not _practice, "can_flee": true,
		"bag": bag, "enemy_bag": ConsumableCatalog.enemy_bag(), "intel_hook": IntelData.record}
	if is_campaign and not _practice:
		opts["loot_hook"] = func(r: Dictionary) -> void: ConsumableCatalog.grant_loot(bag, r)
	mgr.setup(a, b, opts)
	FightResults.apply_start_health(mgr)
	results = FightResults.new(_owner, player_character, enemy_character)
	results.champion = _champion
	results.companions = a.filter(func(c: Character) -> bool: return c != player_character)
	if _practice:
		results.snapshot_practice([player_character, enemy_character])
	mgr.log_line.connect(_log)
	_log("¡Comienza el combate!")
	mgr.battle_ended.connect(_on_battle_ended)
	mgr.fighter_down.connect(_on_fighter_down)
	for f in mgr.fighters:
		var card := _make_card(f, f.side == 1)
		(enemy_row if f.side == 1 else party_row).add_child(card.root)
		_cards[f] = card
	_apply_view(Settings.combat_view)
	if not Settings.changed.is_connected(_on_settings_changed):
		Settings.changed.connect(_on_settings_changed)
	_pick_background()
	_set_title()
	if not embedded:
		Music.play_context("battle" if a.size() + b.size() > 2 else "duel")
	btn_back.disabled = true
	btn_back.text = "Volver a la batalla" if embedded else _return_text()
	btn_back.tooltip_text = "Termina el combate (o abandona) para volver."
	_refresh()
	_advance()

func _return_text() -> String:
	if not is_campaign:
		return "Volver al menú"
	if CombatSetup.return_scene.ends_with("map.tscn"):
		return "Volver al Mapa"
	if CombatSetup.return_scene.ends_with("relations.tscn"):
		return "Volver a Relaciones"
	return "Volver al Castillo"

func _set_title() -> void:
	var t := title_text
	if t.is_empty():
		if embedded:
			t = ""   # duelo en mitad de una batalla: sin título
		elif CombatSetup.is_tournament():
			t = "Torneo · ronda %d de %d" % [CombatSetup.tournament_round, CombatSetup.tournament_opponents.size()]
		elif _practice:
			t = "Práctica · sin heridas"
		elif group:
			t = str(CombatSetup.pending_outcome.get("title", "Combate"))
		else:
			t = "Duelo de honor"
	if mgr.to_the_death:
		t = ("☠ " + t + " · a muerte") if not t.is_empty() else "☠ A muerte"
		title_label.add_theme_color_override("font_color", TO_DEATH_COLOR)
	title_label.text = t
	title_label.tooltip_text = t
	title_label.visible = not t.is_empty()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background = TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.01, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	screen = MarginContainer.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		screen.add_theme_constant_override("margin_" + side, 12)
	for side in ["top", "bottom"]:
		screen.add_theme_constant_override("margin_" + side, 8)
	add_child(screen)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	screen.add_child(root)
	_root_box = root
	# Barra superior: título, línea de turnos, ronda y volver.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.custom_minimum_size.y = 40
	root.add_child(top)
	title_label = Label.new()
	title_label.theme_type_variation = &"HeaderLabel"
	title_label.custom_minimum_size.x = 160
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_PASS
	top.add_child(title_label)
	var tl := Label.new()
	tl.text = "Turnos"
	tl.theme_type_variation = &"MutedLabel"
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(tl)
	timeline_box = HBoxContainer.new()
	timeline_box.add_theme_constant_override("separation", 4)
	timeline_box.tooltip_text = "Próximos turnos: el más ágil actúa antes."
	top.add_child(timeline_box)
	round_label = Label.new()
	round_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	round_label.custom_minimum_size.x = 64
	round_label.add_theme_font_size_override("font_size", 13)
	top.add_child(round_label)
	var btn_options := Button.new()
	btn_options.text = "Opciones"
	btn_options.tooltip_text = "Sonido, efectos y vista de combate."
	btn_options.add_theme_font_size_override("font_size", 13)
	btn_options.focus_mode = Control.FOCUS_NONE
	btn_options.pressed.connect(func(): OptionsPanel.open(self))
	top.add_child(btn_options)
	btn_back = Button.new()
	btn_back.add_theme_font_size_override("font_size", 13)
	btn_back.pressed.connect(_on_back_pressed)
	top.add_child(btn_back)
	# Escenario: tu grupo a la izquierda y los enemigos a la derecha, de cuerpo entero y frente a frente.
	var stage := HBoxContainer.new()
	stage.add_theme_constant_override("separation", STAGE_GAP)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(stage)
	_stage = stage
	party_row = HBoxContainer.new()
	party_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	party_row.add_theme_constant_override("separation", FIGURE_GAP)
	party_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.add_child(party_row)
	enemy_row = HBoxContainer.new()
	enemy_row.alignment = BoxContainer.ALIGNMENT_END
	enemy_row.add_theme_constant_override("separation", FIGURE_GAP)
	enemy_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.add_child(enemy_row)
	# Abajo: la crónica (izquierda) y el menú de órdenes (derecha).
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	bottom.custom_minimum_size.y = BOTTOM_H
	root.add_child(bottom)
	_bottom = bottom
	log_panel = PanelContainer.new()
	log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(log_panel)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true   # siempre en la última línea
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.add_theme_font_size_override("normal_font_size", 13)
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.custom_minimum_size.y = LOG_HEIGHT
	log_panel.add_child(log_label)
	var cmd_panel := PanelContainer.new()
	cmd_panel.custom_minimum_size.x = 340
	_cmd_panel = cmd_panel
	bottom.add_child(cmd_panel)
	var cmd_col := VBoxContainer.new()
	cmd_col.add_theme_constant_override("separation", 4)
	cmd_panel.add_child(cmd_col)
	actor_label = Label.new()
	actor_label.clip_text = true
	actor_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	actor_label.add_theme_color_override("font_color", ACTING_BORDER)
	cmd_col.add_child(actor_label)
	hint_label = Label.new()
	hint_label.theme_type_variation = &"MutedLabel"
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.max_lines_visible = 2
	hint_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hint_label.custom_minimum_size = Vector2(320, 34)
	cmd_col.add_child(hint_label)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Listas largas (técnicas, objetos): se desplazan arrastrando sobre ellas (táctil), con una barra
	# ancha y siguiendo al botón elegido con teclado o mando.
	scroll.scroll_deadzone = CMD_SCROLL_DEADZONE
	scroll.follow_focus = true
	scroll.get_v_scroll_bar().custom_minimum_size.x = CMD_SCROLLBAR_WIDTH
	scroll.get_v_scroll_bar().value_changed.connect(func(_v: float): _last_scroll_ms = Time.get_ticks_msec())
	cmd_col.add_child(scroll)
	cmd_box = VBoxContainer.new()
	cmd_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cmd_box.add_theme_constant_override("separation", 3)
	scroll.add_child(cmd_box)

func _bar(parent: Node, color: Color) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var icon := StatIcons.icon("vida" if color == HP_COLOR else "pt", 12)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	row.add_child(bar)
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.custom_minimum_size.x = 52
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	return [bar, lbl]

func _small_label(parent: Node, size: int = 12) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _make_card(f, enemy: bool) -> Dictionary:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)   # sin fondo: la figura está sobre el escenario
	style.border_color = CARD_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(FIGURE_MIN_W, 0)
	panel.gui_input.connect(_on_card_input.bind(f))
	panel.mouse_entered.connect(_on_card_hover.bind(f))
	panel.tooltip_text = _card_tip(f)
	var d := {"root": panel, "style": style}
	var tag := Label.new()
	tag.add_theme_font_size_override("font_size", 15)
	tag.add_theme_color_override("font_outline_color", Color.BLACK)
	tag.add_theme_constant_override("outline_size", 5)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.tag = tag
	if true:   # enemigos y tu grupo, con la misma figura (los tuyos llevan además nivel y PT)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(box)
		var tex := TextureRect.new()
		tex.texture = f.c.get_portrait()
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED   # figura completa, sin recortar cabeza ni pies
		tex.custom_minimum_size = Vector2(FIGURE_MIN_W - 8, FIGURE_MIN_H)
		tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tex.flip_h = not enemy   # los tuyos miran hacia los enemigos
		tex.clip_contents = true
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tex)
		tex.add_child(tag)
		tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		d.portrait = tex
		d.enemy = enemy
		d.full_tex = tex.texture
		d.bust_tex = _upper_body(f.c).texture if not enemy else tex.texture
		d.name = _small_label(box, 13)
		d.name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.name.add_theme_color_override("font_outline_color", Color.BLACK)
		d.name.add_theme_constant_override("outline_size", 4)
		if not enemy:
			var lv_row := HBoxContainer.new()
			lv_row.add_theme_constant_override("separation", 4)
			lv_row.alignment = BoxContainer.ALIGNMENT_CENTER
			lv_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(lv_row)
			lv_row.add_child(SkillIcons.damage_icon(int(f.s.weapon), 16))
			d.level = _small_label(lv_row, 11)
		# Lo que se sabe del rival: su tipo de daño y cómo encaja cada tipo (se rellena en _refresh_intel).
		var intel := HBoxContainer.new()
		intel.add_theme_constant_override("separation", 2)
		intel.alignment = BoxContainer.ALIGNMENT_CENTER
		intel.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(intel)
		d.intel = intel
		d.intel_sig = ""
		intel.visible = enemy
		var hp := _bar(box, HP_COLOR)
		d.hp = hp[0]
		d.hp_label = hp[1]
		if not enemy:
			var pt := _bar(box, PT_COLOR)
			d.pt = pt[0]
			d.pt_label = pt[1]
		d.status = _small_label(box, 11)
		d.status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if not enemy:
			d.erase("intel")
	return d

## Lo que el jugador sabe de un combatiente: los suyos, todo; los rivales, lo descubierto (IntelData).
func _intel(f) -> Dictionary:
	if f.side == 0:
		var aff := []
		for dt in 4:
			aff.append(RpgStats.affinity(dt, int(f.s.armor), bool(f.s.shield)))
		return {"weapon": int(f.s.weapon), "armor": int(f.s.armor), "shield": bool(f.s.shield), "aff": aff}
	return IntelData.view(f.c, f.s)

func _card_tip(f) -> String:
	var v := _intel(f)
	var lines := ["%s · Nv %d" % [f.c.full_name(), f.c.level]]
	lines.append("Arma: %s" % (RpgStats.DAMAGE_NAMES[v.weapon] if v.weapon >= 0 else "?"))
	var armor := "?"
	if v.armor >= 0:
		armor = RpgStats.ARMOR_NAMES[v.armor] + (" + escudo" if v.shield else "")
	lines.append("Armadura: %s" % armor)
	var weak := []
	var resist := []
	for dt in 4:
		if v.aff[dt] == RpgStats.Affinity.DEBIL:
			weak.append(RpgStats.DAMAGE_NAMES[dt])
		elif v.aff[dt] == RpgStats.Affinity.RESISTE:
			resist.append(RpgStats.DAMAGE_NAMES[dt])
	if not weak.is_empty():
		lines.append("Débil a: " + ", ".join(weak))
	if not resist.is_empty():
		lines.append("Resiste: " + ", ".join(resist))
	if f.side == 1 and -1 in v.aff:
		lines.append("Descubre más golpeándole, recibiendo sus golpes o analizándolo.")
	return "\n".join(lines)

func _refresh_intel(f, d: Dictionary) -> void:
	var v := _intel(f)
	var sig := str(v)
	if sig == d.intel_sig:
		return
	d.intel_sig = sig
	for ch in d.intel.get_children():
		ch.queue_free()
	var w := SkillIcons.damage_icon(v.weapon, 18)
	w.tooltip_text = "Ataca con: " + (RpgStats.DAMAGE_NAMES[v.weapon] if v.weapon >= 0 else "?")
	d.intel.add_child(w)
	var sep := VSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.intel.add_child(sep)
	for dt in 4:
		d.intel.add_child(SkillIcons.affinity_badge(dt, v.aff[dt], 22))
	d.root.tooltip_text = _card_tip(f)

const PARTY_PORTRAIT_SIZE := Vector2(84, 84)
const UPPER_BODY_WIDTH := 2.4    # ancho del recorte en «caras» (hombros incluidos)
const UPPER_BODY_HEIGHT := 2.6   # alto: de la coronilla a la cintura
const UPPER_BODY_TOP := 0.15     # margen sobre la cabeza

# Mitad superior del cuerpo (cabeza y torso) para las tarjetas del grupo: se recorta alrededor
# de la cara del retrato (Character.get_face) para que la figura llene el marco.
func _upper_body(c: Character) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = PARTY_PORTRAIT_SIZE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := c.get_portrait()
	if tex == null:
		return rect
	var face := c.get_face() as AtlasTexture
	var region := Rect2(0, 0, tex.get_width(), tex.get_height() * 0.5)
	if face != null and face.region.size.x > 0:
		var side := face.region.size.x
		var w := minf(tex.get_width(), side * UPPER_BODY_WIDTH)
		var h := minf(tex.get_height(), side * UPPER_BODY_HEIGHT)
		var cx := face.region.position.x + side * 0.5
		var x := clampf(cx - w * 0.5, 0.0, tex.get_width() - w)
		var y := clampf(face.region.position.y - side * UPPER_BODY_TOP, 0.0, tex.get_height() - h)
		region = Rect2(x, y, w, h)
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = region
	rect.texture = atlas
	return rect

const BiomeBackgrounds = preload("res://scripts/resources/biome_backgrounds.gd")

# Fondo según el bioma del lugar donde estás; torneos y duelos de práctica, en el patio de armas.
func _pick_background() -> void:
	var biome := BiomeBackgrounds.TOURNAMENT if _in_castle_fight() else BiomeBackgrounds.current_biome()
	var tex := BiomeBackgrounds.texture_for(biome)
	if tex != null:
		background.texture = tex

## El cuartel (fondo de torneo) solo para lo que pasa dentro del castillo: torneos, prácticas y duelos
## que retas allí (o desde Relaciones). Choques de batalla, caminos, expediciones y eventos: el bioma.
func _in_castle_fight() -> bool:
	if embedded:
		return false
	if not is_campaign:
		return true   # duelo de práctica del menú principal
	if CombatSetup.is_tournament() or _practice:
		return true
	return not CombatSetup.group_fight and CombatSetup.return_scene in [CombatSetup.CASTLE_SCENE, "res://scenes/relations/relations.tscn"]

# --- Pintar el estado ---

func _status_short(f) -> String:
	var names := []
	for k in f.statuses:
		names.append(RpgBattleManager.STATUS_NAMES.get(k, k))
	return " · ".join(names)

func _shown(side: int, cap: int) -> Array:
	var list: Array = mgr.side_fighters(side)
	var up_active := list.filter(func(f) -> bool: return f.active and f.up())
	var res := list.filter(func(f) -> bool: return not f.active and f.up()) if side == 1 else []
	var fallen := list.filter(func(f) -> bool: return not f.up() and f.participated and not _gone.has(f))
	return (up_active + res + fallen).slice(0, cap)

func _refresh() -> void:
	if mgr == null:
		return
	for side in 2:
		var shown := _shown(side, ENEMY_MAX if side == 1 else PARTY_MAX)
		var row := enemy_row if side == 1 else party_row
		for f in mgr.side_fighters(side):
			_cards[f].root.visible = f in shown
		var idx := 0
		for g in shown:
			var card_root: Control = _cards[g].root
			if card_root.get_parent() == row:   # (en Primera persona, el aliado en grande está en otra columna)
				row.move_child(card_root, idx)
				idx += 1
	for f in mgr.fighters:
		var d: Dictionary = _cards[f]
		d.name.text = f.c.full_name()
		d.hp.max_value = f.max_hp
		d.hp.value = f.hp
		d.hp_label.text = "%d/%d" % [f.hp, f.max_hp]
		if d.has("pt"):
			d.pt.max_value = maxi(1, f.max_pt)
			d.pt.value = f.pt
			d.pt_label.text = str(f.pt)   # el icono de la barra ya dice que son PT
			d.level.text = "Nv %d · %s" % [f.c.level, RpgStats.DAMAGE_NAMES[int(f.s.weapon)]]
		if d.has("intel"):
			_refresh_intel(f, d)
		var st := _status_short(f)
		if not f.up():
			st = "Muerto" if f.dead else "Fuera de combate"
		elif f.side == 1 and not f.active:
			st = "En reserva"
		d.status.text = st
		d.status.tooltip_text = st
		if f.up() and (_dying.has(f) or _gone.has(f)):   # volvió a levantarse (lo reanimaron)
			_revive_card(f)
		if not _dying.has(f):   # (mientras se apaga, su color lo lleva la animación)
			d.root.modulate = Color(0.45, 0.45, 0.45) if not f.up() else (Color(0.75, 0.75, 0.75) if not f.active else Color.WHITE)
			if _view == View.ENFOCADA and mgr.current != null and not f in _focus and f.up():
				d.root.modulate *= FOCUS_DIM
		d.style.border_color = CLASSIC_BORDER if _view == View.CLASICA else CARD_BORDER
		if _targeting.is_empty() or not f in _targeting.targets:
			d.tag.text = ""
	if not _targeting.is_empty():
		_mark_targets()
	_update_focus()
	_update_act_glow()
	for ch in timeline_box.get_children():
		ch.queue_free()
	for f in mgr.timeline(TIMELINE_N):
		var icon := FaceIcon.make(f.c, 32, SIDE_COLORS[f.side], false)
		icon.tooltip_text = f.c.full_name()
		timeline_box.add_child(icon)
	round_label.text = "Ronda %d" % mgr.round_num
	_update_music()

func _update_music() -> void:
	if embedded:
		return
	var lowest := 1.0
	for f in mgr.fighters:
		if f.active and f.up():
			lowest = minf(lowest, f.hp_ratio())
	Music.set_intensity(smoothstep(0.75, 0.3, lowest))

func _log(text: String) -> void:
	_log_text = text if _log_text.is_empty() else _log_text + "\n" + text
	_log_text = LogView.cap(_log_text)
	log_label.text = StatIcons.richify(_log_text, 13)

# --- Turnos ---

func _hp_snapshot() -> Dictionary:
	var out := {}
	var st := {}
	for f in mgr.fighters:
		out[f] = f.hp
		st[f] = f.statuses.keys()
	out["_st"] = st
	return out

func _advance() -> void:
	if _busy:
		return
	_busy = true
	while not mgr.ended:
		var before := _hp_snapshot()
		var f = mgr.next_turn()
		_float_diffs(before, {})
		_refresh()
		if f == null:
			break
		if f.side == 0 and not test_auto:
			_acting = f
			_show_main_menu()
			_busy = false
			return
		_clear_menu()
		actor_label.text = "Turno de %s" % f.c.full_name()
		hint_label.text = ""
		await get_tree().create_timer(_pace(THINK_TIME)).timeout
		if not is_inside_tree() or mgr.ended:
			break
		var action := mgr.ai_choose(f)
		await _telegraph(f, action, _pace(TELEGRAPH_TIME))
		if not is_inside_tree() or mgr.ended:
			break
		await _perform(f, action)
		await get_tree().create_timer(_delay() * 0.5).timeout
		if not is_inside_tree():
			return
	_busy = false

func _perform(f, action: Dictionary) -> void:
	var before := _hp_snapshot()
	var info := mgr.act(f, action)
	if not is_inside_tree():
		return
	await _play_fx(info, before)
	_clear_aim()
	_refresh()

func _player_do(action: Dictionary) -> void:
	if _acting == null or mgr.ended or _busy:
		return
	var f = _acting
	_acting = null
	_targeting = {}
	_clear_menu()
	_busy = true
	await _telegraph(f, action, _pace(PLAYER_TELEGRAPH))
	await _perform(f, action)
	if mgr.ended or not is_inside_tree():
		_busy = false
		return
	await get_tree().create_timer(_delay() * 0.5).timeout
	_busy = false
	if is_inside_tree():
		_advance()

# --- Menú de órdenes ---

func _clear_menu() -> void:
	_keys.clear()
	for ch in cmd_box.get_children():
		cmd_box.remove_child(ch)
		ch.queue_free()

func _cmd(parent: Node, text: String, key: Key, tip: String, cb: Callable, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.disabled = disabled
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.mouse_filter = Control.MOUSE_FILTER_PASS   # arrastrar sobre el botón desplaza la lista (el toque sigue pulsándolo)
	# Si la lista acaba de moverse, el dedo estaba desplazando, no eligiendo: no se pulsa.
	b.pressed.connect(func(): if Time.get_ticks_msec() - _last_scroll_ms > CMD_SCROLL_GRACE_MS: cb.call())
	b.focus_entered.connect(func(): hint_label.text = tip)
	b.mouse_entered.connect(func(): hint_label.text = tip)
	parent.add_child(b)
	if key != KEY_NONE and not disabled:
		_keys[key] = cb
	return b

func _show_main_menu() -> void:
	_menu = "main"
	_clear_menu()
	var f = _acting
	actor_label.text = "Turno de %s" % f.c.full_name()
	hint_label.text = "Elige una orden."
	var grid := GridContainer.new()
	grid.columns = 3 if _view == View.PRIMERA else 2   # Primera persona: franja baja y ancha
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cmd_box.add_child(grid)
	var dt := int(f.s.weapon)
	var first := _cmd(grid, "Atacar (A)", KEY_A, "Golpe con el arma (%s). Recupera PT." % RpgStats.DAMAGE_NAMES[dt],
		func(): _choose_target({"type": "atacar"}, mgr.active_of(1), dt, {}))
	SkillIcons.set_button_icon(first, SkillIcons.texture(SkillIcons.DAMAGE[dt]), SkillIcons.DAMAGE_COLORS[dt], MENU_ICON)
	var techs: Array = mgr.techniques_of(f)
	_cmd(grid, "Técnicas (T)", KEY_T, "%d técnicas · %d PT" % [techs.size(), f.pt], _show_techniques, techs.is_empty())
	_cmd(grid, "Defender (D)", KEY_D, "Menos daño hasta tu turno y recuperas PT.", func(): _player_do({"type": "defender"}))
	var no_items: bool = mgr.bags[0].is_empty()
	_cmd(grid, "Objeto (O)", KEY_O, "No llevas objetos." if no_items else "Usa un objeto (gasta el turno).", _show_items, no_items)
	_cmd(grid, "Cambiar (C)", KEY_C, "Entra alguien de la reserva (gasta el turno)." if not mgr.reserve_of(0).is_empty() else "No hay nadie en la reserva.",
		_show_swap, mgr.reserve_of(0).is_empty())
	_cmd(grid, "Retirarse (R)", KEY_R, "Huir del combate: depende de tu Agilidad frente a la del rival. Si falla, pierdes el turno; si sale bien, algo de honor." if mgr.can_flee else "No hay escapatoria.",
		func(): _player_do({"type": "abandonar", "mode": "retirarse"}), not mgr.can_flee)
	first.grab_focus.call_deferred()

## «Volver» va arriba de la lista: con muchas técnicas (o en el móvil) el final queda fuera de la vista.
func _back_button() -> void:
	var b := _cmd(cmd_box, "◂ Volver", KEY_NONE, "Volver a las órdenes (Esc o el gesto «atrás» del móvil).", _show_main_menu)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	cmd_box.move_child(b, 0)

func _aff_hint(f, t, dt: int, fx: Dictionary) -> String:
	if t == null or t.side == f.side or dt < 0:   # dt < 0: objeto, sin afinidad
		return ""
	if t.side == 1 and int(_intel(t).aff[dt]) < 0:   # aún no sabes cómo encaja ese tipo
		return "?"
	match mgr.affinity_of(f, t, dt, fx):
		RpgStats.Affinity.DEBIL:
			return "Débil"
		RpgStats.Affinity.RESISTE:
			return "Resiste"
	return ""

func _ref_target(f):
	var foes: Array = mgr.active_of(1 - f.side)
	if _last_target != null and _last_target in foes:
		return _last_target
	return foes[0] if not foes.is_empty() else null

func _show_techniques() -> void:
	_menu = "tech"
	_clear_menu()
	var f = _acting
	actor_label.text = "Técnicas · %d PT" % f.pt
	var first: Button = null
	for n: Dictionary in mgr.techniques_of(f):
		var dt := int(n.get("dt", -1))
		if dt < 0:
			dt = int(f.s.weapon)
		var pow := float(n.get("pow", 0.0))
		var fx: Dictionary = n.get("fx", {})
		var tgt: String = n.get("tgt", "enemy")
		var text := "%s · %d PT · %s" % [n.name, int(n.get("pt", 0)), TGT_NAMES.get(tgt, tgt)]
		if pow > 0.0:
			text += " · " + RpgStats.DAMAGE_NAMES[dt]
		var tip: String = n.get("desc", "")
		if pow > 0.0 and tgt in ["enemy", "enemies", "random3"]:
			var ref = _ref_target(f)
			var hint := _aff_hint(f, ref, dt, fx)
			if hint == "?":
				tip += " Aún no sabes cómo lo encaja %s." % ref.c.full_name()
			elif not hint.is_empty():
				tip += " %s ante %s." % [hint, ref.c.full_name()]
		var ok: bool = f.pt >= int(n.get("pt", 0)) and not mgr.valid_targets(f, n).is_empty()
		var id: String = n.id
		var cb := func():
			if tgt in ["enemy", "ally", "ko_ally"]:
				_choose_target({"type": "tecnica", "node": id}, mgr.valid_targets(f, n), dt, fx)
			else:
				_player_do({"type": "tecnica", "node": id})
		var b := _cmd(cmd_box, text, KEY_NONE, tip, cb, not ok)
		SkillIcons.set_node_button_icon(b, id, f.c, MENU_ICON)
		if ok and first == null:
			first = b
	_back_button()
	if first != null:
		first.grab_focus.call_deferred()
	else:
		cmd_box.get_child(0).grab_focus.call_deferred()   # «Volver»

func _show_swap() -> void:
	_menu = "swap"
	_clear_menu()
	var f = _acting
	actor_label.text = "Cambiar a %s por…" % f.c.first_name
	var first: Button = null
	for r in mgr.reserve_of(0):
		var b := _cmd(cmd_box, "%s · PV %d/%d" % [r.c.full_name(), r.hp, r.max_hp], KEY_NONE, "Entra al combate y %s pasa a la reserva." % f.c.first_name,
			func(): _player_do({"type": "cambiar", "out": f, "reserve": r}))
		if first == null:
			first = b
	_back_button()
	if first != null:
		first.grab_focus.call_deferred()

func _show_items() -> void:
	_menu = "items"
	_clear_menu()
	var f = _acting
	actor_label.text = "Objetos"
	var first: Button = null
	for id in mgr.bags[0].keys():
		if not ConsumableCatalog.combat_item(id):
			continue   # el Tomo del olvido se usa fuera de combate
		var it := ConsumableCatalog.item(id)
		var tgt := str(it.get("tgt", "ally"))
		var text := "%s ×%d · %s" % [it.name, ConsumableCatalog.count(mgr.bags[0], id), TGT_NAMES.get(tgt, tgt)]
		var item_id: String = id
		var cb := func():
			if tgt == "allies":
				_player_do({"type": "objeto", "item": item_id, "target": f})
			else:
				_choose_target({"type": "objeto", "item": item_id}, ConsumableCatalog.targets(mgr, f, item_id), -1, {})
		var b := _cmd(cmd_box, text, KEY_NONE, str(it.desc), cb)
		SkillIcons.set_button_icon(b, StatIcons.consumable_texture(item_id), StatIcons.CONSUMABLE_COLOR, MENU_ICON)
		if first == null:
			first = b
	_back_button()
	if first != null:
		first.grab_focus.call_deferred()

# --- Elegir objetivo (teclado, mando o ratón) ---

func _choose_target(action: Dictionary, targets: Array, dt: int, fx: Dictionary) -> void:
	if targets.is_empty() or _acting == null:
		return
	_menu = "target"
	var idx := targets.find(_last_target)
	_targeting = {"action": action, "targets": targets, "idx": maxi(0, idx), "dt": dt, "fx": fx}
	_clear_menu()
	var b := _cmd(cmd_box, "◂ Volver", KEY_NONE, "Volver a las órdenes (Esc).", _cancel_target)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_NONE
	get_viewport().gui_release_focus()
	actor_label.text = "Elige objetivo"
	_mark_targets()

func _mark_targets() -> void:
	var targets: Array = _targeting.targets
	var cur = targets[_targeting.idx]
	for t in targets:
		var d: Dictionary = _cards[t]
		var hint := _aff_hint(_acting, t, _targeting.dt, _targeting.fx) if _acting != null else ""
		d.tag.text = ("▼ " + hint) if t == cur else hint
		d.tag.add_theme_color_override("font_color", WEAK_COLOR if hint == "Débil" else (RESIST_COLOR if hint == "Resiste" else Color.WHITE))
	var h := _aff_hint(_acting, cur, _targeting.dt, _targeting.fx) if _acting != null else ""
	var aff_txt := ""
	if h == "?":
		aff_txt = ": efecto desconocido"
	elif not h.is_empty():
		aff_txt = ": " + h + (" (×1,4)" if h == "Débil" else " (×0,6)")
	hint_label.text = "%s%s · ←/→ cambia, Aceptar confirma." % [cur.c.full_name(), aff_txt]

func _cycle_target(step: int) -> void:
	var n: int = _targeting.targets.size()
	_targeting.idx = (int(_targeting.idx) + step + n) % n
	_refresh()

func _confirm_target() -> void:
	var t = _targeting.targets[_targeting.idx]
	var action: Dictionary = _targeting.action.duplicate()
	action["target"] = t
	if t.side == 1:
		_last_target = t
	_targeting = {}
	_player_do(action)

func _cancel_target() -> void:
	_targeting = {}
	_refresh()
	_show_main_menu()

func _on_card_input(event: InputEvent, f) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _targeting.is_empty() and f in _targeting.targets:
			_targeting.idx = _targeting.targets.find(f)
			_confirm_target()

func _on_card_hover(f) -> void:
	if not _targeting.is_empty() and f in _targeting.targets:
		_targeting.idx = _targeting.targets.find(f)
		_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if _ended or _acting == null:
		return
	if not _targeting.is_empty():
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
			_cycle_target(-1)
		elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
			_cycle_target(1)
		elif event.is_action_pressed("ui_accept"):
			_confirm_target()
		elif event.is_action_pressed("ui_cancel"):
			_cancel_target()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and _menu != "main":
		_show_main_menu()
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and _menu == "main" and _keys.has(key.keycode):
		get_viewport().set_input_as_handled()
		_keys[key.keycode].call()

# --- Anunciar la acción: qué hace y a quién ---

func _action_name(action: Dictionary) -> String:
	match str(action.get("type", "atacar")):
		"atacar":
			return "Ataque"
		"tecnica":
			return str(SkillTreeCatalog.node(str(action.get("node", ""))).get("name", "Técnica"))
		"defender":
			return "En guardia"
		"objeto":
			return ConsumableCatalog.item_name(str(action.get("item", "")))
		"cambiar":
			return "Relevo"
		"abandonar":
			return "Retirada" if str(action.get("mode", "")) == "retirarse" else "Rendición"
	return ""

## A quién va la acción (antes de ejecutarla). Las de área marcan a todo el bando.
func _intended_targets(f, action: Dictionary) -> Array:
	var t = action.get("target", null)
	if t != null:
		return [t]
	if str(action.get("type", "")) == "tecnica":
		match str(SkillTreeCatalog.node(str(action.get("node", ""))).get("tgt", "enemy")):
			"enemies", "random3":
				return mgr.active_of(1 - f.side)
			"allies":
				return mgr.active_of(f.side)
	return []

## Anuncia la acción: su nombre sobre quien la hace, flecha y borde en sus objetivos; espera `time`.
func _telegraph(f, action: Dictionary, time: float) -> void:
	if not is_inside_tree() or not _cards.has(f):
		return
	var label := _action_name(action)
	var targets := _intended_targets(f, action).filter(func(t): return _cards.has(t))
	_aim = targets
	if _view in [View.ENFOCADA, View.PRIMERA] and _update_focus():
		await get_tree().process_frame   # el foco cambia el diseño: las flechas, con las posiciones nuevas
		await get_tree().process_frame
	var to_txt := ""
	if targets.size() == 1 and targets[0] != f:
		to_txt = " → %s" % targets[0].c.full_name()
	elif targets.size() > 1:
		to_txt = " → todos"
	actor_label.text = "%s: %s%s" % [f.c.full_name(), label, to_txt]
	_refresh()
	if time <= 0.0:
		return
	if _cards[f].root.visible:
		CombatFx.punch(_cards[f].portrait, 0.06)   # se prepara (se encoge un poco, sin salirse del marco)
		if not label.is_empty():
			_float(f, label, INTENT_COLOR, 20)
	_draw_aim(f, targets)
	await get_tree().create_timer(time).timeout

## Flechas de quien actúa a cada objetivo (encima de todo, sin capturar el ratón).
func _draw_aim(f, targets: Array) -> void:
	_clear_aim_lines()
	if _aim_layer == null:
		_aim_layer = Control.new()
		_aim_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_aim_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_aim_layer.z_index = 90
		add_child(_aim_layer)
	if not _cards[f].root.visible:
		return
	var from := _center(f) - _aim_layer.global_position
	for t in targets:
		if t == f or not _cards[t].root.visible:
			continue
		var to := _center(t) - _aim_layer.global_position
		var dir := (to - from).normalized()
		var a := from + dir * 46.0   # sale del borde del retrato, no del centro
		var b := to - dir * 50.0
		var color := AIM_FRIENDLY if t.side == f.side else AIM_HOSTILE
		var line := Line2D.new()
		line.points = PackedVector2Array([a, b])
		line.width = AIM_WIDTH
		line.default_color = color
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_aim_layer.add_child(line)
		var head := Polygon2D.new()
		var side := Vector2(-dir.y, dir.x)
		head.polygon = PackedVector2Array([b + dir * 18.0, b + side * 11.0, b - side * 11.0])
		head.color = color
		_aim_layer.add_child(head)
		for n: CanvasItem in [line, head]:
			n.modulate.a = 0.0
			n.create_tween().tween_property(n, "modulate:a", 1.0, 0.15)

# --- Vistas ---

func _on_settings_changed() -> void:
	if Settings.combat_view != _view and not _cards.is_empty():
		_apply_view(Settings.combat_view)
		if _menu == "main" and _acting != null:
			_show_main_menu()   # el menú cambia de columnas según la vista

## Coloca filas y figuras según la vista: Escenario (frente a frente), Clásica (tarjetas) o Enfocada.
func _apply_view(view: int) -> void:
	_view = view
	_reset_first_person()
	if view == View.PRIMERA:
		_layout_first_person()
	elif view == View.CLASICA:
		_stage.visible = false
		enemy_row.reparent(_root_box, false)
		_root_box.move_child(enemy_row, 1)
		enemy_row.alignment = BoxContainer.ALIGNMENT_CENTER
		enemy_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		log_panel.reparent(_root_box, false)
		_root_box.move_child(log_panel, 2)
		log_panel.size_flags_horizontal = Control.SIZE_FILL
		party_row.reparent(_bottom, false)
		_bottom.move_child(party_row, 0)
		_bottom.custom_minimum_size.y = CLASSIC_BOTTOM_H
	else:
		party_row.reparent(_stage, false)
		enemy_row.reparent(_stage, false)
		_stage.move_child(party_row, 0)
		enemy_row.alignment = BoxContainer.ALIGNMENT_END
		enemy_row.size_flags_vertical = Control.SIZE_FILL
		_stage.visible = true
		log_panel.reparent(_bottom, false)
		_bottom.move_child(log_panel, 0)
		log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_bottom.custom_minimum_size.y = BOTTOM_H
	_fp_ready = false
	for f in _cards:
		_style_card(_cards[f])
	_focus = []
	_apply_compact()
	_refresh()

## Vuelve a la disposición base (escenario + franja inferior) antes de aplicar otra vista.
func _reset_first_person() -> void:
	if _fp_main == null:
		return
	for f in _cards:
		var r: Control = _cards[f].root
		if f.side == 0 and r.get_parent() != party_row:
			r.reparent(party_row, false)
	if _bottom.get_parent() != _root_box:
		_bottom.reparent(_root_box, false)
		_root_box.move_child(_bottom, -1)
	party_row.reparent(_stage, false)
	enemy_row.reparent(_stage, false)
	_stage.move_child(party_row, 0)
	enemy_row.size_flags_stretch_ratio = 1.0
	_bottom.size_flags_stretch_ratio = 1.0
	_bottom.size_flags_vertical = Control.SIZE_FILL
	party_row.size_flags_vertical = Control.SIZE_FILL
	_fp_main.visible = false
	_cmd_panel.custom_minimum_size.x = 340
	hint_label.visible = true
	party_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	party_row.alignment = BoxContainer.ALIGNMENT_BEGIN

func _layout_first_person() -> void:
	if _fp_main == null:
		_fp_main = HBoxContainer.new()
		_fp_main.add_theme_constant_override("separation", 10)
		_fp_main.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_root_box.add_child(_fp_main)
		_root_box.move_child(_fp_main, 1)
		_fp_left = VBoxContainer.new()
		_fp_left.add_theme_constant_override("separation", 6)
		_fp_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_fp_left.size_flags_stretch_ratio = FP_LEFT_SHARE
		_fp_main.add_child(_fp_left)
		var right := VBoxContainer.new()
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.size_flags_stretch_ratio = 1.0
		_fp_main.add_child(right)
		_fp_spot = HBoxContainer.new()
		_fp_spot.alignment = BoxContainer.ALIGNMENT_CENTER
		_fp_spot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right.add_child(_fp_spot)
	_fp_main.visible = true
	_stage.visible = false
	enemy_row.reparent(_fp_left, false)
	enemy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_row.size_flags_stretch_ratio = FP_ENEMY_SHARE
	_bottom.reparent(_fp_left, false)
	_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bottom.size_flags_stretch_ratio = 1.0
	_bottom.custom_minimum_size.y = FP_BOTTOM_MIN
	_cmd_panel.custom_minimum_size.x = FP_CMD_W
	hint_label.visible = false   # la descripción sigue en la ayuda de cada botón
	# Abajo: el resto de tu grupo en miniatura, la crónica y los comandos.
	log_panel.reparent(_bottom, false)
	_bottom.move_child(log_panel, 0)
	log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	party_row.reparent(_bottom, false)
	_bottom.move_child(party_row, 0)
	party_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	party_row.size_flags_horizontal = Control.SIZE_FILL
	party_row.size_flags_vertical = Control.SIZE_SHRINK_END

func _style_card(d: Dictionary) -> void:
	var classic := _view == View.CLASICA
	var enemy: bool = d.enemy
	var panel: PanelContainer = d.root
	var tex: TextureRect = d.portrait
	d.style.bg_color = CLASSIC_BG if classic else Color(0, 0, 0, 0)
	panel.size_flags_stretch_ratio = 1.0
	tex.visible = true
	if d.has("fp_big"):
		_fp_zoom(d, false)
	if classic:
		panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		panel.size_flags_horizontal = Control.SIZE_FILL
		panel.custom_minimum_size = Vector2(ENEMY_CARD_W if enemy else PARTY_CARD_W, 0)
		tex.texture = d.full_tex if enemy else d.bust_tex
		tex.flip_h = false
		tex.size_flags_vertical = Control.SIZE_FILL
		tex.custom_minimum_size = Vector2(panel.custom_minimum_size.x - 10, CLASSIC_ENEMY_PORTRAIT_H if enemy else CLASSIC_PARTY_PORTRAIT_H)
	else:
		var min_w := FOCUS_MIN_W if _view == View.ENFOCADA else FIGURE_MIN_W
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size = Vector2(min_w, 0)
		tex.texture = d.full_tex
		tex.flip_h = not enemy   # los tuyos miran hacia los enemigos
		tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tex.custom_minimum_size = Vector2(min_w - 8, FIGURE_MIN_H if _view == View.ESCENARIO else 90)

## Vista Enfocada: quien actúa y a quién apunta se ensanchan; el resto se queda pequeño.
## Devuelve si el foco cambió.
func _update_focus() -> bool:
	if _view not in [View.ENFOCADA, View.PRIMERA] or mgr == null:
		return false
	var focus: Array = []
	if mgr.current != null:
		focus.append(mgr.current)
	for t in _aim:
		if not t in focus:
			focus.append(t)
	if not _targeting.is_empty():
		var t = _targeting.targets[_targeting.idx]
		if not t in focus:
			focus.append(t)
	if _view == View.PRIMERA:
		# De tu grupo, solo en grande quien tiene el turno o es objetivo; los demás, nombre y barras.
		var spot := focus.filter(func(x) -> bool: return x.side == 0)
		if spot.is_empty():   # turno enemigo sin objetivo aún: sigue en pantalla el último
			spot = _focus.filter(func(x) -> bool: return x.up()) if _fp_ready else []
		if spot.is_empty():
			spot = mgr.side_fighters(0).filter(func(x) -> bool: return x.active and x.up()).slice(0, 1)
		if spot.size() > 2:   # algo que alcanza a todo tu grupo: en grande, quien actúa (o el primero)
			spot = [mgr.current] if mgr.current in spot else spot.slice(0, 1)
		if _fp_ready and spot == _focus:
			return false
		_fp_ready = true
		_focus = spot
		for f in _cards:
			if f.side == 0:
				_set_spotlight(_cards[f], f in spot)
		return true
	if focus.size() < 2 and _last_target != null and _last_target in _cards and not _last_target in focus:
		focus.append(_last_target)
	if focus.is_empty() or focus == _focus:
		return false
	_focus = focus
	for f in _cards:
		_cards[f].root.size_flags_stretch_ratio = FOCUS_RATIO if f in focus else 1.0
	_apply_compact()
	return true

## Primera persona: un aliado en grande (con retrato) o en la franja (sin retrato, abajo).
func _set_spotlight(d: Dictionary, on: bool) -> void:
	var r: Control = d.root
	var target: Node = _fp_spot if on else party_row
	if r.get_parent() != target:
		r.reparent(target, false)
	d.portrait.visible = on
	_fp_zoom(d, on)
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL if on else Control.SIZE_SHRINK_END
	r.size_flags_stretch_ratio = 1.0
	r.custom_minimum_size.x = FIGURE_MIN_W if on else FP_STRIP_W
	d.hp_label.visible = on
	if d.has("pt_label"):
		d.pt_label.visible = on

## Primera persona: el retrato del activo se dibuja mayor que su hueco y desplazado hacia abajo
## (una copia hija del retrato; el original queda invisible pero conserva destellos y sacudidas).
func _fp_zoom(d: Dictionary, on: bool) -> void:
	var tex: TextureRect = d.portrait
	if on and not d.has("fp_big"):
		var big := TextureRect.new()
		big.texture = tex.texture
		big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		big.mouse_filter = Control.MOUSE_FILTER_IGNORE
		big.show_behind_parent = false
		tex.add_child(big)
		tex.move_child(big, 0)   # bajo la etiqueta de objetivo
		d.fp_big = big
		tex.resized.connect(_fp_place.bind(d))
	if d.has("fp_big"):
		d.fp_big.visible = on
		d.fp_big.flip_h = tex.flip_h
		tex.clip_contents = not on
		tex.self_modulate.a = 0.0 if on else 1.0
		if on:
			_fp_place(d)

func _fp_place(d: Dictionary) -> void:
	if not d.has("fp_big") or not d.fp_big.visible:
		return
	var tex: TextureRect = d.portrait
	var sz := tex.size * FP_ZOOM
	d.fp_big.size = sz
	d.fp_big.position = Vector2((tex.size.x - sz.x) * 0.5, tex.size.y * FP_DROP)

## En la vista Enfocada, las figuras pequeñas solo muestran nombre y barras (sin números ni iconos).
func _apply_compact() -> void:
	for f in _cards:
		var d: Dictionary = _cards[f]
		var compact: bool = _view == View.ENFOCADA and not _focus.is_empty() and not f in _focus
		if d.has("intel"):
			d.intel.visible = not compact
		d.hp_label.visible = not compact
		if d.has("pt_label"):
			d.pt_label.visible = not compact
		d.status.visible = not compact

func _clear_aim_lines() -> void:
	if _aim_layer == null:
		return
	for ch in _aim_layer.get_children():
		var n: CanvasItem = ch
		var tw := n.create_tween()
		tw.tween_property(n, "modulate:a", 0.0, 0.2)
		tw.tween_callback(n.queue_free)

func _clear_aim() -> void:
	_aim = []
	_clear_aim_lines()

# --- Sensación de golpe ---

func _center(f) -> Vector2:
	var p: Control = _cards[f].portrait
	return (p if p.is_visible_in_tree() else _cards[f].root as Control).get_global_rect().get_center()

func _float(f, text: String, color: Color, size: int = 28) -> void:
	if _cards[f].root.visible:
		CombatFx.floating_text(self, _center(f), text, color, size)

func _impact(f, tier: int) -> void:
	var p: Control = _cards[f].portrait
	CombatFx.flash(p)
	CombatFx.squash(p, 0.05 + CombatFx.TIER_SHAKE[tier] * 0.005)
	CombatFx.sparks(self, _center(f) - global_position, Color(1.0, 0.85, 0.4), 16 + tier * 16)
	CombatFx.shake(screen, CombatFx.TIER_SHAKE[tier], 0.25)
	CombatFx.hit_stop(get_tree(), CombatFx.TIER_HIT_STOP[tier])

func _play_fx(info: Dictionary, before: Dictionary) -> void:
	var actor = info.actor
	var covered := {}
	if info.type in ["atacar", "tecnica"] and not info.hits.is_empty() and _cards[actor].root.visible:
		# Embestida hacia su objetivo (el primero que recibe), y el golpe llega al alcanzarlo.
		var first = info.hits[0].target
		var dir: Vector2 = Vector2.DOWN if actor.side == 1 else Vector2.UP
		if first != actor and _cards[first].root.visible:
			dir = _center(first) - _center(actor)
		CombatFx.lunge(_cards[actor].portrait, dir, LUNGE_DISTANCE)
		if _pace(STRIKE_DELAY) > 0.0:
			await get_tree().create_timer(_pace(STRIKE_DELAY)).timeout
			if not is_inside_tree():
				return
	for h: Dictionary in info.hits:
		var t = h.target
		covered[t] = true
		if not h.hit:
			Sfx.play("whoosh")
			_float(t, "Falla", CombatFx.MISS_COLOR, 26)
			continue
		var tier := mini(CombatFx.tier_for(int(h.dmg)) + (2 if h.crit else 0), CombatFx.Tier.BIG)
		if h.crit:
			Sfx.play("crit")
		else:
			Sfx.play("clash", -6.0)
			Sfx.play("hit")
		if _cards[t].root.visible:
			_impact(t, tier)
		var text := "-%d" % int(h.dmg)
		var color := CombatFx.CRIT_COLOR if h.crit else CombatFx.DAMAGE_COLOR
		if h.crit:
			text = "¡Crítico! " + text
		match int(h.aff):
			RpgStats.Affinity.DEBIL:
				text += " ¡Débil!"
				color = WEAK_COLOR
			RpgStats.Affinity.RESISTE:
				text += " Resiste"
		_float(t, text, color, 28 + tier * 6)
	match str(info.type):
		"defender":
			Sfx.play("guard")
			_glow(actor, GLOW_BUFF, 0.45)
			_float(actor, "En guardia", CombatFx.INFO_COLOR, 22)
		"cambiar":
			Sfx.play("whoosh", -4.0)
		"abandonar":
			if not mgr.ended:
				Sfx.play("guard", -4.0)
				_float(actor, "¡No lo logra!", CombatFx.MISS_COLOR, 24)
	if info.get("extra", false):
		Sfx.stinger("crit", -8.0, 0.5)
		CombatFx.banner(self, "★ ¡Aprovecha la brecha!", CombatFx.CRIT_COLOR, 28, 0.6, log_panel.get_global_rect())
	_float_diffs(before, covered)

## PV que cambian sin un golpe visible (sangrado, respuestas, curas): número flotante.
func _float_diffs(before: Dictionary, covered: Dictionary) -> void:
	for f in mgr.fighters:
		var d: int = f.hp - int(before.get(f, f.hp))
		if d > 0:
			_glow(f, GLOW_HEAL)
		elif d < 0 and not covered.has(f):
			_glow(f, CombatFx.DAMAGE_FLASH)
		if d == 0 or (d < 0 and covered.has(f)):
			continue
		_float(f, ("+%d" % d) if d > 0 else ("-%d" % -d), CombatFx.INFO_COLOR if d > 0 else CombatFx.DAMAGE_COLOR, 24)
	_glow_statuses(before)

## Estados nuevos desde la instantánea: azul si son a favor, morado si son en contra.
func _glow_statuses(before: Dictionary) -> void:
	var old: Dictionary = before.get("_st", {})
	if old.is_empty():
		return
	for f in mgr.fighters:
		if not f.up() or not old.has(f):
			continue
		var bad := false
		var good := false
		for k in f.statuses.keys():
			if k in old[f]:
				continue
			if k in RpgBattleManager.NEGATIVE or k in DEBUFFS:
				bad = true
			else:
				good = true
		if bad:
			_glow(f, GLOW_DEBUFF, 0.5)
		elif good:
			_glow(f, GLOW_BUFF, 0.5)

## Destello de color sobre el retrato (y su copia ampliada en Primera persona).
func _glow(f, color: Color, duration: float = 0.35) -> void:
	if not _cards.has(f) or not _cards[f].root.visible:
		return
	CombatFx.flash(_cards[f].portrait, color, duration)

## Al empezar su turno, un destello blanco de todo su cuerpo (menos de un segundo).
func _update_act_glow() -> void:
	var f = mgr.current if mgr != null and not mgr.ended else null
	if f != null and (not f.up() or not _cards.has(f)):
		f = null
	if f == _glow_f:
		return
	if _glow_tw != null and _glow_tw.is_valid():
		_glow_tw.kill()
	if _glow_f != null and _cards.has(_glow_f):
		(_cards[_glow_f].root.get_child(0) as CanvasItem).modulate = Color.WHITE
	_glow_f = f
	if f == null or CombatFx._reduced():
		return
	var body: CanvasItem = _cards[f].root.get_child(0)
	_glow_tw = body.create_tween()
	_glow_tw.tween_property(body, "modulate", GLOW_ACT, 0.2).set_trans(Tween.TRANS_SINE)
	_glow_tw.tween_property(body, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE)

func _on_fighter_down(f) -> void:
	_float(f, "Muere" if f.dead else "Cae", CombatFx.MISS_COLOR, 30)
	_ko_anim(f)

## Al caer: una X sobre su retrato, luego se va a negro y desaparece de la pantalla.
func _ko_anim(f) -> void:
	if not _cards.has(f) or _dying.has(f):
		return
	var d: Dictionary = _cards[f]
	_dying[f] = true
	if f == _glow_f:
		_update_act_glow()
	await get_tree().create_timer(_pace(KO_DELAY)).timeout   # que se vea el golpe
	if not is_inside_tree() or not _dying.has(f):
		return
	var mark := Label.new()
	mark.text = "✕"
	mark.add_theme_font_size_override("font_size", 120)
	mark.add_theme_color_override("font_color", Color(0.85, 0.12, 0.1))
	mark.add_theme_color_override("font_outline_color", Color.BLACK)
	mark.add_theme_constant_override("outline_size", 10)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.root.add_child(mark)   # sobre toda la figura (PanelContainer: se centra en ella)
	d.ko_mark = mark
	mark.modulate.a = 0.0
	var root: CanvasItem = d.root
	var tw := create_tween()
	tw.tween_property(mark, "modulate:a", 1.0, KO_IN_TIME)
	tw.tween_interval(_pace(KO_MARK_TIME))
	tw.tween_property(root, "modulate", Color(0, 0, 0, 1), _pace(KO_BLACK_TIME))
	tw.tween_property(root, "modulate:a", 0.0, _pace(KO_FADE_TIME))
	tw.tween_callback(func():
		if not _dying.has(f):
			return
		_dying.erase(f)
		_gone[f] = true
		if is_instance_valid(mark):
			mark.queue_free()
		d.erase("ko_mark")
		_refresh())

## Reanimado: vuelve a verse normal.
func _revive_card(f) -> void:
	_dying.erase(f)
	_gone.erase(f)
	var d: Dictionary = _cards[f]
	if d.has("ko_mark") and is_instance_valid(d.ko_mark):
		d.ko_mark.queue_free()
	d.erase("ko_mark")
	d.root.modulate = Color.WHITE

# --- Final ---

func _on_battle_ended(result: Dictionary) -> void:
	_ended = true
	last_result = result
	_acting = null
	_targeting = {}
	_clear_menu()
	FightResults.sync_health(mgr)
	var fled := int(result.get("retreated", -1)) >= 0
	var won := int(result.get("winner", -1)) == 0 and not fled
	actor_label.text = "¡Victoria!" if won else ("Huida" if fled else "Derrota")
	hint_label.text = ""
	var text := ""
	if embedded:
		_embedded_winner = results.finish_embedded(result)
	elif is_campaign and _practice:
		text = results.finish_practice(result)
	elif is_campaign:
		var out: Dictionary = results.finish_campaign(result)
		text = out.text
		if out.next_round:
			_pending_next_round = true
			btn_back.text = "Siguiente ronda (%d/%d)" % [CombatSetup.tournament_round + 1, CombatSetup.tournament_opponents.size()]
		elif out.death_owner:
			btn_back.text = "Volver al Mapa"
		if out.trophy:
			_offer_trophy.call_deferred()
	for l in results.log_lines:
		_log(l)
	if not text.is_empty():
		_log(text)
		hint_label.text = text
		hint_label.tooltip_text = text
	_refresh()
	btn_back.disabled = false
	btn_back.tooltip_text = ""
	_play_end_sound(won, fled)
	# Al terminar, el combate te saca de la pantalla: en batalla vuelve solo al tablero;
	# fuera, un cartel con el resultado y «Continuar».
	if embedded:
		await get_tree().create_timer(EMBEDDED_RETURN_DELAY).timeout
		if is_inside_tree():
			_on_back_pressed()
		return
	await get_tree().create_timer(END_PANEL_DELAY).timeout
	if is_inside_tree():
		_show_end_panel(won, fled, text)

const EMBEDDED_RETURN_DELAY := 1.4   # s: deja ver el golpe final antes de volver al tablero
const END_PANEL_DELAY := 1.2

var _trophy_overlay: Node   # ventana del trofeo abierta: el cartel final espera a que se cierre

func _show_end_panel(won: bool, fled: bool, text: String) -> void:
	if is_instance_valid(_trophy_overlay) and _trophy_overlay.is_inside_tree():
		await _trophy_overlay.tree_exited
	if not is_inside_tree():
		return
	text += await _recruit_offers(won)
	if not is_inside_tree():
		return
	var o := _overlay(0.6)
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = "¡Victoria!" if won else ("Huida" if fled else "Derrota")
	title.add_theme_color_override("font_color", CombatFx.CRIT_COLOR if won else CombatFx.DAMAGE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	o[1].add_child(title)
	if not text.is_empty():
		_note(o[1], text)
	var btn := Button.new()
	btn.text = btn_back.text if _pending_next_round else "Continuar"
	btn.theme_type_variation = &"PrimaryButton"
	o[1].add_child(btn)
	btn.grab_focus.call_deferred()
	await btn.pressed
	o[0].queue_free()
	_on_back_pressed()

const RecruitRules = preload("res://scripts/resources/recruit_rules.gd")
const RecruitDialog = preload("res://scripts/ui/recruit_dialog.gd")

## Tras ganar un combate de grupo en campaña (caminos, expediciones, eventos), algún enemigo genérico
## vencido puede querer unirse a ti, o puedes encerrarlo. Devuelve el texto de lo decidido.
func _recruit_offers(won: bool) -> String:
	if not won or not is_campaign or not group or _practice or CombatSetup.is_tournament() or not GameManager.is_game_active or test_auto:
		return ""
	var defeated := []
	for f in mgr.side_fighters(1):
		if not f.dead:
			defeated.append(f.c)
	var lines: Array[String] = []
	for offer: Dictionary in RecruitRules.offers_after_fight(defeated):
		var d := RecruitDialog.open(self, offer.c, offer.mode)
		var t: String = await d.done
		if not t.is_empty():
			lines.append(t)
	return ("\n" + "\n".join(lines)) if not lines.is_empty() else ""

func _play_end_sound(won: bool, fled: bool) -> void:
	if fled:
		Sfx.play("whoosh")
		return
	CombatFx.slow_mo(get_tree(), KO_SLOW_MO)
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return
	Sfx.stinger("victory" if won else "defeat", 0.0, 2.5)
	CombatFx.banner(self, "¡Victoria!" if won else "Derrota", CombatFx.CRIT_COLOR if won else CombatFx.DAMAGE_COLOR, 46, 1.2, log_panel.get_global_rect())

func _on_back_pressed() -> void:
	if not _ended:
		return
	if embedded:
		embedded_finished.emit(_embedded_winner)
		return
	if _pending_next_round:
		CombatSetup.advance_tournament_round()
		get_tree().change_scene_to_file(CombatSetup.RPG_SCENE)
		return
	if is_campaign:
		var scene := CombatSetup.return_scene
		CombatSetup.clear()
		get_tree().change_scene_to_file(scene)
		return
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

# --- Ventanas previas y trofeo ---

func _overlay(alpha: float = 0.65, tint := Color(0, 0, 0)) -> Array:
	var overlay := ColorRect.new()
	overlay.color = Color(tint.r, tint.g, tint.b, alpha)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 70
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	return [overlay, box]

func _note(box: Node, text: String) -> void:
	var note := RichTextLabel.new()   # con iconos: «Oro −20» pasa a ser la moneda y el número
	note.bbcode_enabled = true
	note.fit_content = true
	note.scroll_active = false
	note.text = StatIcons.richify(text)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(520, 0)
	box.add_child(note)

func _warn_to_death() -> void:
	var o := _overlay(0.75, Color(0.08, 0, 0))
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = "☠ A MUERTE contra %s" % enemy_character.full_name()
	title.add_theme_color_override("font_color", TO_DEATH_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	o[1].add_child(title)
	_note(o[1], "Quien caiga, muere. Si caes tú, te sucede tu heredero. Puedes intentar retirarte, a costa de tu honor.")
	var btn := Button.new()
	btn.text = "Desenvainar"
	btn.theme_type_variation = &"PrimaryButton"
	o[1].add_child(btn)
	btn.grab_focus.call_deferred()
	Sfx.play("guard", -4.0)
	await btn.pressed
	o[0].queue_free()

func _ask_champion(champions: Array[Character]) -> Character:
	var o := _overlay()
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = "¿Quién se bate contra %s?" % enemy_character.full_name()
	o[1].add_child(title)
	_note(o[1], "Un campeón puede luchar por ti: si vence, ganas honor y fama; las heridas son suyas.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	o[1].add_child(row)
	var result := [null]
	var candidates: Array[Character] = [_owner]
	candidates.append_array(champions)
	var preferred: Character = champions[0] if RelationsData.is_designated_champion(champions[0]) else _owner
	for c: Character in candidates:
		var card := VBoxContainer.new()
		card.add_child(FaceIcon.make(c, 110, Color("d4af5a") if c == preferred else FaceIcon.FRAME_COLOR))
		var btn := Button.new()
		btn.text = "Yo mismo" if c == _owner else (c.first_name + (" (campeón)" if c == preferred else ""))
		btn.tooltip_text = "%s · Nv %d · Vida %d/%d" % [c.full_name(), c.level, c.current_health, c.max_health]
		btn.theme_type_variation = &"PrimaryButton" if c == preferred else &""
		btn.pressed.connect(func(): result[0] = c)
		card.add_child(btn)
		row.add_child(card)
		if c == preferred:
			btn.grab_focus.call_deferred()
	while result[0] == null:
		await get_tree().process_frame
	o[0].queue_free()
	return result[0]

## Trofeo: si el vencido lleva una pieza única, el jugador puede reclamarla (cuesta honor y rencor).
func _offer_trophy() -> void:
	var item := UniqueItems.carried_by(enemy_character)
	var taker: Character = _owner if _owner != null else player_character
	if item == null or taker == null or test_auto:
		return
	var o := _overlay()
	_trophy_overlay = o[0]
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = "%s lleva %s" % [enemy_character.full_name(), item.equipment_name]
	title.add_theme_color_override("font_color", Color("f0c060"))
	o[1].add_child(title)
	_note(o[1], "%s\n\nReclamarla es tu derecho, pero no es de caballeros (−%d de honor) y %s no lo olvidará (+%d de rencor)." % [
		item.description, UniqueItems.TROPHY_HONOR_COST, enemy_character.full_name(), UniqueItems.TROPHY_GRUDGE])
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	o[1].add_child(row)
	var claim := Button.new()
	claim.text = "Reclamar el trofeo"
	claim.theme_type_variation = &"PrimaryButton"
	row.add_child(claim)
	var leave := Button.new()
	leave.text = "Dejarla estar"
	row.add_child(leave)
	claim.pressed.connect(func():
		var text := UniqueItems.claim_trophy(taker, enemy_character)
		CombatSetup.last_result_text = (CombatSetup.last_result_text + " " + text).strip_edges()
		_log(text)
		o[0].queue_free())
	leave.pressed.connect(func(): o[0].queue_free())
	leave.grab_focus.call_deferred()
