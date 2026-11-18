import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../clock/clock_providers.dart' show sharedPreferencesProvider;
import 'kiosk_models.dart';
import 'kiosk_store.dart';
import 'probe_engine.dart';

part 'kiosk_controller.g.dart';

enum KioskMode { clock, frame }

class KioskState {
  const KioskState({required this.mode});

  final KioskMode mode;
}

/// 日程引擎（App 的打开与关闭由手机端 Activator / 看门狗负责）：
/// - 落在相框展示时间内：按设定间隔探测 NAS，在线切相框、离线回时钟。
/// - 展示时间外：恒为时钟。
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
    return const KioskState(mode: KioskMode.clock);
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

    final inWindow = day.windows.any((w) => hmInRange(w.start, w.end, cur));
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
    _update(mode: mode);
  }

  void _update({required KioskMode mode}) {
    if (mode == state.mode) return;
    state = KioskState(mode: mode);
  }

  // MARK: 原生通道

  void _listenDeepLink() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'deepLink') {
        // 看门狗/Activator 通过 clockandphotoframe://open 拉起：立即探测刷新。
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
