-- Keep shares in the same public, owner-write timeline as ordinary posts.
-- Deleting the original removes the reference but preserves the author's quote.
set local lock_timeout = '5s';

alter table public.posts
  add column shared_post_id uuid references public.posts(id) on delete set null,
  add column share_kind text,
  add constraint veyro_post_share_shape check (
    (share_kind is null and shared_post_id is null)
    or (share_kind is not null and share_kind in ('repost', 'quote')
        and type = 'text' and shared_post_id is distinct from id)
  );
create index veyro_shared_post_lookup on public.posts (shared_post_id)
  where shared_post_id is not null;
create unique index veyro_one_repost_per_user
  on public.posts (author_id, shared_post_id)
  where share_kind = 'repost' and shared_post_id is not null;

-- Append fields so the old APK's RPC type and column order are unchanged.
create or replace view public.veyro_following_feed with (security_invoker = true) as
  select p.id, p.author_id, p.type, p.media_urls, p.description, p.caption,
         p.created_at, null::uuid as user_id, p.shared_post_id, p.share_kind
  from public.posts p
  where p.author_id = (select auth.uid())
     or exists (
       select from public.followers f
       where f.follower_id = (select auth.uid()) and f.following_id = p.author_id
     );

-- A shallow, to-one PostgREST embed for the original. Functions keep post RLS
-- in force, and the Following-specific overload does not grant view access.
create function public.veyro_shared_post(entry public.posts)
  returns setof public.posts rows 1 language sql stable security invoker
  set search_path = ''
as $$ select p.* from public.posts p where p.id = entry.shared_post_id; $$;
create function public.veyro_shared_post(entry public.veyro_following_feed)
  returns setof public.posts rows 1 language sql stable security invoker
  set search_path = ''
as $$ select p.* from public.posts p where p.id = entry.shared_post_id; $$;
revoke all on function public.veyro_shared_post(public.posts) from public, anon;
revoke all on function public.veyro_shared_post(public.veyro_following_feed) from public, anon;
grant execute on function public.veyro_shared_post(public.posts) to authenticated;
grant execute on function public.veyro_shared_post(public.veyro_following_feed) to authenticated;

notify pgrst, 'reload schema';
