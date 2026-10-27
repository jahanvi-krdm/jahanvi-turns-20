-- Anyone with the website link can read notes and add new ones (no sign-in).
-- Nobody can edit or delete through the website; Jahanvi removes notes in Table Editor.

create table if not exists public.wishes (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  name text check (name is null or char_length(name) <= 60),
  message text not null default '' check (char_length(message) <= 1200),
  sticker text check (sticker in ('daisy', 'tulip', 'ball', 'flame', 'heart')),
  photo_path text check (photo_path is null or photo_path ~ '^[A-Za-z0-9._-]{1,120}$')
);

alter table public.wishes enable row level security;

drop policy if exists "anyone can read wishes" on public.wishes;
create policy "anyone can read wishes" on public.wishes
  for select to anon, authenticated using (true);

drop policy if exists "anyone can add a wish" on public.wishes;
create policy "anyone can add a wish" on public.wishes
  for insert to anon, authenticated with check (true);

-- live updates on the wall
do $$ begin
  alter publication supabase_realtime add table public.wishes;
exception when duplicate_object then null;
end $$;

-- public photo bucket, images only, 10 MB max
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', true, 10485760,
        array['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic', 'image/heif'])
on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "anyone can upload a photo" on storage.objects;
create policy "anyone can upload a photo" on storage.objects
  for insert to anon, authenticated with check (bucket_id = 'photos');
