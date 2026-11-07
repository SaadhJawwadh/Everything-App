
### 🌟 What's New
- **Universal P2P & Cross-Network Sync Parity**: End-to-end verified BIP-340 Schnorr WebSocket relay alongside dedicated IPv4 socket binding, enabling frictionless sync across Wi-Fi, Hotspots, and Mobile Data.

### 🚀 Improvements
- **Background Queue Synchronization**: Added polling-based asynchronous drain synchronization to `AppFunctionInboxService`, ensuring immediate, reliable execution and SnackBar feedback for queued actions.

### 🐛 Fixes
- **Async Execution Race Guard**: Eliminated timing races in background queue processing to ensure database writes complete before status feedback is presented.

