import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'backup_service.dart';
import 'sync_merge_service.dart';
import '../features/sync/data/p2p_pairing_model.dart';
import '../features/finances/presentation/screens/financial_manager_screen.dart';
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

  SystemDiagnostics({
    required this.wifiConnected,
    this.localIp,
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
  static const String _deviceIdStorageKey = 'p2p_local_device_id_v1';

  String? _deviceId;
  HttpServer? _httpServer;
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

  /// Updates the set of trusted pair codes from already-paired devices so that
  /// even if the user regenerates their host code or pairs multiple devices,
  /// previously paired devices continue to authenticate seamlessly.
  void updateTrustedPairCodes(Iterable<String> codes) {
    _trustedPairCodes
      ..clear()
      ..addAll(codes.map((c) => c.trim()).where((c) => c.isNotEmpty));
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

  /// Detects the local IPv4 Wi-Fi/Ethernet address, prioritizing physical LAN interfaces
  /// and avoiding cellular (rmnet) or virtual interfaces.
  Future<String?> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      if (interfaces.isEmpty) return null;

      // Sort interfaces: Wi-Fi / Ethernet first, deprioritizing cellular and virtual
      final sortedInterfaces = [...interfaces]..sort((a, b) {
        final aScore = _scoreNetworkInterface(a.name);
        final bScore = _scoreNetworkInterface(b.name);
        return bScore.compareTo(aScore);
      });

      for (final interface in sortedInterfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && !addr.isLinkLocal) {
            final ip = addr.address;
            if (ip.isNotEmpty && !ip.startsWith('127.')) {
              return ip;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static int _scoreNetworkInterface(String name) {
    final lower = name.toLowerCase();
    // High priority: Wi-Fi interfaces (Android wlan*, Samsung swlan*, hotspot ap*, Apple en*, Linux wl*, Windows Wi-Fi)
    if (lower.startsWith('wlan') ||
        lower.startsWith('swlan') ||
        lower.startsWith('ap') ||
        lower.startsWith('wl') ||
        lower.contains('wifi') ||
        lower.contains('wi-fi')) {
      return 100;
    }
    // Ethernet interfaces (en0/en1, eth0)
    if (lower.startsWith('en') || lower.startsWith('eth')) {
      return 80;
    }
    // Deprioritize mobile data / cellular interfaces
    if (lower.startsWith('rmnet') || lower.startsWith('ccmni') || lower.startsWith('pdp') || lower.startsWith('cellular')) {
      return -50;
    }
    // Deprioritize virtual, container, VPN, and Wi-Fi Direct
    if (lower.startsWith('dummy') || lower.startsWith('p2p') || lower.startsWith('tun') || lower.startsWith('tap') || lower.startsWith('docker') || lower.startsWith('vbox')) {
      return -100;
    }
    return 10;
  }

  /// System hardware diagnostics for local Wi-Fi & IP.
  Future<SystemDiagnostics> runDiagnostics() async {
    final ip = await getLocalIpAddress();
    return SystemDiagnostics(
      wifiConnected: ip != null,
      localIp: ip,
    );
  }

  /// Starts the Primary Host HTTP Server & UDP Radio Beacon.
  Future<void> startPrimaryHostServer(String userName, String pairCode) async {
    while (_serverTransitionFuture != null) {
      await _serverTransitionFuture;
    }
    final completer = Completer<void>();
    _serverTransitionFuture = completer.future;
    try {
      await _stopPrimaryHostServerInternal();
      try {
        _httpServer = await HttpServer.bind(
          InternetAddress.anyIPv4,
          httpSyncPort,
          shared: true,
        );
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
        _isHosting = true;
        debugPrint('[P2pSyncService] Primary Host Server listening on port $httpSyncPort');

        await startUdpBeacon(userName, pairCode);
      } catch (e) {
        _isHosting = false;
        debugPrint('[P2pSyncService] Primary Host Server bind error: $e');
      }
    } finally {
      _serverTransitionFuture = null;
      completer.complete();
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
      _isHosting = false;
    } catch (_) {}
  }

  /// Starts UDP Radio Beacon on port 8766 for instant local network discovery.
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

      _udpSocket!.listen(
        (RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            final datagram = _udpSocket?.receive();
            if (datagram != null) {
              _handleUdpDatagram(datagram, pairCode);
            }
          }
        },
        onError: (Object error) {
          debugPrint('[P2pSyncService] UDP Beacon socket error: $error');
        },
        cancelOnError: false,
      );

      // Broadcast an immediate beacon on start, then every 2 seconds
      unawaited(broadcastUdpBeacon(userName, pairCode));
      _beaconTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        await broadcastUdpBeacon(userName, pairCode);
      });
    } catch (e) {
      debugPrint('[P2pSyncService] UDP Beacon error: $e');
    }
  }

  Future<void> broadcastUdpBeacon(String userName, String pairCode) async {
    if (_udpSocket == null) return;
    try {
      final ip = await getLocalIpAddress();
      final myDeviceId = await getDeviceId();

      // 1. Broadcast open presence beacon (LocalSend pattern: allows nearby devices to populate the discovery list)
      final presenceMap = {
        'action': 'presence',
        'deviceId': myDeviceId,
        'deviceName': userName,
        'ip': ip ?? '',
        'port': httpSyncPort,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final presenceData = utf8.encode(json.encode(presenceMap));
      _sendUdpBroadcast(presenceData, ip);

      // 2. Broadcast encrypted beacon for pre-paired devices (without pairCode reflection)
      final beaconMap = {
        'action': 'beacon',
        'role': 'PRIMARY',
        'deviceId': myDeviceId,
        'deviceName': userName,
        'ip': ip ?? '',
        'port': httpSyncPort,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final encrypted = _crypto.encryptPayload(json.encode(beaconMap), pairCode);
      if (encrypted != null) {
        _sendUdpBroadcast(utf8.encode(encrypted), ip);
      }
    } catch (_) {}
  }

  void _sendUdpBroadcast(List<int> data, String? localIp) {
    if (_udpSocket == null) return;
    try {
      _udpSocket!.send(data, InternetAddress('255.255.255.255'), udpBeaconPort);
      // Also send directly to the subnet broadcast address (e.g. 192.168.1.255)
      // because many mobile routers drop global 255.255.255.255.
      if (localIp != null && localIp.contains('.')) {
        final parts = localIp.split('.');
        if (parts.length == 4) {
          final subnetBroadcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
          _udpSocket!.send(data, InternetAddress(subnetBroadcast), udpBeaconPort);
        }
      }
    } catch (_) {}
  }

  void _handleUdpDatagram(Datagram datagram, String pairCode) async {
    try {
      final message = utf8.decode(datagram.data);
      final myDeviceId = await getDeviceId();
      final senderIp = datagram.address.address;

      // 1. Check for public presence beacon (unencrypted)
      try {
        final decoded = json.decode(message);
        if (decoded is Map<String, dynamic> && decoded['action'] == 'presence') {
          final senderDeviceId = decoded['deviceId'] as String?;
          final senderName = decoded['deviceName'] as String? ?? 'Nearby Device';
          final port = decoded['port'] is int ? decoded['port'] as int : httpSyncPort;
          if (senderDeviceId != null && senderDeviceId != myDeviceId) {
            final effectiveIp = (decoded['ip'] is String && (decoded['ip'] as String).isNotEmpty)
                ? decoded['ip'] as String
                : senderIp;
            _discoveredPeersController.add(DiscoveredPeer(
              deviceId: senderDeviceId,
              deviceName: senderName,
              ipAddress: effectiveIp,
              port: port,
              lastSeenAt: DateTime.now(),
            ));
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

      final effectiveIp = (map['ip'] is String && (map['ip'] as String).trim().isNotEmpty)
          ? sanitizeTargetIp((map['ip'] as String).trim())
          : sanitizeTargetIp(senderIp);
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

      // 1. Direct Ping
      if (path == '/api/sync/ping') {
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
        final (decrypted, isLegacy, matchedCode) = _decryptWithAnyTrustedCode(body, pairCode);
        if (decrypted != null) {
          _clearFailedAuth(clientIp);
          final backupJson = await generateBackupJson();
          final encryptedReply = _crypto.encryptPayload(backupJson, matchedCode, legacyMode: isLegacy);

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
          final (decrypted, isLegacy, matchedCode) = _decryptWithAnyTrustedCode(body, pairCode);
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
            final encryptedReply = _crypto.encryptPayload(updatedBackupJson, matchedCode, legacyMode: isLegacy);

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

  /// Sends pair handshake to Primary Device IP.
  Future<PairedDevice?> sendPairHandshake(
    String pairCode,
    String myDeviceName,
    String targetIp, {
    int targetPort = httpSyncPort,
  }) async {
    final parsed = parseTargetAddress(targetIp, targetPort);
    final cleanIp = parsed.$1;
    final cleanPort = parsed.$2;

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final myDeviceId = await getDeviceId();
      final handshakeMap = {
        'action': 'pair_handshake',
        'deviceId': myDeviceId,
        'deviceName': myDeviceName,
        'pairCode': pairCode,
        'role': 'PEER',
        'port': httpSyncPort,
      };

      // 1. Try standard PBKDF2 payload encryption
      var encrypted = _crypto.encryptPayload(json.encode(handshakeMap), pairCode);
      if (encrypted == null) {
        throw StateError('Failed to encrypt pair handshake payload. Check pair code.');
      }

      var req = await client.postUrl(buildSyncUri(cleanIp, cleanPort, '/api/sync/pair_handshake'));
      req.write(encrypted);
      var res = await req.close().timeout(const Duration(seconds: 15));

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
          final remoteDevice = PairedDevice(
            deviceId: map['deviceId'] ?? const Uuid().v4(),
            deviceName: map['deviceName'] ?? PairedDevice.generateRandomName(),
            pairCode: pairCode,
            lastSyncedAt: null,
            transportMode: 'Bi-Directional Sync',
            endpoints: [DeviceEndpoint(ipAddress: cleanIp, port: cleanPort, lastSeenAt: DateTime.now())],
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
      debugPrint('[P2pSyncService] Pair handshake error: $e');
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  static String formatUserFriendlyErrorMessage(dynamic e, [String? targetIp]) {
    final str = e.toString();
    final ipSuffix = (targetIp != null && targetIp.isNotEmpty) ? ' ($targetIp)' : '';
    if (str.contains('SocketException') || str.contains('Connection refused') || str.contains('No route to host')) {
      return 'Peer device unreachable$ipSuffix. Please open Note Taking on the other device and ensure both are on the same Wi-Fi.';
    } else if (str.contains('TimeoutException') || str.contains('timed out')) {
      return 'Connection timed out$ipSuffix. Ensure Note Taking is open and active on your peer device.';
    } else if (str.contains('HandshakeException') || str.contains('Pair Code mismatch')) {
      return 'Pair code mismatch. Re-scan QR code or check 6-digit pair code.';
    } else if (str.contains('FormatException')) {
      return 'Unexpected data format received during sync.';
    }
    final firstLine = str.split('\n').first;
    return 'Sync error$ipSuffix: ${firstLine.length > 80 ? firstLine.substring(0, 80) : firstLine}';
  }

  String _formatUserFriendlyError(dynamic e, String targetIp) => formatUserFriendlyErrorMessage(e, targetIp);

  /// Sends a direct test ping with round-trip latency measurement.
  Future<SyncResult> sendTestPing(String targetIp, String pairCode, {int targetPort = httpSyncPort}) async {
    final parsed = parseTargetAddress(targetIp, targetPort);
    final cleanIp = parsed.$1;
    final cleanPort = parsed.$2;

    final startTime = DateTime.now().millisecondsSinceEpoch;
    try {
      final pingMap = {
        'action': 'ping',
        'timestamp': startTime,
      };
      final rawJson = json.encode(pingMap);
      final encrypted = _crypto.encryptPayload(rawJson, pairCode);
      if (encrypted == null) {
        return SyncResult(success: false, errorMessage: 'Encryption failed. Check pair code.');
      }

      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      try {
        var req = await client.postUrl(buildSyncUri(cleanIp, cleanPort, '/api/sync/ping'));
        req.write(encrypted);
        var res = await req.close().timeout(const Duration(seconds: 10));

        // Automatic fallback to legacy v1 SHA-256 key if target device is on an older build
        if (res.statusCode == 401) {
          await res.drain<void>().catchError((_) {});
          final legacyEncrypted = _crypto.encryptPayload(rawJson, pairCode, legacyMode: true);
          if (legacyEncrypted != null) {
            final retryReq = await client.postUrl(buildSyncUri(cleanIp, cleanPort, '/api/sync/ping'));
            retryReq.write(legacyEncrypted);
            res = await retryReq.close().timeout(const Duration(seconds: 10));
          }
        }

        if (res.statusCode == 200) {
          final body = await utf8.decoder.bind(res).join().timeout(const Duration(seconds: 10));
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
      final encrypted = _crypto.encryptPayload(rawJson, pairCode);
      if (encrypted == null) {
        return SyncResult(success: false, errorMessage: 'Encryption error');
      }

      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      try {
        var req = await client.postUrl(buildSyncUri(cleanIp, cleanPort, '/api/sync/pull_master'));
        req.write(encrypted);
        var res = await req.close().timeout(const Duration(seconds: 30));

        if (res.statusCode == 401) {
          await res.drain<void>().catchError((_) {});
          final legacyEncrypted = _crypto.encryptPayload(rawJson, pairCode, legacyMode: true);
          if (legacyEncrypted != null) {
            final retryReq = await client.postUrl(buildSyncUri(cleanIp, cleanPort, '/api/sync/pull_master'));
            retryReq.write(legacyEncrypted);
            res = await retryReq.close().timeout(const Duration(seconds: 30));
          }
        }

        if (res.statusCode == 200) {
          final responseBody = await utf8.decoder.bind(res).join().timeout(const Duration(seconds: 45));
          final decryptedReply = _crypto.decryptPayload(responseBody, pairCode);
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

  /// Performs non-destructive Bi-Directional Delta Merge with Target Peer Device.
  Future<SyncResult> syncBiDirectional(String targetIp, String pairCode, {int targetPort = httpSyncPort}) async {
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
      encrypted = _crypto.encryptPayload(clientBackupJson, pairCode);
      if (encrypted == null) {
        return SyncResult(success: false, errorMessage: 'Encryption error');
      }
    } catch (e) {
      final res = SyncResult(success: false, errorMessage: _formatUserFriendlyError(e, cleanIp));
      _syncEventsController.add(res);
      return res;
    }

    const int max503Retries = 2;
    for (int attempt = 0; attempt <= max503Retries; attempt++) {
      if (_isSyncing) {
        return SyncResult(success: false, errorMessage: 'Sync already in progress');
      }
      _isSyncing = true;

      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      try {
        var req = await client.postUrl(buildSyncUri(cleanIp, cleanPort, '/api/sync/bidirectional_sync'));
        req.write(encrypted);
        var res = await req.close().timeout(const Duration(seconds: 45));

        // Automatic fallback to legacy v1 SHA-256 key if target device is on an older build
        if (res.statusCode == 401) {
          await res.drain<void>().catchError((_) {});
          final legacyEncrypted = _crypto.encryptPayload(clientBackupJson, pairCode, legacyMode: true);
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
          final decryptedReply = _crypto.decryptPayload(responseBody, pairCode);
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
