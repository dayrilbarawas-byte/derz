-- DERIL SOCIAL initial schema. Run in Supabase SQL Editor.
create extension if not exists pgcrypto;
create table public.profiles(
 id uuid primary key references auth.users(id) on delete cascade,
 username text unique not null check(char_length(username) between 3 and 30),
 display_name text, bio text default '', avatar_url text, website text,
 is_private boolean not null default false, created_at timestamptz not null default now()
);
create table public.posts(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 caption text, created_at timestamptz not null default now()
);
create table public.post_media(
 id uuid primary key default gen_random_uuid(),
 post_id uuid not null references public.posts(id) on delete cascade,
 media_url text not null, media_type text not null check(media_type in ('image','video')),
 sort_order int not null default 0
);
create table public.likes(
 post_id uuid references public.posts(id) on delete cascade,
 user_id uuid references public.profiles(id) on delete cascade,
 created_at timestamptz default now(), primary key(post_id,user_id)
);
create table public.comments(
 id uuid primary key default gen_random_uuid(),
 post_id uuid not null references public.posts(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 body text not null check(char_length(body) between 1 and 2000),
 parent_id uuid references public.comments(id) on delete cascade,
 created_at timestamptz not null default now()
);
create table public.follows(
 follower_id uuid references public.profiles(id) on delete cascade,
 following_id uuid references public.profiles(id) on delete cascade,
 created_at timestamptz default now(), primary key(follower_id,following_id),
 check(follower_id <> following_id)
);
create table public.follow_requests(
 requester_id uuid references public.profiles(id) on delete cascade,
 target_id uuid references public.profiles(id) on delete cascade,
 created_at timestamptz default now(), primary key(requester_id,target_id),
 check(requester_id <> target_id)
);
create table public.saved_posts(
 user_id uuid references public.profiles(id) on delete cascade,
 post_id uuid references public.posts(id) on delete cascade,
 created_at timestamptz default now(), primary key(user_id,post_id)
);
create table public.conversations(id uuid primary key default gen_random_uuid(),is_group boolean not null default false,created_at timestamptz default now());
create table public.conversation_members(
 conversation_id uuid references public.conversations(id) on delete cascade,
 user_id uuid references public.profiles(id) on delete cascade,
 joined_at timestamptz default now(), primary key(conversation_id,user_id)
);
create table public.messages(
 id uuid primary key default gen_random_uuid(),
 conversation_id uuid not null references public.conversations(id) on delete cascade,
 sender_id uuid not null references public.profiles(id) on delete cascade,
 body text, media_url text, created_at timestamptz not null default now(), read_at timestamptz,
 check(body is not null or media_url is not null)
);
create table public.notifications(
 id uuid primary key default gen_random_uuid(),
 recipient_id uuid not null references public.profiles(id) on delete cascade,
 actor_id uuid references public.profiles(id) on delete set null,
 kind text not null, entity_id uuid, created_at timestamptz default now(), read_at timestamptz
);
create table public.stories(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id) on delete cascade,
 media_url text not null,media_type text not null check(media_type in ('image','video')),
 created_at timestamptz default now(),expires_at timestamptz not null default now()+interval '24 hours'
);
create table public.story_views(
 story_id uuid references public.stories(id) on delete cascade,
 viewer_id uuid references public.profiles(id) on delete cascade,
 viewed_at timestamptz default now(),primary key(story_id,viewer_id)
);
create table public.hashtags(id uuid primary key default gen_random_uuid(),tag text unique not null);
create table public.post_hashtags(post_id uuid references public.posts(id) on delete cascade,hashtag_id uuid references public.hashtags(id) on delete cascade,primary key(post_id,hashtag_id));
create table public.blocks(blocker_id uuid references public.profiles(id) on delete cascade,blocked_id uuid references public.profiles(id) on delete cascade,created_at timestamptz default now(),primary key(blocker_id,blocked_id),check(blocker_id<>blocked_id));
create table public.reports(id uuid primary key default gen_random_uuid(),reporter_id uuid references public.profiles(id) on delete cascade,target_user_id uuid references public.profiles(id) on delete cascade,post_id uuid references public.posts(id) on delete cascade,reason text not null,details text,created_at timestamptz default now());
create table public.calls(id uuid primary key default gen_random_uuid(),conversation_id uuid references public.conversations(id) on delete cascade,initiator_id uuid references public.profiles(id),status text not null default 'ringing',call_type text not null check(call_type in ('audio','video')),started_at timestamptz default now(),ended_at timestamptz);
create index posts_created_idx on public.posts(created_at desc);
create index messages_conversation_idx on public.messages(conversation_id,created_at desc);
create index stories_expiry_idx on public.stories(expires_at);
-- Auto-create profile after signup; username is supplied in auth metadata.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,username,display_name)
 values(new.id,coalesce(new.raw_user_meta_data->>'username','user_'||substr(new.id::text,1,8)),coalesce(new.raw_user_meta_data->>'username',''));
 return new;
