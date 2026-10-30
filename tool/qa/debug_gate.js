/** 调试：长按家长门过程逐秒截图。 */
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
const PAGE_BG = 'pageBg:#FAF7F0';
const BRAND_DEEP = 'brandDeep:#4B3FBF';
const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8', '.json': 'application/json; charset=utf-8',
  '.png': 'image/png', '.ttf': 'font/ttf', '.otf': 'font/otf',
  '.woff2': 'font/woff2', '.wasm': 'application/wasm', '.bin': 'application/octet-stream',
  '.symbols': 'text/plain',
};

function serve() {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      const url = decodeURIComponent((req.url || '/').split('?')[0]);
      let file = path.join(WEB_DIR, url === '/' ? 'index.html' : url);
      if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) file = path.join(WEB_DIR, 'index.html');
      const body = fs.readFileSync(file);
      res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream', 'Content-Length': body.length });
      res.end(body);
    });
    server.listen(PORT, '127.0.0.1', () => resolve(server));
  });
}

function analyze(fileName, colors) {
  return JSON.parse(execFileSync('python',
    [path.join(__dirname, 'board_analyzer.py'), path.join(SHOT_DIR, fileName), String(SCALE), colors],
    { encoding: 'utf8' }));
}

(async () => {
  const server = await serve();
  const browser = await chromium.launch({ headless: true, args: ['--disable-gpu-vsync', '--use-angle=swiftshader', '--no-sandbox', '--disable-dev-shm-usage'] });
  const context = await browser.newContext({ viewport: { width: 360, height: 800 }, deviceScaleFactor: SCALE, isMobile: true, hasTouch: true });
  const page = await context.newPage();
  page.on('pageerror', (e) => console.log('PAGEERROR:', e.message));
  page.on('console', (m) => { if (m.type() === 'error') console.log('CONSOLE_ERROR:', m.text().slice(0, 200)); });

  await page.goto('http://127.0.0.1:' + PORT + '/?gate=hold', { waitUntil: 'load' });
  const shotFile = async (name) => { await page.screenshot({ path: path.join(SHOT_DIR, name) }); return name; };
  for (let i = 0; i < 10; i++) {
    await page.waitForTimeout(2000);
    const f = await shotFile('_dbg.png');
    const r = analyze(f, 'sakura:#F5A8C7');
    if (r.cards.length) break;
  }
  console.log('hall rendered');
  await page.touchscreen.tap(308, 44);
  await page.waitForTimeout(1500);
  const gate = analyze(await shotFile('_dbg.png'), PAGE_BG);
  console.log('gate pageBg cards:', JSON.stringify(gate.cards.filter((c) => c.w > 80)));
  const circle = gate.cards.find((c) => c.key === 'pageBg' && c.w >= 90 && c.w <= 170);
  if (!circle) { console.log('NO CIRCLE FOUND'); await browser.close(); server.close(); return; }
  const cx = circle.x + circle.w / 2, cy = circle.y + circle.h / 2;
  console.log('circle at', Math.round(cx), Math.round(cy));
  await page.mouse.move(cx, cy);
  await page.mouse.down();
  for (const t of [800, 1600, 2400, 3200, 4000, 4800]) {
    await page.waitForTimeout(t === 800 ? 800 : 800);
    await page.screenshot({ path: path.join(SHOT_DIR, '_dbg-hold.png') });
    const st = analyze('_dbg-hold.png', PAGE_BG + ',' + BRAND_DEEP);
    console.log('t=' + t, 'pageBg:', JSON.stringify(st.cards.filter((c) => c.key === 'pageBg').map((c) => [Math.round(c.w), Math.round(c.h)])));
  }
  await page.mouse.up();
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(SHOT_DIR, '_dbg-after.png') });
  const after = analyze('_dbg-after.png', PAGE_BG + ',' + BRAND_DEEP);
  console.log('after up:', JSON.stringify(after.cards.filter((c) => c.w > 60).map((c) => [c.key, Math.round(c.w), Math.round(c.h), Math.round(c.x), Math.round(c.y)])));
  await browser.close();
  server.close();
})();
