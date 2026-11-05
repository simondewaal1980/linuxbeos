#!/usr/bin/env python3
"""Genereer de binaire BeOS-assets voor LinuxBeOS.

De bronnen van de thema-assets staan in deze repository; dit script maakt de
PNG/XPM-afbeeldingen, de Xcursor-bestanden en de achtergronden opnieuw. De
gegenereerde bestanden worden mee gecommit, zodat de ISO-build geen
renderprogramma's op de host of in de build-VM nodig heeft.

Gebruik (vanuit de projectroot):

    python3 desktop/tools/generate-assets.py

Vereist: Python 3 met Pillow, ImageMagick (convert) en xcursorgen.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
XFWM_DIR = ROOT / "desktop" / "xfwm4"
CURSOR_DIR = ROOT / "desktop" / "cursors" / "LinuxBeOS" / "cursors"
BACKGROUND_DIR = ROOT / "desktop" / "backgrounds"

# BeOS R5-palet, vrij geïnterpreteerd.
TAB_ACTIVE = (245, 230, 75, 255)
TAB_ACTIVE_HI = (255, 247, 168, 255)
TAB_ACTIVE_LO = (201, 185, 58, 255)
TAB_INACTIVE = (216, 216, 208, 255)
TAB_INACTIVE_HI = (240, 240, 235, 255)
TAB_INACTIVE_LO = (170, 170, 165, 255)
FRAME = (214, 214, 214, 255)
FRAME_HI = (247, 247, 247, 255)
FRAME_LO = (173, 173, 173, 255)
BORDER = (74, 74, 74, 255)
TEXT = (16, 16, 16, 255)
TEXT_DIM = (96, 96, 96, 255)

TOP_H = 29
SIDE_W = 5
BOTTOM_H = 5
CORNER = 16
BUTTON_W = 21
TITLE_PATH = ROOT / "config" / "project.conf"


def solid(size: tuple[int, int], color) -> Image.Image:
    return Image.new("RGBA", size, color)


def frame_side(width: int, height: int, left: bool, active: bool) -> Image.Image:
    img = Image.new("RGBA", (width, height), FRAME)
    draw = ImageDraw.Draw(img)
    cols = [BORDER, FRAME_HI, FRAME, FRAME, FRAME_LO]
    if not left:
        cols = list(reversed(cols))
    for x, color in enumerate(cols):
        draw.line([(x, 0), (x, height - 1)], fill=color)
    return img


def frame_bottom(width: int, height: int) -> Image.Image:
    img = Image.new("RGBA", (width, height), FRAME)
    draw = ImageDraw.Draw(img)
    rows = [FRAME_LO, FRAME, FRAME, FRAME, BORDER]
    for y, color in enumerate(rows):
        draw.line([(0, y), (width - 1, y)], fill=color)
    return img


def corner_bottom(size: int, right: bool) -> Image.Image:
    img = Image.new("RGBA", (size, size), FRAME)
    draw = ImageDraw.Draw(img)
    draw.line([(0, 0), (size - 1, 0)], fill=FRAME_LO)
    draw.line([(0, size - 1), (size - 1, size - 1)], fill=BORDER)
    if right:
        draw.line([(size - 1, 0), (size - 1, size - 1)], fill=BORDER)
        for i in range(4, size - 2, 4):
            draw.line([(size - i, size - 2), (size - 2, size - i)], fill=BORDER)
    else:
        draw.line([(0, 0), (0, size - 1)], fill=BORDER)
        for i in range(4, size - 2, 4):
            draw.line([(i, size - 2), (size - 2, i)], fill=BORDER)
    return img


def tab_profile(height: int, active: bool) -> list:
    hi = TAB_ACTIVE_HI if active else TAB_INACTIVE_HI
    tab = TAB_ACTIVE if active else TAB_INACTIVE
    lo = TAB_ACTIVE_LO if active else TAB_INACTIVE_LO
    rows = []
    for y in range(height):
        if y == 0:
            rows.append(BORDER)
        elif y == 1:
            rows.append(hi)
        elif y == height - 6:
            rows.append(lo)
        elif y == height - 5:
            rows.append(BORDER)
        elif y >= height - 4:
            rows.append(FRAME)
        else:
            rows.append(tab)
    return rows


def title_stretch(active: bool, width: int = 8) -> Image.Image:
    img = Image.new("RGBA", (width, TOP_H), TAB_ACTIVE if active else TAB_INACTIVE)
    draw = ImageDraw.Draw(img)
    for y, color in enumerate(tab_profile(TOP_H, active)):
        draw.line([(0, y), (width - 1, y)], fill=color)
    return img


def top_corner(active: bool, right: bool) -> Image.Image:
    img = Image.new("RGBA", (SIDE_W, TOP_H), TAB_ACTIVE if active else TAB_INACTIVE)
    draw = ImageDraw.Draw(img)
    for y, color in enumerate(tab_profile(TOP_H, active)):
        draw.line([(0, y), (SIDE_W - 1, y)], fill=color)
    # Buitenrand en highlight aan de zijkant van de tab.
    if right:
        draw.line([(SIDE_W - 1, 0), (SIDE_W - 1, TOP_H - 1)], fill=BORDER)
    else:
        draw.line([(0, 0), (0, TOP_H - 1)], fill=BORDER)
        draw.line([(1, 1), (1, TOP_H - 6)], fill=FRAME_HI)
    return img


def draw_button(symbol: str, state: str) -> Image.Image:
    """Teken een BeOS-knop in de titeltab.

    state is een van active/inactive/prelight/pressed; toggled-* valt terug
    op de bijbehorende basistoestand.
    """
    base_state = state.replace("toggled-", "")
    active = base_state != "inactive"
    tab = TAB_ACTIVE if active else TAB_INACTIVE
    hi = TAB_ACTIVE_HI if active else TAB_INACTIVE_HI
    lo = TAB_ACTIVE_LO if active else TAB_INACTIVE_LO
    fg = TEXT if active else TEXT_DIM

    if base_state == "prelight":
        box = TAB_ACTIVE_HI if active else TAB_INACTIVE_HI
    elif base_state == "pressed":
        box = TAB_ACTIVE_LO if active else TAB_INACTIVE_LO
    else:
        box = tab

    img = Image.new("RGBA", (BUTTON_W, TOP_H), tab)
    draw = ImageDraw.Draw(img)
    # Neem het verticale tabprofiel over, zodat de knop naadloos in de tab
    # valt en de grijze rand onder de tab niet wordt afgedekt.
    for y, color in enumerate(tab_profile(TOP_H, active)):
        draw.line([(0, y), (BUTTON_W - 1, y)], fill=color)
    x0, y0, x1, y1 = 2, 5, BUTTON_W - 3, TOP_H - 7
    draw.rectangle([x0, y0, x1, y1], fill=box, outline=BORDER)
    if base_state == "prelight":
        draw.line([(x0 + 1, y0 + 1), (x1 - 1, y0 + 1)], fill=hi)
    if base_state == "pressed":
        draw.line([(x0 + 1, y0 + 1), (x1 - 1, y0 + 1)], fill=lo)

    cx = (x0 + x1) // 2
    cy = (y0 + y1) // 2
    if symbol == "close":
        draw.line([(cx - 4, cy - 4), (cx + 4, cy + 4)], fill=fg, width=2)
        draw.line([(cx - 4, cy + 4), (cx + 4, cy - 4)], fill=fg, width=2)
    elif symbol == "maximize":
        draw.rectangle([cx - 4, cy - 4, cx + 4, cy + 4], outline=fg, width=2)
    elif symbol == "hide":
        draw.polygon([(cx - 5, cy - 2), (cx + 5, cy - 2), (cx, cy + 4)], fill=fg)
    elif symbol == "shade":
        draw.polygon([(cx - 5, cy + 2), (cx + 5, cy + 2), (cx, cy - 4)], fill=fg)
    elif symbol == "stick":
        draw.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=fg)
    else:  # menu
        for offset in (-4, 0, 4):
            draw.line([(cx - 5, cy + offset), (cx + 5, cy + offset)], fill=fg, width=2)
    return img


def write_xpm(png: Path) -> None:
    xpm = png.with_suffix(".xpm")
    subprocess.run(
        ["convert", str(png), str(xpm)],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def generate_xfwm4() -> None:
    if XFWM_DIR.exists():
        shutil.rmtree(XFWM_DIR)
    XFWM_DIR.mkdir(parents=True)

    images: dict[str, Image.Image] = {}
    for active in (True, False):
        suffix = "active" if active else "inactive"
        images[f"title-{suffix}-stretch"] = title_stretch(active)
        for i in range(1, 6):
            # title-2 bepaalt waar de titeltekst begint: minimaal de breedte
            # van de sluitknop, zodat de tekst niet onder de knop schuift.
            width = 24 if i == 2 else 8
            images[f"title-{i}-{suffix}"] = title_stretch(active, width=width)
        images[f"top-left-{suffix}"] = top_corner(active, right=False)
        images[f"top-right-{suffix}"] = top_corner(active, right=True)
        images[f"left-{suffix}"] = frame_side(SIDE_W, 24, left=True, active=active)
        images[f"right-{suffix}"] = frame_side(SIDE_W, 24, left=False, active=active)
        images[f"bottom-{suffix}"] = frame_bottom(32, BOTTOM_H)
        images[f"bottom-left-{suffix}"] = corner_bottom(CORNER, right=False)
        images[f"bottom-right-{suffix}"] = corner_bottom(CORNER, right=True)
        for symbol in ("menu", "stick", "shade", "hide", "maximize", "close"):
            for state in (
                "active",
                "inactive",
                "prelight",
                "pressed",
                "toggled-active",
                "toggled-inactive",
                "toggled-prelight",
                "toggled-pressed",
            ):
                images[f"{symbol}-{state}"] = draw_button(symbol, state)

    for name, image in images.items():
        png = XFWM_DIR / f"{name}.png"
        image.save(png)
        write_xpm(png)

    (XFWM_DIR / "themerc").write_text(
        "\n".join(
            [
                "# LinuxBeOS xfwm4-thema: BeOS R5-geïnspireerde titeltab.",
                "active_text_color=#101010",
                "inactive_text_color=#606060",
                "active_text_shadow_color=#fff7a8",
                "inactive_text_shadow_color=#f0f0f0",
                "button_layout=C|M",
                "button_offset=0",
                "button_spacing=0",
                "full_width_title=true",
                "title_alignment=left",
                "title_horizontal_offset=4",
                "title_vertical_offset_active=0",
                "title_vertical_offset_inactive=0",
                "title_shadow_active=false",
                "title_shadow_inactive=false",
                "show_app_icon=false",
                "frame_border_top=0",
                "maximized_offset=0",
                "",
            ]
        ),
        encoding="utf-8",
    )


def draw_arrow(size: int, kind: str) -> tuple[Image.Image, tuple[int, int]]:
    scale = size / 32.0
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    def p(points):
        return [(round(x * scale), round(y * scale)) for x, y in points]

    if kind == "left_ptr":
        pts = [(3, 2), (3, 22), (8, 17), (12, 27), (16, 25), (12, 15), (19, 15)]
        draw.polygon(p(pts), fill=(255, 255, 255, 255), outline=(255, 255, 255, 255))
        inner = [(5, 5), (5, 19), (9, 15), (13, 25), (14, 24), (11, 14), (17, 14)]
        draw.polygon(p(inner), fill=(0, 0, 0, 255), outline=(0, 0, 0, 255))
        return img, (3, 2)
    if kind == "hand2":
        draw.rectangle(p([(10, 12), (22, 26)]), fill=(255, 255, 255, 255), outline=(0, 0, 0, 255))
        draw.rectangle(p([(12, 14), (20, 25)]), fill=(245, 230, 75, 255))
        return img, (16, 12)
    if kind == "xterm":
        draw.rectangle(p([(14, 6), (17, 26)]), fill=(255, 255, 255, 255), outline=(0, 0, 0, 255))
        draw.line(p([(12, 7), (19, 7)]), fill=(0, 0, 0, 255))
        draw.line(p([(12, 25), (19, 25)]), fill=(0, 0, 0, 255))
        return img, (15, 16)
    if kind == "crosshair":
        draw.line(p([(16, 4), (16, 28)]), fill=(0, 0, 0, 255), width=2)
        draw.line(p([(4, 16), (28, 16)]), fill=(0, 0, 0, 255), width=2)
        draw.ellipse(p([(12, 12), (20, 20)]), outline=(0, 0, 0, 255), width=2)
        return img, (16, 16)
    if kind == "fleur":
        draw.line(p([(16, 4), (16, 28)]), fill=(0, 0, 0, 255), width=2)
        draw.line(p([(4, 16), (28, 16)]), fill=(0, 0, 0, 255), width=2)
        for dx, dy in ((0, -10), (0, 10), (-10, 0), (10, 0)):
            draw.polygon(
                p(
                    [
                        (16 + dx, 16 + dy),
                        (13 + dx // 2, 16 + dy // 2),
                        (19 + dx // 2, 16 + dy // 2),
                    ]
                ),
                fill=(0, 0, 0, 255),
            )
        return img, (16, 16)
    raise ValueError(kind)


def generate_cursors() -> None:
    if CURSOR_DIR.parent.exists():
        shutil.rmtree(CURSOR_DIR.parent)
    CURSOR_DIR.mkdir(parents=True)
    tmp = ROOT / "desktop" / "cursors" / ".tmp"
    if tmp.exists():
        shutil.rmtree(tmp)
    tmp.mkdir(parents=True)

    kinds = ["left_ptr", "hand2", "xterm", "crosshair", "fleur"]
    for kind in kinds:
        cfg_lines = []
        for size in (24, 32, 48):
            img, hotspot = draw_arrow(size, kind)
            path = tmp / f"{kind}-{size}.png"
            img.save(path)
            cfg_lines.append(f"{size} {hotspot[0]} {hotspot[1]} {path} 0")
        config = tmp / f"{kind}.cfg"
        config.write_text("\n".join(cfg_lines) + "\n", encoding="utf-8")
        subprocess.run(
            ["xcursorgen", str(config), str(CURSOR_DIR / kind)],
            check=True,
        )

    # Dezelfde vorm voor de gangbare aliassen; Xcursor kent geen
    # harde eisen aan de naam, maar applicaties vragen verschillende namen.
    aliases = {
        "default": "left_ptr",
        "arrow": "left_ptr",
        "top_left_arrow": "left_ptr",
        "left_ptr_watch": "left_ptr",
        "right_ptr": "left_ptr",
        "hand1": "hand2",
        "pointer": "hand2",
        "question_arrow": "left_ptr",
        "context-menu": "left_ptr",
        "text": "xterm",
        "vertical-text": "xterm",
        "cross": "crosshair",
        "cross_reverse": "crosshair",
        "tcross": "crosshair",
        "move": "fleur",
        "all-scroll": "fleur",
        "size_all": "fleur",
        "watch": "left_ptr",
        "progress": "left_ptr",
        "wait": "left_ptr",
        "not-allowed": "left_ptr",
        "no-drop": "left_ptr",
        "help": "left_ptr",
        "openhand": "hand2",
        "closedhand": "hand2",
        "dnd-none": "hand2",
        "dnd-copy": "hand2",
        "dnd-link": "hand2",
        "dnd-move": "hand2",
    }
    for alias, target in aliases.items():
        dst = CURSOR_DIR / alias
        if dst.exists():
            dst.unlink()
        os.symlink(target, dst)

    (CURSOR_DIR.parent / "cursor.theme").write_text(
        "\n".join(
            [
                "[Icon Theme]",
                "Name=LinuxBeOS",
                "Comment=BeOS-geinspireerde cursors voor LinuxBeOS",
                "Inherits=Adwaita",
                "",
            ]
        ),
        encoding="utf-8",
    )

    shutil.rmtree(tmp)


def font(size: int, bold: bool = True) -> ImageFont.FreeTypeFont:
    candidates = [
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ]
    if not bold:
        candidates = [
            "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        ]
    for candidate in candidates:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default()


def generate_wallpaper() -> None:
    BACKGROUND_DIR.mkdir(parents=True, exist_ok=True)
    width, height = 1920, 1080
    img = Image.new("RGB", (width, height))
    draw = ImageDraw.Draw(img)
    top = (8, 34, 74)
    bottom = (24, 78, 145)
    for y in range(height):
        ratio = y / (height - 1)
        color = tuple(round(top[i] + (bottom[i] - top[i]) * ratio) for i in range(3))
        draw.line([(0, y), (width - 1, y)], fill=color)

    # Subtiele diagonale lijnen, geïnspireerd op het BeOS-bureaublad.
    for offset in range(-height, width, 80):
        draw.line([(offset, height), (offset + height, 0)], fill=(30, 90, 160), width=1)

    # Gele tab met eigen wordmark (geen BeOS/Haiku-logo).
    tab_w, tab_h = 620, 92
    x0, y0 = 80, height - tab_h - 80
    draw.rectangle([x0, y0, x0 + tab_w, y0 + tab_h], fill=(245, 230, 75))
    draw.rectangle([x0, y0, x0 + tab_w, y0 + 6], fill=(255, 247, 168))
    draw.rectangle([x0, y0 + tab_h - 6, x0 + tab_w, y0 + tab_h], fill=(201, 185, 58))
    draw.rectangle([x0, y0, x0 + tab_w, y0 + tab_h], outline=(74, 74, 74), width=3)
    draw.text((x0 + 28, y0 + 18), "LinuxBeOS", font=font(40), fill=(16, 16, 16))
    draw.text((x0 + 30, y0 + 64), "open desktop, BeOS-geest", font=font(18, bold=False), fill=(50, 45, 20))

    # Discrete monitor-achtige vorm rechtsboven.
    draw.rectangle([width - 420, 80, width - 80, 300], fill=(20, 62, 118), outline=(120, 170, 220), width=2)
    draw.rectangle([width - 400, 100, width - 100, 260], fill=(226, 232, 240), outline=(74, 74, 74), width=2)
    draw.rectangle([width - 400, 100, width - 100, 124], fill=(245, 230, 75), outline=(74, 74, 74), width=1)
    draw.text((width - 380, 130), "Welcome to LinuxBeOS", font=font(22), fill=(16, 16, 16))

    img.save(BACKGROUND_DIR / "linuxbeos-wallpaper.png", optimize=True)

    # Greeter-versie: dezelfde achtergrond met gecentreerde merknaam.
    greeter = img.copy()
    gdraw = ImageDraw.Draw(greeter)
    gdraw.text((width // 2 - 220, height // 2 - 60), "LinuxBeOS", font=font(72), fill=(255, 255, 255))
    gdraw.rectangle([width // 2 - 230, height // 2 + 40, width // 2 + 230, height // 2 + 52], fill=(245, 230, 75))
    greeter.save(BACKGROUND_DIR / "linuxbeos-greeter.png", optimize=True)


def main() -> int:
    if not TITLE_PATH.exists():
        print("WAARSCHUWING: config/project.conf niet gevonden", file=sys.stderr)
    for tool in ("convert", "xcursorgen"):
        if shutil.which(tool) is None:
            print(f"FOUT: {tool} ontbreekt", file=sys.stderr)
            return 1
    print("xfwm4-assets genereren ...")
    generate_xfwm4()
    print("cursors genereren ...")
    generate_cursors()
    print("achtergronden genereren ...")
    generate_wallpaper()
    print("klaar")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
