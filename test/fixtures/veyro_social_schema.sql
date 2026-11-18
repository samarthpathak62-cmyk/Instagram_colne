-- Minimal standalone schema for testing the migrations. Not deployed.
create role anon;
create role authenticated;
create schema auth;
grant usage on schema auth to anon, authenticated;
create function auth.uid() returns uuid language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''),
                  nullif(current_setting('request.jwt.claims', true), '')::jsonb->>'sub')::uuid
$$;
create table public.users (
  id uuid primary key, username text, full_name text, profile_picture_url text
);
create table public.posts (
  id uuid primary key default gen_random_uuid(), author_id uuid not null references public.users,
  type text not null default 'image', media_urls text[], description text, caption text, created_at timestamptz default now()
);
create table public.comments (
  id uuid primary key default gen_random_uuid(), post_id uuid not null references public.posts on delete cascade,
  user_id uuid not null references public.users, content text not null, created_at timestamptz default now()
);
create table public.likes (
  post_id uuid not null references public.posts on delete cascade, user_id uuid not null references public.users, unique (post_id, user_id)
);
create table public.followers (
  follower_id uuid not null references public.users, following_id uuid not null references public.users, unique (follower_id, following_id)
);
create table public.saved_posts (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.users,
  post_id uuid not null references public.posts on delete cascade, unique (user_id, post_id)
);
create table public.notifications (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.users, actor_id uuid references public.users,
  type text not null, resource_id uuid, message text, is_read bool default false, created_at timestamptz default now()
);
create table public.settings (user_id uuid primary key references public.users, notifications_enabled bool default true);
grant insert, update on public.settings to authenticated;
alter table public.settings enable row level security;
create policy own_settings on public.settings for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
grant select on all tables in schema public to anon, authenticated;
grant insert, update, delete on public.posts to authenticated;
grant insert, delete on public.likes, public.followers, public.saved_posts to authenticated;
grant insert on public.comments to authenticated;
grant update (is_read), delete on public.notifications to authenticated;
alter table public.posts enable row level security;
alter table public.comments enable row level security;
alter table public.likes enable row level security;
alter table public.followers enable row level security;
alter table public.saved_posts enable row level security;
alter table public.notifications enable row level security;
create policy public_posts on public.posts for select using (true);
create policy owner_writes on public.posts for all to authenticated using (author_id = auth.uid()) with check (author_id = auth.uid());
create policy public_comments on public.comments for select using (true);
create policy own_comment on public.comments for insert to authenticated with check (user_id = auth.uid());
create policy public_likes on public.likes for select using (true);
create policy own_like on public.likes for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy public_follows on public.followers for select using (true);
create policy own_follow on public.followers for all to authenticated using (follower_id = auth.uid()) with check (follower_id = auth.uid());
create policy private_saves on public.saved_posts for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy private_activity on public.notifications for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Existing messaging contracts, isolated here because the integration
-- migration also manages Supabase-only storage buckets and publications.
create table public.chats (
  id uuid primary key default gen_random_uuid(),
  user1_id uuid not null references public.users on delete cascade,
  user2_id uuid not null references public.users on delete cascade,
  last_message_time timestamptz default now(), has_unread_messages bool default false,
  unique (user1_id, user2_id)
);
create table public.messages (
  id uuid primary key default gen_random_uuid(), chat_id uuid not null references public.chats on delete cascade,
  sender_id uuid not null references public.users on delete cascade,
  receiver_id uuid not null references public.users on delete cascade,
  content text not null, timestamp timestamptz default now(), is_read bool default false
);
alter table public.chats enable row level security;
alter table public.messages enable row level security;
grant select, insert on public.chats, public.messages to authenticated;
grant update (is_read) on public.messages to authenticated;
create policy chat_participants on public.chats for select to authenticated using (auth.uid() in (user1_id, user2_id));
create policy chat_create on public.chats for insert to authenticated with check (user1_id <> user2_id and auth.uid() in (user1_id, user2_id));
create policy message_participants on public.messages for select to authenticated using (auth.uid() in (sender_id, receiver_id));
create policy message_send on public.messages for insert to authenticated with check (
  sender_id = auth.uid() and is_read is false and exists (
    select 1 from public.chats c where c.id = chat_id and
      ((c.user1_id = sender_id and c.user2_id = receiver_id) or (c.user2_id = sender_id and c.user1_id = receiver_id))
  )
);
create policy message_read on public.messages for update to authenticated using (receiver_id = auth.uid())
  with check (receiver_id = auth.uid() and is_read is true);
