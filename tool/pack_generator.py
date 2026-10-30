#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""《童趣游戏盒》素材包清单生成器（里程碑 M2：B-1 素材包解锁）。

职责（对应开发里程碑文档 M2 步骤 1）：
  1. 按游戏汇总其素材文件清单；
  2. 计算「合并后字节流」的 MD5（下载后用于完整性校验）；
  3. 输出 `assets/packs/<gameId>/manifest.json`，含：
       gameId / displayName / minAge / sizeBytes(声明包大小，用于商店展示与下载进度模拟)
       / fileCount / md5(实际素材字节流的摘要) / files(素材相对工程根的路径列表)。

说明：B-1 方案中「游戏逻辑内置 APK，素材按游戏拆成资源包」。本工程以
`assets/packs/<gameId>/` 作为该游戏的素材包根，清单与素材均随 App 内置发布；
「下载」= 在本地按三级源（局域网 / 托管 / 本地素材包）取得该包并校验 MD5 后解锁入口。
为防止不同平台字节序差异，MD5 一律按 `files` 列表的**字典序**逐文件拼接后计算。

运行：
    python tool/pack_generator.py
"""

from __future__ import annotations

import hashlib
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 游戏 -> 素材文件（相对工程根）。占位游戏（comingSoon）暂用空清单，
# 其 sizeBytes 仅用于商店展示与下载进度模拟，不参与 MD5。
GAMES: dict[str, dict] = {
    "memory_match": {
        "displayName": "翻牌记忆",
        "minAge": 3,
        "sizeBytes": 0,  # 0 表示按实际素材字节数自动统计
        "files": [
            "assets/shared/character-library/animal_01_cat.png",
            "assets/shared/character-library/animal_02_dog.png",
            "assets/shared/character-library/animal_03_rabbit.png",
            "assets/shared/character-library/animal_04_panda.png",
            "assets/shared/character-library/animal_05_fox.png",
            "assets/shared/character-library/animal_06_unicorn.png",
            "assets/shared/character-library/animal_07_bear.png",
            "assets/shared/character-library/animal_08_penguin.png",
            "assets/shared/character-library/animal_09_frog.png",
            "assets/shared/character-library/animal_10_chick.png",
            "assets/shared/character-library/animal_11_pig.png",
            "assets/shared/character-library/animal_12_koala.png",
        ],
    },
    "whack_mole": {
        "displayName": "打地鼠",
        "minAge": 3,
        "sizeBytes": 6 * 1024 * 1024,  # 占位声明大小（M4 实装后由真实素材替换）
        "files": [],
    },
    "jigsaw": {
        "displayName": "宝宝爱拼图",
        "minAge": 3,
        "sizeBytes": 8 * 1024 * 1024,  # 占位声明大小（M4 实装后由真实素材替换）
        "files": [],
    },
}


def md5_of_files(files: list[str]) -> tuple[str, int]:
    """按字典序拼接所有文件字节，返回 (md5_hex, 总字节数)。"""
    h = hashlib.md5()
    total = 0
    for rel in sorted(files):
        path = os.path.join(ROOT, rel)
        if not os.path.isfile(path):
            print(f"  [WARN] 素材缺失，跳过：{rel}", file=sys.stderr)
            continue
        with open(path, "rb") as fh:
            for chunk in iter(lambda: fh.read(1 << 16), b""):
                h.update(chunk)
                total += len(chunk)
    return h.hexdigest(), total


def main() -> None:
    for game_id, meta in GAMES.items():
        files = meta["files"]
        md5_hex, real_bytes = md5_of_files(files)
        declared = meta["sizeBytes"] if meta["sizeBytes"] > 0 else real_bytes
        manifest = {
            "gameId": game_id,
            "displayName": meta["displayName"],
            "minAge": meta["minAge"],
            "sizeBytes": declared,
            "fileCount": len(files),
            "md5": md5_hex,
            "files": files,
        }
        out_dir = os.path.join(ROOT, "assets", "packs", game_id)
        os.makedirs(out_dir, exist_ok=True)
        out_path = os.path.join(out_dir, "manifest.json")
        with open(out_path, "w", encoding="utf-8") as fh:
            json.dump(manifest, fh, ensure_ascii=False, indent=2)
        mb = declared / 1024 / 1024
        print(
            f"  [OK] {game_id}: {len(files)} 文件, "
            f"md5={md5_hex[:8]}…, 展示大小={mb:.1f} MB -> {out_path}"
        )
    print("素材包清单生成完成。")


if __name__ == "__main__":
    main()
