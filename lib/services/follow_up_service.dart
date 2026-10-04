import '../models/customer.dart';
import '../models/follow_up_item.dart';
import 'database_service.dart';

class FollowUpService {
  FollowUpService._();
  static final instance = FollowUpService._();

  static const taskMarker = '[FOLLOW_UP]';
  static const defaultDays = <String, int>{
    'Khách mới': 1,
    'Đã liên hệ': 2,
    'Đang tư vấn': 2,
    'Khảo sát': 2,
    'Báo giá': 2,
    'Đàm phán': 3,
  };

  static const _ignoredActivityTypes = <String>{
    'Tạo khách',
    'Cập nhật',
    'Nhắc chăm sóc',
  };

  Future<Map<String, int>> getRules() async {
    final rules = <String, int>{};
    for (final entry in defaultDays.entries) {
      final raw = await DatabaseService.instance.getSetting('follow_up_days_${entry.key}');
      rules[entry.key] = int.tryParse(raw ?? '') ?? entry.value;
    }
    return rules;
  }

  Future<void> setRule(String stage, int days) =>
      DatabaseService.instance.setSetting('follow_up_days_$stage', days.clamp(1, 30).toString());

  Future<List<FollowUpItem>> getItems({bool dueOnly = false}) async {
    final db = DatabaseService.instance;
    final results = await Future.wait<Object>([
      db.getCustomers(),
      db.getTasks(onlyOpen: true),
      getRules(),
    ]);
    final customers = results[0] as List<Customer>;
    final tasks = results[1] as List<Map<String, Object?>>;
    final rules = results[2] as Map<String, int>;
    final now = DateTime.now();
    final items = <FollowUpItem>[];

    for (final customer in customers) {
      final id = customer.id;
      final thresholdDays = rules[customer.stage];
      if (id == null || thresholdDays == null) continue;

      final activities = await db.getActivities(id);
      var lastInteraction = DateTime.tryParse(customer.createdAt) ?? now;
      for (final activity in activities) {
        if (_ignoredActivityTypes.contains(activity.type)) continue;
        final parsed = DateTime.tryParse(activity.createdAt);
        if (parsed != null) {
          lastInteraction = parsed;
          break;
        }
      }

      Map<String, Object?>? manualTask;
      for (final task in tasks) {
        if (task['customer_id'] != id) continue;
        final note = task['note']?.toString() ?? '';
        if (!note.startsWith(taskMarker)) continue;
        manualTask = task;
        break;
      }

      DateTime dueAt;
      String reason;
      var manual = false;
      if (manualTask != null) {
        dueAt = DateTime.tryParse(manualTask['due_date']?.toString() ?? '') ??
            lastInteraction.add(Duration(days: thresholdDays));
        reason = 'Đến lịch chăm sóc lại';
        manual = true;
      } else {
        dueAt = lastInteraction.add(Duration(days: thresholdDays));
        reason = _reasonForStage(customer.stage);
      }

      if (dueOnly && dueAt.isAfter(now)) continue;
      items.add(FollowUpItem(
        customer: customer,
        dueAt: dueAt,
        lastInteractionAt: lastInteraction,
        reason: reason,
        manualReminder: manual,
      ));
    }

    items.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return items;
  }

  Future<List<FollowUpItem>> getDueItems() => getItems(dueOnly: true);

  Future<void> snooze(int customerId, String customerName, DateTime dueAt) async {
    await DatabaseService.instance.completeFollowUpTasks(customerId);
    await DatabaseService.instance.addTask(
      customerId: customerId,
      title: 'Chăm sóc lại $customerName',
      dueDate: dueAt.toIso8601String(),
      priority: 'Cao',
      note: '$taskMarker Nhắc chăm sóc khách hàng',
      reminderEnabled: true,
      reminderMinutes: 0,
    );
  }

  static String _reasonForStage(String stage) => switch (stage) {
        'Khách mới' => 'Khách mới chưa được liên hệ',
        'Đã liên hệ' => 'Đã liên hệ nhưng chưa có bước tiếp theo',
        'Đang tư vấn' => 'Khách đang tư vấn cần follow-up',
        'Khảo sát' => 'Khách đã khảo sát cần chăm sóc tiếp',
        'Báo giá' => 'Đã báo giá nhưng chưa có phản hồi',
        'Đàm phán' => 'Đang đàm phán nhưng chưa có tương tác mới',
        _ => 'Khách cần được chăm sóc',
      };
}
