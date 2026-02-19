# PermGuard (Permission Manager Pro)

PermGuard is a robust Flutter-based application designed for advanced Android permission management, featuring Shizuku native integration and a production-ready M-Pesa payment system.

## 🚀 Key Features

- **Advanced Permission Control**: Leverage Shizuku for deep system-level permission management without root.
- **Real-time Monitoring**: Track app usage statistics and permission states dynamically.
- **Overlay Protection**: Secure UI overlays to prevent tapjacking and unauthorized permission grants.
- **M-Pesa Payment System**: 
  - Integrated STK Push for seamless subscription activation.
  - Automatic trial and premium activation via Supabase Edge Functions.
  - Real-time payment verification with a 15-second secure timeout.
- **Cloud Infrastructure**: Powered by Supabase for secure Authentication, Real-time Database, and Edge Functions.

## 🛠 Tech Stack

- **Frontend**: Flutter (3.9.0+)
- **State Management**: Riverpod
- **Backend**: Supabase (Auth, PostgreSQL, Realtime, Edge Functions)
- **Native Integration**: Shizuku API
- **Payments**: Safaricom M-Pesa API (Integrated via Edge Functions)

## 📦 Prerequisites

- Flutter SDK ^3.9.0
- Android SDK (minSdk 26)
- Supabase Project (with Edge Functions enabled)
- Safaricom M-Pesa Developer Account

## ⚙️ Setup Instructions

### 1. Database Setup
Run the consolidated SQL scripts in your Supabase SQL Editor:
- [full_app.sql](./full_app.sql): Sets up the entire database schema, RLS policies, and triggers.

### 2. Edge Functions
Deploy the M-Pesa callback handler:
```bash
npx supabase functions deploy mpesa-callback --no-verify-jwt
```

### 3. Environment Configuration
Create a `.env` file in the root directory using [env-example](../env-example) as a template:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `MPESA_CALLBACK_URL`
- `MPESA_ENVIRONMENT` (sandbox/production)

### 4. Running the App
Use the provided scripts for reliable builds on Windows:
- **Build and Run**: `bash arun.sh`
- **Fast Run (Existing Build)**: `bash run.sh`

## 🛡 Security & RLS

PermGuard implements strict Row Level Security (RLS) on all tables:
- **Users**: Can only view and update their own profile.
- **Payments**: Users can initiate payments, while the backend (Edge Function) handles secure updates via Service Role.
- **Error Logs**: System-wide error auditing for payment and sync failures.

## 🐞 Support & Debugging

If you encounter issues during payment or user sync:
1. Check the `public.error_logs` table in Supabase.
2. Monitor the terminal for `DATABASE ERROR` or `Payment session timed out` logs.
3. Verify that Shizuku is running on your target device for native functionality.
