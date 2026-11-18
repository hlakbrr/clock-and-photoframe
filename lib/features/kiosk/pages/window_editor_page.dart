import 'package:flutter/material.dart';

import '../kiosk_models.dart';

class WindowEditorResult {
  WindowEditorResult({required this.deleted, required this.window});

  final bool deleted;
  final ProbeWindow window;
}

/// 相框展示时间编辑页：开始 / 结束时间分开设置。
/// initial == null 表示新增；返回 WindowEditorResult（deleted = 删除该条）。
class WindowEditorPage extends StatefulWidget {
  const WindowEditorPage({super.key, this.initial});

  final ProbeWindow? initial;

  @override
  State<WindowEditorPage> createState() => _WindowEditorPageState();
}

class _WindowEditorPageState extends State<WindowEditorPage> {
  late String _start;
  late String _end;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _start = widget.initial?.start ?? '12:30';
    _end = widget.initial?.end ?? '14:00';
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = _timeOfDay(isStart ? _start : _end);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      final text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      if (isStart) {
        _start = text;
      } else {
        _end = text;
      }
    });
  }

  TimeOfDay _timeOfDay(String s) {
    final m = parseHm(s) ?? 0;
    return TimeOfDay(hour: m ~/ 60, minute: m % 60);
  }

  void _save() {
    Navigator.of(context).pop(WindowEditorResult(
      deleted: false,
      window: ProbeWindow(start: _start, end: _end),
    ));
  }

  void _delete() {
    Navigator.of(context).pop(WindowEditorResult(
      deleted: true,
      window: widget.initial!,
    ));
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
          title: Text(_isEditing ? '编辑展示时间' : '添加展示时间'),
          actions: [
            TextButton(
              onPressed: _save,
              child: const Text('保存',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _timeTile(
                      label: '开始时间', value: _start, onTap: () => _pickTime(isStart: true)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _timeTile(
                      label: '结束时间', value: _end, onTap: () => _pickTime(isStart: false)),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '展示时间内按设定间隔探测 NAS，在线切相框、离线回时钟。'
                '结束时间小于开始时间视为跨午夜（如 18:00 ~ 次日 01:00）。',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 24),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
                onPressed: _delete,
                child: const Text('删除这条展示时间'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _timeTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
