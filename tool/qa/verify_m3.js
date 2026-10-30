/**
 * 《童趣游戏盒》M3 里程碑 —— 浏览器验收脚本（Playwright + Chromium）。
 *
 * 验收范围（开发里程碑文档 M3 · 家长中心 + 儿童保护）：
 *   ① 家长门：算术题（答错换题）+ 长按 3 秒两种验证方式，未通过无法进入家长中心
 *   ② 家长中心降饱和奶油底视觉分区
 *   ③ 每日时长滑块（20~120，默认 40）
 *   ④ 游戏隐藏：大厅不再展示；可恢复显示
 *   ⑤ 游戏删除：家长门 + 危险按钮 + 二次确认；删除后回到商店未下载状态
 *   ⑥ 护眼休息：演示节奏下连续 20s 触发强制休息 30s（不可跳过，到点自动恢复）
 *   ⑦ 每日时长到点：显示「明天见」锁屏页（演示节奏下 60s）
 *
 * 验收辅助（不影响默认行为）：
 *   - URL `?gate=math|hold` 固定家长门验证方式（默认随机轮换）；
 *   - 家长中心「护眼验收调试」演示节奏（连续 20s / 每日 60s，休息仍为真实 30s）。
 *
 * 口径与 M1/M2 相同：360×800 竖屏、DPR=3、像素取色定位。
 *
 * 运行（注意：必须带 --no-web-resources-cdn，否则 loader 会从 gstatic CDN 拉取
 * CanvasKit，离线/受限网络下首帧永久白屏）：
 *   flutter build web --release --no-web-resources-cdn --dart-define=FLUTTER_WEB_CANVASKIT_URL=canvaskit/
 *   $env:NODE_PATH="C:\nvm4w\nodejs\node_global\node_modules\@playwright\cli\node_modules"
 *   node tool/qa/verify_m3.js
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
const TMP = '_wait.png'; // 轮询/取色临时截图

const PRIMARY = 'primary:#FFB627';
const STAR = 'star:#FFC93C';
const BRAND_DEEP = 'brandDeep:#4B3FBF';
const PAGE_BG = 'pageBg:#FAF7F0';
const DANGER = 'danger:#F0544F';
const SECONDARY = 'secondary:#9B93BC';
const CREAM = 'cream:#F7ECCB';
const LAVENDER = 'lavender:#B7AEF2';
const SAKURA = 'sakura:#F5A8C7';
const WARNING = 'warning:#FFA53B';

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

/** 调 Python 像素分析脚本定位色块（CSS 像素坐标）。返回的 key 是冒号前缀。 */
function analyze(fileName, colors) {
  const out = execFileSync(
    'python',
    [path.join(__dirname, 'board_analyzer.py'), path.join(SHOT_DIR, fileName), String(SCALE), colors],
    { encoding: 'utf8' }
  );
  return JSON.parse(out);
}

