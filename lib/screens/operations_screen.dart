import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/customer.dart';
import '../services/database_service.dart';
import '../services/attachment_service.dart';
import '../utils/constants.dart';

class _VndInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final formatted = NumberFormat.decimalPattern('vi_VN').format(int.parse(digits));
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

String _moneyDigits(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

class OperationsScreen extends StatefulWidget {
  final int? customerId;
  final String? customerName;
  const OperationsScreen({super.key, this.customerId, this.customerName});

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> with SingleTickerProviderStateMixin {
  late TabController tabController;
  List<Customer> customers = [];
  List<Map<String, Object?>> projects = [];
  List<Map<String, Object?>> quotes = [];
  List<Map<String, Object?>> contracts = [];
  List<Map<String, Object?>> payments = [];
  bool loading = true;

  final money = NumberFormat.decimalPattern('vi_VN');

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      DatabaseService.instance.getCustomers(),
      DatabaseService.instance.getProjects(customerId: widget.customerId),
      DatabaseService.instance.getQuotes(customerId: widget.customerId),
      DatabaseService.instance.getContracts(customerId: widget.customerId),
      DatabaseService.instance.getPayments(customerId: widget.customerId),
    ]);
    if (!mounted) return;
    setState(() {
      customers = results[0] as List<Customer>;
      projects = results[1] as List<Map<String, Object?>>;
      quotes = results[2] as List<Map<String, Object?>>;
      contracts = results[3] as List<Map<String, Object?>>;
      payments = results[4] as List<Map<String, Object?>>;
      loading = false;
    });
  }

  String customerName(Object? id) {
    if (widget.customerId != null && id == widget.customerId && widget.customerName != null) {
      return widget.customerName!;
    }
    for (final customer in customers) {
      if (customer.id == id) return customer.name;
    }
    return 'Khách hàng';
  }

  String projectName(Object? id) {
    for (final project in projects) {
      if (project['id'] == id) return (project['name'] ?? 'Công trình').toString();
    }
    return 'Chưa gắn công trình';
  }

  String contractCode(Object? id) {
    for (final contract in contracts) {
      if (contract['id'] == id) return (contract['code'] ?? 'Hợp đồng').toString();
    }
    return 'Hợp đồng';
  }

  int? defaultCustomerId() => widget.customerId ?? (customers.isEmpty ? null : customers.first.id);

  Future<void> _addProject([Map<String, Object?>? existing]) async {
    final name = TextEditingController(text: (existing?['name'] ?? '').toString());
    final address = TextEditingController(text: (existing?['address'] ?? '').toString());
    String aluminumBrand = (existing?['aluminum_brand'] ?? aluminumBrands.first).toString();
    if (!aluminumBrands.contains(aluminumBrand)) aluminumBrand = aluminumBrands.first;
    final aluminumType = TextEditingController(text: (existing?['aluminum_type'] ?? '').toString());
    final accessory = TextEditingController(text: (existing?['accessory'] ?? '').toString());
    final areaM2 = TextEditingController(text: existing == null ? '' : (existing['area_m2'] ?? '').toString());
    final quantity = TextEditingController(text: existing == null ? '' : (existing['quantity'] ?? '').toString());
    final note = TextEditingController(text: (existing?['note'] ?? '').toString());
    int? customerId = existing?['customer_id'] as int? ?? defaultCustomerId();
    String category = (existing?['category'] ?? 'Cửa nhôm kính').toString();
    String status = (existing?['status'] ?? 'Chuẩn bị').toString();
    DateTime? productionDate = DateTime.tryParse((existing?['production_date'] ?? '').toString());
    DateTime? installDate = DateTime.tryParse((existing?['install_date'] ?? '').toString());
    final photoPaths = <String>[];
    try { photoPaths.addAll((jsonDecode((existing?['photo_paths'] ?? '[]').toString()) as List).cast<String>()); } catch (_) {}

    Future<DateTime?> pickDate(BuildContext context, DateTime? current) =>
        showDatePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
          initialDate: current ?? DateTime.now(),
        );

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
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Quay lại',
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        existing == null ? 'Thêm công trình' : 'Chỉnh sửa công trình',
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _CustomerPicker(
                  customers: customers,
                  value: customerId,
                  locked: widget.customerId != null,
                  onChanged: (v) => setModalState(() => customerId = v),
                ),
                const SizedBox(height: 10),
                TextField(
                    textCapitalization: TextCapitalization.sentences,controller: name, decoration: const InputDecoration(labelText: 'Tên công trình *')),
                const SizedBox(height: 10),
                TextField(
                    textCapitalization: TextCapitalization.sentences,controller: address, decoration: const InputDecoration(labelText: 'Địa chỉ công trình')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Hạng mục'),
                  items: const ['Cửa nhôm kính','Vách kính','Mặt dựng','Lam nhôm','Lan can kính','Khác']
                      .map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                  onChanged: (v) => setModalState(() => category = v ?? category),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: aluminumBrand,
                  decoration: const InputDecoration(labelText: 'Hãng nhôm'),
                  items: aluminumBrands
                      .map((brand) => DropdownMenuItem(value: brand, child: Text(brand)))
                      .toList(),
                  onChanged: (value) => setModalState(() => aluminumBrand = value ?? aluminumBrand),
                ),
                const SizedBox(height: 10),
                TextField(
                    textCapitalization: TextCapitalization.sentences,controller: aluminumType, decoration: const InputDecoration(labelText: 'Loại nhôm', hintText: 'VD: cầu cách nhiệt, slim...')),
                const SizedBox(height: 10),
                TextField(
                    textCapitalization: TextCapitalization.sentences,controller: accessory, decoration: const InputDecoration(labelText: 'Phụ kiện', hintText: 'VD: Cmech, Kinlong...')),
                const SizedBox(height: 10),
                TextField(
                  controller: areaM2,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Khối lượng', suffixText: 'm²', hintText: 'VD: 25,5'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Số lượng', suffixText: 'bộ'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final d = await pickDate(context, productionDate);
                          if (d != null) setModalState(() => productionDate = d);
                        },
                        icon: const Icon(Icons.precision_manufacturing_outlined),
                        label: Text(productionDate == null ? 'Ngày sản xuất' : DateFormat('dd/MM/yyyy').format(productionDate!)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final d = await pickDate(context, installDate);
                          if (d != null) setModalState(() => installDate = d);
                        },
                        icon: const Icon(Icons.event_available_outlined),
                        label: Text(installDate == null ? 'Ngày lắp đặt' : DateFormat('dd/MM/yyyy').format(installDate!)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Tiến độ'),
                  items: const ['Chuẩn bị','Đo đạc','Sản xuất','Lắp đặt','Nghiệm thu','Hoàn thành']
                      .map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                  onChanged: (v) => setModalState(() => status = v ?? status),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await AttachmentService.pickProjectImages();
                    if (selected.isNotEmpty) setModalState(() => photoPaths.addAll(selected));
                  },
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(photoPaths.isEmpty ? 'Thêm hình ảnh công trình' : 'Thêm ảnh khác (${photoPaths.length} ảnh)'),
                ),
                if (photoPaths.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 82,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: photoPaths.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, index) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(File(photoPaths[index]), width: 82, height: 82, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                    textCapitalization: TextCapitalization.sentences,controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Ghi chú')),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () async {
                    if (customerId == null || name.text.trim().isEmpty) return;
                    final now = DateTime.now().toIso8601String();
                    final data = <String, Object?>{
                      'customer_id': customerId,
                      'name': name.text.trim(),
                      'address': address.text.trim(),
                      'category': category,
                      'aluminum_brand': aluminumBrand,
                      'aluminum_type': aluminumType.text.trim(),
                      'aluminum_system': '',
                      'accessory': accessory.text.trim(),
                      'dimensions': '',
                      'area_m2': double.tryParse(areaM2.text.replaceAll(',', '.').trim()) ?? 0,
                      'quantity': int.tryParse(quantity.text.trim()) ?? 0,
                      'status': status,
                      'start_date': now,
                      'production_date': productionDate?.toIso8601String() ?? '',
                      'install_date': installDate?.toIso8601String() ?? '',
                      'photo_paths': jsonEncode(photoPaths),
                      'note': note.text.trim(),
                      'created_at': existing?['created_at'] ?? now,
                      'updated_at': now,
                    };
                    if (existing == null) {
                      await DatabaseService.instance.addProject(data);
                    } else {
                      await DatabaseService.instance.updateProject(existing['id'] as int, data);
                    }
                    if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                  },
                  child: const Text('Lưu công trình'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    name.dispose();
    address.dispose();
    aluminumType.dispose();
    accessory.dispose();
    areaM2.dispose();
    quantity.dispose();
    note.dispose();
    if (saved == true) _load();
  }

  Future<void> _addQuote([Map<String, Object?>? existing]) async {
    final code = TextEditingController(text: existing == null ? 'BG-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}' : (existing['code'] ?? '').toString());
    final amount = TextEditingController(text: existing == null ? '' : NumberFormat.decimalPattern('vi_VN').format(((existing['amount'] as num?) ?? 0).round()));
    final note = TextEditingController(text: (existing?['note'] ?? '').toString());
    int? customerId = existing?['customer_id'] as int? ?? defaultCustomerId();
    int? projectId = existing?['project_id'] as int?;
    String status = (existing?['status'] ?? 'Nháp').toString();
    String? filePath = (existing?['file_path'] ?? '').toString();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredProjects = projects.where((p) => customerId == null || p['customer_id'] == customerId).toList();
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(existing == null ? 'Tạo báo giá' : 'Chỉnh sửa báo giá', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  _CustomerPicker(
                    customers: customers,
                    value: customerId,
                    locked: widget.customerId != null,
                    onChanged: (v) => setModalState(() { customerId = v; projectId = null; }),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    initialValue: projectId,
                    decoration: const InputDecoration(labelText: 'Công trình'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Không gắn công trình')),
                      ...filteredProjects.map((p) => DropdownMenuItem<int?>(value: p['id'] as int?, child: Text((p['name'] ?? '').toString()))),
                    ],
                    onChanged: (v) => setModalState(() => projectId = v),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,controller: code, decoration: const InputDecoration(labelText: 'Mã báo giá')),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_VndInputFormatter()],
                    decoration: const InputDecoration(labelText: 'Giá trị báo giá', suffixText: 'VNĐ'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Trạng thái'),
                    items: const ['Nháp','Đã gửi','Đang thương lượng','Đã duyệt','Từ chối']
                        .map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                    onChanged: (v) => setModalState(() => status = v ?? status),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await AttachmentService.pickBusinessDocument();
                      if (selected != null) setModalState(() => filePath = selected);
                    },
                    icon: const Icon(Icons.attach_file),
                    label: Text(filePath == null ? 'Đính kèm file báo giá' : AttachmentService.fileName(filePath!)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Ghi chú')),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () async {
                      if (customerId == null || code.text.trim().isEmpty) return;
                      final data = <String, Object?>{
                        'customer_id': customerId,
                        'project_id': projectId,
                        'code': code.text.trim(),
                        'amount': double.tryParse(_moneyDigits(amount.text)) ?? 0,
                        'status': status,
                        'valid_until': '',
                        'file_path': filePath ?? '',
                        'note': note.text.trim(),
                        'created_at': existing?['created_at'] ?? DateTime.now().toIso8601String(),
                      };
                      if (existing == null) {
                        await DatabaseService.instance.addQuote(data);
                      } else {
                        await DatabaseService.instance.updateQuote(existing['id'] as int, data);
                      }
                      if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                    },
                    child: const Text('Lưu báo giá'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    code.dispose();
    amount.dispose();
    note.dispose();
    if (saved == true) _load();
  }

  Future<void> _addContract([Map<String, Object?>? existing]) async {
    final code = TextEditingController(text: existing == null ? 'HD-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}' : (existing['code'] ?? '').toString());
    final value = TextEditingController(text: existing == null ? '' : NumberFormat.decimalPattern('vi_VN').format(((existing['value'] as num?) ?? 0).round()));
    final profitPercent = TextEditingController(text: existing == null ? '' : ((existing['profit_percent'] as num?) ?? 0).toString());
    final companyCostPercent = TextEditingController(text: ((existing?['company_cost_percent'] as num?) ?? 8).toString());
    final commissionSharePercent = TextEditingController(text: ((existing?['commission_share_percent'] as num?) ?? 40).toString());
    final commissionReceived = TextEditingController(text: existing == null || ((existing['commission_received'] as num?) ?? 0) == 0 ? '' : NumberFormat.decimalPattern('vi_VN').format(((existing['commission_received'] as num?) ?? 0).round()));
    final warranty = TextEditingController(text: (existing?['warranty_months'] ?? 12).toString());
    final note = TextEditingController(text: (existing?['note'] ?? '').toString());
    int? customerId = existing?['customer_id'] as int? ?? defaultCustomerId();
    int? projectId = existing?['project_id'] as int?;
    String status = (existing?['status'] ?? 'Đã ký').toString();
    DateTime? installDate = DateTime.tryParse((existing?['install_date'] ?? '').toString());
    DateTime? commissionReceivedAt = DateTime.tryParse((existing?['commission_received_at'] ?? '').toString());
    String? filePath = (existing?['file_path'] ?? '').toString();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredProjects = projects.where((p) => customerId == null || p['customer_id'] == customerId).toList();
          final contractValue = double.tryParse(_moneyDigits(value.text)) ?? 0;
          final profit = double.tryParse(profitPercent.text.replaceAll(',', '.')) ?? 0;
          final companyCost = double.tryParse(companyCostPercent.text.replaceAll(',', '.')) ?? 0;
          final share = double.tryParse(commissionSharePercent.text.replaceAll(',', '.')) ?? 0;
          final commissionBasePercent = (profit - companyCost).clamp(0, 100).toDouble();
          final calculatedCommission = contractValue * commissionBasePercent / 100 * share / 100;
          final receivedCommission = double.tryParse(_moneyDigits(commissionReceived.text)) ?? 0;
          final remainingCommission = (calculatedCommission - receivedCommission).clamp(0, double.infinity).toDouble();
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(existing == null ? 'Tạo hợp đồng' : 'Chỉnh sửa hợp đồng', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  _CustomerPicker(
                    customers: customers,
                    value: customerId,
                    locked: widget.customerId != null,
                    onChanged: (v) => setModalState(() { customerId = v; projectId = null; }),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    initialValue: projectId,
                    decoration: const InputDecoration(labelText: 'Công trình'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Không gắn công trình')),
                      ...filteredProjects.map((p) => DropdownMenuItem<int?>(value: p['id'] as int?, child: Text((p['name'] ?? '').toString()))),
                    ],
                    onChanged: (v) => setModalState(() => projectId = v),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,controller: code, decoration: const InputDecoration(labelText: 'Mã hợp đồng')),
                  const SizedBox(height: 10),
                  TextField(
                    controller: value,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_VndInputFormatter()],
                    onChanged: (_) => setModalState(() {}),
                    decoration: const InputDecoration(labelText: 'Giá trị hợp đồng', suffixText: 'VNĐ'),
                  ),
                  const SizedBox(height: 14),
                  Text('Hoa hồng của tôi', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: profitPercent,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setModalState(() {}),
                          decoration: const InputDecoration(labelText: 'Lợi nhuận', suffixText: '%'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: companyCostPercent,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setModalState(() {}),
                          decoration: const InputDecoration(labelText: 'Chi phí CT', suffixText: '%'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: commissionSharePercent,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setModalState(() {}),
                          decoration: const InputDecoration(labelText: 'Tôi hưởng', suffixText: '%'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        _CommissionPreviewRow('Phần LN tính hoa hồng', money.format(contractValue * commissionBasePercent / 100) + 'đ'),
                        const SizedBox(height: 6),
                        _CommissionPreviewRow('Hoa hồng dự kiến', money.format(calculatedCommission) + 'đ', emphasize: true),
                        const SizedBox(height: 6),
                        _CommissionPreviewRow('Còn chưa nhận', money.format(remainingCommission) + 'đ'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: commissionReceived,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_VndInputFormatter()],
                    onChanged: (_) => setModalState(() {}),
                    decoration: const InputDecoration(labelText: 'Hoa hồng đã nhận', suffixText: 'VNĐ'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                        initialDate: commissionReceivedAt ?? DateTime.now(),
                      );
                      if (d != null) setModalState(() => commissionReceivedAt = d);
                    },
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    label: Text(commissionReceivedAt == null
                        ? 'Ngày nhận hoa hồng'
                        : 'Đã nhận: ${DateFormat('dd/MM/yyyy').format(commissionReceivedAt!)}'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: warranty,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Bảo hành (tháng)'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                        initialDate: installDate ?? DateTime.now(),
                      );
                      if (d != null) setModalState(() => installDate = d);
                    },
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text(installDate == null ? 'Ngày lắp đặt' : DateFormat('dd/MM/yyyy').format(installDate!)),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Trạng thái'),
                    items: const ['Đã ký','Đang thực hiện','Chờ nghiệm thu','Hoàn thành','Hủy']
                        .map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                    onChanged: (v) => setModalState(() => status = v ?? status),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await AttachmentService.pickBusinessDocument();
                      if (selected != null) setModalState(() => filePath = selected);
                    },
                    icon: const Icon(Icons.attach_file),
                    label: Text(filePath == null ? 'Đính kèm file hợp đồng' : AttachmentService.fileName(filePath!)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Ghi chú')),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () async {
                      if (customerId == null || code.text.trim().isEmpty) return;
                      final now = DateTime.now().toIso8601String();
                      final data = <String, Object?>{
                        'customer_id': customerId,
                        'project_id': projectId,
                        'code': code.text.trim(),
                        'value': double.tryParse(_moneyDigits(value.text)) ?? 0,
                        'profit_percent': double.tryParse(profitPercent.text.replaceAll(',', '.')) ?? 0,
                        'company_cost_percent': double.tryParse(companyCostPercent.text.replaceAll(',', '.')) ?? 8,
                        'commission_share_percent': double.tryParse(commissionSharePercent.text.replaceAll(',', '.')) ?? 40,
                        'commission_received': double.tryParse(_moneyDigits(commissionReceived.text)) ?? 0,
                        'commission_received_at': commissionReceivedAt?.toIso8601String() ?? '',
                        'signed_at': existing?['signed_at'] ?? now,
                        'install_date': installDate?.toIso8601String() ?? '',
                        'warranty_months': int.tryParse(warranty.text.trim()) ?? 12,
                        'status': status,
                        'file_path': filePath ?? '',
                        'note': note.text.trim(),
                        'created_at': existing?['created_at'] ?? now,
                      };
                      if (existing == null) {
                        await DatabaseService.instance.addContract(data);
                      } else {
                        await DatabaseService.instance.updateContract(existing['id'] as int, data);
                      }
                      if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                    },
                    child: const Text('Lưu hợp đồng'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    code.dispose();
    value.dispose();
    profitPercent.dispose();
    companyCostPercent.dispose();
    commissionSharePercent.dispose();
    commissionReceived.dispose();
    warranty.dispose();
    note.dispose();
    if (saved == true) _load();
  }

  Future<void> _addPayment([Map<String, Object?>? existing]) async {
    if (contracts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hãy tạo hợp đồng trước khi thu tiền.')));
      return;
    }
    final amount = TextEditingController(text: existing == null ? '' : NumberFormat.decimalPattern('vi_VN').format(((existing['amount'] as num?) ?? 0).round()));
    final note = TextEditingController(text: (existing?['note'] ?? '').toString());
    int? contractId = existing?['contract_id'] as int? ?? contracts.first['id'] as int?;
    String method = (existing?['method'] ?? 'Chuyển khoản').toString();
    DateTime paidAt = DateTime.tryParse((existing?['paid_at'] ?? '').toString()) ?? DateTime.now();

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
                Text(existing == null ? 'Ghi nhận thu tiền' : 'Chỉnh sửa khoản thu', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                DropdownButtonFormField<int?>(
                  initialValue: contractId,
                  decoration: const InputDecoration(labelText: 'Hợp đồng'),
                  items: contracts.map((c) {
                    final label = (c['code'] ?? '').toString() + ' • ' + customerName(c['customer_id']);
                    return DropdownMenuItem<int?>(value: c['id'] as int?, child: Text(label));
                  }).toList(),
                  onChanged: (v) => setModalState(() => contractId = v),
                ),
                const SizedBox(height: 10),
                TextField(controller: amount, keyboardType: TextInputType.number, inputFormatters: [_VndInputFormatter()], decoration: const InputDecoration(labelText: 'Số tiền thu', suffixText: 'VNĐ')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'Hình thức'),
                  items: const ['Chuyển khoản','Tiền mặt','Khác'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                  onChanged: (v) => setModalState(() => method = v ?? method),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      initialDate: paidAt,
                    );
                    if (d != null) {
                      setModalState(() => paidAt = DateTime(d.year, d.month, d.day, paidAt.hour, paidAt.minute));
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text('Ngày thu: ${DateFormat('dd/MM/yyyy').format(paidAt)}'),
                ),
                const SizedBox(height: 10),
                TextField(
                    textCapitalization: TextCapitalization.sentences,controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Ghi chú')),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () async {
                    if (contractId == null) return;
                    final contract = contracts.firstWhere((c) => c['id'] == contractId);
                    final data = <String, Object?>{
                      'contract_id': contractId,
                      'customer_id': contract['customer_id'],
                      'amount': double.tryParse(_moneyDigits(amount.text)) ?? 0,
                      'paid_at': paidAt.toIso8601String(),
                      'method': method,
                      'note': note.text.trim(),
                    };
                    if (existing == null) {
                      await DatabaseService.instance.addPayment(data);
                    } else {
                      await DatabaseService.instance.updatePayment(existing['id'] as int, data);
                    }
                    if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                  },
                  child: const Text('Lưu khoản thu'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    amount.dispose(); note.dispose();
    if (saved == true) _load();
  }

  Future<bool> _confirmDelete(String label) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Xóa $label?'),
            content: const Text('Dữ liệu đã xóa sẽ không thể hoàn tác.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
              FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa')),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteProject(Map<String, Object?> row) async {
    if (!await _confirmDelete('công trình')) return;
    try { await DatabaseService.instance.deleteProject(row['id'] as int); await _load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể xóa: $e'))); }
  }

  Future<void> _deleteQuote(Map<String, Object?> row) async {
    if (!await _confirmDelete('báo giá')) return;
    await DatabaseService.instance.deleteQuote(row['id'] as int); await _load();
  }

  Future<void> _deleteContract(Map<String, Object?> row) async {
    if (!await _confirmDelete('hợp đồng')) return;
    try { await DatabaseService.instance.deleteContract(row['id'] as int); await _load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể xóa: $e'))); }
  }

  Future<void> _deletePayment(Map<String, Object?> row) async {
    if (!await _confirmDelete('khoản thu')) return;
    await DatabaseService.instance.deletePayment(row['id'] as int); await _load();
  }

  void _addCurrent() {
    switch (tabController.index) {
      case 0: _addProject(); break;
      case 1: _addQuote(); break;
      case 2: _addContract(); break;
      default: _addPayment();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.customerName == null ? 'Nghiệp vụ' : 'Nghiệp vụ • ' + widget.customerName!;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: TabBar(
          controller: tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Công trình'),
            Tab(text: 'Báo giá'),
            Tab(text: 'Hợp đồng'),
            Tab(text: 'Thu tiền'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCurrent,
        icon: const Icon(Icons.add),
        label: const Text('Thêm'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: tabController,
              children: [
                _ProjectList(rows: projects, customerName: customerName, onRefresh: _load, onEdit: _addProject, onDelete: _deleteProject),
                _QuoteList(rows: quotes, customerName: customerName, projectName: projectName, money: money, onRefresh: _load, onEdit: _addQuote, onDelete: _deleteQuote),
                _ContractList(rows: contracts, customerName: customerName, projectName: projectName, payments: payments, money: money, onRefresh: _load, onEdit: _addContract, onDelete: _deleteContract),
                _PaymentList(rows: payments, customerName: customerName, contractCode: contractCode, money: money, onRefresh: _load, onEdit: _addPayment, onDelete: _deletePayment),
              ],
            ),
    );
  }
}

class _CommissionPreviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;
  const _CommissionPreviewRow(this.label, this.value, {this.emphasize = false});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
              fontSize: emphasize ? 17 : 14,
            ),
          ),
        ],
      );
}

class _CustomerPicker extends StatelessWidget {
  final List<Customer> customers;
  final int? value;
  final bool locked;
  final ValueChanged<int?> onChanged;
  const _CustomerPicker({required this.customers, required this.value, required this.locked, required this.onChanged});

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int?>(
        initialValue: value,
        decoration: const InputDecoration(labelText: 'Khách hàng'),
        items: customers.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))).toList(),
        onChanged: locked ? null : onChanged,
      );
}

