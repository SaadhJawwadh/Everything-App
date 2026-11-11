import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

typedef _Sha256Native = Int32 Function(Pointer<Uint8>, IntPtr, Pointer<Uint8>);
typedef _Sha256Dart = int Function(Pointer<Uint8>, int, Pointer<Uint8>);

typedef _Pbkdf2Native = Int32 Function(Pointer<Uint8>, IntPtr, Pointer<Uint8>, IntPtr, Uint32, Pointer<Uint8>);
typedef _Pbkdf2Dart = int Function(Pointer<Uint8>, int, Pointer<Uint8>, int, int, Pointer<Uint8>);

typedef _FastDigitScanNative = Int32 Function(Pointer<Uint8>, IntPtr);
typedef _FastDigitScanDart = int Function(Pointer<Uint8>, int);

typedef _CMallocNative = Pointer<Uint8> Function(IntPtr);
typedef _CMallocDart = Pointer<Uint8> Function(int);

typedef _CFreeNative = Void Function(Pointer<Void>);
typedef _CFreeDart = void Function(Pointer<Void>);

/// Bridge to native Rust / C shared library (`libeverything_core`) with seamless
/// automatic fallback to pure Dart implementations.
class NativeCoreBridge {
  static final NativeCoreBridge instance = NativeCoreBridge._internal();
  NativeCoreBridge._internal() {
    _initLibrary();
  }
  factory NativeCoreBridge() => instance;

  DynamicLibrary? _dylib;
  bool _isNativeLoaded = false;
  bool get isNativeLoaded => _isNativeLoaded;

  _Sha256Dart? _nativeSha256;
  _Pbkdf2Dart? _nativePbkdf2;
  _FastDigitScanDart? _nativeFastDigitScan;

  _CMallocDart? _cMalloc;
  _CFreeDart? _cFree;

  void _initLibrary() {
    try {
      final processLib = Platform.isWindows
          ? DynamicLibrary.open('msvcrt.dll')
          : DynamicLibrary.process();
      _cMalloc = processLib
          .lookup<NativeFunction<_CMallocNative>>('malloc')
          .asFunction<_CMallocDart>();
      _cFree = processLib
          .lookup<NativeFunction<_CFreeNative>>('free')
          .asFunction<_CFreeDart>();
    } catch (e) {
      debugPrint('[NativeCoreBridge] Could not bind system malloc/free: $e');
    }

    try {
      if (Platform.isAndroid) {
        _dylib = DynamicLibrary.open('libeverything_core.so');
      } else if (Platform.isMacOS || Platform.isLinux) {
        final libName = Platform.isMacOS ? 'libeverything_core.dylib' : 'libeverything_core.so';
        final localBuildPath = '${Directory.current.path}/build/native/$libName';
        if (File(localBuildPath).existsSync()) {
          _dylib = DynamicLibrary.open(localBuildPath);
        } else {
          try {
            _dylib = DynamicLibrary.process();
          } catch (_) {}
        }
      } else if (Platform.isIOS) {
        _dylib = DynamicLibrary.process();
      }

      if (_dylib != null && _cMalloc != null && _cFree != null) {
        try {
          _nativeSha256 = _dylib!
              .lookup<NativeFunction<_Sha256Native>>('everything_sha256')
              .asFunction<_Sha256Dart>();
        } catch (_) {}

        try {
          _nativePbkdf2 = _dylib!
              .lookup<NativeFunction<_Pbkdf2Native>>('everything_pbkdf2_hmac_sha256')
              .asFunction<_Pbkdf2Dart>();
        } catch (_) {}

        try {
          _nativeFastDigitScan = _dylib!
              .lookup<NativeFunction<_FastDigitScanNative>>('everything_fast_digit_scan')
              .asFunction<_FastDigitScanDart>();
        } catch (_) {}

        _isNativeLoaded = _nativeSha256 != null || _nativePbkdf2 != null || _nativeFastDigitScan != null;
      }
    } catch (e) {
      debugPrint('[NativeCoreBridge] Native library load skipped (using Dart engine): $e');
      _isNativeLoaded = false;
    }
  }

