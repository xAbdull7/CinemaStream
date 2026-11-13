import 'dart:ffi';
import 'dart:io';

/// Native Windows Wakelock helper using Win32 SetThreadExecutionState.
/// Prevents the screen and system from going to sleep during video playback.
class WindowsWakelock {
  static DynamicLibrary? _kernel32;
  static int Function(int)? _setThreadExecutionState;
  static bool _initialized = false;

  static const int esContinuous = 0x80000000;
  static const int esSystemRequired = 0x00000001;
  static const int esDisplayRequired = 0x00000002;

  static void _init() {
    if (_initialized) return;
    _initialized = true;
    if (Platform.isWindows) {
      try {
        _kernel32 = DynamicLibrary.open('kernel32.dll');
        _setThreadExecutionState = _kernel32?.lookupFunction<Uint32 Function(Uint32), int Function(int)>(
          'SetThreadExecutionState',
        );
      } catch (_) {}
    }
  }

  /// Keep display and system awake.
  static void enable() {
    _init();
    try {
      _setThreadExecutionState?.call(esContinuous | esSystemRequired | esDisplayRequired);
    } catch (_) {}
  }

  /// Restore standard Windows power saving behavior.
  static void disable() {
    _init();
    try {
      _setThreadExecutionState?.call(esContinuous);
    } catch (_) {}
  }
}

