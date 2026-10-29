# 里程碑 M1 开发记录 —— 框架搭建

> 日期：2026-10-29 ｜ 里程碑：M1（框架搭建，完成游戏数 1 / 19）
> 技术栈：Flutter 3.47.7（stable）+ Flame 1.38.2 + shared_preferences 2.5.6 ｜ 目标平台：**Android 手机优先**（AGENT.md §1.1）
> 依据：`docs/开发里程碑文档.md` §1（M1）、`docs/儿童小游戏APP计划书.md` §4.2/§4.3、`docs/UI 设计规范.md`、`AGENT.md` §1.1/§2
> 验收运行日志：`.logs/m1-browser-verify.log`

---

## 一、已实现功能点清单

### 1.1 M-Core 核心框架（6 项）

| # | 功能点 | 实现说明 | 对应文件 / 截图 |
|---|---|---|---|
| 1 | 设计 Token 体系 | 颜色 / 间距 / 字体 / 圆角 / 阴影 / 动效 全量 Token 化，UI 规范 §8.0.1「零魔法值」；`bg.primary` 垂直渐变背景 | `lib/core/theme/app_tokens.dart` |
| 2 | 全局主题 | 基于 Token 派生 `ThemeData`（Material 3 + 自定义 ColorScheme），全局字体栈与中文回退 | `lib/core/theme/app_theme.dart` |
| 3 | 中文字体方案 | `fontFamilyFallback: [PingFang SC, Noto Sans CJK SC, Microsoft YaHei]`，覆盖 iOS/Android/Windows/Web，**包体零增加**；Web 端实测中文正常（修复 M0 遗留 tofu） | `lib/core/theme/app_theme.dart`、`docs/shortscreens/1-1-大厅总览.png` |
| 4 | 公共组件 | `AppButton`（主/次/幽灵三态）、`AppToast`、`RoundIconButton`（圆形图标按钮）、`StarsRow`（星星展示） | `lib/core/widgets/` |
| 5 | 路由 | `MaterialApp` + `routes` 命名路由：大厅 `/`、家长中心 `/parent`、游戏页 `/game/:id` | `lib/main.dart` |
| 6 | M-Store 进度存储 | `ProgressStore` + `GameProgress`：每游戏一份 JSON（`unlocked` / `bestScore` / `bestStars` / `lastScore` / `plays`），带 `revision` 版本号用于变更通知回显；`shared_preferences` 落盘 | `lib/core/storage/progress_store.dart`、`lib/core/storage/game_progress.dart` |

### 1.2 统一游戏框架（6 项）

| # | 功能点 | 实现说明 | 对应文件 / 截图 |
|---|---|---|---|
| 7 | `GameModule` 抽象契约 | 严格对齐计划书 §4.3 的 10 个成员：`id` / `name` / `minAge` / `packSize` / `init(GameConfig)` / `buildGamePage` / `pause` / `resume` / `dispose` / `resultStream`；另提供**可选** `buildHud()` 扩展（默认 `null`，不破坏既有契约） | `lib/game_engine/game_module.dart` |
| 8 | `GameScaffold` 统一外壳 | 四态渲染：loading / empty / error / normal；画布层与 UI 层分离（UI 规范 §8.6.4），HUD 置于画布上方不侵入画布；异常捕获并落日志 | `lib/game_engine/game_scaffold.dart`、`docs/shortscreens/1-6-暂停遮罩.png` |
| 9 | 全局唯一统一结算弹窗 | `result_dialog.dart` 为全项目**唯一**结算入口：星星（`font.display` 分数）+ 用时 / 步数指标 + 「再玩一次」「回大厅」双按钮；游戏模块禁止自造结算页 | `lib/game_engine/result_dialog.dart`、`docs/shortscreens/1-11-统一结算弹窗.png` |
| 10 | 返回二次确认 | 游戏中返回先弹二次确认弹窗（丢弃本局 / 继续游戏），避免误触丢失进度 | `docs/shortscreens/1-7-返回二次确认.png`、`docs/shortscreens/1-13-返回二次确认2.png` |
| 11 | `score_system` 统一计分 | `starsFor(StarRule, metric)` 回调式星级（1~3 星夹紧）；`computeScore(baseScore, steps, perfectSteps, duration)` ＝基础分 − 超额步数惩罚(20/步) + 用时奖励(上限 60)，下限 10 分；`commit()` 结算落库 | `lib/game_engine/score_system.dart` |
| 12 | `GameRegistry` 游戏清单注册表 | 统一登记游戏 id / 名称 / 适龄下限 / 素材包大小 / 模块工厂；大厅宫格与路由均由此驱动，新增游戏只改一处 | `lib/game_engine/game_registry.dart` |

