import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'backup_service.dart';
import 'sync_merge_service.dart';
import '../features/sync/data/p2p_pairing_model.dart';
import '../features/finances/presentation/screens/financial_manager_screen.dart';
import 'p2p_relay_sync_service.dart';
import 'sync_crypto_service.dart';

class SyncResult {
  final bool success;
  final int syncedCount;
  final int receivedCount;
  final int sentCount;
  final String transportUsed;
  final String? errorMessage;
  final int? latencyMs;
  final bool isServerInbound;
  final String? peerName;

  SyncResult({
    required this.success,
    this.syncedCount = 0,
    this.receivedCount = 0,
    this.sentCount = 0,
    this.transportUsed = 'Primary Master Sync',
    this.errorMessage,
    this.latencyMs,
    this.isServerInbound = false,
    this.peerName,
  });
}

class SystemDiagnostics {
  final bool wifiConnected;
  final String? localIp;
  final List<String> allLocalIps;

  SystemDiagnostics({
    required this.wifiConnected,
    this.localIp,
    this.allLocalIps = const [],
  });

  bool get isReady => wifiConnected && localIp != null;
}

/// Represents a peer discovered dynamically on the local network via UDP beacon.
class DiscoveredPeer {
  final String deviceId;
  final String deviceName;
  final String ipAddress;
  final int port;
  final DateTime lastSeenAt;

  const DiscoveredPeer({
    required this.deviceId,
    required this.deviceName,
    required this.ipAddress,
    this.port = P2pSyncService.httpSyncPort,
    required this.lastSeenAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredPeer &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId;

  @override
  int get hashCode => deviceId.hashCode;
}

class P2pSyncService {
  static final P2pSyncService instance = P2pSyncService._init();
  P2pSyncService._init();
  factory P2pSyncService() => instance;

  static const int httpSyncPort = 8765;
  static const int udpBeaconPort = 8766;
  static const String udpMulticastGroup = '224.0.0.167';
  static const String _deviceIdStorageKey = 'p2p_local_device_id_v1';

  String? _deviceId;
  HttpServer? _httpServer;
  HttpServer? _httpServerV6;
  RawDatagramSocket? _udpSocket;
  Timer? _beaconTimer;

  final SyncCryptoService _crypto = SyncCryptoService.instance;

  final StreamController<SyncResult> _syncEventsController = StreamController<SyncResult>.broadcast();
  Stream<SyncResult> get syncEvents => _syncEventsController.stream;

  final StreamController<PairedDevice> _remoteDevicePairedController = StreamController<PairedDevice>.broadcast();
  Stream<PairedDevice> get remoteDevicePaired => _remoteDevicePairedController.stream;

  final StreamController<DiscoveredPeer> _discoveredPeersController = StreamController<DiscoveredPeer>.broadcast();
  Stream<DiscoveredPeer> get discoveredPeers => _discoveredPeersController.stream;

  bool _isHosting = false;
  bool _isSyncing = false;
  Future<void>? _serverTransitionFuture;
  final Set<String> _trustedPairCodes = <String>{};

  bool get isHosting => _isHosting && _httpServer != null;
  bool get isSyncing => _isSyncing;

  /// Clears IP rate-limit tracking (used for testing and clean state resets).
  @visibleForTesting
  static void clearRateLimits() => _failedAuthAttemptsByIp.clear();

  /// Emits a remote device paired event (used by direct HTTP and Cross-Network E2EE Relay handlers).
  void notifyRemoteDevicePaired(PairedDevice device) {
    _remoteDevicePairedController.add(device);
  }

  /// Emits a sync activity result (used by direct HTTP and Cross-Network E2EE Relay handlers).
  void notifySyncEvent(SyncResult result) {
    _syncEventsController.add(result);
  }

  /// Updates the set of trusted pair codes from already-paired devices so that
  /// even if the user regenerates their host code or pairs multiple devices,
  /// previously paired devices continue to authenticate seamlessly.
  void updateTrustedPairCodes(Iterable<String> codes) {
    _trustedPairCodes
      ..clear()
      ..addAll(codes.map((c) => c.trim()).where((c) => c.isNotEmpty));
    final primary = _trustedPairCodes.isNotEmpty ? _trustedPairCodes.first : '';
    P2pRelaySyncService.instance.updateTrustedPairCodes(primary, _trustedPairCodes);
  }

  List<String> _candidateCodes(String primaryCode) {
    final ordered = <String>[];
    final trimmed = primaryCode.trim();
    if (trimmed.isNotEmpty) {
      ordered.add(trimmed);
    }
    for (final code in _trustedPairCodes) {
      if (!ordered.contains(code)) {
        ordered.add(code);
      }
    }
    return ordered;
  }

  /// Attempts to decrypt [encryptedPayload] against [primaryCode] and all [_trustedPairCodes].
  /// Returns `(decryptedText, isLegacyKey, matchedPairCode)`.
  (String?, bool, String) _decryptWithAnyTrustedCode(String encryptedPayload, String primaryCode) {
    for (final candidate in _candidateCodes(primaryCode)) {
      final (decrypted, isLegacy) = _crypto.decryptPayloadDetailed(encryptedPayload, candidate);
      if (decrypted != null) {
        return (decrypted, isLegacy, candidate);
      }
    }
    return (null, false, primaryCode);
  }

  /// Offloads multi-megabyte payload decryption to a background isolate when payload >= 2KB.
  Future<(String?, bool, String)> _decryptWithAnyTrustedCodeAsync(String encryptedPayload, String primaryCode) async {
    if (encryptedPayload.length < 2048) {
      return _decryptWithAnyTrustedCode(encryptedPayload, primaryCode);
    }
    final candidateCodes = _candidateCodes(primaryCode);
    return Isolate.run(() {
      for (final candidate in candidateCodes) {
        final (decrypted, isLegacy) = SyncCryptoService.instance.decryptPayloadDetailed(encryptedPayload, candidate);
        if (decrypted != null) {
          return (decrypted, isLegacy, candidate);
        }
      }
      return (null, false, primaryCode);
    });
  }

  Future<String> getDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedId = prefs.getString(_deviceIdStorageKey);
      if (storedId != null && storedId.isNotEmpty) {
        _deviceId = storedId;
        return _deviceId!;
      }
      _deviceId = const Uuid().v4();
      await prefs.setString(_deviceIdStorageKey, _deviceId!);
    } catch (_) {
      // Keep P2P usable if preference storage is unavailable in a test or recovery path.
      _deviceId = const Uuid().v4();
    }
    return _deviceId!;
  }

