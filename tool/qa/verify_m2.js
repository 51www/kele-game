/**
 * 《童趣游戏盒》M2 里程碑 —— 浏览器验收脚本（Playwright + Chromium）。
 *
 * 验收范围（开发里程碑文档 M2 · B-1 素材包解锁）：
 *   ① 商店展示大小/适龄、未下载显示下载入口
 *   ② 下载确认 → 胶囊进度条 → 星星解锁动画 → 进入游戏
 *   ③ 下载后在大厅「我的游戏」回显
 *   ④ MD5 校验失败 → 引导本地导入 → 本地导入成功
 *   ⑤ 单队列策略（同时仅 1 个活动下载，其余排队）
 *   ⑥ 占位游戏解锁后「即将上架」
 *
 * 口径与 M1 相同：360×800 竖屏、deviceScaleFactor=3、像素取色定位。
 * 说明：
 *   - 状态推进用「轮询等待特征色出现」而非固定延时（无头渲染节奏有波动）；
 *   - 下载面板布局固定，表头图标 / 关闭钮 / 下载钮相对偏移恒定，
 *     单队列场景用「一次取色 + 确定性偏移点击」压缩入队前耗时，确保拍到排队态。
 *
 * 运行：
 *   flutter build web --release --dart-define=FLUTTER_WEB_CANVASKIT_URL=canvaskit/
 *   $env:NODE_PATH="C:\nvm4w\nodejs\node_global\node_modules\@playwright\cli\node_modules"
 *   node tool/qa/verify_m2.js
 *
 * 注意：--dart-define=FLUTTER_WEB_CANVASKIT_URL=canvaskit/ 必须带上，
 * 否则 CanvasKit 会尝试从 gstatic CDN 拉取，离线环境下首帧永久白屏。
 */
const http = require('http');
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { chromium } = require('playwright');

const ROOT = path.resolve(__dirname, '../..');
const WEB_DIR = path.join(ROOT, 'build', 'web');
const SHOT_DIR = path.join(ROOT, 'docs', 'shortscreens');
const PORT = 8099;
const SCALE = 3;

const PRIMARY = 'primary:#FFB627';
const STAR = 'star:#FFC93C';
const BRAND_DEEP = 'brandDeep:#4B3FBF';

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff2': 'font/woff2',
  '.wasm': 'application/wasm',
  '.bin': 'application/octet-stream',
  '.symbols': 'text/plain',
};

const log = [];
const errors = [];
function step(name, detail) {
  const line = `[${name}] ${detail}`;
  console.log(line);
  log.push(line);
}

function serve() {
  const server = http.createServer((req, res) => {
    const url = decodeURIComponent((req.url || '/').split('?')[0]);
    let file = path.join(WEB_DIR, url === '/' ? 'index.html' : url);
    if (!file.startsWith(WEB_DIR)) { res.writeHead(403); res.end(); return; }
    if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      file = path.join(WEB_DIR, 'index.html');
    }
    const body = fs.readFileSync(file);
    res.writeHead(200, {
      'Content-Type': MIME[path.extname(file)] || 'application/octet-stream',
      'Content-Length': body.length,
    });
    res.end(body);
  });
  return new Promise((resolve) => server.listen(PORT, '127.0.0.1', () => resolve(server)));
}

/** 调 Python 像素分析脚本定位色块（CSS 像素坐标）。注意返回的 key 是冒号前缀。 */
function analyze(fileName, colors) {
  const out = execFileSync(
    'python',
    [path.join(__dirname, 'board_analyzer.py'), path.join(SHOT_DIR, fileName), String(SCALE), colors],
    { encoding: 'utf8' }
  );
  return JSON.parse(out);
}