### 1.3 M-Home 游戏大厅（4 项）

| # | 功能点 | 实现说明 | 对应文件 / 截图 |
|---|---|---|---|
| 13 | 「我的游戏」宫格卡 | 卡片式宫格，展示游戏图标、名称、适龄下限、最高分与星级；未解锁显示锁定态 | `lib/features/home/game_tile_card.dart`、`docs/shortscreens/1-1-大厅总览.png` |
| 14 | 「游戏商店」占位卡 | 商店区占位卡（更多游戏敬请期待），点击给出 Toast 提示，M2 起接真实下载列表 | `docs/shortscreens/1-4-大厅商店区.png` |
| 15 | 家长中心入口 | 大厅入口按钮 → 家长中心页（护眼时长 / 音量等设置占位），支持返回 | `lib/features/parent/parent_center_page.dart`、`docs/shortscreens/1-2-家长中心.png` |
| 16 | 成绩回显 | 退出游戏回到大厅，宫格卡显示「最高 X 分」与星星数（读 M-Store） | `docs/shortscreens/1-14-大厅成绩回显.png` |

### 1.4 内置游戏「翻牌记忆」（7 项）

| # | 功能点 | 实现说明 | 对应文件 / 截图 |
|---|---|---|---|
| 17 | Flame 玩法实现 | 4×3 共 12 张卡（6 对动物），双翻比对，配对成功保留、不匹配延时盖回（`GameConfig.pairDelayMs` 儿童档 1.5s） | `lib/games/memory_match/memory_match_game.dart`、`docs/shortscreens/1-5-翻牌记忆初始棋盘.png` |
| 18 | 状态机与防连点 | `_phase` 四态：等待点击 / 已翻第一张 / 两张待比较 / 不配对待盖回；比较中与待盖回阶段屏蔽输入，防止连点错乱 | `memory_match_game.dart` |
| 19 | 步数与计时统计 | 每次「双翻」计 1 步；开局计时，结束时写入 `GameResult.metrics`（步数 / 用时） | `memory_match_game.dart` |
| 20 | 结算上报 | 游戏结束经 `resultStream` 抛出 `GameResult` → `GameScaffold` 调起**全局唯一**结算弹窗 → `ScoreSystem.commit()` 落库 | `lib/games/memory_match/memory_match_module.dart` |
| 21 | 资源加载 | 共享角色库 12 只动物贴图作为卡面；`Images(prefix: '')` 自建缓存按完整资源键取图，规避 Flame 默认 `assets/images/` 前缀导致的 404 | `memory_match_module.dart` |
| 22 | 暂停 / 恢复 | 暂停遮罩覆盖画布并冻结计时与输入，恢复后继续；与返回二次确认协同 | `docs/shortscreens/1-6-暂停遮罩.png`、`docs/shortscreens/1-8-继续游戏中.png` |
| 23 | 「再玩一次」 | 结算弹窗点「再玩一次」→ 调 `init(GameConfig)` 重置 → 步数归零、棋盘重新洗牌 | `docs/shortscreens/1-12-再玩一次重开.png` |

### 1.5 素材（3 项）

