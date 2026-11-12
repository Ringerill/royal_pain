"""Copia los iconos de game-icons.net que usa el juego (tipos de daño, armaduras y categorías de habilidad).

Uso:  python -I tools/build_skill_icons.py <carpeta icons/ del zip de game-icons.net>

- Lee los nombres de las constantes de scripts/ui/skill_icons.gd (DAMAGE, ARMOR, CAT_ICONS, SHIELD,
  UNKNOWN, DAMAGE_GENERIC) y de scripts/ui/stat_icons.gd (ICONS) y copia esos SVG a assets/icons/game-icons/<nombre>.svg (borra los que sobran).
- Ajusta sus .import (64 px con mipmaps) y escribe assets/icons/game-icons/CREDITOS.txt (CC BY 3.0).
Tras ejecutarlo: importar en Godot (--import); si se ajustaron .import, importar otra vez.
El zip: https://game-icons.net/archives/ffffff/transparent/game-icons.net.svg.zip
"""
import os, re, shutil, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src_root = sys.argv[1]

ui = open(os.path.join(ROOT, "scripts", "ui", "skill_icons.gd"), encoding="utf-8").read()
needed = set()
for const in ("DAMAGE", "ARMOR", "CAT_ICONS"):
    m = re.search(r"const %s := \[(.*?)\]" % const, ui)
    needed.update(re.findall(r'"([a-z0-9-]+)"', m.group(1)))
for const in ("SHIELD", "UNKNOWN", "DAMAGE_GENERIC"):
    needed.add(re.search(r'const %s := "([a-z0-9-]+)"' % const, ui).group(1))
# Iconos de recursos, atributos, relaciones y roles (scripts/ui/stat_icons.gd, const ICONS).
stat = open(os.path.join(ROOT, "scripts", "ui", "stat_icons.gd"), encoding="utf-8").read()
m = re.search(r"const ICONS := \{(.*?)\n\}", stat, re.S)
needed.update(re.findall(r'": "([a-z0-9-]+)"', m.group(1)))
# Accesorios, monturas y consumibles: los iconos (valores) de ITEM_ICONS, ITEM_ICON_FALLBACK y CONSUMABLE_ICONS.
for const in ("ITEM_ICONS", "ITEM_ICON_FALLBACK", "CONSUMABLE_ICONS"):
    m = re.search(r"const %s := (.*?)\nconst " % const, stat, re.S)
    needed.update(re.findall(r'": "([a-z0-9-]+)"', m.group(1)))     # {"clave": "icono"}
    needed.update(re.findall(r'", "([a-z0-9-]+)"\]', m.group(1)))   # [["Nombre", "icono"]]
needed.add("help")
needed = sorted(needed)

index = {}
for dirpath, _, files in os.walk(src_root):
    for fn in files:
        if fn.endswith(".svg"):
            index.setdefault(fn[:-4], (os.path.join(dirpath, fn), os.path.basename(dirpath)))
missing = [n for n in needed if n not in index]
if missing:
    sys.exit("Faltan iconos: %s" % missing)

out_dir = os.path.join(ROOT, "assets", "icons", "game-icons")
os.makedirs(out_dir, exist_ok=True)
for f in os.listdir(out_dir):
    if f.endswith(".svg") and f[:-4] not in needed:
        os.remove(os.path.join(out_dir, f))
        if os.path.exists(os.path.join(out_dir, f + ".import")):
            os.remove(os.path.join(out_dir, f + ".import"))
authors = {}
for n in needed:
    path, author = index[n]
    shutil.copyfile(path, os.path.join(out_dir, n + ".svg"))
    authors.setdefault(author, []).append(n)

# Los SVG miden 512 px; se importan a 64 px con mipmaps (se ven a 16–24 px).
patched = 0
for n in needed:
    imp = os.path.join(out_dir, n + ".svg.import")
    if os.path.exists(imp):
        txt = open(imp, encoding="utf-8").read()
        new = txt.replace("svg/scale=1.0", "svg/scale=0.125").replace("mipmaps/generate=false", "mipmaps/generate=true")
        if new != txt:
            open(imp, "w", encoding="utf-8", newline="\n").write(new)
            patched += 1

with open(os.path.join(out_dir, "CREDITOS.txt"), "w", encoding="utf-8") as f:
    f.write("Iconos de https://game-icons.net, bajo licencia Creative Commons BY 3.0\n")
    f.write("(https://creativecommons.org/licenses/by/3.0/). Se usan teñidos en el juego.\n\n")
    for a in sorted(authors):
        f.write("%s: %s\n\n" % (a, ", ".join(sorted(authors[a]))))
print("iconos:", len(needed), "| autores:", sorted(authors), "| .import ajustados:", patched)
