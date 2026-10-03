import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/activity.dart';
import '../models/customer.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final searchController = TextEditingController();
  List<Customer> customers = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    searchController.addListener(_load);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await DatabaseService.instance.getCustomers(query: searchController.text);
    if (!mounted) return;
    setState(() { customers = data; loading = false; });
  }

  Future<void> _openForm([Customer? customer]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CustomerFormScreen(customer: customer)),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Khách hàng')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Thêm khách'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Tìm tên, số điện thoại, địa chỉ...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(onPressed: () => searchController.clear(), icon: const Icon(Icons.clear)),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : customers.isEmpty
                    ? _EmptyCustomers(onAdd: () => _openForm())
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: customers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final c = customers[index];
                            final color = stageColor(c.stage, theme);
                            final contact = [if (c.phone.isNotEmpty) c.phone, if (c.address.isNotEmpty) c.address].join(' • ');
                            return Card(
                              elevation: 0,
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(14),
                                leading: CircleAvatar(child: Text(c.name.trim().isEmpty ? '?' : c.name.trim()[0].toUpperCase())),
                                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text(contact.isEmpty ? 'Chưa có thông tin liên hệ' : contact, maxLines: 2, overflow: TextOverflow.ellipsis),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                  decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(18)),
                                  child: Text(c.stage, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: c.id!)),
                                  );
                                  _load();
                                },
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
}

class _EmptyCustomers extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyCustomers({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text('Chưa có khách hàng', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text('Thêm khách đầu tiên để bắt đầu quản lý hành trình bán hàng.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Thêm khách hàng')),
            ],
          ),
        ),
      );
}

class CustomerFormScreen extends StatefulWidget {
  final Customer? customer;
  const CustomerFormScreen({super.key, this.customer});
  @override State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final zalo = TextEditingController();
  final address = TextEditingController();
  final need = TextEditingController();
  final budget = TextEditingController();
  final note = TextEditingController();
  late String source;
  late String stage;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    name.text = c?.name ?? '';
    phone.text = c?.phone ?? '';
    zalo.text = c?.zalo ?? '';
    address.text = c?.address ?? '';
    need.text = c?.need ?? '';
    budget.text = c == null || c.budget == 0 ? '' : c.budget.toStringAsFixed(0);
    note.text = c?.note ?? '';
    source = c?.source ?? leadSources.first;
    stage = c?.stage ?? pipelineStages.first;
  }

  @override
  void dispose() {
    name.dispose(); phone.dispose(); zalo.dispose(); address.dispose();
    need.dispose(); budget.dispose(); note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    final now = DateTime.now().toIso8601String();
    final old = widget.customer;
    final customer = Customer(
      id: old?.id,
      name: name.text.trim(),
      phone: phone.text.trim(),
      zalo: zalo.text.trim(),
      address: address.text.trim(),
      source: source,
      stage: stage,
      need: need.text.trim(),
      budget: double.tryParse(budget.text.replaceAll(',', '').trim()) ?? 0,
      note: note.text.trim(),
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
    );
    if (old == null) {
      final id = await DatabaseService.instance.insertCustomer(customer);
      await DatabaseService.instance.addActivity(Activity(
        customerId: id,
        type: 'Tạo khách',
        title: 'Tạo hồ sơ khách hàng',
        content: 'Nguồn: ' + source,
        createdAt: now,
      ));
    } else {
      await DatabaseService.instance.updateCustomer(customer);
      await DatabaseService.instance.addActivity(Activity(
        customerId: old.id!,
        type: 'Cập nhật',
        title: 'Cập nhật hồ sơ',
        content: 'Trạng thái: ' + stage,
        createdAt: now,
      ));
    }
    if (mounted) Navigator.pop(context, true);
  }

  InputDecoration dec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.customer == null ? 'Thêm khách hàng' : 'Sửa khách hàng')),
    body: Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          TextFormField(controller: name, decoration: dec('Họ và tên *', Icons.person_outline), validator: (v) => v == null || v.trim().isEmpty ? 'Nhập tên khách hàng' : null),
          const SizedBox(height: 12),
          TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: dec('Số điện thoại', Icons.phone_outlined)),
          const SizedBox(height: 12),
          TextFormField(controller: zalo, decoration: dec('Zalo', Icons.chat_bubble_outline)),
          const SizedBox(height: 12),
          TextFormField(controller: address, decoration: dec('Địa chỉ', Icons.location_on_outlined)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: source,
            decoration: dec('Nguồn khách', Icons.campaign_outlined),
            items: leadSources.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
            onChanged: (v) => setState(() => source = v ?? source),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: stage,
            decoration: dec('Trạng thái', Icons.route_outlined),
            items: pipelineStages.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
            onChanged: (v) => setState(() => stage = v ?? stage),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: need, maxLines: 2, decoration: dec('Nhu cầu', Icons.home_work_outlined)),
          const SizedBox(height: 12),
          TextFormField(controller: budget, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: dec('Ngân sách dự kiến', Icons.payments_outlined)),
          const SizedBox(height: 12),
          TextFormField(controller: note, maxLines: 4, decoration: dec('Ghi chú', Icons.notes_outlined)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
            label: Text(saving ? 'Đang lưu...' : 'Lưu khách hàng'),
          ),
        ],
      ),
    ),
  );
}

