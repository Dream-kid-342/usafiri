-- =========================
-- FEATURE BUNDLE UPDATE
-- =========================

-- 1. ADD AVATAR URL TO USERS
alter table public.users add column if not exists avatar_url text;

-- 2. CREATE AVATARS BUCKET
insert into storage.buckets (id, name, public) 
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy "Avatar images are publicly accessible."
  on storage.objects for select
  using ( bucket_id = 'avatars' );

create policy "Anyone can upload an avatar."
  on storage.objects for insert
  with check ( bucket_id = 'avatars' );
  
create policy "Anyone can update an avatar."
  on storage.objects for update
  with check ( bucket_id = 'avatars' );

-- 3. UPDATE NEW USER TRIGGER FOR 30-DAY TRIAL
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, email, role, phone, trial_started_at, trial_expires_at, subscription_status)
  values (
    new.id, 
    new.email, 
    'client',
    new.raw_user_meta_data->>'phone',
    now(),
    now() + interval '30 days',
    'trial'
  );
  return new;
end;
$$ language plpgsql security definer;

-- 4. FIX ADMIN VISIBILITY (RLS)
-- Drop existing restrictive policies and re-create better ones
drop policy if exists "Admins can view all users" on public.users;

create policy "Admins can view all users"
on public.users
for select
using (
  (select role from public.users where id = auth.uid()) = 'admin'
);

-- Ensure users can update their own avatar_url
create policy "Users can update own avatar"
on public.users
for update
using (auth.uid() = id);

-- 5. UPDATE SUBSCRIPTION PRICE (Optional specific data fix)
-- Update subscription checks if needed, but handled in code mainly.
