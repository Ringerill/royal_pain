extends Control
# Rediseño v2, fase 6: una expedición (o la arena) en curso: los niveles de salas de izquierda a
# derecha, la sala actual marcada y las del nivel siguiente para elegir. Los combates salen a la
# pantalla de combate y vuelven aquí (Expeditions.SCENE).

const ARENA_BG := "res://assets/battle/backgrounds/tournament.png"

var _bg: TextureRect
var _rooms: HBoxContainer
var _text: RichTextLabel
var _title: Label
var _buttons: HBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	if not Expeditions.active():
		get_tree().change_scene_to_file.call_deferred(GameManager.MAP_SCENE)
		return
	var last := CombatSetup.last_result_text if "last_result_text" in CombatSetup else ""
	_refresh(last if not last.is_empty() else "Avanzas con cuidado. Elige por dónde seguir.")

func _build() -> void:
	_bg = TextureRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_bg)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 30
	col.offset_right = -30
	col.offset_top = 20
	col.offset_bottom = -20
	col.add_theme_constant_override("separation", 16)
	add_child(col)
	_title = Label.new()
	_title.theme_type_variation = &"HeaderLabel"
	col.add_child(_title)
	_rooms = HBoxContainer.new()
	_rooms.alignment = BoxContainer.ALIGNMENT_CENTER
	_rooms.add_theme_constant_override("separation", 28)
	_rooms.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_rooms)
	var panel := PanelContainer.new()
	col.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	panel.add_child(inner)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.add_theme_font_size_override("normal_font_size", 17)
	inner.add_child(_text)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	inner.add_child(_buttons)

func _refresh(text: String) -> void:
	for ch in _rooms.get_children():
		ch.queue_free()
	for ch in _buttons.get_children():
		ch.queue_free()
	if not Expeditions.active():
		_title.text = "Expedición terminada"
		_text.text = StatIcons.richify(text, 17)
		_button("Volver al mapa", func(): get_tree().change_scene_to_file(GameManager.MAP_SCENE))
		return
	var run: Dictionary = Expeditions.run
	_title.text = str(run.title)
	var place := str(run.place)
	_bg.texture = load(ARENA_BG) if place == "arena" else PlaceArt.scene_now(str(Expeditions.PLACES[place].bg))
	var open: Array = Expeditions.choices()
	for l in run.layers.size():
		var colv := VBoxContainer.new()
		colv.alignment = BoxContainer.ALIGNMENT_CENTER
		colv.add_theme_constant_override("separation", 14)
		_rooms.add_child(colv)
		for r in run.layers[l].size():
			var rm: Dictionary = run.layers[l][r]
			var b := Button.new()
			var known: bool = l <= int(run.layer) + 1
			b.text = Expeditions.ROOM_NAMES[rm.type] if known else "?"
			b.icon = SkillIcons.texture(Expeditions.ROOM_ICONS[rm.type]) if known else null
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 26)
			b.custom_minimum_size = Vector2(130, 52)
			b.disabled = not [l, r] in open
			if l == int(run.layer) and r == int(run.room):
				b.text = "▶ " + b.text
			elif bool(rm.done):
				b.modulate = Color(0.6, 0.6, 0.6)
			b.pressed.connect(_go.bind(l, r))
			colv.add_child(b)
	_text.text = StatIcons.richify(text, 17)
	_button("Retirarse", func():
		Expeditions.retreat()
		get_tree().change_scene_to_file(GameManager.MAP_SCENE))

func _button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	_buttons.add_child(b)

func _go(l: int, r: int) -> void:
	var res: Dictionary = Expeditions.enter(l, r)
	if res.has("fight"):
		var scene := CombatSetup.begin_event_fight(res.fight, str(Expeditions.run.title))
		CombatSetup.return_scene = Expeditions.SCENE
		if not scene.is_empty():
			get_tree().change_scene_to_file(scene)
		return
	var text := str(res.get("text", ""))
	if Expeditions.finished():
		text += "\n\n" + Expeditions._finish()
	_refresh(text)
