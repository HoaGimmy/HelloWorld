import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/activity.dart';
import '../models/customer.dart';
import '../services/database_service.dart';
import '../services/ios_native_service.dart';
import '../utils/constants.dart';
import 'operations_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final searchController = TextEditingController();
  List<Customer> customers = [];
  bool loading = true;
  String? selectedStage;
  DateTime? selectedMonth;

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
    var filtered = selectedStage == null
        ? data
        : data.where((customer) => customer.stage == selectedStage).toList();
    if (selectedMonth != null) {
      filtered = filtered.where((customer) {
        final created = DateTime.tryParse(customer.createdAt);
        return created != null &&
            created.year == selectedMonth!.year &&
            created.month == selectedMonth!.month;
      }).toList();
    }
    if (!mounted) return;
    setState(() { customers = filtered; loading = false; });
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
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm tên, SĐT, địa chỉ...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchController.text.isEmpty
                          ? null
                          : IconButton(onPressed: () => searchController.clear(), icon: const Icon(Icons.clear)),
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _MonthYearFilter(
                  value: selectedMonth,
                  onChanged: (value) {
                    setState(() => selectedMonth = value);
                    _load();
                  },
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                _StageFilterChip(
                  label: 'Tất cả',
                  selected: selectedStage == null,
                  onTap: () { setState(() => selectedStage = null); _load(); },
                ),
                ...pipelineStages.map(
                  (stage) => _StageFilterChip(
                    label: stage,
                    selected: selectedStage == stage,
                    onTap: () { setState(() => selectedStage = stage); _load(); },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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

class _MonthYearFilter extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  const _MonthYearFilter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => PopupMenuButton<DateTime?>(
        tooltip: 'Lọc theo tháng/năm',
        onSelected: onChanged,
        itemBuilder: (_) {
          final now = DateTime.now();
          return <PopupMenuEntry<DateTime?>>[
            const PopupMenuItem<DateTime?>(value: null, child: Text('Tất cả thời gian')),
            const PopupMenuDivider(),
            ...List.generate(24, (index) {
              final date = DateTime(now.year, now.month - index);
              return PopupMenuItem<DateTime?>(
                value: date,
                child: Text('Tháng ${DateFormat('MM/yyyy').format(date)}'),
              );
            }),
          ];
        },
        child: Container(
          height: 56,
          constraints: const BoxConstraints(minWidth: 58, maxWidth: 142),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: value == null
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month_outlined, size: 21),
              if (value != null) ...[
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    DateFormat('MM/yyyy').format(value!),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              const SizedBox(width: 2),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            ],
          ),
        ),
      );
}

