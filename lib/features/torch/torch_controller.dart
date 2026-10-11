import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/channels.dart';
import '../../core/models.dart';

/// UI-facing snapshot of the torch.
class TorchUiState {
  const TorchUiState({
    required this.on,
    required this.mode,
    required this.level,
    required this.brightnessSupported,
    required this.maxStrength,
    this.notice,
  });

  factory TorchUiState.initial() => const TorchUiState(
        on: false,
        mode: TorchMode.steady,
        level: 5,
        brightnessSupported: true,
        maxStrength: 1,
      );

  final bool on;
  final TorchMode mode;
  final int level;
  final bool brightnessSupported;
  final int maxStrength;
  final String? notice;

  TorchUiState copyWith({
    bool? on,
    TorchMode? mode,
    int? level,
    bool? brightnessSupported,
    int? maxStrength,
    String? notice,
    bool clearNotice = false,
  }) =>
      TorchUiState(
        on: on ?? this.on,
        mode: mode ?? this.mode,
        level: level ?? this.level,
        brightnessSupported: brightnessSupported ?? this.brightnessSupported,
        maxStrength: maxStrength ?? this.maxStrength,
        notice: clearNotice ? null : (notice ?? this.notice),
      );
}

final torchControllerProvider =
    StateNotifierProvider<TorchController, TorchUiState>(
  (ref) => TorchController(),
);

/// Bridges the native torch event stream to the UI.
/// Toggle is optimistic: the UI updates first, the native callback confirms.
class TorchController extends StateNotifier<TorchUiState> {
  TorchController() : super(TorchUiState.initial()) {
    _eventsSub = TorchApi.events.listen(
      _onNativeEvent,
      onError: (_) {},
    );
    _syncFromNative();
  }

  StreamSubscription<Map<dynamic, dynamic>>? _eventsSub;
  Timer? _noticeTimer;
  int _lastLevel = 5;

  Future<void> _syncFromNative() async {
    try {
      final map = await TorchApi.getState();
      if (map.isNotEmpty) _applyMap(map);
    } catch (_) {
      // Native not ready yet; the event stream will catch up.
    }
  }

  void _onNativeEvent(Map<dynamic, dynamic> map) => _applyMap(map);

  void _applyMap(Map<dynamic, dynamic> map) {
    final s = TorchState.fromMap(map);
    if (s.on) _lastLevel = s.level;
    state = state.copyWith(
      on: s.on,
      mode: s.mode,
      level: s.level,
      brightnessSupported: s.brightnessSupported,
      maxStrength: s.maxStrength,
      clearNotice: s.conflict ? false : state.notice == null,
      notice: s.conflict ? 'Camera in use by another app' : state.notice,
    );
  }

  /// One tap lights the torch immediately: UI first, native confirms.
  Future<void> toggle() async {
    if (state.on) {
      state = state.copyWith(on: false, mode: TorchMode.steady);
      await TorchApi.turnOff();
    } else {
      final level = _lastLevel;
      state = state.copyWith(on: true, mode: TorchMode.steady, level: level);
      await TorchApi.turnOn(level);
    }
  }

  Future<void> setLevel(int level) async {
    final l = level.clamp(1, 5);
    _lastLevel = l;
    state = state.copyWith(level: l);
    if (state.on && state.mode == TorchMode.steady) {
      await TorchApi.setLevel(l);
    }
  }

  Future<void> stopAll() async {
    state = state.copyWith(on: false, mode: TorchMode.steady);
    await TorchApi.stopAll();
  }

  void showNotice(String text,
      {Duration duration = const Duration(seconds: 5)}) {
    _noticeTimer?.cancel();
    state = state.copyWith(notice: text);
    _noticeTimer = Timer(duration, () {
      state = state.copyWith(clearNotice: true);
    });
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _noticeTimer?.cancel();
    super.dispose();
  }
}
