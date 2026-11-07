# LedgerLens 🔍 (Flutter Edition)

> **A private, local-first personal finance Android app built with Flutter for Indian banking formats.**

Runs entirely on your Android smartphone with a local SQLite database (`sqflite`), strict integer-paise accounting, zero cloud storage by default, and an elegant warm off-black ink dark mode.

---

## ⚡ Quickstart

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.24+)
- Android Studio or VS Code with Flutter extension
- An Android smartphone or emulator

### Run on your Android phone

```bash
# 1. Install Flutter dependencies
flutter pub get

# 2. Run on connected Android device
flutter run

# 3. Build release APK
flutter build apk --release
```
The output APK is generated at:
`build/app/outputs/flutter-apk/app-release.apk`

---

## ☁️ Optional Cloud Sync (Supabase Setup)

LedgerLens includes an optional, **local-first, multi-user sync engine** designed for siblings where each sibling has their own account on their own phone. All data remains stored locally in on-device SQLite, and delta changes sync seamlessly to Supabase with Row Level Security (RLS).

### 1. Database & Table Setup
1. Open your [Supabase Dashboard](https://supabase.com/dashboard).
2. Navigate to the **SQL Editor** tab.
3. Open [`supabase/schema.sql`](file:///home/xlr8/Downloads/money/supabase/schema.sql) in this repo, paste the contents into the SQL Editor, and click **Run**.
   - This creates `categories`, `merchant_rules`, and `transactions` tables.
   - Sets up performance indexes on `(user_id, updated_at DESC)`.
   - Enables Row Level Security (RLS) guaranteeing strict data isolation between sibling user accounts.

### 2. Sibling User Creation
1. In the Supabase Dashboard, go to **Authentication -> Users**.
2. Click **Add user -> Create user**.
3. Create an account for each sibling (e.g. `sibling1@example.com`, `sibling2@example.com`) with a password.
   - *Note*: There is no in-app sign-up screen; accounts are provisioned securely by the project administrator in the dashboard.

### 3. Connect the Flutter App
1. Open **Settings** in LedgerLens on each sibling's phone.
2. Under **Cloud Sync (Supabase)**, tap **Setup URL**:
   - **Project URL**: `https://<your-project-id>.supabase.co`
   - **Public Anon Key**: Paste your `anon` / `publishable` public key from **Project Settings -> API**.
   - *(Never enter the `service_role` secret key into the app!)*
3. Enter the sibling's email and password, then tap **Sign In to Sync**.
4. Existing offline transactions will automatically be stamped with the signed-in user's UUID and synchronized to their personal cloud partition.

### Sync Features:
- **Last-Write-Wins (LWW)**: Automatic conflict resolution based on UTC timestamp.
- **Offline Resilient**: Changes made while offline accumulate in a local queue and push upon reconnection.
- **Data Isolation**: Database queries strictly filter on `user_id = auth.uid()`. One sibling cannot read or mutate another sibling's data.
- **Delete My Cloud Data**: 1-tap removal of all cloud copies while keeping local device data intact.

---

## 📱 App Features & Screens

1. **Dashboard (`lib/screens/dashboard_screen.dart`)**:
   - Total Net Cashflow, Monthly Income, Monthly Outflow, and Savings Rate.
   - Spending by Category progress bars (Food & Dining, SIP Investments, Utilities).
   - Quick action shortcuts and recent transactions.

2. **Transactions (`lib/screens/transactions_screen.dart`)**:
   - Real-time search across merchants, descriptions, and categories.
   - Quick filter chips: All, Under ₹500, ₹500–₹5k, Over ₹5k, Income only.
   - Indian rupee formatting (`₹`) with integer-paise precision (prevents floating-point rounding errors).

3. **Review Queue (`lib/screens/review_screen.dart`)**:
   - Low-confidence heuristic matches are quarantined here.
   - 1-tap **"✓ Confirm"** or **"Change Category"** with live badge updates.

4. **Insights (`lib/screens/insights_screen.dart`)**:
   - Weekly Outflow trend bar chart.
   - AI-generated financial insights (SIP streaks, utility spikes, dining trends).

5. **Ask Your Money (`lib/screens/ask_screen.dart`)**:
   - Natural language queries powered by Google Gemini AI with local rules-only fallback.
   - Pre-built suggestion chips (salary arrival, SIP totals, electricity bills).

6. **Import Statement (`lib/screens/upload_screen.dart`)**:
   - Multi-format ingestion for **HDFC, SBI, ICICI, Axis, Kotak**.
   - 100% on-device privacy guarantee.

7. **Settings (`lib/screens/settings_screen.dart`)**:
   - Supabase multi-user cloud sync configuration, live status, and manual sync.
   - Biometric App Lock on cold start and background resume.
   - Android `FLAG_SECURE` screen protection against recents task switcher previews and screenshots.

---

## 🛠️ Architecture

- **Framework**: Flutter 3 (Dart)
- **Local Storage**: SQLite via `sqflite` with v1 -> v2 automatic schema migration
- **Cloud Backend**: Optional `supabase_flutter` with Row Level Security (RLS)
- **State Management**: `provider` (`ChangeNotifier`)
- **Formatting**: `intl` (Indian Rupee `en_IN`)
- **AI Engine**: `google_generative_ai` (Gemini API) with rules-only offline fallback
- **Automated CI/CD**: GitHub Actions workflow in `.github/workflows/build-apk.yml`
