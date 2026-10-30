const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const ROOT = path.resolve(__dirname, '../..');
const WEB_DIR = path.join(ROOT, 'build', 'web');
const PORT = 8098;
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.png': 'image/png', '.wasm': 'application/wasm', '.ttf': 'font/ttf', '.otf': 'font/otf' };

const server = http.createServer((req, res) => {
  const url = decodeURIComponent((req.url || '/').split('?')[0]);
  let file = path.join(WEB_DIR, url === '/' ? 'index.html' : url);
  if (!file.startsWith(WEB_DIR)) { res.writeHead(403); res.end(); return; }
  const exists = fs.existsSync(file) && fs.statSync(file).isFile();
  console.log('REQ', url, exists ? 'OK' : 'MISSING');
  if (!exists) { res.writeHead(404); res.end('not found'); return; }
  const body = fs.readFileSync(file);
  res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream' });
  res.end(body);
});

server.listen(PORT, '127.0.0.1', async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox', '--use-angle=swiftshader'] });
  const page = await browser.newPage({ viewport: { width: 360, height: 800 } });
  page.on('console', (m) => console.log('CONSOLE[' + m.type() + ']', m.text().slice(0, 300)));
  page.on('pageerror', (e) => console.log('PAGEERROR', e.message.slice(0, 500)));
  page.on('requestfailed', (r) => console.log('REQFAIL', r.url(), r.failure() && r.failure().errorText));
  await page.goto(`http://127.0.0.1:${PORT}`, { waitUntil: 'load' });
  await page.waitForTimeout(8000);
  await page.screenshot({ path: path.join(ROOT, '.logs', 'probe.png') });
  await browser.close();
  server.close();
  process.exit(0);
});
