import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'kiosk_models.dart';

/// kiosk 模块的持久化存储。
class KioskStore {
  static const _scheduleKey = 'kiosk_schedule';
  static const _urlKey = 'kiosk_server_url';
  static const _secretKey = 'kiosk_auth_secret';
  static const _intervalKey = 'kiosk_probe_interval';

  static const defaultProbeInterval = 60; // 秒

  static KioskSchedule schedule(SharedPreferences prefs) {
    final raw = prefs.getString(_scheduleKey);
    if (raw == null) return KioskSchedule.defaults();
    try {
      return KioskSchedule.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return KioskSchedule.defaults();
    }
  }

  static Future<void> saveSchedule(
    SharedPreferences prefs,
    KioskSchedule schedule,
  ) {
    return prefs.setString(_scheduleKey, jsonEncode(schedule.toJson()));
  }

  static String? serverUrl(SharedPreferences prefs) {
    final t = (prefs.getString(_urlKey) ?? '').trim();
    return t.isEmpty ? null : t;
  }

  static String? authSecret(SharedPreferences prefs) {
    final t = (prefs.getString(_secretKey) ?? '').trim();
    return t.isEmpty ? null : t;
  }

  static Future<void> saveServerUrl(SharedPreferences prefs, String url) {
    return prefs.setString(_urlKey, url.trim());
  }

  static Future<void> saveAuthSecret(SharedPreferences prefs, String secret) {
    return prefs.setString(_secretKey, secret.trim());
  }

  static int probeInterval(SharedPreferences prefs) {
    final v = prefs.getInt(_intervalKey);
    if (v == null) return defaultProbeInterval;
    return v < 15 ? 15 : v;
  }

  static Future<void> saveProbeInterval(SharedPreferences prefs, int seconds) {
    return prefs.setInt(_intervalKey, seconds < 15 ? 15 : seconds);
  }

  /// 相框页地址：服务器地址（缺协议自动补 http://）+ 可选 ?authsecret=
  static String? frameUrl(SharedPreferences prefs) {
    var base = serverUrl(prefs);
    if (base == null) return null;
    final lower = base.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      base = 'http://$base';
    }
    final secret = authSecret(prefs);
    if (secret != null && secret.isNotEmpty) {
      final uri = Uri.parse(base);
      final query = Map<String, String>.from(uri.queryParameters);
      query['authsecret'] = secret;
      return uri.replace(queryParameters: query).toString();
    }
    return base;
  }
}
