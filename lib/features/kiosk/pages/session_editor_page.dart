import 'package:flutter/material.dart';

import '../kiosk_models.dart';

class SessionEditorResult {
  SessionEditorResult({required this.deleted, required this.session});

  final bool deleted;
  final KioskSession session;
}

/// 会话编辑页：开始/结束时间 + 探测窗口列表。
/// initial == null 表示新增；返回 SessionEditorResult（deleted = 删除该会话）。
class SessionEditorPage extends StatefulWidget {
  const SessionEditorPage({super.key, this.initial});

  final KioskSession? initial;

  @override
  State<SessionEditorPage> createState() => _SessionEditorPageState();
}

class _SessionEditorPageState extends State<SessionEditorPage> {
  late String _start;
  late String _end;
  late List<ProbeWindow> _windows;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _start = widget.initial?.start ?? '07:00';
    _end = widget.initial?.end ?? '08:30';
    _windows = [
      for (final w in widget.initial?.probeWindows ?? []) w,
    ];
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

  Future<void> _addWindow() async {
    final startPick = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (startPick == null || !mounted) return;
    final endPick = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: (startPick.hour + 1) % 24, minute: startPick.minute),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (endPick == null || !mounted) return;
    setState(() {
      _windows.add(ProbeWindow(
        start:
            '${startPick.hour.toString().padLeft(2, '0')}:${startPick.minute.toString().padLeft(2, '0')}',
        end:
            '${endPick.hour.toString().padLeft(2, '0')}:${endPick.minute.toString().padLeft(2, '0')}',
      ));
    });
  }

  void _save() {
    Navigator.of(context).pop(SessionEditorResult(
      deleted: false,
      session: KioskSession(
        start: _start,
        end: _end,
        probeWindows: [for (final w in _windows) w],
      ),
    ));
  }

  void _delete() {
    Navigator.of(context).pop(SessionEditorResult(
      deleted: true,
      session: widget.initial!,
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
          title: Text(_isEditing ? '编辑会话' : '添加会话'),
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
                      label: '会话开始', value: _start, onTap: () => _pickTime(isStart: true)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _timeTile(
                      label: '会话结束', value: _end, onTap: () => _pickTime(isStart: false)),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '结束时间小于开始时间视为跨午夜（如 18:00 ~ 次日 01:00）。',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('探测窗口',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('添加窗口'),
                  onPressed: _addWindow,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_windows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '（无探测窗口 = 该会话全程显示时钟）',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            for (var i = 0; i < _windows.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('探测 ${_windows[i]}',
                          style: const TextStyle(fontSize: 15)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: Colors.redAccent),
                      onPressed: () => setState(() => _windows.removeAt(i)),
                    ),
                  ],
                ),
              ),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
                onPressed: _delete,
                child: const Text('删除这个会话'),
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
