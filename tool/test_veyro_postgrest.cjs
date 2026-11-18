// Tests the actual HTTP API and PostgREST SQL generator in a disposable DB.
// Do not point this at a deployed API or use a deployment signing secret.
const assert = require('node:assert/strict');
const { createHmac } = require('node:crypto');

const base = 'http://127.0.0.1:3100';
const viewer = '00000000-0000-4000-8000-000000000002';
const originalAuthor = '00000000-0000-4000-8000-000000000001';
const followedPost = '00000000-0000-4000-8000-000000000010';
const ownPost = '00000000-0000-4000-8000-000000000011';
const legacySelect = 'id,author_id,type,media_urls,description,caption,created_at,' +
  'author:users!posts_author_id_fkey(id,username,profile_picture_url),' +
  'likes(count),comments(count),liked_by_user:likes(user_id),saved_by_user:saved_posts(id)';
const preview = 'id,author_id,type,media_urls,description,caption,created_at,share_kind,' +
  'author:users!posts_author_id_fkey(id,username,full_name,profile_picture_url)';
const modernSelect = `${preview},shared_post_id,source:veyro_shared_post(${preview}),` +
  'likes(count),comments(count)';
const filters = new URLSearchParams({
  select: legacySelect,
  'liked_by_user.user_id': `eq.${viewer}`,
  'saved_by_user.user_id': `eq.${viewer}`,
  order: 'created_at.desc.nullslast,id.desc.nullslast', offset: '0', limit: '10',
});
const secret = process.env.VEYRO_TEST_JWT_SECRET;
assert.ok(secret && secret.length >= 32, 'Set the disposable DB JWT secret.');
function token(sub) {
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const signed = `${encode({ alg: 'HS256', typ: 'JWT' })}.${encode({
    role: 'authenticated', sub, exp: Math.floor(Date.now() / 1000) + 300,
  })}`;
  return `${signed}.${createHmac('sha256', secret).update(signed).digest('base64url')}`;
}
async function request(route, query, { sub = viewer, method = 'GET', value } = {}) {
  const headers = sub ? { Authorization: `Bearer ${token(sub)}` } : {};
  if (value) {
    headers['Content-Type'] = 'application/json';
    headers.Prefer = 'return=representation';
    headers.Accept = 'application/vnd.pgrst.object+json';
  }
  const result = await fetch(`${base}${route}?${query}`, {
    headers, method, body: value && JSON.stringify(value),
  });
  const body = await result.text();
  return { status: result.status, data: body ? JSON.parse(body) : null };
}

async function testCommunity() {
  const createGroup = (owner_id) => request('/veyro_groups', 'select=id,owner_id,name', {
    method: 'POST', sub: originalAuthor, value: { owner_id, name: 'Aperture Club', category: 'creative' },
  });
  assert.equal((await createGroup(viewer)).status, 403);
  const created = await createGroup(originalAuthor);
  assert.equal(created.status, 201, JSON.stringify(created.data));
  const groupId = created.data.id;
  const memberProjection = 'id,owner_id,name,members:veyro_group_members(count),membership:veyro_group_members(user_id)';
  const groupQuery = () => new URLSearchParams({ id: `eq.${groupId}`, select: memberProjection, 'membership.user_id': `eq.${viewer}` });
  const group = (await request('/veyro_groups', groupQuery())).data[0];
  assert.deepEqual(group.members, [{ count: 1 }]);
  assert.deepEqual(group.membership, []);
  const groupPostSelect = `${modernSelect},group_id,group:veyro_groups(name),reaction_counts:veyro_reaction_counts(reaction,total),liked_by_user:likes(user_id,reaction),saved_by_user:saved_posts(id)`;
  const publish = () => request('/posts', new URLSearchParams({ select: groupPostSelect }), {
    method: 'POST', value: { author_id: viewer, group_id: groupId, type: 'text', description: 'Hello to Aperture Club', media_urls: [] },
  });
  const refused = await publish();
  assert.equal(refused.status, 403, `Posting requires membership: ${JSON.stringify(refused.data)}`);
  const join = (user_id) => request('/veyro_group_members', 'select=group_id,user_id', {
    method: 'POST', value: { group_id: groupId, user_id },
  });
  assert.equal((await join(originalAuthor)).status, 403);
  assert.equal((await join(viewer)).status, 201);
  assert.equal((await join(viewer)).status, 409);
  const myGroups = groupQuery();
  myGroups.set('select', memberProjection.replace('membership:veyro_group_members(', 'membership:veyro_group_members!inner('));
  const member = (await request('/veyro_groups', myGroups)).data[0];
  assert.deepEqual(member.members, [{ count: 2 }]);
  assert.deepEqual(member.membership, [{ user_id: viewer }]);
  assert.deepEqual((await request('/veyro_groups', new URLSearchParams({ select: 'name', name: 'ilike.%aperture%' }))).data, [{ name: 'Aperture Club' }]);
  const published = await publish();
  assert.equal(published.status, 201, JSON.stringify(published.data));
  const id = published.data.id;
  assert.equal(published.data.group.name, 'Aperture Club');
  const react = (p_reaction, sub) => request('/rpc/veyro_react', '', { method: 'POST', sub, value: { p_post_id: id, p_reaction } });
  assert.equal((await react('love')).status, 204);
  assert.equal((await react('wow')).status, 204);
  assert.equal((await react('like', originalAuthor)).status, 204);
  assert.equal((await react('invalid')).status, 400);
  assert.ok([401, 403, 404].includes((await react('sad', null)).status));
  const postQuery = new URLSearchParams({
    select: groupPostSelect, group_id: `eq.${groupId}`, 'liked_by_user.user_id': `eq.${viewer}`, 'saved_by_user.user_id': `eq.${viewer}`,
  });
  for (const route of ['/posts', '/veyro_following_feed']) {
    const listing = await request(route, postQuery);
    assert.equal(listing.status, 200, `${route}: ${JSON.stringify(listing.data)}`);
    assert.equal(listing.data.length, 1);
    assert.equal(listing.data[0].group.name, 'Aperture Club');
    assert.deepEqual(Object.fromEntries(listing.data[0].reaction_counts.map(({ reaction, total }) => [reaction, total])), { like: 1, wow: 1 });
    assert.deepEqual(listing.data[0].liked_by_user, [{ user_id: viewer, reaction: 'wow' }]);
  }
  assert.equal((await request('/likes', new URLSearchParams({ post_id: `eq.${id}`, user_id: `eq.${viewer}` }), { method: 'DELETE' })).status, 204);
  assert.deepEqual((await request('/posts', postQuery)).data[0].reaction_counts, [{ reaction: 'like', total: 1 }]);
  assert.equal((await request('/veyro_group_members', new URLSearchParams({ group_id: `eq.${groupId}`, user_id: `eq.${viewer}` }), { method: 'DELETE' })).status, 204);
  assert.deepEqual((await request('/veyro_groups', myGroups)).data, []);
  assert.equal((await publish()).status, 403);
  assert.equal((await request('/posts', new URLSearchParams({ id: `eq.${id}` }), { method: 'DELETE', sub: originalAuthor })).status, 204);
  assert.deepEqual((await request('/posts', postQuery)).data, []);
  console.log('Group create/join/post/leave, moderator removal, nonmember denial, and one reaction per viewer passed real PostgREST.');
}

