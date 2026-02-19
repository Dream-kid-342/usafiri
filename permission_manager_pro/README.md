# Permission Manager Pro

A production-ready Flutter Android application with a Client/Admin split, Supabase backend, Role-Based Access Control (RBAC), and M-Pesa payment integration.

## Features

- **Authentication**: Supabase Email/Password Auth with role-based redirection.
- **Client Features**: Dashboard, Subscription Tracking, M-Pesa Integration.
- **Admin Features**: Dashboard with user statistics and management.
- **Security**: Row Level Security (RLS) policies for strict data access control.

## Prerequisites

- Flutter SDK (latest stable)
- Supabase Project

## Setup

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/yourusername/permission_manager_pro.git
    cd permission_manager_pro
    ```

2.  **Supabase Setup**:
    - Run the SQL script in `supabase/schema.sql` in your Supabase SQL Editor.
    - Create a default admin user in Supabase Auth (e.g., `admin@gmail.com`).
    - Deploy the Edge Function in `supabase/functions/mpesa-payment`.

3.  **Environment Variables**:
    - Update `lib/core/supabase_client.dart` with your Supabase URL and Anon Key.
    - Update Edge Function secrets for M-Pesa (Daraja) credentials.

4.  **Run the App**:
    ```bash
    flutter pub get
    flutter run
    ```

## Architecture

The project follows Clean Architecture principles:
- `lib/core`: Shared utilities and configuration.
- `lib/features`: Feature-based modules (Auth, Client, Admin, Payment).
  - `repository`: Data layer (Supabase interaction).
  - `provider`: State management (Riverpod).
  - `dashboard`: UI layer.

## Testing

Run tests using:
```bash
flutter test
```
