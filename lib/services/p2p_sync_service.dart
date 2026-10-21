import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'backup_service.dart';
import 'sync_merge_service.dart';
import '../features/sync/data/p2p_pairing_model.dart';
import 'sync_crypto_service.dart';

class SyncResult {
  final bool success;
  final int syncedCount;
  final int receivedCount;
  final int sentCount;
  final String transportUsed;
  final String? errorMessage;
  final int? latencyMs;

  SyncResult({
    required this.success,
    this.syncedCount = 0,
    this.receivedCount = 0,
    this.sentCount = 0,
    this.transportUsed = 'Primary Master Sync',
    this.errorMessage,
    this.latencyMs,
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

  bool _isHosting = false;
  bool _isSyncing = false;

  bool get isHosting => _isHosting;
  bool get isSyncing => _isSyncing;

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

  /// Detects the local IPv4 address of this device on network interfaces.
  Future<String?> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return null;
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
    await stopPrimaryHostServer();
    try {
      _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, httpSyncPort);
      _httpServer!.listen((HttpRequest request) async {
        await _handlePrimaryHttpRequest(request, pairCode, userName);
      });
      _isHosting = true;
      debugPrint('[P2pSyncService] Primary Host Server listening on port $httpSyncPort');

      await startUdpBeacon(userName, pairCode);
    } catch (e) {
      debugPrint('[P2pSyncService] Primary Host Server bind error: $e');
    }
  }

  /// Stops Primary Host Server & UDP Beacon.
  Future<void> stopPrimaryHostServer() async {
    try {
      _beaconTimer?.cancel();
      _udpSocket?.close();
      _udpSocket = null;
      await _httpServer?.close(force: true);
      _httpServer = null;
      _isHosting = false;
    } catch (_) {}
  }

