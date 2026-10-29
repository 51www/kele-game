"""《童趣游戏盒》浏览器验收辅助脚本 —— 从截图中定位卡牌并提取特征。

用途：Flutter Web 渲染在 Canvas 上，DOM 快照拿不到元素位置，
因此改用「像素取色」定位——翻牌记忆的 6 张卡背颜色互不相同
（马卡龙瓷砖色板循环），可用颜色反查每张卡的位置。

用法：
    python tool/qa/board_analyzer.py <png> <scale> <key:hex,key:hex,...>
输出（JSON，坐标已换算为 CSS 像素）：
    {"cards": [{"key": "...", "x": .., "y": .., "w": .., "h": .., "sig": [...]}]}
"""

from __future__ import annotations

import json
import sys

from PIL import Image, ImageChops

# 马卡龙瓷砖色板（UI 规范 §1.2），与 Dart 侧一一对应
TILE_COLORS = {
    "lavender": (0xB7, 0xAE, 0xF2),
    "mint": (0x7F, 0xD8, 0xA4),
    "sky": (0x8F, 0xCB, 0xF0),
    "sakura": (0xF5, 0xA8, 0xC7),
    "peach": (0xF5, 0xB0, 0x8A),
    "lemon": (0xF7, 0xD8, 0x4A),
}


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16))


def find_color_box(img: Image.Image, target):
    """返回该颜色在画面中的包围盒（像素坐标），未找到返回 None。

    先在 1/8 缩略图上做覆盖率阈值过滤，剔除零星抗锯齿杂点，
    再在候选窗口内做全分辨率包围盒，保证定位到的是「色块」而不是杂散像素。
    """
    tr, tg, tb = target
    r, g, b = img.split()
    mr = r.point(lambda v: 255 if abs(v - tr) <= 3 else 0)
    mg = g.point(lambda v: 255 if abs(v - tg) <= 3 else 0)
    mb = b.point(lambda v: 255 if abs(v - tb) <= 3 else 0)
    mask = ImageChops.multiply(ImageChops.multiply(mr, mg), mb)

    width, height = mask.size
    coarse = mask.resize(
        (max(1, width // 8), max(1, height // 8)),
        Image.BOX,
    )
    coarse_bbox = coarse.point(lambda v: 255 if v > 70 else 0).getbbox()
    if coarse_bbox is None:
        return None

    x0 = max(0, coarse_bbox[0] * 8 - 8)
    y0 = max(0, coarse_bbox[1] * 8 - 8)
    x1 = min(width, coarse_bbox[2] * 8 + 8)
    y1 = min(height, coarse_bbox[3] * 8 + 8)
    bbox = mask.crop((x0, y0, x1, y1)).getbbox()
    if bbox is None:
        return None
    return (
        x0 + bbox[0],
        y0 + bbox[1],
        x0 + bbox[2] - 1,
        y0 + bbox[3] - 1,
        0,
    )


def signature(img: Image.Image, box) -> list[int]:
    """取卡牌内部区域，降采样成 16×16 RGB 特征，用于比较两张卡是否同一张图。

    用 RGB 而非灰度，避免两只颜色接近的动物被误判为同一张。
    """
    min_x, min_y, max_x, max_y, _ = box
    w = max_x - min_x + 1
    h = max_y - min_y + 1
    inset_x = int(w * 0.25)
    inset_y = int(h * 0.25)
    crop = img.crop(
        (
            min_x + inset_x,
            min_y + inset_y,
            max_x - inset_x,
            max_y - inset_y,
        )
    )
    if crop.width < 4 or crop.height < 4:
        return []
    small = crop.resize((16, 16), Image.BOX)
    return list(small.tobytes())


def main() -> None:
    png_path = sys.argv[1]
    scale = float(sys.argv[2])
    wanted = sys.argv[3] if len(sys.argv) > 3 else ""

    img = Image.open(png_path).convert("RGB")
    width, height = img.size

    # 模式二：直接按给定的卡牌矩形（CSS 像素）取特征，用于卡面已翻开时比对
    if wanted.startswith("["):
        rects = json.loads(wanted)
        cards = []
        for rect in rects:
            box = (
                int(rect["x"] * scale),
                int(rect["y"] * scale),
                int((rect["x"] + rect["w"]) * scale) - 1,
                int((rect["y"] + rect["h"]) * scale) - 1,
                0,
            )
            cards.append(
                {
                    "key": rect.get("key", ""),
                    "x": rect["x"],
                    "y": rect["y"],
                    "w": rect["w"],
                    "h": rect["h"],
                    "sig": signature(img, box),
                }
            )
        print(json.dumps({"size": [width, height], "cards": cards}))
        return

    cards = []
    if wanted:
        for item in wanted.split(","):
            key, _, value = item.partition(":")
            target = hex_to_rgb(value) if value else TILE_COLORS[key]
            box = find_color_box(img, target)
            if box is None:
                continue
            min_x, min_y, max_x, max_y, _ = box
            cards.append(
                {
                    "key": key,
                    "x": round(min_x / scale, 1),
                    "y": round(min_y / scale, 1),
                    "w": round((max_x - min_x + 1) / scale, 1),
                    "h": round((max_y - min_y + 1) / scale, 1),
                    "sig": signature(img, box),
                }
            )
    print(json.dumps({"size": [width, height], "cards": cards}))


if __name__ == "__main__":
    main()
