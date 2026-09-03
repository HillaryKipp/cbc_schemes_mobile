# CBC Schemes of Work — Mobile App (Flutter)

Professional lesson planning and scheme of work generator mobile application for Kenyan Competency-Based Curriculum (CBC) teachers.

Built with **Flutter**, **Supabase Backend (PostgreSQL + RLS)**, **Material 3 (Kenyan Emerald & Gold Theme)**, and **Android Studio ready**.

---

## 🌟 Key Features

1. **Guest-First & Offline Mode**:
   - Auth is completely optional. Teachers can immediately select Grade, Subject, Term, and generate full 10-column schemes locally on their devices.
   - Schemes and rows are stored locally in `SharedPreferences` (JSON) under key `cbc_guest_schemes`.
2. **1-Click Cloud Claiming**:
   - Teachers can connect with Google anytime (`app.cbcschemes://login-callback`).
   - Claiming a guest scheme smoothly migrates local schemes and rows directly into Supabase `schemes` and `scheme_rows` tables.
3. **Official 10-Column Generation Engine**:
   - Exact port of the KICD curriculum generation algorithm.
   - Computes lesson slots: `weeks × lessonsPerWeek`.
   - Sequential strand & sub-strand slot allocation.
   - Content bank resolution: Reference course book specific items with generic fallback (`reference_book_id IS NULL`).
   - Assessment methods default to global items; Reflections always starts empty.
4. **Rich Interactive Editor**:
   - Dual-view toggle: **Expandable Lesson Cards** (optimized for mobile) and **Full 10-Column Data Table**.
   - Multi-select bottom sheets for learning outcomes, inquiry questions, experiences, resources, assessments.
   - Debounced autosave (600ms) with live sync indicator.
   - Row actions: Insert below, delete, and reorder.
5. **PDF Preview, Native Printing & Word (.docx) Export**:
   - Official landscape A4 table format matching TSC and Ministry of Education standards.
   - Direct WiFi/Bluetooth printing with `printing`.
   - Formatted Word `.docx` file generator with document XML tables.
6. **Admin Management Portal**:
   - Automatically accessible when authenticated user has admin role in `user_roles` table or is `ruttohkip4@gmail.com`.
   - Control monetization, payment gates, ads, and price per scheme.

---

## 🏗️ Architecture & Project Structure

```
cbc_schemes_mobile/
├── android/                         # Android Studio native Gradle & Manifest configuration
├── assets/                          # Template files and app assets
├── lib/
│   ├── main.dart                    # App initialization, Providers & Material 3 setup
│   ├── core/
│   │   ├── config/
│   │   │   ├── app_config.dart      # Supabase URL/Key, constants & storage keys
│   │   │   └── theme.dart           # Kenyan Emerald & Gold theme with Google Fonts
│   │   └── utils/
│   │       ├── calendar_utils.dart  # Term date calculation & slot indexing
│   │       ├── debounce.dart        # 600ms autosave debouncer
│   │       └── formatters.dart      # Currency & date formatters
│   ├── models/
│   │   ├── grade.dart               # PP1 to Grade 9 models
│   │   ├── subject.dart             # CBC Learning areas
│   │   ├── strand.dart              # Strands and SubStrands
│   │   ├── reference_book.dart      # KICD approved books (KLB, Oxford, Longhorn)
│   │   ├── content_bank.dart        # Outcomes, Questions, Experiences, Resources, Assessments
│   │   ├── scheme.dart              # Main Scheme header model
│   │   ├── scheme_row.dart          # 10-column lesson row model
│   │   ├── guest_scheme.dart        # Local offline guest scheme
│   │   ├── term_template.dart       # Official term dates and default week counts
│   │   └── app_settings.dart        # Admin flags (payments, ads, pricing)
│   ├── services/
│   │   ├── supabase_service.dart    # Supabase Client & Google OAuth
│   │   ├── guest_storage_service.dart # Local SharedPreferences JSON storage
│   │   ├── curriculum_service.dart  # Supabase fetching with rich offline seed fallbacks
│   │   ├── seed_data.dart           # Built-in curriculum bank data
│   │   ├── scheme_generator.dart    # 10-column scheme generation engine
│   │   ├── scheme_sync_service.dart # Guest scheme claiming & autosave
│   │   ├── pdf_export_service.dart  # Landscape PDF generator & printer
│   │   └── docx_export_service.dart # Word (.docx) generator
│   ├── state/
│   │   ├── auth_provider.dart       # Session, Guest vs Signed-In, Admin detection
│   │   ├── scheme_editor_provider.dart # Live 10-column editing & autosave state
│   │   └── scheme_list_provider.dart   # Merged cloud + guest scheme manager
│   └── ui/
│       ├── screens/
│       │   ├── home/                # Discovery, Quick Finder & Level cards
│       │   ├── generate/            # 3-step Scheme Generator Wizard
│       │   ├── editor/              # 10-column Scheme Editor (Card & Table views)
│       │   ├── preview/             # Official Document Preview, Print & Export
│       │   ├── dashboard/           # My Schemes list & account claim banner
│       │   ├── auth/                # Sign In / Value prompt modal
│       │   ├── admin/               # Admin Portal for app flags & curriculum
│       │   ├── settings/            # Default Teacher Cover details & profile
│       │   └── main_navigation_screen.dart # Bottom Navigation
│       └── widgets/
│           ├── claim_account_banner.dart
│           ├── content_picker_sheet.dart
│           ├── scheme_row_card.dart
│           ├── scheme_data_table.dart
│           └── stat_badge.dart
└── test/
    └── widget_test.dart             # Unit & Widget test suite
```

---

## 🚀 How to Run in Android Studio

1. **Open Android Studio**:
   - Click **Open** and select the folder `c:\Users\hillary.kipkorir\Desktop\cbc_schemes_mobile`.
2. **Sync Dependencies**:
   - Open terminal in Android Studio or run `flutter pub get`.
3. **Configure Supabase Credentials (Optional)**:
   - To connect to your Supabase project, pass `--dart-define` parameters in your run configuration:
   ```bash
   flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=your-anon-key
   ```
   - *Note: If no Supabase URL is passed, the app operates completely smoothly in offline Guest Mode with built-in curriculum seed banks.*
4. **Run on Device / Emulator**:
   - Select your Android Emulator or connected physical device and click the green **Play (Run)** button.

---

## 🧪 Running Tests

```bash
flutter test
```
All unit tests for `CalendarUtils`, `SchemeGenerator`, and UI widgets will execute and verify.
"# cbcschemesmobile" 
