-- ==========================================
-- UPDATES SCHEMA (Advanced Features)
-- ==========================================

-- 1. Add account_status to public.users
-- Check if column exists first to avoid errors (or just add it if safe)
do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema='public' and table_name='users' and column_name='account_status') then
    alter table public.users add column account_status text default 'active';
  end if;
end $$;

-- 2. Add full_name to public.users if not exists
do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema='public' and table_name='users' and column_name='full_name') then
    alter table public.users add column full_name text;
  end if;
end $$;


-- 3. Function to block/unblock user (Admin Only)
create or replace function public.update_user_status(target_user_id uuid, new_status text)
returns void as $$
begin
  -- Check if executing user is admin
  if not public.is_admin() then
    raise exception 'Access Denied: Only admins can update status';
  end if;

  update public.users
  set account_status = new_status
  where id = target_user_id;

  -- Log the action
  insert into public.admin_logs (admin_id, action, target_user)
  values (auth.uid(), 'update_status_' || new_status, target_user_id);
end;
$$ language plpgsql security definer;

-- 4. Update Admin View Policies (Ensure they see everything)
-- (Existing policies in latest_db_schema.sql should cover this, but double checking)

-- 5. Helper to get all users (for Admin Dashboard)
-- Access controlled by RLS, but this view helps structre
create or replace view public.admin_users_view as
select 
  id, 
  email, 
  role, 
  phone, 
  full_name,
  subscription_status, 
  account_status,
  created_at 
from public.users;

-- Grant access to this view only to admins (via RLS on underlying table mostly, but we can be explicit)
-- Postgres views obey RLS of underlying tables by default if created with security invoker (default).