  /// High-performance SHA-256 calculation (uses native Apple/Rust instructions when available).
  Uint8List sha256Digest(Uint8List data) {
    if (_isNativeLoaded && _nativeSha256 != null && _cMalloc != null && _cFree != null) {
      final inPtr = _cMalloc!(data.length);
      final outPtr = _cMalloc!(32);
      try {
        final inView = inPtr.asTypedList(data.length);
        inView.setAll(0, data);
        final status = _nativeSha256!(inPtr, data.length, outPtr);
        if (status == 0) {
          final outView = outPtr.asTypedList(32);
          return Uint8List.fromList(outView);
        }
      } catch (e) {
        debugPrint('[NativeCoreBridge] Native sha256 failed ($e), falling back to Dart');
      } finally {
        _cFree!(inPtr.cast<Void>());
        _cFree!(outPtr.cast<Void>());
      }
    }
    // Pure-Dart fallback
    return Uint8List.fromList(sha256.convert(data).bytes);
  }

  /// Hardware-accelerated PBKDF2-HMAC-SHA256 1-block 32-byte key derivation.
  Uint8List derivePbkdf2Sha256({
    required Uint8List secret,
    required Uint8List salt,
    required int iterations,
  }) {
    if (_isNativeLoaded && _nativePbkdf2 != null && _cMalloc != null && _cFree != null) {
      final passPtr = _cMalloc!(secret.length);
      final saltPtr = _cMalloc!(salt.length);
      final outPtr = _cMalloc!(32);
      try {
        passPtr.asTypedList(secret.length).setAll(0, secret);
        saltPtr.asTypedList(salt.length).setAll(0, salt);
        final status = _nativePbkdf2!(passPtr, secret.length, saltPtr, salt.length, iterations, outPtr);
        if (status == 0) {
          return Uint8List.fromList(outPtr.asTypedList(32));
        }
      } catch (e) {
        debugPrint('[NativeCoreBridge] Native PBKDF2 failed ($e), falling back to Dart');
      } finally {
        _cFree!(passPtr.cast<Void>());
        _cFree!(saltPtr.cast<Void>());
        _cFree!(outPtr.cast<Void>());
      }
    }

    // Pure-Dart fallback
    final hmac = Hmac(sha256, secret);
    final saltPlusBlockIndex = Uint8List(salt.length + 4)
      ..setRange(0, salt.length, salt)
      ..setRange(salt.length, salt.length + 4, [0, 0, 0, 1]);

    List<int> u = hmac.convert(saltPlusBlockIndex).bytes;
    final t = Uint8List.fromList(u);

    for (int i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (int j = 0; j < 32; j++) {
        t[j] ^= u[j];
      }
    }
    return t;
  }

  /// Single-pass pre-filter returning true if the UTF-8 payload contains any numerical digit.
  bool smsFastDigitScan(Uint8List utf8Bytes) {
    if (utf8Bytes.isEmpty) return false;
    if (_isNativeLoaded && _nativeFastDigitScan != null && _cMalloc != null && _cFree != null) {
      final inPtr = _cMalloc!(utf8Bytes.length);
      try {
        inPtr.asTypedList(utf8Bytes.length).setAll(0, utf8Bytes);
        final result = _nativeFastDigitScan!(inPtr, utf8Bytes.length);
        return result == 1;
      } catch (_) {
      } finally {
        _cFree!(inPtr.cast<Void>());
      }
    }
    // Pure-Dart fallback
    for (int i = 0; i < utf8Bytes.length; i++) {
      final b = utf8Bytes[i];
      if (b >= 0x30 && b <= 0x39) return true;
    }
    return false;
  }

  /// Convenience string digit scan prefilter.
  bool containsDigits(String text) {
    if (text.isEmpty) return false;
    return smsFastDigitScan(Uint8List.fromList(utf8.encode(text)));
  }
}
