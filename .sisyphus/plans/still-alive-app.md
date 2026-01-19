# Implementation Plan: Still Alive (Dead Man's Switch App)

This plan outlines the step-by-step implementation of the "Still Alive" Flutter application using Supabase as the backend.

## Project Overview
- **Goal**: A cross-platform safety app where users check in periodically. Failure to check in triggers automated SMS alerts to emergency contacts.
- **Backend**: Supabase (PostgreSQL, Auth, Edge Functions, Cron).
- **Frontend**: Flutter (Android/iOS).

---

## Phase 0: Supabase Project Setup (Manual Steps)

### 0.1. Create Supabase Project
1. Go to [database.new](https://database.new) and create a new project.
2. Note your **Project URL** and **API Keys** (anon public, service_role).
   - Go to `Settings` > `API` to find these.

### 0.2. Database Schema Setup
Run the following SQL in the Supabase **SQL Editor** to create all necessary tables, security policies, and indexes.

```sql
-- Enable necessary extensions
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- 1. PROFILES (Extends auth.users)
create table public.profiles (
  id uuid references auth.users(id) on delete cascade not null primary key,
  email text,
  full_name text,
  avatar_url text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 2. USER SETTINGS
create table public.user_settings (
  user_id uuid references public.profiles(id) on delete cascade not null primary key,
  check_in_interval_hours int default 48, -- Default 2 days
  alert_message text default '🚨 STILL ALIVE ALERT: {user_name} has not checked in for {interval} hours. This is an automated safety alert. Please try to contact them.',
  last_check_in timestamptz default now(),
  next_check_in_deadline timestamptz generated always as (last_check_in + (check_in_interval_hours || ' hours')::interval) stored,
  alert_sent boolean default false, -- Reset to false on check-in
  timezone text default 'UTC',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 3. EMERGENCY CONTACTS (Max 3 per user via app logic)
create table public.emergency_contacts (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  name text not null,
  phone_number text not null,
  relationship text,
  created_at timestamptz default now()
);

-- 4. CHECK-IN HISTORY
create table public.check_in_history (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  check_in_time timestamptz default now(),
  method text default 'manual' -- 'manual', 'automatic', etc.
);

-- RLS POLICIES -----------------------------------------

-- Enable RLS
alter table public.profiles enable row level security;
alter table public.user_settings enable row level security;
alter table public.emergency_contacts enable row level security;
alter table public.check_in_history enable row level security;

-- Profiles: Users can read/update their own profile
create policy "Users can view own profile" on public.profiles
  for select using (auth.uid() = id);
create policy "Users can update own profile" on public.profiles
  for update using (auth.uid() = id);

-- Settings: Users can read/update their own settings
create policy "Users can view own settings" on public.user_settings
  for select using (auth.uid() = user_id);
create policy "Users can update own settings" on public.user_settings
  for update using (auth.uid() = user_id);
create policy "Users can insert own settings" on public.user_settings
  for insert with check (auth.uid() = user_id);

-- Contacts: Users can CRUD their own contacts
create policy "Users can view own contacts" on public.emergency_contacts
  for select using (auth.uid() = user_id);
create policy "Users can insert own contacts" on public.emergency_contacts
  for insert with check (auth.uid() = user_id);
create policy "Users can update own contacts" on public.emergency_contacts
  for update using (auth.uid() = user_id);
create policy "Users can delete own contacts" on public.emergency_contacts
  for delete using (auth.uid() = user_id);

-- History: Users can view/insert their history
create policy "Users can view own history" on public.check_in_history
  for select using (auth.uid() = user_id);
create policy "Users can insert own history" on public.check_in_history
  for insert with check (auth.uid() = user_id);

-- TRIGGERS ---------------------------------------------

-- Auto-create profile and settings on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, new.raw_user_meta_data->>'full_name');
  
  insert into public.user_settings (user_id)
  values (new.id);
  
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Auto-log check-in history when user settings 'last_check_in' updates
create or replace function public.log_check_in()
returns trigger as $$
begin
  -- Only insert history if last_check_in actually changed
  if old.last_check_in is distinct from new.last_check_in then
    insert into public.check_in_history (user_id, check_in_time)
    values (new.user_id, new.last_check_in);
    
    -- Reset alert status
    new.alert_sent := false;
  end if;
  return new;
end;
$$ language plpgsql security definer;

create trigger on_check_in_update
  before update on public.user_settings
  for each row execute procedure public.log_check_in();
```

---

## Phase 1: Supabase Edge Function

### 1.1. Create Edge Function
Initialize Supabase locally (if not done) or create the function file directly.
Name: `check-dead-man-switch`

**File:** `supabase/functions/check-dead-man-switch/index.ts`

```typescript
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

Deno.serve(async (req) => {
  try {
    // 1. Find users who are overdue and haven't been alerted yet
    const { data: overdueUsers, error: fetchError } = await supabase
      .from('user_settings')
      .select(`
        user_id,
        check_in_interval_hours,
        alert_message,
        last_check_in,
        profiles:user_id ( full_name, email ),
        emergency_contacts:user_id ( name, phone_number )
      `)
      .lt('next_check_in_deadline', new Date().toISOString())
      .eq('alert_sent', false)

    if (fetchError) throw fetchError

    console.log(`Found ${overdueUsers?.length || 0} overdue users.`)

    const results = []

    // 2. Process each overdue user
    for (const user of overdueUsers || []) {
      const contacts = user.emergency_contacts
      if (!contacts || contacts.length === 0) {
        console.log(`User ${user.user_id} has no contacts. Skipping.`)
        continue
      }

      const message = user.alert_message
        .replace('{user_name}', user.profiles?.full_name || 'User')
        .replace('{interval}', user.check_in_interval_hours.toString())

      // 3. Send SMS to each contact (Mocked for now)
      for (const contact of contacts) {
        // TODO: Replace with actual Twilio/SMS provider call
        console.log(`[MOCK SMS] To: ${contact.phone_number}, Msg: ${message}`)
      }

      // 4. Mark as alerted so we don't spam them every hour
      const { error: updateError } = await supabase
        .from('user_settings')
        .update({ alert_sent: true })
        .eq('user_id', user.user_id)

      if (updateError) {
        console.error(`Failed to update status for user ${user.user_id}`, updateError)
      } else {
        results.push({ user: user.user_id, status: 'alerted' })
      }
    }

    return new Response(
      JSON.stringify({ success: true, processed: results }),
      { headers: { 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
```

### 1.2. Deploy Function
```bash
supabase functions deploy check-dead-man-switch --no-verify-jwt
```

### 1.3. Schedule Cron Job
In Supabase SQL Editor, set up `pg_cron` to call this function every hour.

```sql
select cron.schedule(
  'check-every-hour', -- name of the cron job
  '0 * * * *',        -- every hour at minute 0
  $$
  select
    net.http_post(
        url:='https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/check-dead-man-switch',
        headers:='{"Content-Type": "application/json", "Authorization": "Bearer <YOUR_SERVICE_ROLE_KEY>"}'::jsonb,
        body:='{}'::jsonb
    ) as request_id;
  $$
);
```
*Note: Replace `<YOUR_PROJECT_REF>` and `<YOUR_SERVICE_ROLE_KEY>` with actual values.*

---

## Phase 2: Flutter Project Configuration

### 2.1. Dependencies
Update `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  # Backend
  supabase_flutter: ^2.12.0
  
  # Storage
  flutter_secure_storage: ^9.0.0
  
  # Auth
  google_sign_in: ^6.2.0
  sign_in_with_apple: ^6.1.0
  
  # Utils
  flutter_local_notifications: ^19.5.0
  timezone: ^0.12.0
  permission_handler: ^11.3.1
  intl: ^0.19.0
  uuid: ^4.3.3
```

### 2.2. Folder Structure
Create the following directories in `lib/`:
```
lib/
├── core/
│   ├── constants.dart
│   └── utils.dart
├── models/
├── repositories/
├── services/
├── screens/
│   ├── auth/
│   ├── home/
│   ├── onboarding/
│   ├── settings/
│   └── history/
├── widgets/
└── main.dart
```

### 2.3. Platform Specifics

**Android (`android/app/build.gradle`)**:
- Set `minSdkVersion 23` (required for some auth plugins).

**iOS (`ios/Runner/Info.plist`)**:
- Add URL schemes for Google Sign-In (reversed client ID).
- Add `Privacy - Location Always...` (not strictly needed yet but good for background work prep).
- Add `Sign In with Apple` capability in Xcode.

---

## Phase 3: Core Flutter Services

### 3.1. Constants (`lib/core/constants.dart`)
```dart
class AppConstants {
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
  
  // Routes
  static const String routeSplash = '/';
  static const String routeLogin = '/login';
  static const String routeOnboarding = '/onboarding';
  static const String routeHome = '/home';
  static const String routeSettings = '/settings';
  static const String routeHistory = '/history';
}
```

### 3.2. Supabase Service (`lib/services/supabase_service.dart`)
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';

class SupabaseService {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
```

### 3.3. Auth Service (`lib/services/auth_service.dart`)
Implement methods:
- `signInWithEmail(email, password)`
- `signUpWithEmail(email, password)`
- `signInWithGoogle()`
- `signInWithApple()`
- `signOut()`
- `get currentUser`

---

## Phase 4: Data Models & Repositories

### 4.1. Models
Create Dart classes with `fromJson`/`toJson` for:
- **UserProfile**: `id`, `email`, `fullName`.
- **UserSettings**: `userId`, `checkInInterval`, `alertMessage`, `lastCheckIn`, `alertSent`.
- **EmergencyContact**: `id`, `name`, `phoneNumber`, `relationship`.
- **CheckIn**: `id`, `checkInTime`, `method`.

### 4.2. Repositories
Create repositories to abstract Supabase calls:
- **SettingsRepository**:
  - `fetchSettings()`
  - `updateSettings(UserSettings)`
  - `checkInNow()`: Updates `last_check_in` timestamp.
- **ContactRepository**:
  - `getContacts()`
  - `addContact(EmergencyContact)`
  - `updateContact(EmergencyContact)`
  - `deleteContact(id)`
- **CheckInRepository**:
  - `getHistory(limit: 50)`

---

## Phase 5: UI Screens

### 5.1. Auth & Onboarding
- **SplashScreen**: Check `Supabase.auth.currentUser`. If null -> Login. If logged in -> check `UserSettings`. If contacts empty -> Onboarding. Else -> Home.
- **LoginScreen**: Standard implementation.
- **OnboardingScreen**: PageView with 3 steps:
  1. Introduction
  2. Add Emergency Contacts (at least 1)
  3. Set Check-in Interval & Message.

### 5.2. Home Screen
- Display "Time until next check-in" (calculated from `UserSettings.lastCheckIn` + interval).
- Large "I AM ALIVE" button.
- Action: `onPressed` -> call `SettingsRepository.checkInNow()`, show celebration animation, reset timer.

### 5.3. Settings Screen
- Allow editing contacts (ListView with add/edit/delete).
- Change interval (Slider: 24h to 168h).
- Edit Alert Message (TextField).

### 5.4. History Screen
- Simple ListView showing `check_in_history` table data.
- Format dates nicely using `intl` package.

---

## Phase 6: Testing & Verification

### 6.1. Functional Testing
1. **Sign Up**: Create a new account.
2. **Onboarding**: complete setup. Check Supabase table `user_settings` and `emergency_contacts` to see data.
3. **Check-in**: Tap button. Verify `user_settings.last_check_in` updates and `check_in_history` gets a new row.
4. **Logout/Login**: Verify session persistence.

### 6.2. Dead Man's Switch Test
1. Manually edit your row in `user_settings` via Supabase Dashboard.
   - Set `last_check_in` to 3 days ago.
   - Set `check_in_interval_hours` to 48.
   - Ensure `alert_sent` is `false`.
2. Wait for the hourly cron (or manually trigger the Edge Function via cURL/Postman).
3. Check Function Logs in Supabase Dashboard.
4. Verify `alert_sent` becomes `true`.
5. Verify "Mock SMS" log appears.
