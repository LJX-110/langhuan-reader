"""Generate the 琅嬛阁 app icon and launch mark.

Direction B · 月牙与檐: an ink field, a moon-white crescent, and one moon-white
eave stroke. Only two colours, no gradient, shadow, text or pavilion detail.
The mark is drawn at 4x and downsampled so every density keeps clean edges,
including the 48 px legacy icon.

Android 12+ splash animation lives in
`android/app/src/main/res/drawable/launch_mark_animated.xml`; the vector and
this raster script must keep the same geometry.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]

INK = (23, 40, 58, 255)          # #17283A 墨
MOON = (242, 233, 215, 255)      # #F2E9D7 月白
CLEAR = (0, 0, 0, 0)
WHITE = (255, 255, 255, 255)

MIPMAPS = {
    "mdpi": (48, 108),
    "hdpi": (72, 162),
    "xhdpi": (96, 216),
    "xxhdpi": (144, 324),
    "xxxhdpi": (192, 432),
}

# 1024 x 1024 design box.
MOON_CENTER = (470, 400)
MOON_RADIUS = 300
CUT_CENTER = (596, 330)
CUT_RADIUS = 268

# 一笔屋檐：平脊，两端起翘；落在月牙下方。
EAVE = ((210, 792), (424, 744), (600, 744), (814, 792))
EAVE_WIDTH = 58


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

    def points(self, points: tuple[tuple[float, float], ...]) -> list[tuple[float, float]]:
        return [self.xy(x, y) for x, y in points]

    def radius(self, value: float) -> float:
        return value * self.scale * self.unit

    def width(self, value: float) -> int:
        return max(1, round(value * self.scale * self.unit))


def _draw_mark(
    draw: ImageDraw.ImageDraw,
    pen: _Pen,
    *,
    moon_fill: tuple[int, int, int, int],
    cut_fill: tuple[int, int, int, int],
    eave_fill: tuple[int, int, int, int],
) -> None:
    cx, cy = pen.xy(*MOON_CENTER)
    r = pen.radius(MOON_RADIUS)
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=moon_fill)
    # 月牙 = 月盘减去右上方的圆；有底色时用底色，无底色时用透明。
    cx, cy = pen.xy(*CUT_CENTER)
    r = pen.radius(CUT_RADIUS)
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=cut_fill)
    draw.line(
        pen.points(EAVE),
        fill=eave_fill,
        width=pen.width(EAVE_WIDTH),
        joint="curve",
    )


def _render(
    size: int,
    *,
    scale: float = 1.0,
    circular: bool = False,
    background: bool = True,
    mono: bool = False,
    inverted: bool = False,
) -> Image.Image:
    pen = _Pen(size, scale)
    canvas = Image.new("RGBA", (pen.canvas, pen.canvas), CLEAR)
    draw = ImageDraw.Draw(canvas)

    if background:
        field = INK
        if circular:
            draw.ellipse((0, 0, pen.canvas - 1, pen.canvas - 1), fill=field)
        else:
            draw.rounded_rectangle(
                (0, 0, pen.canvas - 1, pen.canvas - 1),
                radius=round(pen.canvas * 0.215),
                fill=field,
            )

    if mono:
        # Android 主题图标只取 alpha：月牙 + 屋檐合成单色剪影。
        _draw_mark(draw, pen, moon_fill=WHITE, cut_fill=CLEAR, eave_fill=WHITE)
    elif inverted:
        # 启动页在纸白底上：墨色月牙 + 墨色屋檐，切割处透明。
        _draw_mark(draw, pen, moon_fill=INK, cut_fill=CLEAR, eave_fill=INK)
    elif background:
        _draw_mark(draw, pen, moon_fill=MOON, cut_fill=INK, eave_fill=MOON)
    else:
        # 自适应前景：切割处透明，底色层由 @color/brand_deep 提供。
        _draw_mark(draw, pen, moon_fill=MOON, cut_fill=CLEAR, eave_fill=MOON)
    return canvas.resize((size, size), Image.LANCZOS)


def _icon(size: int = 1024, circular: bool = False) -> Image.Image:
    return _render(size, circular=circular)


def _foreground(size: int = 1024) -> Image.Image:
    # Adaptive foregrounds are cropped to the 66/108 safe zone; 0.78 keeps the
    # crescent and eave inside it while leaving the mark large enough to read.
    return _render(size, scale=0.78, background=False)


def _monochrome(size: int = 1024) -> Image.Image:
    return _render(size, scale=0.78, background=False, mono=True)


def _splash(size: int = 512) -> Image.Image:
    # Transparent mark for the paper-white launch screen, no solid field.
    return _render(size, scale=0.62, background=False, inverted=True)


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
