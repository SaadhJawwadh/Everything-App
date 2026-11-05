
### 🌟 What's New
- **Robust P2P Network Synchronization**: Resolved Android UDP socket discovery exceptions, enabling instant background discovery between phones and tablets on the same Wi-Fi.
- **Multi-Code Trusted Key Ring**: Host servers seamlessly authenticate and decrypt incoming requests using both primary host codes and previously paired device keys.
- **Simultaneous Sync Collision Recovery**: Automatic randomized jitter backoff and retries when both peer devices trigger synchronization at the exact same moment.

### 🚀 Improvements
- **Multi-Network Endpoint Priority**: Intelligently prioritizes actively broadcasting Wi-Fi interfaces over stale network IPs from previous locations.
- **Inbound Sync UI Reactivity**: Live inbound delta merges immediately trigger real-time UI refreshes across Notes, Finances, Split Bills, Savings Goals, and Period Tracker.
- **Cryptographically Secure IV Generation**: Upgraded P2P AES-CBC encryption with unique cryptographically random initialization vectors.

### 🐛 Fixes
- **LAN Rate-Limit Tolerance**: Raised the temporary IP lockout threshold to accommodate multi-endpoint discovery and dual-version encryption fallbacks.
- **Samsung & Hotspot Interface Recognition**: Enhanced network interface scoring to recognize `swlan` and `ap` hotspot adapters.

