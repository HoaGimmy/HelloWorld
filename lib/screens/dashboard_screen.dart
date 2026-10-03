import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/database_service.dart';
import '../services/export_service.dart';
import '../widgets/mpwindows_brand.dart';
import 'operations_screen.dart';
import 'settings_screen.dart';

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

  void _openSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _openOperations() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const OperationsScreen())).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Object>>(
        future: _future,
        builder: (context, snapshot) {
          final values = snapshot.data;
          final stats = values == null ? const <String, int>{} : values[0] as Map<String, int>;
          final finance = values == null ? const <String, double>{} : values[1] as Map<String, double>;
          final total = stats['total'] ?? 0;
          final surveys = stats['surveys'] ?? 0;
          final quotes = stats['quotes'] ?? 0;
          final contracts = stats['contracts'] ?? 0;
          final contractValue = finance['contractValue'] ?? 0;
          final paid = finance['paid'] ?? 0;
          final receivable = finance['receivable'] ?? 0;

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
                  tooltip: 'Xuất Excel',
                  onPressed: exporting ? null : _export,
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
                  const SizedBox(height: 14),
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
                    childAspectRatio: 1.35,
                    children: [
                      _StatCard('Tổng khách', total.toString(), Icons.people_outline),
                      _StatCard('Khảo sát', surveys.toString(), Icons.straighten),
                      _StatCard('Báo giá', quotes.toString(), Icons.receipt_long_outlined),
                      _StatCard('Đã chốt', contracts.toString(), Icons.handshake_outlined),
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
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _openOperations,
                    icon: const Icon(Icons.business_center_outlined),
                    label: const Text('Quản lý công trình'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: exporting ? null : _export,
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Xuất toàn bộ dữ liệu Excel'),
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
  const _StatCard(this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 28),
              Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              Text(label),
            ],
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
