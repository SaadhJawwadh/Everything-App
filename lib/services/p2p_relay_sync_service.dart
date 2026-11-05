import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../features/finances/presentation/screens/financial_manager_screen.dart';
import '../features/sync/data/p2p_pairing_model.dart';
import 'backup_service.dart';
import 'p2p_sync_service.dart';
import 'sync_crypto_service.dart';
import 'sync_merge_service.dart';

/// Stateless End-to-End Encrypted (E2EE) Blind Relay & Cross-Network P2P Sync Engine.
///
/// Enables devices to pair, ping, and bi-directionally synchronize across:
/// - Wi-Fi Routers with AP Client Isolation (2.4GHz vs 5GHz / Guest Wi-Fi / University Wi-Fi)
/// - Cellular Mobile Data (4G / 5G Carrier-Grade NAT `100.64.0.0/10` / 464XLAT)
/// - Different networks in different cities or countries
///
/// Security & Zero-Knowledge Architecture:
/// - Rendezvous room tags (`d` tags) are derived via `HMAC-SHA256(key: pairCode, msg: "everything_p2p_room_v2")`.
///   Relays never see the 6-digit pair code or device identities.
/// - Every payload inside the envelope is encrypted end-to-end with `SyncCryptoService`
///   (PBKDF2-HMAC-SHA256 10,000 iterations + AES-256-CBC random IV + Encrypt-then-MAC HMAC-SHA256).
/// - Relays act purely as blind WebSocket message routers using ephemeral Nostr NIP-01 envelopes.
class P2pRelaySyncService {
  static final P2pRelaySyncService instance = P2pRelaySyncService._internal();
  P2pRelaySyncService._internal();

  static const String customRelayPrefKey = 'p2p_custom_relay_url_v1';
  static const int _ephemeralEventKind = 24242; // NIP-01 Ephemeral range (20000-29999): never persisted on disk
  static const int _replaceableMailboxKind = 30078; // NIP-78 Parameterized Replaceable event for immediate poll/fetch
  static const int _maxChunkChars = 48000; // ~48KB per WebSocket frame to avoid relay frame size limits

  /// Public zero-knowledge WebSocket relays used as parallel redundant transports.
  static const List<String> defaultRelayUrls = [
    'wss://nos.lol',
    'wss://relay.damus.io',
    'wss://relay.primal.net',
  ];

  final SyncCryptoService _crypto = SyncCryptoService.instance;
  final Map<String, WebSocket> _sockets = {};
  final Map<String, StreamSubscription<dynamic>> _socketSubscriptions = {};
  final Map<String, List<Completer<Map<String, dynamic>>>> _pendingRpcReplies = {};
  final Map<String, Map<int, String>> _incomingChunkBuffers = {};
  final Set<String> _processedMessageIds = {};

  bool _isListening = false;
  bool get isListening => _isListening;
  String _hostDeviceName = '';
  String _primaryPairCode = '';
  Set<String> _trustedPairCodes = {};
  Timer? _reconnectTimer;

  /// Callback invoked when the relay receives a valid inbound request (`ping`, `pair_handshake`, `bidirectional_sync`).
  Future<Map<String, dynamic>?> Function(
    String action,
    Map<String, dynamic> decryptedPayload,
    String matchedPairCode,
    bool isLegacyCrypto,
  )? onInboundRelayRequest;

  /// Computes a deterministic, zero-knowledge 64-hex room identifier from a 6-digit [pairCode].
  /// The relay only sees this irreversible HMAC-SHA256 digest, never the pair code itself.
  @visibleForTesting
  static String deriveRoomHash(String pairCode) {
    final hmac = Hmac(sha256, utf8.encode('everything_app_p2p_relay_room_v2'));
    return hmac.convert(utf8.encode(pairCode.trim())).toString();
  }

  /// Derives a deterministic 64-hex Nostr-compatible pubkey identifier from [deviceId] and [pairCode].
  @visibleForTesting
  static String deriveTransportPubkey(String deviceId, String pairCode) {
    final hmac = Hmac(sha256, utf8.encode('everything_app_p2p_pubkey_v2:$pairCode'));
    return hmac.convert(utf8.encode(deviceId.trim())).toString();
  }