| # | 功能点 | 实现说明 | 对应文件 / 截图 |
|---|---|---|---|
| 24 | AI 生成共享角色库 | 按《素材资源指南》§4.1 统一 Prompt 模板生成 12 只萌系动物（猫/狗/兔/熊猫/狐狸/独角兽/小熊/企鹅/青蛙/小鸡/小猪/考拉），512×512 透明底 | `assets/shared/character-library/animal_01_cat.png` … `animal_12_koala.png` |
| 25 | 狐狸吉祥物 | 全局吉祥物（大厅 / 加载页复用），存 `assets/shared/ui/`，**全项目仅一份** | `assets/shared/ui/mascot_fox.png` |
| 26 | 素材后处理脚本 | `tool/prepare_character_assets.py`：容差洪泛去白底（保留主体）、统一尺寸与命名，删除重复原图 | `tool/prepare_character_assets.py` |

### 1.6 工程质量（4 项）

| # | 功能点 | 实现说明 | 对应文件 / 截图 |
|---|---|---|---|
| 27 | 静态检查零告警 | `flutter analyze` → `No issues found!` | `pubspec.yaml` |
| 28 | 冒烟/单元测试 | `flutter test` → 5 项全部通过（大厅渲染 / 商店点击提示 / 计分系统 / M-Store 读写 / 游戏清单） | `test/widget_test.dart` |
| 29 | Web 产物可运行 | `flutter build web --release` 成功；`pubspec.yaml` 资源声明改为**显式叶子目录**（`assets/shared/character-library/`、`assets/shared/ui/`），修复目录声明未递归导致素材未打包 | `pubspec.yaml` |
| 30 | 浏览器自动化验收脚本 | `tool/qa/verify_m1.js`（Node + Playwright/Chromium，360×800 竖屏基准）+ `tool/qa/board_analyzer.py`（PIL 像素取色 / 16×16 RGB 特征比对） | `tool/qa/` |

---

## 二、浏览器验证结果汇总表

> 验证环境：Playwright + Chromium（`--use-angle=swiftshader --no-sandbox`），手机竖屏基准视口 **360×800**（`deviceScaleFactor=3`、`isMobile`、`hasTouch`），符合 AGENT.md §1.1「以手机视口为基准」。
> 验证脚本：`tool/qa/verify_m1.js`；运行日志：`.logs/m1-browser-verify.log`。
> 量化方法：Canvas 游戏无 DOM 快照，故用 Python/PIL 对截图做**颜色包围盒定位 + 16×16 RGB 特征比对**，把像素坐标换算为逻辑坐标后与目标比对，避免肉眼判读误差。

