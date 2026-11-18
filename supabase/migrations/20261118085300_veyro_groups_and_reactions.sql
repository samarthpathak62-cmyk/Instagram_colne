-- Public group content and one reaction per post/viewer. Older clients keep
-- reading ordinary posts and total likes; their inserts default to Like.
set local lock_timeout = '5s';

create table public.veyro_groups (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.users(id) on delete set null,
  name text not null check (char_length(trim(name)) between 3 and 50),
  description text not null default '' check (char_length(description) <= 360),
  category text not null default 'general'
    check (category in ('general', 'creative', 'local', 'gaming', 'learning')),
  created_at timestamptz not null default now()
);
create table public.veyro_group_members (
  group_id uuid not null references public.veyro_groups(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index veyro_group_members_by_user on public.veyro_group_members (user_id, group_id);
create index veyro_group_directory on public.veyro_groups (created_at desc, id desc);
alter table public.veyro_groups enable row level security;
alter table public.veyro_group_members enable row level security;
revoke all on public.veyro_groups, public.veyro_group_members from public, anon, authenticated;
grant select on public.veyro_groups to anon, authenticated;
grant select on public.veyro_group_members to authenticated;
grant insert (owner_id, name, description, category) on public.veyro_groups to authenticated;
grant update (name, description, category) on public.veyro_groups to authenticated;
grant insert (group_id, user_id) on public.veyro_group_members to authenticated;
grant delete on public.veyro_group_members to authenticated;

create policy veyro_read_groups on public.veyro_groups for select to anon, authenticated using (true);
create policy veyro_create_group on public.veyro_groups for insert to authenticated
  with check (owner_id = (select auth.uid()));
create policy veyro_edit_group on public.veyro_groups for update to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy veyro_read_group_members on public.veyro_group_members for select to authenticated using (true);
create policy veyro_join_group on public.veyro_group_members for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy veyro_leave_group on public.veyro_group_members for delete to authenticated
  using (user_id = (select auth.uid()) and not exists (
    select from public.veyro_groups g
    where g.id = veyro_group_members.group_id and g.owner_id = (select auth.uid())
  ));

create function public.veyro_group_owner_membership() returns trigger
  language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.veyro_group_members (group_id, user_id) values (new.id, new.owner_id);
  return new;
end;
$$;
revoke all on function public.veyro_group_owner_membership() from public, anon, authenticated;
create trigger veyro_group_owner_join after insert on public.veyro_groups
  for each row execute function public.veyro_group_owner_membership();

alter table public.posts add column group_id uuid references public.veyro_groups(id) on delete cascade;
create index veyro_group_timeline on public.posts (group_id, created_at desc nulls last, id desc)
  where group_id is not null;
create policy veyro_only_members_publish_to_group on public.posts as restrictive
  for insert to authenticated with check (group_id is null or exists (
    select from public.veyro_group_members m
    where m.group_id = posts.group_id and m.user_id = (select auth.uid())
  ));
create policy veyro_group_owner_remove_post on public.posts for delete to authenticated
  using (group_id is not null and exists (
    select from public.veyro_groups g
    where g.id = posts.group_id and g.owner_id = (select auth.uid())
  ));
create function public.veyro_post_audience_immutable() returns trigger
  language plpgsql set search_path = ''
as $$
begin
  if new.group_id is distinct from old.group_id then
    raise exception 'A published post cannot move to another audience' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function public.veyro_post_audience_immutable() from public, anon, authenticated;
create trigger veyro_keep_post_audience before update of group_id on public.posts
  for each row execute function public.veyro_post_audience_immutable();

-- Append a column without changing the legacy Following RPC composite type.
create or replace view public.veyro_following_feed with (security_invoker = true) as
  select p.id, p.author_id, p.type, p.media_urls, p.description, p.caption,
         p.created_at, null::uuid as user_id, p.shared_post_id, p.share_kind, p.group_id
  from public.posts p
  where p.author_id = (select auth.uid())
     or exists (
       select from public.followers f
       where f.follower_id = (select auth.uid()) and f.following_id = p.author_id
     );

alter table public.likes add column reaction text not null default 'like'
  check (reaction in ('like', 'love', 'care', 'laugh', 'wow', 'sad'));
revoke update on public.likes from public, anon, authenticated;
grant insert (reaction), update (reaction) on public.likes to authenticated;
create policy veyro_update_own_reaction on public.likes for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
-- Computed fields keep the payload bounded to six totals and don't depend
-- on enabling new PostgREST aggregate syntax for the entire deployment.
create function public.veyro_reaction_counts(p public.posts) returns jsonb
  language sql stable security invoker set search_path = ''
as $$
  select coalesce(jsonb_object_agg(t.reaction, t.total), '{}'::jsonb)
  from (
    select l.reaction, count(*) as total
    from public.likes l where l.post_id = p.id group by l.reaction
  ) t;
$$;
create function public.veyro_reaction_counts(p public.veyro_following_feed) returns jsonb
  language sql stable security invoker set search_path = ''
as $$
  select coalesce(jsonb_object_agg(t.reaction, t.total), '{}'::jsonb)
  from (
    select l.reaction, count(*) as total
    from public.likes l where l.post_id = p.id group by l.reaction
  ) t;
$$;
revoke all on function public.veyro_reaction_counts(public.posts),
  public.veyro_reaction_counts(public.veyro_following_feed) from public;
grant execute on function public.veyro_reaction_counts(public.posts) to anon, authenticated;
grant execute on function public.veyro_reaction_counts(public.veyro_following_feed) to authenticated;

create function public.veyro_react(p_post_id uuid, p_reaction text) returns void
  language sql security invoker set search_path = ''
as $$
  insert into public.likes (post_id, user_id, reaction)
    values (p_post_id, (select auth.uid()), p_reaction)
    on conflict (post_id, user_id) do update set reaction = excluded.reaction;
$$;
revoke all on function public.veyro_react(uuid, text) from public, anon;
grant execute on function public.veyro_react(uuid, text) to authenticated;

create or replace function public.veyro_notify_social_activity() returns trigger
  language plpgsql security definer set search_path = ''
as $$
declare
  recipient uuid;
  actor uuid;
  related uuid;
  kind text;
  summary text;
begin
  if tg_table_schema <> 'public' then return new; end if;
  case tg_table_name
    when 'followers' then
      recipient := new.following_id;
      actor := new.follower_id;
      related := actor;
      kind := 'follow';
      summary := 'followed you.';
    when 'likes', 'comments' then
      select p.author_id into recipient from public.posts p where p.id = new.post_id;
      actor := new.user_id;
      related := new.post_id;
      kind := case when tg_table_name = 'likes' then 'like' else 'comment' end;
      summary := case when kind = 'like' then 'reacted to your post.' else 'commented on your post.' end;
    else return new;
  end case;
  if recipient is null or actor is null or recipient = actor then return new; end if;
  if exists (select 1 from public.settings s where s.user_id = recipient and s.notifications_enabled = false)
    then return new;
  end if;
  -- Likes/follows uniquely identify an edge; toggling the same edge must not
  -- fill the recipient’s inbox. Distinct comments still produce activity.
  if kind <> 'comment' and exists (
    select 1 from public.notifications n
    where n.user_id = recipient and n.actor_id = actor
      and n.type = kind and n.resource_id = related
  ) then return new; end if;
  insert into public.notifications (user_id, actor_id, type, resource_id, message)
    values (recipient, actor, kind, related, summary);
  return new;
end;
$$;

notify pgrst, 'reload schema';