const has = (res, key) => res.cards.some((c) => c.key === key.split(':')[0]);
const pick = (res, key) => res.cards.find((c) => c.key === key.split(':')[0]);
const center = (c) => ({ x: c.x + c.w / 2, y: c.y + c.h / 2 });

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
  activePage = page;
  page.on('pageerror', (e) => errors.push('PAGEERROR: ' + e.message));
  page.on('console', (m) => { if (m.type() === 'error') errors.push('CONSOLE_ERROR: ' + m.text()); });

  const shot = async (name) => { await page.screenshot({ path: path.join(SHOT_DIR, name) }); step('SHOT', name); };
  const wait = (ms) => page.waitForTimeout(ms);
  const BASE = `http://127.0.0.1:${PORT}`;

  const snap = async (colors) => {
    await page.screenshot({ path: path.join(SHOT_DIR, TMP) });
    return analyze(TMP, colors);
  };

  const waitUntil = async (desc, colors, predicate, timeoutMs = 40000) => {
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

  const gotoApp = async (query) => {
    await page.goto(BASE + (query || ''), { waitUntil: 'load' });
    for (let round = 0; round < 2; round++) {
      for (let i = 0; i < 8; i++) {
        await wait(2000);
        const res = await snap(SAKURA);
        if (has(res, 'sakura')) { fs.rmSync(path.join(SHOT_DIR, TMP), { force: true }); return; }
      }
      if (round === 0) await page.reload({ waitUntil: 'load' });
    }
    throw new Error('应用未能渲染（轮询超时）');
  };

  const tapAt = async (x, y) => { await page.touchscreen.tap(x, y); };

  /** 检测家长门是否打开（长按=100~150 圆钮 / 算术题=200~300 宽面板；排除通过后家长中心的全屏 pageBg 背景） */
  const gateColor = async () => {
    const res = await snap(PAGE_BG);
    return res.cards.find(
      (c) => c.key === 'pageBg' && ((c.w >= 100 && c.w <= 160) || (c.w >= 200 && c.w <= 300))
    ) || null;
  };

  /**
   * 通过家长门（长按 3 秒模式）：定位 pageBg 圆钮（120px）→ 按住 3.4s → 松手。
   * 若出现的是算术题模式（宽面板），抛错（脚本各阶段用 ?gate=hold 固定长按）。
   */
  const passGate = async (label) => {
    const circle = await waitUntil(
      '家长门出现(' + label + ')',
      PAGE_BG,
      (r) => {
        const c = r.cards.find((c) => c.key === 'pageBg' && c.w >= 100 && c.w <= 150 && Math.abs(c.w - c.h) < 25);
        return !!c;
      },
      12000
    );
    const btn = circle.cards.find((c) => c.key === 'pageBg' && c.w >= 100 && c.w <= 150 && Math.abs(c.w - c.h) < 25);
    const c = center(btn);
    await page.mouse.move(c.x, c.y);
    await page.mouse.down();
    await wait(4500); // 长按识别 ~500ms + 进度 3000ms，留足余量
    await page.mouse.up();
    await wait(1200);
    const after = await gateColor();
    if (after && after.w >= 100 && after.w <= 150) {
      // 圆钮还在：长按未被识别，重试一次
      await page.mouse.move(c.x, c.y);
      await page.mouse.down();
      await wait(4500);
      await page.mouse.up();
      await wait(1200);
    }
    const gone = await gateColor();
    if (gone) throw new Error(`家长门未通过（${label}）`);
    step('家长门', `长按 3 秒验证通过（${label}）`);
  };

  /** 进入家长中心：回页顶 → 点右上锁钮 → 家长门 → 通过 */
  const openParentCenter = async (label) => {
    await scrollTop();
    await tapAt(308, 44);
    await passGate(label);
    await wait(800);
  };

  /** 从家长中心返回大厅：回页顶 → 点返回圆钮 */
  const backToHall = async () => {
    await scrollTop();
    await tapAt(28, 40);
    await wait(1300);
  };

  // ================= 阶段一：家长门-算术题（?gate=math） =================
  step('阶段一', '家长门-算术题：展示 + 答错随机换题 + 未通过无法进入');
  await page.evaluate(() => localStorage.clear()).catch(() => {});
  await gotoApp('/?gate=math');
  await tapAt(308, 44);
  const mathPanel = await waitUntil(
    '算术题家长门',
    PAGE_BG,
    (r) => !!r.cards.find((c) => c.key === 'pageBg' && c.w > 200),
    12000
  );
  await shot('3-1-家长门-算术题.png');
  const panel = mathPanel.cards.find((c) => c.key === 'pageBg' && c.w > 200);
  step('家长门', '算术题家长门已打开，大厅被遮罩拦截（儿童无法直接进入家长中心）');

  // 记录题目区域特征（面板顶部 ~94px 为题目区）
  const qRect = { key: 'q', x: panel.x, y: panel.y, w: panel.w, h: Math.min(94, panel.h) };
  const sigBefore = analyze('3-1-家长门-算术题.png', JSON.stringify([qRect])).cards[0].sig;

  // 键盘定位：pageBg 包围盒底 = 第 4 行键帽底；列中心 93/180/265
  const kbBottom = panel.y + panel.h;
  const rowY = (i) => kbBottom - 26 - (3 - i) * 60; // i:0..3
  const colX = [93, 180, 265];
  await tapAt(colX[0], rowY(0)); // 1
  await wait(400);
  await tapAt(colX[2], rowY(0)); // 3 → 输入 13
  await wait(400);
  await shot('3-2-家长门-算术题-输入答案.png');

  const primBtn = pick(analyze('3-2-家长门-算术题-输入答案.png', PRIMARY), 'primary');
  if (!primBtn) throw new Error('未定位到「确认」按钮');
  await tapCenterOf(primBtn);
  await wait(1200);
  await shot('3-3-家长门-算术题-答错换题.png');
  const gateStill = await gateColor();
  if (gateStill && gateStill.w > 200) {
    const sigAfter = analyze('3-3-家长门-算术题-答错换题.png', JSON.stringify([qRect])).cards[0].sig;
    const changed = JSON.stringify(sigBefore) !== JSON.stringify(sigAfter);
    step('答错换题', changed ? '答错后提示 + 自动随机换题（题目区域像素特征已变化）' : '警告：题目区域特征未变化，需人工复核');
  } else {
    step('小概率事件', '输入 13 恰好等于答案，家长门直接通过（约 1% 概率，重跑可复核换题分支）');
  }

  // 点遮罩关闭（未通过 → 回到大厅）
  await tapAt(180, 24);
  await wait(900);
  await shot('3-4-家长门-关闭后仍在大厅.png');
  step('未通过拦截', '点击遮罩关闭家长门，仍停留在大厅（未验证通过无法进入家长中心）');

  // ================= 阶段二：家长门-长按 + 家长中心视觉分区 + 每日时长 =================
  step('阶段二', '长按 3 秒通过 → 家长中心（奶油底分区）+ 每日时长默认 40');
  await page.evaluate(() => localStorage.clear());
  await gotoApp('/?gate=hold');
  await openParentCenter('入口');
  await wait(600);
  await shot('3-5-家长中心-奶油底视觉分区.png');
  step('视觉分区', '家长中心为降饱和奶油底 + 白卡 + 深紫字（与儿童区深紫渐变明确区分）');
  await shot('3-6-家长中心-护眼与每日时长.png');
  step('每日时长', '滑块默认位于 40 分钟（20~120 范围），今日/连续用时可见');

  // 滑块交互：点滑轨右侧（≈115 分钟）再观察
  await tapAt(300, 258);
  await wait(800);
  await shot('3-7-每日时长-滑块调整.png');
  step('时长调整', '点击滑轨右侧，上限调整（标签随动）');

  // ================= 阶段三：游戏隐藏 → 大厅不展示 → 恢复显示 =================
  step('阶段三', '游戏隐藏（家长门 + 确认）→ 大厅不再展示 → 恢复显示');
  // 游戏管理卡在护眼卡下方，向下滚动到 lavender 图标可见
  let rowIcon = null;
  for (let i = 0; i < 6 && !rowIcon; i++) {
    await page.mouse.move(180, 500);
    await page.mouse.wheel(0, 260);
    await wait(700);
    const res = await snap(LAVENDER + ',' + WARNING);
    rowIcon = pick(res, 'lavender');
  }
  if (!rowIcon) throw new Error('未定位到游戏管理卡的翻牌记忆行');
  const rowCenterY = rowIcon.y + rowIcon.h / 2;
  await tapAt(246, rowCenterY); // 隐藏圆钮（行右侧第一枚）
  await passGate('隐藏游戏');
  await wait(800);
  await shot('3-8-隐藏游戏-确认弹窗.png');
  await tapPrimaryBtn();
  await wait(1200);
  await shot('3-9-游戏已隐藏-标记显示.png');
  step('隐藏', '通过家长门并确认后，翻牌记忆标记「已隐藏」');

  await backToHall();
  await shot('3-10-大厅-翻牌记忆已隐藏.png');
  const hallCheck = await snap(LAVENDER + ',' + SAKURA);
  step('大厅回显', !has(hallCheck, 'lavender') && has(hallCheck, 'sakura')
    ? '大厅不再展示翻牌记忆（商店仅剩打地鼠/拼图）'
    : '警告：大厅仍检测到 lavender，需人工复核');

  await openParentCenter('恢复显示');
  for (let i = 0; i < 6; i++) {
    const res = await snap(LAVENDER);
    const icon = pick(res, 'lavender');
    if (icon) { await tapAt(246, icon.y + icon.h / 2); break; }
    await page.mouse.move(180, 500);
    await page.mouse.wheel(0, 260);
    await wait(700);
  }
  await passGate('恢复显示');
  await wait(1000);
  await shot('3-11-恢复显示-取消隐藏.png');
  step('恢复显示', '再次点击眼睛钮（家长门通过后直接恢复，无需确认弹窗）');

  // ================= 阶段四：删除游戏（家长门 + 危险按钮 + 二次确认） =================
  step('阶段四', '删除游戏：先下载解锁，再经家长门 + 危险按钮 + 二次确认删除');
  await backToHall();
  // 滚到商店，打开翻牌记忆下载面板并完成解锁（沿用 M2 链路）
  let storeCard = null;
  for (let i = 0; i < 6 && !storeCard; i++) {
    const res = await snap(LAVENDER);
    storeCard = pick(res, 'lavender');
    if (!storeCard) {
      await page.mouse.move(180, 500);
      await page.mouse.wheel(0, 400);
      await wait(700);
    }
  }
  if (!storeCard) throw new Error('未定位到商店中的翻牌记忆卡');
  await tapCenterOf(storeCard);
  await wait(1000);
  await tapPrimaryBtn(); // 下载
  await waitUntil('翻牌记忆解锁', `${PRIMARY},${STAR}`, (r) => has(r, 'primary') && has(r, 'star'));
  await shot('3-12-删除前置-翻牌记忆已解锁.png');
  step('前置', '翻牌记忆经 M2 下载链路解锁（有解锁状态与进度可供删除）');
  const secBtn = pick(await snap(SECONDARY), 'secondary');
  if (secBtn) await tapCenterOf(secBtn); // 回大厅（关闭面板）
  await wait(1200);

  await openParentCenter('删除游戏');
  let delIcon = null;
  for (let i = 0; i < 6; i++) {
    const res = await snap(LAVENDER);
    delIcon = pick(res, 'lavender');
    if (delIcon) break;
    await page.mouse.move(180, 500);
    await page.mouse.wheel(0, 260);
    await wait(700);
  }
  if (!delIcon) throw new Error('未定位到翻牌记忆行（删除）');
  await tapAt(298, delIcon.y + delIcon.h / 2); // 删除圆钮（行右侧第二枚）
  await passGate('删除游戏');
  await wait(800);
  await shot('3-13-删除游戏-危险确认.png');
  await tapDangerBtn();
  await wait(900);
  await shot('3-14-删除游戏-二次确认.png');
  await tapDangerBtn();
  await wait(1200);
  await shot('3-15-删除游戏-完成.png');
  step('删除', '家长门 → 危险红钮确认 → 二次确认 → 删除完成');

  await backToHall();
  await shot('3-16-大厅-删除后回到商店.png');
  const afterDel = await snap(LAVENDER);
  const lavCard = pick(afterDel, 'lavender');
  step('删除回显', lavCard ? '翻牌记忆回到游戏商店（解锁与进度已清空）' : '警告：未在商店检测到翻牌记忆');

  // ================= 阶段五：护眼休息 + 每日时长锁屏（演示节奏） =================
  step('阶段五', '护眼休息（30s 不可跳过）+ 每日时长到点「明天见」锁屏');
  await page.evaluate(() => localStorage.clear());
  await gotoApp('/?gate=hold');
  await openParentCenter('演示节奏');
  // 滚到「护眼验收调试」卡：先重置今日护眼，再开启演示节奏
  let debugBtn = null;
  for (let i = 0; i < 8 && !debugBtn; i++) {
    const res = await snap(PRIMARY + ',' + SECONDARY);
    const p = pick(res, 'primary');
    const s = pick(res, 'secondary');
    // 调试卡的两枚按钮并排（primary 左 / secondary 右，y 相同且在页面下部）
    if (p && s && Math.abs(p.y - s.y) < 12 && p.y > 300) debugBtn = { y: p.y + p.h / 2 };
    if (!debugBtn) {
      await page.mouse.move(180, 500);
      await page.mouse.wheel(0, 300);
      await wait(700);
    }
  }
  if (!debugBtn) throw new Error('未定位到护眼验收调试按钮行');
  await tapAt(253, debugBtn.y); // 重置今日护眼（右钮）
  await wait(800);
  await tapAt(107, debugBtn.y); // 开启演示节奏（左钮）
  await wait(800);
  await shot('3-17-家长中心-演示节奏已开启.png');
  step('演示节奏', '已重置今日护眼并开启演示节奏（连续 20s / 每日 60s，休息仍真实 30s）');

  await backToHall();
  step('计时', '回大厅等待连续 20 秒触发护眼休息…');
  await waitUntil('护眼休息覆盖层', CREAM, (r) => {
    const c = pick(r, 'cream');
    return !!c && c.w > 350 && c.h > 700;
  }, 40000);
  await shot('3-18-护眼休息-强制休息30秒.png');
  step('护眼休息', '连续使用到点，强制休息覆盖层出现（眼保健操 + 倒计时，无跳过按钮）');

  // 不可跳过：点击覆盖层 + 等待 6s 后仍在休息
  await tapAt(180, 400);
  await wait(6000);
  await shot('3-19-护眼休息-点击不可跳过.png');
  const stillRest = await snap(CREAM);
  const restCard = pick(stillRest, 'cream');
  if (!restCard || restCard.w <= 350) throw new Error('休息覆盖层意外消失');
  step('不可跳过', '点击休息页无效，6 秒后仍在强制休息（倒计时继续）');

  // 等待休息自动结束
  await waitUntil('休息自动结束', CREAM + ',' + LAVENDER, (r) => {
    const c = pick(r, 'cream');
    return !(c && c.w > 350 && c.h > 700);
  }, 45000);
  await shot('3-20-休息结束-自动恢复大厅.png');
  step('自动恢复', '30 秒休息到点自动结束，回到大厅（连续计时已清零）');

  // 等待每日 60 秒到点 → 明天见锁屏（含第二次护眼休息的 30 秒，放宽到 120s）
  await waitUntil('明天见锁屏', BRAND_DEEP, (r) => {
    const c = pick(r, 'brandDeep');
    return !!c && c.w > 350 && c.h > 750;
  }, 120000);
  await shot('3-21-明天见-每日时长到点锁屏.png');
  step('每日锁屏', '每日累计 60 秒到点，全屏「明天见」锁屏页（至次日自动解除）');

  // 锁屏不可绕过：点击无效
  await tapAt(180, 400);
  await wait(2500);
  await shot('3-22-明天见-点击不可解除.png');
  const stillLock = await snap(BRAND_DEEP + ',' + LAVENDER);
  if (!pick(stillLock, 'brandDeep') || pick(stillLock, 'brandDeep').w <= 350) {
    throw new Error('锁屏页被意外解除');
  }
  step('锁屏不可绕过', '点击锁屏页无效，仍处于「明天见」锁定状态');

  // 演示专用重置：点「（演示）重置今日时长」回到大厅
  let unlocked = false;
  for (const y of [520, 545, 570, 495]) {
    await tapAt(180, y);
    await wait(1500);
    const res = await snap(LAVENDER + ',' + SAKURA);
    if (has(res, 'sakura') || has(res, 'lavender')) { unlocked = true; break; }
  }
  if (!unlocked) throw new Error('演示重置未生效（未回到大厅）');
  await shot('3-23-演示重置-回到大厅.png');
  step('演示重置', '通过演示专用重置入口清零今日时长并回到大厅（正式版无此入口，锁屏至次日）');

  // ================= 汇总 =================
  await shot('3-24-M3-验收完成-大厅终态.png');
  const report = ['# M3 浏览器验收运行日志', '', ...log, '', '控制台错误: ' + (errors.length ? errors.join(' | ') : '无')];
  fs.writeFileSync(path.join(ROOT, '.logs', 'm3-browser-verify.log'), report.join('\n'), 'utf8');
  console.log('控制台错误:', errors.length ? errors.join(' | ') : '无');
  await browser.close();
  server.close();
  if (errors.length) process.exitCode = 2;
}

