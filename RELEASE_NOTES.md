
### 🐛 Fixes
- **Transaction Edits Preserved Against AI Overwrites**: Manual category, description, and date edits on SMS-imported transactions now mark the record as refined and preserve time-of-day, UUIDs, and settlement links so background AI catch-up never reverts user changes.
- **Finance Widget Cold-Start Sync**: Fixed the cold-start race between `SettingsProvider` initialization and `HomeScreen` widget config syncing, added native self-healing from `FlutterSharedPreferences`, and removed the stale padlock icon so enabled Finance widgets never randomly show "Finances disabled".
- **App Lock & Module Lock Conflict Fixes**: Fixed PIN-fallback infinite re-lock loops under Immediate timeout, stale native screen-off flags, `ModuleLockGate` resume auto-prompting, keyboard focus leaks while locked, cold-start `WhatsNewSheet` / `BiometricPrompt` collisions, and closed lock bypasses in Search, Smart Action Cards, Security Settings, and QR Scanner.
- **Notes Save & Embed Safety**: Added lifecycle background flush for pending note debounces, immediate saves on lock/folder/reminder/tag changes, and ensured image-only or table-only notes are never deleted as empty.