class _ProjectList extends StatelessWidget {
  final List<Map<String, Object?>> rows;
  final String Function(Object?) customerName;
  final Future<void> Function(Map<String, Object?>) onEdit;
  final Future<void> Function(Map<String, Object?>) onDelete;
  final Future<void> Function() onRefresh;
  const _ProjectList({required this.rows, required this.customerName, required this.onRefresh, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) => _ListFrame(
        empty: 'Chưa có công trình.',
        rows: rows,
        onRefresh: onRefresh,
        builder: (row) => Card(
          elevation: 0,
          child: ListTile(
            onTap: () => onEdit(row),
            onLongPress: () => onDelete(row),
            leading: const CircleAvatar(child: Icon(Icons.home_work_outlined)),
            title: Text((row['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text([
              customerName(row['customer_id']),
              (row['category'] ?? '').toString(),
              if ((row['aluminum_brand'] ?? '').toString().isNotEmpty) (row['aluminum_brand'] ?? '').toString(),
              if ((row['aluminum_type'] ?? '').toString().isNotEmpty) (row['aluminum_type'] ?? '').toString(),
              if (((row['area_m2'] ?? 0) as num).toDouble() > 0) NumberFormat.decimalPattern('vi_VN').format(row['area_m2']) + ' m²',
              if (((row['quantity'] ?? 0) as num).toDouble() > 0) NumberFormat.decimalPattern('vi_VN').format(row['quantity']) + ' bộ',
              (row['status'] ?? '').toString(),
              if ((row['address'] ?? '').toString().isNotEmpty) (row['address'] ?? '').toString(),
            ].join(' • ')),
          ),
        ),
      );
}

class _QuoteList extends StatelessWidget {
  final List<Map<String, Object?>> rows;
  final String Function(Object?) customerName;
  final String Function(Object?) projectName;
  final NumberFormat money;
  final Future<void> Function(Map<String, Object?>) onEdit;
  final Future<void> Function(Map<String, Object?>) onDelete;
  final Future<void> Function() onRefresh;
  const _QuoteList({required this.rows, required this.customerName, required this.projectName, required this.money, required this.onRefresh, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) => _ListFrame(
        empty: 'Chưa có báo giá.',
        rows: rows,
        onRefresh: onRefresh,
        builder: (row) => Card(
          elevation: 0,
          child: ListTile(
            onTap: () => onEdit(row),
            onLongPress: () => onDelete(row),
            leading: const CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
            title: Text((row['code'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(customerName(row['customer_id']) + ' • ' + projectName(row['project_id']) + ' • ' + (row['status'] ?? '').toString()),
            trailing: Text(money.format(((row['amount'] ?? 0) as num).toDouble()) + 'đ', style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      );
}

class _ContractList extends StatelessWidget {
  final List<Map<String, Object?>> rows;
  final List<Map<String, Object?>> payments;
  final String Function(Object?) customerName;
  final String Function(Object?) projectName;
  final NumberFormat money;
  final Future<void> Function(Map<String, Object?>) onEdit;
  final Future<void> Function(Map<String, Object?>) onDelete;
  final Future<void> Function() onRefresh;
  const _ContractList({required this.rows, required this.customerName, required this.projectName, required this.payments, required this.money, required this.onRefresh, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) => _ListFrame(
        empty: 'Chưa có hợp đồng.',
        rows: rows,
        onRefresh: onRefresh,
        builder: (row) {
          final contractId = row['id'];
          final paid = payments.where((p) => p['contract_id'] == contractId).fold<double>(0, (sum, p) => sum + ((p['amount'] ?? 0) as num).toDouble());
          final value = ((row['value'] ?? 0) as num).toDouble();
          final debt = value - paid;
          final profitPercent = ((row['profit_percent'] ?? 0) as num).toDouble();
          final companyCostPercent = ((row['company_cost_percent'] ?? 8) as num).toDouble();
          final sharePercent = ((row['commission_share_percent'] ?? 40) as num).toDouble();
          final basePercent = (profitPercent - companyCostPercent).clamp(0, 100).toDouble();
          final commission = value * basePercent / 100 * sharePercent / 100;
          final commissionReceived = ((row['commission_received'] ?? 0) as num).toDouble();
          final commissionRemaining = (commission - commissionReceived).clamp(0, double.infinity).toDouble();
          return Card(
            elevation: 0,
            child: ListTile(
              onTap: () => onEdit(row),
            onLongPress: () => onDelete(row),
              leading: const CircleAvatar(child: Icon(Icons.handshake_outlined)),
              title: Text((row['code'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                customerName(row['customer_id']) + ' • ' + projectName(row['project_id']) +
                '\nĐã thu ' + money.format(paid) + 'đ • Còn ' + money.format(debt < 0 ? 0 : debt) + 'đ' +
                '\nHoa hồng ' + money.format(commission) + 'đ • Chưa nhận ' + money.format(commissionRemaining) + 'đ',
              ),
              isThreeLine: true,
              trailing: Text(money.format(value) + 'đ', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          );
        },
      );
}

class _PaymentList extends StatelessWidget {
  final List<Map<String, Object?>> rows;
  final String Function(Object?) customerName;
  final String Function(Object?) contractCode;
  final NumberFormat money;
  final Future<void> Function(Map<String, Object?>) onEdit;
  final Future<void> Function(Map<String, Object?>) onDelete;
  final Future<void> Function() onRefresh;
  const _PaymentList({required this.rows, required this.customerName, required this.contractCode, required this.money, required this.onRefresh, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) => _ListFrame(
        empty: 'Chưa ghi nhận khoản thu.',
        rows: rows,
        onRefresh: onRefresh,
        builder: (row) {
          final dt = DateTime.tryParse((row['paid_at'] ?? '').toString());
          return Card(
            elevation: 0,
            child: ListTile(
              onTap: () => onEdit(row),
            onLongPress: () => onDelete(row),
              leading: const CircleAvatar(child: Icon(Icons.payments_outlined)),
              title: Text(money.format(((row['amount'] ?? 0) as num).toDouble()) + 'đ', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(customerName(row['customer_id']) + ' • ' + contractCode(row['contract_id']) + ' • ' + (row['method'] ?? '').toString()),
              trailing: Text(dt == null ? '' : DateFormat('dd/MM').format(dt)),
            ),
          );
        },
      );
}

class _ListFrame extends StatelessWidget {
  final String empty;
  final List<Map<String, Object?>> rows;
  final Widget Function(Map<String, Object?>) builder;
  final Future<void> Function() onRefresh;
  const _ListFrame({required this.empty, required this.rows, required this.builder, required this.onRefresh});

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: onRefresh,
        child: rows.isEmpty
            ? ListView(children: [const SizedBox(height: 130), Center(child: Text(empty))])
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: rows.length,
                itemBuilder: (_, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: builder(rows[index]),
                ),
              ),
      );
}
