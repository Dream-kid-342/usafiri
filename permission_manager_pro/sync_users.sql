-- ====================================================
-- SYNC MISSING USER PROFILES
-- ====================================================
-- This script ensures that any user in auth.users 
-- has a corresponding record in public.users.
-- This is critical for foreign key constraints in payments.

insert into public.users (id, email, phone, role)
select 
  id, 
  email, 
  raw_user_meta_data->>'phone',
  'client'
from auth.users
where id not in (select id from public.users)
on conflict (id) do nothing;

-- Also, ensure RLS for payments is permissive enough for initiates
do $$
begin
    if not exists (
        select 1 from pg_policies 
        where tablename = 'payments' and policyname = 'Users can insert own payments'
    ) then
        create policy "Users can insert own payments"
        on public.payments
        for insert
        with check (auth.uid() = user_id);
    end if;
end $$;
