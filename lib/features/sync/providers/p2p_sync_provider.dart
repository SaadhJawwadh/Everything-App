import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../services/p2p_sync_service.dart';
import '../data/p2p_pairing_model.dart';

enum SyncStatus { idle, hosting, connecting, syncing, completed, error }

/// Represents an immutable audit entry of a P2P sync exchange.
class SyncActivityEvent {
  final DateTime timestamp;
  final SyncResult result;
  final String? peerName;

  const SyncActivityEvent({
    required this.timestamp,
    required this.result,
    this.peerName,
  });
}

class P2pSyncProvider with ChangeNotifier {
  static const _storageKey = 'p2p_paired_devices_v2';
  static const _legacyStorageKey = 'p2p_paired_devices_v1';
  static const _autoSyncKey = 'p2p_auto_sync_enabled';
  static const _deviceNameKey = 'p2p_local_device_name_v1';
  static const _pairCodeKey = 'p2p_local_pair_code_v2';

  final P2pSyncService _service = P2pSyncService.instance;
  List<PairedDevice> _pairedDevices = [];
  List<PairedDevice> get pairedDevices => List.unmodifiable(_pairedDevices);
  final List<SyncActivityEvent> _recentActivity = [];
  List<SyncActivityEvent> get recentActivity => List.unmodifiable(_recentActivity);
  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;
  bool _isAutoSyncEnabled = true;
  bool get isAutoSyncEnabled => _isAutoSyncEnabled;
  DateTime? _lastSyncedAt;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? _lastMessage;
  String? get lastMessage => _lastMessage;
  String _currentPairCode = '';
  String get currentPairCode => _currentPairCode;
  String _localDeviceId = '';
  String get localDeviceId => _localDeviceId;
  String _localDeviceName = '';
  String get localDeviceName => _localDeviceName;
  String? _localIpAddress;
  String? get localIpAddress => _localIpAddress;
  SystemDiagnostics? _diagnostics;
  SystemDiagnostics? get diagnostics => _diagnostics;

  StreamSubscription<SyncResult>? _syncResultSubscription;
  StreamSubscription<PairedDevice>? _remotePairSubscription;
  Timer? _eventDebounceTimer;
  static P2pSyncProvider? _activeInstance;
  static P2pSyncProvider? get activeInstance => _activeInstance;

  P2pSyncProvider() {
    _activeInstance = this;
    unawaited(loadSettings());
  }

