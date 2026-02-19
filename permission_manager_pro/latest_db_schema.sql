-- =========================
-- EXTENSIONS
-- =========================
create extension if not exists "pgcrypto";

-- =========================
-- USERS TABLE
-- =========================
create table public.users (
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

-- =========================
-- SUBSCRIPTIONS TABLE
-- =========================
create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  amount integer,
  status text,
  mpesa_receipt text,
  created_at timestamp default now(),
  expires_at timestamp
);

alter table public.subscriptions enable row level security;

-- =========================
-- PAYMENTS TABLE
-- =========================
create table public.payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  amount integer,
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

-- =========================
-- PAYMENT PLANS TABLE
-- =========================
create table public.payment_plans (
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

-- Index for faster lookups
create index idx_payments_user_id on public.payments(user_id);
create index idx_payments_checkout_request_id on public.payments(checkout_request_id);
create index idx_payments_phone on public.payments(phone);

-- Function to handle M-Pesa Callback updates
create or replace function public.handle_mpesa_callback(
  p_checkout_request_id text,
  p_status text,
  p_receipt text,
  p_result_desc text,
  p_callback_response jsonb,
  p_transaction_date timestamp
)
returns void as $$
begin
  update public.payments
  set 
    status = p_status,
    mpesa_receipt = p_receipt,
    result_desc = p_result_desc,
    callback_response = p_callback_response,
    transaction_date = p_transaction_date,
    updated_at = now()
  where checkout_request_id = p_checkout_request_id;
  
  -- If payment successful, update or create subscription
  if p_status = 'completed' then
    -- Logic to activate subscription would go here
    -- For now, we trust the payment record
    null;
  end if;
end;
$$ language plpgsql security definer;

-- =========================
-- ADMIN LOGS TABLE
-- =========================
create table public.admin_logs (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references public.users(id),
  action text,
  target_user uuid,
  created_at timestamp default now()
);

alter table public.admin_logs enable row level security;

-- =========================
-- AUTO CREATE USER PROFILE
-- =========================
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

do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'on_auth_user_created') then
    create trigger on_auth_user_created
    after insert on auth.users
    for each row execute procedure public.handle_new_user();
  end if;
end $$;

-- =========================
-- HELPER FUNCTION (ADMIN CHECK)
-- =========================
create or replace function public.is_admin()
returns boolean as $$
begin
  return exists (
    select 1 from public.users
    where id = auth.uid() and role = 'admin'
  );
end;
$$ language plpgsql security definer;

-- =========================
-- RLS POLICIES
-- =========================

-- ===== USERS TABLE =====

-- View own data
create policy "Users can view own data"
on public.users
for select
using (auth.uid() = id);

-- Insert own record (needed!)
create policy "Users can insert own data"
on public.users
for insert
with check (auth.uid() = id);

-- Update own record
create policy "Users can update own data"
on public.users
for update
using (auth.uid() = id);

-- Admin can view all
create policy "Admins can view all users"
on public.users
for select
using (public.is_admin());

-- ===== SUBSCRIPTIONS =====

-- User view own
create policy "Users can view own subscriptions"
on public.subscriptions
for select
using (auth.uid() = user_id);

-- User insert own subscription
create policy "Users can create subscription"
on public.subscriptions
for insert
with check (auth.uid() = user_id);

-- Admin full access
create policy "Admins full access subscriptions"
on public.subscriptions
for all
using (public.is_admin());

-- ===== PAYMENTS =====

-- User view own
create policy "Users can view own payments"
on public.payments
for select
using (auth.uid() = user_id);

-- User insert own payment
create policy "Users can create payment"
on public.payments
for insert
with check (auth.uid() = user_id);

-- Admin full access
create policy "Admins full access payments"
on public.payments
for all
using (public.is_admin());

-- ===== PAYMENT PLANS =====

-- Anyone can view active plans
create policy "Anyone can view active payment plans"
on public.payment_plans
for select
using (is_active = true);

-- Admin full access
create policy "Admins full access payment plans"
on public.payment_plans
for all
using (public.is_admin());

-- ===== ADMIN LOGS =====

-- Only admin can view
create policy "Admins can view logs"
on public.admin_logs
for select
using (public.is_admin());

-- Only admin can insert
create policy "Admins can insert logs"
on public.admin_logs
for insert
with check (public.is_admin());
