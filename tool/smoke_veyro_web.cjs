// Run against a compiled Flutter Web build with playwright-core and Chrome.
// Signed-in interactions use local fixtures; no live accounts or posts are created.
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

const firstPost = '00000000-0000-4000-8000-000000000010';
const firstText = 'A first update from the Veyro community.';
const viewerId = '00000000-0000-4000-8000-000000000001';
const otherId = '00000000-0000-4000-8000-000000000002';
const reelFile = process.env.VEYRO_TEST_REEL;

async function mockSignedIn(page) {
  const timestamp = new Date().toISOString();
  const b64 = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const exp = Math.floor(Date.now() / 1000) + 3600;
  const session = {
    // Neither the fixture user ID nor this unsigned token leaves the browser test.
    access_token: `${b64({ alg: 'HS256' })}.${b64({ sub: viewerId, exp })}.fixture`,
    expires_in: 3600,
    refresh_token: 'browser-smoke-fixture',
    token_type: 'bearer',
    user: {
      id: viewerId, aud: 'authenticated', email: 'preview@example.invalid',
      app_metadata: {}, user_metadata: { username: 'veyro_preview', full_name: 'Veyro Preview' }, created_at: timestamp,
    },
  };
  const people = [
    { id: viewerId, username: 'veyro_preview', full_name: 'Veyro Preview' },
    { id: otherId, username: 'veyro_friend', full_name: 'Veyro Friend' },
  ];
  const nextId = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
  const mediaUrl = new URL('veyro-browser-test-reel.webm', url).href;
  const writes = [];
  const posts = [
    { id: firstPost, author_id: otherId, type: 'text', description: firstText, media_urls: [], created_at: timestamp },
    ...(reelFile ? [{ id: nextId(11), author_id: otherId, type: 'video', description: 'An example reel from our community.', media_urls: [mediaUrl], created_at: timestamp }] : []),
  ];
  if (reelFile) {
    await page.route(mediaUrl, (route) => route.fulfill({ path: reelFile, contentType: 'video/webm' }));
  }
  const liked = new Set();
  const saved = new Map();
  const comments = [];
  const follows = new Set();
  const messages = [];
  const chats = [];
  const notifications = [{
    id: nextId(400), user_id: viewerId, actor_id: otherId, type: 'follow', resource_id: otherId,
    actor: people[1], message: 'followed you.', is_read: false, created_at: timestamp,
  }];
  const publicPhoto = fs.readFileSync('web/icons/Icon-192.png');
  function postProjection(post) {
    return {
      ...post, caption: null, author: people.find((person) => person.id === post.author_id),
      likes: [{ count: Number(liked.has(post.id)) }],
      comments: [{ count: comments.filter((comment) => comment.post_id === post.id).length }],
      liked_by_user: liked.has(post.id) ? [{ user_id: viewerId }] : [],
      saved_by_user: saved.has(post.id) ? [{ id: saved.get(post.id) }] : [],
    };
  }
  // Use the existing client's REST path, query, auth and CORS contracts. This is
  // deliberately an in-memory fixture, not a test against production data or Realtime.
  await page.route(`${backend.origin}/**`, async (route) => {
    const request = route.request();
    const resourceUrl = new URL(request.url());
    const resource = resourceUrl.pathname.replace(/^\/rest\/v1\//, '');
    const method = request.method();
    const eq = (key) => resourceUrl.searchParams.get(key)?.replace(/^eq\./, '');
    const contains = (key) => resourceUrl.searchParams.get(key)?.replace(/^ilike\.%|%$/g, '').replaceAll('\\', '').toLowerCase();
    const object = (request.headers().accept || '').includes('vnd.pgrst.object+json');
    const cors = {
      'access-control-allow-origin': url.origin,
      'access-control-allow-methods': 'GET, POST, PATCH, DELETE, OPTIONS',
      'access-control-allow-headers': request.headers()['access-control-request-headers'] || '*',
      'access-control-expose-headers': 'content-range',
    };
    const json = (body, status = 200, headers = {}) => route.fulfill({ status, json: body, headers: { ...cors, ...headers } });
    if (method === 'OPTIONS') return route.fulfill({ status: 204, headers: cors });
    if (resource === '/auth/v1/user') return json(session.user);
    if (resource.startsWith('/storage/v1/object/public/post-media/') && method === 'GET') {
      return route.fulfill({ status: 200, contentType: 'image/png', body: publicPhoto, headers: cors });
    }
    if (resource.startsWith('/storage/v1/object/post-media/') && method === 'POST') {
      writes.push({ resource: 'media', method });
      return json({ Key: resource.split('/object/')[1] });
    }
    let rows = [];
    if (method === 'GET') {
      switch (resource) {
        case 'settings':
          rows = [{ id: viewerId, user_id: viewerId, theme_mode: 'dark', language: 'en', notifications_enabled: true, updated_at: timestamp }];
          break;
        case 'users':
          rows = people.filter((person) => (!eq('id') || person.id === eq('id')) &&
            (!contains('username') || person.username.includes(contains('username')))).map((person) => ({
            ...person, bio: 'Browser fixture profile', posts: [{ count: posts.filter((post) => post.author_id === person.id).length }],
            followers: [{ count: Number(follows.has(person.id)) }], following: [{ count: person.id === viewerId ? follows.size : 0 }],
          }));
          break;
        case 'posts':
        case 'veyro_following_feed':
          rows = posts.filter((post) =>
            (resource !== 'veyro_following_feed' || follows.has(post.author_id) || post.author_id === viewerId) &&
            (!eq('id') || post.id === eq('id')) && (!eq('author_id') || post.author_id === eq('author_id')) &&
            (!eq('type') || post.type === eq('type')) && (!contains('description') || post.description?.toLowerCase().includes(contains('description'))),
          ).map(postProjection);
          break;
        case 'comments':
          rows = comments.filter((item) => item.post_id === eq('post_id'));
          break;
        case 'saved_posts':
          rows = posts.filter((post) => saved.has(post.id)).map((post) => ({
            id: saved.get(post.id), post_id: post.id, user_id: viewerId, post: postProjection(post), created_at: timestamp,
          }));
          break;
        case 'followers':
          rows = [...follows].filter((id) => !eq('following_id') || id === eq('following_id')).map((id) => ({ id: nextId(500), person: people.find((person) => person.id === id) }));
          break;
        case 'notifications': rows = notifications; break;
        case 'chats': rows = chats; break;
        case 'messages': rows = messages.filter((message) => message.chat_id === eq('chat_id')); break;
        case 'stories': break;
        default: return json({ message: `Unexpected fixture GET ${resource}` }, 404);
      }
      const total = rows.length;
      const offset = Number(resourceUrl.searchParams.get('offset') || 0);
      const limit = Number(resourceUrl.searchParams.get('limit') || total);
      rows = rows.slice(offset, offset + limit);
      return json(object ? rows[0] || {} : rows, 200, { 'content-range': `*/${total}` });
    }
    const body = request.postData() ? request.postDataJSON() : null;
    writes.push({ resource, method, body });
    if (method === 'POST') {
      switch (resource) {
        case 'posts': {
          const post = { ...body, id: nextId(12 + posts.length + writes.length), created_at: new Date().toISOString() };
          posts.unshift(post);
          return json(postProjection(post), 201);
        }
        case 'likes': liked.add(body.post_id); return json({}, 201);
        case 'saved_posts': saved.set(body.post_id, nextId(600 + saved.size)); return json({}, 201);
        case 'comments': {
          const item = { ...body, id: nextId(200 + comments.length), author: people[0], created_at: timestamp };
          comments.unshift(item);
          return json(item, 201);
        }
        case 'followers': follows.add(body.following_id); return json({}, 201);
        case 'chats': {
          const chat = { ...body, id: nextId(300), first_user: people[0], second_user: people[1], last_message_time: timestamp,
            has_unread_messages: false, unread: [{ count: 0 }] };
          chats.push(chat);
          return json(chat, 201);
        }
        case 'messages': {
          const sent = { ...body, id: nextId(301 + messages.length), is_read: false, timestamp: new Date().toISOString() };
          messages.push(sent);
          return json(sent, 201);
        }
      }
    } else if (method === 'DELETE') {
      if (resource === 'likes') liked.delete(eq('post_id'));
      if (resource === 'saved_posts') saved.delete(eq('post_id'));
      if (resource === 'followers') follows.delete(eq('following_id'));
      const list = { posts, comments, notifications }[resource];
      const index = list?.findIndex((item) => item.id === eq('id'));
      if (index >= 0) return json(list.splice(index, 1));
      return json([]);
    } else if (method === 'PATCH') {
      if (resource === 'notifications') notifications.filter((item) => !eq('id') || item.id === eq('id')).forEach((item) => Object.assign(item, body));
      if (resource === 'posts') {
        const post = posts.find((item) => item.id === eq('id'));
        return json(post ? [Object.assign(post, body)] : []);
      }
      return json([]);
    }
    return json({ message: `Unexpected fixture ${method} ${resource}` }, 404);
  });
  await page.routeWebSocket(`wss://${backend.host}/realtime/v1/websocket**`, (socket) => {
    socket.onMessage((message) => {
      const event = JSON.parse(message);
      socket.send(JSON.stringify({ topic: event.topic, event: 'phx_reply', ref: event.ref,
        payload: { status: 'ok', response: {} } }));
    });
  });
  await page.addInitScript(({ origin, key, value }) => {
    if (location.origin === origin) localStorage.setItem(key, value);
  }, { origin: url.origin, key: `sb-${backend.hostname.split('.')[0]}-auth-token`, value: JSON.stringify(session) });
  return { posts, saved, liked, comments, follows, messages, notifications, writes };
}

async function openApp(page, address = url.href) {
  await page.goto(address, { waitUntil: 'domcontentloaded' });
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

function controls(page) {
  // Flutter emits a role for most controls and labelled containers for some
  // navigation/InkWell destinations. Both support a semantics tap.
  const control = (name) => page.getByRole('button', { name, exact: typeof name === 'string' })
    .or(page.getByLabel(name, { exact: typeof name === 'string' }))
    .or(page.getByTitle(name, { exact: typeof name === 'string' }));
  async function press(name, physical = false) {
    const element = control(name).and(page.locator(':not([aria-disabled="true"]):not([disabled])')).first();
    await element.waitFor({ state: 'attached', timeout });
    if (!physical) {
      await element.evaluate((node) => node.click());
      if (name === 'Back' || name === 'Close comments') await page.waitForTimeout(320);
      return;
    }
    const box = await element.boundingBox();
    assert.ok(box, `visible bounds for ${name}`);
    await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
  }
  async function enter(value, name) {
    const textbox = page.getByRole('textbox', { name }).first();
    await textbox.waitFor({ state: 'attached', timeout });
    // Flutter attaches its DOM editing strategy after the semantics focus
    // action. Focusing the accessibility field is more reliable than clicking
    // coordinates during tab/dialog transitions.
    await page.bringToFront();
    await textbox.focus();
    await page.waitForTimeout(180);
    await textbox.fill(value, { timeout });
    assert.equal(await textbox.inputValue(), value, `text entered in ${name || 'editor'}`);
    await page.waitForTimeout(180);
  }
  async function changed(name, resource, method) {
    const [receipt] = await Promise.all([
      page.waitForResponse((response) => {
        const target = new URL(response.url());
        return target.origin === backend.origin && target.pathname === `/rest/v1/${resource}` && response.request().method() === method;
      }, { timeout }),
      press(name),
    ]).catch((error) => { throw new Error(`${name} (${method} ${resource}): ${error.message}`); });
    assert.ok(receipt.ok(), `${method} ${resource} succeeded`);
  }
  const waitFor = (name) => control(name).first().waitFor({ state: 'attached', timeout });
  return { press, enter, waitFor, changed };
}

async function testSocial(page, state, name) {
  const { press, enter, waitFor, changed } = controls(page);
  const text = `New ${name} update from browser smoke.`;
  await waitFor('Like post');
  await capture(page, `${name}-feed`);
  await changed('Like post', 'likes', 'POST');
  await waitFor('Unlike post');
  assert.ok(state.liked.has(firstPost));
  await changed('Save post', 'saved_posts', 'POST');
  assert.ok(state.saved.has(firstPost));
  await press('Comments');
  await waitFor('Close comments');
  await enter('A real comment action in this test.');
  await changed('Send comment', 'comments', 'POST');
  await waitFor('Delete comment');
  assert.ok(state.comments.some((item) => item.content === 'A real comment action in this test.' && item.post_id === firstPost));
  await capture(page, `${name}-comments`);
  await press('Close comments');
  await press('Saved posts');
  await press(/Open text post/);
  await waitFor('Unlike post');
  await waitFor('Remove from saved');
  await press('Share post');
  await waitFor('Copy link');
  await page.bringToFront();
  await page.evaluate(() => navigator.clipboard.writeText(''));
  await page.waitForTimeout(280);
  await press('Copy link', true);
  await page.waitForFunction(async (postId) => (await navigator.clipboard.readText()).includes(postId), firstPost, { timeout });
  const copy = await page.evaluate(() => navigator.clipboard.readText());
  assert.equal(new URL(copy).searchParams.get('post'), firstPost);
  await waitFor('Post options');
  await press('Back');
  await waitFor('Sort saved posts');
  await press('Back');
  await waitFor('Refresh feed');

  await press(/What’s on your mind/);
  await waitFor('Publish');
  await enter(text, /Post text/);
  await capture(page, `${name}-composer`);
  await changed('Publish', 'posts', 'POST');
  assert.equal(state.posts[0].description, text);
  assert.equal(state.posts[0].type, 'text');
  assert.deepEqual(state.posts[0].media_urls, []);
  await waitFor('Refresh feed');
  const [following] = await Promise.all([
    page.waitForResponse((response) => response.url().includes('/rest/v1/veyro_following_feed'), { timeout }),
    press('Following'),
  ]);
  assert.ok(following.ok(), 'server-side Following request succeeds');

  if (name === 'desktop') {
    await press('Post options');
    await press('Edit post');
    await enter(`${text} Edited.`, /Post text/);
    await changed('Save changes', 'posts', 'PATCH');
    assert.ok(state.posts[0].description.includes('Edited.'));
    await press('Post options');
    await press('Delete post');
    await waitFor('Cancel');
    await changed('Delete post', 'posts', 'DELETE');
    assert.ok(!state.posts.some((post) => post.description.includes('Edited.')));
    await press('Latest');
    await press('Notifications');
    await changed('Mark all as read', 'notifications', 'PATCH');
    assert.ok(state.notifications.every((item) => item.is_read));
    await press(/veyro_friend followed you/);
    await changed('Follow', 'followers', 'POST');
    await waitFor('Following');
    assert.ok(state.follows.has(otherId));
    await press('Back');
    await waitFor('Refresh notifications');
    await press('Back');
    await waitFor('Refresh feed');
    await press('Following');
    await waitFor('Unlike post');
    await press('Share post');
    await press('Send in message');
    await enter('veyro_friend', /Search by username/);
    await press(/@veyro_friend/);
    await changed('Send message', 'messages', 'POST');
    assert.equal(new URL(state.messages[0].content).searchParams.get('post'), firstPost);
    await press('View shared post');
    await waitFor('Unlike post');
    await capture(page, 'desktop-shared-post');
    await press('Back');
    await waitFor('View shared post');
    await press('Back');
    await waitFor('Refresh feed');
  }

  await press(/\bReels\b/);
  if (reelFile) {
    await waitFor('Refresh reels');
    const video = page.locator('video').first();
    await video.waitFor({ state: 'attached', timeout });
    await video.evaluate((element) => {
      if (element.readyState >= 2) return;
      return new Promise((resolve, reject) => {
        element.addEventListener('loadeddata', resolve, { once: true });
        setTimeout(() => reject(new Error('reel media did not load')), 10000);
      });
    });
    assert.ok(await video.evaluate((element) => element.duration > 0));
    await waitFor('Comments');
    await capture(page, `${name}-reels`);
  } else {
    await waitFor('Create a reel');
  }

  // The same link works when opened afresh and reads persisted viewer flags.
  await openApp(page, copy);
  await waitFor('Back');
  await waitFor('Unlike post');
  assert.ok(state.saved.has(firstPost));
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
    await browserContext.grantPermissions(['clipboard-read', 'clipboard-write'], { origin: url.origin });
    const page = await browserContext.newPage();
    const issues = [];
    page.on('pageerror', (err) => issues.push(err.message));
    page.on('response', (res) => {
      if (new URL(res.url()).origin === url.origin && res.status() >= 400) {
        issues.push(`${res.status()} ${new URL(res.url()).pathname}`);
      }
    });
    try {
      const social = signedIn ? await mockSignedIn(page) : null;
      await openApp(page);
      const button = (label) => page.getByRole('button', { name: label, exact: true }).first();
      const waitFor = (label) => button(label).waitFor({ state: 'attached', timeout });
      if (social) {
        await testSocial(page, social, name);
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
      const controls = await page.locator('flt-semantics[role="button"],input[data-semantics-role],textarea[data-semantics-role]').evaluateAll((nodes) =>
        nodes.slice(0, 24).map((node) => [node.getAttribute('aria-label') || node.textContent?.trim() || node.tagName,
          node.getAttribute('aria-disabled') === 'true' ? 'disabled' : '', node.value].filter(Boolean).join(' '))).catch(() => []);
      throw new Error(`${name} ${signedIn ? 'social' : 'auth'}: ${error.message}\n${issues.join('\n')}\nControls: ${controls.join(' | ')}`);
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
    const failures = [];
    for (const [name, viewport] of [
      ['desktop', { width: 1360, height: 860 }],
      ['mobile', { width: 390, height: 844 }],
    ]) {
      // Keep keyboard and clipboard operations in one foreground page.
      try { await testViewport(browser, name, viewport); }
      catch (error) { failures.push(error.message); }
    }
    if (failures.length) throw new Error(failures.join('\n'));
    console.log('::notice::Veyro auth and signed-in social flows verified in desktop and mobile Chrome (fixture backend).');
  } finally {
    await browser.close();
  }
})().catch((error) => {
  const text = (error.stack || error.message).replace(/%/g, '%25').replace(/\r/g, '%0D').replace(/\n/g, '%0A');
  console.error(`::error::${text}`);
  process.exitCode = 1;
});
