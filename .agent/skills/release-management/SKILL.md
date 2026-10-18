---
name: release-management
description: Handles the end-to-end release process, ensuring local builds are tested and verified by the user before pushing tags to trigger CI/CD releases. Use this whenever preparing for a public version update.
---

# Release Management & DevOps

## Purpose
Ensures that any code being pushed to production is functional, stable, and verified. It prevents "broken releases" by mandating a local build and test cycle before public tags are created.

## Core Mandates
1. **Absolute Permission Rule**: NEVER perform a `git commit`, `git tag`, or `git push` without explicit, real-time user consent for that specific action.
2. **Consent-First Releases**: NEVER trigger a GitHub Actions workflow or push a release tag without permission.
3. **Local Build & Test First**: Always build a local APK and provide it to the user for testing before asking for permission to commit or release.
4. **Mandatory User Verification**: Wait for explicit user confirmation that the local APK works as expected before final commit and push.
5. **Mandatory Play Store Listing Update**: ALWAYS update `PLAY_STORE_NOTES.md` with bilingual release notes (`<en-US>` and `<ta-IN>`) under 450 characters BEFORE running `./deploy.sh` or tagging a release.

---

## Release Workflow

### Step 1: Quality Gate, Documentation & Play Store Listing Sync
Before bumping the version or running deployment, ensure all of the following are done:
* `flutter analyze` → **zero errors/warnings**. CI/CD will fail on any lint issues.
* `flutter test` → **all tests passing**. Running the full test suite locally is mandatory to catch regressions.
* `CHANGELOG.md` entry is documented under `## X.Y.Z - YYYY-MM-DD` (without brackets around the version number). Write for everyday general users—**avoid technical developer jargon** (no "SQLCipher", "WorkManager", "ChangeNotifier", "Delta JSON", "BackdropFilter"). Group all entries into 3 explicit categories using expressive emojis:
  * 🌟 **What's New** (New user-facing features)
  * 🚀 **Improvements** (UI polish, performance, usability enhancements)
  * 🐛 **Fixes** (Bug fixes and stability improvements)
* **Changelog Screen (MANDATORY for every release)**: Update `lib/screens/changelog_screen.dart` by adding a new `_buildVersionSection(context, version: 'vX.Y.Z', date: '...', isLatest: true, changes: [...])` entry at the top of the list.
* **What's New Sheet & Compatibility Test (MANDATORY — must match pubspec version)**: Update `lib/widgets/whats_new_sheet.dart` cards for THIS release's features (3–5 cards max). The version string passed to `WhatsNewSheet(currentVersion: ...)` in `home_screen.dart` must match the version in `pubspec.yaml` exactly, otherwise the sheet will not show on first launch of the new version. Verify by grepping `WhatsNewSheet` in `home_screen.dart` and confirming the version string is updated. Also update the exact version assertion in `test/upgrade_backward_compatibility_test.dart`. All 5 release points (`CHANGELOG.md`, `changelog_screen.dart`, `whats_new_sheet.dart`, `PLAY_STORE_NOTES.md`, and `upgrade_backward_compatibility_test.dart`) must ALWAYS be updated together atomically.
* **Onboarding Wizard Sync (`onboarding_screen.dart`) (MANDATORY)**: Update `lib/features/settings/presentation/screens/onboarding_screen.dart` feature summaries (e.g. Page 3 Modular Powerups) whenever new core features or UI dashboards are added so first-time users and replaying users see accurate descriptions.
* **Play Console Listing Notes (`PLAY_STORE_NOTES.md`) (MANDATORY BEFORE DEPLOYMENT)**:
  * Update `PLAY_STORE_NOTES.md` at project root with current bilingual release notes in English (`<en-US>`) and Tamil (`<ta-IN>`).
  * Target everyday users with friendly emojis.
  * **500 Character Maximum Limit**: Keep total character count under **450 characters** per language block to prevent Google Play API publication failures.
