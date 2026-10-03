import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/appointment.dart';
import '../models/customer.dart';
import '../services/database_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime selectedDate = DateTime.now();
  List<Map<String, Object?>> appointments = [];
  List<Customer> customers = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      DatabaseService.instance.getAppointmentsForDay(selectedDate),
      DatabaseService.instance.getCustomers(),
    ]);
    if (!mounted) return;
    setState(() {
      appointments = results[0] as List<Map<String, Object?>>;
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: selectedDate,
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
      _load();
    }
  }

  Future<void> _addAppointment() async {
    final title = TextEditingController();
    final location = TextEditingController();
    final note = TextEditingController();
    String time = DateFormat('HH:mm').format(DateTime.now());
    int duration = 60;
    int? customerId;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Tạo lịch hẹn', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Tên lịch hẹn')),
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  initialValue: customerId,
                  decoration: const InputDecoration(labelText: 'Khách hàng'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Không gắn khách')),
                    ...customers.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (v) => setModalState(() => customerId = v),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: const Text('Giờ hẹn'),
                  subtitle: Text(time),
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                    if (t != null) setModalState(() => time = t.format(context));
                  },
                ),
                DropdownButtonFormField<int>(
                  initialValue: duration,
                  decoration: const InputDecoration(labelText: 'Thời lượng'),
                  items: const [
                    DropdownMenuItem(value: 30, child: Text('30 phút')),
                    DropdownMenuItem(value: 60, child: Text('60 phút')),
                    DropdownMenuItem(value: 90, child: Text('90 phút')),
                    DropdownMenuItem(value: 120, child: Text('120 phút')),
                  ],
                  onChanged: (v) => setModalState(() => duration = v ?? duration),
                ),
                const SizedBox(height: 10),
                TextField(controller: location, decoration: const InputDecoration(labelText: 'Địa điểm')),
                const SizedBox(height: 10),
                TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Ghi chú')),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: title.text.trim().isEmpty
                      ? null
                      : () async {
                          final parts = time.split(':');
                          var hour = int.tryParse(parts.first) ?? TimeOfDay.now().hour;
                          var minute = int.tryParse(parts.last) ?? TimeOfDay.now().minute;
                          if (time.contains('PM') && hour < 12) hour += 12;
                          if (time.contains('AM') && hour == 12) hour = 0;
                          final dt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, hour, minute);
                          await DatabaseService.instance.addAppointment(
                            customerId: customerId,
                            title: title.text.trim(),
                            startsAt: dt.toIso8601String(),
                            durationMinutes: duration,
                            location: location.text.trim(),
                            note: note.text.trim(),
                          );
                          if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                        },
                  child: const Text('Lưu lịch hẹn'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    title.dispose();
    location.dispose();
    note.dispose();
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Lịch hẹn'),
          actions: [IconButton(onPressed: _pickDate, icon: const Icon(Icons.calendar_month))],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addAppointment,
          icon: const Icon(Icons.event_available),
          label: const Text('Đặt lịch'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Card(
                elevation: 0,
                child: ListTile(
                  leading: const Icon(Icons.today),
                  title: Text(DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(selectedDate)),
                  trailing: Text(appointments.length.toString() + ' lịch'),
                  onTap: _pickDate,
                ),
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: appointments.isEmpty
                          ? ListView(children: const [SizedBox(height: 120), Center(child: Text('Chưa có lịch hẹn trong ngày.'))])
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                              itemCount: appointments.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, index) {
                                final a = Appointment.fromMap(appointments[index]);
                                final time = DateFormat('HH:mm').format(DateTime.tryParse(a.startsAt) ?? DateTime.now());
                                final customer = customerName(a.customerId);
                                return Card(
                                  elevation: 0,
                                  child: ListTile(
                                    leading: CircleAvatar(child: Text(time)),
                                    title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    subtitle: Text([time, a.durationMinutes.toString() + ' phút', if (customer.isNotEmpty) customer, if (a.location.isNotEmpty) a.location].join(' • ')),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      );
}
