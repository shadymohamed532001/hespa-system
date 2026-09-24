#!/usr/bin/env python3
"""Generate 16:9 Arabic promo slides for the Hesba website video."""

from __future__ import annotations

import sys
from pathlib import Path

import arabic_reshaper
from bidi.algorithm import get_display
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps


WIDTH = 1920
HEIGHT = 1080
NAVY = "#102f3e"
NAVY_DARK = "#09242f"
INK = "#173443"
TEAL = "#0b8c7e"
TEAL_DARK = "#08776b"
TEAL_LIGHT = "#e4f5f1"
MUTED = "#718792"
BG = "#f4f7f8"
WHITE = "#ffffff"
AMBER = "#d89236"

SCRIPT_DIR = Path(__file__).resolve().parent
SITE_DIR = SCRIPT_DIR.parent
ASSET_DIR = SITE_DIR / "assets"
FONT_DIR = ASSET_DIR / "fonts"


def font(size: int, weight: str = "regular") -> ImageFont.FreeTypeFont:
    names = {
        "regular": "IBMPlexSansArabic-Regular.ttf",
        "medium": "IBMPlexSansArabic-Medium.ttf",
        "semibold": "IBMPlexSansArabic-SemiBold.ttf",
        "bold": "IBMPlexSansArabic-Bold.ttf",
    }
    return ImageFont.truetype(str(FONT_DIR / names[weight]), size=size)


def rtl(text: str) -> str:
    return get_display(arabic_reshaper.reshape(text))


def draw_rtl(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    text: str,
    text_font: ImageFont.FreeTypeFont,
    fill: str,
    *,
    anchor: str = "ra",
    spacing: int = 12,
) -> None:
    draw.multiline_text(
        xy,
        rtl(text),
        font=text_font,
        fill=fill,
        anchor=anchor,
        align="right",
        spacing=spacing,
    )


def gradient(start: str, end: str) -> Image.Image:
    top = tuple(int(start[i : i + 2], 16) for i in (1, 3, 5))
    bottom = tuple(int(end[i : i + 2], 16) for i in (1, 3, 5))
    image = Image.new("RGB", (WIDTH, HEIGHT), top)
    pixels = image.load()
    for y in range(HEIGHT):
        ratio = y / max(HEIGHT - 1, 1)
        color = tuple(round(top[c] * (1 - ratio) + bottom[c] * ratio) for c in range(3))
        for x in range(WIDTH):
            pixels[x, y] = color
    return image.convert("RGBA")


def rounded_shadow(
    image: Image.Image,
    box: tuple[int, int, int, int],
    radius: int,
    *,
    blur: int = 35,
    offset: tuple[int, int] = (0, 18),
    opacity: int = 42,
) -> None:
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(layer)
    x1, y1, x2, y2 = box
    ox, oy = offset
    shadow_draw.rounded_rectangle((x1 + ox, y1 + oy, x2 + ox, y2 + oy), radius, fill=(9, 36, 47, opacity))
    image.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))


