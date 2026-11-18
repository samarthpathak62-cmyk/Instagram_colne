// Run in an isolated Postgres WASM instance, not against the shared Veyro data.
// NODE_PATH can point at a temporary install of @electric-sql/pglite.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { PGlite } = require('@electric-sql/pglite');

const migrationDir = 'supabase/migrations';
const db = new PGlite();

async function main() {
  await db.exec(fs.readFileSync('test/fixtures/veyro_social_schema.sql', 'utf8'));
  for (const suffix of ['_veyro_social_actions.sql', '_veyro_following_rest.sql', '_veyro_post_shares.sql', '_veyro_groups_and_reactions.sql']) {
    const migration = fs.readdirSync(migrationDir).find((name) => name.endsWith(suffix));
    assert.ok(migration, `Missing migration: ${suffix}`);
    await db.exec(`begin;\n${fs.readFileSync(`${migrationDir}/${migration}`, 'utf8')}\ncommit;`);
  }
  const ids = [1, 2, 3].map((n) => `00000000-0000-4000-8000-00000000000${n}`);
  const [alice, bob, other] = ids;
  await db.query('insert into public.users values ($1), ($2), ($3)', ids);
  async function viewer(id) {
    await db.exec('set role authenticated');
    await db.query("select set_config('request.jwt.claim.sub', $1, false)", [id]);
  }
  await db.exec('set role anon');
  await assert.rejects(db.query('select * from public.veyro_following_posts()'), /permission denied/);
  await assert.rejects(db.query('select * from public.veyro_following_feed'), /permission denied/);
  const writePost = "insert into public.posts (author_id, type, description) values ($1, 'text', $2) returning id";
  await viewer(alice);
  await assert.rejects(db.query(writePost, [alice, ' \n\t']), /veyro_valid_text_post/);
  await assert.rejects(db.query(writePost, [alice, 'x'.repeat(501)]), /veyro_valid_text_post/);
  await assert.rejects(db.query(writePost, [bob, 'Not my account']), /row-level security/);
  const post = (await db.query(writePost, [alice, 'Hello from Veyro'])).rows[0].id;
  await db.query("insert into public.posts (author_id, type, media_urls) values ($1, 'image', array['example.jpg'])", [alice]);
  await viewer(other);
  await db.query(writePost, [other, 'Unrelated']);
  await viewer(bob);
  await db.query(writePost, [bob, 'My own update']);
  assert.equal((await db.query('select * from public.veyro_following_posts()')).rows.length, 1);
  await db.query('insert into public.followers values ($1, $2)', [bob, alice]);
  for (const source of ['veyro_following_posts()', 'veyro_following_feed']) {
    assert.deepEqual((await db.query(`select distinct author_id from public.${source} order by author_id`)).rows.map((row) => row.author_id), [alice, bob]);
  }
  await db.query('insert into public.likes values ($1, $2)', [post, bob]);
  await db.query('delete from public.likes where post_id = $1', [post]);
  await db.query('insert into public.likes values ($1, $2)', [post, bob]);
  const writeComment = 'insert into public.comments (post_id, user_id, content) values ($1, $2, $3) returning id';
  await assert.rejects(db.query(writeComment, [post, bob, '\t\n']), /veyro_valid_comment/);
  await assert.rejects(db.query(writeComment, [post, bob, 'x'.repeat(1001)]), /veyro_valid_comment/);
  await assert.rejects(db.query(writeComment, [post, alice, 'Spoofed']), /row-level security/);
  const comment = (await db.query(writeComment, [post, bob, 'Nice post!'])).rows[0].id;
  await db.query('insert into public.saved_posts (post_id,user_id) values ($1,$2)', [post, bob]);
  assert.equal((await db.query('select * from public.notifications')).rows.length, 0);
  await assert.rejects(db.query("insert into public.notifications (user_id, type) values ($1, 'system')", [alice]), /permission denied/);
  await viewer(alice);
  assert.equal((await db.query('select * from public.saved_posts')).rows.length, 0);
  assert.equal((await db.query('delete from public.comments where id = $1 returning id', [comment])).rows.length, 0);
  await db.query('insert into public.likes values ($1, $2)', [post, alice]);
  assert.deepEqual((await db.query('select type from public.notifications order by type')).rows.map((row) => row.type), ['comment', 'follow', 'like']);
  await db.query('update public.notifications set is_read = true');
  await db.query('insert into public.settings (user_id, notifications_enabled) values ($1, false)', [alice]);
  await viewer(other);
  await db.query('insert into public.followers values ($1, $2)', [other, alice]);
  await viewer(alice);
  assert.equal((await db.query('select * from public.notifications')).rows.length, 3);
  await assert.rejects(db.query("update public.notifications set message = 'spoofed'"), /permission denied/);
  await viewer(bob);
  assert.equal((await db.query('delete from public.comments where id = $1 returning id', [comment])).rows.length, 1);
  assert.equal((await db.query('delete from public.posts where id = $1 returning id', [post])).rows.length, 0);
  await viewer(alice);
  assert.equal((await db.query('delete from public.posts where id = $1 returning id', [post])).rows.length, 1);
  const newGroup = 'insert into public.veyro_groups (owner_id, name, category) values ($1, $2, $3) returning id';
  await assert.rejects(db.query(newGroup, [bob, 'Spoofed group', 'general']), /row-level security/);
  await assert.rejects(db.query(newGroup, [alice, 'x', 'general']), /check constraint/);
  const group = (await db.query(newGroup, [alice, 'Street Photography', 'creative'])).rows[0].id;
  const members = 'select user_id from public.veyro_group_members where group_id = $1 order by user_id';
  assert.deepEqual((await db.query(members, [group])).rows, [{ user_id: alice }]);
  const leave = 'delete from public.veyro_group_members where group_id = $1 returning user_id';
  assert.deepEqual((await db.query(leave, [group])).rows, [], 'Owner cannot leave');
  const publish = "insert into public.posts (author_id, type, description, group_id) values ($1, 'text', 'Group update', $2) returning id";
  const join = 'insert into public.veyro_group_members (group_id, user_id) values ($1, $2)';
  await viewer(bob);
  await assert.rejects(db.query(publish, [bob, group]), /row-level security/);
  await assert.rejects(db.query(join, [group, other]), /row-level security/);
  await db.query(join, [group, bob]);
  await assert.rejects(db.query(join, [group, bob]), /duplicate key/);
  const groupPost = (await db.query(publish, [bob, group])).rows[0].id;
  await assert.rejects(db.query('update public.posts set group_id = null where id = $1', [groupPost]), /cannot move/);
  assert.equal((await db.query("update public.veyro_groups set name = 'Not allowed' where id = $1 returning id", [group])).rows.length, 0);
  assert.deepEqual((await db.query(leave, [group])).rows, [{ user_id: bob }]);
  await assert.rejects(db.query(publish, [bob, group]), /row-level security/);
  await db.query('insert into public.likes (post_id,user_id) values ($1,$2)', [groupPost, bob]);
  assert.equal((await db.query('select reaction from public.likes where post_id = $1', [groupPost])).rows[0].reaction, 'like');
  await viewer(other);
  assert.equal((await db.query('select id from public.posts where group_id = $1', [group])).rows.length, 1, 'Groups are public');
  assert.equal((await db.query('delete from public.posts where id = $1 returning id', [groupPost])).rows.length, 0);
  assert.equal((await db.query("update public.likes set reaction = 'sad' where post_id = $1 returning user_id", [groupPost])).rows.length, 0);
  await db.query("select public.veyro_react($1, 'love')", [groupPost]);
  await db.query("select public.veyro_react($1, 'wow')", [groupPost]);
  await assert.rejects(db.query("select public.veyro_react($1, 'nope')", [groupPost]), /check constraint/);
  const tally = 'select jsonb_object_agg(r.reaction, r.total) as counts from public.posts p, lateral public.veyro_reaction_counts(p) r where p.id = $1';
  assert.deepEqual((await db.query(tally, [groupPost])).rows[0].counts, { like: 1, wow: 1 });
  await db.exec("reset role; set role anon; select set_config('request.jwt.claim.sub', '', false)");
  await assert.rejects(db.query(members, [group]), /permission denied/);
  await assert.rejects(db.query("select public.veyro_react($1, 'like')", [groupPost]), /permission denied/);
  await viewer(alice);
  assert.equal((await db.query('delete from public.posts where id = $1 returning id', [groupPost])).rows.length, 1, 'Group admins can remove group posts');
  console.log('Social schema: Following, saves, activity, public group membership/ownership and reaction integrity passed.');
}

main().catch((error) => { console.error(error); process.exitCode = 1; }).finally(() => db.close());