  @override
  void dispose() {
    _eventDebounceTimer?.cancel();
    _syncResultSubscription?.cancel();
    _remotePairSubscription?.cancel();
    unawaited(_service.stopPrimaryHostServer());
    if (identical(_activeInstance, this)) _activeInstance = null;
    super.dispose();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isAutoSyncEnabled = prefs.getBool(_autoSyncKey) ?? true;
    _localDeviceId = await _service.getDeviceId();
    _localDeviceName = prefs.getString(_deviceNameKey) ?? _defaultDeviceName(_localDeviceId);
    await prefs.setString(_deviceNameKey, _localDeviceName);
    _currentPairCode = prefs.getString(_pairCodeKey) ?? _newPairCode();
    await prefs.setString(_pairCodeKey, _currentPairCode);

    final rawJson = prefs.getString(_storageKey) ?? prefs.getString(_legacyStorageKey);
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final rawList = json.decode(rawJson) as List<dynamic>;
        final usedIds = <String>{};
        _pairedDevices = rawList.map((item) => PairedDevice.fromMap(Map<String, dynamic>.from(item as Map))).map((device) {
          if (usedIds.add(device.deviceId)) return device;
          final migrated = PairedDevice(
            deviceId: const Uuid().v4(),
            deviceName: device.deviceName,
            pairCode: device.pairCode,
            lastSyncedAt: device.lastSyncedAt,
            transportMode: device.transportMode,
            isPaired: device.isPaired,
            role: device.role,
            endpointId: device.endpointId,
            endpoints: device.endpoints,
            isNameCustom: device.isNameCustom,
          );
          usedIds.add(migrated.deviceId);
          return migrated;
        }).toList();
        await _saveDevicesToStorage();
      } catch (e) {
        debugPrint('[P2pSyncProvider] Failed to parse paired devices: $e');
        _pairedDevices = [];
      }
    }

    _syncResultSubscription ??= _service.syncEvents.listen(_handleSyncEvent);
    _remotePairSubscription ??= _service.remoteDevicePaired.listen((device) async => _upsertDevice(device));
    await refreshDiagnostics();
    await startPrimaryHostServer();
    notifyListeners();
  }

  void _handleSyncEvent(SyncResult result) {
    _recentActivity.insert(
      0,
      SyncActivityEvent(
        timestamp: DateTime.now(),
        result: result,
        peerName: _pairedDevices.isNotEmpty ? _pairedDevices.first.deviceName : null,
      ),
    );
    if (_recentActivity.length > 20) {
      _recentActivity.removeLast();
    }

    if (result.success) {
      _status = SyncStatus.completed;
      _lastSyncedAt = DateTime.now();
      _lastMessage = result.latencyMs != null
          ? 'Test ping succeeded (${result.latencyMs}ms)'
          : (result.syncedCount > 0 ? 'Sync complete' : result.transportUsed);
    } else {
      _status = SyncStatus.error;
      _lastMessage = result.errorMessage ?? 'Sync error';
    }
    notifyListeners();
  }

  String _newPairCode() => (100000 + Random.secure().nextInt(900000)).toString();

  String _defaultDeviceName(String deviceId) {
    return PairedDevice.generateRandomName();
  }

  Future<void> refreshDiagnostics() async {
    _diagnostics = await _service.runDiagnostics();
    _localIpAddress = _diagnostics?.localIp;
    notifyListeners();
  }

  Future<void> startPrimaryHostServer() async {
    _status = SyncStatus.hosting;
    notifyListeners();
    await _service.startPrimaryHostServer(_localDeviceName, _currentPairCode);
  }

  Future<void> renameLocalDevice(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _localDeviceName = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceNameKey, trimmed);
    await startPrimaryHostServer();
    notifyListeners();
  }

  Future<void> renamePairedDevice(String deviceId, String name) async {
    final index = _pairedDevices.indexWhere((device) => device.deviceId == deviceId);
    if (index == -1 || name.trim().isEmpty) return;
    _pairedDevices[index] = _pairedDevices[index].copyWith(deviceName: name.trim(), isNameCustom: true);
    await _saveDevicesToStorage();
    notifyListeners();
  }

  Future<void> setAutoSyncEnabled(bool enabled) async {
    _isAutoSyncEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSyncKey, enabled);
    notifyListeners();
  }

  String generateNewPairCode() {
    _currentPairCode = _newPairCode();
    unawaited(_persistPairCodeAndRestart());
    notifyListeners();
    return _currentPairCode;
  }

  Future<void> _persistPairCodeAndRestart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pairCodeKey, _currentPairCode);
    await startPrimaryHostServer();
  }

  Future<PairedDevice> pairNewDevice({
    required String deviceName,
    required String pairCode,
    String? targetIp,
    int targetPort = P2pSyncService.httpSyncPort,
    String? remoteDeviceId,
    String role = 'PRIMARY',
  }) async {
    if (targetIp == null || targetIp.trim().isEmpty || pairCode.trim().length != 6) {
      throw ArgumentError('A valid local IP address and six-digit pair code are required.');
    }
    final verifiedTargetIp = targetIp.trim();
    _status = SyncStatus.connecting;
    _lastMessage = 'Verifying ${deviceName.trim().isEmpty ? 'device' : deviceName}…';
    notifyListeners();

    _currentPairCode = pairCode.trim();
    await _persistPairCodeAndRestart();
    final verifiedRemoteDevice = await _service.sendPairHandshake(
      _currentPairCode,
      _localDeviceName,
      verifiedTargetIp,
      targetPort: targetPort,
    );
    if (verifiedRemoteDevice == null) {
      _status = SyncStatus.error;
      _lastMessage = 'Could not verify the device. Confirm both devices are on the same Wi-Fi and retry.';
      notifyListeners();
      throw StateError(_lastMessage!);
    }
    final verifiedRemoteDeviceId = remoteDeviceId?.trim();

    final device = PairedDevice(
      deviceId: verifiedRemoteDeviceId?.isNotEmpty == true ? verifiedRemoteDeviceId! : verifiedRemoteDevice.deviceId,
      deviceName: deviceName.trim().isEmpty ? verifiedRemoteDevice.deviceName : deviceName.trim(),
      pairCode: _currentPairCode,
      lastSyncedAt: DateTime.now(),
      transportMode: 'Primary Direct Sync',
      endpoints: [DeviceEndpoint(ipAddress: verifiedTargetIp, port: targetPort, lastSeenAt: DateTime.now())],
      role: role,
    );
    await _upsertDevice(device);
    _status = SyncStatus.completed;
    _lastMessage = 'Paired with ${device.deviceName}';
    notifyListeners();
    return device;
  }

  Future<void> _upsertDevice(PairedDevice incoming) async {
    final index = _pairedDevices.indexWhere((device) => device.deviceId == incoming.deviceId);
    if (index == -1) {
      _pairedDevices.add(incoming);
    } else {
      final existing = _pairedDevices[index];
      var updated = existing.copyWith(
        deviceName: existing.isNameCustom ? existing.deviceName : incoming.deviceName,
        pairCode: incoming.pairCode.isEmpty ? existing.pairCode : incoming.pairCode,
        lastSyncedAt: incoming.lastSyncedAt ?? existing.lastSyncedAt,
        transportMode: incoming.transportMode,
        role: incoming.role,
      );
      for (final endpoint in incoming.endpoints) {
        updated = updated.withEndpoint(endpoint);
      }
      _pairedDevices[index] = updated;
    }
    await _saveDevicesToStorage();
    notifyListeners();
  }

  Future<void> unpairDevice(String deviceId) async {
    _pairedDevices.removeWhere((device) => device.deviceId == deviceId);
    await _saveDevicesToStorage();
    notifyListeners();
  }

  Future<void> removeEndpoint(String deviceId, String ipAddress) async {
    final index = _pairedDevices.indexWhere((device) => device.deviceId == deviceId);
    if (index == -1) return;
    final device = _pairedDevices[index];
    _pairedDevices[index] = device.copyWith(endpoints: device.endpoints.where((endpoint) => endpoint.ipAddress != ipAddress).toList());
    await _saveDevicesToStorage();
    notifyListeners();
  }

  Future<bool> sendTestPing({PairedDevice? device, String? targetIp}) async {
    final peer = device ?? (_pairedDevices.isEmpty ? null : _pairedDevices.first);
    if (peer == null) {
      _status = SyncStatus.error;
      _lastMessage = 'Test ping failed: no paired device available.';
      notifyListeners();
      return false;
    }

    if (targetIp != null) {
      _lastMessage = 'Pinging $targetIp…';
      notifyListeners();
      final result = await _service.sendTestPing(targetIp, peer.pairCode);
      _handleSyncEvent(result);
      return result.success;
    }

    final endpoints = [...peer.endpoints]
      ..sort((a, b) => (b.lastSyncedAt ?? b.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.lastSyncedAt ?? a.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0)));

    if (endpoints.isEmpty) {
      _status = SyncStatus.error;
      _lastMessage = 'Test ping failed: no endpoint available for ${peer.deviceName}.';
      notifyListeners();
      return false;
    }

    SyncResult? lastResult;
    for (final endpoint in endpoints) {
      _lastMessage = 'Pinging ${endpoint.ipAddress}…';
      notifyListeners();
      final result = await _service.sendTestPing(endpoint.ipAddress, peer.pairCode, targetPort: endpoint.port);
      lastResult = result;
      if (result.success) {
        _handleSyncEvent(result);
        return true;
      }
    }

    if (lastResult != null) {
      _handleSyncEvent(lastResult);
    }
    return false;
  }

  void triggerEventSync() {
    if (!_isAutoSyncEnabled || _pairedDevices.isEmpty) return;
    _eventDebounceTimer?.cancel();
    _eventDebounceTimer = Timer(const Duration(seconds: 3), () => unawaited(syncAllPairedDevices()));
  }

  Future<SyncResult> syncNow({Function()? onCompleted}) => syncAllPairedDevices(onCompleted: onCompleted);

  Future<SyncResult> syncAllPairedDevices({Function()? onCompleted}) async {
    if (_pairedDevices.isEmpty) return SyncResult(success: false, errorMessage: 'No paired devices available.');
    SyncResult? lastSuccess;
    String? lastError;
    for (final device in _pairedDevices) {
      final result = await syncDevice(device, onCompleted: onCompleted);
      if (result.success) {
        lastSuccess = result;
      } else {
        lastError = result.errorMessage;
      }
    }
    return lastSuccess ?? SyncResult(success: false, errorMessage: lastError ?? 'No paired devices were reachable.');
  }

  Future<SyncResult> syncDevice(PairedDevice device, {Function()? onCompleted}) async {
    if (device.endpoints.isEmpty) return SyncResult(success: false, errorMessage: 'No saved endpoint for ${device.deviceName}. Scan its QR code again.');
    _status = SyncStatus.syncing;
    notifyListeners();
    SyncResult? lastFailure;
    final endpoints = [...device.endpoints]
      ..sort((a, b) => (b.lastSyncedAt ?? b.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.lastSyncedAt ?? a.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    for (final endpoint in endpoints) {
      final result = await _service.syncBiDirectional(endpoint.ipAddress, device.pairCode, targetPort: endpoint.port);
      if (result.success) {
        final index = _pairedDevices.indexWhere((item) => item.deviceId == device.deviceId);
        if (index != -1) {
          _pairedDevices[index] = _pairedDevices[index].withEndpoint(endpoint.copyWith(lastSeenAt: DateTime.now(), lastSyncedAt: DateTime.now())).copyWith(
                lastSyncedAt: DateTime.now(),
                transportMode: result.transportUsed,
              );
          await _saveDevicesToStorage();
        }
        _status = SyncStatus.completed;
        _lastSyncedAt = DateTime.now();
        _lastMessage = 'Synced with ${device.deviceName}';
        if (onCompleted != null) onCompleted();
        notifyListeners();
        return result;
      }
      lastFailure = result;
    }
    _status = SyncStatus.error;
    _lastMessage = lastFailure?.errorMessage ?? 'Sync failed';
    notifyListeners();
    return lastFailure ?? SyncResult(success: false, errorMessage: _lastMessage);
  }

  Future<SyncResult> syncBiDirectional({String? targetIp, Function()? onCompleted}) {
    final device = targetIp == null
        ? (_pairedDevices.isEmpty ? null : _pairedDevices.first)
        : _pairedDevices.cast<PairedDevice?>().firstWhere(
              (item) => item?.endpoints.any((endpoint) => endpoint.ipAddress == targetIp) ?? false,
              orElse: () => null,
            );
    if (device == null) return Future.value(SyncResult(success: false, errorMessage: 'No paired device endpoint is available.'));
    return syncDevice(device, onCompleted: onCompleted);
  }

  Future<SyncResult> pullFromPrimary({String? targetIp, Function()? onCompleted}) async {
    final device = targetIp == null
        ? (_pairedDevices.isEmpty ? null : _pairedDevices.first)
        : _pairedDevices.cast<PairedDevice?>().firstWhere(
              (item) => item?.endpoints.any((endpoint) => endpoint.ipAddress == targetIp) ?? false,
              orElse: () => null,
            );
    final endpoint = device?.preferredEndpoint;
    if (device == null || endpoint == null) return SyncResult(success: false, errorMessage: 'Primary device endpoint unavailable.');
    final result = await _service.pullMasterFromPrimary(endpoint.ipAddress, device.pairCode, targetPort: endpoint.port);
    if (result.success && onCompleted != null) onCompleted();
    return result;
  }

  Future<void> _saveDevicesToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final unique = <String, PairedDevice>{for (final device in _pairedDevices) device.deviceId: device};
    _pairedDevices = unique.values.toList();
    await prefs.setString(_storageKey, json.encode(_pairedDevices.map((device) => device.toMap()).toList()));
  }
}