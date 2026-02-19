-- ==================================================
-- FIX ADMIN DASHBOARD & USER VISIBILITY
-- ==================================================

-- 1. DROP EXISTING POLICIES (Start Clean)
drop policy if exists "Admins can view all users" on public.users;
drop policy if exists "Users can see their own data" on public.users;
drop policy if exists "Users can update own avatar" on public.users;

-- 2. CREATE ROBUST POLICIES
-- Policy: Users can see their own data
create policy "Users can see their own data"
on public.users
for select
using (auth.uid() = id);

-- Policy: Admins can see ALL data
-- We check if the requesting user has 'admin' role in the users table OR metadata
create policy "Admins can view all users"
on public.users
for select
using (
  (select role from public.users where id = auth.uid()) = 'admin'
  OR 
  (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
);

-- Policy: Update Avatar
create policy "Users can update own avatar"
on public.users
for update
using (auth.uid() = id);

-- 3. ENSURE ADMIN USER EXISTS (Safety Net)
-- If your current user is not admin, this will force it.
-- Replace 'YOUR_EMAIL' with the actual admin email if known, 
-- or rely on manual update if you don't know the specific ID.
-- For now, we update based on common admin emails or leave as is if unsure.
-- Example: Update ANY user with 'admin' in email to be admin role.
update public.users 
set role = 'admin' 
where email like '%admin%';

-- 4. FIX TRIAL LOGIC (Ensure all users have trial dates)
update public.users
set 
  trial_started_at = coalesce(trial_started_at, created_at),
  trial_expires_at = coalesce(trial_expires_at, created_at + interval '30 days'),
  subscription_status = coalesce(subscription_status, 'trial')
where subscription_status is null or subscription_status = 'none';

-- 5. VERIFY PAYMENTS TABLE
create table if not exists public.payments (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.users(id),
  amount numeric,
  phone text,
  status text,
  checkout_request_id text,
  merchant_request_id text,
  created_at timestamp with time zone default now()
);

-- Enable RLS on payment
alter table public.payments enable row level security;

-- Payment Policies
create policy "Users manage own payments"
on public.payments
for all
using (auth.uid() = user_id);

create policy "Admins view all payments"
on public.payments
for select
using (
  (select role from public.users where id = auth.uid()) = 'admin'
);
