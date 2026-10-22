"""Generate the 琅嬛阁 app icon and launch mark.

Direction B · 双页书: a deep 碧海青 field, an open book in cool white, and one
鎏金 seal. The mark is drawn once at 1024 px and downsampled so every density
keeps the same proportions.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]

DEEP = (20, 80, 91, 255)        # #14505B 碧海青
PAGE = (244, 248, 247, 255)     # #F4F8F7 cool white
SHADOW = (4, 30, 35, 70)
GOLD = (201, 162, 75, 255)      # #C9A24B 鎏金

MIPMAPS = {
    "mdpi": (48, 108),
    "hdpi": (72, 162),
    "xhdpi": (96, 216),
    "xxhdpi": (144, 324),
    "xxxhdpi": (192, 432),
}


def _quadratic(
    start: tuple[float, float],
    control: tuple[float, float],
    end: tuple[float, float],
    steps: int = 18,
) -> list[tuple[float, float]]:
    points = []
    for i in range(steps + 1):
        t = i / steps
        x = (1 - t) ** 2 * start[0] + 2 * (1 - t) * t * control[0] + t**2 * end[0]
        y = (1 - t) ** 2 * start[1] + 2 * (1 - t) * t * control[1] + t**2 * end[1]
        points.append((x, y))
    return points


def _page(mirror: bool = False) -> list[tuple[float, float]]:
    """One open page: a V-shaped wedge with a curved outer edge and spine."""
    points = _quadratic((512, 430), (390, 398), (252, 380))
    points += _quadratic((252, 380), (232, 500), (252, 620))
    points += _quadratic((252, 620), (390, 662), (512, 690))
    if mirror:
        points = [(1024 - x, y) for x, y in points]
    return points


def _draw_book(
    draw: ImageDraw.ImageDraw,
    page_fill: tuple[int, int, int, int],
    spine_fill: tuple[int, int, int, int],
    seal_fill: tuple[int, int, int, int],
    seal_inner: tuple[int, int, int, int],
) -> None:
    left = _page()
    right = _page(mirror=True)

    for outline in (left, right):
        draw.polygon([(x, y + 14) for x, y in outline], fill=SHADOW)

    for outline in (left, right):
        draw.polygon(outline, fill=page_fill)

    # A gold outer edge and a single spine keep the mark clean at 48 px.
    for edge in (
        _quadratic((252, 380), (232, 500), (252, 620)),
        _quadratic((772, 380), (792, 500), (772, 620)),
    ):
        draw.line(edge, fill=GOLD, width=3, joint="curve")
    draw.line([(512, 432), (512, 688)], fill=spine_fill, width=5)

    draw.rounded_rectangle((632, 470, 696, 534), radius=6, fill=seal_fill)
    draw.rounded_rectangle(
        (640, 478, 688, 526),
        radius=3,
        outline=seal_inner,
        width=4,
    )


def _icon(size: int = 1024, circular: bool = False) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    if circular:
        draw.ellipse((0, 0, size - 1, size - 1), fill=DEEP)
    else:
        draw.rounded_rectangle(
            (0, 0, size - 1, size - 1),
            radius=round(size * 0.215),
            fill=DEEP,
        )
    _draw_book(draw, PAGE, DEEP, GOLD, DEEP)
    return image


def _foreground(size: int = 1024) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    _draw_book(ImageDraw.Draw(image), PAGE, DEEP, GOLD, DEEP)
    return image


def _splash(size: int = 512) -> Image.Image:
    image = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    _draw_book(ImageDraw.Draw(image), DEEP, GOLD, GOLD, DEEP)
    return image.resize((size, size), Image.LANCZOS)


def main() -> None:
    brand = ROOT / "assets" / "brand"
    brand.mkdir(parents=True, exist_ok=True)

    master = _icon()
    master.save(brand / "icon_master.png")
    _foreground().save(brand / "icon_foreground.png")
    _splash().save(brand / "launch_logo.png")

    for density, (icon_size, fg_size) in MIPMAPS.items():
        out = ROOT / "android" / "app" / "src" / "main" / "res" / f"mipmap-{density}"
        out.mkdir(parents=True, exist_ok=True)
        master.resize((icon_size, icon_size), Image.LANCZOS).save(
            out / "ic_launcher.png"
        )
        _icon(circular=True).resize((icon_size, icon_size), Image.LANCZOS).save(
            out / "ic_launcher_round.png"
        )
        _foreground().resize((fg_size, fg_size), Image.LANCZOS).save(
            out / "ic_launcher_foreground.png"
        )

    nodpi = ROOT / "android" / "app" / "src" / "main" / "res" / "drawable-nodpi"
    nodpi.mkdir(parents=True, exist_ok=True)
    _splash().save(nodpi / "launch_logo.png")

    print("brand assets written")


if __name__ == "__main__":
    main()
