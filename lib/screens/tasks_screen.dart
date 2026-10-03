import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/customer.dart';
import '../services/database_service.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<Map<String, Object?>> tasks = [];
  List<Customer> customers = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      DatabaseService.instance.getTasks(),
      DatabaseService.instance.getCustomers(),
    ]);
    if (!mounted) return;
    setState(() {
      tasks = results[0] as List<Map<String, Object?>>;
      customers = results[1] as List<Customer>;
      loading = false;
    });
  }

  String customerName(Object? id) {
    if (id == null) return '';
    for (final c in customers) {
      if (c.id == id) return c.name;
    }
    return '';
  }

  Future<void> _addTask() async {
    final title = TextEditingController();
    final note = TextEditingController();
    String priority = 'Bình thường';
    DateTime dueDate = DateTime.now().add(const Duration(days: 1));
    int? customerId;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Thêm công việc', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,controller: title, decoration: const InputDecoration(labelText: 'Tên công việc')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    initialValue: customerId,
                    decoration: const InputDecoration(labelText: 'Gắn với khách hàng'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Không gắn khách')),
                      ...customers.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
                    ],
                    onChanged: (v) => setModalState(() => customerId = v),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: 'Ưu tiên'),
                    items: const ['Thấp','Bình thường','Cao','Khẩn cấp'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                    onChanged: (v) => setModalState(() => priority = v ?? priority),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Hạn hoàn thành'),
                    subtitle: Text(DateFormat('dd/MM/yyyy').format(dueDate)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                        initialDate: dueDate,
                      );
                      if (picked != null) setModalState(() => dueDate = picked);
                    },
                  ),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Ghi chú')),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: title.text.trim().isEmpty
                        ? null
                        : () async {
                            await DatabaseService.instance.addTask(
                              customerId: customerId,
                              title: title.text.trim(),
                              dueDate: dueDate.toIso8601String(),
                              priority: priority,
                              note: note.text.trim(),
                            );
                            if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                          },
                    child: const Text('Lưu công việc'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    title.dispose();
    note.dispose();
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Công việc')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addTask,
          icon: const Icon(Icons.add_task),
          label: const Text('Thêm việc'),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: tasks.isEmpty
                    ? const Center(child: Text('Chưa có công việc.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: tasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final task = tasks[index];
                          final id = task['id'] as int;
                          final completed = (task['completed'] as int? ?? 0) == 1;
                          final due = DateTime.tryParse(task['due_date'] as String? ?? '') ?? DateTime.now();
                          final overdue = !completed && due.isBefore(DateTime.now());
                          final customer = customerName(task['customer_id']);
                          return Card(
                            elevation: 0,
                            child: CheckboxListTile(
                              value: completed,
                              onChanged: (value) async {
                                await DatabaseService.instance.setTaskCompleted(id, value ?? false);
                                _load();
                              },
                              title: Text(
                                task['title'] as String? ?? '',
                                style: TextStyle(fontWeight: FontWeight.w700, decoration: completed ? TextDecoration.lineThrough : null),
                              ),
                              subtitle: Text(
                                [
                                  DateFormat('dd/MM/yyyy').format(due),
                                  task['priority'] as String? ?? 'Bình thường',
                                  if (customer.isNotEmpty) customer,
                                  if (overdue) 'Quá hạn',
                                ].join(' • '),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          );
                        },
                      ),
              ),
      );
}
