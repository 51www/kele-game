# 童趣游戏盒（tongqu_gamebox）

面向 3~9 岁儿童的本地小游戏合集（Flutter 应用）。深紫渐变糖果风儿童界面 + 家长中心：

- **游戏**：翻牌记忆、打地鼠、宝宝爱拼图（本地素材包按需"下载"解锁，含下载确认、进度、星星结算）
- **儿童保护**：家长门（算术题 / 长按 3 秒随机轮换）、连续 20 分钟强制眼保健操 30 秒（不可跳过）、每日时长上限（20~120 分钟）到点「明天见」锁屏
- **家长中心**：时长设置、游戏隐藏 / 删除（家长门 + 二次确认）、全局音效
- **数据**：本地 SharedPreferences 存储，离线可用

里程碑与验收记录见 `.logs/`，浏览器验收截图见 `docs/shortscreens/`。

## 环境要求

- Flutter 3.47.x（stable）、Android SDK / Chrome（Web 调试）

## 运行（开发调试）

```bash
flutter pub get
flutter run -d chrome          # Web 调试
flutter run                    # 默认设备
```

## 部署（Web 构建发布）

```bash
# 必须带 --no-web-resources-cdn，否则 CanvasKit 从 gstatic CDN 加载，离线/受限网络下白屏
flutter build web --release --no-web-resources-cdn --dart-define=FLUTTER_WEB_CANVASKIT_URL=canvaskit/
```

产物在 `build/web/`，任意静态服务器可直接托管，例如：

```bash
python -m http.server 8080 --directory build/web
# 或 npx serve build/web
```

> 注意：静态服务需将未知路径回退到 `index.html`（当前路由基于 hash / 单页）。

## Android 打包

```bash
flutter build apk --release    # 产物 build/app/outputs/flutter-apk/
```

## 浏览器验收（QA）

```bash
$env:NODE_PATH="C:\nvm4w\nodejs\node_global\node_modules\@playwright\cli\node_modules"
node tool/qa/verify_m3.js      # M1/M2/M3 各有对应脚本
```