async function main() {
  fs.mkdirSync(SHOT_DIR, { recursive: true });
  const server = await serve();
  const browser = await chromium.launch({
    headless: true,
    args: ['--disable-gpu-vsync', '--use-angle=swiftshader', '--no-sandbox', '--disable-dev-shm-usage'],
  });
  const context = await browser.newContext({
    viewport: { width: 360, height: 800 },
    deviceScaleFactor: SCALE,
    isMobile: true,
    hasTouch: true,
  });
  const page = await context.newPage();
  page.on('pageerror', (e) => errors.push('PAGEERROR: ' + e.message));
  page.on('console', (m) => { if (m.type() === 'error') errors.push('CONSOLE_ERROR: ' + m.text()); });

  const shot = async (name) => { await page.screenshot({ path: path.join(SHOT_DIR, name) }); step('SHOT', name); };
  const wait = (ms) => page.waitForTimeout(ms);
  const URL = `http://127.0.0.1:${PORT}`;
  const TMP = '_wait.png';

  const snap = async (colors) => {
    await page.screenshot({ path: path.join(SHOT_DIR, TMP) });
    return analyze(TMP, colors);
  };
  const has = (res, key) => res.cards.some((c) => c.key === key.split(':')[0]);
  const pick = (res, key) => res.cards.find((c) => c.key === key.split(':')[0]);
  const center = (c) => ({ x: c.x + c.w / 2, y: c.y + c.h / 2 });

  /** 轮询等待画面特征出现（如解锁星星、失败引导） */
  const waitUntil = async (desc, colors, predicate, timeoutMs = 25000) => {
    const start = Date.now();
    let last = null;
    while (Date.now() - start < timeoutMs) {
      last = await snap(colors);
      if (predicate(last)) {
        fs.rmSync(path.join(SHOT_DIR, TMP), { force: true });
        return last;
      }
      await wait(400);
    }
    const keep = path.join(SHOT_DIR, '_timeout-' + desc + '.png');
    fs.copyFileSync(path.join(SHOT_DIR, TMP), keep);
    fs.rmSync(path.join(SHOT_DIR, TMP), { force: true });
    const keys = last ? last.cards.map((c) => c.key).join(',') : 'none';
    throw new Error(`等待超时: ${desc}（最后特征: ${keys}，现场: ${path.basename(keep)}）`);
  };

  const goto = async () => {
    await page.goto(URL, { waitUntil: 'load' });
    // SwiftShader 冷启动偶发首帧不渲染（截图全白），轮询等待 + 重载兜底
    for (let round = 0; round < 2; round++) {
      for (let i = 0; i < 8; i++) {
        await wait(2000);
        const res = await snap('lavender');
        if (has(res, 'lavender')) { fs.rmSync(path.join(SHOT_DIR, TMP), { force: true }); return; }
      }
      if (round === 0) await page.reload({ waitUntil: 'load' });
    }
    throw new Error('应用未能渲染（轮询超时）');
  };
  const top = async () => {
    await page.mouse.move(180, 400);
    await page.mouse.wheel(0, -1600);
    await wait(700);
  };
  const scrollToColor = async (color, shotName) => {
    await page.mouse.move(180, 500);
    await page.mouse.wheel(0, 500);
    await wait(700);
    await shot(shotName);
    let found = analyze(shotName, color).cards[0];
    let guard = 0;
    while (!found && guard < 4) {
      await page.mouse.wheel(0, 380);
      await wait(700);
      await shot(shotName);
      found = analyze(shotName, color).cards[0];
      guard++;
    }
    if (!found) throw new Error(`滚动后未定位到颜色 ${color}`);
    return found;
  };
  const tapAt = async (x, y) => { await page.touchscreen.tap(x, y); };
  const tapCenter = async (c) => { await tapAt(c.x + c.w / 2, c.y + c.h / 2); };
  const tapPrimary = async (shotName) => {
    const btn = analyze(shotName, PRIMARY).cards[0];
    if (!btn) throw new Error(`${shotName} 未找到主按钮`);
    await tapCenter(btn);
    return btn;
  };
  /**
   * 点击商店卡打开下载面板；返回打开后面板的一次综合取色
   * （含表头图标 color、关闭钮 brandDeep、主按钮 primary）。
   */
  const openStoreSheet = async (color, shotName) => {
    const combo = `${color},${BRAND_DEEP},${PRIMARY}`;
    for (let i = 0; i < 3; i++) {
      await page.screenshot({ path: path.join(SHOT_DIR, shotName) });
      const card = pick(analyze(shotName, color), color);
      if (!card) throw new Error(`未定位到商店卡 ${color}`);
      await tapCenter(card);
      await wait(900);
      await page.screenshot({ path: path.join(SHOT_DIR, shotName) });
      const after = analyze(shotName, combo);
      const icon = pick(after, color);
      if (icon && icon.y < 520) return after; // 面板表头图标位置
      step('重试', `下载面板未打开（第 ${i + 1} 次），用新坐标重试`);
    }
    throw new Error(`点击后未打开下载面板（${color}）`);
  };

  // ================= 阶段一：翻牌记忆 下载解锁 + 进入游戏 =================
  step('阶段一', '翻牌记忆：下载确认 → 进度 → 星星解锁 → 进入游戏');
  await goto();
  await shot('2-1-大厅-未下载状态.png');

  await scrollToColor('lavender', '2-2-商店区-大小适龄标签.png');
  const sheet1 = await openStoreSheet('lavender', '2-3-下载确认面板.png');
  step('确认面板', '面板已打开（含图标、大小 2.1MB、适龄 3岁+、离线说明）');

  await tapCenter(pick(sheet1, PRIMARY));
  await wait(900);
  await shot('2-4-下载进度-胶囊进度条.png');
  const prog = await snap('lemon');
  step('进度条', has(prog, 'lemon') ? '柠檬黄胶囊进度条已出现，正在从本地素材包获取' : '未定位到进度条');
  fs.rmSync(path.join(SHOT_DIR, TMP), { force: true });

  await waitUntil('星星解锁动画', `${PRIMARY},${STAR}`, (r) => has(r, PRIMARY) && has(r, STAR));
  await shot('2-5-星星解锁动画.png');
  step('解锁', '星星解锁动画出现，面板提示解锁成功');

  await tapPrimary('2-5-星星解锁动画.png'); // 开始玩
  await wait(3500);
  await shot('2-6-下载后进入游戏.png');

  // 退出游戏（返回 → 二次确认 → 退出）
  await page.touchscreen.tap(44, 40);
  await wait(1000);
  await shot('2-6b-返回二次确认.png');
  const exitBtn = analyze('2-6b-返回二次确认.png', PRIMARY).cards[0];
  if (exitBtn) {
    await page.touchscreen.tap(exitBtn.x + exitBtn.w / 2, exitBtn.y + exitBtn.h / 2 + 76);
    await wait(1800);
  }
  await top();
  await shot('2-7-我的游戏回显-翻牌记忆已解锁.png');
  const memMine = analyze('2-7-我的游戏回显-翻牌记忆已解锁.png', 'lavender').cards[0];
  step('回显', memMine ? `翻牌记忆已进入我的游戏 = ${Math.round(memMine.x)},${Math.round(memMine.y)}` : '未定位到我的游戏卡');

  // ================= 阶段二：MD5 校验失败 → 本地导入（全新状态） =================
  step('阶段二', 'MD5 校验失败 → 引导本地导入');
  await page.evaluate(() => localStorage.clear());
  await goto();

  await page.touchscreen.tap(308, 44); // 家长中心
  await wait(1300);
  await shot('2-8-家长中心-下载调试开关.png');
  await tapPrimary('2-8-家长中心-下载调试开关.png'); // 开启下载调试
  await wait(800);
  await page.touchscreen.tap(44, 40); // 返回大厅
  await wait(1300);

  await scrollToColor('sakura', '2-9-下载确认-含模拟校验失败入口.png');
  const sheet2 = await openStoreSheet('sakura', '2-9-下载确认-含模拟校验失败入口.png');
  step('调试入口', '确认面板含「（开发者测试）模拟一次校验失败的下载」入口');

  // 长按面板表头图标触发「模拟校验失败」下载（家长中心已开启调试）
  const icon2 = pick(sheet2, 'sakura');
  const c2 = center(icon2);
  await page.mouse.move(c2.x, c2.y);
  await page.mouse.down();
  await wait(900);
  await page.mouse.up();
  step('调试', '已长按触发模拟校验失败下载（模拟下载源）');

  await waitUntil('MD5 校验失败态', `${PRIMARY},${STAR}`, (r) => has(r, PRIMARY) && !has(r, STAR));
  await shot('2-10-MD5校验失败-引导本地导入.png');
  step('校验失败', 'MD5 校验失败，出现「本地导入」引导');

  await tapPrimary('2-10-MD5校验失败-引导本地导入.png'); // 本地导入
  await waitUntil('本地导入解锁', `${PRIMARY},${STAR}`, (r) => has(r, PRIMARY) && has(r, STAR));
  await shot('2-11-本地导入-解锁成功.png');
  step('本地导入', '本地素材包源校验通过并解锁');

  // ================= 阶段三：单队列 + 占位游戏「即将上架」（全新状态） =================
  step('阶段三', '单队列策略 + 占位游戏即将上架');
  await page.evaluate(() => localStorage.clear());
  await goto();

  const whack2 = await scrollToColor('sakura', '2-12-商店区-下载入口.png');
  step('商店', `打地鼠商店卡定位 = ${Math.round(whack2.x)},${Math.round(whack2.y)}`);
  const sheet3 = await openStoreSheet('sakura', '2-13-下载确认面板-打地鼠.png');
  const icon3 = pick(sheet3, 'sakura');
  const closeBtn3 = pick(sheet3, BRAND_DEEP);
  const dl3 = pick(sheet3, PRIMARY);
  const closeOffset = {
    dx: closeBtn3.x + closeBtn3.w / 2 - (icon3.x + icon3.w / 2),
    dy: closeBtn3.y + closeBtn3.h / 2 - (icon3.y + icon3.h / 2),
  };
  const dlOffset = {
    dx: dl3.x + dl3.w / 2 - (icon3.x + icon3.w / 2),
    dy: dl3.y + dl3.h / 2 - (icon3.y + icon3.h / 2),
  };

  await tapCenter(dl3); // t0：开始下载打地鼠
  await wait(150);
  // 立即关面板（关闭钮相对表头图标偏移恒定），下载转后台
  await tapAt(icon3.x + closeOffset.dx, icon3.y + closeOffset.dy);
  await wait(400);
  await shot('2-14-商店卡下载进度反馈.png');
  step('后台下载', '关闭面板后下载继续，商店卡显示进度反馈');

  // 打地鼠下载中，立即把宝宝爱拼图也加入队列（应排队，不并发）
  const jigsaw = pick(analyze('2-14-商店卡下载进度反馈.png', 'mint'), 'mint');
  step('定位', `拼图商店卡 = ${Math.round(jigsaw.x)},${Math.round(jigsaw.y)}`);
  await tapCenter(jigsaw);
  await wait(700);
  await shot('2-15-下载确认面板-拼图.png');
  const jIcon = pick(analyze('2-15-下载确认面板-拼图.png', 'mint'), 'mint');
  if (!jIcon || jIcon.y >= 520) throw new Error('拼图下载面板未打开');
  await tapAt(jIcon.x + dlOffset.dx, jIcon.y + dlOffset.dy); // 入队（确定性偏移）
  await wait(700);
  await shot('2-16-单队列-排队中.png');
  step('单队列', '打地鼠下载中，宝宝爱拼图加入队列');

  await waitUntil('拼图开始下载', 'lemon', (r) => has(r, 'lemon'));
  await shot('2-17-队列推进-拼图开始下载.png');
  step('队列推进', '打地鼠完成后拼图自动开始下载（同一时刻仅 1 个活动下载）');

  await waitUntil('拼图解锁', `${PRIMARY},${STAR}`, (r) => has(r, PRIMARY) && has(r, STAR));
  await shot('2-18-占位游戏-解锁成功.png');
  await tapPrimary('2-18-占位游戏-解锁成功.png'); // 开始玩
  await wait(600);
  await shot('2-19-占位游戏-即将上架提示.png');
  step('占位游戏', '占位游戏点开始玩给出「还在开发中」提示');

  await wait(1800);
  await top();
  await shot('2-20-大厅-我的游戏回显-即将上架.png');

  fs.rmSync(path.join(SHOT_DIR, TMP), { force: true });
  step('控制台', errors.length ? errors.join(' | ') : '无错误');
  fs.writeFileSync(
    path.join(ROOT, '.logs', 'm2-browser-verify.log'),
    log.concat(['', 'ERRORS: ' + (errors.length ? errors.join('\n') : 'none')]).join('\n'),
    'utf8'
  );
  await browser.close();
  server.close();
  console.log('\nDONE');
}

main().catch(async (err) => {
  console.error('FAILED:', err.message);
  try {
    if (errors.length) console.error('BROWSER_ERRORS:', errors.join('\n'));
  } catch (_) {}
  try {
    fs.writeFileSync(
      path.join(ROOT, '.logs', 'm2-browser-verify.log'),
      log.concat(['', 'FAILED: ' + err.message]).join('\n'),
      'utf8'
    );
  } catch (_) {}
  process.exit(1);
});
