-- Ensure admin@gmail.com has the 'admin' role in user_metadata
UPDATE auth.users
SET raw_user_meta_data = 
  CASE 
    WHEN raw_user_meta_data IS NULL THEN '{"role": "admin"}'::jsonb
    ELSE raw_user_meta_data || '{"role": "admin"}'::jsonb
  END
WHERE email = 'admin@gmail.com';

-- Verify the update
SELECT email, raw_user_meta_data FROM auth.users WHERE email = 'admin@gmail.com';
