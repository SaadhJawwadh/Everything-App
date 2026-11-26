# Everything App

[![Get it on Google Play](https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png)](https://play.google.com/store/apps/details?id=com.saadhjawwadh.notebook)

Everything App (v3.8.0) is an offline-first, encrypted workspace designed to manage your notes, track your finances, log your health, and sync directly across devices without sending data to external cloud servers.

Built with **Flutter (Dart 3)** and backed by an encrypted **SQLCipher** database, Everything App combines hardware-backed security, Material 3 Expressive design, and on-device intelligence in one local app.

---

## Key Features

### 1. Rich Notes & Story Cards
* **Lossless Quill Editor**: Write and organize notes using headers, collapsible checklists, blockquotes, inline tables, and images (`flutter_quill`).
* **Offline OCR (`/scan`)**: Extract editable text directly from photos or embedded note images 100% on-device.
* **Multi-Slide Story Cards**: Export notes as crisp multi-slide image carousels with optional on-device AI highlight selection and studio styles.
* **Full-Library Search & Vault Lock**: Search across unlocked note bodies and tags while keeping locked notes hidden behind biometric or PIN authentication.

### 2. Private Financial Manager & Split Bills
* **Dual-Account Ledger**: Separate **Daily Operating** cash flow from your **Savings Vault** with instant account filtering.
* **Smart SMS Auto-Import**: Parses bank transaction SMS messages locally on-device with automatic duplicate filtering, refund reversals, and recurring rule propagation.
* **Budgets & Proactive Alerts**: Track monthly category budgets with 80% and 100% alerts, recurring bill reminders, and an optional weekly spend digest.
* **Split Bills**: Scan receipts offline via ML Kit OCR, simplify group debts to the fewest transfers, and share itemized payment reminders.

### 3. Health Tracker (Cycle & Ovulation Log)
* **Outlier-Aware Predictions**: Computes cycle and fertile/ovulation windows locally while ignoring cycle anomalies (< 15 or > 60 days).
* **Discreet Notifications & Tab Lock**: Customize private reminder text, add optional period notes, and lock the Health tab independently.

### 4. Local P2P Sync & Browser Companion
* **Zero-Cloud Wi-Fi Sync**: Two-way last-write-wins (LWW) delta sync over local Wi-Fi (HTTP port `8765` + UDP discovery beacon `8766`) with AES-256 encrypted payloads and E2EE cross-network relay fallback.
* **Read-Only Desktop Browser Companion**: Open your phone's local IP on port `8765` in any desktop browser and unlock with your 6-digit pair code to browse unlocked notes or download a JSON backup. Locked notes remain strictly on-device.

### 5. Offline AI (Gemini Nano / AICore)
* **On-Device Intelligence**: Summarize notes (with automatic Tamil detection), suggest tags, refine selected paragraphs into Casual, Professional, Expand, or Shorten tones, and assist with SMS categorization on supported devices.

### 6. Material You Widgets & Dynamic Shortcuts
* **Adaptive Home Widgets**: Two Material You widgets (**Tasks & Notes** and **Finances**) that scale from compact 4x1 strips to tablet layouts.
* **Widget Privacy Lock**: Automatically masks home screen balances and checklist tasks while App Lock or Finance Lock is active.
* **Dynamic App Shortcuts**: Long-press launcher shortcuts adapt to your enabled modules for quick access to New Note, Sync, Search, New Transaction, and Scan Receipt.

### 7. High-Grade Security & Encrypted Backups
* **SQLCipher + Keystore**: Local SQLite database encrypted with 256-bit AES in WAL mode, with keys stored in Android Keystore or iOS Keychain.
* **Tamper-Proof v3 Backups**: Encrypted JSON backups with integrity verification, rolling pre-migration snapshots, and optional Android screenshot protection.

---

## Download & Install

Everything App can be installed from the Google Play Store or manually via GitHub Releases.

### 1. Google Play Store (Recommended)

[![Get it on Google Play](https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png)](https://play.google.com/store/apps/details?id=com.saadhjawwadh.notebook)

### 2. Manual Installation (GitHub Releases)

1. Navigate to the [GitHub Releases Page](https://github.com/SaadhJawwadh/Note-taking/releases).
2. Download the latest release `.apk` file.
3. Open the downloaded file on your Android device and allow **"Install unknown apps"** if prompted.
4. Follow the on-screen installer instructions to finish.

---

## Developer Setup & Builds

### Prerequisites
* Flutter SDK (`>=3.27.0`) and Dart (`>=3.6.0`)
* JDK 17
* Android SDK & Gradle

### Building Locally

1. **Clone the repository**:
   ```bash
   git clone https://github.com/SaadhJawwadh/Note-taking.git
   cd Note-taking
   ```

2. **Get Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run Static Analysis & Tests**:
   ```bash
   flutter analyze
   flutter test
   ```

4. **Compile a Release APK**:
   ```bash
   flutter build apk --release
   ```
   *Note: If no `android/key.properties` file exists in the directory, local release builds default to signing with the debug certificate (`~/.android/debug.keystore`).*
