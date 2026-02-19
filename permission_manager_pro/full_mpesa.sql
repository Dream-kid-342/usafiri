-- ====================================================
-- M-PESA INTEGRATION CONSOLIDATED SQL
-- ====================================================

-- 1. TABLES
-- Ensure payments and subscriptions tables exist for M-Pesa tracking

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
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

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  amount numeric,
  status text,
  mpesa_receipt text,
  created_at timestamp default now(),
  expires_at timestamp
);

alter table public.subscriptions enable row level security;

create table if not exists public.error_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  error_message text,
  stack_trace text,
  context text,
  created_at timestamp default now()
);

alter table public.error_logs enable row level security;

-- 2. INDICES
create index if not exists idx_payments_checkout_request_id on public.payments(checkout_request_id);
create index if not exists idx_payments_user_id on public.payments(user_id);

-- 3. CALLBACK HANDLER FUNCTION
-- This function is called by the Supabase Edge Function to process M-Pesa notifications

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

  -- 2. Exit and Log if payment not found
  if v_user_id is null then
    insert into public.error_logs (error_message, context)
    values ('Payment record not found for CheckoutRequestID: ' || p_checkout_request_id, 'handle_mpesa_callback');
    return;
  end if;

  -- 3. Prevent overwriting 'completed' status (Idempotency)
  if v_existing_status = 'completed' then
    return;
  end if;

  -- 4. Update the payment record with real-time feedback data
  update public.payments
  set 
    status = p_status,
    mpesa_receipt = p_receipt,
    result_desc = p_result_desc,
    callback_response = p_callback_response,
    transaction_date = p_transaction_date,
    updated_at = now()
  where checkout_request_id = p_checkout_request_id;
  
  -- 5. If payment successful, activate subscription and update user profile
  if p_status = 'completed' then
    -- A. Update user profile
    update public.users
    set 
      subscription_status = 'active',
      subscription_expires_at = now() + interval '30 days',
      trial_started_at = coalesce(trial_started_at, now())
    where id = v_user_id;

    -- B. Insert record into subscriptions table for history
    insert into public.subscriptions (user_id, amount, status, mpesa_receipt, expires_at)
    values (v_user_id, v_amount, 'active', p_receipt, now() + interval '30 days');
  end if;
end;
$$ language plpgsql security definer;

-- 4. RLS POLICIES

-- User can view their own payments
do $$ begin
  create policy "Users can view own payments" on public.payments for select using (auth.uid() = user_id);
exception when duplicate_object then null; end $$;

-- User can create their own payment (for STK Push initiation)
do $$ begin
  create policy "Users can insert own payments" on public.payments for insert with check (auth.uid() = user_id);
exception when duplicate_object then null; end $$;

-- User can view their own subscriptions
do $$ begin
  create policy "Users can view own subscriptions" on public.subscriptions for select using (auth.uid() = user_id);
exception when duplicate_object then null; end $$;

-- Service Role (Edge Function) bypasses RLS via 'security definer' in the function
-- but we ensure admins can see everything
do $$ begin
  create policy "Admins full access payments" on public.payments for all using (
    exists (select 1 from public.users where id = auth.uid() and role = 'admin')
  );
exception when duplicate_object then null; end $$;

-- 5. SYNC EXISTING USERS
-- Ensure all auth users have public.users records so payments don't fail foreign key checks
insert into public.users (id, email, role, phone)
select 
  id, 
  email, 
  'client',
  raw_user_meta_data->>'phone'
from auth.users
where id not in (select id from public.users)
on conflict (id) do nothing;
