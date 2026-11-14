import 'dart:io';

class GpuService {
  static bool? _hasNvidiaRtx;
  static String? _gpuName;

  /// Check whether the Windows host has a supported NVIDIA GeForce RTX GPU
  static Future<bool> hasNvidiaRtx() async {
    if (_hasNvidiaRtx != null) return _hasNvidiaRtx!;

    if (!Platform.isWindows) {
      _hasNvidiaRtx = false;
      return false;
    }

    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r'(Get-CimInstance Win32_VideoController).Name',
      ]);
      final raw = result.stdout.toString();
      _gpuName = raw.trim();
      final upper = raw.toUpperCase();
      _hasNvidiaRtx = upper.contains('NVIDIA') && upper.contains('RTX');
    } catch (_) {
      _hasNvidiaRtx = false;
    }
    return _hasNvidiaRtx!;
  }

  static String? get gpuName => _gpuName;
}

