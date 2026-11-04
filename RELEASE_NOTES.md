
### 🌟 What's New
- **Adaptive P2P Device Pairing**: Context-aware Master Sync hub automatically detects unpaired states, providing direct QR code generation and 1-tap device pairing with descriptive connection feedback.
- **Cross-Version Sync Cryptography**: Backward and forward compatibility negotiation between PBKDF2 and legacy key derivations for seamless multi-device merges across app versions.
- **Resilient IPv6 Local Discovery**: Full bracketed IPv6 socket routing across all local sync, ping, and master snapshot protocols.

### 🚀 Improvements
- **Non-Blocking SMS Ingestion**: Clean sliver-docked sync progress with real-time counters and instant cancellation.
- **Database UUID Deduplication**: Instant O(1) transaction lookups with automated UUID backfills and covering index `idx_transactions_uuid`.

### 🐛 Fixes
- **Finances Banner Ghosting**: Eliminated duplicate render artifacts between scrollable slivers and layout overlays.
- **P2P Verification Clarity**: Replaced generic fallback errors with actionable status diagnostics (code mismatches, network timeouts, rate limiting).