class CustomerDetailScreen extends StatefulWidget {
  final int customerId;
  const CustomerDetailScreen({super.key, required this.customerId});
  @override State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  Customer? customer;
  List<Activity> activities = [];
  bool loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final c = await DatabaseService.instance.getCustomer(widget.customerId);
    final a = await DatabaseService.instance.getActivities(widget.customerId);
    if (!mounted) return;
    setState(() { customer = c; activities = a; loading = false; });
  }

  Future<void> _edit() async {
    final c = customer;
    if (c == null) return;
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => CustomerFormScreen(customer: c)));
    if (changed == true) _load();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa khách hàng?'),
        content: const Text('Timeline của khách hàng cũng sẽ bị xóa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok == true) {
      await DatabaseService.instance.deleteCustomer(widget.customerId);
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _addActivity() async {
    final title = TextEditingController();
    final content = TextEditingController();
    var type = 'Gọi điện';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thêm hoạt động'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                items: const ['Gọi điện','Tin nhắn','Khảo sát','Báo giá','Gặp khách','Ghi chú']
                    .map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                onChanged: (v) => setDialogState(() => type = v ?? type),
                decoration: const InputDecoration(labelText: 'Loại'),
              ),
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Tiêu đề')),
              TextField(controller: content, maxLines: 3, decoration: const InputDecoration(labelText: 'Nội dung')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Lưu')),
          ],
        ),
      ),
    );
    if (saved == true && title.text.trim().isNotEmpty) {
      await DatabaseService.instance.addActivity(Activity(
        customerId: widget.customerId,
        type: type,
        title: title.text.trim(),
        content: content.text.trim(),
        createdAt: DateTime.now().toIso8601String(),
      ));
      await _load();
    }
    title.dispose();
    content.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final c = customer;
    if (c == null) return const Scaffold(body: Center(child: Text('Không tìm thấy khách hàng')));
    final color = stageColor(c.stage, Theme.of(context));

    return Scaffold(
      appBar: AppBar(
        title: Text(c.name),
        actions: [
          IconButton(onPressed: _edit, icon: const Icon(Icons.edit_outlined)),
          IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addActivity,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Hoạt động'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      CircleAvatar(radius: 30, child: Text(c.name.trim().isEmpty ? '?' : c.name.trim()[0].toUpperCase())),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.name, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
                        Text(c.phone.isEmpty ? 'Chưa có số điện thoại' : c.phone),
                      ])),
                    ]),
                    const SizedBox(height: 16),
                    Wrap(spacing: 16, runSpacing: 12, children: [
                      _Info(label: 'Nguồn', value: c.source),
                      _Info(label: 'Ngân sách', value: c.budget > 0 ? NumberFormat.decimalPattern('vi_VN').format(c.budget) : 'Chưa có'),
                    ]),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
                      child: Text(c.stage, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                    ),
                    if (c.address.isNotEmpty) ...[const SizedBox(height: 12), _Info(label: 'Địa chỉ', value: c.address)],
                    if (c.need.isNotEmpty) ...[const SizedBox(height: 12), _Info(label: 'Nhu cầu', value: c.need)],
                    if (c.note.isNotEmpty) ...[const SizedBox(height: 12), _Info(label: 'Ghi chú', value: c.note)],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Timeline', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (activities.isEmpty)
              const Card(elevation: 0, child: Padding(padding: EdgeInsets.all(20), child: Text('Chưa có hoạt động.')))
            else
              ...activities.map((a) {
                final stamp = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.tryParse(a.createdAt) ?? DateTime.now());
                final subtitle = a.type + ' • ' + stamp + (a.content.isEmpty ? '' : '\n' + a.content);
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(_activityIcon(a.type))),
                    title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(subtitle),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  IconData _activityIcon(String type) => switch (type) {
        'Gọi điện' => Icons.phone,
        'Tin nhắn' => Icons.chat_bubble_outline,
        'Khảo sát' => Icons.straighten,
        'Báo giá' => Icons.receipt_long,
        'Gặp khách' => Icons.handshake_outlined,
        _ => Icons.notes,
      };
}

class _Info extends StatelessWidget {
  final String label;
  final String value;
  const _Info({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 155,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 3),
        Text(value),
      ],
    ),
  );
}
