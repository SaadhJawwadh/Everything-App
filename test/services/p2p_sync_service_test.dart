import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_taking_app/data/note_model.dart';
import 'package:note_taking_app/features/sync/data/p2p_pairing_model.dart';
import 'package:note_taking_app/services/p2p_sync_service.dart';
import 'package:note_taking_app/services/sync_crypto_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P2P Sync Functionality & Manifest Tests', () {
    final syncService = P2pSyncService.instance;
    final cryptoService = SyncCryptoService.instance;
    const testPairCode = '123456';

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
        contains('Peer device unreachable (192.168.1.5)'),
      );
      expect(
        P2pSyncService.formatUserFriendlyErrorMessage('TimeoutException after 0:00:30.000000', '192.168.1.5'),
        contains('Connection timed out (192.168.1.5)'),
      );
    });
  });
}
