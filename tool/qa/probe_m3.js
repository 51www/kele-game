/** 快速探针：加载页面并打印控制台消息/错误，截屏一张。 */
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const ROOT = path.resolve(__dirname, '../..');
const WEB_DIR = path.join(ROOT, 'build', 'web');
const PORT = 8099;
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
      if (!file.startsWith(WEB_DIR)) { res.writeHead(403); res.end(); return; }
      if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) file = path.join(WEB_DIR, 'index.html');
      const body = fs.readFileSync(file);
      res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream', 'Content-Length': body.length });
      res.end(body);
    });
    server.listen(PORT, '127.0.0.1', () => resolve(server));
  });
}

(async () => {
  const server = await serve();
  const browser = await chromium.launch({
    headless: true,
    args: ['--disable-gpu-vsync', '--use-angle=swiftshader', '--no-sandbox', '--disable-dev-shm-usage'],
  });
  const context = await browser.newContext({ viewport: { width: 360, height: 800 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true });
  const page = await context.newPage();
  page.on('pageerror', (e) => console.log('PAGEERROR:', e.message, '\nSTACK:', (e.stack || '').slice(0, 1500)));
  page.on('console', (m) => console.log('CONSOLE[' + m.type() + ']:', m.text().slice(0, 500)));
  page.on('requestfailed', (r) => console.log('REQFAIL:', r.url().slice(0, 120), r.failure()?.errorText));
  await page.addInitScript(() => {
    window.addEventListener('error', (e) => {
      console.log('WINERR: ' + (e.message || '') + ' @ ' + (e.filename || '') + ':' + (e.lineno || '') + '\n' + (e.error && e.error.stack ? e.error.stack.slice(0, 2000) : ''));
    });
    window.addEventListener('unhandledrejection', (e) => {
      console.log('UNHANDLED: ' + (e.reason && (e.reason.stack || e.reason.message || e.reason)));
    });
  });
  await page.goto('http://127.0.0.1:' + PORT + '/?gate=math', { waitUntil: 'load' });
  for (let i = 0; i < 12; i++) {
    await page.waitForTimeout(3000);
    if (i === 2) { console.log('reload'); await page.reload({ waitUntil: 'load' }); continue; }
    const info = await page.evaluate(() => {
      const v = document.querySelector('flutter-view');
      return { hasView: !!v, scenes: document.querySelectorAll('flt-scene').length, glass: !!document.querySelector('flt-glass-pane') };
    });
    console.log('probe', i, JSON.stringify(info));
    await page.screenshot({ path: path.join(ROOT, 'docs', 'shortscreens', '_probe.png') });
  }
  await browser.close();
  server.close();
})();
