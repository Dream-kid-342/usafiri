-- ==========================================
-- PRODUCTION-READY M-PESA CALLBACK HANDLER
-- ==========================================
-- Ensures reliable state updates and subscription activation.

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

  -- 2. Exit if payment not found (shouldn't happen with correct request sequence)
  if v_user_id is null then
    raise notice 'Payment not found for CheckoutRequestID: %', p_checkout_request_id;
    return;
  end if;

  -- 3. Prevent overwriting 'completed' status (Idempotency)
  if v_existing_status = 'completed' then
    raise notice 'Payment % already marked as completed. Skipping.', p_checkout_request_id;
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
    
    -- C. Log system activation
    insert into public.admin_logs (admin_id, action, target_user)
    values (v_user_id, 'SYSTEM_AUTO_ACTIVATION: ' || p_receipt, v_user_id);
  end if;
end;
$$ language plpgsql security definer;