* **Codebase Knowledge Graph (`map.md`)**: Ensure [.agent/map.md](file:///Users/saadhjawwadh/Documents/Code/Note%20taking/.agent/map.md) is updated with any new files or feature architecture.
* **Major vs. Minor / Patch Release Strategy (MANDATORY)**:
  - **🌟 Major Releases (`X.0.0`)**:
    - **Scope**: Major architectural milestones, new module additions, or fundamental redesigns.
    - **Onboarding Wizard (`onboarding_screen.dart`)**: Comprehensive review and update of all onboarding slides. If foundational paradigms change, bump the onboarding version key (e.g., `hasSeenOnboarding_v2`) to re-introduce the experience to all users.
    - **Play Store Notes & What's New**: Focus on marquee pillar capabilities and headline visual transformations.
  - **🚀 Minor & Patch Releases (`X.Y.Z` where `Y > 0` or `Z > 0`)**:
    - **Onboarding Continuity**: Existing users MUST NEVER be forced through the onboarding wizard again (`hasSeenOnboarding_v1` stays intact). First-time users continue to receive the updated onboarding flow on fresh install.
    - **Cumulative What's New & Play Store Notes**: `PLAY_STORE_NOTES.md` and `lib/widgets/whats_new_sheet.dart` MUST preserve and present the **cumulative headline features and improvements from the entire current minor cycle (`X.Y.x`)**, updating on top of them with the latest optimizations/fixes. This ensures users skipping intermediate versions get the complete feature showcase.
    - **Granular Changelogs**: `CHANGELOG.md` and `lib/screens/changelog_screen.dart` maintain granular, distinct sections for each version delta (`X.Y.1`, `X.Y.0`) to keep the historical engineering record precise.
* Version number in `pubspec.yaml` is bumped using the project convention:
  * **Major bump**: `X.0.0+Y` where `Y = X * 10000` (e.g. `3.0.0+30000`)
  * **Minor bump**: `X.Y.0+Z` where `Z = X * 10000 + Y * 100` (e.g. `2.21.0+22100`)
  * **Patch bump**: `X.Y.Z+W` where `W = X * 10000 + Y * 100 + Z` (e.g. `2.21.1+22101`)
  * Keep `minor` and `patch` numbers strictly under `100` to prevent version code overlaps.
* **Google Play VersionCode Immutability & Re-upload Protection**:
  Google Play Developer Console strictly disallows re-uploading an existing `versionCode` (even if an earlier run failed at a later step or only partially completed). Never attempt to re-deploy or re-run a release workflow with the same version code. If a release run fails after or during the upload step, the patch version MUST be bumped (e.g. `2.30.0+23000` $\rightarrow$ `2.30.1+23001`). Also ensure `test/upgrade_backward_compatibility_test.dart` is updated atomically to match the new version string.

### Step 2: Build Local Release APK & On-Device Smoke Test
Verify the release build succeeds locally:
```bash
flutter build apk --release
```
Provide the APK path (`build/app/outputs/flutter-apk/app-release.apk`) to the user for verification.

**Release-mode emulator smoke test is mandatory, not optional.** Install the release APK on the emulator and cold-start it. Verify:
* First frame renders without jank or white screen flashes.
* The What's New sheet fires with the exact version matching `pubspec.yaml`.
* Each module tab (Notes, Finances, Health, Settings) opens smoothly.
* **Status Bar Notification & Silhouette Icon Verification**: Trigger a test notification via `Settings` $\rightarrow$ `About & Diagnostics` $\rightarrow$ `Test Notifications` (ensure `POST_NOTIFICATIONS` is granted). Verify the notification displays the transparent monochrome silhouette icon (`ic_notification.png`) in the Android status bar and shade, confirming that Android Gradle Plugin resource shrinking (`isShrinkResources = true`) did not strip dynamically referenced drawables preserved in `android/app/src/main/res/raw/keep.xml`.
* **Emulator Storage Clean Flush (`INSTALL_FAILED_INSUFFICIENT_STORAGE`)**:
  - If `flutter install` or `adb install -r` fails on the emulator with `INSTALL_FAILED_INSUFFICIENT_STORAGE` due to limited `/data` partition headroom, execute clean uninstall:
    ```bash
    adb -s <device> uninstall com.saadhjawwadh.notebook
    ```
  - This clears >150MB of cached APK revisions and app sandbox data, enabling a clean install that also thoroughly tests the first-run Onboarding wizard and fresh database initialization.

### Step 3: Run Release Automation
Execute the automated deploy script to bump, tag, and publish:
```bash
flutter analyze && ./deploy.sh <version>
```

```xml
<en-US>
🌟 What's New
• Smart search and new folder organizing options.

🚀 Improvements
• Faster page loading and refreshed Material 3 styling.

🐛 Fixes
• Fixed minor checklist and notification bugs.
</en-US>
<ta-IN>
🌟 புதிய அம்சங்கள்
• ஸ்மார்ட் தேடல் மற்றும் புதிய கோப்பு அமைப்புகள்.

🚀 மேம்பாடுகள்
• வேகமான செயல்பாடு மற்றும் புதிய வடிவமைப்பு.

🐛 பிழை திருத்தங்கள்
• விழிப்பூட்டல் மற்றும் சரிபார்ப்பு பட்டியல் பிழைகள் சரி செய்யப்பட்டன.
</ta-IN>
```
`./deploy.sh` and GitHub Actions will read `PLAY_STORE_NOTES.md` to automatically publish multilingual WhatsNew notes directly to Google Play Console.

---

## Gradle & Build Configuration Guidelines

* **JVM Targets**: Always ensure a consistent `jvmTarget = "17"` across all Android subprojects in `build.gradle.kts` to prevent compiler mismatch failures.
* **R8 Code & Resource Shrinking**: Release builds use `isMinifyEnabled = true` and `isShrinkResources = true`. When adding any new third-party Flutter plugin that uses native Android code, reflection, or native channels:
  1. Add a corresponding `-keep class <package_name>.** { *; }` rule to `android/app/proguard-rules.pro`.
  2. Always build a local release APK (`flutter build apk --release`) to verify R8 compiles without class-stripping errors.
  3. Declare dynamically referenced drawables and icons (e.g., `@drawable/ic_notification`, `@drawable/launcher_icon`, `@drawable/ic_*`) in `android/app/src/main/res/raw/keep.xml` to prevent AGP resource shrinking from stripping assets resolved via string reflection at runtime.
* **ProGuard Core Rules**: Ensure core drivers (SQLCipher, sqflite, Pigeon, WorkManager, LocalAuth, Google ML Kit) are protected in `android/app/proguard-rules.pro`:
  ```proguard
  -keep class net.sqlcipher.** { *; }
  -keep class net.sqlcipher.database.SQLiteDatabase { *; }
  -keep class com.tekartik.sqflite.** { *; }
  -keep class com.google_mlkit_text_recognition.** { *; }
  -keep class com.google.mlkit.vision.text.** { *; }
  -keep class com.google.mlkit.vision.common.** { *; }
  -dontwarn com.google.mlkit.vision.text.**
  ```
* **Flutter Icon Tree-Shaking Rule**:
  * **Zero Non-Constant `IconData` Calls**: Never instantiate `IconData(codePoint, ...)` using dynamic or runtime variables anywhere in Dart code. Flutter's release AOT compiler statically inspects `IconData` invocations to tree-shake font files and will abort the build with `Error: Avoid non-constant invocations of IconData`.
  * **Static Lookup Map Pattern**: Always resolve dynamic icon code points via a `const Map<int, IconData>` lookup table mapping code points to `const` icon constants (e.g. `Icons.directions_car_outlined`). Fall back to a `const` icon (e.g. `Icons.category_outlined`).
  * **CI/CD Flag Guardrail**: In GitHub Actions release workflows (`.github/workflows/release.yml`), always include `--no-tree-shake-icons` for both `flutter build apk --release --no-tree-shake-icons` and `flutter build appbundle --release --no-tree-shake-icons` as an extra fail-safe.
* **`deploy.sh` Pathspec Exclusion**: When checking git cleanliness before release, exclude version bump files (`pubspec.yaml` and `CHANGELOG.md`) using pathspecs (`git diff-index --quiet HEAD -- . ':!pubspec.yaml' ':!CHANGELOG.md'`).
* **Replacing Existing Tags**: If a tag needs to be updated or replaced on a new commit:
  ```bash
  git tag -d vX.Y.Z
  git push origin :refs/tags/vX.Y.Z
  git tag vX.Y.Z
  git push origin vX.Y.Z
  ```

---

## Play Store Listing Assets & Mockup Generation

### 1. App Icon & Feature Graphic Specifications
Google Play Console enforces strict dimensions for marketing assets. Use `sips` on macOS to resize/crop generated assets:
* **App Icon (512x512 PNG)**:
  ```bash
  sips -z 512 512 <source_icon.png> --out <dest_icon_512.png>
  ```
* **Feature Graphic (1024x500 PNG)**: Generate a 1024x1024 background asset first, then center-crop it to the correct aspect ratio:
  ```bash
  sips -c 500 1024 <source_graphic.png> --out <dest_graphic_1024x500.png>
  ```

### 2. Creating Mockups with Real Emulator Screenshots (On-Demand)
> [!IMPORTANT]
> **User Request Gate**: Only execute this screenshot and mockup generation workflow **if explicitly requested by the user**. Do NOT generate mockups on every standard release cycle.

To showcase real app workflows in mockups instead of generic placeholders:
1. Launch the app on the connected emulator using the canonical application identifier:
   ```bash
   adb shell am start -n com.saadhjawwadh.notebook/com.saadhjawwadh.notebook.MainActivity
   ```
2. Switch tabs or trigger actions by tapping exact coordinates (e.g., `x=270, y=2250` for Notes, `x=750, y=2250` for Finances):
   ```bash
   adb shell input tap <x> <y>
   ```
3. Capture screen contents directly to files:
   ```bash
   adb exec-out screencap -p > screenshots/<name>.png
   ```
4. Pass the captured screenshot paths to `generate_image` using:
   - **Feature Graphic (16:9)**: High-impact banner showcasing core pillars.
   - **Showcase Cards (9:16)**: Framing real screenshots inside modern bezels with bold Google Sans headlines and subtle Material 3 ambient gradients.
5. Save finished assets to `distribution/playstore_assets/` ready for Google Play Developer Console upload.

### 3. Android Monochrome Launcher Override Gotcha
If regenerating adaptive icons using tools like `flutter_launcher_icons`, check for any pre-existing monochrome vector resource at `android/app/src/main/res/drawable/ic_launcher_monochrome.xml`. Delete this stale XML to allow the system launcher to fallback correctly to the newly generated transparent PNG layers.