| # | 功能点 | 操作步骤 | 预期结果 | 实际结果 | 是否通过 | 截图 |
|---|---|---|---|---|---|---|
| 1 | 代码静态检查 | `flutter analyze` | 无 issue | `No issues found!` | ✅ | — |
| 2 | 单元 / 冒烟测试 | `flutter test` | 全部通过 | `All tests passed!`（5/5） | ✅ | — |
| 3 | Web 可重复构建 | `flutter build web --release` | 产出 `build/web` | 构建成功 | ✅ | — |
| 4 | 共享素材打包 | 检查 `AssetManifest.json` | 含 shared 角色库与吉祥物 | `assets/shared/character-library/*`、`assets/shared/ui/mascot_fox.png` 全部在册 | ✅ | — |
| 5 | 大厅首屏渲染 | 打开 360×800 产物 | 「我的游戏」宫格 + 商店占位 + 家长入口 | 布局正常，中文无 tofu（字体回退生效） | ✅ | `1-1-大厅总览.png` |
| 6 | 大厅滚动 | 下滑 | 露出「游戏商店」区 | 商店区可见，占位卡完整 | ✅ | `1-3-大厅总览2.png`、`1-4-大厅商店区.png` |
| 7 | 商店占位卡点击 | 点击商店占位卡 | Toast 提示 | 弹出「更多游戏敬请期待」提示 | ✅ | `1-4-大厅商店区.png` |
| 8 | 家长中心进入 | 点击家长中心入口 | 进入家长中心页 | 页面正常，左上返回按钮可定位 | ✅ | `1-2-家长中心.png` |
| 9 | 家长中心返回 | 点击左上返回 | 回到大厅 | 正常返回 | ✅ | `1-3-大厅总览2.png` |
| 10 | 进入游戏 | 点击「翻牌记忆」卡 | 进入 `GameScaffold` 正常态 | 4×3 = 12 张卡全部渲染，贴图加载成功（无 404） | ✅ | `1-5-翻牌记忆初始棋盘.png` |
| 11 | 初始卡牌数校验 | 像素取色统计卡背色块 | 6 种马卡龙色 × 各 2 张 | 脚本识别初始卡牌数 = 6（颜色分组正确） | ✅ | `1-5-翻牌记忆初始棋盘.png` |
| 12 | 暂停遮罩 | 触发暂停 | 遮罩覆盖画布并冻结输入 | 遮罩显示，游戏不可操作 | ✅ | `1-6-暂停遮罩.png` |
| 13 | 返回二次确认 | 游戏中点返回 | 弹二次确认 | 弹出「离开游戏？本局进度将丢失」确认框 | ✅ | `1-7-返回二次确认.png` |
| 14 | 继续游戏 | 确认框选「继续游戏」 | 返回游戏且状态保留 | 恢复游戏，棋盘状态保留 | ✅ | `1-8-继续游戏中.png` |
| 15 | 双翻比对 | 点两张不匹配的卡 | 两张翻开待比对 | 两张同时翻开显示动物 | ✅ | `1-9-翻牌对比.png` |
| 16 | 配对成功 | 点两张相同动物 | 配对成功并保留 | lavender+mint 成功；sky+sakura 成功；peach+lemon 成功 | ✅ | `1-10-配对成功.png` |
| 17 | 全盘通关 | 脚本自动完成 6 对 | 6/6 配对成功 | `[玩法] 脚本判定配对 6/6 张` | ✅ | `1-10-配对成功.png` |
| 18 | 统一结算弹窗 | 通关后 | 弹出全局唯一结算弹窗 | 自动弹出，含星星 / 分数 / 用时 / 步数 + 双按钮 | ✅ | `1-11-统一结算弹窗.png` |
| 19 | 结算数据正确 | 读取弹窗内容 | 分数与星级符合公式 | 248 分 / 2 星（6 步），与 `computeScore` 公式一致 | ✅ | `1-11-统一结算弹窗.png` |
| 20 | 「再玩一次」 | 点「再玩一次」 | 重置并重开 | 步数归零、棋盘重新洗牌 | ✅ | `1-12-再玩一次重开.png` |
| 21 | 退出确认（局中） | 重开后点返回 | 再次弹二次确认 | 正常弹出 | ✅ | `1-13-返回二次确认2.png` |
| 22 | 退出回大厅 | 确认离开 | 回大厅且成绩已落库 | 大厅卡片显示「最高 248 分」+ 2 星 | ✅ | `1-14-大厅成绩回显.png` |
| 23 | 运行时报错 | 监听 pageerror / console.error | 0 错误 | `[控制台] 无错误`；`ERRORS: none` | ✅ | — |
| 24 | 真机 60fps / APK 装机 | `flutter run` 到 Android 真机 | 稳定 60fps、可安装 | 环境无 Android 设备与 SDK，未执行 | ⚠️ 未验证（环境限制） | — |

### M1 验收标准对照

| 里程碑文档 §1 M1 验收标准 | 结论 | 依据 |
|---|---|---|
| 核心框架（主题 / 组件 / 路由 / 存储）搭建完成 | ✅ 通过 | 表中 #1~#6、#27~#29 |
| 统一游戏框架（GameModule / GameScaffold / 统一结算 / 计分 / 注册表）可用 | ✅ 通过 | 表中 #7~#12 |
| 大厅「我的游戏」+ 商店占位 + 家长入口 | ✅ 通过 | 表中 #13~#16 |
| 至少 1 款内置游戏可玩（计入 19 款） | ✅ 通过 | 「翻牌记忆」，表中 #17~#23 |
| 浏览器视口（360×800）实测截图 | ✅ 通过 | 14 张截图，见 `docs/shortscreens/` |
| 真机 60fps / 性能达标 | ⚠️ 部分（环境限制） | 见表中 #24 与「遗留问题」第 1 条 |

---

## 三、开发中遇到的问题及解决方式

