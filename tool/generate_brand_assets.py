"""Generate the 琅嬛阁 app icon and launch mark.

Direction C · 月照琅嬛: a deep ink field, a moon-white disc, and a single
dark-gold pavilion. The mark is drawn at 4x and downsampled so every density
keeps clean edges, including the 48 px legacy icon.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]

INK = (23, 40, 58, 255)          # #17283A 墨蓝
MOON = (242, 233, 215, 255)      # #F2E9D7 月白
GOLD = (184, 154, 104, 255)      # #B89A68 柔金
CLEAR = (0, 0, 0, 0)
WHITE = (255, 255, 255, 255)

MIPMAPS = {
    "mdpi": (48, 108),
    "hdpi": (72, 162),
    "xhdpi": (96, 216),
    "xxhdpi": (144, 324),
    "xxxhdpi": (192, 432),
}

# Composition geometry in a 1024 x 1024 design box.
ROOF_TIPS = ((128, 620), (896, 620))
MOON_CENTER = (512, 410)
MOON_RADIUS = 238


def _cubic(
    start: tuple[float, float],
    control1: tuple[float, float],
    control2: tuple[float, float],
    end: tuple[float, float],
    steps: int = 24,
) -> list[tuple[float, float]]:
    points = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        x = (
            u**3 * start[0]
            + 3 * u**2 * t * control1[0]
            + 3 * u * t**2 * control2[0]
            + t**3 * end[0]
        )
        y = (
            u**3 * start[1]
            + 3 * u**2 * t * control1[1]
            + 3 * u * t**2 * control2[1]
            + t**3 * end[1]
        )
        points.append((x, y))
    return points


def _roof_points() -> list[tuple[float, float]]:
    """Single-eave roof with upturned tips and a flat ridge."""
    points = _cubic((128, 620), (240, 620), (300, 575), (356, 520))
    points += [(400, 500), (624, 500), (668, 520)]
    points += _cubic((668, 520), (724, 575), (784, 620), (896, 620))
    points += _cubic((896, 620), (820, 665), (730, 680), (640, 680))
    points += [(384, 680)]
    points += _cubic((384, 680), (294, 680), (204, 665), (128, 620))
    return points


class _Pen:
    """Maps 1024-box coordinates onto a 4x render canvas."""

    def __init__(self, size: int, scale: float):
        self.size = size
        self.scale = scale
        self.supersample = 4
        self.canvas = size * self.supersample
        self.unit = self.canvas / 1024

    def xy(self, x: float, y: float) -> tuple[float, float]:
        return (
            (512 + (x - 512) * self.scale) * self.unit,
            (512 + (y - 512) * self.scale) * self.unit,
        )

    def points(self, points: list[tuple[float, float]]) -> list[tuple[float, float]]:
        return [self.xy(x, y) for x, y in points]

    def width(self, width: float) -> int:
        return max(1, round(width * self.scale * self.unit))


def _draw_pavilion(
    draw: ImageDraw.ImageDraw,
    pen: _Pen,
    *,
    simplify: bool,
    mono: bool = False,
    draw_moon: bool = True,
) -> None:
    roof_fill = WHITE if mono else INK
    body_fill = WHITE if mono else INK
    line_fill = WHITE if mono else GOLD
    door_fill = CLEAR if mono else GOLD

    if draw_moon:
        cx, cy = pen.xy(*MOON_CENTER)
        radius = MOON_RADIUS * pen.scale * pen.unit
        draw.ellipse(
            (cx - radius, cy - radius, cx + radius, cy + radius),
            fill=WHITE if mono else MOON,
        )

    roof = pen.points(_roof_points())
    draw.polygon(roof, fill=roof_fill)
    # Draw the closed outline in two passes; PIL leaves a small notch where the
    # first and last segments meet at the sharp left eave tip.
    draw.line(roof, fill=line_fill, width=pen.width(14), joint="curve")
    draw.line(
        [roof[-1], roof[0], roof[1]],
        fill=line_fill,
        width=pen.width(14),
        joint="curve",
    )

    # Ridge finial: a small diamond, still visible as a gold dot at 48 px.
    finial = pen.points([(512, 472), (530, 490), (512, 508), (494, 490)])
    draw.polygon(finial, fill=line_fill)

    body = [pen.xy(340, 680), pen.xy(684, 840)]
    draw.rectangle(body, fill=body_fill)
    draw.rectangle(body, outline=line_fill, width=pen.width(12))

    if not simplify:
        for x in (400, 624):
            draw.line(
                [pen.xy(x, 680), pen.xy(x, 840)],
                fill=door_fill if mono else line_fill,
                width=pen.width(8),
            )

    # Door: a solid gold spine in colour, an opening in monochrome.
    draw.rectangle(
        [pen.xy(476, 716), pen.xy(548, 840)],
        fill=door_fill,
    )

    draw.line(
        [pen.xy(270, 858), pen.xy(754, 858)],
        fill=line_fill,
        width=pen.width(14),
    )
    if not simplify:
        draw.line(
            [pen.xy(310, 880), pen.xy(714, 880)],
            fill=line_fill,
            width=pen.width(8),
        )


def _render(
    size: int,
    *,
    scale: float = 1.0,
    circular: bool = False,
    background: bool = True,
    mono: bool = False,
    draw_moon: bool = True,
    simplify: bool | None = None,
) -> Image.Image:
    pen = _Pen(size, scale)
    canvas = Image.new("RGBA", (pen.canvas, pen.canvas), CLEAR)
    draw = ImageDraw.Draw(canvas)

    if background:
        if circular:
            draw.ellipse((0, 0, pen.canvas - 1, pen.canvas - 1), fill=INK)
        else:
            draw.rounded_rectangle(
                (0, 0, pen.canvas - 1, pen.canvas - 1),
                radius=round(pen.canvas * 0.215),
                fill=INK,
            )

    if simplify is None:
        simplify = size <= 96
    _draw_pavilion(
        draw,
        pen,
        simplify=simplify,
        mono=mono,
        draw_moon=draw_moon,
    )
    return canvas.resize((size, size), Image.LANCZOS)


def _icon(size: int = 1024, circular: bool = False) -> Image.Image:
    return _render(size, circular=circular)


def _foreground(size: int = 1024) -> Image.Image:
    # Adaptive foregrounds are cropped to the 66/108 safe zone; 0.78 keeps the
    # eave tips inside it while leaving the mark large enough to read.
    return _render(size, scale=0.78, background=False)


def _monochrome(size: int = 1024) -> Image.Image:
    return _render(
        size,
        scale=0.78,
        background=False,
        mono=True,
        draw_moon=False,
    )


def _splash(size: int = 512) -> Image.Image:
    # Inverted mark for the paper-white launch screen: a gold moon ring and an
    # ink pavilion, no solid field.
    canvas = Image.new("RGBA", (2048, 2048), CLEAR)
    draw = ImageDraw.Draw(canvas)
    pen = _Pen(512, 0.62)
    # _Pen renders at 4x; use the same helper on the 512 design box.
    ring = pen.xy(512, 512)
    radius = 360 * pen.scale * pen.unit
    draw.ellipse(
        (ring[0] - radius, ring[1] - radius, ring[0] + radius, ring[1] + radius),
        outline=GOLD,
        width=pen.width(8),
    )
    _draw_pavilion(draw, pen, simplify=False, draw_moon=False)
    return canvas.resize((size, size), Image.LANCZOS)


def main() -> None:
    brand = ROOT / "assets" / "brand"
    brand.mkdir(parents=True, exist_ok=True)

    _icon().save(brand / "icon_master.png")
    _foreground().save(brand / "icon_foreground.png")
    _splash().save(brand / "launch_logo.png")

    for density, (icon_size, fg_size) in MIPMAPS.items():
        out = ROOT / "android" / "app" / "src" / "main" / "res" / f"mipmap-{density}"
        out.mkdir(parents=True, exist_ok=True)
        _icon(icon_size).save(out / "ic_launcher.png")
        _icon(icon_size, circular=True).save(out / "ic_launcher_round.png")
        _foreground(fg_size).save(out / "ic_launcher_foreground.png")
        _monochrome(fg_size).save(out / "ic_launcher_monochrome.png")

    nodpi = ROOT / "android" / "app" / "src" / "main" / "res" / "drawable-nodpi"
    nodpi.mkdir(parents=True, exist_ok=True)
    _splash().save(nodpi / "launch_logo.png")

    print("brand assets written")


if __name__ == "__main__":
    main()