  /// Starts UDP Radio Beacon on port 8766 for instant local network discovery.
  Future<void> startUdpBeacon(String userName, String pairCode) async {
    try {
      _udpSocket?.close();
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, udpBeaconPort);
      _udpSocket!.broadcastEnabled = true;

      _udpSocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket!.receive();
          if (datagram != null) {
            _handleUdpDatagram(datagram, pairCode);
          }
        }
      });

      _beaconTimer?.cancel();
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
      final beaconMap = {
        'action': 'beacon',
        'role': 'PRIMARY',
        'deviceId': await getDeviceId(),
        'deviceName': userName,
        'pairCode': pairCode,
        'ip': ip ?? '',
        'port': httpSyncPort,
      };
      final encrypted = _crypto.encryptPayload(json.encode(beaconMap), pairCode);
      if (encrypted != null) {
        final data = utf8.encode(encrypted);
        _udpSocket!.send(data, InternetAddress('255.255.255.255'), udpBeaconPort);
      }
    } catch (_) {}
  }

  void _handleUdpDatagram(Datagram datagram, String pairCode) async {
    try {
      final message = utf8.decode(datagram.data);
      final decrypted = _crypto.decryptPayload(message, pairCode);
      if (decrypted == null) return;

      final Map<String, dynamic> map = json.decode(decrypted);
      final senderDeviceId = map['deviceId'] as String?;
      final senderName = map['deviceName'] as String? ?? PairedDevice.generateRandomName();

      if (senderDeviceId == null || senderDeviceId == await getDeviceId()) return;

      final senderIp = datagram.address.address;

      if (map['action'] == 'pair_handshake' || map['action'] == 'beacon') {
        final remoteDevice = PairedDevice(
          deviceId: senderDeviceId,
          deviceName: senderName,
          pairCode: pairCode,
          lastSyncedAt: DateTime.now(),
          transportMode: 'Primary Direct Sync',
          endpoints: [
            DeviceEndpoint(
              ipAddress: senderIp,
              port: map['port'] is int ? map['port'] as int : httpSyncPort,
              lastSeenAt: DateTime.now(),
            ),
          ],
          role: map['role'] as String? ?? 'PRIMARY',
        );
        _remoteDevicePairedController.add(remoteDevice);
      }
    } catch (_) {}
  }

  /// Handles HTTP Requests on Primary Host Server.
  Future<void> _handlePrimaryHttpRequest(HttpRequest request, String pairCode, String userName) async {
    final response = request.response;
    response.headers.contentType = ContentType.json;

    // Guard against memory exhaustion from oversized payloads (25MB limit)
    const int maxPayloadBytes = 25 * 1024 * 1024;
    if (request.contentLength > maxPayloadBytes) {
      response.statusCode = HttpStatus.requestEntityTooLarge;
      response.write(json.encode({'error': 'Payload exceeds 25MB limit'}));
      await response.close();
      return;
    }

    try {
      final path = request.uri.path;

      // 1. Direct Ping
      if (path == '/api/sync/ping') {
        final body = await utf8.decoder.bind(request).join();
        final decrypted = _crypto.decryptPayload(body, pairCode);
        if (decrypted != null) {
          final reqMap = json.decode(decrypted);
          final reply = _crypto.encryptPayload(
            json.encode({
              'status': 'pong',
              'clientTime': reqMap['timestamp'],
              'serverTime': DateTime.now().millisecondsSinceEpoch,
              'hostName': userName,
            }),
            pairCode,
          );
          response.statusCode = HttpStatus.ok;
          response.write(reply);
        } else {
          response.statusCode = HttpStatus.unauthorized;
        }
      } 
      // 2. Pair Handshake
      else if (path == '/api/sync/pair_handshake') {
        final body = await utf8.decoder.bind(request).join();
        final decrypted = _crypto.decryptPayload(body, pairCode);
        if (decrypted != null) {
          final Map<String, dynamic> map = json.decode(decrypted);
          final remoteDevice = PairedDevice(
            deviceId: map['deviceId'] ?? const Uuid().v4(),
            deviceName: map['deviceName'] ?? PairedDevice.generateRandomName(),
            pairCode: pairCode,
            lastSyncedAt: DateTime.now(),
            transportMode: 'Primary Direct Sync',
            endpoints: [
              DeviceEndpoint(
                ipAddress: request.connectionInfo?.remoteAddress.address ?? '',
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
            pairCode,
          );
          response.statusCode = HttpStatus.ok;
          response.write(ackReply);
        } else {
          response.statusCode = HttpStatus.unauthorized;
        }
      } 
      // 3. Pull Master Snapshot (1-Way Fallback)
      else if (path == '/api/sync/pull_master') {
        final body = await utf8.decoder.bind(request).join();
        final decrypted = _crypto.decryptPayload(body, pairCode);
        if (decrypted != null) {
          final backupJson = await generateBackupJson();
          final encryptedReply = _crypto.encryptPayload(backupJson, pairCode);

          response.statusCode = HttpStatus.ok;
          response.write(encryptedReply);

          _syncEventsController.add(SyncResult(
            success: true,
            syncedCount: 1,
            receivedCount: 0,
            sentCount: 1,
            transportUsed: 'Primary Master Export',
          ));
        } else {
          response.statusCode = HttpStatus.unauthorized;
        }
      } 
      // 4. Bi-Directional Delta Merge (Non-Destructive 2-Way Sync)
      else if (path == '/api/sync/bidirectional_sync') {
        final body = await utf8.decoder.bind(request).join();
        final decrypted = _crypto.decryptPayload(body, pairCode);
        if (decrypted != null) {
          final Map<String, dynamic> clientData = json.decode(decrypted);

          // 1. Merge client data into host database
          final mergeResult = await SyncMergeService.instance.mergeRemoteData(clientData);

          // 2. Generate updated host payload for client
          final updatedBackupJson = await generateBackupJson();
          final encryptedReply = _crypto.encryptPayload(updatedBackupJson, pairCode);

          response.statusCode = HttpStatus.ok;
          response.write(encryptedReply);

          _syncEventsController.add(SyncResult(
            success: true,
            syncedCount: mergeResult.notesMerged + mergeResult.transactionsMerged,
            receivedCount: mergeResult.notesMerged,
            sentCount: 1,
            transportUsed: 'Bi-Directional Delta Merge',
          ));
        } else {
          response.statusCode = HttpStatus.unauthorized;
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

  /// Sends pair handshake to Primary Device IP.
  Future<PairedDevice?> sendPairHandshake(
    String pairCode,
    String myDeviceName,
    String targetIp, {
    int targetPort = httpSyncPort,
  }) async {
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

      final encrypted = _crypto.encryptPayload(json.encode(handshakeMap), pairCode);
      if (encrypted == null) return null;

      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final req = await client.postUrl(Uri.parse('http://$targetIp:$targetPort/api/sync/pair_handshake'));
      req.write(encrypted);
      final res = await req.close();

      if (res.statusCode == 200) {
        final body = await utf8.decoder.bind(res).join();
        final decrypted = _crypto.decryptPayload(body, pairCode);
        if (decrypted != null) {
          final Map<String, dynamic> map = json.decode(decrypted);
          final remoteDevice = PairedDevice(
            deviceId: map['deviceId'] ?? const Uuid().v4(),
            deviceName: map['deviceName'] ?? PairedDevice.generateRandomName(),
            pairCode: pairCode,
            lastSyncedAt: DateTime.now(),
            transportMode: 'Bi-Directional Sync',
            endpoints: [DeviceEndpoint(ipAddress: targetIp, port: targetPort, lastSeenAt: DateTime.now())],
            role: map['role'] as String? ?? 'PEER',
          );
          _remoteDevicePairedController.add(remoteDevice);
          return remoteDevice;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[P2pSyncService] Pair handshake error: $e');
      return null;
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
    final startTime = DateTime.now().millisecondsSinceEpoch;
    try {
      final pingMap = {
        'action': 'ping',
        'timestamp': startTime,
      };
      final encrypted = _crypto.encryptPayload(json.encode(pingMap), pairCode);
      if (encrypted == null) {
        return SyncResult(success: false, errorMessage: 'Encryption failed. Check pair code.');
      }

      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      try {
        final req = await client.postUrl(Uri.parse('http://$targetIp:$targetPort/api/sync/ping'));
        req.write(encrypted);
        final res = await req.close();

        if (res.statusCode == 200) {
          final body = await utf8.decoder.bind(res).join();
          final decrypted = _crypto.decryptPayload(body, pairCode);
          if (decrypted != null) {
            final endTime = DateTime.now().millisecondsSinceEpoch;
            final latency = endTime - startTime;
            final result = SyncResult(
              success: true,
              syncedCount: 0,
              transportUsed: 'Direct IP ($targetIp)',
              latencyMs: latency,
            );
            _syncEventsController.add(result);
            return result;
          } else {
            return SyncResult(success: false, errorMessage: 'Pair Code mismatch. Decryption failed for $targetIp.');
          }
        } else if (res.statusCode == 401) {
          return SyncResult(success: false, errorMessage: 'Pair Code mismatch. Check 6-digit code on target device.');
        }
        return SyncResult(success: false, errorMessage: 'Ping failed (HTTP ${res.statusCode}) from $targetIp');
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      final res = SyncResult(success: false, errorMessage: _formatUserFriendlyError(e, targetIp));
      _syncEventsController.add(res);
      return res;
    }
  }

  /// Secondary pulls master state from Primary and overwrites local DB 100%.
  Future<SyncResult> pullMasterFromPrimary(String targetIp, String pairCode, {int targetPort = httpSyncPort}) async {
    if (_isSyncing) {
      return SyncResult(success: false, errorMessage: 'Sync already in progress');
    }
    _isSyncing = true;

    try {
      final requestMap = {
        'action': 'pull_master',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final encrypted = _crypto.encryptPayload(json.encode(requestMap), pairCode);
      if (encrypted == null) {
        return SyncResult(success: false, errorMessage: 'Encryption error');
      }

      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      try {
        final req = await client.postUrl(Uri.parse('http://$targetIp:$targetPort/api/sync/pull_master'));
        req.write(encrypted);
        final res = await req.close();

        if (res.statusCode == 200) {
          final responseBody = await utf8.decoder.bind(res).join();
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
              transportUsed: 'Primary Master Sync ($targetIp)',
            );
            _syncEventsController.add(syncRes);
            return syncRes;
          }
        }
        return SyncResult(success: false, errorMessage: 'Failed to fetch master snapshot from $targetIp');
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
    if (_isSyncing) {
      return SyncResult(success: false, errorMessage: 'Sync already in progress');
    }
    _isSyncing = true;

    try {
      final clientBackupJson = await generateBackupJson();
      final encrypted = _crypto.encryptPayload(clientBackupJson, pairCode);
      if (encrypted == null) {
        return SyncResult(success: false, errorMessage: 'Encryption error');
      }

      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      try {
        final req = await client.postUrl(Uri.parse('http://$targetIp:$targetPort/api/sync/bidirectional_sync'));
        req.write(encrypted);
        final res = await req.close();

        if (res.statusCode == 200) {
          final responseBody = await utf8.decoder.bind(res).join().timeout(const Duration(seconds: 10));
          final decryptedReply = _crypto.decryptPayload(responseBody, pairCode);
          if (decryptedReply != null) {
            final Map<String, dynamic> replyMap = json.decode(decryptedReply);

            // Non-destructive Last-Write-Wins Merge on client device
            final mergeResult = await SyncMergeService.instance.mergeRemoteData(replyMap);

            final syncRes = SyncResult(
              success: true,
              syncedCount: mergeResult.notesMerged + mergeResult.transactionsMerged,
              receivedCount: mergeResult.notesMerged,
              sentCount: 1,
              transportUsed: 'Bi-Directional Delta Merge ($targetIp)',
            );
            _syncEventsController.add(syncRes);
            return syncRes;
          } else {
            return SyncResult(success: false, errorMessage: 'Pair Code mismatch. Decryption failed for $targetIp.');
          }
        } else if (res.statusCode == 401) {
          return SyncResult(success: false, errorMessage: 'Pair Code mismatch. Check 6-digit code on target device.');
        }
        return SyncResult(success: false, errorMessage: 'Sync failed (HTTP ${res.statusCode}) with $targetIp');
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      final res = SyncResult(success: false, errorMessage: _formatUserFriendlyError(e, targetIp));
      _syncEventsController.add(res);
      return res;
    } finally {
      _isSyncing = false;
    }
  }

  /// Background auto-sync trigger compatibility alias (uses Bi-Directional Merge).
  Future<SyncResult> performSync(PairedDevice device) async {
    final ip = device.ipAddress ?? '127.0.0.1';
    return syncBiDirectional(ip, device.pairCode);
  }
}
