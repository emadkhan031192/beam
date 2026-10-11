import 'dart:async';

import 'package:flutter/services.dart';

/// Bridge to the native Kotlin torch layer.
///
/// MethodChannel `com.afzal.beam/torch`:
///   isSupported, on(level, external), off, setLevel, startStrobe(hz),
///   startSos, stop, getState, getApkSizeMb, consumeShortcutLightOn,
///   setAutoOffMinutes, requestNotificationPermission, openBatterySettings,
///   setShakeEnabled.
///
/// EventChannel `com.afzal.beam/torch_events` streams maps:
///   {on, mode, level, brightnessSupported, maxStrength, conflict}
/// EventChannel `com.afzal.beam/battery` streams the battery percent as int.
class TorchApi {
  TorchApi._();

  static const MethodChannel _method = MethodChannel('com.afzal.beam/torch');
  static const EventChannel _events =
      EventChannel('com.afzal.beam/torch_events');
  static const EventChannel _battery = EventChannel('com.afzal.beam/battery');

  static Stream<Map<dynamic, dynamic>>? _eventStream;
  static Stream<int>? _batteryStream;

  /// Warms the channel binding. Called before the first frame; does no I/O.
  static Future<void> init() async {
    _eventStream ??=
        _events.receiveBroadcastStream().map((e) => e as Map<dynamic, dynamic>);
    _batteryStream ??= _battery
        .receiveBroadcastStream()
        .map((e) => (e as num).toInt())
        .distinct();
  }

  static Stream<Map<dynamic, dynamic>> get events {
    final s = _eventStream;
    assert(s != null, 'Call TorchApi.init() before reading events');
    return s!;
  }

  static Stream<int> get battery {
    final s = _batteryStream;
    assert(s != null, 'Call TorchApi.init() before reading battery');
    return s!;
  }

  static Future<bool> isSupported() async =>
      (await _method.invokeMethod<bool>('isSupported')) ?? false;

  static Future<void> turnOn(int level, {bool external = false}) =>
      _method.invokeMethod('on', {'level': level, 'external': external});

  static Future<void> turnOff() => _method.invokeMethod('off');

  static Future<void> setLevel(int level) =>
      _method.invokeMethod('setLevel', {'level': level});

  static Future<void> startStrobe(int hz) =>
      _method.invokeMethod('startStrobe', {'hz': hz});

  static Future<void> startSos() => _method.invokeMethod('startSos');

  /// Stops any strobe/SOS pattern and turns the torch off.
  static Future<void> stopAll() => _method.invokeMethod('stop');

  static Future<Map<dynamic, dynamic>> getState() async =>
      (await _method.invokeMapMethod('getState')) ?? <dynamic, dynamic>{};

  /// APK size in megabytes (from packageCodePath), for the settings footer.
  static Future<double> getApkSizeMb() async =>
      (await _method.invokeMethod<double>('getApkSizeMb')) ?? 0;

  /// Returns true once if the app was launched from the "Light on" shortcut.
  static Future<bool> consumeShortcutLightOn() async =>
      (await _method.invokeMethod<bool>('consumeShortcutLightOn')) ?? false;

  static Future<void> setAutoOffMinutes(int minutes) =>
      _method.invokeMethod('setAutoOffMinutes', {'minutes': minutes});

  /// Asks for POST_NOTIFICATIONS on Android 13+. Returns granted state.
  static Future<bool> requestNotificationPermission() async =>
      (await _method.invokeMethod<bool>('requestNotificationPermission')) ??
      false;

  static Future<void> openBatterySettings() =>
      _method.invokeMethod('openBatterySettings');

  static Future<void> setShakeEnabled(bool enabled) =>
      _method.invokeMethod('setShakeEnabled', {'enabled': enabled});
}
