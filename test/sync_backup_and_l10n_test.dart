import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_test/flutter_test.dart';
import 'package:note_taking_app/l10n/app_localizations.dart';
import 'package:note_taking_app/services/backup_service.dart';
import 'package:note_taking_app/services/native_core_bridge.dart';
import 'package:note_taking_app/services/p2p_relay_sync_service.dart';
import 'package:note_taking_app/services/p2p_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupService v3 Encrypt-then-MAC & v2 Backward Compatibility', () {
    test('encryptBackupJson outputs version 3 with HMAC and round-trips cleanly', () {
      const sampleJson = '{"notes":[{"id":"n1","title":"Test"}],"transactions":[]}';
      const passphrase = 'correct-horse-battery-staple';

      final encoded = BackupService.encryptBackupJson(sampleJson, passphrase);
      final container = jsonDecode(encoded) as Map<String, dynamic>;

      expect(container['version'], 3);
      expect(container['encrypted'], isTrue);
      expect((container['mac'] as String?)?.isNotEmpty, isTrue);

      final decrypted = BackupService.decryptBackupJson(container, passphrase);
      expect(decrypted, sampleJson);
    });

    test('decryptBackupJson rejects tampered ciphertext or tampered MAC with FormatException', () {
      const sampleJson = '{"notes":[],"transactions":[]}';
      const passphrase = 'my-strong-passphrase';

      final container = jsonDecode(BackupService.encryptBackupJson(sampleJson, passphrase)) as Map<String, dynamic>;

      // Flip a character in MAC
      final origMac = container['mac'] as String;
      final badMac = '${origMac[0] == 'A' ? 'B' : 'A'}${origMac.substring(1)}';
      expect(
        () => BackupService.decryptBackupJson({...container, 'mac': badMac}, passphrase),
        throwsFormatException,
      );

      // Flip a character inside ciphertext (even if still valid base64)
      final origCipher = container['ciphertext'] as String;
      final badCipher = '${origCipher[0] == 'A' ? 'B' : 'A'}${origCipher.substring(1)}';
      expect(
        () => BackupService.decryptBackupJson({...container, 'ciphertext': badCipher}, passphrase),
        throwsFormatException,
      );
    });

    test('decryptBackupJson rejects 50 wrong passphrases deterministically with 0 flakes', () {
      const sampleJson = '{"notes":[{"id":"1","title":"Check"}],"transactions":[]}';
      final container = jsonDecode(
        BackupService.encryptBackupJson(sampleJson, 'master-passphrase'),
      ) as Map<String, dynamic>;

      for (int i = 0; i < 50; i++) {
        expect(
          () => BackupService.decryptBackupJson(container, 'wrong-passphrase-$i'),
          throwsFormatException,
        );
      }
    });

    test('decryptBackupJson remains backward-compatible with legacy v2 containers without mac', () {
      const sampleJson = '{"notes":[{"id":"legacy"}],"transactions":[]}';
      const passphrase = 'legacy-password';
      final salt = Uint8List.fromList(List<int>.generate(16, (i) => i + 1));
      final keyBytes = NativeCoreBridge.instance.derivePbkdf2Sha256(
        secret: Uint8List.fromList(utf8.encode(passphrase)),
        salt: salt,
        iterations: 10000,
      );
      final iv = enc.IV.fromSecureRandom(16);
      final encrypter = enc.Encrypter(enc.AES(enc.Key(keyBytes), mode: enc.AESMode.cbc));
      final encrypted = encrypter.encrypt(sampleJson, iv: iv);

      final v2Container = {
        'version': 2,
        'encrypted': true,
        'salt': base64.encode(salt),
        'iv': iv.base64,
        'ciphertext': encrypted.base64,
      };

      expect(BackupService.decryptBackupJson(v2Container, passphrase), sampleJson);
    });
  });

  group('P2pRelaySyncService Offline Mailbox Crash-Safety, 2-Way Reply & EOSE', () {
    tearDown(() {
      P2pRelaySyncService.instance.overrideRelayUrlsForTesting = null;
      P2pRelaySyncService.instance.onInboundRelayRequest = null;
    });

    test('drainOfflineRelayMailboxes exits early on EOSE and persists msgId only after merge succeeds', () async {
      const pairCode = '654321';
      SharedPreferences.setMockInitialValues({
        'p2p_device_id': 'device-receiver',
        'p2p_paired_devices_v2': jsonEncode([
          {
            'deviceId': 'device-sender',
            'deviceName': 'Peer Phone',
            'pairCode': pairCode,
            'endpoints': [],
          },
        ]),
      });

      final roomPubHex = P2pRelaySyncService.deriveRoomHash(pairCode);
      const inboundMsgId = 'mailbox-msg-eose-1';

      // Start local loopback WebSocket mock Nostr relay
      final publishedEvents = <Map<String, dynamic>>[];
      final serverSockets = <WebSocket>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

      // Prepare signed mailbox_push event built via buildSignedNostrEventFrame
      final serverSub = server.listen((HttpRequest req) async {
        if (!WebSocketTransformer.isUpgradeRequest(req)) {
          req.response.statusCode = HttpStatus.badRequest;
          await req.response.close();
          return;
        }
        // ignore: close_sinks
        final ws = await WebSocketTransformer.upgrade(req);
        serverSockets.add(ws);
        ws.listen((dynamic raw) {
          if (raw is! String) return;
          final msg = jsonDecode(raw) as List<dynamic>;
          if (msg[0] == 'REQ') {
            final subId = msg[1] as String;
            if (subId == 'everything_mailbox_drain') {
              // Immediately reply with one buffered mailbox_push event and then EOSE
              final outerReq = publishedEvents.firstWhere((e) => e['kind'] == 30078, orElse: () => {});
              if (outerReq.isNotEmpty) {
                ws.add(jsonEncode(['EVENT', subId, outerReq]));
              }
              ws.add(jsonEncode(['EOSE', subId]));
            }
          } else if (msg[0] == 'EVENT') {
            publishedEvents.add(msg[1] as Map<String, dynamic>);
          }
        });
      });

      try {
        // Seed one encrypted mailbox_push event from a different senderId
        final keyPair = Bip340Schnorr.deriveRoomKeyPair(pairCode);
        expect(keyPair.pubHex, roomPubHex);

        // Encrypt using SyncCryptoService via publishOfflineMailboxSync? Or construct ciphertext:
        // Wait: P2pRelaySyncService uses SyncCryptoService; let's use P2pRelaySyncService on loopback to seed first!
        P2pRelaySyncService.instance.overrideRelayUrlsForTesting = ['ws://127.0.0.1:${server.port}'];

        // Inject encrypted frame directly into mock relay storage with a different senderId
        final myDeviceId = await P2pSyncService.instance.getDeviceId();
        final envelopeJson = jsonEncode({
          'app': 'everything_p2p_relay_v2',
          'type': 'mailbox_push',
          'isMailboxReply': false,
          'msgId': inboundMsgId,
          'corrId': inboundMsgId,
          'senderId': 'device-sender',
          'targetDeviceId': myDeviceId,
          'chunkIndex': 0,
          'totalChunks': 1,
          'cipher': await _encryptTestPayload(pairCode, '{"notes":[],"transactions":[]}'),
          'ts': DateTime.now().millisecondsSinceEpoch,
        });
        final signedFrame = P2pRelaySyncService.buildSignedNostrEventFrame(
          pairCode: pairCode,
          kind: 30078,
          content: envelopeJson,
          tags: [
            ['d', 'mailbox:$roomPubHex:device-sender:0'],
            ['p', roomPubHex],
          ],
        );
        final parsedEvent = (jsonDecode(signedFrame) as List<dynamic>)[1] as Map<String, dynamic>;
        publishedEvents.add(parsedEvent);

        // 1. Simulate failed merge (handler throws): msgId MUST NOT be persisted!
        P2pRelaySyncService.instance.onInboundRelayRequest = (action, payload, code, isLegacy) async {
          throw StateError('Simulated mid-merge crash');
        };
        final mergedOnFailure = await P2pRelaySyncService.instance.drainOfflineRelayMailboxes();
        expect(mergedOnFailure, 0);
        final prefsAfterFail = await SharedPreferences.getInstance();
        expect(prefsAfterFail.getStringList('p2p_processed_mailbox_ids_v1') ?? const [], isNot(contains(inboundMsgId)));

        // 2. Now simulate healthy merge returning a 2-way return snapshot
        bool handlerCalled = false;
        P2pRelaySyncService.instance.onInboundRelayRequest = (action, payload, code, isLegacy) async {
          handlerCalled = true;
          return {'action': 'mailbox_reply_snapshot', 'notes': [], 'transactions': []};
        };

        final sw = Stopwatch()..start();
        final mergedOnSuccess = await P2pRelaySyncService.instance.drainOfflineRelayMailboxes();
        sw.stop();

        expect(handlerCalled, isTrue);
        expect(mergedOnSuccess, 1);
        // Verified early EOSE exit (well below the 4000ms worst-case timeout)
        expect(sw.elapsedMilliseconds, lessThan(2000));

        // Processed msgId IS now persisted after merge succeeded
        final prefsAfterSuccess = await SharedPreferences.getInstance();
        expect(prefsAfterSuccess.getStringList('p2p_processed_mailbox_ids_v1'), contains(inboundMsgId));

        // Give async unawaited 2-way return push a moment to publish to mock relay
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final replyEvents = publishedEvents.where((e) {
          final tags = (e['tags'] as List<dynamic>? ?? []);
          return tags.any((t) => t is List && t.isNotEmpty && t[0] == 'd' && t[1].toString().startsWith('mailbox_reply:'));
        }).toList();
        expect(replyEvents, isNotEmpty);
      } finally {
        for (final ws in serverSockets) {
          await ws.close().catchError((_) {});
        }
        await serverSub.cancel();
        await server.close(force: true);
      }
    });
  });

  group('Multi-Locale AppLocalizations Parity (All 8 Locales)', () {
    test('New Sync, Backup, and Finance Settings strings load across all 8 locales', () async {
      const supported = AppLocalizations.supportedLocales;
      expect(supported.length, 8);

      for (final locale in supported) {
        final l10n = await AppLocalizations.delegate.load(locale);
        expect(l10n.peerToPeerSync, isNotEmpty, reason: 'peerToPeerSync empty in ${locale.languageCode}');
        expect(l10n.p2pDeviceSync, isNotEmpty, reason: 'p2pDeviceSync empty in ${locale.languageCode}');
        expect(l10n.encryptedJsonBackups, isNotEmpty, reason: 'encryptedJsonBackups empty in ${locale.languageCode}');
        expect(l10n.masterP2pDeviceSync, isNotEmpty, reason: 'masterP2pDeviceSync empty in ${locale.languageCode}');
        expect(l10n.biDirectionalP2pSync, isNotEmpty, reason: 'biDirectionalP2pSync empty in ${locale.languageCode}');
        expect(l10n.financialManager, isNotEmpty, reason: 'financialManager empty in ${locale.languageCode}');
        expect(l10n.onDeviceSmartAi, isNotEmpty, reason: 'onDeviceSmartAi empty in ${locale.languageCode}');
        expect(l10n.discreetPrivacyMode, isNotEmpty, reason: 'discreetPrivacyMode empty in ${locale.languageCode}');
      }
    });
  });
}

Future<String> _encryptTestPayload(String pairCode, String jsonStr) async {
  // Mirror SyncCryptoService v2 envelope format so test uses exact production decrypt path
  final keyBytes = NativeCoreBridge.instance.derivePbkdf2Sha256(
    secret: Uint8List.fromList(utf8.encode(pairCode.trim())),
    salt: Uint8List.fromList(utf8.encode('EverythingApp_P2P_Sync_Salt_v2')),
    iterations: 10000,
  );
  final iv = enc.IV.fromSecureRandom(16);
  final encrypter = enc.Encrypter(enc.AES(enc.Key(keyBytes), mode: enc.AESMode.cbc));
  final encrypted = encrypter.encrypt(jsonStr, iv: iv);
  final wrapper = {'v': 2, 'iv': iv.base64, 'data': encrypted.base64};
  return base64.encode(utf8.encode(json.encode(wrapper)));
}
