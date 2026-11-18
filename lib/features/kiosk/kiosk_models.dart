/// 时钟 & 相框日程的数据模型。
/// 所有时间均为 "HH:mm" 字符串；end < start 表示跨午夜（如 18:00 ~ 01:00）。
class ProbeWindow {
  ProbeWindow({required this.start, required this.end});

  final String start;
  final String end;

  Map<String, dynamic> toJson() => {'start': start, 'end': end};

  factory ProbeWindow.fromJson(Map<String, dynamic> json) => ProbeWindow(
    start: json['start'] as String,
    end: json['end'] as String,
  );

  @override
  String toString() => '$start ~ $end';
}

/// 一个"会话"：App 在此时间段内保持前台显示时钟（或相框），
/// 会话结束自动返回桌面。探测窗口嵌套在会话之内。
class KioskSession {
  KioskSession({
    required this.start,
    required this.end,
    List<ProbeWindow>? probeWindows,
  }) : probeWindows = probeWindows ?? [];

  final String start;
  final String end;
  final List<ProbeWindow> probeWindows;

  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
    'probeWindows': [for (final w in probeWindows) w.toJson()],
  };

  factory KioskSession.fromJson(Map<String, dynamic> json) => KioskSession(
    start: json['start'] as String,
    end: json['end'] as String,
    probeWindows: [
      for (final w in (json['probeWindows'] as List?) ?? [])
        ProbeWindow.fromJson(Map<String, dynamic>.from(w as Map)),
    ],
  );
}

/// 单个日型（工作日 / 休息日）的会话列表。
class DaySchedule {
  DaySchedule({required this.sessions});

  final List<KioskSession> sessions;

  Map<String, dynamic> toJson() => {
    'sessions': [for (final s in sessions) s.toJson()],
  };

  factory DaySchedule.fromJson(Map<String, dynamic> json) => DaySchedule(
    sessions: [
      for (final s in (json['sessions'] as List?) ?? [])
        KioskSession.fromJson(Map<String, dynamic>.from(s as Map)),
    ],
  );
}

/// 完整日程：工作日（周一至周五）+ 休息日（周六、周日）。
class KioskSchedule {
  KioskSchedule({required this.weekday, required this.weekend});

  final DaySchedule weekday;
  final DaySchedule weekend;

  Map<String, dynamic> toJson() => {
    'weekday': weekday.toJson(),
    'weekend': weekend.toJson(),
  };

  factory KioskSchedule.fromJson(Map<String, dynamic> json) => KioskSchedule(
    weekday: DaySchedule.fromJson(
      Map<String, dynamic>.from(json['weekday'] as Map),
    ),
    weekend: DaySchedule.fromJson(
      Map<String, dynamic>.from(json['weekend'] as Map),
    ),
  );

  /// 用户需求的默认日程。
  factory KioskSchedule.defaults() => KioskSchedule(
    weekday: DaySchedule(sessions: [
      KioskSession(start: '07:00', end: '08:30'),
      KioskSession(
        start: '12:00',
        end: '15:30',
        probeWindows: [ProbeWindow(start: '12:30', end: '14:00')],
      ),
      KioskSession(
        start: '18:00',
        end: '01:00',
        probeWindows: [ProbeWindow(start: '18:30', end: '23:30')],
      ),
    ]),
    weekend: DaySchedule(sessions: [
      KioskSession(
        start: '08:00',
        end: '01:00',
        probeWindows: [
          ProbeWindow(start: '09:00', end: '13:00'),
          ProbeWindow(start: '16:00', end: '23:30'),
        ],
      ),
    ]),
  );
}

/// "HH:mm" -> 当日分钟数；非法输入返回 null。
int? parseHm(String s) {
  final parts = s.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  if (h < 0 || h > 23 || m < 0 || m > 59) return null;
  return h * 60 + m;
}

/// 判断 curMin（当日分钟数）是否落在 [start, end) 内。
/// start == end 视为全天；end < start 自动按跨午夜处理。
bool hmInRange(String start, String end, int curMin) {
  final s = parseHm(start);
  final e = parseHm(end);
  if (s == null || e == null) return false;
  if (s == e) return true;
  final span = (e - s) % 1440;
  final delta = (curMin - s) % 1440;
  return delta < span;
}