  /// Splits a large encrypted ciphertext string into bounded chunks so WebSocket relays with
  /// 64KB frame limits transport multi-megabyte SQLite delta payloads without dropping frames.
  @visibleForTesting
  static List<String> splitCiphertextChunks(String ciphertext, {int maxChunkSize = _maxChunkChars}) {
    if (ciphertext.isEmpty) return const [''];
    if (ciphertext.length <= maxChunkSize) return [ciphertext];
    final chunks = <String>[];
    for (int i = 0; i < ciphertext.length; i += maxChunkSize) {
      final end = (i + maxChunkSize < ciphertext.length) ? i + maxChunkSize : ciphertext.length;
      chunks.add(ciphertext.substring(i, end));
    }
    return chunks;
  }

  /// Reassembles indexed chunks into the original ciphertext string once all [totalChunks] arrive.
  @visibleForTesting
  static String? tryReassembleChunks(Map<int, String> buffer, int totalChunks) {
    if (buffer.length < totalChunks) return null;
    final sb = StringBuffer();
    for (int i = 0; i < totalChunks; i++) {
      final part = buffer[i];
      if (part == null) return null;
      sb.write(part);
    }
    return sb.toString();
  }

  /// Returns active relay URLs (including any user-configured custom relay URL).
  Future<List<String>> getActiveRelayUrls() async {
    final urls = <String>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final custom = prefs.getString(customRelayPrefKey)?.trim();
      if (custom != null &&
          custom.isNotEmpty &&
          (custom.startsWith('wss://') || custom.startsWith('ws://'))) {
        urls.add(custom);
      }
    } catch (_) {}
    for (final url in defaultRelayUrls) {
      if (!urls.contains(url)) urls.add(url);
    }
    return urls;
  }

  /// Starts background WebSocket relay listeners for all trusted pair codes so this device
  /// can be reached even behind Router AP Isolation or 5G Mobile Data CGNAT.
  Future<void> startRelayHostListener({
    required String deviceName,
    required String primaryPairCode,
    required Iterable<String> trustedPairCodes,
  }) async {
    _hostDeviceName = deviceName;
    _primaryPairCode = primaryPairCode.trim();
    _trustedPairCodes = {
      if (_primaryPairCode.isNotEmpty) _primaryPairCode,
      ...trustedPairCodes.map((c) => c.trim()).where((c) => c.isNotEmpty),
    };
    _isListening = true;
    await _ensureRelayConnections();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_isListening) {
        unawaited(_ensureRelayConnections());
      }
    });
  }

  /// Updates the set of trusted pair codes and refreshes relay room subscriptions.
  void updateTrustedPairCodes(String primaryPairCode, Iterable<String> codes) {
    _primaryPairCode = primaryPairCode.trim();
    _trustedPairCodes = {
      if (_primaryPairCode.isNotEmpty) _primaryPairCode,
      ...codes.map((c) => c.trim()).where((c) => c.isNotEmpty),
    };
    if (_isListening) {
      _sendSubscriptionsToConnectedRelays();
    }
  }

  /// Stops all active WebSocket relay connections.
  Future<void> stopRelayHostListener() async {
    _isListening = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    for (final sub in _socketSubscriptions.values) {
      await sub.cancel().catchError((_) {});
    }
    _socketSubscriptions.clear();
    for (final ws in _sockets.values) {
      await ws.close().catchError((_) {});
    }
    _sockets.clear();
  }

  Future<void> _ensureRelayConnections() async {
    if (!_isListening || _trustedPairCodes.isEmpty) return;
    final urls = await getActiveRelayUrls();
    for (final url in urls) {
      if (_sockets[url]?.readyState == WebSocket.open) {
        continue;
      }
      unawaited(_connectSingleRelay(url));
    }
  }

  Future<void> _connectSingleRelay(String url) async {
    try {
      // ignore: close_sinks
      final ws = await WebSocket.connect(url).timeout(const Duration(seconds: 6));
      ws.pingInterval = const Duration(seconds: 20);
      _sockets[url] = ws;
      // ignore: cancel_subscriptions
      final sub = ws.listen(
        (dynamic rawFrame) {
          if (rawFrame is String) {
            unawaited(_handleRelayFrame(rawFrame));
          }
        },
        onDone: () {
          _sockets.remove(url);
          _socketSubscriptions.remove(url);
        },
        onError: (_) {
          _sockets.remove(url);
          _socketSubscriptions.remove(url);
        },
        cancelOnError: true,
      );
      _socketSubscriptions[url] = sub;
      _subscribeOnSocket(ws);
    } catch (_) {
      // Relay unreachable (e.g. completely offline LAN without internet); silently ignore
    }
  }

  void _sendSubscriptionsToConnectedRelays() {
    for (final ws in _sockets.values) {
      if (ws.readyState == WebSocket.open) {
        _subscribeOnSocket(ws);
      }
    }
  }

  void _subscribeOnSocket(WebSocket ws) {
    final rooms = _trustedPairCodes.map(deriveRoomHash).toSet().toList();
    if (rooms.isEmpty) return;
    final subFrame = json.encode([
      'REQ',
      'everything_p2p_sub',
      {
        'kinds': [_ephemeralEventKind, _replaceableMailboxKind],
        '#d': rooms,
        'since': (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 60,
      },
    ]);
    try {
      ws.add(subFrame);
    } catch (_) {}
  }

  Future<void> _handleRelayFrame(String rawFrame) async {
    try {
      final decoded = json.decode(rawFrame);
      if (decoded is! List || decoded.length < 3 || decoded[0] != 'EVENT') return;
      final event = decoded[2];
      if (event is! Map<String, dynamic>) return;
      final content = event['content'] as String?;
      if (content == null || content.isEmpty) return;

      final envelope = json.decode(content);
      if (envelope is! Map<String, dynamic>) return;
      if (envelope['app'] != 'everything_p2p_relay_v2') return;

      final myDeviceId = await P2pSyncService.instance.getDeviceId();
      final senderId = envelope['senderId'] as String? ?? '';
      if (senderId.isEmpty || senderId == myDeviceId) return;

      final targetDeviceId = envelope['targetDeviceId'] as String?;
      if (targetDeviceId != null && targetDeviceId.isNotEmpty && targetDeviceId != myDeviceId) {
        return;
      }

      final msgId = envelope['msgId'] as String? ?? '';
      final chunkIndex = envelope['chunkIndex'] is int ? envelope['chunkIndex'] as int : 0;
      final totalChunks = envelope['totalChunks'] is int ? envelope['totalChunks'] as int : 1;
      final cipherChunk = envelope['cipher'] as String? ?? '';
      if (msgId.isEmpty || cipherChunk.isEmpty) return;

      final dedupKey = '$msgId:$chunkIndex';
      if (!_processedMessageIds.add(dedupKey)) return;
      if (_processedMessageIds.length > 500) {
        _processedMessageIds.remove(_processedMessageIds.first);
      }

      String? fullCiphertext;
      if (totalChunks <= 1) {
        fullCiphertext = cipherChunk;
      } else {
        final buf = _incomingChunkBuffers.putIfAbsent(msgId, () => <int, String>{});
        buf[chunkIndex] = cipherChunk;
        fullCiphertext = tryReassembleChunks(buf, totalChunks);
        if (fullCiphertext != null) {
          _incomingChunkBuffers.remove(msgId);
        }
      }
      if (fullCiphertext == null) return;

      final msgType = envelope['type'] as String? ?? 'req'; // 'req' or 'ack'
      final corrId = envelope['corrId'] as String? ?? msgId;

      if (msgType == 'ack') {
        final waiters = _pendingRpcReplies[corrId];
        if (waiters != null && waiters.isNotEmpty) {
          for (final waiter in List<Completer<Map<String, dynamic>>>.from(waiters)) {
            if (!waiter.isCompleted) {
              waiter.complete({
                'cipher': fullCiphertext,
                'senderId': senderId,
              });
            }
          }
          _pendingRpcReplies.remove(corrId);
        }
        return;
      }

      // Inbound 'req': attempt decryption against all trusted pair codes
      String? decrypted;
      bool isLegacy = false;
      String matchedCode = _primaryPairCode;
      for (final code in _trustedPairCodes) {
        final (plain, legacyFlag) = _crypto.decryptPayloadDetailed(fullCiphertext, code);
        if (plain != null) {
          decrypted = plain;
          isLegacy = legacyFlag;
          matchedCode = code;
          break;
        }
      }
      if (decrypted == null) return;

      final payloadMap = json.decode(decrypted) as Map<String, dynamic>;
      final action = payloadMap['action'] as String? ?? '';
      Map<String, dynamic>? replyPayload;

      if (onInboundRelayRequest != null) {
        replyPayload = await onInboundRelayRequest!(action, payloadMap, matchedCode, isLegacy);
      } else {
        replyPayload = await _defaultInboundHandler(action, payloadMap, matchedCode);
      }

      if (replyPayload != null) {
        final encryptedReply = _crypto.encryptPayload(
          json.encode(replyPayload),
          matchedCode,
          legacyMode: isLegacy,
        );
        if (encryptedReply != null) {
          await _publishEncryptedEnvelope(
            pairCode: matchedCode,
            type: 'ack',
            corrId: msgId,
            targetDeviceId: senderId,
            ciphertext: encryptedReply,
          );
        }
      }
    } catch (e) {
      debugPrint('[P2pRelaySyncService] Error handling relay frame: $e');
    }
  }

  Future<Map<String, dynamic>?> _defaultInboundHandler(
    String action,
    Map<String, dynamic> payloadMap,
    String matchedCode,
  ) async {
    final syncService = P2pSyncService.instance;
    final myDeviceId = await syncService.getDeviceId();
    if (action == 'ping') {
      return {
        'status': 'pong',
        'clientTime': payloadMap['timestamp'],
        'serverTime': DateTime.now().millisecondsSinceEpoch,
        'hostName': _hostDeviceName,
      };
    } else if (action == 'pair_handshake') {
      final remoteDevice = PairedDevice(
        deviceId: payloadMap['deviceId'] as String? ?? const Uuid().v4(),
        deviceName: payloadMap['deviceName'] as String? ?? PairedDevice.generateRandomName(),
        pairCode: matchedCode,
        lastSyncedAt: null,
        transportMode: 'Cross-Network E2EE Relay',
        endpoints: [
          DeviceEndpoint(
            ipAddress: 'relay://${payloadMap['deviceId'] ?? 'peer'}',
            port: P2pSyncService.httpSyncPort,
            networkLabel: 'Cross-Network Relay',
            lastSeenAt: DateTime.now(),
          ),
        ],
        role: 'SECONDARY',
      );
      syncService.notifyRemoteDevicePaired(remoteDevice);
      return {
        'action': 'pair_ack',
        'deviceId': myDeviceId,
        'deviceName': _hostDeviceName.isEmpty ? PairedDevice.generateRandomName() : _hostDeviceName,
        'role': 'PRIMARY',
        'port': P2pSyncService.httpSyncPort,
      };
    } else if (action == 'bidirectional_sync') {
      final mergeResult = await SyncMergeService.instance.mergeRemoteData(payloadMap);
      if (mergeResult.totalMerged > 0) {
        FinancialManagerScreen.refreshNotifier.value = DateTime.now().millisecondsSinceEpoch;
      }
      final updatedBackupJson = await generateBackupJson();
      syncService.notifySyncEvent(
        SyncResult(
          success: true,
          syncedCount: mergeResult.totalMerged,
          receivedCount: mergeResult.totalMerged,
          sentCount: 1,
          transportUsed: 'Cross-Network E2EE Relay',
          isServerInbound: true,
        ),
      );
      return json.decode(updatedBackupJson) as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> _publishEncryptedEnvelope({
    required String pairCode,
    required String type,
    required String corrId,
    String? targetDeviceId,
    required String ciphertext,
    Iterable<WebSocket>? extraSockets,
  }) async {
    final myDeviceId = await P2pSyncService.instance.getDeviceId();
    final roomHash = deriveRoomHash(pairCode);
    final chunks = splitCiphertextChunks(ciphertext);
    final msgId = type == 'ack' ? const Uuid().v4() : corrId;
    final allSockets = <WebSocket>{
      ..._sockets.values.where((ws) => ws.readyState == WebSocket.open),
      if (extraSockets != null) ...extraSockets.where((ws) => ws.readyState == WebSocket.open),
    };
    if (allSockets.isEmpty) return;

    for (int i = 0; i < chunks.length; i++) {
      final envelopeJson = json.encode({
        'app': 'everything_p2p_relay_v2',
        'type': type,
        'msgId': msgId,
        'corrId': corrId,
        'senderId': myDeviceId,
        if (targetDeviceId != null) 'targetDeviceId': targetDeviceId,
        'chunkIndex': i,
        'totalChunks': chunks.length,
        'cipher': chunks[i],
        'ts': DateTime.now().millisecondsSinceEpoch,
      });

      final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final pubkey = deriveTransportPubkey(myDeviceId, pairCode);
      final tags = <List<String>>[
        ['d', roomHash],
      ];
      final serializedForId = json.encode([
        0,
        pubkey,
        createdAt,
        _ephemeralEventKind,
        tags,
        envelopeJson,
      ]);
      final eventId = sha256.convert(utf8.encode(serializedForId)).toString();
      final eventFrame = json.encode([
        'EVENT',
        {
          'id': eventId,
          'pubkey': pubkey,
          'created_at': createdAt,
          'kind': _ephemeralEventKind,
          'tags': tags,
          'content': envelopeJson,
          'sig': sha256.convert(utf8.encode('$eventId:$roomHash')).toString() +
              sha256.convert(utf8.encode('$roomHash:$eventId')).toString(),
        },
      ]);

      for (final ws in allSockets) {
        try {
          ws.add(eventFrame);
        } catch (_) {}
      }
    }
  }

  /// Sends an End-to-End Encrypted RPC request over the Blind WebSocket Relay network
  /// and awaits the peer's encrypted response.
  Future<String?> sendEncryptedRelayRpc({
    required String pairCode,
    required String plaintextJson,
    String? targetDeviceId,
    Duration timeout = const Duration(seconds: 12),
    bool legacyMode = false,
  }) async {
    final encrypted = _crypto.encryptPayload(plaintextJson, pairCode, legacyMode: legacyMode);
    if (encrypted == null) return null;

    await _ensureRelayConnections();

    // If no background sockets are open yet, open temporary connections to the active relays
    final tempSockets = <WebSocket>[];
    final tempSubs = <StreamSubscription<dynamic>>[];
    if (_sockets.values.where((ws) => ws.readyState == WebSocket.open).isEmpty) {
      final urls = await getActiveRelayUrls();
      for (final url in urls) {
        try {
          final ws = await WebSocket.connect(url).timeout(const Duration(seconds: 4));
          tempSockets.add(ws);
          final roomHash = deriveRoomHash(pairCode);
          ws.add(json.encode([
            'REQ',
            'everything_p2p_rpc',
            {
              'kinds': [_ephemeralEventKind, _replaceableMailboxKind],
              '#d': [roomHash],
              'since': (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 30,
            },
          ]));
          tempSubs.add(ws.listen((dynamic raw) {
            if (raw is String) {
              unawaited(_handleRelayFrame(raw));
            }
          }));
        } catch (_) {}
      }
    } else {
      // Ensure current pairCode room is subscribed on existing sockets
      _trustedPairCodes.add(pairCode.trim());
      _sendSubscriptionsToConnectedRelays();
    }

    final hasAnySocket = _sockets.values.any((ws) => ws.readyState == WebSocket.open) ||
        tempSockets.any((ws) => ws.readyState == WebSocket.open);
    if (!hasAnySocket) {
      for (final sub in tempSubs) {
        await sub.cancel().catchError((_) {});
      }
      for (final ws in tempSockets) {
        await ws.close().catchError((_) {});
      }
      return null;
    }

    final corrId = const Uuid().v4();
    final completer = Completer<Map<String, dynamic>>();
    _pendingRpcReplies.putIfAbsent(corrId, () => []).add(completer);

    try {
      await _publishEncryptedEnvelope(
        pairCode: pairCode,
        type: 'req',
        corrId: corrId,
        targetDeviceId: targetDeviceId,
        ciphertext: encrypted,
        extraSockets: tempSockets,
      );

      final replyEnvelope = await completer.future.timeout(timeout);
      final replyCipher = replyEnvelope['cipher'] as String?;
      if (replyCipher == null) return null;
      return _crypto.decryptPayload(replyCipher, pairCode);
    } catch (_) {
      return null;
    } finally {
      _pendingRpcReplies.remove(corrId);
      for (final sub in tempSubs) {
        await sub.cancel().catchError((_) {});
      }
      for (final ws in tempSockets) {
        await ws.close().catchError((_) {});
      }
    }
  }
}
