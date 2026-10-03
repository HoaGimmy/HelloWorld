import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../services/export_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, int>> _future;
  bool exporting = false;

  @override
  void initState() {
    super.initState();
    _future = DatabaseService.instance.getCustomerStats();
  }

  Future<void> _refresh() async {
    setState(() => _future = DatabaseService.instance.getCustomerStats());
    await _future;
  }

  Future<void> _export() async {
    setState(() => exporting = true);
    try {
      await ExportService.exportAndShare();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tạo file Excel và mở bảng chia sẻ.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xuất Excel lỗi: $e')));
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, int>>(
        future: _future,
        builder: (context, snapshot) {
          final s = snapshot.data ?? const {'total': 0, 'contracts': 0, 'surveys': 0, 'quotes': 0};
          return Scaffold(
            appBar: AppBar(
              title: const Text('Tổng quan'),
              actions: [
                IconButton(
                  tooltip: 'Xuất Excel',
                  onPressed: exporting ? null : _export,
                  icon: exporting ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.file_download_outlined),
                ),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                children: [
                  Text('MPWindows CRM', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('Nắm toàn bộ khách hàng và tiến độ bán hàng trên iPhone.'),
                  const SizedBox(height: 20),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.35,
                    children: [
                      _StatCard('Tổng khách', s['total'].toString(), Icons.people_outline),
                      _StatCard('Khảo sát', s['surveys'].toString(), Icons.straighten),
                      _StatCard('Báo giá', s['quotes'].toString(), Icons.receipt_long_outlined),
                      _StatCard('Đã chốt', s['contracts'].toString(), Icons.handshake_outlined),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 0,
                    child: ListTile(
                      leading: Icon(Icons.file_download_outlined, color: Theme.of(context).colorScheme.primary),
                      title: const Text('Xuất dữ liệu Excel'),
                      subtitle: const Text('Khách hàng, timeline, công việc và lịch hẹn thành một file XLSX.'),
                      trailing: FilledButton.tonalIcon(
                        onPressed: exporting ? null : _export,
                        icon: const Icon(Icons.ios_share),
                        label: const Text('Xuất'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 0,
                    child: ListTile(
                      leading: Icon(Icons.next_plan_outlined, color: Theme.of(context).colorScheme.primary),
                      title: const Text('Bước tiếp theo'),
                      subtitle: const Text('Báo giá → hợp đồng → thu tiền → công nợ → công trình.'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
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
