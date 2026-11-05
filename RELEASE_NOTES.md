
### 🌟 What's New
- **BIP-340 Schnorr Cross-Network E2EE Relay**: Genuine `secp256k1` BIP-340 Schnorr cryptographic signing and verification for Nostr NIP-01/NIP-78 envelopes, enabling 100% reliable pairing and sync across 4G/5G Mobile Data CGNAT and AP-isolated Wi-Fi routers.
- **Fast `/24` HTTP Subnet Peer Scanner**: LocalSend-style parallel TCP/HTTP `/24` subnet discovery sweep (`scanLocalSubnetByHttp`) finds devices on the same Wi-Fi or Hotspot in under 2 seconds even when routers block all UDP broadcast and multicast traffic.
- **Custom E2EE Relay Settings**: View active connected relay status and configure an optional self-hosted WebSocket relay (`wss://...`) directly from the Master P2P Sync hub.

### 🚀 Improvements
- **Happy Eyeballs Parallel IP Racing**: Simultaneously races all candidate LAN and Hotspot IP addresses with a fast 2.2-second handshake check so stale endpoints never delay pairing or sync.
- **Self-Healing Host Server Watchdog**: Performs a 400ms loopback socket health check (`verifyLocalServerAlive`) on app resume and diagnostics refresh, automatically re-binding port `8765` if the OS suspended the socket in the background.

### 🐛 Fixes
- **Dedicated Android IPv4 Socket Binding**: Explicitly binds `InternetAddress.anyIPv4` (`0.0.0.0:8765`) as the primary host socket alongside an independent `v6Only: true` IPv6 listener, resolving `Connection refused` (`192.168.1.70`) on Android kernels with `bindv6only=1`.
- **Relay Subscription Race Elimination**: Added buffered NIP-78 replaceable envelopes with 120s expiration and automatic 2.5s request re-publish retry so peers connect reliably regardless of timing.

