import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';
import 'customers_screen.dart';

class PipelineScreen extends StatefulWidget {
  const PipelineScreen({super.key});
  @override State<PipelineScreen> createState() => _PipelineScreenState();
}

class _PipelineScreenState extends State<PipelineScreen> {
  List<Customer> customers = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await DatabaseService.instance.getCustomers();
    if (!mounted) return;
    setState(() {
      customers = data;
      loading = false;
    });
  }

  Future<void> _changeStage(Customer customer) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text('Chuyển trạng thái', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            ...pipelineStages.map(
              (stage) => ListTile(
                leading: Icon(
                  stage == customer.stage ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                ),
                title: Text(stage),
                onTap: () => Navigator.pop(context, stage),
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null && selected != customer.stage) {
      await DatabaseService.instance.updateCustomerStage(customer.id!, selected);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Hành trình khách hàng')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: pipelineStages.map((stage) {
                  final list = customers.where((c) => c.stage == stage).toList();
                  final color = stageColor(stage, theme);
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: .12),
                        foregroundColor: color,
                        child: Text(list.length.toString()),
                      ),
                      title: Text(stage, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(list.isEmpty ? 'Chưa có khách' : list.length.toString() + ' khách'),
                      children: list.isEmpty
                          ? const [
                              Padding(
                                padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Chưa có khách ở giai đoạn này.'),
                                ),
                              )
                            ]
                          : list.map((customer) {
                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text(customer.name.trim().isEmpty ? '?' : customer.name.trim()[0].toUpperCase()),
                                ),
                                title: Text(customer.name),
                                subtitle: Text(customer.phone.isEmpty ? 'Chưa có SĐT' : customer.phone),
                                trailing: IconButton(
                                  tooltip: 'Đổi trạng thái',
                                  icon: const Icon(Icons.swap_horiz),
                                  onPressed: () => _changeStage(customer),
                                ),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: customer.id!)),
                                  );
                                  _load();
                                },
                              );
                            }).toList(),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }
}
