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
