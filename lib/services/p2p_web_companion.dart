import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../data/note_model.dart';
import '../features/notes/data/note_repository.dart';
import 'backup_service.dart';

typedef CompanionNotesLoader = Future<List<Note>> Function();
typedef CompanionBackupLoader = Future<String> Function();

class _CompanionSession {
  final String token;
  final DateTime expiresAt;

  const _CompanionSession({
    required this.token,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Read-only local Wi-Fi browser companion served on port 8765 alongside P2P sync.
class P2pWebCompanion {
  static final P2pWebCompanion instance = P2pWebCompanion();

  static const Duration sessionTtl = Duration(minutes: 30);
  static const int maxActiveSessions = 16;

  final CompanionNotesLoader _notesLoader;
  final CompanionBackupLoader _backupLoader;
  final Random _random = Random.secure();
  final Map<String, _CompanionSession> _sessions = <String, _CompanionSession>{};

  P2pWebCompanion({
    CompanionNotesLoader? notesLoader,
    CompanionBackupLoader? backupLoader,
  })  : _notesLoader = notesLoader ?? _defaultNotesLoader,
        _backupLoader = backupLoader ?? (() => generateBackupJson());

  static Future<List<Note>> _defaultNotesLoader() async {
    final active = await NoteRepository.instance.readAllNotes(
      isArchived: false,
      isTrashed: false,
    );
    final archived = await NoteRepository.instance.readAllNotes(
      isArchived: true,
      isTrashed: false,
    );
    return <Note>[...active, ...archived];
  }

  /// Clears all active in-memory companion sessions.
  void clearSessions() {
    _sessions.clear();
  }

  /// Returns `true` if [path] is handled by the browser companion.
  static bool canHandlePath(String path) {
    return path == '/' ||
        path == '/api/companion/unlock' ||
        path == '/api/companion/notes' ||
        path == '/api/companion/backup';
  }

  /// Handles companion HTTP routes. Returns `true` if the request was handled.
  Future<bool> handleRequest({
    required HttpRequest request,
    required String clientIp,
    required String userName,
    required List<String> trustedPairCodes,
    required Future<String?> Function() readBoundedBody,
    required void Function(String ip) onFailedAuth,
    required void Function(String ip) onClearAuth,
  }) async {
    final path = request.uri.path;
    final method = request.method.toUpperCase();
    // Closed by P2pSyncService._handlePrimaryHttpRequest's finally block.
    // ignore: close_sinks
    final response = request.response;

    if (path == '/' && method == 'GET') {
      await request.drain<void>().catchError((_) {});
      response.statusCode = HttpStatus.ok;
      response.headers.contentType = ContentType.html;
      response.headers.set('Cache-Control', 'no-store');
      response.headers.set('X-Content-Type-Options', 'nosniff');
      response.write(buildCompanionHtml(deviceName: userName));
      return true;
    }

    if (path == '/api/companion/unlock' && method == 'POST') {
      final body = await readBoundedBody();
      if (body == null) {
        response.statusCode = HttpStatus.requestEntityTooLarge;
        response.write(json.encode({'error': 'Payload exceeds limit.'}));
        return true;
      }

      final submittedCode = _extractSubmittedCode(body);
      if (submittedCode.isEmpty || !_matchesAnyCode(submittedCode, trustedPairCodes)) {
        onFailedAuth(clientIp);
        response.statusCode = HttpStatus.unauthorized;
        response.write(json.encode({'error': 'Invalid pair code.'}));
        return true;
      }

      onClearAuth(clientIp);
      final session = _issueSession();
      response.statusCode = HttpStatus.ok;
      response.headers.set('Cache-Control', 'no-store');
      response.write(json.encode({
        'token': session.token,
        'expiresInSeconds': sessionTtl.inSeconds,
        'deviceName': userName,
      }));
      return true;
    }

    if (path == '/api/companion/notes' && method == 'GET') {
      await request.drain<void>().catchError((_) {});
      if (!_isAuthorized(request)) {
        response.statusCode = HttpStatus.unauthorized;
        response.write(json.encode({'error': 'Valid pair-code session token required.'}));
        return true;
      }

      final allNotes = await _notesLoader();
      // Defense in depth: never expose locked or trashed notes to the browser companion.
      final visibleNotes = allNotes
          .where((note) => !note.isLocked && note.deletedAt == null)
          .map(_serializeNote)
          .toList(growable: false);

      response.statusCode = HttpStatus.ok;
      response.headers.set('Cache-Control', 'no-store');
      response.write(json.encode({
        'deviceName': userName,
        'count': visibleNotes.length,
        'notes': visibleNotes,
      }));
      return true;
    }

    if (path == '/api/companion/backup' && method == 'GET') {
      await request.drain<void>().catchError((_) {});
      if (!_isAuthorized(request)) {
        response.statusCode = HttpStatus.unauthorized;
        response.write(json.encode({'error': 'Valid pair-code session token required.'}));
        return true;
      }

      final backupJson = await _backupLoader();
      response.statusCode = HttpStatus.ok;
      response.headers.contentType = ContentType.json;
      response.headers.set('Cache-Control', 'no-store');
      response.headers.set(
        'Content-Disposition',
        'attachment; filename="everything-app-backup.json"',
      );
      response.write(backupJson);
      return true;
    }

    return false;
  }

  String _extractSubmittedCode(String rawBody) {
    try {
      final decoded = json.decode(rawBody);
      if (decoded is Map) {
        final raw = decoded['pairCode'] ?? decoded['code'];
        if (raw != null) {
          return raw.toString().trim();
        }
      }
    } catch (_) {}
    return '';
  }

  bool _matchesAnyCode(String submitted, List<String> trustedCodes) {
    for (final candidate in trustedCodes) {
      final clean = candidate.trim();
      if (clean.isNotEmpty && _constantTimeEquals(submitted, clean)) {
        return true;
      }
    }
    return false;
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  _CompanionSession _issueSession() {
    _pruneExpiredSessions();
    if (_sessions.length >= maxActiveSessions) {
      final oldestKey = _sessions.keys.first;
      _sessions.remove(oldestKey);
    }
    final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
    final token = base64UrlEncode(bytes).replaceAll('=', '');
    final session = _CompanionSession(
      token: token,
      expiresAt: DateTime.now().add(sessionTtl),
    );
    _sessions[token] = session;
    return session;
  }

  bool _isAuthorized(HttpRequest request) {
    _pruneExpiredSessions();
    final token = _extractToken(request);
    if (token == null || token.isEmpty) return false;
    final session = _sessions[token];
    if (session == null || session.isExpired) {
      _sessions.remove(token);
      return false;
    }
    return true;
  }

  String? _extractToken(HttpRequest request) {
    final authHeader = request.headers.value(HttpHeaders.authorizationHeader);
    if (authHeader != null && authHeader.toLowerCase().startsWith('bearer ')) {
      return authHeader.substring(7).trim();
    }
    final customHeader = request.headers.value('x-companion-token');
    if (customHeader != null && customHeader.trim().isNotEmpty) {
      return customHeader.trim();
    }
    final queryToken = request.uri.queryParameters['token'];
    if (queryToken != null && queryToken.trim().isNotEmpty) {
      return queryToken.trim();
    }
    return null;
  }

  void _pruneExpiredSessions() {
    _sessions.removeWhere((_, session) => session.isExpired);
  }

  Map<String, dynamic> _serializeNote(Note note) {
    return {
      'id': note.id,
      'title': note.title,
      'previewText': note.previewText ?? '',
      'plainText': _extractPlainText(note.content),
      'tags': note.tags,
      'category': note.category,
      'isPinned': note.isPinned,
      'isArchived': note.isArchived,
      'dateCreated': note.dateCreated.toIso8601String(),
      'dateModified': note.dateModified.toIso8601String(),
    };
  }

  /// Extracts readable plain text from Quill Delta JSON or raw string content.
  static String _extractPlainText(String rawContent) {
    final trimmed = rawContent.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      try {
        final decoded = json.decode(trimmed);
        final List<dynamic>? ops = decoded is List
            ? decoded
            : (decoded is Map && decoded['ops'] is List ? decoded['ops'] as List<dynamic> : null);
        if (ops != null) {
          final buffer = StringBuffer();
          for (final op in ops) {
            if (op is Map && op['insert'] is String) {
              buffer.write(op['insert']);
            }
          }
          return buffer.toString().trim();
        }
      } catch (_) {}
    }
    return trimmed;
  }

  /// Self-contained single-file HTML workspace for the local Wi-Fi browser companion.
  static String buildCompanionHtml({required String deviceName}) {
    final safeDeviceName = const HtmlEscape().convert(deviceName);
    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Everything App Companion</title>
  <style>
    :root {
      --bg: #141318;
      --bg-elevated: #1D1B24;
      --bg-subtle: #262430;
      --border: rgba(242, 242, 247, 0.12);
      --text: #F2F2F7;
      --text-muted: #A7A5B4;
      --accent: #6B4EFF;
      --accent-ink: #FFFFFF;
      --danger: #FF6B6B;
      --text-heading: 1.375rem;
      --text-body: 1rem;
      --text-sm: 0.875rem;
    }

    *, *::before, *::after { box-sizing: border-box; }

    body {
      margin: 0;
      min-height: 100dvh;
      background-color: var(--bg);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      font-size: var(--text-body);
      line-height: 1.55;
      font-variant-numeric: tabular-nums;
    }

    .topbar {
      border-bottom: 1px solid var(--border);
      background-color: var(--bg-elevated);
      padding: 14px 24px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
    }

    .brand {
      font-size: 1.0625rem;
      font-weight: 700;
      letter-spacing: -0.02em;
    }

    .device-meta {
      font-size: var(--text-sm);
      color: var(--text-muted);
    }

    .shell {
      width: min(1120px, 100% - 32px);
      margin: 28px auto 48px;
    }

    .unlock-panel {
      max-width: 440px;
      margin: 64px auto;
      padding: 28px;
      border-radius: 20px;
      background-color: var(--bg-elevated);
      border: 1px solid var(--border);
    }

    .unlock-panel h1 {
      margin: 0 0 8px;
      font-size: var(--text-heading);
      font-weight: 700;
      letter-spacing: -0.02em;
    }

    .unlock-panel p {
      margin: 0 0 20px;
      color: var(--text-muted);
      font-size: var(--text-body);
    }

    .field-label {
      display: block;
      margin-bottom: 8px;
      font-size: var(--text-sm);
      font-weight: 600;
    }

    .code-input, .search-input {
      width: 100%;
      min-height: 48px;
      padding: 0 14px;
      border-radius: 12px;
      border: 1px solid var(--border);
      background-color: var(--bg-subtle);
      color: var(--text);
      font-size: var(--text-body);
      font-variant-numeric: tabular-nums;
    }

    .primary-btn {
      margin-top: 16px;
      width: 100%;
      min-height: 48px;
      border: none;
      border-radius: 999px;
      background-color: var(--accent);
      color: var(--accent-ink);
      font-size: var(--text-body);
      font-weight: 600;
      cursor: pointer;
      transition: opacity 160ms cubic-bezier(0.22, 1, 0.36, 1);
    }

    .primary-btn:hover { opacity: 0.92; }

    .error-msg {
      margin: 12px 0 0;
      color: var(--danger);
      font-size: var(--text-sm);
      min-height: 20px;
    }

    .workspace-bar {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      justify-content: space-between;
      gap: 14px;
      margin-bottom: 20px;
    }

    .workspace-bar .search-input {
      max-width: 380px;
    }

    .action-btn {
      min-height: 44px;
      padding: 0 20px;
      border-radius: 999px;
      border: 1px solid var(--border);
      background-color: var(--bg-elevated);
      color: var(--text);
      font-size: var(--text-sm);
      font-weight: 600;
      cursor: pointer;
      transition: background-color 160ms cubic-bezier(0.22, 1, 0.36, 1);
    }

    .action-btn:hover {
      background-color: var(--bg-subtle);
    }

    .workspace-grid {
      display: grid;
      grid-template-columns: 320px 1fr;
      gap: 20px;
      align-items: start;
    }

    .note-list {
      border: 1px solid var(--border);
      border-radius: 16px;
      background-color: var(--bg-elevated);
      overflow: hidden;
    }

    .note-row {
      width: 100%;
      text-align: left;
      padding: 14px 16px;
      border: none;
      border-bottom: 1px solid var(--border);
      background: transparent;
      color: var(--text);
      cursor: pointer;
      display: grid;
      gap: 4px;
      transition: background-color 140ms cubic-bezier(0.22, 1, 0.36, 1);
    }

    .note-row:last-child { border-bottom: none; }
    .note-row:hover, .note-row.is-active { background-color: var(--bg-subtle); }

    .note-row-title {
      font-size: var(--text-body);
      font-weight: 600;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .note-row-meta {
      font-size: var(--text-sm);
      color: var(--text-muted);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .reader-pane {
      border: 1px solid var(--border);
      border-radius: 16px;
      background-color: var(--bg-elevated);
      padding: 24px;
      min-height: 360px;
    }

    .reader-title {
      margin: 0 0 8px;
      font-size: var(--text-heading);
      font-weight: 700;
      letter-spacing: -0.02em;
    }

    .reader-meta {
      margin: 0 0 20px;
      font-size: var(--text-sm);
      color: var(--text-muted);
      padding-bottom: 14px;
      border-bottom: 1px solid var(--border);
    }

    .reader-body {
      margin: 0;
      white-space: pre-wrap;
      word-break: break-word;
      font-size: var(--text-body);
      max-width: 65ch;
    }

    .hidden { display: none; }

    @media (max-width: 760px) {
      .workspace-grid {
        grid-template-columns: 1fr;
      }
      .workspace-bar .search-input {
        max-width: none;
      }
    }

    @media (prefers-reduced-motion: reduce) {
      .primary-btn, .action-btn, .note-row { transition: none; }
    }
  </style>
</head>
<body>
  <header class="topbar">
    <span class="brand">Everything App Companion</span>
    <span class="device-meta">Host: $safeDeviceName</span>
  </header>

  <main class="shell">
    <section id="unlock-view" class="unlock-panel">
      <h1>Unlock local notes</h1>
      <p>Enter the 6-digit pair code shown on your phone to browse unlocked notes over local Wi-Fi.</p>
      <form id="unlock-form">
        <label class="field-label" for="pair-code">Pair code</label>
        <input class="code-input" id="pair-code" type="password" inputmode="numeric" autocomplete="one-time-code" maxlength="12" placeholder="6-digit code" required>
        <button class="primary-btn" type="submit">Unlock workspace</button>
        <p class="error-msg" id="unlock-error" role="alert"></p>
      </form>
    </section>

    <section id="workspace-view" class="hidden">
      <div class="workspace-bar">
        <input class="search-input" id="search-input" type="search" placeholder="Filter unlocked notes">
        <button class="action-btn" id="download-backup-btn" type="button">Download backup JSON</button>
      </div>
      <div class="workspace-grid">
        <div class="note-list" id="note-list" role="listbox" aria-label="Unlocked notes"></div>
        <article class="reader-pane" id="reader-pane">
          <h2 class="reader-title" id="reader-title">Select a note</h2>
          <p class="reader-meta" id="reader-meta">Read-only local Wi-Fi session. Locked notes remain hidden on device.</p>
          <p class="reader-body" id="reader-body"></p>
        </article>
      </div>
    </section>
  </main>

  <script>
    (function () {
      var sessionToken = '';
      var allNotes = [];
      var activeNoteId = '';

      var unlockView = document.getElementById('unlock-view');
      var workspaceView = document.getElementById('workspace-view');
      var unlockForm = document.getElementById('unlock-form');
      var pairInput = document.getElementById('pair-code');
      var unlockError = document.getElementById('unlock-error');
      var searchInput = document.getElementById('search-input');
      var noteListEl = document.getElementById('note-list');
      var readerTitle = document.getElementById('reader-title');
      var readerMeta = document.getElementById('reader-meta');
      var readerBody = document.getElementById('reader-body');
      var backupBtn = document.getElementById('download-backup-btn');

      unlockForm.addEventListener('submit', function (e) {
        e.preventDefault();
        unlockError.textContent = '';
        var code = pairInput.value.trim();
        fetch('/api/companion/unlock', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ pairCode: code })
        })
          .then(function (res) {
            if (!res.ok) {
              throw new Error(res.status === 429 ? 'Too many attempts. Wait a minute.' : 'Invalid pair code.');
            }
            return res.json();
          })
          .then(function (data) {
            sessionToken = data.token;
            unlockView.classList.add('hidden');
            workspaceView.classList.remove('hidden');
            return loadNotes();
          })
          .catch(function (err) {
            unlockError.textContent = err.message || 'Unable to unlock.';
          });
      });

      function loadNotes() {
        return fetch('/api/companion/notes', {
          headers: { 'Authorization': 'Bearer ' + sessionToken }
        })
          .then(function (res) {
            if (!res.ok) throw new Error('Session expired');
            return res.json();
          })
          .then(function (data) {
            allNotes = data.notes || [];
            renderList();
            if (allNotes.length > 0) {
              selectNote(allNotes[0].id);
            }
          });
      }

      function renderList() {
        var q = searchInput.value.trim().toLowerCase();
        var filtered = allNotes.filter(function (n) {
          if (!q) return true;
          return (n.title || '').toLowerCase().indexOf(q) !== -1 ||
                 (n.plainText || '').toLowerCase().indexOf(q) !== -1 ||
                 (n.tags || []).join(' ').toLowerCase().indexOf(q) !== -1;
        });

        noteListEl.innerHTML = '';
        if (filtered.length === 0) {
          var empty = document.createElement('div');
          empty.className = 'note-row';
          empty.textContent = 'No matching unlocked notes.';
          noteListEl.appendChild(empty);
          return;
        }

        filtered.forEach(function (note) {
          var btn = document.createElement('button');
          btn.type = 'button';
          btn.className = 'note-row' + (note.id === activeNoteId ? ' is-active' : '');
          btn.addEventListener('click', function () { selectNote(note.id); });

          var title = document.createElement('span');
          title.className = 'note-row-title';
          title.textContent = note.title || 'Untitled';

          var meta = document.createElement('span');
          meta.className = 'note-row-meta';
          meta.textContent = (note.category || 'All Notes') + ' · ' + (note.dateModified || '').slice(0, 10);

          btn.appendChild(title);
          btn.appendChild(meta);
          noteListEl.appendChild(btn);
        });
      }

      function selectNote(id) {
        activeNoteId = id;
        var note = allNotes.find(function (n) { return n.id === id; });
        if (!note) return;
        readerTitle.textContent = note.title || 'Untitled';
        var tagsText = (note.tags && note.tags.length) ? ' · Tags: ' + note.tags.join(', ') : '';
        readerMeta.textContent = 'Modified ' + (note.dateModified || '').slice(0, 16).replace('T', ' ') + tagsText;
        readerBody.textContent = note.plainText || note.previewText || '';
        renderList();
      }

      searchInput.addEventListener('input', renderList);

      backupBtn.addEventListener('click', function () {
        if (!sessionToken) return;
        window.location.href = '/api/companion/backup?token=' + encodeURIComponent(sessionToken);
      });
    })();
  </script>
</body>
</html>
''';
  }
}
