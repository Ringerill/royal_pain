class_name MentionedFaces
extends RefCounted
# Rostros de los personajes que aparecen nombrados en un texto (sucesos, noticias, comentarios):
# así cada suceso que implica a alguien lo muestra en pantalla.
#   MentionedFaces.find(texto)            → [Character] en el orden en que se les nombra (máx. MAX)
#   MentionedFaces.row(texto, 56, excluir) → HBoxContainer con sus rostros (null si no nombra a nadie)

const MAX := 4

static func find(text: String, exclude: Array = [], limit: int = MAX) -> Array[Character]:
	var out: Array[Character] = []
	var tree := Engine.get_main_loop() as SceneTree
	var rd: Node = tree.root.get_node_or_null("RelationsData") if tree != null else null
	if rd == null or text.is_empty():
		return out
	var hits := []   # [posición, personaje]
	var seen := {}
	for r: Relationship in rd.relations:
		var c: Character = r.character
		if c == null or c in exclude or seen.has(c):
			continue
		var at := text.find(r.person_name)
		if at < 0:
			at = text.find(c.full_name())
		if at >= 0:
			hits.append([at, c])
			seen[c] = true
	hits.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for h: Array in hits.slice(0, limit):
		out.append(h[1])
	return out

static func row(text: String, size: int = 56, exclude: Array = []) -> HBoxContainer:
	var chars := find(text, exclude)
	if chars.is_empty():
		return null
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	for c: Character in chars:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		var face := FaceIcon.make(c, size)
		face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(face)
		var name := Label.new()
		name.text = c.full_name()
		name.theme_type_variation = &"MutedLabel"
		name.add_theme_font_size_override("font_size", 12)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.custom_minimum_size.x = size + 30
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(name)
		box.add_child(col)
	return box
