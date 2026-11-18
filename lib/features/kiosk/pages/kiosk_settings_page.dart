import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../clock/clock_providers.dart' show sharedPreferencesProvider;
import '../kiosk_controller.dart';
import '../kiosk_models.dart';
import '../kiosk_store.dart';
import 'window_editor_page.dart';

/// 日程与自动切换设置页（独立浅色主题，保证可读性）。
class KioskSettingsPage extends ConsumerStatefulWidget {
  const KioskSettingsPage({super.key});

  @override
  ConsumerState<KioskSettingsPage> createState() => _KioskSettingsPageState();
}

class _KioskSettingsPageState extends ConsumerState<KioskSettingsPage> {
  late final TextEditingController _urlController;
  late final TextEditingController _secretController;
  late int _interval;
  late KioskSchedule _schedule;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    _urlController = TextEditingController(text: KioskStore.serverUrl(prefs) ?? '');
    _secretController =
        TextEditingController(text: KioskStore.authSecret(prefs) ?? '');
    _interval = KioskStore.probeInterval(prefs);
    _schedule = KioskStore.schedule(prefs);
  }

  Future<void> _save() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await KioskStore.saveServerUrl(prefs, _urlController.text);
    await KioskStore.saveAuthSecret(prefs, _secretController.text);
    await KioskStore.saveProbeInterval(prefs, _interval);
    await KioskStore.saveSchedule(prefs, _schedule);
    await ref.read(kioskControllerProvider.notifier).refresh();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _editWindow({required bool weekend, int? index}) async {
    final day = weekend ? _schedule.weekend : _schedule.weekday;
    final initial = index == null ? null : day.windows[index];
    final result = await Navigator.of(context).push<WindowEditorResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => WindowEditorPage(initial: initial),
      ),
    );
    if (result == null) return;
    setState(() {
      if (result.deleted) {
        day.windows.removeAt(index!);
      } else if (index == null) {
        day.windows.add(result.window);
      } else {
        day.windows[index] = result.window;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.teal,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('日程与自动切换'),
          actions: [
            TextButton(
              onPressed: _save,
              child: const Text('保存', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(
              title: '相框服务器',
              children: [
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: '服务器地址',
                    hintText: '例如 192.168.1.10:8080',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _secretController,
                  decoration: const InputDecoration(
                    labelText: '认证密钥 authSecret（可选）',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            _card(
              title: '探测间隔',
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 30, label: Text('30秒')),
                    ButtonSegment(value: 60, label: Text('1分钟')),
                    ButtonSegment(value: 120, label: Text('2分钟')),
                    ButtonSegment(value: 300, label: Text('5分钟')),
                  ],
                  selected: {_interval},
                  onSelectionChanged: (s) => setState(() => _interval = s.first),
                ),
                const SizedBox(height: 6),
                const Text(
                  '仅在相框展示时间内按此间隔探测 NAS；在线切相框、离线回时钟。',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
            _scheduleCard(
              title: '工作日日程（周一至周五）',
              weekend: false,
            ),
            _scheduleCard(
              title: '休息日日程（周六、周日）',
              weekend: true,
            ),
            _card(
              title: '说明',
              children: [
                const Text(
                  '· 相框展示时间：此时间段内自动探测 NAS，在线切相框、离线回时钟；时间段外恒为时钟。\n'
                  '· App 的打开和关闭由手机端 Activator / 看门狗负责，本页不设会话时间。\n'
                  '· 结束时间小于开始时间视为跨午夜（如 18:00 ~ 次日 01:00）。\n'
                  '· 保存后立即生效。',
                  style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.6),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required String title, required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _scheduleCard({required String title, required bool weekend}) {
    final day = weekend ? _schedule.weekend : _schedule.weekday;
    final rows = <Widget>[];
    for (var i = 0; i < day.windows.length; i++) {
      final w = day.windows[i];
      rows.add(Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${w.start} ~ ${w.end}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('相框展示时间',
                      style: TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _editWindow(weekend: weekend, index: i),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: Colors.redAccent),
              onPressed: () => setState(() => day.windows.removeAt(i)),
            ),
          ],
        ),
      ));
    }
    rows.add(OutlinedButton.icon(
      icon: const Icon(Icons.add, size: 18),
      label: const Text('添加展示时间'),
      onPressed: () => _editWindow(weekend: weekend),
    ));
    return _card(title: title, children: rows);
  }
}