  /// Returns all usable local IPv4 addresses across active Wi-Fi, Mobile Hotspot,
  /// Wi-Fi Direct, USB/Bluetooth Tethering, and Ethernet interfaces, ordered by priority
  /// while filtering out Mobile Data (rmnet/ccmni/clat/CGNAT) and VPN tunnels.
  Future<List<String>> getAllLocalIpAddresses() async {
    final result = <String>[];
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      if (interfaces.isEmpty) return result;

      final sortedInterfaces = [...interfaces]
        ..removeWhere((iface) => scoreNetworkInterface(iface.name) < 0)
        ..sort((a, b) => scoreNetworkInterface(b.name).compareTo(scoreNetworkInterface(a.name)));

      for (final interface in sortedInterfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && !addr.isLinkLocal) {
            final ip = addr.address.trim();
            if (isUsableLocalP2pAddress(ip, interfaceName: interface.name) && !result.contains(ip)) {
              result.add(ip);
            }
          }
        }
      }
    } catch (_) {}
    return result;
  }

  /// Detects the primary local IPv4 Wi-Fi/Hotspot/Ethernet address, avoiding cellular (rmnet/CGNAT) or VPN interfaces.
  Future<String?> getLocalIpAddress() async {
    final all = await getAllLocalIpAddresses();
    return all.isNotEmpty ? all.first : null;
  }

  /// Scores network interface names so Wi-Fi, Mobile Hotspot, Wi-Fi Direct, and Tethering
  /// interfaces take priority while Mobile Data (rmnet/ccmni/clat) and VPNs (tun/wg/utun) are excluded.
  @visibleForTesting
  static int scoreNetworkInterface(String name) {
    final lower = name.trim().toLowerCase();
    // Exclude cellular / mobile data & 464XLAT clat interfaces first
    if (lower.startsWith('rmnet') ||
        lower.startsWith('v4-rmnet') ||
        lower.startsWith('rev_rmnet') ||
        lower.startsWith('ccmni') ||
        lower.startsWith('v4-ccmni') ||
        lower.startsWith('pdp') ||
        lower.startsWith('clat') ||
        lower.startsWith('wwan') ||
        lower.startsWith('cellular') ||
        lower.contains('rmnet') ||
        lower.contains('ccmni')) {
      return -50;
    }
    // Exclude virtual, container, and VPN tunnel interfaces
    if (lower.startsWith('dummy') ||
        lower.startsWith('tun') ||
        lower.startsWith('tap') ||
        lower.startsWith('utun') ||
        lower.startsWith('ipsec') ||
        lower.startsWith('ppp') ||
        lower.startsWith('wg') ||
        lower.startsWith('tailscale') ||
        lower.startsWith('docker') ||
        lower.startsWith('vbox') ||
        lower.startsWith('veth') ||
        lower.startsWith('virbr') ||
        lower.startsWith('lo')) {
      return -100;
    }
    // High priority: Wi-Fi & Mobile Hotspot AP interfaces
    if (lower.startsWith('wlan') ||
        lower.startsWith('swlan') ||
        lower.startsWith('ap') ||
        lower.startsWith('softap') ||
        lower.startsWith('wl') ||
        lower.contains('wifi') ||
        lower.contains('wi-fi') ||
        lower.contains('hotspot')) {
      return 100;
    }
    // High priority: Wi-Fi Direct (p2p-wlan0-0, p2p0), USB/Bluetooth Tethering & Hotspot bridges
    if (lower.startsWith('p2p') ||
        lower.startsWith('tether') ||
        lower.startsWith('rndis') ||
        lower.startsWith('ncm') ||
        lower.startsWith('bridge') ||
        lower.startsWith('bt-pan') ||
        lower.startsWith('bnep')) {
      return 90;
    }
    // Physical Ethernet interfaces (en0/en1, eth0)
    if (lower.startsWith('en') || lower.startsWith('eth')) {
      return 80;
    }
    return 10;
  }

  /// Validates whether an IPv4 address on [interfaceName] is a usable local P2P/Hotspot address
  /// rather than a loopback, link-local, 464XLAT (192.0.0.0/24), or Carrier-Grade NAT (100.64.0.0/10) address.
  @visibleForTesting
  static bool isUsableLocalP2pAddress(String ip, {String interfaceName = ''}) {
    final trimmed = ip.trim();
    if (trimmed.isEmpty) return false;
    if (interfaceName.isNotEmpty && scoreNetworkInterface(interfaceName) < 0) {
      return false;
    }
    if (trimmed.startsWith('127.') ||
        trimmed.startsWith('0.') ||
        trimmed.startsWith('169.254.') ||
        trimmed.startsWith('192.0.0.')) {
      return false;
    }
    final parts = trimmed.split('.');
    if (parts.length == 4) {
      final first = int.tryParse(parts[0]);
      final second = int.tryParse(parts[1]);
      // Filter RFC 6598 Carrier-Grade NAT (100.64.0.0/10 -> 100.64.x.x to 100.127.x.x)
      // commonly assigned by mobile cellular carriers.
      if (first == 100 && second != null && second >= 64 && second <= 127) {
        return false;
      }
    }
    return true;
  }

  /// Resolves the best routable IP for a discovered peer by prioritizing the kernel-verified
  /// socket [senderIp] over self-reported payload IPs when [senderIp] is a valid non-loopback address.
  @visibleForTesting
  static String resolvePeerEffectiveIp({
    required String senderIp,
    String? reportedIp,
    List<String> localIps = const [],
  }) {
    final cleanSender = sanitizeTargetIp(_normalizeClientIp(senderIp));
    final cleanReported = (reportedIp != null && reportedIp.trim().isNotEmpty)
        ? sanitizeTargetIp(reportedIp.trim())
        : '';

    // If the packet arrived from a usable non-loopback LAN/Hotspot IP, prefer the actual socket source IP
    // unless the reported IP is on the exact same /24 subnet as one of our local interfaces and senderIp is not.
    if (isUsableLocalP2pAddress(cleanSender)) {
      if (cleanReported.isEmpty || !isUsableLocalP2pAddress(cleanReported)) {
        return cleanSender;
      }
      if (localIps.isNotEmpty) {
        final senderMatchesLocalSubnet = localIps.any((lip) => _sameIpv4Subnet24(lip, cleanSender));
        final reportedMatchesLocalSubnet = localIps.any((lip) => _sameIpv4Subnet24(lip, cleanReported));
        if (senderMatchesLocalSubnet && !reportedMatchesLocalSubnet) {
          return cleanSender;
        }
      }
      return cleanSender;
    }

    if (cleanReported.isNotEmpty && isUsableLocalP2pAddress(cleanReported)) {
      return cleanReported;
    }
    return cleanReported.isNotEmpty ? cleanReported : cleanSender;
  }

  static bool _sameIpv4Subnet24(String ipA, String ipB) {
    final a = ipA.split('.');
    final b = ipB.split('.');
    if (a.length != 4 || b.length != 4) return false;
    return a[0] == b[0] && a[1] == b[1] && a[2] == b[2];
  }

  /// System hardware diagnostics for local Wi-Fi, Hotspot & IP interfaces.
  Future<SystemDiagnostics> runDiagnostics() async {
    final allIps = await getAllLocalIpAddresses();
    final ip = allIps.isNotEmpty ? allIps.first : null;
    return SystemDiagnostics(
      wifiConnected: ip != null,
      localIp: ip,
      allLocalIps: allIps,
    );
  }

  /// Starts the Primary Host HTTP Server & UDP Radio Beacon.
  ///
  /// Explicitly binds `InternetAddress.anyIPv4` (`0.0.0.0:8765`) as the primary socket so
  /// Android kernels with `net.ipv6.bindv6only=1` never reject IPv4 LAN connections (`192.168.x.x`),
  /// and optionally binds a separate `v6Only: true` IPv6 listener alongside it.
  Future<void> startPrimaryHostServer(String userName, String pairCode) async {
    while (_serverTransitionFuture != null) {
      await _serverTransitionFuture;
    }
    final completer = Completer<void>();
    _serverTransitionFuture = completer.future;
    try {
      await _stopPrimaryHostServerInternal();
      try {
        try {
          _httpServer = await HttpServer.bind(
            InternetAddress.anyIPv4,
            httpSyncPort,
          );
        } catch (_) {
          _httpServer = await HttpServer.bind(
            InternetAddress.anyIPv4,
            httpSyncPort,
            shared: true,
          );
        }
        _httpServer!.listen(
          (HttpRequest request) async {
            await _handlePrimaryHttpRequest(request, pairCode, userName);
          },
          onError: (Object error) {
            debugPrint('[P2pSyncService] HTTP Server stream error: $error');
          },
          onDone: () {
            _isHosting = false;
          },
          cancelOnError: false,
        );

        // Optional independent IPv6 listener (v6Only: true so it never conflicts with IPv4 0.0.0.0)
        try {
          _httpServerV6 = await HttpServer.bind(
            InternetAddress.anyIPv6,
            httpSyncPort,
            v6Only: true,
          );
          _httpServerV6!.listen(
            (HttpRequest request) async {
              await _handlePrimaryHttpRequest(request, pairCode, userName);
            },
            onError: (_) {},
            cancelOnError: false,
          );
        } catch (_) {}

        _isHosting = true;
        debugPrint('[P2pSyncService] Primary Host Server listening on 0.0.0.0:$httpSyncPort');

        await startUdpBeacon(userName, pairCode);
        unawaited(
          P2pRelaySyncService.instance.startRelayHostListener(
            deviceName: userName,
            primaryPairCode: pairCode,
            trustedPairCodes: _candidateCodes(pairCode),
          ),
        );
      } catch (e) {
        _isHosting = false;
        debugPrint('[P2pSyncService] Primary Host Server bind error: $e');
      }
    } finally {
      _serverTransitionFuture = null;
      completer.complete();
    }
  }

  /// Verifies that the local HTTP host server on port 8765 is genuinely alive and accepting TCP
  /// connections (detecting zombie sockets frozen or closed by OS background suspension).
  Future<bool> verifyLocalServerAlive() async {
    if (!_isHosting || _httpServer == null) return false;
    try {
      final socket = await Socket.connect(
        '127.0.0.1',
        httpSyncPort,
        timeout: const Duration(milliseconds: 400),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Ensures the Primary Host Server is actively accepting connections, re-binding if the OS
  /// suspended the socket while the device was asleep or in the background.
  Future<void> ensureHostServerRunning(String userName, String pairCode) async {
    final alive = await verifyLocalServerAlive();
    if (!alive) {
      await startPrimaryHostServer(userName, pairCode);
    } else {
      await startUdpBeacon(userName, pairCode);
      unawaited(
        P2pRelaySyncService.instance.startRelayHostListener(
          deviceName: userName,
          primaryPairCode: pairCode,
          trustedPairCodes: _candidateCodes(pairCode),
        ),
      );
    }
  }

  /// Stops Primary Host Server & UDP Beacon.
  Future<void> stopPrimaryHostServer() async {
    while (_serverTransitionFuture != null) {
      await _serverTransitionFuture;
    }
    final completer = Completer<void>();
    _serverTransitionFuture = completer.future;
    try {
      await _stopPrimaryHostServerInternal();
    } finally {
      _serverTransitionFuture = null;
      completer.complete();
    }
  }

  Future<void> _stopPrimaryHostServerInternal() async {
    try {
      _beaconTimer?.cancel();
      _beaconTimer = null;
      _udpSocket?.close();
      _udpSocket = null;
      await _httpServer?.close(force: true);
      _httpServer = null;
      await _httpServerV6?.close(force: true);
      _httpServerV6 = null;
      _isHosting = false;
      await P2pRelaySyncService.instance.stopRelayHostListener();
    } catch (_) {}
  }

  /// Starts UDP Radio Beacon on port 8766 (with LocalSend 224.0.0.167 Multicast + Multi-Subnet Broadcast).
  Future<void> startUdpBeacon(String userName, String pairCode) async {
    _beaconTimer?.cancel();
    _beaconTimer = null;
    try {
      _udpSocket?.close();
      // Note: Do NOT pass reusePort: true here — Dart's RawDatagramSocket.bind throws
      // SocketException on Android when reusePort is true, killing UDP discovery.
      try {
        _udpSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          udpBeaconPort,
          reuseAddress: true,
        );
      } catch (_) {
        _udpSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          udpBeaconPort,
        );
      }
      _udpSocket!.broadcastEnabled = true;
      try {
        _udpSocket!.multicastLoopback = false;
      } catch (_) {}
      await _joinMulticastOnAllInterfaces();

      _udpSocket!.listen(
        (RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            final datagram = _udpSocket?.receive();
            if (datagram != null) {
              _handleUdpDatagram(datagram, pairCode, userName);
            }
          }
        },
        onError: (Object error) {
          debugPrint('[P2pSyncService] UDP Beacon socket error: $error');
        },
        cancelOnError: false,
      );

      // Broadcast an immediate beacon & HTTP gateway probe on start, then every 2 seconds
      unawaited(broadcastUdpBeacon(userName, pairCode));
      unawaited(probeHttpDiscovery(userName));
      int tick = 0;
      _beaconTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        tick++;
        await broadcastUdpBeacon(userName, pairCode);
        // Probe HTTP gateway every 6 seconds to support hotspots that block UDP completely
        if (tick % 3 == 0) {
          unawaited(probeHttpDiscovery(userName));
        }
      });
    } catch (e) {
      debugPrint('[P2pSyncService] UDP Beacon error: $e');
    }
  }

  Future<void> _joinMulticastOnAllInterfaces() async {
    if (_udpSocket == null) return;
    final multicastAddr = InternetAddress(udpMulticastGroup);
    try {
      _udpSocket!.joinMulticast(multicastAddr);
    } catch (_) {}
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final iface in interfaces) {
        if (scoreNetworkInterface(iface.name) >= 0) {
          try {
            _udpSocket!.joinMulticast(multicastAddr, iface);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> broadcastUdpBeacon(String userName, String pairCode) async {
    if (_udpSocket == null) return;
    try {
      final ips = await getAllLocalIpAddresses();
      final primaryIp = ips.isNotEmpty ? ips.first : null;
      final myDeviceId = await getDeviceId();

      // 1. Broadcast open presence beacon (LocalSend pattern: allows nearby devices to populate the discovery list)
      final presenceMap = {
        'action': 'presence',
        'deviceId': myDeviceId,
        'deviceName': userName,
        'ip': primaryIp ?? '',
        'ips': ips,
        'port': httpSyncPort,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final presenceData = utf8.encode(json.encode(presenceMap));
      _sendUdpBroadcast(presenceData, ips);

      // 2. Broadcast encrypted beacon for pre-paired devices (without pairCode reflection)
      final beaconMap = {
        'action': 'beacon',
        'role': 'PRIMARY',
        'deviceId': myDeviceId,
        'deviceName': userName,
        'ip': primaryIp ?? '',
        'ips': ips,
        'port': httpSyncPort,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final encrypted = _crypto.encryptPayload(json.encode(beaconMap), pairCode);
      if (encrypted != null) {
        _sendUdpBroadcast(utf8.encode(encrypted), ips);
      }
    } catch (_) {}
  }

  void _sendUdpBroadcast(List<int> data, List<String> localIps) {
    if (_udpSocket == null) return;
    final targets = <String>{
      udpMulticastGroup, // 224.0.0.167 Link-Local Multicast (LocalSend standard)
      '255.255.255.255', // Global broadcast
    };
    for (final ip in localIps) {
      if (ip.contains('.')) {
        final parts = ip.split('.');
        if (parts.length == 4) {
          final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
          targets.add('$prefix.255'); // Directed subnet broadcast
          // Also send direct unicast to the subnet gateway (.1) when this device is a hotspot client,
          // bypassing Android/iOS hotspot broadcast filtering!
          final gateway = '$prefix.1';
          if (ip != gateway) {
            targets.add(gateway);
          }
        }
      }
    }
    for (final target in targets) {
      try {
        _udpSocket!.send(data, InternetAddress(target), udpBeaconPort);
      } catch (_) {}
    }
  }

  void _sendUnicastUdpReply(InternetAddress targetAddress, String userName, String pairCode) async {
    if (_udpSocket == null) return;
    try {
      final ips = await getAllLocalIpAddresses();
      final primaryIp = ips.isNotEmpty ? ips.first : null;
      final myDeviceId = await getDeviceId();
      final replyMap = {
        'action': 'presence',
        'isReply': true,
        'deviceId': myDeviceId,
        'deviceName': userName,
        'ip': primaryIp ?? '',
        'ips': ips,
        'port': httpSyncPort,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      _udpSocket?.send(utf8.encode(json.encode(replyMap)), targetAddress, udpBeaconPort);
    } catch (_) {}
  }

  /// Races multiple candidate LAN IPs in parallel ("Happy Eyeballs" RFC 8305 pattern) and returns
  /// the first IP address that completes a TCP handshake on [port] within [timeout].
  Future<String?> probeFastestReachableIp(
    List<String> candidateIps, {
    int port = httpSyncPort,
    Duration timeout = const Duration(milliseconds: 2200),
  }) async {
    final validIps = candidateIps
        .map(sanitizeTargetIp)
        .where((ip) => ip.isNotEmpty && ip.toLowerCase() != 'relay' && !ip.startsWith('relay://'))
        .toSet()
        .toList();
    if (validIps.isEmpty) return null;
    if (validIps.length == 1) return validIps.first;

    final completer = Completer<String?>();
    int remaining = validIps.length;
    for (final ip in validIps) {
      unawaited(
        Socket.connect(ip, port, timeout: timeout).then((socket) {
          socket.destroy();
          if (!completer.isCompleted) {
            completer.complete(ip);
          }
        }).catchError((_) {
          remaining--;
          if (remaining <= 0 && !completer.isCompleted) {
            completer.complete(null);
          }
        }),
      );
    }
    return completer.future.timeout(timeout + const Duration(milliseconds: 200), onTimeout: () => null);
  }

  /// Probes subnet gateways (e.g. Hotspot host `.1` IPs), optional known peer IPs, and optionally
  /// performs a LocalSend-style fast parallel `/24` TCP subnet sweep (`fullSubnetScan: true`) over
  /// `/api/sync/discover` so devices discover each other even when 100% of UDP traffic is blocked.
  Future<void> probeHttpDiscovery(
    String userName, {
    Iterable<String> extraTargetIps = const [],
    bool fullSubnetScan = false,
  }) async {
    try {
      final localIps = await getAllLocalIpAddresses();
      final myDeviceId = await getDeviceId();
      final candidateIps = <String>{};

      for (final ip in localIps) {
        final parts = ip.split('.');
        if (parts.length == 4) {
          final gateway = '${parts[0]}.${parts[1]}.${parts[2]}.1';
          if (ip != gateway) {
            candidateIps.add(gateway);
          }
        }
      }
      for (final extra in extraTargetIps) {
        final clean = sanitizeTargetIp(extra);
        if (isUsableLocalP2pAddress(clean) && !localIps.contains(clean)) {
          candidateIps.add(clean);
        }
      }

      if (fullSubnetScan && localIps.isNotEmpty) {
        final primaryParts = localIps.first.split('.');
        if (primaryParts.length == 4) {
          final prefix = '${primaryParts[0]}.${primaryParts[1]}.${primaryParts[2]}';
          final openSubnetIps = <String>[];
          const batchSize = 50;
          for (int start = 1; start <= 254; start += batchSize) {
            final end = (start + batchSize - 1 <= 254) ? start + batchSize - 1 : 254;
            final batchFutures = <Future<void>>[];
            for (int host = start; host <= end; host++) {
              final ip = '$prefix.$host';
              if (localIps.contains(ip) || candidateIps.contains(ip)) continue;
              batchFutures.add(
                Socket.connect(ip, httpSyncPort, timeout: const Duration(milliseconds: 280)).then((s) {
                  s.destroy();
                  openSubnetIps.add(ip);
                }).catchError((_) {}),
              );
            }
            await Future.wait(batchFutures);
          }
          candidateIps.addAll(openSubnetIps);
        }
      }

      if (candidateIps.isEmpty) return;

      final payload = json.encode({
        'action': 'discover',
        'deviceId': myDeviceId,
        'deviceName': userName,
        'ip': localIps.isNotEmpty ? localIps.first : '',
        'ips': localIps,
        'port': httpSyncPort,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await Future.wait(
        candidateIps.map((targetIp) async {
          final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 1200);
          try {
            final req = await client.postUrl(buildSyncUri(targetIp, httpSyncPort, '/api/sync/discover'));
            req.headers.contentType = ContentType.json;
            req.write(payload);
            final res = await req.close().timeout(const Duration(milliseconds: 1500));
            if (res.statusCode == HttpStatus.ok) {
              final body = await utf8.decoder.bind(res).join().timeout(const Duration(milliseconds: 1500));
              final decoded = json.decode(body);
              if (decoded is Map<String, dynamic>) {
                final peerId = decoded['deviceId'] as String?;
                if (peerId != null && peerId.isNotEmpty && peerId != myDeviceId) {
                  final peerName = decoded['deviceName'] as String? ?? 'Nearby Device';
                  final peerPort = decoded['port'] is int ? decoded['port'] as int : httpSyncPort;
                  _discoveredPeersController.add(DiscoveredPeer(
                    deviceId: peerId,
                    deviceName: peerName,
                    ipAddress: targetIp,
                    port: peerPort,
                    lastSeenAt: DateTime.now(),
                  ));
                }
              }
            } else {
              await res.drain<void>().catchError((_) {});
            }
          } catch (_) {
          } finally {
            client.close(force: true);
          }
        }),
      );
    } catch (_) {}
  }

  void _handleUdpDatagram(Datagram datagram, String pairCode, [String userName = 'Nearby Device']) async {
    try {
      final message = utf8.decode(datagram.data);
      final myDeviceId = await getDeviceId();
      final senderIp = _normalizeClientIp(datagram.address.address);
      final localIps = await getAllLocalIpAddresses();

      // 1. Check for public presence beacon (unencrypted)
      try {
        final decoded = json.decode(message);
        if (decoded is Map<String, dynamic> && decoded['action'] == 'presence') {
          final senderDeviceId = decoded['deviceId'] as String?;
          final senderName = decoded['deviceName'] as String? ?? 'Nearby Device';
          final port = decoded['port'] is int ? decoded['port'] as int : httpSyncPort;
          if (senderDeviceId != null && senderDeviceId != myDeviceId) {
            final effectiveIp = resolvePeerEffectiveIp(
              senderIp: senderIp,
              reportedIp: decoded['ip'] as String?,
              localIps: localIps,
            );
            _discoveredPeersController.add(DiscoveredPeer(
              deviceId: senderDeviceId,
              deviceName: senderName,
              ipAddress: effectiveIp,
              port: port,
              lastSeenAt: DateTime.now(),
            ));
            // Send direct unicast reply if this was an initial broadcast/multicast announcement
            if (decoded['isReply'] != true) {
              _sendUnicastUdpReply(datagram.address, userName, pairCode);
            }
          }
          return;
        }
      } catch (_) {}

      // 2. Check for encrypted beacon / handshake against primary or any trusted paired code
      final (decrypted, _, matchedCode) = _decryptWithAnyTrustedCode(message, pairCode);
      if (decrypted == null) return;

      final Map<String, dynamic> map = json.decode(decrypted);
      final senderDeviceId = map['deviceId'] as String?;
      final senderName = map['deviceName'] as String? ?? PairedDevice.generateRandomName();

      if (senderDeviceId == null || senderDeviceId == myDeviceId) return;

      final effectiveIp = resolvePeerEffectiveIp(
        senderIp: senderIp,
        reportedIp: map['ip'] as String?,
        localIps: localIps,
      );
      final effectivePort = map['port'] is int ? map['port'] as int : httpSyncPort;

      if (map['action'] == 'beacon') {
        // Emit as a discovered peer so already-paired devices update their endpoint IP/lastSeenAt
        // without fabricating a fake lastSyncedAt timestamp or clobbering their paired role.
        _discoveredPeersController.add(DiscoveredPeer(
          deviceId: senderDeviceId,
          deviceName: senderName,
          ipAddress: effectiveIp,
          port: effectivePort,
          lastSeenAt: DateTime.now(),
        ));
        if (map['isReply'] != true) {
          _sendUnicastUdpReply(datagram.address, userName, pairCode);
        }
      } else if (map['action'] == 'pair_handshake') {
        final remoteDevice = PairedDevice(
          deviceId: senderDeviceId,
          deviceName: senderName,
          pairCode: matchedCode,
          lastSyncedAt: null,
          transportMode: 'Primary Direct Sync',
          endpoints: [
            DeviceEndpoint(
              ipAddress: effectiveIp,
              port: effectivePort,
              lastSeenAt: DateTime.now(),
            ),
          ],
          role: map['role'] as String? ?? 'PRIMARY',
        );
        _remoteDevicePairedController.add(remoteDevice);
      }
    } catch (_) {}
  }

  static final Map<String, List<int>> _failedAuthAttemptsByIp = {};

  static bool _isIpRateLimited(String ip) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final attempts = _failedAuthAttemptsByIp[ip];
    if (attempts == null) return false;
    attempts.removeWhere((ts) => now - ts > 60000);
    return attempts.length >= 25;
  }

  static void _recordFailedAuth(String ip) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final attempts = _failedAuthAttemptsByIp.putIfAbsent(ip, () => []);
    attempts.add(now);
  }

  static void _clearFailedAuth(String ip) {
    _failedAuthAttemptsByIp.remove(ip);
  }

  /// Normalizes IPv4-mapped IPv6 addresses (e.g. `::ffff:192.168.1.15` -> `192.168.1.15`).
  static String _normalizeClientIp(String rawIp) {
    final trimmed = rawIp.trim();
    if (trimmed.toLowerCase().startsWith('::ffff:')) {
      return trimmed.substring(7);
    }
    return trimmed;
  }

  /// Handles HTTP Requests on Primary Host Server.
  Future<void> _handlePrimaryHttpRequest(HttpRequest request, String pairCode, String userName) async {
    final response = request.response;
    response.headers.contentType = ContentType.json;

    final clientIp = _normalizeClientIp(request.connectionInfo?.remoteAddress.address ?? 'unknown');
    if (_isIpRateLimited(clientIp)) {
      await request.drain<void>().catchError((_) {});
      response.statusCode = HttpStatus.tooManyRequests;
      response.write(json.encode({'error': 'Rate limited due to repeated failed authentication attempts.'}));
      await response.close();
      return;
    }

    // Guard against memory exhaustion from oversized payloads (25MB limit)
    const int maxPayloadBytes = 25 * 1024 * 1024;
    if (request.contentLength > maxPayloadBytes) {
      await request.drain<void>().catchError((_) {});
      response.statusCode = HttpStatus.requestEntityTooLarge;
      response.write(json.encode({'error': 'Payload exceeds 25MB limit'}));
      await response.close();
      return;
    }

    Future<String?> readBoundedBody() async {
      final chunks = <List<int>>[];
      int totalBytes = 0;
      await for (final chunk in request.timeout(const Duration(seconds: 30))) {
        totalBytes += chunk.length;
        if (totalBytes > maxPayloadBytes) {
          return null;
        }
        chunks.add(chunk);
      }
      return utf8.decode(chunks.expand((c) => c).toList());
    }

    try {
      final path = request.uri.path;

      // 0. Open Discovery Handshake (LocalSend HTTP Fallback for Hotspots / UDP-Blocked Networks)
      if (path == '/api/sync/discover') {
        final body = await readBoundedBody();
        if (body != null && body.trim().isNotEmpty) {
          try {
            final caller = json.decode(body);
            if (caller is Map<String, dynamic>) {
              final callerId = caller['deviceId'] as String?;
              final myId = await getDeviceId();
              if (callerId != null && callerId.isNotEmpty && callerId != myId) {
                final callerName = caller['deviceName'] as String? ?? 'Nearby Device';
                final callerPort = caller['port'] is int ? caller['port'] as int : httpSyncPort;
                final localIps = await getAllLocalIpAddresses();
                final effectiveIp = resolvePeerEffectiveIp(
                  senderIp: clientIp,
                  reportedIp: caller['ip'] as String?,
                  localIps: localIps,
                );
                if (effectiveIp.isNotEmpty && effectiveIp != 'unknown') {
                  _discoveredPeersController.add(DiscoveredPeer(
                    deviceId: callerId,
                    deviceName: callerName,
                    ipAddress: effectiveIp,
                    port: callerPort,
                    lastSeenAt: DateTime.now(),
                  ));
                }
              }
            }
          } catch (_) {}
        }
        final ips = await getAllLocalIpAddresses();
        response.statusCode = HttpStatus.ok;
        response.write(json.encode({
          'action': 'presence',
          'deviceId': await getDeviceId(),
          'deviceName': userName,
          'ip': ips.isNotEmpty ? ips.first : '',
          'ips': ips,
          'port': httpSyncPort,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }));
      }
      // 1. Direct Ping
      else if (path == '/api/sync/ping') {
        final body = await readBoundedBody();
        if (body == null) {
          response.statusCode = HttpStatus.requestEntityTooLarge;
          return;
        }
        final (decrypted, isLegacy, matchedCode) = _decryptWithAnyTrustedCode(body, pairCode);
        if (decrypted != null) {
          _clearFailedAuth(clientIp);
          final reqMap = json.decode(decrypted);
          final reply = _crypto.encryptPayload(
            json.encode({
              'status': 'pong',
              'clientTime': reqMap['timestamp'],
              'serverTime': DateTime.now().millisecondsSinceEpoch,
              'hostName': userName,
            }),
            matchedCode,
            legacyMode: isLegacy,
          );
          response.statusCode = HttpStatus.ok;
          response.write(reply);
        } else {
          _recordFailedAuth(clientIp);
          response.statusCode = HttpStatus.unauthorized;
        }
      } 
      // 2. Pair Handshake
      else if (path == '/api/sync/pair_handshake') {
        final body = await readBoundedBody();
        if (body == null) {
          response.statusCode = HttpStatus.requestEntityTooLarge;
          return;
        }
        final (decrypted, isLegacy, matchedCode) = _decryptWithAnyTrustedCode(body, pairCode);
        if (decrypted != null) {
          _clearFailedAuth(clientIp);
          final Map<String, dynamic> map = json.decode(decrypted);
          final remoteDevice = PairedDevice(
            deviceId: map['deviceId'] ?? const Uuid().v4(),
            deviceName: map['deviceName'] ?? PairedDevice.generateRandomName(),
            pairCode: matchedCode,
            lastSyncedAt: null,
            transportMode: 'Primary Direct Sync',
            endpoints: [
              DeviceEndpoint(
                ipAddress: clientIp == 'unknown' ? '' : clientIp,
                port: map['port'] is int ? map['port'] as int : httpSyncPort,
                lastSeenAt: DateTime.now(),
              ),
            ],
            role: 'SECONDARY',
          );
          _remoteDevicePairedController.add(remoteDevice);

          final ackReply = _crypto.encryptPayload(
            json.encode({
              'action': 'pair_ack',
              'deviceId': await getDeviceId(),
              'deviceName': userName,
              'role': 'PRIMARY',
              'port': httpSyncPort,
            }),
            matchedCode,
            legacyMode: isLegacy,
          );
          response.statusCode = HttpStatus.ok;
          response.write(ackReply);
        } else {
          _recordFailedAuth(clientIp);
          response.statusCode = HttpStatus.unauthorized;
        }
      } 
      // 3. Pull Master Snapshot (1-Way Fallback)
      else if (path == '/api/sync/pull_master') {
        final body = await readBoundedBody();
        if (body == null) {
          response.statusCode = HttpStatus.requestEntityTooLarge;
          return;
        }
        final (decrypted, isLegacy, matchedCode) = await _decryptWithAnyTrustedCodeAsync(body, pairCode);
        if (decrypted != null) {
          _clearFailedAuth(clientIp);
          final backupJson = await generateBackupJson();
          final encryptedReply = await _crypto.encryptPayloadAsync(backupJson, matchedCode, legacyMode: isLegacy);

          response.statusCode = HttpStatus.ok;
          response.write(encryptedReply);

          _syncEventsController.add(SyncResult(
            success: true,
            syncedCount: 1,
            receivedCount: 0,
            sentCount: 1,
            transportUsed: 'Primary Master Export',
            isServerInbound: true,
          ));
        } else {
          _recordFailedAuth(clientIp);
          response.statusCode = HttpStatus.unauthorized;
        }
      } 
      // 4. Bi-Directional Delta Merge (Non-Destructive 2-Way Sync)
      else if (path == '/api/sync/bidirectional_sync') {
        if (_isSyncing) {
          await request.drain<void>().catchError((_) {});
          response.statusCode = HttpStatus.serviceUnavailable;
          response.write(json.encode({'error': 'Device is currently synchronizing. Please retry shortly.'}));
          return;
        }
        _isSyncing = true;
        try {
          final body = await readBoundedBody();
          if (body == null) {
            response.statusCode = HttpStatus.requestEntityTooLarge;
            return;
          }
          final (decrypted, isLegacy, matchedCode) = await _decryptWithAnyTrustedCodeAsync(body, pairCode);
          if (decrypted != null) {
            _clearFailedAuth(clientIp);
            final Map<String, dynamic> clientData = json.decode(decrypted);

            // 1. Merge client data into host database
            final mergeResult = await SyncMergeService.instance.mergeRemoteData(clientData);
            if (mergeResult.totalMerged > 0) {
              FinancialManagerScreen.refreshNotifier.value = DateTime.now().millisecondsSinceEpoch;
            }

            // 2. Generate updated host payload for client
            final updatedBackupJson = await generateBackupJson();
            final encryptedReply = await _crypto.encryptPayloadAsync(updatedBackupJson, matchedCode, legacyMode: isLegacy);

            response.statusCode = HttpStatus.ok;
            response.write(encryptedReply);

            _syncEventsController.add(SyncResult(
              success: true,
              syncedCount: mergeResult.totalMerged,
              receivedCount: mergeResult.totalMerged,
              sentCount: 1,
              transportUsed: 'Bi-Directional Delta Merge',
              isServerInbound: true,
            ));
          } else {
            _recordFailedAuth(clientIp);
            response.statusCode = HttpStatus.unauthorized;
          }
        } finally {
          _isSyncing = false;
        }
      } else {
        response.statusCode = HttpStatus.notFound;
      }
    } catch (e) {
      response.statusCode = HttpStatus.internalServerError;
    } finally {
      await response.close();
    }
  }

  /// Parses target address which might contain scheme (http://), port (:8765), or whitespace.
  static (String, int) parseTargetAddress(String input, [int defaultPort = httpSyncPort]) {
    var trimmed = input.trim();
    if (trimmed.startsWith('http://')) {
      trimmed = trimmed.substring(7);
    } else if (trimmed.startsWith('https://')) {
      trimmed = trimmed.substring(8);
    }
    if (trimmed.contains('/')) {
      trimmed = trimmed.split('/').first;
    }

    // Bracketed IPv6 format: [fe80::1]:8765 or [fe80::1]
    if (trimmed.startsWith('[')) {
      final closeIdx = trimmed.indexOf(']');
      if (closeIdx != -1) {
        final ip = trimmed.substring(1, closeIdx);
        final rest = trimmed.substring(closeIdx + 1);
        final portCandidate = rest.startsWith(':')
            ? (int.tryParse(rest.substring(1)) ?? defaultPort)
            : defaultPort;
        final port = (portCandidate > 0 && portCandidate <= 65535) ? portCandidate : defaultPort;
        return (ip, port);
      }
    }

    // Standard IPv4:port
    if (trimmed.contains(':') && !trimmed.contains('::')) {
      final parts = trimmed.split(':');
      final portCandidate = int.tryParse(parts.last) ?? defaultPort;
      final port = (portCandidate > 0 && portCandidate <= 65535) ? portCandidate : defaultPort;
      final ip = parts.first.trim();
      return (ip, port);
    }
    return (trimmed, defaultPort);
  }

  /// Sanitizes IP string by removing scheme, trailing path, or port.
  static String sanitizeTargetIp(String input) => parseTargetAddress(input).$1;

  /// Safely constructs a HTTP URI for local P2P sync, wrapping IPv6 addresses in brackets.
  static Uri buildSyncUri(String ip, int port, String path) {
    final clean = ip.trim();
    final host = clean.contains(':') && !clean.startsWith('[') ? '[$clean]' : clean;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('http://$host:$port$normalizedPath');
  }

  /// Sends pair handshake to Primary Device IP, with optional Cross-Network E2EE Relay fallback
  /// when local Wi-Fi has AP Client Isolation or devices are on different networks / Mobile Data.
  Future<PairedDevice?> sendPairHandshake(
    String pairCode,
    String myDeviceName,
    String targetIp, {
    int targetPort = httpSyncPort,
    bool allowRelayFallback = true,
  }) async {
    final trimmedTarget = targetIp.trim();
    final isExplicitRelayTarget = trimmedTarget.isEmpty ||
        trimmedTarget.toLowerCase() == 'relay' ||
        trimmedTarget.startsWith('relay://');

    final myDeviceId = await getDeviceId();
    final handshakeMap = {
      'action': 'pair_handshake',
      'deviceId': myDeviceId,
      'deviceName': myDeviceName,
      'pairCode': pairCode,
      'role': 'PEER',
      'port': httpSyncPort,
    };

    Future<PairedDevice?> attemptRelayHandshake() async {
      final relayReply = await P2pRelaySyncService.instance.sendEncryptedRelayRpc(
        pairCode: pairCode,
        plaintextJson: json.encode(handshakeMap),
        timeout: const Duration(seconds: 10),
      );
      if (relayReply == null) return null;
      final Map<String, dynamic> map = json.decode(relayReply);
      final remoteId = map['deviceId'] as String? ?? const Uuid().v4();
      final remoteDevice = PairedDevice(
        deviceId: remoteId,
        deviceName: map['deviceName'] as String? ?? PairedDevice.generateRandomName(),
        pairCode: pairCode,
        lastSyncedAt: null,
        transportMode: 'Cross-Network E2EE Relay',
        endpoints: [
          if (!isExplicitRelayTarget)
            DeviceEndpoint(ipAddress: parseTargetAddress(targetIp, targetPort).$1, port: targetPort, lastSeenAt: DateTime.now()),
          DeviceEndpoint(
            ipAddress: 'relay://$remoteId',
            port: httpSyncPort,
            networkLabel: 'Cross-Network Relay',
            lastSeenAt: DateTime.now(),
          ),
        ],
        role: map['role'] as String? ?? 'PEER',
      );
      _remoteDevicePairedController.add(remoteDevice);
      return remoteDevice;
    }

    if (isExplicitRelayTarget) {
      final relayDevice = await attemptRelayHandshake();
      if (relayDevice != null) return relayDevice;
      throw StateError('Could not reach peer over Cross-Network Relay. Confirm the 6-digit pair code and internet connection.');
    }

    final parsed = parseTargetAddress(targetIp, targetPort);
    final cleanIp = parsed.$1;
    final cleanPort = parsed.$2;

    final connectTimeout = allowRelayFallback
        ? const Duration(milliseconds: 2800)
        : const Duration(seconds: 6);
    final client = HttpClient()..connectionTimeout = connectTimeout;
    try {
      // 1. Try standard PBKDF2 payload encryption
      var encrypted = _crypto.encryptPayload(json.encode(handshakeMap), pairCode);
      if (encrypted == null) {
        throw StateError('Failed to encrypt pair handshake payload. Check pair code.');
      }

      var req = await client.postUrl(buildSyncUri(cleanIp, cleanPort, '/api/sync/pair_handshake'));
      req.write(encrypted);
      var res = await req.close().timeout(const Duration(seconds: 10));

      // If server returned 401 Unauthorized, retry once with legacy v1 key in case peer is on older version
      if (res.statusCode == 401) {
        await res.drain<void>().catchError((_) {});
        final legacyEncrypted = _crypto.encryptPayload(json.encode(handshakeMap), pairCode, legacyMode: true);
        if (legacyEncrypted != null) {
          final retryReq = await client.postUrl(buildSyncUri(cleanIp, cleanPort, '/api/sync/pair_handshake'));
          retryReq.write(legacyEncrypted);
          res = await retryReq.close().timeout(const Duration(seconds: 10));
        }
      }

      if (res.statusCode == 200) {
        final body = await utf8.decoder.bind(res).join().timeout(const Duration(seconds: 10));
        final decrypted = _crypto.decryptPayload(body, pairCode);
        if (decrypted != null) {
          final Map<String, dynamic> map = json.decode(decrypted);
          final remoteId = map['deviceId'] as String? ?? const Uuid().v4();
          final remoteDevice = PairedDevice(
            deviceId: remoteId,
            deviceName: map['deviceName'] ?? PairedDevice.generateRandomName(),
            pairCode: pairCode,
            lastSyncedAt: null,
            transportMode: 'Bi-Directional Sync',
            endpoints: [
              DeviceEndpoint(ipAddress: cleanIp, port: cleanPort, lastSeenAt: DateTime.now()),
              DeviceEndpoint(
                ipAddress: 'relay://$remoteId',
                port: httpSyncPort,
                networkLabel: 'Cross-Network Relay',
                lastSeenAt: DateTime.now().subtract(const Duration(minutes: 1)),
              ),
            ],
            role: map['role'] as String? ?? 'PEER',
          );
          _remoteDevicePairedController.add(remoteDevice);
          return remoteDevice;
        } else {
          throw StateError('Handshake decryption failed. Ensure both devices share the exact same 6-digit pair code.');
        }
      } else {
        await res.drain<void>().catchError((_) {});
        if (res.statusCode == 401) {
          throw StateError('Pair code mismatch. Check the 6-digit code on the target device.');
        } else if (res.statusCode == 429) {
          throw StateError('Rate limited due to repeated attempts. Please wait 60 seconds and retry.');
        } else {
          throw StateError('Pairing failed (HTTP ${res.statusCode}) with $cleanIp.');
        }
      }
    } catch (e) {
      debugPrint('[P2pSyncService] Pair handshake direct IP error: $e');
      final errStr = e.toString();
      final isAuthOrRateError = errStr.contains('Pair code mismatch') || errStr.contains('Rate limited');
      if (allowRelayFallback && !isAuthOrRateError && cleanIp != '127.0.0.1' && cleanIp != 'localhost') {
        debugPrint('[P2pSyncService] Direct IP ($cleanIp) unreachable; attempting Cross-Network E2EE Relay fallback...');
        final relayDevice = await attemptRelayHandshake();
        if (relayDevice != null) return relayDevice;
      }
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  static String formatUserFriendlyErrorMessage(dynamic e, [String? targetIp]) {
    final str = e.toString();
    final ipSuffix = (targetIp != null && targetIp.isNotEmpty) ? ' ($targetIp)' : '';
    if (str.contains('Connection refused')) {
      return 'Peer device unreachable$ipSuffix — server not running. Please open Note Taking on the other device so its P2P Sync server is active.';
    } else if (str.contains('Operation not permitted') || str.contains('Permission denied')) {
      return 'Peer device unreachable$ipSuffix — local network permission blocked. Enable Local Network access in OS Settings or disable VPN.';
    } else if (str.contains('No route to host') || str.contains('Network is unreachable')) {
      return 'Peer device unreachable$ipSuffix — router AP Isolation or Guest Wi-Fi may be blocking direct traffic. Please open Note Taking on the other device or use Cross-Network Relay.';
    } else if (str.contains('SocketException')) {
      return 'Peer device unreachable$ipSuffix. Please open Note Taking on the other device, disable VPN, or use Cross-Network Relay.';
    } else if (str.contains('TimeoutException') || str.contains('timed out')) {
      return 'Connection timed out$ipSuffix. Ensure Note Taking is open and active on your peer device.';
    } else if (str.contains('HandshakeException') || str.contains('Pair Code mismatch') || str.contains('Pair code mismatch')) {
      return 'Pair code mismatch. Re-scan QR code or check 6-digit pair code.';
    } else if (str.contains('FormatException')) {
      return 'Unexpected data format received during sync.';
    }
    final firstLine = str.split('\n').first;
    return 'Sync error$ipSuffix: ${firstLine.length > 80 ? firstLine.substring(0, 80) : firstLine}';
  }

  String _formatUserFriendlyError(dynamic e, String targetIp) => formatUserFriendlyErrorMessage(e, targetIp);

  /// Sends a direct test ping with round-trip latency measurement (with Cross-Network E2EE Relay support).
  Future<SyncResult> sendTestPing(
    String targetIp,
    String pairCode, {
    int targetPort = httpSyncPort,
    bool allowRelayFallback = true,
  }) async {
    final trimmedTarget = targetIp.trim();
    final isExplicitRelayTarget = trimmedTarget.isEmpty ||
        trimmedTarget.toLowerCase() == 'relay' ||
        trimmedTarget.startsWith('relay://');

    final startTime = DateTime.now().millisecondsSinceEpoch;
    final pingMap = {
      'action': 'ping',
      'timestamp': startTime,
    };
    final rawJson = json.encode(pingMap);

    Future<SyncResult?> attemptRelayPing() async {
      final relayReply = await P2pRelaySyncService.instance.sendEncryptedRelayRpc(
        pairCode: pairCode,
        plaintextJson: rawJson,
        timeout: const Duration(seconds: 8),
      );
      if (relayReply == null) return null;
      final endTime = DateTime.now().millisecondsSinceEpoch;
      final result = SyncResult(
        success: true,
        syncedCount: 0,
        transportUsed: 'Cross-Network E2EE Relay',
        latencyMs: endTime - startTime,
      );
      _syncEventsController.add(result);
      return result;
    }

    if (isExplicitRelayTarget) {
      final relayRes = await attemptRelayPing();
      if (relayRes != null) return relayRes;
      final fail = SyncResult(success: false, errorMessage: 'Cross-Network Relay ping timed out.');
      _syncEventsController.add(fail);
      return fail;
    }

    final parsed = parseTargetAddress(targetIp, targetPort);
    final cleanIp = parsed.$1;
    final cleanPort = parsed.$2;

    try {
      final encrypted = _crypto.encryptPayload(rawJson, pairCode);
      if (encrypted == null) {
        return SyncResult(success: false, errorMessage: 'Encryption failed. Check pair code.');
      }

      final connectTimeout = allowRelayFallback
        ? const Duration(milliseconds: 2800)
        : const Duration(seconds: 6);
    final client = HttpClient()..connectionTimeout = connectTimeout;
      try {
        var req = await client.postUrl(buildSyncUri(cleanIp, cleanPort, '/api/sync/ping'));
        req.write(encrypted);
        var res = await req.close().timeout(const Duration(seconds: 8));

        // Automatic fallback to legacy v1 SHA-256 key if target device is on an older build
        if (res.statusCode == 401) {
          await res.drain<void>().catchError((_) {});
          final legacyEncrypted = _crypto.encryptPayload(rawJson, pairCode, legacyMode: true);
          if (legacyEncrypted != null) {
            final retryReq = await client.postUrl(buildSyncUri(cleanIp, cleanPort, '/api/sync/ping'));
            retryReq.write(legacyEncrypted);
            res = await retryReq.close().timeout(const Duration(seconds: 8));
          }
        }

        if (res.statusCode == 200) {
          final body = await utf8.decoder.bind(res).join().timeout(const Duration(seconds: 8));
          final decrypted = _crypto.decryptPayload(body, pairCode);
          if (decrypted != null) {
            final endTime = DateTime.now().millisecondsSinceEpoch;
            final latency = endTime - startTime;
            final result = SyncResult(
              success: true,
              syncedCount: 0,
              transportUsed: 'Direct IP ($cleanIp)',
              latencyMs: latency,
            );
            _syncEventsController.add(result);
            return result;
          } else {
            return SyncResult(success: false, errorMessage: 'Pair Code mismatch. Decryption failed for $cleanIp.');
          }
        }
        await res.drain<void>().catchError((_) {});
        if (res.statusCode == 401) {
          return SyncResult(success: false, errorMessage: 'Pair Code mismatch. Check 6-digit code on target device.');
        } else if (res.statusCode == 429) {
          return SyncResult(success: false, errorMessage: 'Rate limited due to repeated attempts. Please wait 60 seconds and retry.');
        }
        return SyncResult(success: false, errorMessage: 'Ping failed (HTTP ${res.statusCode}) from $cleanIp');
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      if (allowRelayFallback && cleanIp != '127.0.0.1' && cleanIp != 'localhost') {
        final relayRes = await attemptRelayPing();
        if (relayRes != null) return relayRes;
      }
      final res = SyncResult(success: false, errorMessage: _formatUserFriendlyError(e, cleanIp));
      _syncEventsController.add(res);
      return res;
    }
  }

  /// Secondary pulls master state from Primary and overwrites local DB 100%.
  Future<SyncResult> pullMasterFromPrimary(String targetIp, String pairCode, {int targetPort = httpSyncPort}) async {
    final parsed = parseTargetAddress(targetIp, targetPort);
    final cleanIp = parsed.$1;
    final cleanPort = parsed.$2;

    if (_isSyncing) {
      return SyncResult(success: false, errorMessage: 'Sync already in progress');
    }
    _isSyncing = true;

    try {
      final requestMap = {
        'action': 'pull_master',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final rawJson = json.encode(requestMap);
      final encrypted = await _crypto.encryptPayloadAsync(rawJson, pairCode);
      if (encrypted == null) {
        return SyncResult(success: false, errorMessage: 'Encryption error');
      }

      final regex = rawJson; // keep local scope distinct
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      if (regex.isEmpty) return SyncResult(success: false, errorMessage: 'Empty request');
      try {
        var req = await client.postUrl(buildSyncUri(cleanIp, cleanPort, '/api/sync/pull_master'));
        req.write(encrypted);
        var res = await req.close().timeout(const Duration(seconds: 30));

        if (res.statusCode == 401) {
          await res.drain<void>().catchError((_) {});
          final legacyEncrypted = await _crypto.encryptPayloadAsync(rawJson, pairCode, legacyMode: true);
          if (legacyEncrypted != null) {
            final retryReq = await client.postUrl(buildSyncUri(cleanIp, cleanPort, '/api/sync/pull_master'));
            retryReq.write(legacyEncrypted);
            res = await retryReq.close().timeout(const Duration(seconds: 30));
          }
        }

        if (res.statusCode == 200) {
          final responseBody = await utf8.decoder.bind(res).join().timeout(const Duration(seconds: 45));
          final decryptedReply = await _crypto.decryptPayloadAsync(responseBody, pairCode);
          if (decryptedReply != null) {
            final Map<String, dynamic> replyMap = json.decode(decryptedReply);
            
            // Complete Master Overwrite on Secondary Device
            await BackupService.restoreFromBackupData(replyMap);

            final syncRes = SyncResult(
              success: true,
              syncedCount: 1,
              receivedCount: 1,
              sentCount: 0,
              transportUsed: 'Primary Master Sync ($cleanIp)',
            );
            _syncEventsController.add(syncRes);
            return syncRes;
          }
        } else {
          await res.drain<void>().catchError((_) {});
        }
        return SyncResult(success: false, errorMessage: 'Failed to fetch master snapshot from $cleanIp (HTTP ${res.statusCode})');
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      final res = SyncResult(success: false, errorMessage: 'Master sync failed: $e');
      _syncEventsController.add(res);
      return res;
    } finally {
      _isSyncing = false;
    }
  }

  /// Performs non-destructive Bi-Directional Delta Merge with Target Peer Device
  /// (with automatic Cross-Network E2EE Relay fallback for AP Isolation or Mobile Data).
  Future<SyncResult> syncBiDirectional(
    String targetIp,
    String pairCode, {
    int targetPort = httpSyncPort,
    bool allowRelayFallback = true,
  }) async {
    final trimmedTarget = targetIp.trim();
    final isExplicitRelayTarget = trimmedTarget.isEmpty ||
        trimmedTarget.toLowerCase() == 'relay' ||
        trimmedTarget.startsWith('relay://');

    final parsed = parseTargetAddress(targetIp, targetPort);
    final cleanIp = parsed.$1;
    final cleanPort = parsed.$2;

    if (_isSyncing) {
      return SyncResult(success: false, errorMessage: 'Sync already in progress');
    }

    // Generate & encrypt local payload once before acquiring _isSyncing lock so that if
    // the remote peer is also syncing simultaneously, we can release _isSyncing during 503 backoff!
    final String clientBackupJson;
    final String? encrypted;
    try {
      clientBackupJson = await generateBackupJson();
      encrypted = await _crypto.encryptPayloadAsync(clientBackupJson, pairCode);
      if (encrypted == null) {
        return SyncResult(success: false, errorMessage: 'Encryption error');
      }
    } catch (e) {
      final res = SyncResult(success: false, errorMessage: _formatUserFriendlyError(e, cleanIp));
      _syncEventsController.add(res);
      return res;
    }

    Future<SyncResult?> attemptRelaySync() async {
      final Map<String, dynamic> relayPayloadMap = json.decode(clientBackupJson) as Map<String, dynamic>;
      relayPayloadMap['action'] = 'bidirectional_sync';
      final decryptedReply = await P2pRelaySyncService.instance.sendEncryptedRelayRpc(
        pairCode: pairCode,
        plaintextJson: json.encode(relayPayloadMap),
        timeout: const Duration(seconds: 25),
      );
      if (decryptedReply == null) return null;
      final Map<String, dynamic> replyMap = json.decode(decryptedReply);
      final mergeResult = await SyncMergeService.instance.mergeRemoteData(replyMap);
      if (mergeResult.totalMerged > 0) {
        FinancialManagerScreen.refreshNotifier.value = DateTime.now().millisecondsSinceEpoch;
      }
      final syncRes = SyncResult(
        success: true,
        syncedCount: mergeResult.totalMerged,
        receivedCount: mergeResult.totalMerged,
        sentCount: 1,
        transportUsed: 'Cross-Network E2EE Relay',
      );
      _syncEventsController.add(syncRes);
      return syncRes;
    }

    if (isExplicitRelayTarget) {
      _isSyncing = true;
      try {
        final relayRes = await attemptRelaySync();
        if (relayRes != null) return relayRes;
        final fail = SyncResult(
          success: false,
          errorMessage: 'Cross-Network Relay sync timed out. Ensure peer device has Everything App open.',
        );
        _syncEventsController.add(fail);
        return fail;
      } finally {
        _isSyncing = false;
      }
    }

    const int max503Retries = 2;
    for (int attempt = 0; attempt <= max503Retries; attempt++) {
      if (_isSyncing) {
        return SyncResult(success: false, errorMessage: 'Sync already in progress');
      }
      _isSyncing = true;

      final connectTimeout = allowRelayFallback
          ? const Duration(milliseconds: 2800)
          : const Duration(seconds: 8);
      final client = HttpClient()..connectionTimeout = connectTimeout;
      try {
        var req = await client.postUrl(buildSyncUri(cleanIp, cleanPort, '/api/sync/bidirectional_sync'));
        req.write(encrypted);
        var res = await req.close().timeout(const Duration(seconds: 45));

        // Automatic fallback to legacy v1 SHA-256 key if target device is on an older build
        if (res.statusCode == 401) {
          await res.drain<void>().catchError((_) {});
          final legacyEncrypted = await _crypto.encryptPayloadAsync(clientBackupJson, pairCode, legacyMode: true);
          if (legacyEncrypted != null) {
            final retryReq = await client.postUrl(buildSyncUri(cleanIp, cleanPort, '/api/sync/bidirectional_sync'));
            retryReq.write(legacyEncrypted);
            res = await retryReq.close().timeout(const Duration(seconds: 45));
          }
        }

        // If peer is currently busy syncing (e.g., simultaneous button press on Phone & Tablet),
        // release _isSyncing so the peer's request to us can complete, wait randomized jitter, and retry!
        if (res.statusCode == HttpStatus.serviceUnavailable && attempt < max503Retries) {
          await res.drain<void>().catchError((_) {});
          _isSyncing = false;
          final jitterMs = 450 + Random().nextInt(650) + (attempt * 400);
          await Future<void>.delayed(Duration(milliseconds: jitterMs));
          continue;
        }

        if (res.statusCode == 200) {
          final responseBody = await utf8.decoder.bind(res).join().timeout(const Duration(seconds: 45));
          final decryptedReply = await _crypto.decryptPayloadAsync(responseBody, pairCode);
          if (decryptedReply != null) {
            final Map<String, dynamic> replyMap = json.decode(decryptedReply);

            // Non-destructive Last-Write-Wins Merge on client device
            final mergeResult = await SyncMergeService.instance.mergeRemoteData(replyMap);
            if (mergeResult.totalMerged > 0) {
              FinancialManagerScreen.refreshNotifier.value = DateTime.now().millisecondsSinceEpoch;
            }

            final syncRes = SyncResult(
              success: true,
              syncedCount: mergeResult.totalMerged,
              receivedCount: mergeResult.totalMerged,
              sentCount: 1,
              transportUsed: 'Bi-Directional Delta Merge ($cleanIp)',
            );
            _syncEventsController.add(syncRes);
            return syncRes;
          } else {
            return SyncResult(success: false, errorMessage: 'Pair Code mismatch. Decryption failed for $cleanIp.');
          }
        }

        await res.drain<void>().catchError((_) {});
        if (res.statusCode == 401) {
          return SyncResult(success: false, errorMessage: 'Pair Code mismatch. Check 6-digit code on target device.');
        } else if (res.statusCode == 429) {
          return SyncResult(success: false, errorMessage: 'Rate limited due to repeated attempts. Please wait 60 seconds and retry.');
        } else if (res.statusCode == HttpStatus.serviceUnavailable) {
          return SyncResult(success: false, errorMessage: 'Peer device is busy synchronizing ($cleanIp). Please retry in a few seconds.');
        }
        return SyncResult(success: false, errorMessage: 'Sync failed (HTTP ${res.statusCode}) with $cleanIp');
      } catch (e) {
        if (allowRelayFallback && cleanIp != '127.0.0.1' && cleanIp != 'localhost') {
          debugPrint('[P2pSyncService] Direct sync ($cleanIp) failed ($e); trying Cross-Network E2EE Relay...');
          final relayRes = await attemptRelaySync();
          if (relayRes != null) return relayRes;
        }
        final res = SyncResult(success: false, errorMessage: _formatUserFriendlyError(e, cleanIp));
        _syncEventsController.add(res);
        return res;
      } finally {
        _isSyncing = false;
        client.close(force: true);
      }
    }
    return SyncResult(success: false, errorMessage: 'Sync failed with $cleanIp');
  }

  /// Background auto-sync trigger compatibility alias (uses Bi-Directional Merge).
  Future<SyncResult> performSync(PairedDevice device) async {
    final preferred = device.preferredEndpoint;
    final ip = preferred?.ipAddress ?? device.ipAddress ?? '127.0.0.1';
    final port = preferred?.port ?? httpSyncPort;
    return syncBiDirectional(ip, device.pairCode, targetPort: port);
  }
}
