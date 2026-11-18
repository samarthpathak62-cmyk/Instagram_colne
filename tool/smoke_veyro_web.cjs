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
const lexId = '00000000-0000-4000-8000-000000000003';
const reelFile = process.env.VEYRO_TEST_REEL;
const photoFixture = 'test/fixtures/veyro-synthetic-photo.webp';
const otherGroup = '00000000-0000-4000-8000-000000000700';

async function mockSignedIn(page, theme, showcase = false) {
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
    { id: lexId, username: 'veyro_lex', full_name: 'Lex' },
  ];
  const nextId = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
  const mediaUrl = new URL('veyro-browser-test-reel.webm', url).href;
  const photoUrl = new URL('veyro-browser-test-photo.webp', url).href;
  const writes = [];
  const topicSearches = [];
  const posts = [
    ...(showcase ? [{ id: nextId(12), author_id: otherId, type: 'image',
      description: 'The last light in the valley. #bluehour', media_urls: [photoUrl], created_at: timestamp }] : []),
    { id: firstPost, author_id: otherId, type: 'text', description: firstText, media_urls: [], created_at: timestamp },
    ...(reelFile ? [{ id: nextId(11), author_id: otherId, type: 'video', description: 'An example reel from our community.', media_urls: [mediaUrl], created_at: timestamp }] : []),
  ];
  if (reelFile) {
    await page.route(mediaUrl, (route) => route.fulfill({ path: reelFile, contentType: 'video/webm' }));
  }
  if (showcase) await page.route(photoUrl, (route) => route.fulfill({ path: photoFixture, contentType: 'image/webp' }));
  const liked = new Map();
  const storyItems = [];
  const groups = [{ id: otherGroup, owner_id: otherId, name: 'Aperture Club',
    description: 'A place for street photography and visual storytelling.', category: 'creative' }];
  const memberships = new Map([[otherGroup, new Set([otherId])]]);
  const saved = new Map();
  const comments = [];
  const follows = new Set(showcase ? [otherId] : []);
  const sockets = new Map();
  let bindingId = 0;
  let rejectVideoPost = false;
  const chats = [{ id: nextId(300), user1_id: viewerId, user2_id: otherId,
    first_user: people[0], second_user: people[1], last_message_time: timestamp, has_unread_messages: true }];
  const messages = [{ id: nextId(320), chat_id: chats[0].id, sender_id: otherId, receiver_id: viewerId,
    content: 'Welcome to Veyro!', is_read: false, timestamp }];
  function projectChat(chat) {
    const history = messages.filter((message) => message.chat_id === chat.id)
      .sort((left, right) => right.timestamp.localeCompare(left.timestamp) || right.id.localeCompare(left.id));
    return { ...chat,
      unread: history.filter((message) => message.receiver_id === viewerId && !message.is_read).slice(0, 1).map(({ id }) => ({ id })),
      last_message: history.slice(0, 1).map(({ content }) => ({ content })),
    };
  }
  function postgresChange(table, type, record) {
    for (const [socket, topics] of sockets) {
      for (const [topic, filters] of topics) {
        const ids = filters.filter((binding) => {
          if (binding.table !== table || !['*', type].includes(binding.event)) return false;
          const [column, value] = (binding.filter || '').split('=eq.');
          return !column || record[column] === value;
        }).map((binding) => binding.id);
        if (ids.length) socket.send(JSON.stringify({ topic, event: 'postgres_changes', ref: null,
          payload: { ids, data: { schema: 'public', table, type, record, old_record: {},
            commit_timestamp: new Date().toISOString(), columns: [], errors: null } } }));
      }
    }
  }
  function updateChat(id) {
    const chat = chats.find((value) => value.id === id);
    if (!chat) return;
    const history = messages.filter((message) => message.chat_id === id);
    chat.has_unread_messages = history.some((message) => !message.is_read);
    chat.last_message_time = history.map((message) => message.timestamp).sort().at(-1) || chat.last_message_time;
    postgresChange('chats', 'UPDATE', chat);
  }
  function insertMessage(value) {
    const message = { ...value, id: nextId(320 + messages.length), timestamp: new Date().toISOString(), is_read: false };
    messages.push(message);
    updateChat(message.chat_id);
    postgresChange('messages', 'INSERT', message);
    return message;
  }
  const notifications = [{
    id: nextId(400), user_id: viewerId, actor_id: otherId, type: 'follow', resource_id: otherId,
    actor: people[1], message: 'followed you.', is_read: false, created_at: timestamp,
  }];
  const publicPhoto = fs.readFileSync(photoFixture);
  const publicStory = fs.readFileSync('test/fixtures/veyro-synthetic-story.webp');
  function postProjection(post, withOriginal = true) {
    const original = posts.find((entry) => entry.id === post.shared_post_id);
    return {
      ...post, caption: null, source: withOriginal && original ? postProjection(original, false) : null, author: people.find((person) => person.id === post.author_id),
      group: groups.find((group) => group.id === post.group_id) || null,
      reaction_counts: liked.has(post.id) ? [{ reaction: liked.get(post.id), total: 1 }] : [],
      comments: [{ count: comments.filter((comment) => comment.post_id === post.id).length }],
      liked_by_user: liked.has(post.id) ? [{ user_id: viewerId, reaction: liked.get(post.id) }] : [],
      saved_by_user: saved.has(post.id) ? [{ id: saved.get(post.id) }] : [],
    };
  }
  // Use the existing client's REST path, query, auth and CORS contracts. This is
  // deliberately an in-memory fixture with a synthetic Realtime socket.
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
      if (reelFile && resource.endsWith('.webm')) return route.fulfill({ status: 200, contentType: 'video/webm', path: reelFile, headers: cors });
      return route.fulfill({ status: 200, contentType: 'image/webp', body: publicPhoto, headers: cors });
    }
    if (resource.startsWith('/storage/v1/object/public/story-media/') && method === 'GET') {
      return route.fulfill({ status: 200, contentType: 'image/webp', body: publicStory, headers: cors });
    }
    if (/^\/storage\/v1\/object\/(post|story)-media\//.test(resource) && method === 'POST') {
      writes.push({ resource: 'media', method, resourcePath: resource, contentType: request.headers()['content-type'], bytes: request.postDataBuffer()?.length });
      return json({ Key: resource.split('/object/')[1] });
    }
    let rows = [];
    if (method === 'GET') {
      switch (resource) {
        case 'settings':
          rows = [{ id: viewerId, user_id: viewerId, theme_mode: theme, language: 'en', notifications_enabled: true, updated_at: timestamp }];
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
          if (contains('description')) topicSearches.push(contains('description'));
          rows = posts.filter((post) =>
            (resource !== 'veyro_following_feed' || follows.has(post.author_id) || post.author_id === viewerId) &&
            (!eq('id') || post.id === eq('id')) && (!eq('author_id') || post.author_id === eq('author_id')) &&
            (!eq('type') || post.type === eq('type')) &&
            (!eq('group_id') || post.group_id === eq('group_id')) &&
            (!eq('share_kind') || post.share_kind === eq('share_kind')) &&
            (!eq('shared_post_id') || post.shared_post_id === eq('shared_post_id')) &&
            (!contains('description') || post.description?.toLowerCase().includes(contains('description'))),
          ).map((post) => postProjection(post));
          break;
        case 'veyro_groups':
          rows = groups.filter((group) => (!eq('id') || group.id === eq('id')) &&
            (!contains('name') || group.name.toLowerCase().includes(contains('name'))) &&
            (!resourceUrl.searchParams.get('select')?.includes('veyro_group_members!inner') || memberships.get(group.id).has(viewerId)),
          ).map((group) => ({ ...group, members: [{ count: memberships.get(group.id).size }],
            membership: memberships.get(group.id).has(viewerId) ? [{ user_id: viewerId }] : [],
          }));
          break;
        case 'stories':
          rows = [
            ...(storyItems.length ? [{ user_id: viewerId, author: people[0], items: storyItems }] : []),
            ...(showcase ? [{ user_id: otherId, author: people[1], items: [{ id: nextId(330),
              media_url: photoUrl, media_type: 'image', created_at: timestamp }] }] : []),
          ];
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
          rows = [...follows].filter((id) => !eq('following_id') || id === eq('following_id')).map((id) => ({ id: nextId(500), follower_id: viewerId, following_id: id, person: people.find((person) => person.id === id) }));
          break;
        case 'notifications': rows = [...notifications].sort((a, b) => b.created_at.localeCompare(a.created_at) || b.id.localeCompare(a.id)); break;
        case 'chats': {
          const pair = resourceUrl.searchParams.get('or')?.match(/and\(user1_id\.eq\.([^,]+),user2_id\.eq\.([^)]+)\)/);
          rows = chats.filter((chat) => !pair || (chat.user1_id === pair[1] && chat.user2_id === pair[2]) ||
            (chat.user2_id === pair[1] && chat.user1_id === pair[2])).map(projectChat)
            .sort((a, b) => b.last_message_time.localeCompare(a.last_message_time));
          break;
        }
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
          if (body.type === 'video' && rejectVideoPost) {
            rejectVideoPost = false;
            return json({ message: 'Fixture transient publish failure' }, 503);
          }
          if (body.group_id && !memberships.get(body.group_id)?.has(viewerId)) return json({ message: 'Membership required' }, 403);
          const post = { ...body, id: nextId(12 + posts.length + writes.length), created_at: new Date().toISOString() };
          posts.unshift(post);
          return json(postProjection(post), 201);
        }
        case 'rpc/veyro_react': liked.set(body.p_post_id, body.p_reaction); return route.fulfill({ status: 204, headers: cors });
        case 'veyro_groups': {
          const group = { ...body, id: nextId(700 + groups.length) };
          groups.unshift(group);
          memberships.set(group.id, new Set([viewerId]));
          return json({ id: group.id }, 201);
        }
        case 'veyro_group_members': memberships.get(body.group_id).add(body.user_id); return json({}, 201);
        case 'rpc/veyro_add_story_item':
          storyItems.push({ id: nextId(800 + storyItems.length), media_url: body.p_media_url, media_type: body.p_media_type, created_at: new Date().toISOString() });
          return route.fulfill({ status: 204, headers: cors });
        case 'saved_posts': saved.set(body.post_id, nextId(600 + saved.size)); return json({}, 201);
        case 'comments': {
          const item = { ...body, id: nextId(200 + comments.length), author: people[0], created_at: timestamp };
          comments.unshift(item);
          return json(item, 201);
        }
        case 'followers': follows.add(body.following_id); return json({}, 201);
        case 'chats': {
          const chat = { ...body, id: nextId(300 + chats.length),
            first_user: people.find((person) => person.id === body.user1_id),
            second_user: people.find((person) => person.id === body.user2_id),
            last_message_time: timestamp, has_unread_messages: false };
          chats.push(chat);
          postgresChange('chats', 'INSERT', chat);
          return json(chat, 201);
        }
        case 'messages': return json(insertMessage(body), 201);
      }
    } else if (method === 'DELETE') {
      if (resource === 'likes') liked.delete(eq('post_id'));
      if (resource === 'veyro_group_members') memberships.get(eq('group_id')).delete(eq('user_id'));
      if (resource === 'saved_posts') saved.delete(eq('post_id'));
      if (resource === 'followers') follows.delete(eq('following_id'));
      const list = { posts, comments, notifications }[resource];
      const index = list?.findIndex((item) => item.id === eq('id'));
      if (index >= 0) return json(list.splice(index, 1));
      return json([]);
    } else if (method === 'PATCH') {
      if (resource === 'notifications') {
        for (const item of notifications.filter((item) => (!eq('id') || item.id === eq('id')) && !item.is_read)) {
          Object.assign(item, body);
          postgresChange('notifications', 'UPDATE', item);
        }
      }
      if (resource === 'messages') {
        for (const item of messages.filter((item) => item.chat_id === eq('chat_id') && item.receiver_id === eq('receiver_id') && !item.is_read)) {
          Object.assign(item, body);
          postgresChange('messages', 'UPDATE', item);
        }
        updateChat(eq('chat_id'));
      }
      if (resource === 'posts') {
        const post = posts.find((item) => item.id === eq('id'));
        return json(post ? [Object.assign(post, body)] : []);
      }
      return json([]);
    }
    return json({ message: `Unexpected fixture ${method} ${resource}` }, 404);
  });
  await page.routeWebSocket(`wss://${backend.host}/realtime/v1/websocket**`, (socket) => {
    const topics = new Map();
    sockets.set(socket, topics);
    socket.onClose(() => sockets.delete(socket));
    socket.onMessage((message) => {
      const event = JSON.parse(message);
      const response = {};
      if (event.event === 'phx_join') {
        response.postgres_changes = (event.payload.config?.postgres_changes || []).map((filter) => ({ ...filter, id: ++bindingId }));
        topics.set(event.topic, response.postgres_changes);
      } else if (event.event === 'phx_leave') {
        topics.delete(event.topic);
      }
      socket.send(JSON.stringify({ topic: event.topic, event: 'phx_reply', ref: event.ref,
        payload: { status: 'ok', response } }));
    });
  });
  await page.addInitScript(({ origin, key, value }) => {
    if (location.origin === origin) localStorage.setItem(key, value);
  }, { origin: url.origin, key: `sb-${backend.hostname.split('.')[0]}-auth-token`, value: JSON.stringify(session) });
  return { posts, saved, liked, comments, follows, messages, chats, notifications, writes, topicSearches, groups, memberships, storyItems,
    failNextReel() { rejectVideoPost = true; },
    receiveMessage(content) { return insertMessage({ chat_id: chats[0].id, sender_id: otherId, receiver_id: viewerId, content }); },
    receiveActivity() {
      const item = { id: nextId(410), user_id: viewerId, actor_id: otherId, type: 'comment', resource_id: firstPost,
        actor: people[1], message: 'commented on your post.', is_read: false, created_at: new Date().toISOString() };
      notifications.unshift(item);
      postgresChange('notifications', 'INSERT', item);
      return item;
    },
  };
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
  const waitGone = (name) => control(name).first().waitFor({ state: 'detached', timeout });
  return { press, enter, waitFor, waitGone, changed };
}

