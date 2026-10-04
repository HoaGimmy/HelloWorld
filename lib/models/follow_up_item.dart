import 'customer.dart';

class FollowUpItem {
  final Customer customer;
  final DateTime dueAt;
  final DateTime lastInteractionAt;
  final String reason;
  final bool manualReminder;

  const FollowUpItem({
    required this.customer,
    required this.dueAt,
    required this.lastInteractionAt,
    required this.reason,
    this.manualReminder = false,
  });

  bool get isOverdue => dueAt.isBefore(DateTime.now());

  int get overdueDays {
    final days = DateTime.now().difference(dueAt).inDays;
    return days < 0 ? 0 : days;
  }
}
