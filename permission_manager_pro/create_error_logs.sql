-- Create error_logs table for production debugging
create table if not exists public.error_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  error_message text,
  stack_trace text,
  context text,
  created_at timestamp default now()
);

-- Enable RLS
alter table public.error_logs enable row level security;

-- Policy for users to insert their own logs
create policy "Users can insert own error logs"
on public.error_logs
for insert
with check (true); -- Allow anonymous/authenticated for better coverage

-- Policy for admins to view all logs
create policy "Admins can view all error logs"
on public.error_logs
for select
using (exists (
    select 1 from public.users
    where id = auth.uid() and role = 'admin'
));