def circle_glow(image: Image.Image, xy: tuple[int, int], radius: int, color: tuple[int, int, int, int]) -> None:
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(layer)
    x, y = xy
    glow_draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)
    image.alpha_composite(layer.filter(ImageFilter.GaussianBlur(radius // 3)))


def paste_logo(image: Image.Image, x: int, y: int, size: int) -> None:
    logo = Image.open(ASSET_DIR / "hesba-icon.png").convert("RGBA")
    logo = ImageOps.fit(logo, (size, size), Image.Resampling.LANCZOS)
    image.alpha_composite(logo, (x, y))


def phone(image: Image.Image, screenshot_path: Path, box: tuple[int, int, int, int], angle: float = 0) -> None:
    x1, y1, x2, y2 = box
    width, height = x2 - x1, y2 - y1
    phone_layer = Image.new("RGBA", (width + 80, height + 80), (0, 0, 0, 0))
    phone_draw = ImageDraw.Draw(phone_layer)
    outer = (20, 20, width + 60, height + 60)
    phone_draw.rounded_rectangle(outer, radius=55, fill="#102630", outline="#36515c", width=3)
    screenshot = Image.open(screenshot_path).convert("RGBA")
    screenshot = ImageOps.fit(screenshot, (width + 22, height + 22), Image.Resampling.LANCZOS, centering=(0.5, 0.0))
    mask = Image.new("L", screenshot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, screenshot.width, screenshot.height), radius=43, fill=255)
    phone_layer.paste(screenshot, (39, 39), mask)
    if angle:
        phone_layer = phone_layer.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
    shadow = Image.new("RGBA", phone_layer.size, (0, 0, 0, 0))
    shadow.alpha_composite(phone_layer)
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    position = (x1 - (phone_layer.width - width) // 2, y1 - (phone_layer.height - height) // 2)
    image.alpha_composite(shadow, (position[0], position[1] + 22))
    image.alpha_composite(phone_layer, position)


def pill(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], text: str, *, fill: str, text_fill: str) -> None:
    draw.rounded_rectangle(box, radius=(box[3] - box[1]) // 2, fill=fill)
    draw_rtl(
        draw,
        ((box[0] + box[2]) // 2, (box[1] + box[3]) // 2 - 2),
        text,
        font(28, "semibold"),
        text_fill,
        anchor="mm",
    )


def slide_intro() -> Image.Image:
    image = gradient(NAVY_DARK, NAVY)
    circle_glow(image, (1540, 120), 360, (11, 140, 126, 55))
    circle_glow(image, (240, 960), 280, (216, 146, 54, 24))
    draw = ImageDraw.Draw(image)
    draw.ellipse((740, 125, 1180, 565), outline=(126, 224, 211, 35), width=2)
    paste_logo(image, 835, 185, 250)
    draw_rtl(draw, (960, 675), "حِسبة", font(98, "bold"), WHITE, anchor="mm")
    draw_rtl(draw, (960, 785), "كل جنيه في حسابه", font(54, "medium"), "#7ee0d3", anchor="mm")
    pill(draw, (680, 875, 1240, 945), "إدارة التحصيل والمدفوعات", fill="#173d4d", text_fill="#d9efec")
    return image


def slide_all_in_one() -> Image.Image:
    image = gradient("#f8fbfb", "#edf5f4")
    circle_glow(image, (350, 540), 430, (11, 140, 126, 32))
    draw = ImageDraw.Draw(image)
    phone(image, ASSET_DIR / "hesba-mobile-dashboard.png", (145, 80, 625, 1020), angle=-2.5)
    draw_rtl(draw, (1770, 190), "كل شغلك", font(88, "bold"), NAVY)
    draw_rtl(draw, (1770, 300), "في مكان واحد", font(88, "bold"), TEAL)
    draw_rtl(
        draw,
        (1770, 430),
        "تابع الأرصدة والحركات لحظة بلحظة\nمن شاشة واحدة واضحة.",
        font(37, "regular"),
        MUTED,
        spacing=20,
    )
    labels = ["الخزنة", "المحافظ", "الماكينات", "المندوبون"]
    x_positions = [1530, 1300, 1070, 840]
    for label, x in zip(labels, x_positions):
        pill(draw, (x - 185, 600, x, 670), label, fill=WHITE, text_fill=TEAL_DARK)
    draw.rounded_rectangle((815, 755, 1770, 895), radius=26, fill=WHITE, outline="#dce6e9", width=3)
    draw_rtl(draw, (1705, 820), "من أول العملية لحد التقرير", font(38, "semibold"), INK)
    draw.ellipse((850, 800, 890, 840), fill=TEAL_LIGHT)
    draw.line((861, 820, 872, 831, 883, 807), fill=TEAL, width=5)
    return image


def slide_accounts() -> Image.Image:
    image = gradient("#ffffff", "#f2f6f7")
    circle_glow(image, (380, 500), 440, (11, 140, 126, 26))
    draw = ImageDraw.Draw(image)
    phone(image, ASSET_DIR / "hesba-mobile-accounts.png", (160, 85, 630, 1010), angle=-2)
    draw_rtl(draw, (1770, 155), "فوري والشركات", font(82, "bold"), NAVY)
    draw_rtl(draw, (1770, 270), "تحت عينك", font(82, "bold"), TEAL)
    items = [
        ("الأرصدة والعمولات", "متابعة مستقلة لكل حساب"),
        ("الشحن والترحيل", "كل حركة محفوظة وواضحة"),
        ("حدود وتشغيل آمن", "قواعد تمنع الأخطاء قبل وقوعها"),
    ]
    y = 445
    for title, subtitle in items:
        rounded_shadow(image, (870, y, 1770, y + 145), 24, blur=18, offset=(0, 10), opacity=22)
        draw.rounded_rectangle((870, y, 1770, y + 145), radius=24, fill=WHITE, outline="#dce6e9", width=2)
        draw.ellipse((1630, y + 40, 1695, y + 105), fill=TEAL_LIGHT)
        draw.line((1648, y + 72, 1661, y + 86, 1680, y + 60), fill=TEAL, width=6)
        draw_rtl(draw, (1585, y + 50), title, font(34, "semibold"), INK)
        draw_rtl(draw, (1585, y + 100), subtitle, font(25), MUTED)
        y += 170
    return image


def slide_mobile() -> Image.Image:
    image = gradient(NAVY_DARK, NAVY)
    circle_glow(image, (960, 600), 520, (11, 140, 126, 55))
    phone(image, ASSET_DIR / "hesba-mobile-accounts.png", (235, 200, 610, 940), angle=-7)
    phone(image, ASSET_DIR / "hesba-mobile-dashboard.png", (580, 120, 1015, 975), angle=2)
    draw = ImageDraw.Draw(image)
    draw_rtl(draw, (1780, 170), "حِسبة معاك", font(78, "bold"), WHITE)
    draw_rtl(draw, (1780, 280), "على الموبايل", font(78, "bold"), "#7ee0d3")
    draw_rtl(
        draw,
        (1780, 410),
        "نفس البيانات، نفس الحساب،\nونفس صلاحيات كل موظف.",
        font(34),
        "#b9cbd1",
        spacing=18,
    )
    draw.rounded_rectangle((1135, 625, 1780, 790), radius=28, fill="#173d4d", outline="#285567", width=2)
    draw.text((1200, 680), "Android", font=font(39, "semibold"), fill=WHITE, anchor="lm")
    draw.text((1710, 680), "iOS", font=font(39, "semibold"), fill=WHITE, anchor="rm")
    draw.line((1455, 660, 1455, 755), fill="#285567", width=2)
    draw_rtl(draw, (1457, 855), "كمبيوتر • موبايل • تابلت", font(30, "medium"), "#78d9cc", anchor="mm")
    return image


def slide_control() -> Image.Image:
    image = gradient("#f7fafb", "#eef3f5")
    draw = ImageDraw.Draw(image)
    draw_rtl(draw, (1720, 150), "إدارة أوضح.", font(78, "bold"), NAVY)
    draw_rtl(draw, (1720, 255), "قرار أسرع.", font(78, "bold"), TEAL)
    cards = [
        (160, 430, "تقارير شاملة", "اعرف حركة شغلك وأداء كل أصل"),
        (680, 430, "صلاحيات الموظفين", "كل مستخدم يشوف المسموح له فقط"),
        (1200, 430, "مخزون ومبيعات", "الموبايلات والإكسسوارات في نفس النظام"),
    ]
    for index, (x, y, title, subtitle) in enumerate(cards):
        rounded_shadow(image, (x, y, x + 460, y + 360), 32, blur=28, offset=(0, 18), opacity=28)
        draw.rounded_rectangle((x, y, x + 460, y + 360), radius=32, fill=WHITE, outline="#dce6e9", width=2)
        icon_fill = [TEAL_LIGHT, "#fff3df", "#e8eef8"][index]
        icon_color = [TEAL, AMBER, "#5479a5"][index]
        draw.rounded_rectangle((x + 330, y + 45, x + 405, y + 120), radius=18, fill=icon_fill)
        if index == 0:
            draw.line((x + 349, y + 99, x + 365, y + 78, x + 378, y + 88, x + 393, y + 61), fill=icon_color, width=6)
        elif index == 1:
            draw.ellipse((x + 348, y + 60, x + 369, y + 81), outline=icon_color, width=4)
            draw.ellipse((x + 375, y + 60, x + 396, y + 81), outline=icon_color, width=4)
            draw.arc((x + 345, y + 75, x + 373, y + 105), 180, 360, fill=icon_color, width=4)
            draw.arc((x + 372, y + 75, x + 400, y + 105), 180, 360, fill=icon_color, width=4)
        else:
            draw.rectangle((x + 350, y + 66, x + 392, y + 103), outline=icon_color, width=4)
            draw.line((x + 350, y + 79, x + 392, y + 79), fill=icon_color, width=4)
        draw_rtl(draw, (x + 400, y + 165), title, font(37, "semibold"), INK)
        draw_rtl(draw, (x + 400, y + 235), subtitle, font(26), MUTED, spacing=10)
        draw_rtl(draw, (x + 400, y + 315), "حِسبة", font(22, "medium"), TEAL)
    draw_rtl(draw, (960, 920), "كل حركة مسجلة • كل رقم واضح • كل صلاحية تحت تحكمك", font(31, "medium"), MUTED, anchor="mm")
    return image


def slide_cta() -> Image.Image:
    image = gradient(NAVY_DARK, NAVY)
    circle_glow(image, (1520, 150), 400, (11, 140, 126, 55))
    draw = ImageDraw.Draw(image)
    paste_logo(image, 820, 100, 280)
    draw_rtl(draw, (960, 500), "جرّب حِسبة على شغلك", font(76, "bold"), WHITE, anchor="mm")
    draw_rtl(draw, (960, 610), "وابدأ حسابات أوضح من أول يوم", font(42, "regular"), "#b9cbd1", anchor="mm")
    draw.rounded_rectangle((470, 730, 1450, 890), radius=30, fill="#173d4d", outline="#285567", width=2)
    draw.text((590, 790), "0100 661 8377", font=font(38, "semibold"), fill="#7ee0d3", anchor="lm")
    draw.text((1330, 790), "shadysteha571@gmail.com", font=font(31, "medium"), fill=WHITE, anchor="rm")
    draw.line((960, 765, 960, 855), fill="#285567", width=2)
    draw_rtl(draw, (960, 980), "حِسبة — كل جنيه في حسابه", font(28, "medium"), "#78a0ab", anchor="mm")
    return image


def main() -> None:
    output_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else SCRIPT_DIR / "slides"
    output_dir.mkdir(parents=True, exist_ok=True)
    slides = [
        slide_intro(),
        slide_all_in_one(),
        slide_accounts(),
        slide_mobile(),
        slide_control(),
        slide_cta(),
    ]
    for index, image in enumerate(slides, start=1):
        image.convert("RGB").save(output_dir / f"slide-{index:02d}.png", quality=95, optimize=True)
        print(output_dir / f"slide-{index:02d}.png")


if __name__ == "__main__":
    main()
