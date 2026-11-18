-- Add to the existing Veyro schema without rewriting posts or profile rows.
set local lock_timeout = '5s';

alter table public.posts add constraint veyro_valid_text_post check (
  type <> 'text' or (
    description is not null and description ~ '[^[:space:]]'
    and char_length(description) <= 500
    and coalesce(cardinality(media_urls), 0) = 0
  )
) not valid;

alter table public.comments add constraint veyro_valid_comment check (
  content ~ '[^[:space:]]' and char_length(content) <= 1000
) not valid;

create policy veyro_delete_own_comment on public.comments
  for delete to authenticated using (user_id = (select auth.uid()));
grant delete on public.comments to authenticated;

create index if not exists veyro_posts_author_timeline
  on public.posts (author_id, created_at desc nulls last, id desc);
create index if not exists veyro_posts_latest
  on public.posts (created_at desc nulls last, id desc);
create index if not exists veyro_reels_latest
  on public.posts (created_at desc nulls last, id desc) where type = 'video';
create index if not exists veyro_comments_by_post
  on public.comments (post_id, created_at desc nulls last, id desc);
create index if not exists veyro_notifications_by_recipient
  on public.notifications (user_id, created_at desc nulls last, id desc);

-- Resolves the viewer from the JWT, keeps post RLS in force and returns the
-- posts composite type so the REST API can embed authors/likes/saved rows.
create function public.veyro_following_posts() returns setof public.posts
  language sql stable security invoker set search_path = ''
as $$
  select p.*
  from public.posts p
  where p.author_id = (select auth.uid())
     or p.author_id in (
       select f.following_id from public.followers f
       where f.follower_id = (select auth.uid())
     );
$$;
revoke all on function public.veyro_following_posts() from public, anon;
grant execute on function public.veyro_following_posts() to authenticated;

-- The existing client INSERT revoke and receiver-only RLS stay in place.
-- Recipients and actor IDs come from RLS-checked rows, never a client RPC arg.
create function public.veyro_notify_social_activity() returns trigger
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
      summary := case when kind = 'like' then 'liked your post.' else 'commented on your post.' end;
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
revoke all on function public.veyro_notify_social_activity() from public, anon, authenticated;

create trigger veyro_on_follow after insert on public.followers
  for each row execute function public.veyro_notify_social_activity();
create trigger veyro_on_like after insert on public.likes
  for each row execute function public.veyro_notify_social_activity();
create trigger veyro_on_comment after insert on public.comments
  for each row execute function public.veyro_notify_social_activity();
