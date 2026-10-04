import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/activity.dart';
import '../models/follow_up_item.dart';
import '../services/database_service.dart';
import '../services/follow_up_service.dart';
import '../services/ios_native_service.dart';
import 'customers_screen.dart';

class FollowUpScreen extends StatefulWidget {
  const FollowUpScreen({super.key});
  @override
  State<FollowUpScreen> createState() => _FollowUpScreenState();
}

class _FollowUpScreenState extends State<FollowUpScreen> {
  List<FollowUpItem> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await FollowUpService.instance.getDueItems();
    if (!mounted) return;
    setState(() {
      items = data;
      loading = false;
    });
  }

  Future<void> _markContacted(FollowUpItem item) async {
    final id = item.customer.id;
    if (id == null) return;
    final now = DateTime.now().toIso8601String();
    await DatabaseService.instance.addActivity(Activity(
      customerId: id,
      type: 'Gọi điện',
      title: 'Đã liên hệ khách hàng',
      content: 'Đánh dấu đã chăm sóc từ danh sách nhắc nhở.',
      createdAt: now,
    ));
    await DatabaseService.instance.completeFollowUpTasks(id);
    if (item.customer.stage == 'Khách mới') {
      await DatabaseService.instance.updateCustomerStage(id, 'Đã liên hệ');
    }
    await IOSNativeService.instance.syncAll();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã ghi nhận liên hệ ${item.customer.name}')),
      );
    }
  }

  Future<void> _snooze(FollowUpItem item) async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Nhắc lại ${item.customer.name}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Sau 2 giờ'),
                onTap: () => Navigator.pop(sheetContext, DateTime.now().add(const Duration(hours: 2))),
              ),
              ListTile(
                leading: const Icon(Icons.today_outlined),
                title: const Text('Ngày mai lúc 09:00'),
                onTap: () {
                  final n = DateTime.now().add(const Duration(days: 1));
                  Navigator.pop(sheetContext, DateTime(n.year, n.month, n.day, 9));
                },
              ),
              ListTile(
                leading: const Icon(Icons.event_repeat_outlined),
                title: const Text('Sau 3 ngày'),
                onTap: () => Navigator.pop(sheetContext, DateTime.now().add(const Duration(days: 3))),
              ),
              ListTile(
                leading: const Icon(Icons.edit_calendar_outlined),
                title: const Text('Chọn ngày giờ khác'),
                onTap: () async {
                  final initial = DateTime.now().add(const Duration(days: 1));
                  final date = await showDatePicker(
                    context: sheetContext,
                    initialDate: initial,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (date == null || !sheetContext.mounted) return;
                  final time = await showTimePicker(
                    context: sheetContext,
                    initialTime: const TimeOfDay(hour: 9, minute: 0),
                  );
                  if (time == null || !sheetContext.mounted) return;
                  Navigator.pop(sheetContext, DateTime(date.year, date.month, date.day, time.hour, time.minute));
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || item.customer.id == null) return;
    await FollowUpService.instance.snooze(item.customer.id!, item.customer.name, picked);
    await DatabaseService.instance.addActivity(Activity(
      customerId: item.customer.id!,
      type: 'Nhắc chăm sóc',
      title: 'Hẹn chăm sóc lại',
      content: DateFormat('dd/MM/yyyy HH:mm').format(picked),
      createdAt: DateTime.now().toIso8601String(),
    ));
    await IOSNativeService.instance.syncAll();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sẽ nhắc lại lúc ${DateFormat('dd/MM HH:mm').format(picked)}')),
      );
    }
  }

  String _dueLabel(FollowUpItem item) =>
      item.overdueDays > 0 ? 'Quá hạn ${item.overdueDays} ngày' : 'Cần chăm sóc hôm nay';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Khách cần chăm sóc (${items.length})')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : items.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.task_alt, size: 64),
                          SizedBox(height: 12),
                          Text('Không có khách bị bỏ quên', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          SizedBox(height: 6),
                          Text('Tất cả khách đang được chăm sóc đúng lịch.', textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final item = items[index];
                        final customer = item.customer;
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(child: Text(customer.name.isEmpty ? '?' : customer.name[0].toUpperCase())),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(customer.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                          Text(customer.stage),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.errorContainer,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _dueLabel(item),
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onErrorContainer),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(item.reason, style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 3),
                                Text(
                                  'Tương tác cuối: ${DateFormat('dd/MM/yyyy HH:mm').format(item.lastInteractionAt)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: () => _markContacted(item),
                                        icon: const Icon(Icons.check_circle_outline, size: 18),
                                        label: const Text('Đã liên hệ'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _snooze(item),
                                        icon: const Icon(Icons.alarm_add_outlined, size: 18),
                                        label: const Text('Nhắc lại'),
                                      ),
                                    ),
                                  ],
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: customer.id!)),
                                    ).then((_) => _load()),
                                    child: const Text('Mở hồ sơ khách'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      );
