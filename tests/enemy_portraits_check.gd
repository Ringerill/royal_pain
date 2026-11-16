extends SceneTree
# Cada tipo de enemigo usa una imagen de las listadas en EnemyCatalog.PORTRAIT_SETS.

func _initialize() -> void:
	var EC = load("res://scripts/resources/enemy_catalog.gd")
	var fallas := 0
	for type_id in EC.TYPES.keys() if "TYPES" in EC else []:
		var used := {}
		var e = EC.make_enemy(type_id, 5, 0, used)
		var path: String = e.portrait.resource_path if e != null and e.portrait != null else ""
		var ok: bool = path in EC.portraits_of(type_id)
		if not ok:
			fallas += 1
		print("  %s %s → %s" % ["ok   " if ok else "FALLA", type_id, path.get_file()])
	print("FALLAS: ", fallas)
	quit()
