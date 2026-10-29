# -*- coding: utf-8 -*-
"""生成各游戏素材目录的 manifest.md（素材清单）"""
import os, sys
sys.stdout.reconfigure(encoding="utf-8")

BASE = r"E:\www\其它\tongqu-gamebox\assets\games"

# slug -> (中文名, 素材清单 [(文件/目录, 规格, 说明)])
GAMES = {
    "memory-match": ("翻牌记忆", [
        ("card-back.png", "256×320 PNG 透明底", "卡背图案，全局统一风格（可用共享角色库形象做卡背）"),
        ("card-fronts/animal_01~12.png", "各 256×256 透明底", "12 种卡面动物，可直接取共享角色库 12 个角色的头像"),
        ("board-bg.png", "1080×1920", "牌桌背景，低饱和不抢主体"),
    ]),
    "whack-mole": ("打地鼠", [
        ("hole.png", "320×200", "地鼠洞口（前景+背景两层便于地鼠从洞后冒出）"),
        ("mole_idle.png / mole_hit.png / mole_bomb.png", "各 256×256 透明底", "普通鼠/被敲中/炸弹鼠三态"),
        ("hats/hat_01~04.png", "各 160×160 透明底", "4 种可爱头饰，随机佩戴"),
        ("grid-bg.png", "1080×1920", "草地背景"),
    ]),
    "jigsaw": ("宝宝拼图", [
        ("pictures/sample_01~10.png", "各 900×900", "拼图底图：单主体动物/水果，背景简洁"),
        ("piece-frame.png", "可选", "拼块描边样式（也可代码绘制切割线）"),
    ]),
    "coloring": ("涂色小画家", [
        ("linearts/lineart_01~10.svg", "矢量优先", "分区线稿（每个闭合区域一个 path/色号），PNG 需另配分区蒙版图"),
        ("samples/colored_01~10.png", "各 900×900", "对应上色完成示例图"),
    ]),
    "lianliankan": ("动物连连看", [
        ("tiles/tile_01~12.png", "各 128×128 透明底", "12 种图案（动物/水果），同一对内完全一致"),
        ("board-bg.png", "1080×1920", "棋盘背景"),
        ("link-line.png", "可选", "连线样式（也可代码绘制圆角折线）"),
    ]),
    "hop-hop": ("跳一跳", [
        ("char_stand.png / char_crouch.png / char_jump.png", "各 256×256 透明底", "主角三态（站/蹲蓄力/腾空）"),
        ("platforms/platform_01~06.png", "各 200×120", "6 种平台造型（方块/圆柱/礼物盒…）"),
        ("center-ring.png", "160×160 透明底", "落点中心提示圈"),
        ("bg.png", "1080×1920", "竖版渐变背景"),
    ]),
    "fishing": ("宝宝钓鱼", [
        ("fish/fish_01~10.png", "各 160×128 透明底", "10 种普通鱼，左右朝向各一张或代码镜像"),
        ("fish/glow_01~02.png", "各 160×128", "2 种发光稀有鱼"),
        ("water-bg.png", "1080×1920", "分层水背景（可拆前后层做视差）"),
        ("hook.png / basket.png", "各 128×128", "鱼钩与鱼篓"),
    ]),
    "bubble-shooter": ("泡泡龙", [
        ("bubbles/bubble_01~06.png", "各 96×96", "6 色泡泡，带高光"),
        ("cannon.png", "256×256 透明底", "底部发射台（可旋转）"),
        ("ceiling.png", "1080×96", "顶部边界"),
    ]),
    "spot-difference": ("找不同", [
        ("pairs/pair_01A.png + pair_01B.png", "各 1200×900 ×10 组", "成对找不同图：B 图在 A 图基础上修改 3~8 处"),
        ("pairs/diffs_01~10.json", "JSON", "每组差异点坐标 [{x,y,r}...]，与图配套"),
        ("ring.png", "128×128", "命中圈标记"),
    ]),
    "merge-fruit": ("合成大西瓜", [
        ("fruit-chain/level_01~11.png", "64→256px 逐级增大", "11 级水果进化链，同款带表情，色系区分度高"),
        ("journal-card.png", "300×400", "图鉴卡底板"),
        ("bg.png", "1080×1920", "容器背景（浅色，衬托水果）"),
    ]),
    "maze": ("迷宫大冒险", [
        ("char.png", "128×128 透明底", "主角（四方向可代码镜像）"),
        ("wall-tile.png / floor-tile.png", "各 128×128 可平铺", "墙/地 tile"),
        ("exit.png", "128×128", "发光出口"),
        ("star.png", "96×96", "可收集星星（可用共享 ui/star）"),
    ]),
    "snake": ("贪吃蛇", [
        ("head.png / body.png", "各 128×128 透明底", "蛇头（带眼睛）/蛇身，代码按方向旋转拼接"),
        ("food/food_01~04.png", "各 96×96", "4 种食物（3 秒闪烁高亮素材自带两帧或代码做透明度动画）"),
        ("grid-bg.png", "1080×1920", "网格棋盘背景"),
    ]),
    "block-builder": ("宝宝搭积木", [
        ("blocks/block_01~15.png", "各 160×160 透明底", "15 种形状积木，全部带笑脸表情"),
        ("platforms/platform_01~03.png", "各 1080×400", "3 种场景地台"),
        ("bg_01~03.png", "1080×1920", "配套背景"),
    ]),
    "sticker-fun": ("贴纸乐园", [
        ("scenes/scene_01~06.png", "各 1080×1920", "6 张场景底图（农场/海底/太空/森林/城市/卧室）"),
        ("stickers/farm_01~10.png 等 6 组", "各 200×200 透明底", "每主题 10 张，共 60 张贴纸"),
    ]),
    "dot-to-dot": ("连线画", [
        ("patterns/pattern_01~10.json", "JSON", "点坐标序列 + 线段连接关系"),
        ("reveals/reveal_01~10.png", "各 900×900", "连线完成后的完整图案（填色动画目标图）"),
    ]),
    "feeding": ("小动物喂食", [
        ("animals/animal_01~06_{hungry,happy,shake}.png", "各 256×256 透明底", "6 种动物 × 3 态（等食/开心/摇头）"),
        ("foods/food_01~12.png", "各 128×128 透明底", "12 种食物"),
    ]),
    "mini-kitchen": ("美食小厨房", [
        ("ingredients/ing_01~12.png", "各 128×128", "12 种食材"),
        ("tools/tool_01~06.png", "各 160×160", "刀/锅/搅拌器/炉灶/盘子/餐桌"),
        ("dishes/dish_01~08.png", "各 200×200", "8 种成品菜"),
        ("tasters/taster_01~03.png", "各 256×256", "3 个试吃角色 ×（期待/美味）表情"),
    ]),
    "relax-tetris": ("俄罗斯方块拼图", [
        ("tetromino/I_J_L_O_S_T_Z.png", "每块 4 单元，单元 96×96", "7 种方块，统一色板不同色"),
        ("grid-bg.png", "可平铺", "棋盘网格"),
        ("clear-fx.png", "1080×120", "消行闪光特效条"),
    ]),
    "character-detective": ("汉字小侦探", [
        ("card-bg.png", "160×160", "字卡底板（目标字/干扰字共用）"),
        ("sparkle.png", "128×128", "答对特效"),
        ("data/hanzi_db.json", "JSON", "形近字库：按部首分组，含字/组词/年级标注（字体渲染用 shared/fonts）"),
    ]),
}

total = 0
for slug, (cn, items) in GAMES.items():
    d = os.path.join(BASE, slug)
    os.makedirs(d, exist_ok=True)
    lines = [
        f"# {cn} · 素材清单",
        "",
        "> 来源与全局规范见 `assets/素材资源指南.md`；文件命名用小写下划线，PNG 一律透明底。",
        "",
        "| 文件/目录 | 规格 | 说明 |",
        "|---|---|---|",
    ]
    for f, spec, desc in items:
        lines.append(f"| `{f}` | {spec} | {desc} |")
    lines.append("")
    with open(os.path.join(d, "manifest.md"), "w", encoding="utf-8") as fp:
        fp.write("\n".join(lines))
    total += 1

print(f"OK: {total} manifests written to {BASE}")