| # | 问题现象 | 根因 | 解决方式 |
|---|---|---|---|
| 1 | `write_to_file` 多次丢失 `filePath` 参数导致写入失败 | 工具调用参数构造不稳定 | 改为「`Set-Content` 建占位文件 → `replace_in_file` 填充内容」两步法，后续全部稳定 |
| 2 | 测试编译报错 `const_eval_method_invocation` | `const int score = ScoreSystem.computeScore(...)`——`computeScore` 非编译期常量 | 改为 `final int score = ...` |
| 3 | Widget 测试找不到「游戏商店」 | 默认测试视口 800×600，商店区在折叠下方不可见 | 新增 `usePhoneViewport(tester)` 助手（360×800 / dPR=1.0），并用 `tester.drag` 滚动定位 |
| 4 | Web 端中文显示为方块（tofu） | M0 遗留：未内置中文字体，且本机网络受限无法下载 CJK 字体（代理 TLS 失败、PyPI/npm 被墙） | 改用 `fontFamilyFallback`（PingFang SC / Noto Sans CJK SC / Microsoft YaHei）系统字体回退；实测中文正常且**包体零增加** |
| 5 | 角色库贴图未打进 Web 产物，进入游戏报 404 | `pubspec.yaml` 用目录声明 `assets/shared/`，Flutter 资源声明**不递归**子目录 | 改为显式声明叶子目录 `assets/shared/character-library/`、`assets/shared/ui/`；`flutter clean` 后重新构建解决 |
| 6 | Flame `Sprite.load` 抛 404，游戏进入「游戏没能打开」错误态 | `Flame.images` 默认前缀为 `assets/images/`，与真实资源键不匹配 | 自建 `Images(prefix: '')` 缓存，按完整资源键取图；同时补 `package:flame/cache.dart`、`package:flame/sprite.dart` 导入 |
| 7 | **真实玩法 BUG**：第二张卡点击被吞，步数恒为 0、游戏无法结束 | 防连点锁写得过严：`_phase != 0` 即拒绝输入，误把「已翻第一张」阶段也屏蔽 | 放宽为「等待点击」与「已翻第一张」两个阶段可点击（构成一次双翻），比较中 / 待盖回阶段仍屏蔽 |
| 8 | 像素取色 bbox 被零星抗锯齿像素拉偏，整页被框成一张卡 | 全分辨率直接找色，抗锯齿边缘像素与主色不连续 | 分析器改为 1/8 缩略粗筛（阈值 70）定候选窗口 → 窗口内全分辨率求精确 bbox |
| 9 | 配对判定误报（相似颜色动物被判为同一张） | 灰度特征丢失色相差异，lavender / sky 等近似色混淆 | 改用 16×16 RGB 特征 + 平均绝对差 ≤ 8 作为同一图判据 |
| 10 | 卡面翻开时卡背颜色消失，无法用颜色定位判定配对 | 取色方案依赖「未翻开」的卡背色 | 分析器新增「按初始棋盘固定矩形取特征」模式，先记录初始矩形再对翻开后卡面取特征 |
| 11 | Dart 编译错误「`library;` 指令必须置于 import 之前」 | 指令顺序违规 | 调整顺序，指令置顶 |
| 12 | `FlameGame` 无公开 `pause/resume/dispose` 方法 | Flame 1.38 的引擎生命周期方法名不同 | 改用 `pauseEngine()` / `resumeEngine()`；模块 `dispose()` 内不得调 `super.dispose()` |
| 13 | 类型与导入问题若干 | `TapCallbacks` / `TapDownEvent` 需 `flame/events.dart`；`Rect.contains(Vector2)` 与 `Offset` 不兼容；PowerShell 管道删除报 `InputObjectNotBound` | 补导入、坐标显式转 `Offset`、删除命令改用 `-Path "目录\通配符" -Force` |
| 14 | 家长中心「知道了」按钮误用橙色主按钮色 | 直接套用 `AppButton` 主色，违反 UI 规范 §7「白卡 + 深紫字」 | 改为 `TextButton.styleFrom(foregroundColor: AppColors.brandDeep)` |
| 15 | **验收后视觉缺陷**：游戏内 HUD 顶部难度按钮（2×3 / 2×4 / 3×4）下边缘被切平 | `_LevelChip` 的 `shadow.rim` 画在布局盒**之外**（下方 3px），而 HUD 的 `Padding` 底边为 `0`，紧随其后的 `Expanded(GameWidget)` 画布在 `Column` 中更晚绘制，把这 3px 底边整片盖掉。像素实测：卡槽底边只残留 0.5px 浅色，其余全被覆盖 | HUD 底部预留 `AppSpacing.sm`（8px）> `AppShadows.rimThin`（3px），底边完整可见；并在 UI 规范 §9 自检清单新增「厚底边下方不得紧邻不透明兄弟节点」一条 |
| 16 | **验收后视觉缺陷**：退出确认弹窗「退出」按钮轮廓不可辨识 | 次按钮为 `panel.bg` 白底 + 底边 `#D8D4E8`，落在白色弹窗面板上：上沿与两侧无任何边界，底边对比度仅 ≈1.4:1，整颗按钮几乎"消失" | 新增 Token `btn.secondaryBorder = #9B93BC`（白底对比度 ≈2.9:1），次按钮补 2px 描边且厚底边取同色（避免"深描边 + 浅光晕"双层边）；同步新增 `AppStrokes` / `AppShadows.rimThin`、`rimThick` 消除魔法值，并回写 UI 规范 §1.5、§5.1、§6.1、§9 |

