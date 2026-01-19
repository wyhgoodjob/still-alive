# Still Alive 🕯️

> **"If you go silent, we speak up for you."**

![Flutter Version](https://img.shields.io/badge/Flutter-3.38%2B-02569B?logo=flutter)
![Dart Version](https://img.shields.io/badge/Dart-3.10%2B-0175C2?logo=dart)
![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?logo=supabase)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-0.1.0-blue)

**Still Alive** is a digital "dead man's switch" designed for peace of mind. It requires users to check in periodically (every 1-7 days). If a check-in is missed, the system automatically alerts designated emergency contacts via SMS, ensuring that someone knows something might be wrong.

---

## ✨ Key Features

- **🛡️ Secure Authentication**: Sign in with Email, Google, or Apple.
- **⏱️ Flexible Check-ins**: Configure check-in intervals from **24 hours to 7 days**.
- **🆘 Emergency Contacts**: Add up to **3 contacts** who will be notified if you fail to check in.
- **🔔 Smart Reminders**: Local notifications at **75%** and **90%** of your interval to prevent false alarms.
- **💬 Custom Alerts**: Personalized SMS messages with dynamic variables like `{user_name}` and `{interval}`.
- **☁️ Server-Side Safety**: Monitoring happens in the cloud—alerts are sent even if your phone is broken or out of battery.
- **🚦 Visual Urgency**: Color-coded UI (Green → Orange → Red) indicates remaining time at a glance.
- **📜 History Tracking**: Keep a log of all your check-ins.

---

## 🛠️ Tech Stack

### Mobile & Web (Flutter)
- **Framework**: Flutter 3.38+ / Dart 3.10+
- **State Management**: `provider` / `riverpod` (implied)
- **Auth**: `google_sign_in`, `sign_in_with_apple`
- **Notifications**: `flutter_local_notifications`
- **Storage**: `flutter_secure_storage`

### Backend (Supabase)
- **Database**: PostgreSQL
- **Authentication**: Supabase Auth
- **Edge Functions**: Deno (TypeScript) for cron jobs and SMS logic
- **SMS Provider**: Twilio API

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed
- [Supabase](https://supabase.com/) account
- [Twilio](https://www.twilio.com/) account (for SMS)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/still_alive.git
   cd still_alive
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Environment**
   Update `lib/core/constants.dart` with your Supabase credentials:
   ```dart
   static const String supabaseUrl = 'YOUR_SUPABASE_URL';
   static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
   ```

4. **Run the App**
   ```bash
   flutter run
   ```

---

## ⚙️ Configuration

### Supabase Setup
1. Create a new Supabase project.
2. Run the SQL scripts in `supabase/migrations` (if provided) or set up tables: `profiles`, `user_settings`, `emergency_contacts`.
3. Deploy the Edge Function for monitoring:
   ```bash
   supabase functions deploy check-overdue
   ```
4. Set up `pg_cron` to call the `check-overdue` function hourly.

### Twilio Setup
Set the following secrets in your Supabase Edge Function environment:
```bash
supabase secrets set TWILIO_ACCOUNT_SID=your_sid
supabase secrets set TWILIO_AUTH_TOKEN=your_token
supabase secrets set TWILIO_PHONE_NUMBER=your_twilio_number
```

---

## 📂 Project Structure

```
lib/
├── core/            # Constants, theme, utilities
├── models/          # Data models (UserProfile, CheckIn, Contact)
├── repositories/    # Data access layer
├── screens/         # UI Screens (Auth, Home, Settings)
├── services/        # External services (Supabase, Notifications)
└── widgets/         # Reusable UI components

supabase/
└── functions/       # Server-side logic (Deno/TypeScript)
    └── check-overdue/  # Cron job for monitoring status
```

---

## 🗺️ Roadmap

- [x] v0.1.0: Core functionality, SMS alerts, Local notifications
- [ ] v0.2.0: Push notifications, Widget support
- [ ] v0.3.0: Location sharing in emergency alerts
- [ ] v1.0.0: Multiple alert channels (Email, Telegram, WhatsApp)

---

## 🙏 Acknowledgments

- [Supabase](https://supabase.com/) for the awesome backend-as-a-service.
- [Twilio](https://www.twilio.com/) for reliable SMS infrastructure.
- [Flutter Team](https://flutter.dev/) for the UI toolkit.
