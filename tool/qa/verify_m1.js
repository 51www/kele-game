/**
 * 《童趣游戏盒》M1 里程碑 —— 浏览器验收脚本（Playwright + Chromium）。
 *
 * 口径：手机竖屏基准视口 360×800（AGENT.md §1.1），deviceScaleFactor=3。
 * 由于 Flutter Web 渲染在 Canvas 上，DOM 快照拿不到元素位置，
 * 定位方式为「像素取色 + 几何推算」（详见 tool/qa/board_analyzer.py）。
 *
 * 运行：
 *   $env:NODE_PATH="C:\nvm4w\nodejs\node_global\node_modules\@playwright\cli\node_modules"
 *   node tool/qa/verify_m1.js
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

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff2': 'font/woff2',
  '.wasm': 'application/wasm',
  '.bin': 'application/octet-stream',
  '.symbols': 'text/plain',
};

const log = [];
function step(name, detail) {
  const line = `[${name}] ${detail}`;
  console.log(line);
  log.push(line);
}

function serve() {
  const server = http.createServer((req, res) => {
    const url = decodeURIComponent((req.url || '/').split('?')[0]);
    let file = path.join(WEB_DIR, url === '/' ? 'index.html' : url);
    if (!file.startsWith(WEB_DIR)) {
      res.writeHead(403);
      res.end();
      return;
    }
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

/** 调 Python 像素分析脚本，返回卡牌/按钮的位置信息 */
function analyze(fileName, colors) {
  const out = execFileSync(
    'python',
    [
      path.join(__dirname, 'board_analyzer.py'),
      path.join(SHOT_DIR, fileName),
      String(SCALE),
      colors,
    ],
    { encoding: 'utf8' }
  );
  return JSON.parse(out);
}

function diff(a, b) {
  if (!a || !b || a.length !== b.length) return 999;
  let sum = 0;
  for (let i = 0; i < a.length; i++) sum += Math.abs(a[i] - b[i]);
  return sum / a.length;
}

