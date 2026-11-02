
### 🌟 What's New
- **Zero-Cloud P2P Device Sync Engine Hardening**: Ultra-resilient local Wi-Fi pairing and synchronization with multi-network endpoint resolution, non-destructive Last-Write-Wins (LWW) delta merge, soft-delete preservation, and dynamic port fallbacks.
- **Hardened App Lock & Local-First Security**: Back-navigation protection with `PopScope(canPop: false)` and `SystemNavigator.pop()`, native biometric and device PIN/pattern fallback, authentication-protected App Lock toggling, and emergency lockout protection.
- **Atomic Vault Transfers & Cash-Flow Isolation**: Added double-entry atomic account transfers between Daily Operating and Savings Vault accounts, properly excluding internal transfers from monthly and all-time income and expense totals.

### 🚀 Improvements
- **Calm Technology Metric Charts (Invariant 1)**: Removed intrusive auto-cycling timers from the Financial Ledger chart deck; metrics remain calm, static, and predictable with smooth user swipe and indicator dot navigation.
- **Precision Plain-Text Note Search**: Note searches strictly target rendered text and plain-text snippets, preventing false-positive matches on raw Quill Delta JSON syntax.
- **Interactive P2P Host & Client UI Reactivity**: Inbound Wi-Fi sync immediately signals and refreshes active ledger streams, savings goals, and notes on host and client devices without restarting the app.
- **Full-Scope P2P Accounting**: `SyncMergeResult` now tracks and reports merged split bills and savings goals alongside notes, transactions, and period logs.

### 🐛 Fixes
- **Relational Backup & Restore Integrity**: Ensured `savings_goals` and `deleted_period_logs` are cleanly wiped before restore with child-first foreign key deletion ordering.
- **SMS Sync Cancellation Banner**: Cancelling an in-progress SMS scan immediately updates UI banners and prevents advancing `lastSmsSyncTime` so unimported message ranges are preserved.
- **Note Editor Selection Range Clamping**: Search jump offsets are clamped to document bounds to eliminate `RangeError` exceptions during active editing.
- **Reactive Financial Trash Bin**: Restoring or permanently deleting trashed transactions instantly notifies all financial charts, metrics, and ledger views.

