#!/usr/bin/env python3
"""Apply a circular alpha mask to the J&T home-screen shortcut artwork."""

import argparse
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw


ICON_NAMES = (
    "delivery.png",
    "vehicle_depart.png",
    "menu_hoa_hong.png",
    "menu_thong_ke_tien_hang.png",
    "receive_package.png",
    "handover.png",
    "memu_clock_in.png",
    "memu_clock_record.png",
    "menu_cs.png",
)
ANTIALIAS_SCALE = 4


def make_circular(image: Image.Image) -> Image.Image:
    width, height = image.size
    side = min(width, height)
    left = (width - side) // 2
    top = (height - side) // 2
    image = image.crop((left, top, left + side, top + side)).convert("RGBA")

    mask = Image.new("L", (side * ANTIALIAS_SCALE, side * ANTIALIAS_SCALE), 0)
    draw = ImageDraw.Draw(mask)
    inset = ANTIALIAS_SCALE
    draw.ellipse(
        (inset, inset, side * ANTIALIAS_SCALE - inset - 1,
         side * ANTIALIAS_SCALE - inset - 1),
        fill=255,
    )
    mask = mask.resize((side, side), Image.Resampling.LANCZOS)
    image.putalpha(mask)
    return image


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("images_dir", type=Path, help="Flutter images/menu directory")
    parser.add_argument("backup_dir", type=Path, help="New or empty directory for original PNGs")
    args = parser.parse_args()

    missing = [name for name in ICON_NAMES if not (args.images_dir / name).is_file()]
    if missing:
        parser.error(f"Missing menu icon(s): {', '.join(missing)}")
    if args.backup_dir.exists() and any(args.backup_dir.iterdir()):
        parser.error(f"Backup directory must be empty: {args.backup_dir}")

    args.backup_dir.mkdir(parents=True, exist_ok=True)
    originals = [(args.images_dir / name, args.backup_dir / name) for name in ICON_NAMES]
    changed: list[Path] = []

    try:
        for source, backup in originals:
            shutil.copy2(source, backup)
        for source, _ in originals:
            with Image.open(source) as image:
                make_circular(image).save(source, format="PNG", optimize=True)
            changed.append(source)
    except Exception as exc:
        for source, backup in originals:
            if backup.exists():
                shutil.copy2(backup, source)
        print(f"Failed to process icons; restored originals: {exc}", file=sys.stderr)
        return 1

    print(f"Rounded {len(changed)} home menu icons; originals saved to {args.backup_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
