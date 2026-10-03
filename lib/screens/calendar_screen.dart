import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/appointment.dart';
import '../models/customer.dart';
import '../services/database_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
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

  Future<void> _openAppointmentEditor({Appointment? appointment}) async {
    final isEditing = appointment != null;
    final initialDateTime = appointment == null
        ? DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            TimeOfDay.now().hour,
            TimeOfDay.now().minute,
          )
        : (DateTime.tryParse(appointment.startsAt) ?? selectedDate);

    final title = TextEditingController(text: appointment?.title ?? '');
    final location = TextEditingController(text: appointment?.location ?? '');
    final note = TextEditingController(text: appointment?.note ?? '');
    DateTime pickedDate = DateTime(initialDateTime.year, initialDateTime.month, initialDateTime.day);
    TimeOfDay pickedTime = TimeOfDay(hour: initialDateTime.hour, minute: initialDateTime.minute);
    int duration = appointment?.durationMinutes ?? 60;
    int? customerId = appointment?.customerId;
    if (customerId != null && !customers.any((c) => c.id == customerId)) {
      customerId = null;
    }

    final changed = await showModalBottomSheet<bool>(
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
                Text(
                  isEditing ? 'Chỉnh sửa lịch hẹn' : 'Tạo lịch hẹn',
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                TextField(
                    textCapitalization: TextCapitalization.sentences,
                  controller: title,
                  autofocus: !isEditing,
                  decoration: const InputDecoration(labelText: 'Tên lịch hẹn'),
                ),
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
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Ngày hẹn'),
                  subtitle: Text(DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(pickedDate)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: pickedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (date != null) setModalState(() => pickedDate = date);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: const Text('Giờ hẹn'),
                  subtitle: Text(pickedTime.format(context)),
                  onTap: () async {
                    final time = await showTimePicker(context: context, initialTime: pickedTime);
                    if (time != null) setModalState(() => pickedTime = time);
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
                TextField(
                    textCapitalization: TextCapitalization.sentences,controller: location, decoration: const InputDecoration(labelText: 'Địa điểm')),
                const SizedBox(height: 10),
                TextField(
                    textCapitalization: TextCapitalization.sentences,controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Ghi chú')),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    final cleanTitle = title.text.trim();
                    if (cleanTitle.isEmpty) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(content: Text('Vui lòng nhập tên lịch hẹn.')),
                      );
                      return;
                    }

                    final startsAt = DateTime(
                      pickedDate.year,
                      pickedDate.month,
                      pickedDate.day,
                      pickedTime.hour,
                      pickedTime.minute,
                    ).toIso8601String();

                    if (isEditing) {
                      await DatabaseService.instance.updateAppointment(
                        id: appointment.id!,
                        customerId: customerId,
                        title: cleanTitle,
                        startsAt: startsAt,
                        durationMinutes: duration,
                        location: location.text.trim(),
                        note: note.text.trim(),
                      );
                    } else {
                      await DatabaseService.instance.addAppointment(
                        customerId: customerId,
                        title: cleanTitle,
                        startsAt: startsAt,
                        durationMinutes: duration,
                        location: location.text.trim(),
                        note: note.text.trim(),
                      );
                    }
                    if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: Text(isEditing ? 'Lưu thay đổi' : 'Lưu lịch hẹn'),
                ),
                if (isEditing) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: sheetContext,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Xóa lịch hẹn?'),
                          content: Text('Lịch “${appointment.title}” sẽ bị xóa khỏi ứng dụng.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext, false),
                              child: const Text('Hủy'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(dialogContext, true),
                              child: const Text('Xóa'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      await DatabaseService.instance.deleteAppointment(appointment.id!);
                      if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Xóa lịch hẹn'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    title.dispose();
    location.dispose();
    note.dispose();

    if (changed == true) {
      if (!isEditing) {
        setState(() => selectedDate = pickedDate);
      }
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Lịch hẹn'),
          actions: [
            IconButton(
              tooltip: 'Chọn ngày',
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openAppointmentEditor(),
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
                  trailing: Text('${appointments.length} lịch'),
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
                          ? ListView(
                              children: const [
                                SizedBox(height: 120),
                                Center(child: Text('Chưa có lịch hẹn trong ngày.')),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                              itemCount: appointments.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, index) {
                                final appointment = Appointment.fromMap(appointments[index]);
                                final time = DateFormat('HH:mm').format(
                                  DateTime.tryParse(appointment.startsAt) ?? DateTime.now(),
                                );
                                final customer = customerName(appointment.customerId);
                                final details = [
                                  '${appointment.durationMinutes} phút',
                                  if (customer.isNotEmpty) customer,
                                  if (appointment.location.isNotEmpty) appointment.location,
                                ].join(' • ');

                                return Card(
                                  elevation: 0,
                                  child: ListTile(
                                    onTap: () => _openAppointmentEditor(appointment: appointment),
                                    leading: Container(
                                      width: 58,
                                      height: 52,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Text(
                                        time,
                                        maxLines: 1,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    title: Text(
                                      appointment.title,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    subtitle: Text(details),
                                    trailing: IconButton(
                                      tooltip: 'Chỉnh sửa',
                                      onPressed: () => _openAppointmentEditor(appointment: appointment),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
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
