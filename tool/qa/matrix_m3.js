/** 探针矩阵：找出不触发引擎 _computeOnScreenKeyboardInsets 断言的仿真组合。 */
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const WEB_DIR = path.resolve(__dirname, '../../build/web');
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
      if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) file = path.join(WEB_DIR, 'index.html');
      const body = fs.readFileSync(file);
      res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream' });
      res.end(body);
    });
    server.listen(PORT, '127.0.0.1', () => resolve(server));
  });
}

(async () => {
  const server = await serve();
  const browser = await chromium.launch({ headless: true, args: ['--disable-gpu-vsync', '--use-angle=swiftshader', '--no-sandbox', '--disable-dev-shm-usage'] });
  const variants = [
    { name: 'dpr3-mobile', dpr: 3, mobile: true },
    { name: 'dpr2-mobile', dpr: 2, mobile: true },
    { name: 'dpr3-nomobile', dpr: 3, mobile: false },
    { name: 'dpr1-mobile', dpr: 1, mobile: true },
  ];
  for (const v of variants) {
    const context = await browser.newContext({ viewport: { width: 360, height: 800 }, deviceScaleFactor: v.dpr, isMobile: v.mobile, hasTouch: true });
    const page = await context.newPage();
    let crashed = false;
    page.on('pageerror', () => { crashed = true; });
    await page.goto('http://127.0.0.1:' + PORT + '/', { waitUntil: 'load' });
    for (let i = 0; i < 15; i++) {
      await page.waitForTimeout(2000);
      const info = await page.evaluate(() => ({ scenes: document.querySelectorAll('flt-scene').length }));
      if (info.scenes > 0) break;
    }
    const info = await page.evaluate(() => ({ scenes: document.querySelectorAll('flt-scene').length }));
    console.log(v.name, 'crashed=' + crashed, 'scenes=' + info.scenes);
    await context.close();
  }
  await browser.close();
  server.close();
})();
