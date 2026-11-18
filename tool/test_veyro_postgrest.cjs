// Tests the actual HTTP API and PostgREST SQL generator in a disposable DB.
// Do not point this at a deployed API or use a deployment signing secret.
const assert = require('node:assert/strict');
const { createHmac } = require('node:crypto');

const base = 'http://127.0.0.1:3100';
const viewer = '00000000-0000-4000-8000-000000000002';
const followedPost = '00000000-0000-4000-8000-000000000010';
const ownPost = '00000000-0000-4000-8000-000000000011';
const legacySelect = 'id,author_id,type,media_urls,description,caption,created_at,' +
  'author:users!posts_author_id_fkey(id,username,full_name,profile_picture_url),' +
  'likes(count),comments(count),liked_by_user:likes(user_id),saved_by_user:saved_posts(id)';
const filters = new URLSearchParams({
  select: legacySelect,
  'liked_by_user.user_id': `eq.${viewer}`,
  'saved_by_user.user_id': `eq.${viewer}`,
  order: 'created_at.desc.nullslast,id.desc', offset: '0', limit: '10',
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
async function read(route, query, sub = viewer) {
  const result = await fetch(`${base}${route}?${query}`, {
    headers: sub ? { Authorization: `Bearer ${token(sub)}` } : {},
  });
  return { status: result.status, data: await result.json() };
}

async function main() {
  // Deliberately use the installed APK's exact shape, including its embedded
  // filters, as well as the replacement table-shaped endpoint in new builds.
  for (const route of ['/rpc/veyro_following_posts', '/veyro_following_feed']) {
    const result = await read(route, filters);
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
    assert.deepEqual((await read(route, page)).data.map((row) => row.id), [followedPost]);
    const guest = await read(route, filters, null);
    assert.ok([401, 403].includes(guest.status), `${route} denies guests: ${guest.status}`);
  }
  console.log('Private viewer flags, pagination and both Following endpoints passed real PostgREST.');
}

main().catch((error) => {
  // Runner logs may be inaccessible to the sandbox; keep the failure in CI annotations.
  console.error(error);
  console.log('::error title=PostgREST integration::' + error.message.replaceAll('%', '%25').replaceAll('\n', '%0A'));
  process.exitCode = 1;
});
