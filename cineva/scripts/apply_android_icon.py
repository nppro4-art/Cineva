#!/usr/bin/env python3
"""Applique l'icône `icon.png` (racine d'une app Flutter) sur les icônes Android.

Usage : python3 apply_android_icon.py <dossier_app>

Doit être exécuté APRÈS `flutter create --platforms=android`.
"""

import sys
from pathlib import Path

from PIL import Image

DARK = (10, 10, 15, 255)  # #0a0a0f, même fond que le thème Cineva

DENSITIES = {
    "mdpi": 1.0,
    "hdpi": 1.5,
    "xhdpi": 2.0,
    "xxhdpi": 3.0,
    "xxxhdpi": 4.0,
}


def ensure(res: Path, name: str, size: int, image: Image.Image) -> None:
    image.save(res / name)
    print(f"  {name} → {size}x{size}")


def main(app_dir: str) -> None:
    root = Path(app_dir)
    icon_path = root / "icon.png"
    res_root = root / "android" / "app" / "src" / "main" / "res"

    if not icon_path.exists():
        print(f"  {icon_path} absent — icônes par défaut conservées")
        return

    if not res_root.exists():
        print(f"  {res_root} absent — lancer d'abord flutter create --platforms=android")
        return

    base_icon = Image.open(icon_path).convert("RGBA")
    count = 0

    for res in sorted(res_root.iterdir()):
        if not res.is_dir() or not res.name.startswith("mipmap-"):
            continue
        qualifier = res.name.split("-", 1)[1]
        scale = DENSITIES.get(qualifier)
        if scale is None:
            continue  # mipmap-anydpi-v26 (XML uniquement)

        launcher = int(48 * scale)
        adaptive = int(108 * scale)

        # Icône carrée classique.
        ensure(res, "ic_launcher.png", launcher,
               base_icon.resize((launcher, launcher), Image.LANCZOS))

        # Avant-plan adaptatif : logo réduit au centre d'un canevas transparent.
        canvas = Image.new("RGBA", (adaptive, adaptive), (0, 0, 0, 0))
        inner = int(adaptive * 0.55)
        foreground = base_icon.resize((inner, inner), Image.LANCZOS)
        canvas.paste(foreground, ((adaptive - inner) // 2,) * 2, foreground)
        ensure(res, "ic_launcher_foreground.png", adaptive, canvas)

        # Arrière-plan adaptatif : fond sombre uni.
        ensure(res, "ic_launcher_background.png", adaptive,
               Image.new("RGBA", (adaptive, adaptive), DARK))
        count += 3

    print(f"  {count} fichiers d'icône générés dans {res_root}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1])