async function main() {
  // Deliberately use the installed APK's exact shape, including its embedded
  // filters, as well as the replacement table-shaped endpoint in new builds.
  for (const route of ['/rpc/veyro_following_posts', '/veyro_following_feed']) {
    const result = await request(route, filters);
    assert.equal(result.status, 200, `${route}: ${JSON.stringify(result.data)}`);
    assert.deepEqual(result.data.map((row) => row.id), [ownPost, followedPost]);
    const [own, other] = result.data;
    assert.equal(own.author.username, 'bob');
    assert.deepEqual(own.saved_by_user, [], 'Someone else’s save stays private');
    assert.deepEqual(own.liked_by_user, []);
    assert.equal(other.author.username, 'alice');
    assert.equal(other.likes[0].count, 2);
    assert.deepEqual(other.liked_by_user, [{ user_id: viewer }]);
    assert.equal(other.saved_by_user.length, 1);
    const page = new URLSearchParams(filters);
    page.set('offset', '1');
    page.set('limit', '1');
    assert.deepEqual((await request(route, page)).data.map((row) => row.id), [followedPost]);
    const guest = await request(route, filters, { sub: null });
    assert.ok([401, 403].includes(guest.status), `${route} denies guests: ${guest.status}`);
  }
  const share = (description, share_kind, author_id = viewer) => request('/posts',
    new URLSearchParams({ select: modernSelect }), {
      method: 'POST', value: {
        author_id, type: 'text', description, media_urls: [],
        shared_post_id: followedPost, share_kind,
      },
    });
  const quote = await share('A new point of view.', 'quote');
  assert.equal(quote.status, 201, JSON.stringify(quote.data));
  assert.equal(quote.data.source.id, followedPost);
  assert.equal(quote.data.source.author.username, 'alice');
  const repost = await share('Reposted a post on Veyro.', 'repost');
  assert.equal(repost.status, 201, JSON.stringify(repost.data));
  assert.equal((await share('Duplicate repost', 'repost')).status, 409);
  assert.equal((await share('Not my account', 'quote', originalAuthor)).status, 403);
  const result = await request('/veyro_following_feed', new URLSearchParams({
    id: `eq.${quote.data.id}`, select: `${modernSelect},liked_by_user:likes(user_id),saved_by_user:saved_posts(id)`,
    'liked_by_user.user_id': `eq.${viewer}`, 'saved_by_user.user_id': `eq.${viewer}`,
  }));
  assert.equal(result.status, 200, JSON.stringify(result.data));
  assert.equal(result.data[0].source.id, followedPost);
  const postById = (id) => new URLSearchParams({ id: `eq.${id}`, select: modernSelect });
  const remove = (id, sub) => request('/posts', postById(id), { method: 'DELETE', sub });
  await remove(repost.data.id, originalAuthor);
  assert.equal((await request('/posts', postById(repost.data.id))).data.length, 1);
  await remove(repost.data.id, viewer);
  assert.equal((await request('/posts', postById(repost.data.id))).data.length, 0);
  await remove(followedPost, originalAuthor);
  const after = (await request('/posts', postById(quote.data.id))).data[0];
  assert.equal(after.description, 'A new point of view.');
  assert.equal(after.shared_post_id, null);
  assert.equal(after.source, null);
  console.log('Quote, repost, ownership, undo and original deletion passed real PostgREST.');
  console.log('Private viewer flags, pagination and both Following endpoints passed real PostgREST.');
  await testCommunity();
}

main().catch((error) => {
  // Runner logs may be inaccessible to the sandbox; keep the failure in CI annotations.
  console.error(error);
  console.log('::error title=PostgREST integration::' + error.message.replaceAll('%', '%25').replaceAll('\n', '%0A'));
  process.exitCode = 1;
});
