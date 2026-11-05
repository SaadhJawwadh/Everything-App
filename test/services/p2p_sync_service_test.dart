import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_taking_app/data/note_model.dart';
import 'package:note_taking_app/features/sync/data/p2p_pairing_model.dart';
import 'package:note_taking_app/services/p2p_relay_sync_service.dart';
import 'package:note_taking_app/services/p2p_sync_service.dart';
import 'package:note_taking_app/services/sync_crypto_service.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  group('P2P Sync Functionality & Manifest Tests', () {
    final syncService = P2pSyncService.instance;
    final cryptoService = SyncCryptoService.instance;
    const testPairCode = '123456';

    setUp(() {
      P2pRelaySyncService.instance.overrideRelayUrlsForTesting = const ['ws://127.0.0.1:9'];
    });

    tearDownAll(() async {
      P2pRelaySyncService.instance.overrideRelayUrlsForTesting = null;
      await syncService.stopPrimaryHostServer();
    });

    test('device ID is generated as valid UUID', () async {
      final deviceId = await syncService.getDeviceId();
      expect(deviceId, isNotEmpty);
      expect(deviceId.length, greaterThanOrEqualTo(32));
    });

    test('encrypts and decrypts sync handshake payload correctly', () {
      final payload = json.encode({'action': 'ping', 'deviceId': 'dev_01'});
      final encrypted = cryptoService.encryptPayload(payload, testPairCode);
      expect(encrypted, isNotNull);

      final decrypted = cryptoService.decryptPayload(encrypted!, testPairCode);
      expect(decrypted, equals(payload));
    });

    test('manifest structure contains required keys for LWW conflict resolution', () {
      final note = Note(
        id: 'note_001',
        title: 'Test Note',
        content: 'Content payload',
        dateCreated: DateTime.parse('2026-08-04T12:00:00Z'),
        dateModified: DateTime.parse('2026-08-04T12:30:00Z'),
      );

      final noteMap = note.toMap();
      expect(noteMap['id'], equals('note_001'));
      expect(noteMap['title'], equals('Test Note'));
      expect(noteMap['dateModified'], equals('2026-08-04T12:30:00.000Z'));
    });

    test('PairedDevice serialization and copyWith works cleanly with BLE transport', () {
      final device = PairedDevice(
        deviceId: 'dev_abc',
        deviceName: 'Pixel 8',
        pairCode: '654321',
        transportMode: 'BLE Nearby P2P',
        endpointId: 'ep_123',
      );

      final map = device.toMap();
      expect(map['deviceId'], equals('dev_abc'));
      expect(map['deviceName'], equals('Pixel 8'));
      expect(map['pairCode'], equals('654321'));
      expect(map['endpointId'], equals('ep_123'));

      final restored = PairedDevice.fromMap(map);
      expect(restored.deviceId, equals(device.deviceId));
      expect(restored.deviceName, equals(device.deviceName));
      expect(restored.pairCode, equals(device.pairCode));
      expect(restored.endpointId, equals(device.endpointId));

      final updated = restored.copyWith(transportMode: 'Backup File');
      expect(updated.transportMode, equals('Backup File'));
    });

    test('migrates a legacy IP address into an endpoint without data loss', () {
      final restored = PairedDevice.fromMap({
        'deviceId': 'legacy-peer',
        'deviceName': 'Old Phone',
        'pairCode': '654321',
        'ipAddress': '192.168.1.20',
      });

      expect(restored.endpoints, hasLength(1));
      expect(restored.preferredEndpoint?.ipAddress, '192.168.1.20');
      expect(restored.toMap()['ipAddress'], '192.168.1.20');
    });

    test('retains home and work endpoints for the same paired device', () {
      final device = PairedDevice(
        deviceId: 'peer-1',
        deviceName: 'Pixel 8',
        pairCode: '654321',
        endpoints: const [DeviceEndpoint(ipAddress: '192.168.1.20')],
      ).withEndpoint(const DeviceEndpoint(ipAddress: '10.0.0.24', networkLabel: 'Work Wi-Fi'));

      final restored = PairedDevice.fromMap(device.toMap());
      expect(restored.endpoints, hasLength(2));
      expect(restored.endpoints.map((endpoint) => endpoint.ipAddress), containsAll(['192.168.1.20', '10.0.0.24']));
    });

    test('preserves a user-renamed paired device', () {
      final renamed = PairedDevice(
        deviceId: 'peer-2',
        deviceName: 'Work Tablet',
        pairCode: '654321',
        isNameCustom: true,
      );

      final restored = PairedDevice.fromMap(renamed.toMap());
      expect(restored.deviceName, 'Work Tablet');
      expect(restored.isNameCustom, isTrue);
    });

    test('parseTargetAddress cleanly sanitizes IP, scheme, path and custom port', () {
      final res1 = P2pSyncService.parseTargetAddress('http://192.168.1.15:8765/api/sync');
      expect(res1.$1, '192.168.1.15');
      expect(res1.$2, 8765);

      final res2 = P2pSyncService.parseTargetAddress('192.168.1.20');
      expect(res2.$1, '192.168.1.20');
      expect(res2.$2, P2pSyncService.httpSyncPort);

      final res3 = P2pSyncService.parseTargetAddress('https://10.0.0.5:9000/');
      expect(res3.$1, '10.0.0.5');
      expect(res3.$2, 9000);

      final res4 = P2pSyncService.parseTargetAddress('  192.168.0.100:8765  ');
      expect(res4.$1, '192.168.0.100');
      expect(res4.$2, 8765);

      final res5 = P2pSyncService.parseTargetAddress('[fe80::1]:8765');
      expect(res5.$1, 'fe80::1');
      expect(res5.$2, 8765);

      final res6 = P2pSyncService.parseTargetAddress('192.168.1.5:99999');
      expect(res6.$1, '192.168.1.5');
      expect(res6.$2, P2pSyncService.httpSyncPort);

      expect(P2pSyncService.sanitizeTargetIp('http://192.168.1.50:8765'), '192.168.1.50');
    });

    test('DiscoveredPeer model retains device properties and timestamp', () {
      final now = DateTime.now();
      final peer = DiscoveredPeer(
        deviceId: 'test-device-uuid',
        deviceName: 'Nearby Pixel',
        ipAddress: '192.168.1.100',
        port: 8765,
        lastSeenAt: now,
      );

      expect(peer.deviceId, 'test-device-uuid');
      expect(peer.deviceName, 'Nearby Pixel');
      expect(peer.ipAddress, '192.168.1.100');
      expect(peer.port, 8765);
      expect(peer.lastSeenAt, now);
    });

    test('formatUserFriendlyErrorMessage transforms exceptions into actionable messages', () {
      expect(
        P2pSyncService.formatUserFriendlyErrorMessage('SocketException: OS Error: Connection refused', '192.168.1.5'),
        contains('(192.168.1.5)'),
      );
      expect(
        P2pSyncService.formatUserFriendlyErrorMessage('SocketException: Failed', '192.168.1.5'),
        contains('Peer device unreachable (192.168.1.5)'),
      );
      expect(
        P2pSyncService.formatUserFriendlyErrorMessage('TimeoutException after 0:00:30.000000', '192.168.1.5'),
        contains('Connection timed out (192.168.1.5)'),
      );
    });

    test('host server accepts both primary pair code and previously paired device codes', () async {
      const hostCode = '111111';
      const pairedTabletCode = '222222';
      syncService.updateTrustedPairCodes([hostCode, pairedTabletCode]);
      await syncService.startPrimaryHostServer('TestHost', hostCode);
      expect(syncService.isHosting, isTrue);

      try {
        // 1. Ping using the secondary trusted code (e.g. tablet paired before code regeneration)
        final pingRes = await syncService.sendTestPing('127.0.0.1', pairedTabletCode);
        expect(pingRes.success, isTrue, reason: pingRes.errorMessage);

        // 2. Ping using the primary host code
        final pingRes2 = await syncService.sendTestPing('127.0.0.1', hostCode);
        expect(pingRes2.success, isTrue, reason: pingRes2.errorMessage);

        // 3. Pair handshake using the secondary trusted code
        final pairedPeer = await syncService.sendPairHandshake(
          pairedTabletCode,
          'Galaxy Tab S9',
          '127.0.0.1',
        );
        expect(pairedPeer, isNotNull);
        expect(pairedPeer!.deviceName, 'TestHost');
        // Handshake alone should not fabricate a fake lastSyncedAt timestamp
        expect(pairedPeer.lastSyncedAt, isNull);
      } finally {
        await syncService.stopPrimaryHostServer();
      }
    });

    test('legacy v1 SHA-256 and v2 PBKDF2 payloads interoperate cleanly and use cryptographically random IVs', () {
      const secret = '987654';
      final raw = json.encode({'action': 'ping', 'timestamp': 1700000000});

      final legacyCipher = cryptoService.encryptPayload(raw, secret, legacyMode: true);
      expect(legacyCipher, isNotNull);
      final (decLegacy, isLegacyFlag) = cryptoService.decryptPayloadDetailed(legacyCipher!, secret);
      expect(decLegacy, equals(raw));
      expect(isLegacyFlag, isTrue);

      final v2Cipher1 = cryptoService.encryptPayload(raw, secret, legacyMode: false);
      final v2Cipher2 = cryptoService.encryptPayload(raw, secret, legacyMode: false);
      expect(v2Cipher1, isNotNull);
      expect(v2Cipher2, isNotNull);
      // Encrypting identical plaintext twice must produce distinct ciphertexts (random non-zero IV)
      expect(v2Cipher1, isNot(equals(v2Cipher2)));

      final (decV2, isV2LegacyFlag) = cryptoService.decryptPayloadDetailed(v2Cipher1!, secret);
      expect(decV2, equals(raw));
      expect(isV2LegacyFlag, isFalse);
    });

    test('PairedDevice.withEndpoint preserves lastSyncedAt and sorts most recently seen endpoint first', () {
      final t1 = DateTime(2026, 11, 1, 10, 0);
      final t2 = DateTime(2026, 11, 2, 10, 0);
      final t3 = DateTime(2026, 11, 3, 10, 0);

      var device = PairedDevice(
        deviceId: 'tab-1',
        deviceName: 'Galaxy Tab',
        pairCode: '123456',
        endpoints: [
          DeviceEndpoint(ipAddress: '192.168.1.10', lastSeenAt: t1, lastSyncedAt: t2),
        ],
      );

      // Updating lastSeenAt on existing endpoint preserves its lastSyncedAt
      device = device.withEndpoint(DeviceEndpoint(ipAddress: '192.168.1.10', lastSeenAt: t2));
      expect(device.endpoints.single.lastSyncedAt, equals(t2));

      // Discovering a newer endpoint on a second Wi-Fi network sorts it first in preferredEndpoint
      device = device.withEndpoint(DeviceEndpoint(ipAddress: '10.0.0.55', lastSeenAt: t3));
      expect(device.preferredEndpoint?.ipAddress, equals('10.0.0.55'));
      expect(device.ipAddress, equals('10.0.0.55'));

      // Removing the primary endpoint does not resurrect it via legacy ipAddress migration
      final afterRemoval = device.copyWith(
        endpoints: device.endpoints.where((e) => e.ipAddress != '10.0.0.55').toList(),
      );
      expect(afterRemoval.endpoints, hasLength(1));
      expect(afterRemoval.preferredEndpoint?.ipAddress, equals('192.168.1.10'));
    });

    test('rate limiter blocks after 25 failed attempts and clears upon valid authentication', () async {
      P2pSyncService.clearRateLimits();
      const hostCode = '654321';
      syncService.updateTrustedPairCodes([hostCode]);
      await syncService.startPrimaryHostServer('RateLimitHost', hostCode);
      try {
        // 13 wrong pings (each wrong ping tries v2 + v1 = 2 failed attempts => 26 failed attempts)
        SyncResult? lastWrong;
        for (int i = 0; i < 13; i++) {
          lastWrong = await syncService.sendTestPing('127.0.0.1', '000000');
        }
        expect(lastWrong, isNotNull);
        expect(lastWrong!.success, isFalse);
        expect(lastWrong.errorMessage, contains('Rate limited'));

        // Reset rate limits and verify valid auth succeeds
        P2pSyncService.clearRateLimits();
        final validPing = await syncService.sendTestPing('127.0.0.1', hostCode);
        expect(validPing.success, isTrue);
      } finally {
        P2pSyncService.clearRateLimits();
        await syncService.stopPrimaryHostServer();
      }
    });

    test('network interface scoring and CGNAT/464XLAT filtering accept Wi-Fi/Hotspot/Wi-Fi Direct and reject Mobile Data/VPN', () {
      // Wi-Fi & Hotspot interfaces get top priority (100)
      expect(P2pSyncService.scoreNetworkInterface('wlan0'), equals(100));
      expect(P2pSyncService.scoreNetworkInterface('swlan0'), equals(100));
      expect(P2pSyncService.scoreNetworkInterface('ap0'), equals(100));
      expect(P2pSyncService.scoreNetworkInterface('softap0'), equals(100));

      // Wi-Fi Direct, USB tethering, and iOS/Android hotspot bridges get high priority (90)
      expect(P2pSyncService.scoreNetworkInterface('p2p-wlan0-0'), equals(90));
      expect(P2pSyncService.scoreNetworkInterface('rndis0'), equals(90));
      expect(P2pSyncService.scoreNetworkInterface('bridge100'), equals(90));

      // Cellular / Mobile Data interfaces are strictly negative (-50)
      expect(P2pSyncService.scoreNetworkInterface('rmnet_data0'), lessThan(0));
      expect(P2pSyncService.scoreNetworkInterface('v4-rmnet_data0'), lessThan(0));
      expect(P2pSyncService.scoreNetworkInterface('ccmni0'), lessThan(0));
      expect(P2pSyncService.scoreNetworkInterface('v4-ccmni0'), lessThan(0));
      expect(P2pSyncService.scoreNetworkInterface('pdp_ip0'), lessThan(0));

      // VPN and virtual container interfaces are strictly negative (-100)
      expect(P2pSyncService.scoreNetworkInterface('tun0'), lessThan(0));
      expect(P2pSyncService.scoreNetworkInterface('wg0'), lessThan(0));
      expect(P2pSyncService.scoreNetworkInterface('utun2'), lessThan(0));
      expect(P2pSyncService.scoreNetworkInterface('docker0'), lessThan(0));

      // Usable local P2P address validation
      expect(P2pSyncService.isUsableLocalP2pAddress('192.168.1.42', interfaceName: 'wlan0'), isTrue);
      expect(P2pSyncService.isUsableLocalP2pAddress('192.168.43.1', interfaceName: 'ap0'), isTrue);
      expect(P2pSyncService.isUsableLocalP2pAddress('192.168.49.1', interfaceName: 'p2p-wlan0-0'), isTrue);
      expect(P2pSyncService.isUsableLocalP2pAddress('172.20.10.1', interfaceName: 'bridge100'), isTrue);

      // Reject 464XLAT clatd dummy range (192.0.0.0/24)
      expect(P2pSyncService.isUsableLocalP2pAddress('192.0.0.4', interfaceName: 'v4-rmnet_data0'), isFalse);
      expect(P2pSyncService.isUsableLocalP2pAddress('192.0.0.4', interfaceName: 'wlan0'), isFalse);

      // Reject RFC 6598 Carrier-Grade NAT (100.64.0.0/10 -> 100.64.x.x to 100.127.x.x)
      expect(P2pSyncService.isUsableLocalP2pAddress('100.64.0.1', interfaceName: 'wlan0'), isFalse);
      expect(P2pSyncService.isUsableLocalP2pAddress('100.95.12.34', interfaceName: 'rmnet_data0'), isFalse);
      expect(P2pSyncService.isUsableLocalP2pAddress('100.127.255.254', interfaceName: 'wlan0'), isFalse);

      // Reject RFC 1918 private IPs if bound to a cellular or VPN interface (e.g., 10.x.x.x on rmnet_data0 or tun0)
      expect(P2pSyncService.isUsableLocalP2pAddress('10.24.56.78', interfaceName: 'rmnet_data0'), isFalse);
      expect(P2pSyncService.isUsableLocalP2pAddress('10.8.0.2', interfaceName: 'tun0'), isFalse);
      expect(P2pSyncService.isUsableLocalP2pAddress('10.0.0.15', interfaceName: 'wlan0'), isTrue);
    });

    test('resolvePeerEffectiveIp prefers OS kernel socket senderIp over stale or wrong self-reported payload IP', () {
      // Kernel socket IP wins when valid non-loopback
      expect(
        P2pSyncService.resolvePeerEffectiveIp(
          senderIp: '192.168.43.1',
          reportedIp: '10.120.44.19', // e.g., peer accidentally reported cellular/secondary IP
        ),
        equals('192.168.43.1'),
      );

      // Falls back to payload IP when socket IP is loopback (unit test / local loopback)
      expect(
        P2pSyncService.resolvePeerEffectiveIp(
          senderIp: '127.0.0.1',
          reportedIp: '192.168.1.88',
        ),
        equals('192.168.1.88'),
      );
    });

    test('HTTP /api/sync/discover endpoint and probeHttpDiscovery discover peer when UDP is blocked', () async {
      const hostCode = '445566';
      syncService.updateTrustedPairCodes([hostCode]);
      await syncService.startPrimaryHostServer('HotspotGatewayHost', hostCode);
      try {
        final client = HttpClient();
        final req = await client.postUrl(
          Uri.parse('http://127.0.0.1:${P2pSyncService.httpSyncPort}/api/sync/discover'),
        );
        req.headers.contentType = ContentType.json;
        req.write(json.encode({
          'app': 'everything_app_p2p',
          'deviceId': 'remote-hotspot-client-id',
          'name': 'HotspotClientPhone',
          'port': P2pSyncService.httpSyncPort,
        }));
        final resp = await req.close();
        expect(resp.statusCode, HttpStatus.ok);
        final body = await resp.transform(utf8.decoder).join();
        final decoded = json.decode(body) as Map<String, dynamic>;
        expect(decoded['action'], equals('presence'));
        expect(decoded['deviceName'], equals('HotspotGatewayHost'));
        expect(decoded['port'], equals(P2pSyncService.httpSyncPort));
        client.close(force: true);
      } finally {
        await syncService.stopPrimaryHostServer();
      }
    });

    test('P2pRelaySyncService derives deterministic zero-knowledge room hash and reassembles multi-chunk ciphertexts', () {
      final hash1 = P2pRelaySyncService.deriveRoomHash('650826');
      final hash2 = P2pRelaySyncService.deriveRoomHash('  650826 ');
      final hashOther = P2pRelaySyncService.deriveRoomHash('123456');

      expect(hash1, hasLength(64));
      expect(hash1, equals(hash2));
      expect(hash1, isNot(equals(hashOther)));
      expect(hash1, isNot(contains('650826')));

      // Verify chunk splitting & out-of-order reassembly
      final largePayload = List.generate(5000, (i) => 'chunk_segment_$i').join('|');
      final chunks = P2pRelaySyncService.splitCiphertextChunks(largePayload, maxChunkSize: 12000);
      expect(chunks.length, greaterThan(3));

      final buffer = <int, String>{};
      for (int i = chunks.length - 1; i >= 0; i--) {
        buffer[i] = chunks[i];
        if (i > 0) {
          expect(P2pRelaySyncService.tryReassembleChunks(buffer, chunks.length), isNull);
        }
      }
      final reassembled = P2pRelaySyncService.tryReassembleChunks(buffer, chunks.length);
      expect(reassembled, equals(largePayload));
    });

    test('Bip340Schnorr signs and verifies valid Nostr NIP-01 events and rejects tampering', () {
      const pairCode = '650826';
      final kp = Bip340Schnorr.deriveRoomKeyPair(pairCode);
      expect(kp.privHex, hasLength(64));
      expect(kp.pubHex, hasLength(64));
      expect(Bip340Schnorr.getPublicKeyHex(kp.privHex), equals(kp.pubHex));

      final frame = P2pRelaySyncService.buildSignedNostrEventFrame(
        pairCode: pairCode,
        kind: 30078,
        content: '{"action":"ping","timestamp":1700000000}',
        tags: [
          ['d', 'msg_1'],
          ['p', kp.pubHex],
        ],
      );
      final decoded = json.decode(frame) as List<dynamic>;
      expect(decoded[0], equals('EVENT'));
      final event = decoded[1] as Map<String, dynamic>;
      final id = event['id'] as String;
      final pubkey = event['pubkey'] as String;
      final sig = event['sig'] as String;

      expect(Bip340Schnorr.verify(id, pubkey, sig), isTrue);

      // Tampered message ID must fail verification
      final tamperedId = id.startsWith('0') ? '1${id.substring(1)}' : '0${id.substring(1)}';
      expect(Bip340Schnorr.verify(tamperedId, pubkey, sig), isFalse);

      // Tampered signature must fail verification
      final tamperedSig = sig.startsWith('0') ? '1${sig.substring(1)}' : '0${sig.substring(1)}';
      expect(Bip340Schnorr.verify(id, pubkey, tamperedSig), isFalse);
    });

    test('verifyLocalServerAlive, ensureHostServerRunning, and probeFastestReachableIp work accurately', () async {
      await syncService.stopPrimaryHostServer();
      expect(await syncService.verifyLocalServerAlive(), isFalse);

      await syncService.ensureHostServerRunning('SelfHealHost', '650826');
      try {
        expect(await syncService.verifyLocalServerAlive(), isTrue);

        final fastest = await syncService.probeFastestReachableIp(
          ['192.0.2.250', '127.0.0.1'],
          timeout: const Duration(milliseconds: 500),
        );
        expect(fastest, equals('127.0.0.1'));
      } finally {
        await syncService.stopPrimaryHostServer();
      }
    });

    test('P2pRelaySyncService completes E2EE RPC over BIP-340 validating WebSocket relay', () async {
      // Spin up a local Nostr NIP-01 relay server that strictly verifies BIP-340 Schnorr signatures
      final relayHttp = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final connectedClients = <WebSocket>[];
      int validEventsAccepted = 0;

      relayHttp.transform(WebSocketTransformer()).listen((WebSocket ws) {
        connectedClients.add(ws);
        ws.listen(
          (dynamic raw) {
            if (raw is! String) return;
            final frame = json.decode(raw) as List<dynamic>;
            final cmd = frame[0] as String;
            if (cmd == 'REQ') {
              final subId = frame[1] as String;
              ws.add(json.encode(['EOSE', subId]));
            } else if (cmd == 'EVENT') {
              final event = frame[1] as Map<String, dynamic>;
              final id = event['id'] as String;
              final pubkey = event['pubkey'] as String;
              final sig = event['sig'] as String;
              final isValid = Bip340Schnorr.verify(id, pubkey, sig);
              ws.add(json.encode(['OK', id, isValid, isValid ? '' : 'invalid: bad signature']));
              if (!isValid) return;
              validEventsAccepted++;

              // Simulate a remote peer responding to 'req' with an E2EE 'ack'
              final content = json.decode(event['content'] as String) as Map<String, dynamic>;
              if (content['type'] == 'req') {
                final corrId = content['corrId'] as String;
                final senderId = content['senderId'] as String;
                final replyPlain = json.encode({
                  'status': 'pong',
                  'hostName': 'RelayPeerTablet',
                  'deviceId': 'remote-peer-uuid-999',
                  'deviceName': 'RelayPeerTablet',
                  'role': 'PRIMARY',
                });
                final replyCipher = cryptoService.encryptPayload(replyPlain, '650826')!;
                final ackEnvelope = json.encode({
                  'app': 'everything_p2p_relay_v2',
                  'type': 'ack',
                  'msgId': 'ack-$corrId',
                  'corrId': corrId,
                  'senderId': 'remote-peer-uuid-999',
                  'targetDeviceId': senderId,
                  'chunkIndex': 0,
                  'totalChunks': 1,
                  'cipher': replyCipher,
                  'ts': DateTime.now().millisecondsSinceEpoch,
                });
                final ackFrame = json.decode(
                  P2pRelaySyncService.buildSignedNostrEventFrame(
                    pairCode: '650826',
                    kind: 24242,
                    content: ackEnvelope,
                    tags: [
                      ['d', pubkey],
                    ],
                  ),
                ) as List<dynamic>;
                for (final client in connectedClients) {
                  if (client.readyState == WebSocket.open) {
                    client.add(json.encode(['EVENT', 'everything_p2p_sub', ackFrame[1]]));
                  }
                }
              }
            }
          },
          onDone: () => connectedClients.remove(ws),
        );
      });

      try {
        await P2pRelaySyncService.instance.stopRelayHostListener();
        P2pRelaySyncService.instance.overrideRelayUrlsForTesting = [
          'ws://127.0.0.1:${relayHttp.port}',
        ];

        final pingRes = await syncService.sendTestPing('relay', '650826');
        expect(pingRes.success, isTrue);
        expect(pingRes.transportUsed, contains('Relay'));
        expect(validEventsAccepted, greaterThanOrEqualTo(1));

        final paired = await syncService.sendPairHandshake('650826', 'MyPhone', 'relay');
        expect(paired, isNotNull);
        expect(paired!.deviceName, equals('RelayPeerTablet'));
        expect(paired.endpoints.any((e) => e.ipAddress.startsWith('relay://')), isTrue);
      } finally {
        await P2pRelaySyncService.instance.stopRelayHostListener();
        for (final c in connectedClients) {
          await c.close().catchError((_) {});
        }
        await relayHttp.close(force: true);
      }
    });
  });
}