end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.post_media enable row level security;
alter table public.likes enable row level security;
alter table public.comments enable row level security;
alter table public.follows enable row level security;
alter table public.follow_requests enable row level security;
alter table public.saved_posts enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
alter table public.notifications enable row level security;
alter table public.stories enable row level security;
alter table public.story_views enable row level security;
alter table public.blocks enable row level security;
alter table public.reports enable row level security;
alter table public.calls enable row level security;
-- Public profiles and public posts; writes restricted to owner.
create policy "profiles readable" on public.profiles for select using(true);
create policy "profile owner update" on public.profiles for update using(auth.uid()=id) with check(auth.uid()=id);
create policy "posts readable" on public.posts for select using(true);
create policy "post owner insert" on public.posts for insert with check(auth.uid()=user_id);
create policy "post owner delete" on public.posts for delete using(auth.uid()=user_id);
create policy "media readable" on public.post_media for select using(true);
create policy "media owner insert" on public.post_media for insert with check(exists(select 1 from public.posts p where p.id=post_id and p.user_id=auth.uid()));
create policy "media owner delete" on public.post_media for delete using(exists(select 1 from public.posts p where p.id=post_id and p.user_id=auth.uid()));
create policy "likes readable" on public.likes for select using(true);
create policy "like as self" on public.likes for insert with check(auth.uid()=user_id);
create policy "unlike self" on public.likes for delete using(auth.uid()=user_id);
create policy "comments readable" on public.comments for select using(true);
create policy "comment as self" on public.comments for insert with check(auth.uid()=user_id);
create policy "comment owner delete" on public.comments for delete using(auth.uid()=user_id);
create policy "follows readable" on public.follows for select using(true);
create policy "follow as self" on public.follows for insert with check(auth.uid()=follower_id);
create policy "unfollow self" on public.follows for delete using(auth.uid()=follower_id);
create policy "requests participants read" on public.follow_requests for select using(auth.uid() in (requester_id,target_id));
create policy "request as self" on public.follow_requests for insert with check(auth.uid()=requester_id);
create policy "request participants delete" on public.follow_requests for delete using(auth.uid() in (requester_id,target_id));
create policy "saved own" on public.saved_posts for all using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy "conversation member read" on public.conversations for select using(exists(select 1 from public.conversation_members m where m.conversation_id=id and m.user_id=auth.uid()));
create policy "member list self" on public.conversation_members for select using(user_id=auth.uid() or exists(select 1 from public.conversation_members x where x.conversation_id=conversation_id and x.user_id=auth.uid()));
create policy "messages member read" on public.messages for select using(exists(select 1 from public.conversation_members m where m.conversation_id=conversation_id and m.user_id=auth.uid()));
create policy "messages member send" on public.messages for insert with check(auth.uid()=sender_id and exists(select 1 from public.conversation_members m where m.conversation_id=conversation_id and m.user_id=auth.uid()));
create policy "notifications recipient" on public.notifications for select using(auth.uid()=recipient_id);
create policy "notifications update recipient" on public.notifications for update using(auth.uid()=recipient_id);
create policy "stories readable active" on public.stories for select using(expires_at>now());
create policy "story owner insert" on public.stories for insert with check(auth.uid()=user_id);
create policy "story owner delete" on public.stories for delete using(auth.uid()=user_id);
create policy "story views participants" on public.story_views for select using(auth.uid()=viewer_id or exists(select 1 from public.stories s where s.id=story_id and s.user_id=auth.uid()));
create policy "story view self" on public.story_views for insert with check(auth.uid()=viewer_id);
create policy "blocks own" on public.blocks for all using(auth.uid()=blocker_id) with check(auth.uid()=blocker_id);
create policy "reports submit own" on public.reports for insert with check(auth.uid()=reporter_id);
create policy "calls member read" on public.calls for select using(exists(select 1 from public.conversation_members m where m.conversation_id=conversation_id and m.user_id=auth.uid()));
-- Storage bucket for user-uploaded post media.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('post-media','post-media',true,52428800,array['image/jpeg','image/png','image/webp','video/mp4','video/webm'])
on conflict(id) do nothing;
create policy "public media read" on storage.objects for select using(bucket_id='post-media');
create policy "upload own folder" on storage.objects for insert to authenticated with check(bucket_id='post-media' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "delete own folder" on storage.objects for delete to authenticated using(bucket_id='post-media' and (storage.foldername(name))[1]=auth.uid()::text);
-- Enable Realtime for messages/notifications as needed from Supabase dashboard.
