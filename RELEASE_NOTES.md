
### 🌟 What's New
- **Cross-Network E2EE Blind Relay Sync**: Pair, ping, and bi-directionally synchronize devices even when your Wi-Fi router has AP Client Isolation enabled or when devices are on separate Wi-Fi and Mobile Data networks.
- **Hotspot & Multi-Subnet Discovery**: Automatic link-local multicast (`224.0.0.167`), gateway unicast beacons, and HTTP discovery probing let phones and tablets discover each other instantly over Personal Hotspots and Wi-Fi Direct.
- **Multi-Interface QR Pairing**: Host QR codes now embed all active local network interfaces and automatically negotiate the fastest working path or fall back to encrypted relay transport.

### 🚀 Improvements
- **Smart Mobile Data & VPN Filtering**: Automatically filters out cellular Carrier-Grade NAT (`100.64.0.0/10`), 464XLAT (`192.0.0.0/24`), and VPN virtual adapters so local P2P always binds to genuine Wi-Fi or Hotspot interfaces.
- **Full Domain Sync Refresh**: Manual and outbound P2P syncs now immediately refresh Split Bills and Savings Goals alongside Notes, Finances, and Period Tracker.
- **Dual-Stack Host Server Resilience**: Host server automatically re-verifies and binds dual-stack IPv4/IPv6 sockets whenever opening the P2P Sync hub or displaying your QR code.

### 🐛 Fixes
- **Same-Wi-Fi Unreachable Peer Fix**: Resolved socket binding and router isolation failures (`Peer device unreachable`) between phones and tablets on the same Wi-Fi network.
- **QR Scanner Camera Fallback**: Added an interactive fallback card to enter the 6-digit pair code manually if camera permissions are denied or unavailable.
- **Deterministic Note Merge Tie-Breaking**: Resolved edge cases where notes with identical millisecond modification timestamps were skipped during merge.

