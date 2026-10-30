# 里程碑 3 开发记录 —— 家长中心 + 儿童保护（M-Parent）

日期：2026-10-30
状态：✅ 全部完成，浏览器验收 24/24 通过，控制台零错误

---

## 一、已实现功能点清单

| # | 功能点 | 实现位置 | 截图 |
|---|--------|----------|------|
| 1 | 家长门（进入家长中心触发）：两位数算术题 + 长按 3 秒两种方式**每次随机轮换**；答错自动换题防试错 | `lib/features/parent/parent_gate.dart` | 3-1 ~ 3-4 |
| 2 | 家长门（隐藏/删除游戏操作触发）：与二次确认串联 | 同上 + `parent_center_page.dart` | 3-8、3-13、3-14 |
| 3 | 家长中心视觉分区：降饱和奶油底（neutral.pageBg）+ 白卡 + 深紫字，无吉祥物无动画，与儿童区明确区分 | `lib/features/parent/parent_center_page.dart` | 3-5 |
| 4 | 每日时长设置：滑块 20~120 分钟（默认 40），实时回显今日已玩/连续时长 | `parent_center_page.dart` + `parental_guard.dart` | 3-6、3-7 |
| 5 | 游戏隐藏：家长门 + 确认弹窗 → 大厅「我的游戏/商店」均不再展示；可恢复显示（免确认） | `core/storage/progress_store.dart`（hiddenGames）+ `home_page.dart`（isHidden 过滤） | 3-9 ~ 3-11 |
| 6 | 游戏删除：家长门 → 危险红钮确认 → **二次确认** → 清空下载解锁与全部进度，回到商店未下载态 | `progress_store.deleteGame()` | 3-12 ~ 3-16 |
| 7 | 护眼计时：连续玩 20 分钟 → 强制休息眼保健操 30 秒，**无任何跳过出口**，到点自动恢复并清零连续计时；休息期间冻结进行中的游戏（GameScaffold 注册 freeze/resume 钩子） | `lib/features/parent/parental_guard.dart` + `guard_overlay.dart` + `game_scaffold.dart` | 3-18 ~ 3-20 |
| 8 | 每日时长到点：全屏「明天见」锁屏页（月亮 + 日期），点击不可解除，至次日自动解除；演示模式下提供显式重置入口 | `guard_overlay.dart`（_DailyLockOverlay） | 3-21 ~ 3-23 |
| 9 | 全局音效开关迁入家长中心（与大厅右上圆钮同一数据源 `ProgressStore.soundMuted`） | `parent_center_page.dart` | 3-5 |
| 10 | 验收辅助（不影响默认行为）：URL `?gate=math\|hold` 固定门模式；家长中心「护眼验收调试」演示节奏（连续 20s / 每日 60s，休息仍真实 30s，重启页面保持） | `parent_gate.dart`（_initialMode）+ `parental_guard.dart`（demoMode） | 3-17 |

截图目录：`docs/shortscreens/3-*.png`（沿用 M1/M2 的目录名）。

## 二、浏览器验证结果汇总表

验证方式：`tool/qa/verify_m3.js`（Playwright + Chromium，360×800 竖屏、DPR=3、像素取色定位，与 M1/M2 同口径），运行日志 `.logs/m3-browser-verify.log`。

| 功能点 | 操作步骤 | 预期结果 | 实际结果 | 通过 |
|--------|----------|----------|----------|------|
| 家长门拦截 | 点大厅右上锁钮 | 弹出家长门，大厅被遮罩 | 算术题门出现（95+5=?），遮罩拦截 | ✅ 3-1 |
| 答错换题 | 输入 13 点确认 | 报错提示 + 随机换题 | Toast 报错，题目区域像素特征变化 | ✅ 3-2/3-3 |
| 未通过不可进 | 点遮罩关闭 | 留在大厅 | 留在大厅 | ✅ 3-4 |
| 长按 3 秒通过 | 按住圆钮 3s+ | 环形进度走满后进入家长中心 | 通过并进入 | ✅ 3-5 |
| 视觉分区 | 观察家长中心 | 奶油底 + 白卡 + 深紫字 | 与儿童区明确区分 | ✅ 3-5 |
| 每日时长滑块 | 观察默认值/点滑轨右侧 | 默认 40，范围 20~120，可调 | 默认 40，调整生效（上限 120） | ✅ 3-6/3-7 |
| 隐藏游戏 | 眼睛钮 → 家长门 → 确认 | 标记「已隐藏」，大厅不展示 | 徽标出现；大厅商店仅剩 2 款 | ✅ 3-8~3-10 |
| 恢复显示 | 再点眼睛钮 → 家长门 | 恢复展示，无需确认 | 恢复，徽标消失 | ✅ 3-11 |
| 删除游戏 | 垃圾桶钮 → 家长门 → 危险确认 → 二次确认 | 两次红色危险按钮，确认后清空进度 | 流程完整，删除完成 | ✅ 3-13~3-15 |
| 删除回显 | 回大厅 | 翻牌记忆回到商店未下载态 | 回到商店 | ✅ 3-16 |
| 演示节奏 | 开启调试开关 | 连续 20s/每日 60s 生效 | 生效 | ✅ 3-17 |
| 护眼休息 | 连续使用 20s | 强制休息覆盖层（倒计时 30s，无跳过按钮） | 出现，倒计时从 30 递减 | ✅ 3-18 |
| 不可跳过 | 点击休息页 + 等 6s | 无响应，仍在休息 | 仍在休息（3-19 倒计时继续） | ✅ 3-19 |
| 自动恢复 | 等休息到点 | 自动回到大厅，连续计时清零 | 自动恢复 | ✅ 3-20 |
| 每日锁屏 | 每日累计 60s | 全屏「明天见」页 | 出现（月亮+日期） | ✅ 3-21 |
| 锁屏不可绕过 | 点击锁屏页 | 无响应 | 仍锁定 | ✅ 3-22 |
| 演示重置 | 点「（演示）重置今日时长」 | 回大厅继续使用 | 回大厅 | ✅ 3-23 |

