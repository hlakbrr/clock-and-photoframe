import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clock/pages/clock_page.dart';
import '../frame_page.dart';
import '../kiosk_controller.dart';

/// 时钟路由的顶层外壳：按日程引擎的决策在时钟页与相框页之间切换。
class KioskShell extends ConsumerWidget {
  const KioskShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // watch 即启动日程引擎（keepAlive）。
    final state = ref.watch(kioskControllerProvider);
    return state.mode == KioskMode.frame ? const FramePage() : const ClockPage();
  }
}
