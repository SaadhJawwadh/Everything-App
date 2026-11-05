import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../features/finances/presentation/screens/financial_manager_screen.dart';
import '../features/sync/data/p2p_pairing_model.dart';
import 'backup_service.dart';
import 'p2p_sync_service.dart';
import 'sync_crypto_service.dart';
import 'sync_merge_service.dart';

/// Pure-Dart BIP-340 Schnorr Signature engine over `secp256k1` (using `pointycastle`).
///
/// Generates mathematically valid Nostr NIP-01 x-only 32-byte public keys and 64-byte
/// BIP-340 Schnorr signatures so public Nostr relays (`wss://nos.lol`, `wss://relay.damus.io`,
/// `wss://relay.primal.net`) validate and route Everyting App E2EE envelopes without rejection.
class Bip340Schnorr {
  static final ECDomainParameters _params = ECCurve_secp256k1();
  static final BigInt _p = BigInt.parse(
    'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F',
    radix: 16,
  );
  static final BigInt _n = _params.n;
  static final ECPoint _g = _params.G;

  static final Map<String, ({String privHex, String pubHex})> _keyCache = {};

  /// Derives a deterministic BIP-340 keypair `(privHex, pubHex)` from a 6-digit [pairCode].
  static ({String privHex, String pubHex}) deriveRoomKeyPair(String pairCode) {
    final normalized = pairCode.trim();
    final cached = _keyCache[normalized];
    if (cached != null) return cached;

    final hmac = Hmac(sha256, utf8.encode('everything_app_p2p_secp256k1_v3'));
    final digest = hmac.convert(utf8.encode(normalized)).bytes;
    var d = _bytesToBigInt(Uint8List.fromList(digest)) % (_n - BigInt.one) + BigInt.one;
    final point = (_g * d)!;
    final px = point.x!.toBigInteger()!;
    final privHex = _bigIntToHex32(d);
    final pubHex = _bigIntToHex32(px);
    final pair = (privHex: privHex, pubHex: pubHex);
    _keyCache[normalized] = pair;
    return pair;
  }

  /// Computes the 32-byte x-only public key hex for a 32-byte [privKeyHex].
  static String getPublicKeyHex(String privKeyHex) {
    final d0 = BigInt.parse(privKeyHex, radix: 16);
    if (d0 <= BigInt.zero || d0 >= _n) {
      throw ArgumentError('Invalid secp256k1 private key scalar');
    }
    final point = (_g * d0)!;
    return _bigIntToHex32(point.x!.toBigInteger()!);
  }

  /// Signs a 32-byte message hash ([msg32Hex]) using [privKeyHex] per BIP-340.
  /// Returns a 64-byte (128-character lowercase hex) Schnorr signature.
  static String sign(String msg32Hex, String privKeyHex) {
    final msgBytes = _hexToBytes(msg32Hex);
    if (msgBytes.length != 32) {
      throw ArgumentError('Message must be 32 bytes (64 hex chars)');
    }
    final d0 = BigInt.parse(privKeyHex, radix: 16);
    if (d0 <= BigInt.zero || d0 >= _n) {
      throw ArgumentError('Private key out of range');
    }

    final P = (_g * d0)!;
    final px = P.x!.toBigInteger()!;
    final py = P.y!.toBigInteger()!;
    final d = py.isOdd ? (_n - d0) : d0;

    final dBytes = _bigIntToBytes32(d);
    final pxBytes = _bigIntToBytes32(px);

    // Deterministic nonce per BIP-340 (aux_rand = 32 zero bytes -> t = d ^ taggedHash("BIP0340/aux", zeros))
    final auxHash = _taggedHash('BIP0340/aux', Uint8List(32));
    final t = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      t[i] = dBytes[i] ^ auxHash[i];
    }

    final randInput = Uint8List(96)
      ..setRange(0, 32, t)
      ..setRange(32, 64, pxBytes)
      ..setRange(64, 96, msgBytes);
    final k0 = _bytesToBigInt(_taggedHash('BIP0340/nonce', randInput)) % _n;
    if (k0 == BigInt.zero) {
      throw StateError('Zero nonce derived in BIP-340 sign');
    }

    final R = (_g * k0)!;
    final rx = R.x!.toBigInteger()!;
    final ry = R.y!.toBigInteger()!;
    final k = ry.isOdd ? (_n - k0) : k0;
    final rxBytes = _bigIntToBytes32(rx);

    final challengeInput = Uint8List(96)
      ..setRange(0, 32, rxBytes)
      ..setRange(32, 64, pxBytes)
      ..setRange(64, 96, msgBytes);
    final e = _bytesToBigInt(_taggedHash('BIP0340/challenge', challengeInput)) % _n;
    final s = (k + (e * d)) % _n;

