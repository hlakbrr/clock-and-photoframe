import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../clock/clock_providers.dart' show sharedPreferencesProvider;
import 'kiosk_store.dart';

/// 相框模式：全屏 WebView 加载 ImmichFrame 服务端网页。
/// 右上角提供半透明设置入口（点按进入日程设置页）。
class FramePage extends ConsumerStatefulWidget {
  const FramePage({super.key});

  @override
  ConsumerState<FramePage> createState() => _FramePageState();
}

class _FramePageState extends ConsumerState<FramePage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    final url = KioskStore.frameUrl(prefs);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF121212))
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (_) => _retryLater(),
        ),
      );
    if (url != null) {
      _controller.loadRequest(Uri.parse(url));
    }
  }

  void _retryLater() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      final url = KioskStore.frameUrl(ref.read(sharedPreferencesProvider));
      if (url != null) _controller.loadRequest(Uri.parse(url));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          Positioned(
            top: 12,
            right: 12,
            child: Opacity(
              opacity: 0.25,
              child: IconButton(
                icon: const Icon(Icons.settings, size: 26, color: Colors.white),
                onPressed: () => context.push('/kiosk-settings'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
