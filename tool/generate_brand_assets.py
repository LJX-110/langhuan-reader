"""Generate the temporary 琅嬛阁 brand assets.

Placeholder visual identity: paper field, ink character, restrained seal-red
accent. Replace with final artwork once a visual reference is chosen.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
FONT = Path(r"C:\Windows\Fonts\STSONG.TTF")
FALLBACK = Path(r"C:\Windows\Fonts\simsun.ttc")
PAPER = (244, 239, 229, 255)
INK = (43, 39, 35, 255)
INK_SOFT = (43, 39, 35, 170)
SEAL = (143, 58, 46, 255)

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


def draw_character(canvas: Image.Image, size: int, color=INK) -> None:
    draw = ImageDraw.Draw(canvas)
    font = get_font(int(size * 0.62))
    text = "琅"
    box = draw.textbbox((0, 0), text, font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    x = (size - w) / 2 - box[0]
    y = (size - h) / 2 - box[1] - size * 0.02
    draw.text((x, y), text, font=font, fill=color)


def rounded_icon(size: int) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    radius = int(size * 0.22)
    draw.rounded_rectangle(
        (0, 0, size - 1, size - 1),
        radius=radius,
        fill=PAPER,
    )
    inset = int(size * 0.055)
    draw.rounded_rectangle(
        (inset, inset, size - 1 - inset, size - 1 - inset),
        radius=max(4, radius - inset // 2),
        outline=INK_SOFT,
        width=max(1, int(size * 0.006)),
    )
    # Small seal-red mark: quiet, readable even at 48 px.
    seal = int(size * 0.075)
    sx = size - inset - seal - int(size * 0.035)
    sy = size - inset - seal - int(size * 0.035)
    draw.rounded_rectangle(
        (sx, sy, sx + seal, sy + seal),
        radius=max(2, seal // 4),
        fill=SEAL,
    )
    draw_character(image, size)
    return image


def round_icon(size: int) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.ellipse((0, 0, size - 1, size - 1), fill=PAPER)
    inset = int(size * 0.055)
    draw.ellipse(
        (inset, inset, size - 1 - inset, size - 1 - inset),
        outline=INK_SOFT,
        width=max(1, int(size * 0.006)),
    )
    seal = int(size * 0.075)
    sx = int(size * 0.70)
    sy = int(size * 0.70)
    draw.rounded_rectangle(
        (sx, sy, sx + seal, sy + seal),
        radius=max(2, seal // 4),
        fill=SEAL,
    )
    draw_character(image, size)
    return image


def foreground(size: int) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw_character(image, size)
    draw = ImageDraw.Draw(image)
    seal = int(size * 0.055)
    sx = int(size * 0.69)
    sy = int(size * 0.73)
    draw.rounded_rectangle(
        (sx, sy, sx + seal, sy + seal),
        radius=max(2, seal // 4),
        fill=SEAL,
    )
    return image


def main() -> None:
    brand = ROOT / "assets" / "brand"
    brand.mkdir(parents=True, exist_ok=True)

    master = rounded_icon(1024)
    master.save(brand / "icon_master.png")
    foreground(1024).save(brand / "icon_foreground.png")

    launch = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    draw_character(launch, 512)
    launch.save(brand / "launch_logo.png")

    for density, (icon_size, fg_size) in MIPMAPS.items():
        out = ROOT / "android" / "app" / "src" / "main" / "res" / f"mipmap-{density}"
        out.mkdir(parents=True, exist_ok=True)
        rounded_icon(icon_size).save(out / "ic_launcher.png")
        round_icon(icon_size).save(out / "ic_launcher_round.png")
        foreground(fg_size).save(out / "ic_launcher_foreground.png")

    nodpi = ROOT / "android" / "app" / "src" / "main" / "res" / "drawable-nodpi"
    nodpi.mkdir(parents=True, exist_ok=True)
    launch.resize((256, 256), Image.LANCZOS).save(nodpi / "launch_logo.png")

    print("brand assets written")


if __name__ == "__main__":
    main()
