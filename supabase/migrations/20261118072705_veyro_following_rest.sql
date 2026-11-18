-- The old APK sends embedded viewer filters to /rpc/veyro_following_posts.
-- PostgREST 14 also projects the embedded user_id filter onto the RPC result
-- (pgrst_call.user_id). Preserve that contract with a harmless compatibility
-- column on the view's row type, without changing the posts table.
set local lock_timeout = '5s';

create view public.veyro_following_feed with (security_invoker = true) as
  select p.id, p.author_id, p.type, p.media_urls, p.description, p.caption,
         p.created_at, null::uuid as user_id
  from public.posts p
  where p.author_id = (select auth.uid())
     or exists (
       select from public.followers f
       where f.follower_id = (select auth.uid()) and f.following_id = p.author_id
     );

revoke all on public.veyro_following_feed from public, anon, authenticated;
grant select on public.veyro_following_feed to authenticated;

drop function public.veyro_following_posts();
create function public.veyro_following_posts() returns setof public.veyro_following_feed
  language sql stable security invoker set search_path = ''
as $$ select * from public.veyro_following_feed; $$;
revoke all on function public.veyro_following_posts() from public, anon;
grant execute on function public.veyro_following_posts() to authenticated;

notify pgrst, 'reload schema';