---

## 四、遗留问题与后续建议

| # | 遗留项 | 现状 | 建议 / 计划 |
|---|---|---|---|
| 1 | 真机 60fps 与 APK 装机验证 | 本环境无 Android 设备与 SDK，未执行 | 在 Android 真机（建议 ≥ Android 8、2GB 内存以上）上跑 `flutter run --profile`，用 Flutter Inspector / `debugPrint` 观察帧率；确认低端机不掉帧后再出 release APK |
| 2 | 音效未接入 | `assets/shared/audio/` 尚未落地，交互无声音反馈 | M2 前接入 Kenney Interface Sounds（CC0），统一由 `AudioService` 播放，配合家长中心音量开关 |
| 3 | 护眼模式 / 单次游玩时长未实现 | `GameConfig` 已有 `level` / `pairDelayMs` / `showTimer` 字段，家长中心为占位页 | M2 在家长中心落地「护眼时长、难度档位、音量」三项下发，贯通 `GameConfig` |
| 4 | 游戏商店下载 / 解锁链路未实现 | 仅占位卡 + Toast；`GameProgress.unlocked` 字段已预留 | M2 实现下载管理器：素材包 zip + md5 校验 + 落盘 + 解锁置位 |
| 5 | 翻牌记忆难度上限单一 | 当前固定 6 对（12 张） | 按 `GameConfig.level` 分档：入门 4 对 / 标准 6 对 / 挑战 8 对，并同步 `perfectSteps` |
| 6 | 角色库表情态缺失 | 目前每只动物仅 1 张（idle），未生成 happy / sad / surprise | 按《素材资源指南》§3.1 补齐 12 × 4 表情态，作为全局复用资产沉淀 |
| 7 | 中文字体方案需固化 | 当前依赖系统字体回退，个别低端机可能仍缺字 | 评估打包一份可商用中文子集字体（OFL），或引入字体动态下载；Web 端保持现有回退 |
| 8 | `buildHud()` 为可选扩展 | 计划书 §4.3 的 `GameModule` 未含 HUD 成员，本项目以默认实现扩展，不破坏既有契约 | 已在 `game_module.dart` 注释说明；后续如需纳入正式契约，同步更新计划书 |
| 9 | 角色库贴图体积累 | 12 张 512×512 PNG 单份较大 | 转 WebP/AVIF 或按需降采样，控制安装包体积 |
| 10 | 自动化验收脚本依赖固定像素 | `tool/qa/verify_m1.js` 以颜色与几何特征定位卡片 | 游戏换肤 / 改分辨率后需同步标定；后续可改为读取游戏内 debug 标记位辅助定位 |
