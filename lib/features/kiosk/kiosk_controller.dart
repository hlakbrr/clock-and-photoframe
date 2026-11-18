import 'dart:async';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../clock/clock_providers.dart' show sharedPreferencesProvider;
import 'kiosk_models.dart';
import 'kiosk_store.dart';
import 'probe_engine.dart';

part 'kiosk_controller.g.dart';

enum KioskMode { clock, frame }

class KioskState {
  const KioskState({required this.mode, required this.sessionActive});

  final KioskMode mode;
  final bool sessionActive;
}

/// 日程引擎：
/// - 会话内：默认显示时钟；落在探测窗口内时按设定间隔探测 NAS，
///   在线切相框、离线回时钟；会话结束自动返回桌面（suspend）。
/// - 会话外：保持时钟（等待外部看门狗在会话开始时拉起）。
/// - 未配置服务器地址：永远时钟。
@Riverpod(keepAlive: true)
class KioskController extends _$KioskController {
  static const _channel = MethodChannel('kiosk/native');

  Timer? _timer;
  DateTime? _lastProbeAt;
  bool? _lastOnline;
  bool _ticking = false;

  @override
  KioskState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    _listenDeepLink();
    _startTimer();
    return const KioskState(mode: KioskMode.clock, sessionActive: false);
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  // MARK: 调度

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      tick();
    });
    tick();
  }

  Future<void> tick() async {
    if (_ticking) return;
    _ticking = true;
    try {
      await _tickInner();
    } finally {
      _ticking = false;
    }
  }

  Future<void> _tickInner() async {
    final now = DateTime.now();
    final schedule = KioskStore.schedule(_prefs);
    final isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    final day = isWeekend ? schedule.weekend : schedule.weekday;
    final cur = now.hour * 60 + now.minute;
    final session = _activeSession(day.sessions, cur);
    final wasActive = state.sessionActive;

    if (session == null) {
      _update(mode: KioskMode.clock, sessionActive: false);
      if (wasActive) {
        await _suspendToHome(); // 会话结束 → 返回桌面（由系统自动锁屏）
      }
      return;
    }

    // 会话内：落在探测窗口内才探测，窗口外恒为时钟。
    final inWindow =
        session.probeWindows.any((w) => hmInRange(w.start, w.end, cur));
    var mode = KioskMode.clock;
    if (inWindow) {
      final interval = KioskStore.probeInterval(_prefs);
      final due = _lastProbeAt == null ||
          now.difference(_lastProbeAt!).inSeconds >= interval;
      if (due) {
        _lastOnline = await ProbeEngine.check(
          url: KioskStore.serverUrl(_prefs),
          secret: KioskStore.authSecret(_prefs),
        );
        _lastProbeAt = now;
      }
      if (_lastOnline == true) mode = KioskMode.frame;
    } else {
      _lastProbeAt = null;
      _lastOnline = null;
    }
    _update(mode: mode, sessionActive: true);
  }

  void _update({required KioskMode mode, required bool sessionActive}) {
    if (mode == state.mode && sessionActive == state.sessionActive) return;
    state = KioskState(mode: mode, sessionActive: sessionActive);
  }

  KioskSession? _activeSession(List<KioskSession> sessions, int cur) {
    for (final s in sessions) {
      if (hmInRange(s.start, s.end, cur)) return s;
    }
    return null;
  }

  // MARK: 原生通道

  Future<void> _suspendToHome() async {
    try {
      await _channel.invokeMethod<void>('suspend');
    } catch (_) {
      // 平台通道失败时保持现状，下个 tick 再试。
    }
  }

  void _listenDeepLink() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'deepLink') {
        // 看门狗/自动化通过 clockandphotoframe://open 拉起：立即探测刷新。
        _lastProbeAt = null;
        await tick();
      }
      return null;
    });
  }

  /// 设置保存后调用：清缓存并立即重算。
  Future<void> refresh() async {
    _lastProbeAt = null;
    _lastOnline = null;
    await tick();
  }
}