    return '${_bigIntToHex32(rx)}${_bigIntToHex32(s)}';
  }

  /// Verifies a 64-byte BIP-340 Schnorr signature ([sig64Hex]) against [msg32Hex] and x-only [pubKey32Hex].
  static bool verify(String msg32Hex, String pubKey32Hex, String sig64Hex) {
    try {
      if (msg32Hex.length != 64 || pubKey32Hex.length != 64 || sig64Hex.length != 128) {
        return false;
      }
      final px = BigInt.parse(pubKey32Hex, radix: 16);
      final r = BigInt.parse(sig64Hex.substring(0, 64), radix: 16);
      final s = BigInt.parse(sig64Hex.substring(64, 128), radix: 16);
      if (px >= _p || r >= _p || s >= _n) return false;

      final P = _liftX(px);
      if (P == null) return false;

      final rxBytes = _bigIntToBytes32(r);
      final pxBytes = _bigIntToBytes32(px);
      final msgBytes = _hexToBytes(msg32Hex);
      final challengeInput = Uint8List(96)
        ..setRange(0, 32, rxBytes)
        ..setRange(32, 64, pxBytes)
        ..setRange(64, 96, msgBytes);
      final e = _bytesToBigInt(_taggedHash('BIP0340/challenge', challengeInput)) % _n;

      // R = s*G - e*P = s*G + (n - e)*P
      final sG = (_g * s)!;
      final negEP = (P * ((_n - e) % _n))!;
      final R = (sG + negEP)!;
      if (R.isInfinity) return false;
      final rx = R.x!.toBigInteger()!;
      final ry = R.y!.toBigInteger()!;
      return !ry.isOdd && rx == r;
    } catch (_) {
      return false;
    }
  }

  static ECPoint? _liftX(BigInt x) {
    if (x <= BigInt.zero || x >= _p) return null;
    final c = (x.modPow(BigInt.from(3), _p) + BigInt.from(7)) % _p;
    final y = c.modPow((_p + BigInt.one) >> 2, _p);
    if (y.modPow(BigInt.two, _p) != c) return null;
    final evenY = y.isOdd ? (_p - y) : y;
    return _params.curve.createPoint(x, evenY);
  }

  static Uint8List _taggedHash(String tag, Uint8List msg) {
    final tagDigest = sha256.convert(utf8.encode(tag)).bytes;
    final builder = BytesBuilder(copy: false)
      ..add(tagDigest)
      ..add(tagDigest)
      ..add(msg);
    return Uint8List.fromList(sha256.convert(builder.toBytes()).bytes);
  }

  static BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final b in bytes) {
      result = (result << 8) | BigInt.from(b);
    }
    return result;
  }

  static Uint8List _bigIntToBytes32(BigInt value) {
    final out = Uint8List(32);
    var v = value;
    for (int i = 31; i >= 0; i--) {
      out[i] = (v & BigInt.from(0xff)).toInt();
      v = v >> 8;
    }
    return out;
  }

  static String _bigIntToHex32(BigInt value) {
    return value.toRadixString(16).padLeft(64, '0').toLowerCase();
  }

  static Uint8List _hexToBytes(String hex) {
    final clean = hex.trim();
    final out = Uint8List(clean.length ~/ 2);
    for (int i = 0; i < out.length; i++) {
      out[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }
}

/// Stateless End-to-End Encrypted (E2EE) Blind Relay & Cross-Network P2P Sync Engine.
///
/// Enables devices to pair, ping, and bi-directionally synchronize across:
/// - Wi-Fi Routers with AP Client Isolation (2.4GHz vs 5GHz / Guest Wi-Fi / University Wi-Fi)
/// - Cellular Mobile Data (4G / 5G Carrier-Grade NAT `100.64.0.0/10` / 464XLAT)
/// - Different networks in different cities or countries
///
/// Security & Zero-Knowledge Architecture:
/// - Outer transport routing uses deterministic `secp256k1` room keypairs derived via `HMAC-SHA256(pairCode)`
///   and signed with genuine **BIP-340 Schnorr signatures** (`Bip340Schnorr`).
/// - Relays never see the 6-digit pair code, device names, or plaintext data.
/// - Every payload inside the envelope is encrypted end-to-end with `SyncCryptoService`
///   (PBKDF2-HMAC-SHA256 10,000 iterations + AES-256-CBC random IV + Encrypt-then-MAC HMAC-SHA256).
class P2pRelaySyncService {
  static final P2pRelaySyncService instance = P2pRelaySyncService._internal();
  P2pRelaySyncService._internal();

  static const String customRelayPrefKey = 'p2p_custom_relay_url_v1';
  static const int _ephemeralEventKind = 24242; // NIP-01 Ephemeral range (instant push)
  static const int _replaceableMailboxKind = 30078; // NIP-78 buffered event (eliminates connection race)
  static const int _maxChunkChars = 48000; // ~48KB per WebSocket frame to respect relay frame limits

  /// Public zero-knowledge WebSocket relays used as parallel redundant transports.
  static const List<String> defaultRelayUrls = [
    'wss://nos.lol',
    'wss://relay.damus.io',
    'wss://relay.primal.net',
  ];

  @visibleForTesting
  List<String>? overrideRelayUrlsForTesting;

  final SyncCryptoService _crypto = SyncCryptoService.instance;
  final Map<String, WebSocket> _sockets = {};
  final Map<String, StreamSubscription<dynamic>> _socketSubscriptions = {};
  final Map<String, List<Completer<Map<String, dynamic>>>> _pendingRpcReplies = {};
  final Map<String, Map<int, String>> _incomingChunkBuffers = {};
  final Set<String> _processedMessageIds = {};

  bool _isListening = false;
  bool get isListening => _isListening;
  int get connectedRelayCount =>
      _sockets.values.where((ws) => ws.readyState == WebSocket.open).length;

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
  /// The relay only sees this irreversible digest / x-only pubkey, never the pair code itself.
  @visibleForTesting
  static String deriveRoomHash(String pairCode) {
    return Bip340Schnorr.deriveRoomKeyPair(pairCode).pubHex;
  }

  /// Derives a deterministic 64-hex Nostr-compatible x-only pubkey from [deviceId] and [pairCode].
  @visibleForTesting
  static String deriveTransportPubkey(String deviceId, String pairCode) {
    return Bip340Schnorr.deriveRoomKeyPair(pairCode).pubHex;
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
    final override = overrideRelayUrlsForTesting;
    if (override != null && override.isNotEmpty) {
      return List<String>.from(override);
    }
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

  /// Saves or clears a custom self-hosted WebSocket relay URL (`wss://...`).
  Future<void> setCustomRelayUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) {
      await prefs.remove(customRelayPrefKey);
    } else {
      await prefs.setString(customRelayPrefKey, trimmed);
    }
    if (_isListening) {
      await stopRelayHostListener();
      await startRelayHostListener(
        deviceName: _hostDeviceName,
        primaryPairCode: _primaryPairCode,
        trustedPairCodes: _trustedPairCodes,
      );
    }
  }

  /// Retrieves the user-configured custom WebSocket relay URL, if any.
  Future<String?> getCustomRelayUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString(customRelayPrefKey)?.trim();
      return (val != null && val.isNotEmpty) ? val : null;
    } catch (_) {
      return null;
    }
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
    if (!_isListening && _trustedPairCodes.isEmpty) return;
    final urls = await getActiveRelayUrls();
    final pending = <Future<void>>[];
    for (final url in urls) {
      if (_sockets[url]?.readyState == WebSocket.open) {
        continue;
      }
      pending.add(_connectSingleRelay(url));
    }
    if (pending.isNotEmpty) {
      await Future.wait(pending);
    }
  }

  Future<void> _connectSingleRelay(String url) async {
    try {
      // ignore: close_sinks
      final ws = await WebSocket.connect(url).timeout(const Duration(seconds: 4));
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

  void _subscribeOnSocket(WebSocket ws, {Iterable<String>? extraPairCodes}) {
    final allCodes = <String>{
      ..._trustedPairCodes,
      if (extraPairCodes != null) ...extraPairCodes.map((c) => c.trim()).where((c) => c.isNotEmpty),
    };
    final roomPubkeys = allCodes.map((c) => Bip340Schnorr.deriveRoomKeyPair(c).pubHex).toSet().toList();
    if (roomPubkeys.isEmpty) return;
    final subFrame = json.encode([
      'REQ',
      'everything_p2p_sub',
      {
        'authors': roomPubkeys,
        'kinds': [_ephemeralEventKind, _replaceableMailboxKind],
        'since': (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 90,
      },
    ]);
    try {
      ws.add(subFrame);
    } catch (_) {}
  }

  /// Builds a signed NIP-01 `["EVENT", {...}]` frame using genuine BIP-340 Schnorr cryptography.
  @visibleForTesting
  static String buildSignedNostrEventFrame({
    required String pairCode,
    required int kind,
    required String content,
    required List<List<String>> tags,
    int? createdAtSeconds,
  }) {
    final keyPair = Bip340Schnorr.deriveRoomKeyPair(pairCode);
    final createdAt = createdAtSeconds ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final serializedForId = json.encode([
      0,
      keyPair.pubHex,
      createdAt,
      kind,
      tags,
      content,
    ]);
    final eventId = sha256.convert(utf8.encode(serializedForId)).toString();
    final sig = Bip340Schnorr.sign(eventId, keyPair.privHex);
    return json.encode([
      'EVENT',
      {
        'id': eventId,
        'pubkey': keyPair.pubHex,
        'created_at': createdAt,
        'kind': kind,
        'tags': tags,
        'content': content,
        'sig': sig,
      },
    ]);
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

      // Ignore stale buffered events older than 60 seconds
      final ts = envelope['ts'] is int ? envelope['ts'] as int : 0;
      if (ts > 0 && (DateTime.now().millisecondsSinceEpoch - ts).abs() > 60000) {
        return;
      }

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
    final roomPubHex = Bip340Schnorr.deriveRoomKeyPair(pairCode).pubHex;
    final chunks = splitCiphertextChunks(ciphertext);
    final msgId = type == 'ack' ? const Uuid().v4() : corrId;
    final allSockets = <WebSocket>{
      ..._sockets.values.where((ws) => ws.readyState == WebSocket.open),
      if (extraSockets != null) ...extraSockets.where((ws) => ws.readyState == WebSocket.open),
    };
    if (allSockets.isEmpty) return;

    final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiration = (createdAt + 120).toString();

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

      // Publish both buffered NIP-78 (kind 30078 with 120s expiration) and instant ephemeral (kind 24242)
      final bufferedFrame = buildSignedNostrEventFrame(
        pairCode: pairCode,
        kind: _replaceableMailboxKind,
        content: envelopeJson,
        createdAtSeconds: createdAt,
        tags: [
          ['d', '$msgId:$i'],
          ['p', roomPubHex],
          ['expiration', expiration],
        ],
      );
      final ephemeralFrame = buildSignedNostrEventFrame(
        pairCode: pairCode,
        kind: _ephemeralEventKind,
        content: envelopeJson,
        createdAtSeconds: createdAt,
        tags: [
          ['d', roomPubHex],
          ['p', roomPubHex],
        ],
      );

      for (final ws in allSockets) {
        try {
          ws.add(bufferedFrame);
          ws.add(ephemeralFrame);
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

    _trustedPairCodes.add(pairCode.trim());
    await _ensureRelayConnections();

    // If no background sockets are open yet, open temporary connections to the active relays
    final tempSockets = <WebSocket>[];
    final tempSubs = <StreamSubscription<dynamic>>[];
    if (_sockets.values.where((ws) => ws.readyState == WebSocket.open).isEmpty) {
      final urls = await getActiveRelayUrls();
      await Future.wait(
        urls.map((url) async {
          try {
            // ignore: close_sinks
            final ws = await WebSocket.connect(url).timeout(const Duration(seconds: 4));
            tempSockets.add(ws);
            _subscribeOnSocket(ws, extraPairCodes: [pairCode]);
            // ignore: cancel_subscriptions
            tempSubs.add(
              ws.listen((dynamic raw) {
                if (raw is String) {
                  unawaited(_handleRelayFrame(raw));
                }
              }),
            );
          } catch (_) {}
        }),
      );
    } else {
      // Ensure current pairCode room is subscribed on all open sockets
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

    Timer? retryTimer;
    try {
      await _publishEncryptedEnvelope(
        pairCode: pairCode,
        type: 'req',
        corrId: corrId,
        targetDeviceId: targetDeviceId,
        ciphertext: encrypted,
        extraSockets: tempSockets,
      );

      // Re-publish once at 2.5s if no ACK yet to eliminate subscription race conditions
      if (timeout > const Duration(seconds: 3)) {
        retryTimer = Timer(const Duration(milliseconds: 2500), () {
          if (!completer.isCompleted) {
            unawaited(
              _publishEncryptedEnvelope(
                pairCode: pairCode,
                type: 'req',
                corrId: corrId,
                targetDeviceId: targetDeviceId,
                ciphertext: encrypted,
                extraSockets: tempSockets,
              ),
            );
          }
        });
      }

      final replyEnvelope = await completer.future.timeout(timeout);
      final replyCipher = replyEnvelope['cipher'] as String?;
      if (replyCipher == null) return null;
      return _crypto.decryptPayload(replyCipher, pairCode);
    } catch (_) {
      return null;
    } finally {
      retryTimer?.cancel();
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
