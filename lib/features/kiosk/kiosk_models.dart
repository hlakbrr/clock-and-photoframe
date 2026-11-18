/// 时钟 & 相框日程的数据模型。
/// 所有时间均为 "HH:mm" 字符串；end < start 表示跨午夜（如 18:00 ~ 01:00）。

/// 相框展示时间：此时间段内按设定间隔探测 NAS，
/// 在线显示相框、离线显示时钟；时间段外恒为时钟。
/// App 的打开与关闭由手机端（Activator / 看门狗）负责。
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

/// 单个日型（工作日 / 休息日）的相框展示时间列表。
class DaySchedule {
  DaySchedule({List<ProbeWindow>? windows}) : windows = windows ?? [];

  final List<ProbeWindow> windows;

  Map<String, dynamic> toJson() => {
    'windows': [for (final w in windows) w.toJson()],
  };

  factory DaySchedule.fromJson(Map<String, dynamic> json) {
    // 新格式：windows。
    final list = json['windows'] as List?;
    if (list != null) {
      return DaySchedule(windows: [
        for (final w in list)
          ProbeWindow.fromJson(Map<String, dynamic>.from(w as Map)),
      ]);
    }
    // 旧格式兼容：sessions 内嵌的 probeWindows 平铺继承。
    final legacySessions = json['sessions'] as List?;
    return DaySchedule(windows: [
      for (final s in legacySessions ?? const [])
        for (final w
            in (Map<String, dynamic>.from(s as Map)['probeWindows']
                    as List?) ??
                const [])
          ProbeWindow.fromJson(Map<String, dynamic>.from(w as Map)),
    ]);
  }
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

  /// 默认日程（对应用户常用作息示例）。
  factory KioskSchedule.defaults() => KioskSchedule(
    weekday: DaySchedule(windows: [
      ProbeWindow(start: '12:30', end: '14:00'),
      ProbeWindow(start: '18:30', end: '23:30'),
    ]),
    weekend: DaySchedule(windows: [
      ProbeWindow(start: '09:00', end: '13:00'),
      ProbeWindow(start: '16:00', end: '23:30'),
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
