extends SceneTree
# Genera los iconos de la aplicación a partir de los SVG de assets/icons/app/:
#   royal_pain.svg            -> icon.svg (icono del proyecto), royal_pain.ico (Windows) y android_192.png
#   royal_pain_foreground.svg -> android_fg_432.png (icono adaptable: primer plano, en la zona segura)
#   royal_pain_background.svg -> android_bg_432.png (icono adaptable: fondo)
# Uso:  <godot>_console.exe --headless --path . --script tools/build_app_icon.gd
# Después, importar (--import) para que Godot vea los PNG nuevos antes de exportar.

const DIR := "res://assets/icons/app/"
const ICO_SIZES := [16, 24, 32, 48, 64, 128, 256]

func _initialize() -> void:
	var main := FileAccess.get_file_as_string(DIR + "royal_pain.svg")
	_png(main, 192, "android_192.png")
	_png(FileAccess.get_file_as_string(DIR + "royal_pain_foreground.svg"), 432, "android_fg_432.png")
	_png(FileAccess.get_file_as_string(DIR + "royal_pain_background.svg"), 432, "android_bg_432.png")
	var f := FileAccess.open("res://icon.svg", FileAccess.WRITE)
	f.store_string(main)
	f.close()
	_ico(main, DIR + "royal_pain.ico")
	print("iconos generados en ", DIR)
	quit()

func _render(svg: String, px: int) -> Image:
	var img := Image.new()
	img.load_svg_from_string(svg, px / 512.0)
	if img.get_width() != px:
		img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	return img

func _png(svg: String, px: int, file: String) -> void:
	_render(svg, px).save_png(DIR + file)

## ICO con PNG dentro (Windows Vista en adelante): cabecera, una entrada por tamaño y los PNG.
func _ico(svg: String, path: String) -> void:
	var pngs := []
	for px: int in ICO_SIZES:
		pngs.append(_render(svg, px).save_png_to_buffer())
	var out := PackedByteArray()
	out.append_array(_u16(0) + _u16(1) + _u16(ICO_SIZES.size()))
	var offset := 6 + 16 * ICO_SIZES.size()
	for i in ICO_SIZES.size():
		var px: int = ICO_SIZES[i]
		var b: PackedByteArray = pngs[i]
		out.append(px % 256)   # 256 se escribe como 0
		out.append(px % 256)
		out.append(0)
		out.append(0)
		out.append_array(_u16(1) + _u16(32) + _u32(b.size()) + _u32(offset))
		offset += b.size()
	for b: PackedByteArray in pngs:
		out.append_array(b)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(out)
	f.close()

func _u16(v: int) -> PackedByteArray:
	return PackedByteArray([v & 0xFF, (v >> 8) & 0xFF])

func _u32(v: int) -> PackedByteArray:
	return PackedByteArray([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF])