控制台错误：**无**（脚本监听 pageerror + console.error）。

## 三、开发过程中遇到的问题及解决方式

1. **家长门传 Navigator 丢失 → 首帧白屏（本里程碑最大坑）**
   `GuardOverlayHost` 挂在 `MaterialApp.builder`，误把 `ValueListenableBuilder` 的 builder 第三参（child，为 null）当作页面内容，`MaterialApp.builder` 传入的 Navigator 被丢弃 → 应用整体不出帧且无报错。通过 `debugPrint` 埋点二分（main → TongquApp → overlay host → HomePage 不再往下）定位。修复：Navigator 通过 `ValueListenableBuilder.child` 传入，避免随守卫状态重建。

2. **Web 构建必须 `--no-web-resources-cdn`**
   本机 Flutter 3.47.7 中，`useLocalCanvasKit` 只在 `--no-web-resources-cdn` 时写入 `flutter_bootstrap.js` 的 buildConfig；仅带 `--dart-define=FLUTTER_WEB_CANVASKIT_URL=canvaskit/` 时 loader 仍可能从 gstatic CDN 拉取 CanvasKit，受限网络下 `ERR_CONNECTION_CLOSED` → 永久白屏（间歇性表现为时好时坏，极具迷惑性）。最终构建/验收命令：
   `flutter build web --release --no-web-resources-cdn --dart-define=FLUTTER_WEB_CANVASKIT_URL=canvaskit/`

3. **验收脚本三处作用域缺陷**：`tapPrimaryBtn/tapDangerBtn/tapCenterOf/scrollTop` 定义在 `main()` 外访问不到 `page/TMP/wait/pick`，报 `xxx is not defined`。统一用模块级 `activePage/TMP/pick/center/sleep` 修复；`node --check` 预检语法。

4. **长按判定误报**：家长门长按实际已通过，但通过后家长中心的全屏 pageBg 背景被脚本的 `gateColor()` 误判为"门还在"。修正判定：只认门面板尺寸（圆钮 100~160px / 算术面板 200~300px）的 pageBg 色块。

5. **锁屏等待窗口不足**：演示节奏下锁屏出现在开启后约 120s（中间还有第二次 30s 休息），脚本原 60s 等待超时。按状态机推演放宽到 120s。

6. **家长门「换成长按/换算术题」双入口**：两种模式底部均有切换入口，保证儿童被算术题卡住时家长可换长按（反之亦然）。

## 四、遗留问题与后续建议

1. **算术题「答对通过」由人工复核**：脚本无法读取 Canvas 上的题目数字，答对通过 与 长按通过 共用同一代码路径（`Navigator.pop(true)`），已在 3-1/3-2 截图中人工确认题面与键盘可用。建议后续提供 2D 文本 DOM 可访问性时补充自动化。
2. **家长门默认随机轮换的稳定性**：URL `?gate=` 参数仅用于验收自动化，正式包不带参数即随机轮换；建议发布前用真机抽测 20 次开合确认两种模式均出现。
3. **护眼计时口径**：当前按「应用前台秒数」累计（休息期间不计），未细化到「仅在游戏页内」。如需更严格口径（离开游戏即暂停连续计时），在 M-Game 深化时于 GameScaffold 生命周期接入。
4. **锁屏页解除依赖跨天**：正式版无重置入口，验收通过演示模式完成；跨天自动解除逻辑（`_isNewDay`）为代码推演 + 单元可测，未做跨午夜实测。
5. **M2 的下载调试入口**已迁入家长中心（天然位于家长门之后），后续如加「儿童无法触达」的自动化断言，可在 M4 一并处理。
