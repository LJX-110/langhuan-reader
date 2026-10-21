"""Generate the final 琅嬛阁 app icon and launch mark.

Direction A · 墨玉书函: a dark jade book case, a cream title slip with the
character 琅, a green bookmark, and a cinnabar seal. The mark is drawn once at
1024 px and downsampled so every density keeps the same proportions.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
FONT = Path(r"C:\Windows\Fonts\STSONG.TTF")
FALLBACK = Path(r"C:\Windows\Fonts\simsun.ttc")

PAPER = (243, 241, 234, 255)
PAPER_LIGHT = (250, 248, 242, 255)
PAPER_DEEP = (230, 225, 213, 255)
INK = (31, 30, 27, 255)
INK_SOFT = (94, 89, 79, 255)
CREAM = (233, 224, 201, 255)
CREAM_DEEP = (213, 201, 174, 255)
SEAL = (154, 59, 46, 255)
JADE = (47, 74, 69, 255)
JADE_LIGHT = (70, 101, 94, 255)
JADE_DARK = (20, 33, 29, 255)
JADE_BLACK = (13, 24, 21, 255)

MIPMAPS = {
    "mdpi": (48, 108),
    "hdpi": (72, 162),
    "xhdpi": (96, 216),
    "xxhdpi": (144, 324),
    "xxxhdpi": (192, 432),
}


def get_font(size: int) -> ImageFont.FreeTypeFont:
    path = FONT if FONT.exists() else FALLBACK
    return ImageFont.truetype(str(path), size)


def vertical_gradient(size: int, top: tuple[int, int, int, int],
                      bottom: tuple[int, int, int, int]) -> Image.Image:
    image = Image.new("RGBA", (size, size), top)
    draw = ImageDraw.Draw(image)
    for y in range(size):
        t = y / max(1, size - 1)
        color = tuple(
            int(top[i] + (bottom[i] - top[i]) * t) for i in range(4)
        )
        draw.line((0, y, size, y), fill=color)
    return image


def center_text(
    draw: ImageDraw.ImageDraw,
    text: str,
    cx: float,
    cy: float,
    font: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int, int],
) -> None:
    box = draw.textbbox((0, 0), text, font=font)
    x = cx - (box[2] - box[0]) / 2 - box[0]
    y = cy - (box[3] - box[1]) / 2 - box[1]
    draw.text((x, y), text, font=font, fill=fill)


def mark_layer(size: int = 1024, ink: bool = False) -> Image.Image:
    """Transparent book-case mark at native 1024 proportions."""
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    s = size / 1024
    case = INK if ink else CREAM
    case_soft = (31, 30, 27, 95) if ink else (233, 224, 201, 95)
    label_fill = PAPER_LIGHT if ink else CREAM
    label_border = PAPER_DEEP if ink else CREAM_DEEP
    bookmark = JADE if ink else JADE_LIGHT
    label_shadow = (0, 0, 0, 0) if ink else (0, 0, 0, 62)

    def box(x1, y1, x2, y2):
        return (x1 * s, y1 * s, x2 * s, y2 * s)

    # Outer case and the thin inner rule.
    draw.rounded_rectangle(
        box(176, 150, 848, 874),
        radius=22 * s,
        outline=case,
        width=max(1, round(12 * s)),
    )
    draw.rounded_rectangle(
        box(208, 182, 816, 842),
        radius=14 * s,
        outline=case_soft,
        width=max(1, round(3 * s)),
    )

    # The title slip sits inside the case with a barely-there shadow.
    if not ink:
        draw.rounded_rectangle(
            box(402, 232, 634, 796),
            radius=4 * s,
            fill=label_shadow,
        )
    draw.rectangle(
        box(594, 176, 636, 430),
        fill=bookmark,
    )
    draw.polygon(
        [
            (594 * s, 430 * s),
            (636 * s, 430 * s),
            (615 * s, 458 * s),
        ],
        fill=bookmark,
    )
    draw.rounded_rectangle(
        box(396, 226, 628, 790),
        radius=4 * s,
        fill=label_fill,
        outline=label_border,
        width=max(1, round(3 * s)),
    )
    draw.line(
        box(410, 244, 614, 244),
        fill=(255, 255, 255, 60) if not ink else (255, 255, 255, 0),
        width=max(1, round(1 * s)),
    )
    # The bookmark runs down the right edge of the slip. Keep it narrow so it
    # reads as a ribbon, not a second panel.
    draw.rectangle(box(610, 176, 628, 408), fill=bookmark)
    draw.polygon(
        [
            (610 * s, 408 * s),
            (628 * s, 408 * s),
            (619 * s, 430 * s),
        ],
        fill=bookmark,
    )

    # A single character is the clearest mark at launcher sizes.
    center_text(
        draw,
        "琅",
        506 * s,
        448 * s,
        get_font(max(1, round(172 * s))),
        INK,
    )
    center_text(
        draw,
        "嬛阁",
        506 * s,
        606 * s,
        get_font(max(1, round(31 * s))),
        INK,
    )

    # Clasps; they read as two small paper tabs at 48 px.
    for x1, x2 in ((154, 186), (838, 870)):
        draw.rounded_rectangle(
            box(x1, 438, x2, 584),
            radius=7 * s,
            fill=CREAM_DEEP if not ink else INK,
            outline=case,
            width=max(1, round(2 * s)),
        )
        draw.line(
            box(x1 + 10, 462, x2 - 10, 462),
            fill=case_soft,
            width=max(1, round(2 * s)),
        )

    # Cinnabar seal at the lower right of the title slip.
    draw.rounded_rectangle(
        box(690, 704, 772, 786),
        radius=3 * s,
        fill=SEAL,
    )
    draw.rounded_rectangle(
        box(699, 713, 763, 777),
        radius=1 * s,
        outline=CREAM,
        width=max(1, round(2 * s)),
    )
    center_text(
        draw,
        "阁",
        731 * s,
        745 * s,
        get_font(max(1, round(38 * s))),
        CREAM,
    )
    return image


def legacy_icon(size: int = 1024) -> Image.Image:
    base = vertical_gradient(size, JADE_DARK, JADE_BLACK)
    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(
        (0, 0, size - 1, size - 1),
        radius=round(size * 0.215),
        fill=255,
    )
    base.putalpha(mask)

    # A quiet inner rim keeps the icon from looking like a flat dark tile.
    border = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    border_draw = ImageDraw.Draw(border)
    border_draw.rounded_rectangle(
        (round(size * 0.035), round(size * 0.035),
         size - round(size * 0.035), size - round(size * 0.035)),
        radius=round(size * 0.18),
        outline=(214, 199, 171, 40),
        width=max(1, round(size * 0.0025)),
    )
    base = Image.alpha_composite(base, border)
    base = Image.alpha_composite(base, mark_layer(size))
    return base


def round_icon(size: int = 1024) -> Image.Image:
    base = vertical_gradient(size, JADE_DARK, JADE_BLACK)
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((0, 0, size - 1, size - 1), fill=255)
    base.putalpha(mask)
    base = Image.alpha_composite(base, mark_layer(size))
    return base


def foreground(size: int) -> Image.Image:
    return mark_layer(size)


def splash_mark(size: int = 512) -> Image.Image:
    return mark_layer(size, ink=True)


def main() -> None:
    brand = ROOT / "assets" / "brand"
    brand.mkdir(parents=True, exist_ok=True)

    master = legacy_icon(1024)
    master.save(brand / "icon_master.png")
    foreground(1024).save(brand / "icon_foreground.png")
    splash_mark(512).save(brand / "launch_logo.png")

    for density, (icon_size, fg_size) in MIPMAPS.items():
        out = ROOT / "android" / "app" / "src" / "main" / "res" / f"mipmap-{density}"
        out.mkdir(parents=True, exist_ok=True)
        master.resize((icon_size, icon_size), Image.LANCZOS).save(
            out / "ic_launcher.png"
        )
        round_icon(1024).resize((icon_size, icon_size), Image.LANCZOS).save(
            out / "ic_launcher_round.png"
        )
        foreground(1024).resize((fg_size, fg_size), Image.LANCZOS).save(
            out / "ic_launcher_foreground.png"
        )

    nodpi = ROOT / "android" / "app" / "src" / "main" / "res" / "drawable-nodpi"
    nodpi.mkdir(parents=True, exist_ok=True)
    splash_mark(512).save(nodpi / "launch_logo.png")

    print("brand assets written")


if __name__ == "__main__":
    main()
