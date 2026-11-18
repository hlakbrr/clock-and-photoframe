import 'package:http/http.dart' as http;

/// NAS 探测：对服务器根路径发 HEAD 请求，收到任何 HTTP 响应即视为在线
/// （对齐 ImmichFrame 安卓版 Helpers.isServerReachable 的行为）。
class ProbeEngine {
  static Future<bool> check({
    required String? url,
    String? secret,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (url == null || url.isEmpty) return false;
    final Uri uri;
    try {
      final lower = url.toLowerCase();
      final fixed = (!lower.startsWith('http://') && !lower.startsWith('https://'))
          ? 'http://$url'
          : url;
      uri = Uri.parse(fixed);
    } catch (_) {
      return false;
    }
    final client = http.Client();
    try {
      final request = http.Request('HEAD', uri);
      if (secret != null && secret.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $secret';
      }
      // 任何 HTTP 响应（含 4xx/5xx）都算在线；只有网络层失败才算离线。
      final response = await client.send(request).timeout(timeout);
      return response.statusCode > 0;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }
}
