"""《童趣游戏盒》素材后处理脚本 —— AI 生成图 → 规范化透明底 PNG。

用途（对齐《素材资源指南》§1 规则 2 / §4）：
1. AI 生成图默认带纯白底，按「素材资源指南 §1 规则 2：PNG 一律透明底」要求去底；
   去底采用**从画布四边向内的容差洪泛填充**，只清除与边缘连通的近白像素，
   避免误伤角色内部的白色区域（例如猫脸的白肚皮、熊猫的白色眼圈）。
2. 按「素材资源指南 §1 规则 2：四周留 10% 透明边距」裁切到内容包围盒后居中放置，
   保证 48px 触控热区留白。
3. 按「素材资源指南 §1 规则 1：小写下划线命名」重命名为 animal_01..12.png / mascot.png。

用法：
    python tool/prepare_character_assets.py
"""

from __future__ import annotations

import re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
LIB_DIR = ROOT / "assets" / "shared" / "character-library"
UI_DIR = ROOT / "assets" / "shared" / "ui"

CANVAS = 512
MARGIN_RATIO = 0.10  # 四周 10% 透明边距
WHITE_TOLERANCE = 30  # 近白判定容差（0~255）
KEY_COLOR = (255, 0, 255)  # 洪泛填充标记色（品红，正常图中不会出现）

# 生成顺序 → 稳定的 animal_01..12 编号
ANIMALS: list[tuple[str, str]] = [
    ("cute_cartoon_orange_tabby_kitt", "01_cat"),
    ("cute_cartoon_cream_puppy_face__", "02_dog"),
    ("cute_cartoon_white_bunny_face__", "03_rabbit"),
    ("cute_cartoon_panda_face_with_b", "04_panda"),
    ("cute_cartoon_orange_fox_face_w", "05_fox"),
    ("cute_cartoon_lavender_unicorn__", "06_unicorn"),
    ("cute_cartoon_light_brown_teddy_", "07_bear"),
    ("cute_cartoon_navy_blue_penguin_", "08_penguin"),
    ("cute_cartoon_mint_green_frog_f", "09_frog"),
    ("cute_cartoon_yellow_chick_face_", "10_chick"),
    ("cute_cartoon_pink_pig_face_wit", "11_pig"),
    ("cute_cartoon_grey_koala_face_w", "12_koala"),
]


def find_source(directory: Path, prefix: str) -> Path:
    candidates = sorted(directory.glob(f"{prefix}*.png"))
    if not candidates:
        raise FileNotFoundError(f"未找到素材：{directory}/{prefix}*.png")
    return candidates[0]


def remove_white_background(img: Image.Image) -> Image.Image:
    """把与画布边缘连通的近白背景抠成透明，保留角色内部白色。"""
    rgba = img.convert("RGBA")
    work = rgba.convert("RGB")

    # 四个角任选其一作为洪泛起点（角色不会覆盖画布四角）
    ImageDraw.floodfill(work, (0, 0), KEY_COLOR, thresh=WHITE_TOLERANCE)

    pixels = work.load()
    out = rgba.load()
    w, h = rgba.size
    for y in range(h):
        for x in range(w):
            if pixels[x, y] == KEY_COLOR:
                out[x, y] = (255, 255, 255, 0)
    return rgba


def trim_and_center(img: Image.Image) -> Image.Image:
    """裁掉完全透明区域，再按 10% 边距居中放入 512×512 画布。"""
    bbox = img.getbbox()
    if bbox is None:
        raise ValueError("图像为空，无法裁切")
    content = img.crop(bbox)

    inner = int(CANVAS * (1 - MARGIN_RATIO * 2))
    content.thumbnail((inner, inner), Image.LANCZOS)

    canvas = Image.new("RGBA", (CANVAS, CANVAS), (255, 255, 255, 0))
    canvas.paste(
        content,
        ((CANVAS - content.width) // 2, (CANVAS - content.height) // 2),
        content,
    )
    return canvas


def process(src: Path, dst: Path) -> None:
    img = Image.open(src)
    out = trim_and_center(remove_white_background(img))
    out.save(dst, "PNG", optimize=True)
    print(f"{src.name} -> {dst.relative_to(ROOT)}  ({dst.stat().st_size} bytes)")


def main() -> None:
    for prefix, name in ANIMALS:
        src = find_source(LIB_DIR, prefix)
        process(src, LIB_DIR / f"animal_{name}.png")
    mascot = find_source(UI_DIR, "cute_cartoon_orange_fox_mascot")
    process(mascot, UI_DIR / "mascot_fox.png")
    print("done")


if __name__ == "__main__":
    main()
