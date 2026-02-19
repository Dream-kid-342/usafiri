-- ====================================================
-- PERMGUARD FULL APPLICATION SQL SCHEMA
-- ====================================================
-- This file contains all tables, functions, policies, 
-- and triggers for the production system.

-- 1. EXTENSIONS
create extension if not exists "pgcrypto";

-- 2. TABLES

-- USERS TABLE
create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique,
  phone text,
  role text default 'client',
  device_id text,
  trial_started_at timestamp,
  trial_expires_at timestamp,
  subscription_status text default 'none',
  subscription_expires_at timestamp,
  created_at timestamp default now()
);

alter table public.users enable row level security;

-- SUBSCRIPTIONS TABLE
create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  amount numeric,
  status text,
  mpesa_receipt text,
  created_at timestamp default now(),
  expires_at timestamp
);

alter table public.subscriptions enable row level security;

-- PAYMENTS TABLE
create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  amount numeric,
  phone text,
  status text default 'pending', -- 'pending', 'completed', 'failed', 'cancelled'
  checkout_request_id text,
  merchant_request_id text,
  mpesa_receipt text,
  result_desc text,
  callback_response jsonb,
  transaction_date timestamp,
  created_at timestamp default now(),
  updated_at timestamp default now()
);

alter table public.payments enable row level security;

-- PAYMENT PLANS TABLE
create table if not exists public.payment_plans (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  price numeric not null,
  duration_days integer default 30,
  features jsonb default '[]'::jsonb,
  is_active boolean default true,
  created_at timestamp default now()
);

alter table public.payment_plans enable row level security;

-- ADMIN LOGS TABLE
create table if not exists public.admin_logs (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references public.users(id),
  action text,
  target_user uuid,
  created_at timestamp default now()
);

alter table public.admin_logs enable row level security;

-- ERROR LOGS TABLE
create table if not exists public.error_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  error_message text,
  stack_trace text,
  context text,
  created_at timestamp default now()
);

alter table public.error_logs enable row level security;

-- 3. INDICES
create index if not exists idx_payments_user_id on public.payments(user_id);
create index if not exists idx_payments_checkout_request_id on public.payments(checkout_request_id);
create index if not exists idx_payments_phone on public.payments(phone);

-- 4. FUNCTIONS

-- Helper function: Cache-safe admin check
create or replace function public.is_admin()
returns boolean as $$
begin
  return exists (
    select 1 from public.users
    where id = auth.uid() and role = 'admin'
  );
end;
$$ language plpgsql security definer;

-- Trigger function: Auto-create public.users profile
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, email, role, phone)
  values (
    new.id, 
    new.email, 
    'client',
    new.raw_user_meta_data->>'phone'
  );
  return new;
end;
$$ language plpgsql security definer;

-- M-Pesa Callback Handler (Refined)
create or replace function public.handle_mpesa_callback(
  p_checkout_request_id text,
  p_status text,
  p_receipt text,
  p_result_desc text,
  p_callback_response jsonb,
  p_transaction_date timestamp
)
returns void as $$
declare
  v_user_id uuid;
  v_amount numeric;
  v_existing_status text;
begin
  -- 1. Fetch existing payment details
  select user_id, amount, status 
  into v_user_id, v_amount, v_existing_status
  from public.payments
  where checkout_request_id = p_checkout_request_id;

  -- 2. Exit if payment not found
  if v_user_id is null then
    raise notice 'Payment not found for CheckoutRequestID: %', p_checkout_request_id;
    return;
  end if;

  -- 3. Prevent overwriting 'completed' status
  if v_existing_status = 'completed' then
    return;
  end if;

  -- 4. Update the payment record
  update public.payments
  set 
    status = p_status,
    mpesa_receipt = p_receipt,
    result_desc = p_result_desc,
    callback_response = p_callback_response,
    transaction_date = p_transaction_date,
    updated_at = now()
  where checkout_request_id = p_checkout_request_id;
  
  -- 5. If payment successful, activate subscription
  if p_status = 'completed' then
    update public.users
    set 
      subscription_status = 'active',
      subscription_expires_at = now() + interval '30 days',
      trial_started_at = coalesce(trial_started_at, now())
    where id = v_user_id;

    insert into public.subscriptions (user_id, amount, status, mpesa_receipt, expires_at)
    values (v_user_id, v_amount, 'active', p_receipt, now() + interval '30 days');
    
    insert into public.admin_logs (admin_id, action, target_user)
    values (v_user_id, 'SYSTEM_AUTO_ACTIVATION: ' || p_receipt, v_user_id);
  end if;
end;
$$ language plpgsql security definer;

-- 5. POLICIES

-- Users table policies
do $$ begin
  create policy "Users can view own data" on public.users for select using (auth.uid() = id);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "Users can insert own data" on public.users for insert with check (auth.uid() = id);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "Users can update own data" on public.users for update using (auth.uid() = id);
exception when duplicate_object then then null; end $$;

do $$ begin
  create policy "Admins can view all users" on public.users for select using (public.is_admin());
exception when duplicate_object then null; end $$;

-- Subscriptions table policies
do $$ begin
  create policy "Users can view own subscriptions" on public.subscriptions for select using (auth.uid() = user_id);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "Users can create subscription" on public.subscriptions for insert with check (auth.uid() = user_id);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "Admins full access subscriptions" on public.subscriptions for all using (public.is_admin());
exception when duplicate_object then null; end $$;

-- Payments table policies
do $$ begin
  create policy "Users can view own payments" on public.payments for select using (auth.uid() = user_id);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "Users can insert own payments" on public.payments for insert with check (auth.uid() = user_id);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "Admins full access payments" on public.payments for all using (public.is_admin());
exception when duplicate_object then null; end $$;

-- Error Logs policies
do $$ begin
  create policy "Users can insert own error logs" on public.error_logs for insert with check (true);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "Admins can view all error logs" on public.error_logs for select using (public.is_admin());
exception when duplicate_object then null; end $$;

-- Payment Plans (Public read-only)
do $$ begin
  create policy "Anyone can view active payment plans" on public.payment_plans for select using (is_active = true);
exception when duplicate_object then null; end $$;

-- 6. TRIGGERS
do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'on_auth_user_created') then
    create trigger on_auth_user_created
    after insert on auth.users
    for each row execute procedure public.handle_new_user();
  end if;
end $$;

-- 7. INITIAL SYNC LOGIC
-- Ensures existing auth users have a public profile
insert into public.users (id, email, phone, role)
select 
  id, 
  email, 
  raw_user_meta_data->>'phone',
  'client'
from auth.users
where id not in (select id from public.users)
on conflict (id) do nothing;