async function testSocial(page, state, name) {
  const { press, enter, waitFor, changed } = controls(page);
  const text = `New ${name} update from browser smoke.`;
  await waitFor('Like post');
  const home = await page.getByRole('button', { name: 'Home', exact: true }).boundingBox();
  const compose = await page.getByRole('button', { name: /What’s on your mind/ }).boundingBox();
  assert.ok(home && compose && (name === 'mobile' ? home.y > compose.y : home.x < compose.x),
    'Primary navigation is below the mobile feed and beside the desktop feed');
  await capture(page, `${name}-feed`);
  await changed('Like post', 'rpc/veyro_react', 'POST');
  await waitFor(/^Unlike post\b/);
  assert.ok(state.liked.has(firstPost));
  await changed('Save post', 'saved_posts', 'POST');
  assert.ok(state.saved.has(firstPost));
  await press(/^Comments\b/);
  await waitFor('Close comments');
  await enter('A real comment action in this test.');
  await changed('Send comment', 'comments', 'POST');
  await waitFor('Delete comment');
  assert.ok(state.comments.some((item) => item.content === 'A real comment action in this test.' && item.post_id === firstPost));
  await capture(page, `${name}-comments`);
  await press('Close comments');
  await press('Profile');
  await waitFor('Edit Profile');
  await capture(page, `${name}-profile`);
  await press('Saved posts');
  await press(/Open text post/);
  await waitFor(/^Unlike post\b/);
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
  await press('Home');
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
    await waitFor(/^Unlike post\b/);
    await press('Share post');
    await press('Send in message');
    await waitFor(/Veyro Friend.*Welcome to Veyro/s);
    await press(/Veyro Friend.*Welcome to Veyro/s);
    await changed('Send message', 'messages', 'POST');
    assert.equal(new URL(state.messages.at(-1).content).searchParams.get('post'), firstPost);
    await press('View shared post');
    await waitFor(/^Unlike post\b/);
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
    await waitFor(/^Comments\b/);
    await capture(page, `${name}-reels`);
  } else {
    await waitFor('Create a reel');
  }

  // The same link works when opened afresh and reads persisted viewer flags.
  await openApp(page, copy);
  await waitFor('Back');
  await waitFor(/^Unlike post\b/);
  assert.ok(state.saved.has(firstPost));
}

