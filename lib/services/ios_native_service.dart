import 'dart:io';

import 'package:flutter/services.dart';

import 'database_service.dart';

class IOSNativeService {
  IOSNativeService._();

  static final IOSNativeService instance = IOSNativeService._();
  static const _channel = MethodChannel('vn.mpwindows.crm/native');

  Future<void> initialize() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<bool>('requestNotificationPermission');
      await syncAll();
    } on PlatformException {
      // Native integration may be unavailable in non-iOS/dev builds.
    }
  }

  Future<void> syncAll() async {
    if (!Platform.isIOS) return;

    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final database = DatabaseService.instance;

    final results = await Future.wait([
      database.getUpcomingAppointments(now, limit: 40),
      database.getTasks(onlyOpen: true),
      database.getAppointmentsForDay(now),
      database.getCustomers(),
    ]);

    final upcomingAppointments = results[0] as List<Map<String, Object?>>;
    final openTasks = results[1] as List<Map<String, Object?>>;
    final todayAppointments = results[2] as List<Map<String, Object?>>;
    final customers = results[3] as List<dynamic>;

    final customerNames = <int, String>{};
    for (final customer in customers) {
      final id = customer.id as int?;
      if (id != null) customerNames[id] = customer.name as String;
    }

    final reminders = <Map<String, Object?>>[];

    for (final row in upcomingAppointments) {
      final startsAt = DateTime.tryParse(row['starts_at'] as String? ?? '');
      final id = row['id'] as int?;
      if (startsAt == null || id == null || !startsAt.isAfter(now)) continue;

      var fireAt = startsAt.subtract(const Duration(minutes: 30));
      if (!fireAt.isAfter(now)) fireAt = startsAt;

      final customer = customerNames[row['customer_id']];
      final location = (row['location'] as String? ?? '').trim();
      final details = <String>[
        if (customer != null && customer.isNotEmpty) customer,
        if (location.isNotEmpty) location,
      ];

      reminders.add({
        'id': 'mpw.appointment.$id',
        'title': 'Lịch hẹn sắp tới',
        'body': [
          row['title'] as String? ?? 'Lịch hẹn',
          if (details.isNotEmpty) details.join(' • '),
        ].join(' — '),
        'fireAt': fireAt.millisecondsSinceEpoch,
      });
    }

    for (final row in openTasks.take(20)) {
      final due = DateTime.tryParse(row['due_date'] as String? ?? '');
      final id = row['id'] as int?;
      if (due == null || id == null) continue;

      final fireAt = DateTime(due.year, due.month, due.day, 9);
      if (!fireAt.isAfter(now)) continue;

      final customer = customerNames[row['customer_id']];
      reminders.add({
        'id': 'mpw.task.$id',
        'title': 'Công việc cần làm',
        'body': [
          row['title'] as String? ?? 'Công việc',
          if (customer != null && customer.isNotEmpty) customer,
        ].join(' — '),
        'fireAt': fireAt.millisecondsSinceEpoch,
      });
    }

    final dueTodayCount = openTasks.where((row) {
      final due = DateTime.tryParse(row['due_date'] as String? ?? '');
      return due != null && !due.isAfter(endOfToday);
    }).length;

    Map<String, Object?>? nextAppointment;
    if (upcomingAppointments.isNotEmpty) {
      final row = upcomingAppointments.first;
      final startsAt = DateTime.tryParse(row['starts_at'] as String? ?? '');
      if (startsAt != null) {
        nextAppointment = {
          'title': row['title'] as String? ?? 'Lịch hẹn',
          'time':
              '${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')}',
          'customer': customerNames[row['customer_id']] ?? '',
        };
      }
    }

    try {
      await _channel.invokeMethod('syncReminders', {'items': reminders});
      await _channel.invokeMethod('updateWidget', {
        'data': {
          'date': '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}',
          'appointmentCount': todayAppointments.length,
          'taskCount': dueTodayCount,
          'customerCount': customers.length,
          'nextAppointment': nextAppointment,
        },
      });
    } on PlatformException {
      // Keep the CRM usable if the native bridge is not present.
    }
  }
}
