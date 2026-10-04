import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/database_service.dart';
import '../services/export_service.dart';
import '../services/follow_up_service.dart';
import '../services/google_drive_backup_service.dart';
import '../widgets/mpwindows_brand.dart';
import '../models/customer.dart';
import 'customers_screen.dart';
import 'operations_screen.dart';
import 'settings_screen.dart';
import 'tasks_screen.dart';
import 'calendar_screen.dart';
import 'follow_up_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Object>> _future;
  bool exporting = false;
  int selectedYear = DateTime.now().year;
  int? selectedMonth = DateTime.now().month;
  final money = NumberFormat.decimalPattern('vi_VN');

  @override
  void initState() {
    super.initState();
    _reloadFuture();
  }

  void _reloadFuture() {
    _future = Future.wait<Object>([
      DatabaseService.instance.getCustomerStats(year: selectedYear, month: selectedMonth),
      DatabaseService.instance.getFinanceStats(year: selectedYear, month: selectedMonth),
      DatabaseService.instance.getTasks(onlyOpen: true),
      DatabaseService.instance.getAppointmentsForDay(DateTime.now()),
      FollowUpService.instance.getDueItems(),
      DatabaseService.instance.getCommissionStats(year: selectedYear, month: selectedMonth),
      DatabaseService.instance.getProjects(),
    ]);
  }

  Future<void> _refresh() async {
    setState(_reloadFuture);
    await _future;
  }

  Future<void> _export() async {
    setState(() => exporting = true);
    try {
      await ExportService.exportAndShare();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tạo file Excel và mở bảng chia sẻ.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xuất Excel lỗi: ' + e.toString())));
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Future<void> _syncSheets() async {
    setState(() => exporting = true);
    try {
      await GoogleDriveBackupService.instance.syncToGoogleSheets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã đồng bộ dữ liệu lên Google Sheets.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đồng bộ Google Sheets lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Future<void> _showExportOptions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Xuất / Đồng bộ dữ liệu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.table_view_outlined),
                title: const Text('Xuất file Excel (.xlsx)'),
                subtitle: const Text('Tạo file để lưu hoặc chia sẻ'),
                onTap: () => Navigator.pop(sheetContext, 'excel'),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_sync_outlined),
                title: const Text('Đồng bộ Google Sheets'),
                subtitle: const Text('Cập nhật MPWindows CRM Online trên Google Drive'),
                onTap: () => Navigator.pop(sheetContext, 'sheets'),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == 'excel') await _export();
    if (action == 'sheets') await _syncSheets();
  }

  void _openSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _openOperations() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const OperationsScreen())).then((_) => _refresh());
  }

  void _openCustomersByStage(String title, {String? stage}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DashboardCustomerListScreen(
          title: title,
          stage: stage,
          year: selectedYear,
          month: selectedMonth,
        ),
      ),
    ).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Object>>(
        future: _future,
        builder: (context, snapshot) {
          final values = snapshot.data;
          final stats = values == null ? const <String, int>{} : values[0] as Map<String, int>;
          final finance = values == null ? const <String, double>{} : values[1] as Map<String, double>;
          final tasks = values == null ? const <Map<String, Object?>>[] : values[2] as List<Map<String, Object?>>;
          final appointments = values == null ? const <Map<String, Object?>>[] : values[3] as List<Map<String, Object?>>;
          final followUps = values == null ? const <dynamic>[] : values[4] as List<dynamic>;
          final commissionStats = values == null ? const <String, double>{} : values[5] as Map<String, double>;
          final projects = values == null ? const <Map<String, Object?>>[] : values[6] as List<Map<String, Object?>>;
          final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
          final installsToday = projects.where((project) {
            final raw = project['install_date']?.toString();
            final date = raw == null ? null : DateTime.tryParse(raw);
            return date != null && DateFormat('yyyy-MM-dd').format(date) == todayKey;
          }).length;
          final overdue = tasks.where((task) {
            final due = DateTime.tryParse(task['due_date']?.toString() ?? '');
            return due != null && due.isBefore(DateTime.now());
          }).length;
          final total = stats['total'] ?? 0;
          final surveys = stats['surveys'] ?? 0;
          final quotes = stats['quotes'] ?? 0;
          final contracts = stats['contracts'] ?? 0;
          final consulting = stats['consulting'] ?? 0;
          final negotiating = stats['negotiating'] ?? 0;
          final contractValue = finance['contractValue'] ?? 0;
          final paid = finance['paid'] ?? 0;
          final receivable = finance['receivable'] ?? 0;
          final commission = commissionStats['commission'] ?? 0;
          final commissionReceived = commissionStats['received'] ?? 0;
          final commissionRemaining = commissionStats['remaining'] ?? 0;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Tổng quan'),
              actions: [
                IconButton(
                  tooltip: 'Cài đặt',
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings_outlined),
                ),
                IconButton(
                  tooltip: 'Nghiệp vụ',
                  onPressed: _openOperations,
                  icon: const Icon(Icons.business_center_outlined),
                ),
                IconButton(
                  tooltip: 'Xuất / Đồng bộ dữ liệu',
                  onPressed: exporting ? null : _showExportOptions,
                  icon: exporting
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.file_download_outlined),
                ),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                children: [
                  const MPWindowsBrandHeader(),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Hôm nay',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        DateFormat('dd/MM/yyyy (EEE)', 'vi_VN').format(DateTime.now()),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.42,
                    children: [
                      _TodayCard(
                        icon: Icons.notifications_active_outlined,
                        value: followUps.length,
                        label: 'Cần chăm sóc',
                        warning: followUps.isNotEmpty ? 'Cần xử lý' : null,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FollowUpScreen())).then((_) => _refresh()),
                      ),
                      _TodayCard(
                        icon: Icons.event_available_outlined,
                        value: appointments.length,
                        label: 'Lịch hẹn',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen())).then((_) => _refresh()),
                      ),
                      _TodayCard(
                        icon: Icons.home_repair_service_outlined,
                        value: installsToday,
                        label: 'Thi công hôm nay',
                        warning: installsToday > 0 ? 'Theo lịch công trình' : null,
                        onTap: _openOperations,
                      ),
                      _TodayCard(
                        icon: Icons.task_alt,
                        value: tasks.length,
                        label: 'Việc đang mở',
                        warning: overdue > 0 ? '$overdue quá hạn' : null,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksScreen())).then((_) => _refresh()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FollowUpScreen()),
                      ).then((_) => _refresh()),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: followUps.isEmpty
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : Theme.of(context).colorScheme.errorContainer,
                              child: Icon(
                                followUps.isEmpty ? Icons.task_alt : Icons.notifications_active_outlined,
                                color: followUps.isEmpty
                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                    : Theme.of(context).colorScheme.onErrorContainer,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Khách cần chăm sóc', style: TextStyle(fontWeight: FontWeight.w800)),
                                  Text(
                                    followUps.isEmpty
                                        ? 'Không có khách bị bỏ quên'
                                        : '${followUps.length} khách đang cần follow-up',
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${followUps.length}',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: followUps.isEmpty ? null : Theme.of(context).colorScheme.error,
                                  ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text('CRM vận hành', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  _PeriodFilter(
                    year: selectedYear,
                    month: selectedMonth,
                    onYearChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        selectedYear = value;
                        _reloadFuture();
                      });
                    },
                    onMonthChanged: (value) {
                      setState(() {
                        selectedMonth = value;
                        _reloadFuture();
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.55,
                    children: [
                      _StatCard('Tổng khách hàng', total.toString(), Icons.people_outline, onTap: () => _openCustomersByStage('Tổng khách hàng')),
                      _StatCard('Khảo sát', surveys.toString(), Icons.straighten, onTap: () => _openCustomersByStage('Khảo sát', stage: 'Khảo sát')),
                      _StatCard('Báo giá', quotes.toString(), Icons.receipt_long_outlined, onTap: () => _openCustomersByStage('Báo giá', stage: 'Báo giá')),
                      _StatCard('Đang tư vấn', consulting.toString(), Icons.support_agent_outlined, onTap: () => _openCustomersByStage('Đang tư vấn', stage: 'Đang tư vấn')),
                      _StatCard('Đàm phán', negotiating.toString(), Icons.forum_outlined, onTap: () => _openCustomersByStage('Đàm phán', stage: 'Đàm phán')),
                      _StatCard('Đã chốt', contracts.toString(), Icons.handshake_outlined, onTap: () => _openCustomersByStage('Đã chốt', stage: 'Chốt hợp đồng')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Tài chính', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _MoneyRow('Giá trị hợp đồng', money.format(contractValue) + 'đ'),
                          const Divider(),
                          _MoneyRow('Đã thu', money.format(paid) + 'đ'),
                          const Divider(),
                          _MoneyRow('Còn phải thu', money.format(receivable < 0 ? 0 : receivable) + 'đ', emphasize: true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Hoa hồng của tôi', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _openOperations,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _MoneyRow('Hoa hồng dự kiến', money.format(commission) + 'đ', emphasize: true),
                            const Divider(),
                            _MoneyRow('Đã nhận', money.format(commissionReceived) + 'đ'),
                            const Divider(),
                            _MoneyRow('Còn chưa nhận', money.format(commissionRemaining) + 'đ', emphasize: commissionRemaining > 0),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    selectedMonth == null
                                        ? 'Tổng hợp theo năm $selectedYear • Bấm để xem từng hợp đồng'
                                        : 'Tổng hợp tháng $selectedMonth/$selectedYear • Bấm để xem từng hợp đồng',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                                const Icon(Icons.chevron_right, size: 20),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _openOperations,
                    icon: const Icon(Icons.business_center_outlined),
                    label: const Text('Quản lý công trình'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: exporting ? null : _showExportOptions,
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Xuất / Đồng bộ dữ liệu'),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class _PeriodFilter extends StatelessWidget {
  final int year;
  final int? month;
  final ValueChanged<int?> onYearChanged;
  final ValueChanged<int?> onMonthChanged;

  const _PeriodFilter({
    required this.year,
    required this.month,
    required this.onYearChanged,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List<int>.generate(12, (index) => currentYear + 1 - index);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_alt_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 7),
                const Text('Kỳ đánh giá', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  month == null ? 'Cả năm $year' : 'Tháng $month/$year',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    initialValue: month,
                    decoration: const InputDecoration(
                      labelText: 'Tháng',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Cả năm')),
                      ...List.generate(
                        12,
                        (index) => DropdownMenuItem<int?>(
                          value: index + 1,
                          child: Text('Tháng ${index + 1}'),
                        ),
                      ),
                    ],
                    onChanged: onMonthChanged,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: year,
                    decoration: const InputDecoration(
                      labelText: 'Năm',
                      border: OutlineInputBorder(),
                    ),
                    items: years
                        .map((item) => DropdownMenuItem<int>(value: item, child: Text(item.toString())))
                        .toList(),
                    onChanged: onYearChanged,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  const _StatCard(this.label, this.value, this.icon, {this.onTap});
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .55), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, size: 18),
              ]),
              Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        ),
      );
}

class _DashboardCustomerListScreen extends StatefulWidget {
  final String title;
  final String? stage;
  final int year;
  final int? month;
  const _DashboardCustomerListScreen({required this.title, this.stage, required this.year, required this.month});

  @override
  State<_DashboardCustomerListScreen> createState() => _DashboardCustomerListScreenState();
}

class _DashboardCustomerListScreenState extends State<_DashboardCustomerListScreen> {
  bool loading = true;
  List<Customer> customers = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final all = await DatabaseService.instance.getCustomers();
    final filtered = all.where((c) {
      if (widget.stage != null && c.stage != widget.stage) return false;
      final created = DateTime.tryParse(c.createdAt);
      if (created == null || created.year != widget.year) return false;
      return widget.month == null || created.month == widget.month;
    }).toList();
    if (mounted) setState(() { customers = filtered; loading = false; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${widget.title} (${customers.length})')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : customers.isEmpty
            ? Center(child: Text('Không có khách hàng trong ${widget.month == null ? 'năm' : 'tháng'} đã chọn.'))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: customers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final customer = customers[i];
                    return Card(
                      elevation: 0,
                      child: ListTile(
                        leading: CircleAvatar(child: Text(customer.name.isEmpty ? '?' : customer.name[0].toUpperCase())),
                        title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text([if (customer.phone.isNotEmpty) customer.phone, customer.stage].join(' • ')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: customer.id!)),
                        ).then((_) => _load()),
                      ),
                    );
                  },
                ),
              ),
  );
}

class _MoneyRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;
  const _MoneyRow(this.label, this.value, {this.emphasize = false});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: TextStyle(fontSize: emphasize ? 18 : 16, fontWeight: FontWeight.w800)),
        ],
      );
}


class _TodayCard extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final String? warning;
  final VoidCallback onTap;
  const _TodayCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
    this.warning,
  });

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$value', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, height: 1)),
                      const SizedBox(height: 6),
                      Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.15)),
                      if (warning != null) ...[
                        const SizedBox(height: 5),
                        Text(warning!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.error)),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ),
        ),
      );
}