async function testSharingAndDiscovery(page, state, name) {
  const { press, enter, waitFor, waitGone, changed } = controls(page);
  // The earlier deep-link check leaves the original open. This avoids relying
  // on the order of feed items after the fixture writes.
  await press('Post options');
  await press('Repost or quote');
  await changed('Repost now', 'posts', 'POST');
  await waitGone('Close repost options');
  assert.equal(state.posts[0].shared_post_id, firstPost);
  assert.equal(state.posts[0].share_kind, 'repost');
  const repostId = state.posts[0].id;
  await press('Post options');
  await press('Repost or quote');
  await changed('Undo repost', 'posts', 'DELETE');
  await waitGone('Close repost options');
  assert.ok(!state.posts.some((post) => post.id === repostId));
  await press('Post options');
  await press('Repost or quote');
  await press('Quote post');
  await enter('I have another take. #veyro', /Your take/);
  await changed('Publish quote', 'posts', 'POST');
  await waitGone('Close repost options');
  assert.equal(state.posts[0].share_kind, 'quote');
  assert.equal(state.posts[0].description, 'I have another take. #veyro');
  assert.equal(state.posts[0].shared_post_id, firstPost);
  await waitFor('Post options');
  await press('Back');
  await waitFor('Refresh feed');
  await waitFor('#veyro');
  await capture(page, `${name}-quote-in-feed`);
  await press('#veyro');
  await waitFor('Refresh search');
  await waitFor(/Open text post/);
  assert.ok(state.topicSearches.includes('#veyro'), 'The topic opens filtered Explore results');
  await press('Back');
  await waitFor('Refresh feed');
  await press('Explore');
  await waitFor('Refresh search');
  await capture(page, `${name}-explore`);
  await press('People');
  await waitFor(/@veyro_friend/);
  await press(/@veyro_friend/);
  await waitFor('Message');
  await press('Back');
  await waitFor('Refresh search');
  await press(/\bHome\b/);
  await waitFor('Refresh feed');

  if (name === 'mobile') {
    await press('Photo');
    await waitFor('Add photos');
    const [chooser] = await Promise.all([
      page.waitForEvent('filechooser', { timeout }),
      press('Add photos', true),
    ]);
    await chooser.setFiles(photoFixture);
    await changed('Publish', 'posts', 'POST');
    const photo = state.posts[0];
    assert.equal(photo.type, 'image');
    assert.equal(photo.media_urls.length, 1);
    assert.match(photo.media_urls[0], /post-media\/00000000-0000-4000-8000-000000000001\//);
    assert.ok(state.writes.some((write) => write.resource === 'media'));
    await waitFor('Refresh feed');
    await capture(page, 'mobile-photo-in-feed');
  }
}

async function testCommunity(page, state, name) {
  const { press, enter, waitFor, changed } = controls(page);
  await press('Groups');
  await waitFor('Refresh groups');
  await waitFor(/^Open Aperture Club/);
  await capture(page, `${name}-groups`);
  await enter('Aperture', /Search groups/);
  await waitFor(/^Open Aperture Club/);
  await press(/^Open Aperture Club/);
  await waitFor('Join group');
  await changed('Join group', 'veyro_group_members', 'POST');
  assert.ok(state.memberships.get(otherGroup).has(viewerId));
  await press('Write a post');
  await waitFor('Publish');
  await enter(`A group update from ${name}.`, /Post text/);
  await changed('Publish', 'posts', 'POST');
  const update = state.posts[0];
  assert.equal(update.group_id, otherGroup);
  assert.equal(update.description, `A group update from ${name}.`);
  await waitFor('Refresh group');
  await press('Choose reaction');
  await changed('Love', 'rpc/veyro_react', 'POST');
  await waitFor('Remove Love reaction');
  assert.equal(state.liked.get(update.id), 'love');
  await press('Choose reaction');
  await changed('Wow', 'rpc/veyro_react', 'POST');
  await waitFor('Remove Wow reaction');
  assert.equal(state.liked.get(update.id), 'wow');
  await capture(page, `${name}-group-discussion`);
  await changed('Remove Wow reaction', 'likes', 'DELETE');
  assert.ok(!state.liked.has(update.id));
  await press('Leave group');
  await waitFor('Cancel');
  await changed('Leave group', 'veyro_group_members', 'DELETE');
  await waitFor('Join group');
  assert.ok(!state.memberships.get(otherGroup).has(viewerId));
  await press('Back');
  await waitFor('Refresh groups');
  await press('Clear group search');
  await press('New group');
  await enter(`${name} Lens Lab`, /Group name/);
  await changed('Create group', 'veyro_groups', 'POST');
  await waitFor('Edit group');
  const created = state.groups[0];
  assert.equal(created.name, `${name} Lens Lab`);
  assert.ok(state.memberships.get(created.id).has(viewerId));
  await press('Back');
  await waitFor('Refresh groups');
  await press('My groups');
  await waitFor(new RegExp(`^Open ${name} Lens Lab`));
  await press(/^Home\b/);
  await waitFor('Refresh feed');
  if (name === 'desktop') {
    await press('Create');
    await press(/Story.*Share for 24 hours/s);
  } else {
    await press('Add story');
  }
  const [chooser] = await Promise.all([
    page.waitForEvent('filechooser', { timeout }),
    press('Add photo', true),
  ]);
  await chooser.setFiles('test/fixtures/veyro-synthetic-story.webp');
  await changed('Publish story', 'rpc/veyro_add_story_item', 'POST');
  assert.equal(state.storyItems[0].media_type, 'image');
  await waitFor('New story by veyro_preview');
  await capture(page, `${name}-stories`);
  await press('New story by veyro_preview');
  await waitFor('Close story');
  await press('Close story');
  await waitFor('Viewed story by veyro_preview');
}

async function testQuickFlows(page, state, name) {
  const { press, enter, waitFor, changed } = controls(page);
  const responseFor = (resource, method) => (response) => new URL(response.url()).pathname === `/rest/v1/${resource}` &&
    response.request().method() === method;

  // A second browser/device action updates the badge via the shared live state
  // without opening the notifications screen to fetch it manually.
  const nextActivity = page.waitForResponse(responseFor('notifications', 'GET'), { timeout: 6500 });
  const activity = state.receiveActivity();
  assert.ok((await nextActivity).ok(), 'activity socket prompted a refresh');
  await capture(page, `${name}-unread-badges`);
  await press('Notifications');
  await waitFor('Mark all as read');
  await capture(page, `${name}-activity`);
  await changed(/veyro_friend commented on your post/, 'notifications', 'PATCH');
  assert.equal(activity.is_read, true, 'Opening the row marks it read');
  await waitFor('Post options');
  await press('Back');
  if (name === 'mobile') await changed('Mark all as read', 'notifications', 'PATCH');
  await changed('Dismiss notification', 'notifications', 'DELETE');
  assert.ok(!state.notifications.some((item) => item.id === activity.id), 'Dismiss removes the activity');
  await press('Back');
  await waitFor('Refresh feed');

  const incoming = state.receiveMessage('A fresh DM from the other account.');
  await press('Messages');
  await waitFor(/A fresh DM from the other account/);
  await capture(page, `${name}-inbox`);
  await changed(/A fresh DM from the other account/, 'messages', 'PATCH');
  assert.equal(incoming.is_read, true, 'Opening a conversation clears its received unread messages');
  await capture(page, `${name}-thread`);
  await press('Back');
  await waitFor('New message');
  await enter('@veyro_lex', /Search by username/);
  await changed(/@veyro_lex/, 'chats', 'POST');
  const text = `Hello from the ${name} inbox!`;
  await enter(text, /Type a message/);
  await changed('Send message', 'messages', 'POST');
  assert.deepEqual([state.messages.at(-1).receiver_id, state.messages.at(-1).content], [lexId, text]);
  await press('Back');
  await press('Clear search');
  await waitFor(new RegExp(text));
  await press('Back');
  await waitFor('Refresh feed');

  if (!reelFile) return;
  await press('Create');
  await capture(page, `${name}-create-menu`);
  await press(/Reel.*Share a video/s);
  const uploadCount = state.writes.filter((write) => write.resource === 'media').length;
  async function chooseVideo(file) {
    const [chooser] = await Promise.all([page.waitForEvent('filechooser', { timeout }), press('Choose video', true)]);
    await chooser.setFiles(file);
  }
  if (name === 'mobile') {
    await chooseVideo({ name: 'not_a_video.txt', mimeType: 'text/plain', buffer: Buffer.from('Invalid media fixture') });
    await waitFor(/This media format is not supported/);
    assert.equal(state.writes.filter((write) => write.resource === 'media').length, uploadCount);
  }
  await chooseVideo(reelFile);
  await waitFor('Play preview');
  const preview = page.locator('video[src^="blob:"]').first();
  await preview.waitFor({ state: 'attached', timeout });
  assert.ok(await preview.evaluate((element) => element.duration > 0), 'Selected clip has a local preview');
  await press('Play preview', true);
  await waitFor('Pause preview');
  await press('Pause preview');
  const caption = `A ${name} reel, previewed before sharing.`;
  await enter(caption, /Caption/);
  await capture(page, `${name}-reel-composer`);
  await press('Close reel composer');
  await press('Keep editing');
  if (name === 'desktop') {
    state.failNextReel();
    const [failed] = await Promise.all([page.waitForResponse(responseFor('posts', 'POST'), { timeout }), press('Share')]);
    assert.equal(failed.status(), 503, 'Fixture exercises upload retry');
    await waitFor('Play preview');
  }
  await changed('Share', 'posts', 'POST');
  assert.equal(state.posts[0].type, 'video');
  assert.equal(state.posts[0].description, caption, 'Reel draft is retained until Share succeeds');
  assert.match(state.posts[0].media_urls[0], new RegExp(`post-media/${viewerId}/.*\\.webm$`));
  assert.ok(state.writes.some((write) => write.resource === 'media' && write.resourcePath?.endsWith('.webm') && write.bytes > 0),
    'Actual picked bytes go to the existing owner-scoped upload endpoint');
  await waitFor('Refresh reels');
  await capture(page, `${name}-reel-published`);
}

async function testViewport(browser, name, viewport) {
  for (const signedIn of [false, true]) {
    const browserContext = await browser.newContext({
      viewport,
      deviceScaleFactor: 1,
      isMobile: name === 'mobile',
      hasTouch: name === 'mobile',
      locale: 'en-US',
      colorScheme: name === 'desktop' ? 'dark' : 'light',
    });
    await browserContext.grantPermissions(['clipboard-read', 'clipboard-write'], { origin: url.origin });
    const page = await browserContext.newPage();
    const issues = [];
    page.on('pageerror', (err) => issues.push(err.message));
    page.on('console', (message) => {
      if (message.type() === 'error' && /exception caught by|renderflex overflowed|renderbox was not laid out/i.test(message.text())) {
        issues.push(message.text());
      }
    });
    page.on('response', (res) => {
      if (new URL(res.url()).origin === url.origin && res.status() >= 400) {
        issues.push(`${res.status()} ${new URL(res.url()).pathname}`);
      }
    });
    try {
      const social = signedIn ? await mockSignedIn(page, name === 'desktop' ? 'dark' : 'light') : null;
      await openApp(page);
      const button = (label) => page.getByRole('button', { name: label, exact: true }).first();
      const waitFor = (label) => button(label).waitFor({ state: 'attached', timeout });
      if (social) {
        await testSocial(page, social, name);
        await testSharingAndDiscovery(page, social, name);
        await testCommunity(page, social, name);
        await testQuickFlows(page, social, name);
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

async function testShowcase(browser, name, viewport, theme) {
  const context = await browser.newContext({ viewport, colorScheme: theme,
    deviceScaleFactor: 1, hasTouch: name === 'mobile', isMobile: name === 'mobile' });
  try {
    const page = await context.newPage();
    await mockSignedIn(page, theme, true);
    const prefs = page.waitForResponse(response => new URL(response.url()).pathname === '/rest/v1/settings');
    const image = page.waitForResponse(response => new URL(response.url()).pathname.endsWith('/veyro-browser-test-photo.webp'));
    await openApp(page);
    assert.ok((await prefs).ok(), `${theme} preference loaded`);
    assert.ok((await image).ok(), 'The fixture feed displays a portrait photograph');
    await controls(page).waitFor('New story by veyro_friend');
    await page.getByLabel('Post photo 1', { exact: true }).first().waitFor({ state: 'attached', timeout });
    await capture(page, `${name}-photo-feed-${theme}`);
  } finally {
    await context.close();
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
    await testShowcase(browser, 'desktop', { width: 1360, height: 860 }, 'dark');
    await testShowcase(browser, 'mobile', { width: 390, height: 844 }, 'dark');
    await testShowcase(browser, 'mobile', { width: 390, height: 844 }, 'light');
    console.log('::notice::Veyro auth and signed-in social flows verified in desktop and mobile Chrome (fixture backend).');
  } finally {
    await browser.close();
  }
})().catch((error) => {
  const text = (error.stack || error.message).replace(/%/g, '%25').replace(/\r/g, '%0D').replace(/\n/g, '%0A');
  console.error(`::error::${text}`);
  process.exitCode = 1;
});