class _StageFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _StageFilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          showCheckmark: false,
          labelStyle: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
        ),
      );
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
  String? province;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    name.text = c?.name ?? '';
    phone.text = c?.phone ?? '';
    zalo.text = c?.zalo ?? '';
    address.text = c?.address ?? '';
    province = _detectProvince(c?.address ?? '');
    need.text = c?.need ?? '';
    budget.text = c == null || c.budget == 0 ? '' : NumberFormat.decimalPattern('vi_VN').format(c.budget);
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

  String? _detectProvince(String value) {
    final normalized = value.toLowerCase();
    for (final item in vietnamProvinces) {
      if (normalized.contains(item.toLowerCase())) return item;
    }
    return null;
  }

  String _fullAddress() {
    final detail = address.text.trim();
    final city = province?.trim() ?? '';
    if (city.isEmpty) return detail;
    if (detail.toLowerCase().contains(city.toLowerCase())) return detail;
    return detail.isEmpty ? city : '$detail, $city';
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
      address: _fullAddress(),
      source: source,
      stage: stage,
      need: need.text.trim(),
      budget: double.tryParse(budget.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
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
    await IOSNativeService.instance.syncAll();
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
          TextFormField(
                    textCapitalization: TextCapitalization.sentences,controller: name, decoration: dec('Họ và tên *', Icons.person_outline), validator: (v) => v == null || v.trim().isEmpty ? 'Nhập tên khách hàng' : null),
          const SizedBox(height: 12),
          TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: dec('Số điện thoại', Icons.phone_outlined)),
          const SizedBox(height: 12),
          TextFormField(
                    textCapitalization: TextCapitalization.sentences,controller: zalo, decoration: dec('Zalo', Icons.chat_bubble_outline)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: province,
            isExpanded: true,
            decoration: dec('Tỉnh/Thành phố', Icons.location_city_outlined),
            hint: const Text('Chọn Tỉnh/Thành phố'),
            items: vietnamProvinces
                .map((x) => DropdownMenuItem(value: x, child: Text(x, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => setState(() => province = v),
          ),
          const SizedBox(height: 12),
          TextFormField(
                    textCapitalization: TextCapitalization.sentences,controller: address, decoration: dec('Địa chỉ', Icons.location_on_outlined)),
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
          TextFormField(
                    textCapitalization: TextCapitalization.sentences,controller: need, maxLines: 2, decoration: dec('Nhu cầu', Icons.home_work_outlined)),
          const SizedBox(height: 12),
          TextFormField(
            controller: budget,
            keyboardType: TextInputType.number,
            decoration: dec('Ngân sách dự kiến (VNĐ)', Icons.payments_outlined).copyWith(suffixText: '₫'),
            onChanged: (value) {
              final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
              if (digits.isEmpty) return;
              final formatted = NumberFormat.decimalPattern('vi_VN').format(int.parse(digits));
              if (formatted != value) {
                budget.value = TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
              }
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
                    textCapitalization: TextCapitalization.sentences,controller: note, maxLines: 4, decoration: dec('Ghi chú', Icons.notes_outlined)),
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
      await IOSNativeService.instance.syncAll();
      if (mounted) Navigator.pop(context, true);
    }
  }

  String _phoneForAction(String phone) =>
      phone.replaceAll(RegExp(r'[^0-9+]'), '');

  Future<void> _copyPhone(String phone) async {
    await Clipboard.setData(ClipboardData(text: phone));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép số điện thoại'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openPhoneAction(String scheme, String phone) async {
    final cleanPhone = _phoneForAction(phone);
    if (cleanPhone.isEmpty) return;
    final uri = Uri(scheme: scheme, path: cleanPhone);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            scheme == 'tel'
                ? 'Không thể mở ứng dụng Điện thoại.'
                : 'Không thể mở ứng dụng Tin nhắn.',
          ),
        ),
      );
    }
  }

  Future<void> _changeStage() async {
    final c = customer;
    if (c == null) return;
    var selected = c.stage;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Cập nhật hành trình khách',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Đóng',
                        onPressed: () => Navigator.pop(sheetContext, false),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: pipelineStages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final stage = pipelineStages[index];
                        final active = stage == selected;
                        final stageThemeColor = stageColor(stage, Theme.of(context));
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => setSheetState(() => selected = stage),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            decoration: BoxDecoration(
                              color: active ? stageThemeColor.withValues(alpha: .08) : null,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: active
                                    ? stageThemeColor
                                    : Theme.of(context).dividerColor.withValues(alpha: .45),
                                width: active ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: stageThemeColor.withValues(alpha: .14),
                                  child: Icon(_stageIcon(stage), color: stageThemeColor, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    stage,
                                    style: TextStyle(
                                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Radio<String>(
                                  value: stage,
                                  groupValue: selected,
                                  onChanged: (value) {
                                    if (value != null) setSheetState(() => selected = value);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext, false),
                          child: const Text('Hủy'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(sheetContext, true),
                          child: const Text('Lưu'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (saved != true || selected == c.stage) return;
    final oldStage = c.stage;
    final now = DateTime.now().toIso8601String();
    await DatabaseService.instance.updateCustomerStage(widget.customerId, selected);
    await DatabaseService.instance.addActivity(Activity(
      customerId: widget.customerId,
      type: 'Hành trình',
      title: 'Cập nhật hành trình khách',
      content: '$oldStage → $selected',
      createdAt: now,
    ));
    await IOSNativeService.instance.syncAll();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã chuyển sang “$selected”')),
    );
  }

  IconData _stageIcon(String stage) => switch (stage) {
        'Khách mới' => Icons.group_outlined,
        'Đã liên hệ' => Icons.phone_in_talk_outlined,
        'Đang tư vấn' => Icons.forum_outlined,
        'Khảo sát' => Icons.search_outlined,
        'Báo giá' => Icons.request_quote_outlined,
        'Đàm phán' => Icons.handshake_outlined,
        'Chốt hợp đồng' => Icons.description_outlined,
        'Thi công' => Icons.build_outlined,
        'Hoàn thành' => Icons.task_alt,
        'Chăm sóc sau bán' => Icons.favorite_outline,
        'Không thành công / Mất khách' => Icons.cancel_outlined,
        _ => Icons.route_outlined,
      };

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
              TextField(
                    textCapitalization: TextCapitalization.sentences,controller: title, decoration: const InputDecoration(labelText: 'Tiêu đề')),
              TextField(
                    textCapitalization: TextCapitalization.sentences,controller: content, maxLines: 3, decoration: const InputDecoration(labelText: 'Nội dung')),
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
      await DatabaseService.instance.completeFollowUpTasks(widget.customerId);
      await IOSNativeService.instance.syncAll();
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
                        if (c.phone.isEmpty)
                          const Text('Chưa có số điện thoại')
                        else
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.phone,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _PhoneActionButton(
                                tooltip: 'Sao chép số',
                                icon: Icons.copy_outlined,
                                onPressed: () => _copyPhone(c.phone),
                              ),
                              _PhoneActionButton(
                                tooltip: 'Gọi điện',
                                icon: Icons.phone_outlined,
                                onPressed: () => _openPhoneAction('tel', c.phone),
                              ),
                              _PhoneActionButton(
                                tooltip: 'Nhắn tin',
                                icon: Icons.sms_outlined,
                                onPressed: () => _openPhoneAction('sms', c.phone),
                              ),
                            ],
                          ),
                      ])),
                    ]),
                    const SizedBox(height: 16),
                    Wrap(spacing: 16, runSpacing: 12, children: [
                      _Info(label: 'Nguồn', value: c.source),
                      _Info(label: 'Ngân sách', value: c.budget > 0 ? '${NumberFormat.decimalPattern('vi_VN').format(c.budget)} ₫' : 'Chưa có'),
                    ]),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _changeStage,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color.withValues(alpha: .28)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_stageIcon(c.stage), size: 18, color: color),
                            const SizedBox(width: 7),
                            Text(c.stage, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 3),
                            Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: color),
                          ],
                        ),
                      ),
                    ),
                    if (c.address.isNotEmpty) ...[const SizedBox(height: 12), _Info(label: 'Địa chỉ', value: c.address)],
                    if (c.need.isNotEmpty) ...[const SizedBox(height: 12), _Info(label: 'Nhu cầu', value: c.need)],
                    if (c.note.isNotEmpty) ...[const SizedBox(height: 12), _Info(label: 'Ghi chú', value: c.note)],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OperationsScreen(customerId: c.id, customerName: c.name),
                  ),
                );
                _load();
              },
              icon: const Icon(Icons.business_center_outlined),
              label: const Text('Quản lý công trình'),
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


class _PhoneActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _PhoneActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        padding: const EdgeInsets.all(6),
      );
}
