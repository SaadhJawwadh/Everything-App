---
name: Tester
description: A comprehensive testing skill that covers UI/UX consistency, codebase QA, security auditing, and verification of settings and backups.
---

# Tester Skill

Use this skill to execute QA verifications, unit/widget tests, security audits, and layout validations.

## 1. UI/UX & Material 3 Expressive Verification
* **Design System Reference**: Verify layouts adhere to [design.md](file:///Users/saadhjawwadh/Documents/Code/Note%20taking/.agent/skills/UI-UX-Specialist/design.md) (5-tier surface tokens `surfaceContainerLow` $\rightarrow$ `surfaceContainerHighest`, $48 \times 48\text{ dp}$ tap targets, spring physics).
* **Button Hierarchy Integrity**: Verify primary actions use `FilledButton` / `IconButton.filled`, secondary actions use `FilledButton.tonal` / `OutlinedButton`, dual actions use **Split Buttons**, and FAB groups expand via the **FAB Menu** pattern.
* **M3 Motion & Spring Physics**: Check that micro-animations and container morphs use spring-based physics (`Curves.elasticOut`, `Curves.fastOutSlowIn`) and maintain smooth 120 FPS render performance.
* **Typography & Emphasized Text**: Confirm that headings and editorial titles leverage M3 Emphasized text style slots (`Google Sans Text` weight 600) and numeric ledgers utilize tabular `Inter` font formatting.
* **Overflow Protection**: Verify all dynamically generated text is wrapped appropriately (`Flexible`/`Expanded`) to prevent `RenderFlex overflow` issues.
* **Visual Validation**: Capture screenshots of the mobile emulator (`emulator-5554`) to verify layouts:
  ```bash
  adb exec-out screencap -p > "screenshots/<filename>.png"
  ```
* **Interactive Carousel Presentation**: When presenting end-of-test verification to the user, collate captured screenshots into an interactive Markdown carousel artifact (`verification_carousel.md`) using ````carousel and `<!-- slide -->` syntax so the user can easily scrub through UI progressions, state changes, and edge-case verifications.

## 2. Codebase QA & Mocking
* **Test Suite execution**: Always run the full local test suite:
  ```bash
  flutter test
  ```
* **Path Provider Mocking**: Unit or widget tests utilizing filesystem paths must mock the path provider channel inside `setUp`:
  ```dart
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall methodCall) async => '.',
  );
  ```
* **Context safety**: Ensure all asynchronous callback gates check `context.mounted` or state `mounted` before executing context operations.
* **Async Provider Constructor Races**: `SettingsProvider` loads `SharedPreferences` asynchronously in its constructor (`loadSettings()`). In unit tests where a new instance is instantiated (`newSettings = SettingsProvider()`), insert `await Future.delayed(const Duration(milliseconds: 100))` before invoking methods like `restoreFromBackupMap` to prevent `loadSettings()` from finishing later and overwriting mock test state.
* **Widget Test Localization Delegates**: Any widget test rendering screens that reference `AppLocalizations.of(context)` (e.g. `SettingsScreen`) must include `localizationsDelegates: AppLocalizations.localizationsDelegates` and `supportedLocales: AppLocalizations.supportedLocales` inside `MaterialApp` in the test widget tree to prevent `null` localization exceptions.
* **SMS Sandbox & PII Sanitization Tests**: Verify regex sanitization does not strip long non-numeric English words by including $>10$ character words (`Supermarket`, `Restaurant`) in test fixtures. Verify sandbox simulations use recognized sender tokens (`BANK_SMS`, `BANK`, `CARD`) to match parser whitelist rules.
* **SMS Permission Manifest Parity Tests**: Verify `SmsService.hasPermission()` checks strictly declared permissions (`Permission.sms`) and gracefully returns fallback booleans when executed outside Android UI isolates.
* **Tombstone Ingestion Guardrail Tests**: Verify `TransactionRepository.createSmsTransaction` rejects inserting transactions whose `smsId` is present in `deleted_transaction_sms_ids` when `bypassTombstones: false`, and deletes the tombstone record allowing insertion when `bypassTombstones: true`.
* **Sync Cancellation Tests**: Verify `SmsService.cancelSync()` sets `_cancelRequested` and halts batch ingestion cleanly without unhandled exceptions or incomplete database writes.
* **Hardware AI Gating Tests**: Test widget trees under both `settings.isDeviceAiSupported = true` and `settings.isDeviceAiSupported = false` to confirm AI buttons and menu items hide cleanly on non-NPU devices and emulators.
* **Scrollable Widget Test Hit Safety**: In tests involving `SingleChildScrollView`, `ListView`, or `CustomScrollView` (such as `OnboardingScreen` or `SettingsScreen`), always call `await tester.ensureVisible(finder)` prior to `tester.tap(finder)` to prevent offscreen hitTest misses.

## 3. Data Integrity & Backups Audit
* **Backup Completeness**: Ensure `BackupService.generateBackupJson` uses `SettingsProvider.toBackupMap()` to export settings. Never hardcode individual SharedPreferences keys, which go stale as new options are added.
* **Restore Operations**: Ensure `SettingsProvider.restoreFromBackupMap` calls **setter methods** (e.g., `await setShowFinancialManager(value)`) instead of assigning directly to private fields. Direct assignments skip saving to SharedPreferences, causing settings to revert on app restart.
* **Multi-Version Database Upgrades**: Verify `onUpgrade` database migrations preserve existing user data from ALL historical versions (e.g., v1 -> v19 in `test/upgrade_backward_compatibility_test.dart`). Ensure all migration SQL statements use standard single quotes (`''`) for string literals and default values (`DEFAULT ''`, `NULLIF(col, '')`) to avoid SQLite identifier syntax errors.

## 4. Security Auditing
* **SQLCipher**: Confirm that database connections are always opened securely with the key from KeyStore.
* **App Lock Screen**: Verify that background state detection locks the app after the idle timeout.
* **Picker & Native Dialog Lock Bypasses**: Verify that screens using platform file/image pickers, share sheets (`SharePlus.instance.share`), or gallery permission dialogs (`Gal.requestAccess`) implement `AppLockScreen.ignoreNextResumeLock()` so that returning from native OS dialogs or sheet interfaces does not trigger the app lock screen and unmount the active widget state.
* **Secure Key Storage**: Never store database encryption keys or backups in unencrypted `SharedPreferences`. Migrate legacy backups to `FlutterSecureStorage` on launch and remove them from plaintext storage immediately to prevent leakage.
* **Android Notifications Resource Resolution**: The `FlutterLocalNotificationsPlugin` looks for initialization icons in the app's `drawable` folder (e.g. `R.drawable.launcher_icon`). If the resource is only defined in `mipmap` directories, it will fail on startup with a `PlatformException(invalid_icon)`. Place a copy of the target icon inside the `drawable` folder to ensure successful native initialization.
* **Tablet & Large Screen Manifest Compatibility**: Ensure `android.hardware.telephony`, `camera`, and `microphone` features in `AndroidManifest.xml` have `android:required="false"` and `<supports-screens>` is configured. Otherwise, Wi-Fi tablets (e.g. Samsung Galaxy Tab S10+) will be automatically excluded from Play Store distribution.

## 5. Release-Mode & On-Device Verification (v2.0 learnings)
* **Debug hides release-only startup races.** A WorkManager task opening the SQLCipher DB in a background isolate during cold start deadlocked the app on the splash — release builds only. ALWAYS install the release APK on the emulator and cold-start it before shipping. Give background tasks an `initialDelay`, and wrap `main()`'s init `Future.wait` in a `.timeout()` so the first frame can never hang.
* **Diagnosing a stuck launch**: `adb logcat -s flutter` (engine + Dart prints), `adb shell dumpsys window | grep mCurrentFocus`, `adb shell pidof <package>`. Two "Impeller" engine lines = a background FlutterEngine (WorkManager) is also running.
* **Background isolate channels**: MethodChannels registered in `MainActivity.configureFlutterEngine` do NOT exist in WorkManager isolates — `MissingPluginException` from there is expected; code must catch it and prefs-only paths must still complete.
* **Drive the UI, don't assume**: a FAB `tooltip` swallowed the long-press that opened the template sheet — only caught by actually long-pressing on the emulator. Screenshot each new surface and LOOK at it.
* **Test-data parity**: `createTestDatabase` pins the CURRENT schema version (v19) — bump it together with `_initDB`'s `version:` and add the `onUpgrade` branch, or tests diverge from production schema.
* **Flutter↔Kotlin prefs types**: Dart `prefs.setInt` stores a Long — Kotlin must read `getLong(...)`, not `getInt(...)`, or widget code silently falls back to defaults.
* **SegmentedButton UI Tap Coordinates in Mobile Emulator**: When driving UI taps on `SegmentedButton` controls via `adb shell input tap <x> <y>`, ensure vertical Y coordinates target the *actual* segment pill row (e.g. `y=970` on $1080 \times 2400$ display below the top hero card), avoiding upper header/scope pill areas (e.g. `y=395`). Inspect dumped UI bounds (`uiautomator dump`) or captured screenshots to verify segment state toggling.
* **Release-Mode Cold Launch Verification**: Always verify that `WhatsNewSheet` fires with the bumped version number, that `_buildFinancesFAB` dynamically updates to "New Split Bill" upon switching tabs, and that no R8/ProGuard class-stripping occurs.
* **Emulator Session Persistence**: Keep the emulator (`emulator-5554`) running in the background during active testing and iterations. Do not close or restart the emulator between test steps. Only shut down the emulator after the release is published or upon explicit user request.

## 6. R8 Optimization & ProGuard Verification
* **R8 Full Mode Enforced**: Verify `android.enableR8.fullMode=true` is set in `android/gradle.properties`. Avoid broad wildcards like `-keep class io.flutter.** { *; }` in `proguard-rules.pro` that disable dead code elimination and method inlining.
* **Release Build Compilation**: Run `flutter build apk --release` to verify that R8 shrinking completes cleanly without `ClassNotFoundException` or missing symbol warnings.
* **Plugin Stripping Check**: When adding a new Flutter plugin with Android native components, verify that `android/app/proguard-rules.pro` has a corresponding explicit `-keep class <package_name>.** { *; }` declaration.
* **On-Device ProGuard Audit**: Test key native features (SQLCipher DB decryption, Biometric auth, Share sheet, Camera/Gallery picking, Background WorkManager) on a release build (`app-release.apk`) to verify R8 has not stripped runtime reflection entry points.

## 7. Bitmap Downsampling & Image Fallbacks
* **Mandatory Bitmap Downsampling**: Verify that all `Image.file`, `Image.network`, and `Image.asset` preview widgets supply `cacheWidth` (e.g. `cacheWidth: 1080` for note body embeds, `cacheWidth: 400` for grid/list cards) to prevent full-resolution 12–48MP camera images from allocating 24–48MB RAM buffers per image.
* **Rich Text Image Fallbacks**: Verify `Image.file` and `Image.network` in custom embed builders implement `errorBuilder` to render a clean fallback container with `Icons.broken_image_outlined` when local image files are deleted from disk or URLs fail to resolve.
* **Database Test Version Alignment**: Verify `DatabaseHelper.createTestDatabase()` pins the exact schema version specified in `_initDB()` (version 19) so test database instances match production database schemas 100%.

## 8. Background Isolate & Schedule QA
* **Isolate Binding Initialization**: Verify all `@pragma('vm:entry-point')` functions and Workmanager task callbacks (`callbackDispatcher`, `backgroundMessageHandler`, `performDailyTransactionSync`) call `WidgetsFlutterBinding.ensureInitialized()` at entry before invoking `SharedPreferences`, `DatabaseHelper`, or platform channels.
* **Workmanager Task Chain Resilience**: Confirm that scheduled background task routines wrap task re-registration logic inside `finally` blocks so temporary failures during task execution do not permanently stop future runs.
* **Automated Notification Schedule Sync**: Verify that model mutations (creating/updating/deleting period logs or auto-purging deleted notes from trash) automatically trigger notification schedule recalculation or cancellation.

## 9. Global Text Scaling & Viewport Audits
* **Dynamic Text Scaling Validation**: Test widget trees across `settings.textSize` boundaries (14.0dp Small, 16.0dp Medium, 20.0dp Large) using `tester.binding.platformDispatcher.textScaleFactorTestValue` to verify text wrapping and prevent layout overflow.

## 10. P2P Pairing & Dynamic-Network QA
* **Identity and Migration Tests**: Cover persisted local device IDs, legacy `ipAddress` migration into `DeviceEndpoint` lists, custom peer-name persistence, and multiple endpoints for one `deviceId`. Never test or assert deduplication by IP address or pair code.
* **Handshake Integrity**: Verify that a failed handshake does not create a paired record and that both QR and manual pairing use the acknowledged peer identity. Cover malformed/legacy QR payload handling without crashing the onboarding or pairing dialog.
* **Physical Two-Device Matrix**: Before release, pair two real devices via QR on the same Wi-Fi, rename both peers, restart each app, then pair a third device. Re-scan after changing one device's Wi-Fi and confirm the original and new endpoints remain stored, with sync falling back when the newest endpoint is unreachable.
* **QR Permissions and Layout**: Confirm Android camera permission and iOS camera usage text are present; exercise the scanner on-device. Verify P2P cards and actions at Large text scale, ensuring all actions retain a $48 \times 48\text{ dp}$ touch target and peer names/IPs use ellipsis instead of overflowing.

## 11. Optimistic UI & Soft-Delete Undo QA
* **0ms In-Memory State Consistency**: When testing deletion, undo, and toggle interactions, verify that in-memory models update synchronously and notify listeners immediately before background database futures resolve.
* **Soft-Delete Undo Contract**: Verify that undoing a soft-deleted item invokes `restoreTransaction(id)` / `restoreNote(id)`, keeping the primary key intact without triggering unique constraint violations or colliding with tombstone safety checks.
* **SMS Timestamp Normalization**: Verify that unit tests for `SmsParser.resolveMessageDate` validate 10-digit second epochs, 13-digit millisecond epochs, boundary years, and null fallbacks without date drift.

## 12. App Shortcuts & Deep Linking QA
* **Android Intent Simulation**: Test native app shortcut navigation using ADB command lines:
  ```bash
  adb shell am start -a android.intent.action.VIEW -d "app://open/new_note"
  adb shell am start -a android.intent.action.VIEW -d "app://open/new_transaction"
  adb shell am start -a android.intent.action.VIEW -d "app://open/scan_receipt"
  adb shell am start -a android.intent.action.VIEW -d "app://open/sync_devices"
  ```
  Verify both cold-start (app killed) and warm-resume (app in background) push the appropriate target screen.

## 13. Split Bills Statement & Settlement Reversal QA
* **Multi-Bill Statement Verification**: Verify that sharing a contact's pending statement generates an itemized list of all open bills and exact amounts rather than just the latest transaction.
* **Settlement Undo Ledger Parity**: Verify that undoing a settlement removes the corresponding expense from the personal ledger and updates the daily operating account balance.
* **Test Notification Diagnostics & Unit Isolation**: Verify the "Test Notifications" trigger in Settings schedules delivery in 3 seconds. Ensure `NotificationService` calls are guarded by `Platform.environment.containsKey('FLUTTER_TEST')` so tests execute without `LateInitializationError`.

