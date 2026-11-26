import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:note_taking_app/data/note_model.dart';
import 'package:note_taking_app/services/p2p_web_companion.dart';

void main() {
  late HttpServer server;
  late P2pWebCompanion companion;
  late HttpClient client;
  final failedAttempts = <String, int>{};

  final sampleNotes = <Note>[
    Note(
      id: 'note-public-1',
      title: 'Grocery List',
      content: json.encode([
        {'insert': 'Buy coffee beans and oats\n'}
      ]),
      dateCreated: DateTime(2026, 11, 20),
      dateModified: DateTime(2026, 11, 25),
      tags: ['home'],
      previewText: 'Buy coffee beans and oats',
      isLocked: false,
    ),
    Note(
      id: 'note-locked-2',
      title: 'Private Recovery Codes',
      content: json.encode([
        {'insert': 'SECRET-PIN-9999\n'}
      ]),
      dateCreated: DateTime(2026, 11, 21),
      dateModified: DateTime(2026, 11, 25),
      tags: ['vault'],
      previewText: 'SECRET-PIN-9999',
      isLocked: true,
    ),
    Note(
      id: 'note-trashed-3',
      title: 'Deleted Draft',
      content: 'Should not appear',
      dateCreated: DateTime(2026, 11, 19),
      dateModified: DateTime(2026, 11, 20),
      deletedAt: DateTime(2026, 11, 22),
      isLocked: false,
    ),
  ];

  setUp(() async {
    failedAttempts.clear();
    companion = P2pWebCompanion(
      notesLoader: () async => sampleNotes,
      backupLoader: () async => json.encode({
        'version': 3,
        'notesCount': 1,
      }),
    );

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((HttpRequest request) async {
      final ip = request.connectionInfo?.remoteAddress.address ?? '127.0.0.1';
      if ((failedAttempts[ip] ?? 0) >= 25) {
        await request.drain<void>().catchError((_) {});
        request.response.statusCode = HttpStatus.tooManyRequests;
        await request.response.close();
        return;
      }

      Future<String?> readBody() => utf8.decoder.bind(request).join();

      final handled = await companion.handleRequest(
        request: request,
        clientIp: ip,
        userName: 'Pixel 9 Pro',
        trustedPairCodes: const ['482913'],
        readBoundedBody: readBody,
        onFailedAuth: (addr) => failedAttempts[addr] = (failedAttempts[addr] ?? 0) + 1,
        onClearAuth: (addr) => failedAttempts.remove(addr),
      );
      if (!handled) {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });

    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await server.close(force: true);
  });

  Future<(int, String, HttpHeaders)> sendRequest(
    String method,
    String path, {
    String? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('http://127.0.0.1:${server.port}$path');
    final req = await client.openUrl(method, uri);
    headers?.forEach((k, v) => req.headers.set(k, v));
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.write(body);
    }
    final res = await req.close();
    final resBody = await utf8.decoder.bind(res).join();
    return (res.statusCode, resBody, res.headers);
  }

  test('GET / serves self-contained HTML companion workspace', () async {
    final (status, body, headers) = await sendRequest('GET', '/');
    expect(status, HttpStatus.ok);
    expect(headers.contentType?.mimeType, 'text/html');
    expect(body, contains('Everything App Companion'));
    expect(body, contains('Pixel 9 Pro'));
    expect(body, contains('/api/companion/unlock'));
  });

  test('notes and backup endpoints reject unauthenticated requests with 401', () async {
    final (notesStatus, _, _) = await sendRequest('GET', '/api/companion/notes');
    expect(notesStatus, HttpStatus.unauthorized);

    final (backupStatus, _, _) = await sendRequest('GET', '/api/companion/backup');
    expect(backupStatus, HttpStatus.unauthorized);

    final (badTokenStatus, _, _) = await sendRequest(
      'GET',
      '/api/companion/notes',
      headers: {'Authorization': 'Bearer invalid-token'},
    );
    expect(badTokenStatus, HttpStatus.unauthorized);
  });

  test('unlock rejects wrong pair code and returns session token for valid code', () async {
    final (failStatus, _, _) = await sendRequest(
      'POST',
      '/api/companion/unlock',
      body: json.encode({'pairCode': '000000'}),
    );
    expect(failStatus, HttpStatus.unauthorized);
    expect(failedAttempts['127.0.0.1'], 1);

    final (okStatus, okBody, _) = await sendRequest(
      'POST',
      '/api/companion/unlock',
      body: json.encode({'pairCode': '482913'}),
    );
    expect(okStatus, HttpStatus.ok);
    final decoded = json.decode(okBody) as Map<String, dynamic>;
    expect(decoded['token'], isA<String>());
    expect((decoded['token'] as String).length, greaterThan(16));
    expect(decoded['deviceName'], 'Pixel 9 Pro');
    expect(failedAttempts.containsKey('127.0.0.1'), isFalse);
  });

  test('authorized notes endpoint excludes locked and trashed notes', () async {
    final (_, unlockBody, _) = await sendRequest(
      'POST',
      '/api/companion/unlock',
      body: json.encode({'pairCode': '482913'}),
    );
    final token = (json.decode(unlockBody) as Map<String, dynamic>)['token'] as String;

    final (status, notesBody, _) = await sendRequest(
      'GET',
      '/api/companion/notes',
      headers: {'Authorization': 'Bearer $token'},
    );
    expect(status, HttpStatus.ok);

    final decoded = json.decode(notesBody) as Map<String, dynamic>;
    final notes = decoded['notes'] as List<dynamic>;
    expect(notes.length, 1);
    final first = notes.first as Map<String, dynamic>;
    expect(first['id'], 'note-public-1');
    expect(first['title'], 'Grocery List');
    expect(first['plainText'], 'Buy coffee beans and oats');
    expect(notesBody, isNot(contains('Private Recovery Codes')));
    expect(notesBody, isNot(contains('SECRET-PIN-9999')));
    expect(notesBody, isNot(contains('Deleted Draft')));
  });

  test('authorized backup endpoint returns downloadable JSON snapshot', () async {
    final (_, unlockBody, _) = await sendRequest(
      'POST',
      '/api/companion/unlock',
      body: json.encode({'pairCode': '482913'}),
    );
    final token = (json.decode(unlockBody) as Map<String, dynamic>)['token'] as String;

    final (status, backupBody, headers) = await sendRequest(
      'GET',
      '/api/companion/backup?token=$token',
    );
    expect(status, HttpStatus.ok);
    expect(headers.value('content-disposition'), contains('everything-app-backup.json'));
    final decoded = json.decode(backupBody) as Map<String, dynamic>;
    expect(decoded['version'], 3);
  });
}
