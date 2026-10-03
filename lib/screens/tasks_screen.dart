import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/customer.dart';
import '../services/database_service.dart';
import '../services/ios_native_service.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<Map<String, Object?>> tasks = [];
  List<Customer> customers = [];
  bool loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final r = await Future.wait([DatabaseService.instance.getTasks(), DatabaseService.instance.getCustomers()]);
    if (!mounted) return;
    setState(() { tasks = r[0] as List<Map<String, Object?>>; customers = r[1] as List<Customer>; loading = false; });
  }

  String customerName(Object? id) {
    for (final c in customers) { if (c.id == id) return c.name; }
    return '';
  }

  Future<void> _openTask([Map<String, Object?>? task]) async {
    final editing = task != null;
    final title = TextEditingController(text: task?['title'] as String? ?? '');
    final note = TextEditingController(text: task?['note'] as String? ?? '');
    int? customerId = task?['customer_id'] as int?;
    String priority = task?['priority'] as String? ?? 'Bình thường';
    bool completed = (task?['completed'] as int? ?? 0) == 1;
    bool reminderEnabled = (task?['reminder_enabled'] as int? ?? 1) == 1;
    int reminderMinutes = task?['reminder_minutes'] as int? ?? 30;
    DateTime due = DateTime.tryParse(task?['due_date'] as String? ?? '') ?? DateTime.now().add(const Duration(days: 1));

    final saved = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(builder: (context, setSheet) {
        Future<void> pickDate() async {
          final d = await showDatePicker(context: context, initialDate: due, firstDate: DateTime(2024), lastDate: DateTime.now().add(const Duration(days: 3650)));
          if (d != null) setSheet(() => due = DateTime(d.year, d.month, d.day, due.hour, due.minute));
        }
        Future<void> pickTime() async {
          final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(due));
          if (t != null) setSheet(() => due = DateTime(due.year, due.month, due.day, t.hour, t.minute));
        }
        return SafeArea(child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 18 + MediaQuery.viewInsetsOf(context).bottom),
          child: SizedBox(height: MediaQuery.sizeOf(context).height * .82, child: Column(children: [
            Row(children: [
              Expanded(child: Text(editing ? 'Chỉnh sửa công việc' : 'Thêm công việc', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
              IconButton(onPressed: () => Navigator.pop(sheetContext, false), icon: const Icon(Icons.close)),
            ]),
            Expanded(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(controller: title, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Tên công việc *', border: OutlineInputBorder())),
              const SizedBox(height: 14),
              DropdownButtonFormField<int?>(initialValue: customerId, decoration: const InputDecoration(labelText: 'Khách hàng', border: OutlineInputBorder()), items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Không gắn khách')),
                ...customers.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
              ], onChanged: (v) => setSheet(() => customerId = v)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: ListTile(shape: RoundedRectangleBorder(side: BorderSide(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(12)), leading: const Icon(Icons.calendar_month_outlined), title: const Text('Ngày thực hiện'), subtitle: Text(DateFormat('dd/MM/yyyy').format(due)), onTap: pickDate)),
                const SizedBox(width: 8),
                Expanded(child: ListTile(shape: RoundedRectangleBorder(side: BorderSide(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(12)), leading: const Icon(Icons.schedule), title: const Text('Giờ'), subtitle: Text(DateFormat('HH:mm').format(due)), onTap: pickTime)),
              ]),
              const SizedBox(height: 16),
              const Text('Độ ưu tiên', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SegmentedButton<String>(segments: const [
                ButtonSegment(value: 'Thấp', label: Text('Thấp')),
                ButtonSegment(value: 'Bình thường', label: Text('Bình thường')),
                ButtonSegment(value: 'Cao', label: Text('Cao')),
              ], selected: {priority == 'Khẩn cấp' ? 'Cao' : priority}, onSelectionChanged: (v) => setSheet(() => priority = v.first)),
              const SizedBox(height: 16),
              DropdownButtonFormField<bool>(initialValue: completed, decoration: const InputDecoration(labelText: 'Trạng thái', border: OutlineInputBorder()), items: const [
                DropdownMenuItem(value: false, child: Text('🔵  Chưa làm')),
                DropdownMenuItem(value: true, child: Text('🟢  Hoàn thành')),
              ], onChanged: (v) => setSheet(() => completed = v ?? completed)),
              const SizedBox(height: 10),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Nhắc nhở', style: TextStyle(fontWeight: FontWeight.w700)), value: reminderEnabled, onChanged: (v) => setSheet(() => reminderEnabled = v)),
              if (reminderEnabled) DropdownButtonFormField<int>(initialValue: reminderMinutes, decoration: const InputDecoration(labelText: 'Thời gian nhắc', prefixIcon: Icon(Icons.schedule), border: OutlineInputBorder()), items: const [
                DropdownMenuItem(value: 15, child: Text('15 phút trước')),
                DropdownMenuItem(value: 30, child: Text('30 phút trước')),
                DropdownMenuItem(value: 60, child: Text('1 giờ trước')),
                DropdownMenuItem(value: 1440, child: Text('1 ngày trước')),
              ], onChanged: (v) => setSheet(() => reminderMinutes = v ?? reminderMinutes)),
              const SizedBox(height: 14),
              TextField(controller: note, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Ghi chú', hintText: 'Nhập ghi chú...', border: OutlineInputBorder())),
              if (editing) ...[
                const SizedBox(height: 10),
                TextButton.icon(onPressed: () async { await DatabaseService.instance.deleteTask(task['id'] as int); if (sheetContext.mounted) Navigator.pop(sheetContext, true); }, icon: const Icon(Icons.delete_outline), label: const Text('Xóa công việc')),
              ],
            ]))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(sheetContext, false), child: const Text('Hủy'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(onPressed: () async {
                if (title.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên công việc'))); return; }
                if (editing) {
                  await DatabaseService.instance.updateTask(id: task['id'] as int, customerId: customerId, title: title.text.trim(), dueDate: due.toIso8601String(), priority: priority, completed: completed, note: note.text.trim(), reminderEnabled: reminderEnabled, reminderMinutes: reminderMinutes);
                } else {
                  await DatabaseService.instance.addTask(customerId: customerId, title: title.text.trim(), dueDate: due.toIso8601String(), priority: priority, note: note.text.trim(), reminderEnabled: reminderEnabled, reminderMinutes: reminderMinutes);
                }
                if (sheetContext.mounted) Navigator.pop(sheetContext, true);
              }, child: const Text('Lưu'))),
            ]),
          ])),
        ));
      }),
    );
    title.dispose(); note.dispose();
    if (saved == true) { await _load(); await IOSNativeService.instance.syncAll(); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Công việc')),
    floatingActionButton: FloatingActionButton.extended(onPressed: () => _openTask(), icon: const Icon(Icons.add_task), label: const Text('Thêm việc')),
    body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
      onRefresh: _load,
      child: tasks.isEmpty ? const Center(child: Text('Chưa có công việc.')) : ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), itemCount: tasks.length, separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final task = tasks[i]; final id = task['id'] as int; final completed = (task['completed'] as int? ?? 0) == 1;
          final due = DateTime.tryParse(task['due_date'] as String? ?? '') ?? DateTime.now(); final customer = customerName(task['customer_id']);
          return Card(elevation: 0, child: ListTile(
            onTap: () => _openTask(task),
            leading: Checkbox(value: completed, onChanged: (v) async { await DatabaseService.instance.setTaskCompleted(id, v ?? false); await _load(); await IOSNativeService.instance.syncAll(); }),
            title: Text(task['title'] as String? ?? '', style: TextStyle(fontWeight: FontWeight.w700, decoration: completed ? TextDecoration.lineThrough : null)),
            subtitle: Text([DateFormat('dd/MM/yyyy • HH:mm').format(due), task['priority'] as String? ?? 'Bình thường', if (customer.isNotEmpty) customer].join(' • ')),
            trailing: IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _openTask(task)),
          ));
        },
      ),
    ),
  );
}