async function main() {
  fs.mkdirSync(SHOT_DIR, { recursive: true });
  const server = await serve();
  const browser = await chromium.launch({
    headless: true,
    args: [
      '--disable-gpu-vsync',
      '--use-angle=swiftshader',
      '--no-sandbox',
      '--disable-dev-shm-usage',
    ],
  });
  const context = await browser.newContext({
    viewport: { width: 360, height: 800 },
    deviceScaleFactor: SCALE,
    isMobile: true,
    hasTouch: true,
  });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push('PAGEERROR: ' + e.message));
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push('CONSOLE_ERROR: ' + m.text());
  });

  const shot = async (name) => {
    await page.screenshot({ path: path.join(SHOT_DIR, name) });
    step('SHOT', name);
  };
  const wait = (ms) => page.waitForTimeout(ms);

  await page.goto(`http://127.0.0.1:${PORT}`, { waitUntil: 'load' });
  await wait(4000);

  // ---------- 1. 大厅 ----------
  await shot('1-1-大厅总览.png');
  const hallCard = analyze('1-1-大厅总览.png', 'lavender');
  if (!hallCard.cards.length) throw new Error('大厅未找到翻牌记忆宫格');
  step('大厅', `翻牌记忆宫格 = ${JSON.stringify(hallCard.cards[0])}`);

  // 家长中心入口（右上角锁按钮）
  await page.touchscreen.tap(308, 44);
  await wait(1200);
  await shot('1-2-家长中心.png');
  const backBtn = analyze('1-2-家长中心.png', 'brandDeep:#4B3FBF');
  step('家长中心', backBtn.cards.length ? '左上返回按钮已定位' : '未定位到返回按钮');

  // 返回大厅
  await page.touchscreen.tap(44, 40);
  await wait(1200);
  await shot('1-3-大厅总览2.png');

  // 商店区（向下滚动）
  await page.mouse.move(180, 500);
  await page.mouse.wheel(0, 400);
  await wait(800);
  await shot('1-4-大厅商店区.png');
  await page.mouse.move(180, 300);
  await page.mouse.wheel(0, -600);
  await wait(800);

  // ---------- 2. 进入游戏 ----------
  const card = analyze('1-1-大厅总览.png', 'lavender').cards[0];
  const cx = card.x + card.w / 2;
  const cy = card.y + card.h / 2;
  await page.touchscreen.tap(cx, cy);
  await wait(3500);
  await shot('1-5-翻牌记忆初始棋盘.png');

  let board = analyze('1-5-翻牌记忆初始棋盘.png', 'lavender,mint,sky,sakura,peach,lemon');
  step('棋盘', `初始卡牌数 = ${board.cards.length}`);
  if (board.cards.length !== 6) throw new Error('初始棋盘未识别到 6 张卡');

  // ---------- 3. 暂停 ----------
  await page.touchscreen.tap(316, 40);
  await wait(700);
  await shot('1-6-暂停遮罩.png');
  await page.touchscreen.tap(316, 40);
  await wait(600);

  // ---------- 4. 返回二次确认 ----------
  await page.touchscreen.tap(44, 40);
  await wait(900);
  await shot('1-7-返回二次确认.png');
  const primary = analyze('1-7-返回二次确认.png', 'primary:#FFB627').cards[0];
  if (!primary) throw new Error('返回确认弹窗未找到主按钮');
  await page.touchscreen.tap(primary.x + primary.w / 2, primary.y + primary.h / 2);
  await wait(700);
  await shot('1-8-继续游戏中.png');

  // ---------- 5. 配对玩法 ----------
  const cards = board.cards;
  const hashOf = {};
  const matched = new Set();
  let matchedShotTaken = false;
  let compareShotTaken = false;

  const tapCard = async (c) => {
    await page.touchscreen.tap(c.x + c.w / 2, c.y + c.h / 2);
  };

  outer: for (let i = 0; i < cards.length; i++) {
    for (let j = i + 1; j < cards.length; j++) {
      if (matched.has(i) || matched.has(j)) continue;
      const knownI = hashOf[i];
      const knownJ = hashOf[j];
      if (knownI && knownJ && diff(knownI, knownJ) > 6) continue; // 已知不匹配，跳过

      const shotName = '1-9-翻牌对比.png';
      // 先确认本局是否已经结束（结算弹窗出现）
      await page.screenshot({ path: path.join(SHOT_DIR, shotName) });
      if (analyze(shotName, 'primary:#FFB627').cards.length) {
        step('玩法', '结算弹窗已出现，本局完成');
        break outer;
      }

      await tapCard(cards[i]);
      await wait(120);
      await tapCard(cards[j]);
      await wait(420);

      await page.screenshot({ path: path.join(SHOT_DIR, shotName) });
      // 卡面已翻开时颜色不再出现，因此按初始棋盘的固定矩形取特征
      const now = analyze(
        shotName,
        JSON.stringify(
          cards.map((c) => ({ key: c.key, x: c.x, y: c.y, w: c.w, h: c.h }))
        )
      );
      const byKey = {};
      now.cards.forEach((c) => {
        byKey[c.key] = c;
      });
      const sigI = byKey[cards[i].key] ? byKey[cards[i].key].sig : null;
      const sigJ = byKey[cards[j].key] ? byKey[cards[j].key].sig : null;
      if (!compareShotTaken) {
        compareShotTaken = true;
        step('对比', shotName);
      }
      if (!sigI || !sigJ || sigI.length === 0 || sigJ.length === 0) {
        step('配对', `${cards[i].key} / ${cards[j].key} 特征提取失败，跳过`);
        await wait(1900);
        continue;
      }
      hashOf[i] = sigI;
      hashOf[j] = sigJ;
      if (diff(sigI, sigJ) <= 8) {
        matched.add(i);
        matched.add(j);
        step('配对', `${cards[i].key} + ${cards[j].key} 匹配成功`);
        await wait(700);
        if (!matchedShotTaken) {
          matchedShotTaken = true;
          await shot('1-10-配对成功.png');
        }
      } else {
        await wait(1900); // 等不匹配的卡盖回
      }
      if (matched.size === cards.length) break outer;
    }
  }
  step('玩法', `脚本判定配对 ${matched.size}/${cards.length} 张`);
  await wait(1500);
  await shot('1-11-统一结算弹窗.png');

  const resultPrimary = analyze('1-11-统一结算弹窗.png', 'primary:#FFB627').cards[0];
  if (!resultPrimary) throw new Error('结算弹窗未找到「再玩一次」按钮');
  await page.touchscreen.tap(
    resultPrimary.x + resultPrimary.w / 2,
    resultPrimary.y + resultPrimary.h / 2
  );
  await wait(2500);
  await shot('1-12-再玩一次重开.png');

  // 退出游戏回大厅：返回 → 退出（次按钮在主按钮下方 64+12=76px）
  await page.touchscreen.tap(44, 40);
  await wait(1000);
  await shot('1-13-返回二次确认2.png');
  const primary2 = analyze('1-13-返回二次确认2.png', 'primary:#FFB627').cards[0];
  if (primary2) {
    await page.touchscreen.tap(primary2.x + primary2.w / 2, primary2.y + primary2.h / 2 + 76);
    await wait(1800);
  }
  await shot('1-14-大厅成绩回显.png');

  step('控制台', errors.length ? errors.join(' | ') : '无错误');
  fs.writeFileSync(
    path.join(ROOT, '.logs', 'm1-browser-verify.log'),
    log.concat(['', 'ERRORS: ' + (errors.length ? errors.join('\n') : 'none')]).join('\n'),
    'utf8'
  );

  await browser.close();
  server.close();
  console.log('\nDONE');
}

main().catch(async (err) => {
  console.error('FAILED:', err.message);
  fs.writeFileSync(
    path.join(ROOT, '.logs', 'm1-browser-verify.log'),
    log.concat(['', 'FAILED: ' + err.message]).join('\n'),
    'utf8'
  );
  process.exit(1);
});
