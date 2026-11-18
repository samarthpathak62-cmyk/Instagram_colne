-- This is an incremental migration for the existing Veyro Social Platform schema.
set local lock_timeout = '5s';

-- Keep public social data readable without publishing email addresses to clients.
alter table public.users add column if not exists full_name text;
revoke select, update on table public.users from public, anon, authenticated;
grant select (id, username, full_name, bio, profile_picture_url, followers_count,
              following_count, posts_count, created_at)
  on public.users to anon, authenticated;
grant update (username, full_name, bio, profile_picture_url)
  on public.users to authenticated;

-- Preserve the auth-to-profile trigger. A duplicate display handle must not
-- prevent signup; that user can pick another handle from Edit Profile.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.email is null then
    return new;
  end if;

  insert into public.users (id, email, username, full_name)
  values (
    new.id, new.email,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'username'), ''), split_part(new.email, '@', 1)),
    nullif(trim(new.raw_user_meta_data ->> 'full_name'), '')
  )
  on conflict (username) do nothing;

  if not found then
    insert into public.users (id, email, full_name)
    values (new.id, new.email, nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''));
  end if;
  return new;
end;
$$;

-- These buckets serve media for the existing public posts, stories and profiles.
-- Uploads and deletions are limited to the authenticated owner's own folder.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('profile-images', 'profile-images', true, 5242880,
   array['image/jpeg','image/png','image/webp','image/gif','image/heic','image/heif']),
  ('post-media', 'post-media', true, 52428800,
   array['image/jpeg','image/png','image/webp','image/gif','image/heic','image/heif',
         'video/mp4','video/quicktime','video/webm','video/3gpp']),
  ('story-media', 'story-media', true, 52428800,
   array['image/jpeg','image/png','image/webp','image/gif','image/heic','image/heif',
         'video/mp4','video/quicktime','video/webm','video/3gpp'])
on conflict (id) do nothing;

create policy veyro_media_insert_own on storage.objects for insert to authenticated
  with check (bucket_id in ('profile-images','post-media','story-media')
    and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy veyro_media_select_own on storage.objects for select to authenticated
  using (bucket_id in ('profile-images','post-media','story-media')
    and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy veyro_media_delete_own on storage.objects for delete to authenticated
  using (bucket_id in ('profile-images','post-media','story-media')
    and (storage.foldername(name))[1] = (select auth.uid())::text);

create table public.settings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users(id) on delete cascade,
  theme_mode text not null default 'system' check (theme_mode in ('system','light','dark')),
  language text not null default 'en',
  notifications_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.settings enable row level security;
revoke all on table public.settings from public, anon, authenticated;
grant select, insert, update on public.settings to authenticated;
create policy veyro_settings_own on public.settings for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy veyro_stories_insert_own on public.stories for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy veyro_story_items_insert_own on public.story_items for insert to authenticated
  with check (exists (select 1 from public.stories s
    where s.id = story_id and s.user_id = (select auth.uid())));

-- Create the story and its first item together; a failed insert leaves no blank story.
create function public.veyro_add_story_item(p_media_url text, p_media_type text)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  story uuid;
begin
  if p_media_type is null or p_media_type not in ('image','video') then
    raise exception 'Unsupported story media type';
  end if;
  insert into public.stories (user_id) values (auth.uid()) returning id into story;
  insert into public.story_items (story_id, media_url, media_type)
    values (story, p_media_url, p_media_type);
end;
$$;
revoke execute on function public.veyro_add_story_item(text, text) from public, anon;
grant execute on function public.veyro_add_story_item(text, text) to authenticated;

-- Messages remain visible only to their two participants. The recipient can
-- mark them read but cannot change the sender, destination or message text.
create policy veyro_chats_insert_participant on public.chats for insert to authenticated
  with check (user1_id <> user2_id and (select auth.uid()) in (user1_id, user2_id));
alter policy "Users can send messages" on public.messages to authenticated
  with check (sender_id = (select auth.uid()) and is_read is false and exists (
    select 1 from public.chats c where c.id = chat_id and
      ((c.user1_id = sender_id and c.user2_id = receiver_id) or
       (c.user2_id = sender_id and c.user1_id = receiver_id))
  ));
revoke update on table public.messages from public, anon, authenticated;
grant update (is_read) on public.messages to authenticated;
create policy veyro_messages_mark_own_read on public.messages for update to authenticated
  using (receiver_id = (select auth.uid()))
  with check (receiver_id = (select auth.uid()) and is_read = true);

create function public.veyro_refresh_chat_after_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.chats c set
    last_message_time = greatest(c.last_message_time, new.timestamp),
    has_unread_messages = exists (
      select 1 from public.messages m where m.chat_id = c.id and m.is_read is not true
    )
  where c.id = new.chat_id;
  return new;
end;
$$;
revoke execute on function public.veyro_refresh_chat_after_message() from public, anon, authenticated;
create trigger veyro_refresh_chat_after_message
  after insert or update of is_read on public.messages
  for each row execute function public.veyro_refresh_chat_after_message();

revoke insert, update on table public.notifications from public, anon, authenticated;
grant update (is_read) on public.notifications to authenticated;
create policy veyro_notifications_mark_own_read on public.notifications for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()) and is_read = true);
create policy veyro_notifications_delete_own on public.notifications for delete to authenticated
  using (user_id = (select auth.uid()));

alter publication supabase_realtime add table public.chats, public.messages, public.notifications;
