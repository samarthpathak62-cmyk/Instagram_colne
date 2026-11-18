// Run against a compiled Flutter Web build with playwright-core and Chrome.
// The signed-in UI uses local browser fixtures; no accounts or posts are created.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright-core');

const url = new URL(process.argv[2] || 'http://127.0.0.1:3000/');
const screenshots = process.env.VEYRO_SCREENSHOTS;
const timeout = 30000;
const backend = new URL(
  fs.readFileSync('lib/core/constants/supabase_constants.dart', 'utf8')
    .match(/supabaseUrl\s*=\s*'([^']+)'/)[1],
);

async function mockSignedIn(page) {
  const id = '00000000-0000-4000-8000-000000000001';
  const timestamp = new Date().toISOString();
  const b64 = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const exp = Math.floor(Date.now() / 1000) + 3600;
  const session = {
    // This fixture deliberately has no valid signature; the browser never sends it to Supabase.
    access_token: `${b64({ alg: 'HS256' })}.${b64({ sub: id, exp })}.fixture`,
    expires_in: 3600,
    refresh_token: 'browser-smoke-fixture',
    token_type: 'bearer',
    user: {
      id,
      aud: 'authenticated',
      email: 'preview@example.invalid',
      app_metadata: {},
      user_metadata: { username: 'veyro_preview', full_name: 'Veyro Preview' },
      created_at: timestamp,
    },
  };
  await page.route(`${backend.origin}/**`, async (route) => {
    const request = route.request();
    const resource = new URL(request.url()).pathname;
    const accept = request.headers().accept || '';
    const cors = {
      'access-control-allow-origin': url.origin,
      'access-control-allow-methods': 'GET, OPTIONS',
      'access-control-allow-headers': request.headers()['access-control-request-headers'] || '*',
    };
    if (request.method() === 'OPTIONS') {
      await route.fulfill({ status: 204, headers: cors });
      return;
    }
    if (request.method() !== 'GET' || !resource.startsWith('/rest/v1/')) {
      await route.abort();
      return;
    }
    let rows = [];
    if (resource === '/rest/v1/settings') {
      rows = [{ id, user_id: id, theme_mode: 'dark', language: 'en', notifications_enabled: true, updated_at: timestamp }];
    } else if (resource === '/rest/v1/users') {
      rows = [{ id, username: 'veyro_preview', full_name: 'Veyro Preview', bio: 'Browser smoke fixture' }];
    }
    await route.fulfill({
      headers: cors,
      json: accept.includes('vnd.pgrst.object+json') ? rows[0] || {} : rows,
    });
  });
  await page.addInitScript(({ origin, key, value }) => {
    if (location.origin === origin) localStorage.setItem(key, value);
  }, {
    origin: url.origin,
    key: `sb-${backend.hostname.split('.')[0]}-auth-token`,
    value: JSON.stringify(session),
  });
}

async function openApp(page) {
  await page.goto(url.href, { waitUntil: 'domcontentloaded' });
  await page.locator('flutter-view').waitFor({ state: 'attached', timeout });
  await page.locator('#veyro-launch').waitFor({ state: 'detached', timeout });
  assert.equal(await page.title(), 'Veyro');
  const manifest = await page.request.get(new URL('manifest.json', url).href);
  assert.ok(manifest.ok());
  const branding = await manifest.json();
  assert.equal(branding.name, 'Veyro');
  assert.equal(branding.short_name, 'Veyro');
  // Enable Flutter's accessible controls in the canvas-based release build.
  const placeholder = page.locator('flt-semantics-placeholder').first();
  await placeholder.evaluate((node) => node.click(), null, { timeout: 5000 }).catch(() => {});
}

async function capture(page, filename) {
  if (!screenshots) return;
  fs.mkdirSync(screenshots, { recursive: true });
  // Flutter route transitions run in the canvas, not as CSS animations.
  await page.waitForTimeout(400);
  await page.screenshot({ path: path.join(screenshots, `${filename}.png`), animations: 'disabled' });
}

async function testViewport(browser, name, viewport) {
  for (const signedIn of [false, true]) {
    const browserContext = await browser.newContext({
      viewport,
      deviceScaleFactor: 1,
      isMobile: name === 'mobile',
      hasTouch: name === 'mobile',
      locale: 'en-US',
      colorScheme: 'dark',
    });
    const page = await browserContext.newPage();
    const issues = [];
    page.on('pageerror', (err) => issues.push(err.message));
    page.on('response', (res) => {
      if (new URL(res.url()).origin === url.origin && res.status() >= 400) {
        issues.push(`${res.status()} ${new URL(res.url()).pathname}`);
      }
    });
    try {
      if (signedIn) await mockSignedIn(page);
      await openApp(page);
      const button = (label) => page.getByRole('button', { name: label, exact: true }).first();
      const waitFor = (label) => button(label).waitFor({ state: 'attached', timeout });
      if (signedIn) {
        await waitFor('Find people');
        await capture(page, `${name}-feed`);
      } else {
        await waitFor('Log in');
        await capture(page, `${name}-login`);
        await waitFor('Create an account');
        await button('Create an account').evaluate((node) => node.click());
        await waitFor('Create account');
        await capture(page, `${name}-signup`);
        await button('Log in').evaluate((node) => node.click());
        await waitFor('Log in');
        await waitFor('Create an account');
      }
      assert.deepEqual(issues, []);
      console.log(`Veyro ${name} ${signedIn ? 'feed' : 'auth'} OK`);
    } catch (error) {
      await capture(page, `${name}-${signedIn ? 'feed' : 'auth'}-error`).catch(() => {});
      throw new Error(`${name} ${signedIn ? 'feed' : 'auth'}: ${error.message}\n${issues.join('\n')}`);
    } finally {
      await browserContext.close();
    }
  }
}

(async () => {
  const browser = await chromium.launch({
    executablePath: process.env.CHROME_BIN || '/usr/bin/google-chrome',
    args: ['--no-sandbox'],
  });
  try {
    await testViewport(browser, 'desktop', { width: 1360, height: 860 });
    await testViewport(browser, 'mobile', { width: 390, height: 844 });
    console.log('::notice::Veyro startup, login, signup and signed-in feed verified in desktop and mobile Chrome.');
  } finally {
    await browser.close();
  }
})().catch((error) => {
  const text = (error.stack || error.message).replace(/%/g, '%25').replace(/\r/g, '%0D').replace(/\n/g, '%0A');
  console.error(`::error::${text}`);
  process.exitCode = 1;
});