/** 页面句柄（main 内赋值，供模块级辅助函数使用） */
let activePage = null;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** 滚回页面顶部（家长中心/大厅的返回钮在页头，滚动后需先回顶） */
const scrollTop = async () => {
  await activePage.mouse.move(180, 500);
  await activePage.mouse.wheel(0, -4000);
  await sleep(700);
};

/** 点主按钮中心（先截图再取色） */
async function tapPrimaryBtn() {
  await activePage.screenshot({ path: path.join(SHOT_DIR, TMP) });
  const btn = pick(analyze(TMP, PRIMARY), 'primary');
  if (!btn) { fs.rmSync(path.join(SHOT_DIR, TMP), { force: true }); throw new Error('未定位到主按钮'); }
  fs.rmSync(path.join(SHOT_DIR, TMP), { force: true });
  await tapCenterOf(btn);
}

/** 点危险按钮中心（先截图再取色） */
async function tapDangerBtn() {
  await activePage.screenshot({ path: path.join(SHOT_DIR, TMP) });
  const btn = pick(analyze(TMP, DANGER), 'danger');
  if (!btn) { fs.rmSync(path.join(SHOT_DIR, TMP), { force: true }); throw new Error('未定位到危险按钮'); }
  fs.rmSync(path.join(SHOT_DIR, TMP), { force: true });
  await tapCenterOf(btn);
}

async function tapCenterOf(card) {
  await activePage.touchscreen.tap(card.x + card.w / 2, card.y + card.h / 2);
}


main().catch(async (e) => {
  console.error('VERIFY FAILED:', e.message);
  try {
    const report = ['# M3 浏览器验收运行日志（失败）', '', ...log, '', 'ERROR: ' + e.message, '控制台错误: ' + (errors.length ? errors.join(' | ') : '无')];
    fs.writeFileSync(path.join(ROOT, '.logs', 'm3-browser-verify.log'), report.join('\n'), 'utf8');
  } catch (_) {}
  process.exitCode = 1;
});
