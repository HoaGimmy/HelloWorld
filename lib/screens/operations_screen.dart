import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/customer.dart';
import '../services/database_service.dart';

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

  Future<void> _addProject() async {
    final name = TextEditingController();
    final address = TextEditingController();
    final aluminum = TextEditingController();
    final accessory = TextEditingController();
    final note = TextEditingController();
    int? customerId = defaultCustomerId();
    String category = 'Cửa nhôm kính';
    String status = 'Chuẩn bị';

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
                const Text('Thêm công trình', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                _CustomerPicker(customers: customers, value: customerId, locked: widget.customerId != null, onChanged: (v) => setModalState(() => customerId = v)),
                const SizedBox(height: 10),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Tên công trình *')),
                const SizedBox(height: 10),
                TextField(controller: address, decoration: const InputDecoration(labelText: 'Địa chỉ công trình')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Hạng mục'),
                  items: const ['Cửa nhôm kính','Vách kính','Mặt dựng','Lam nhôm','Lan can kính','Khác'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                  onChanged: (v) => setModalState(() => category = v ?? category),
                ),
                const SizedBox(height: 10),
                TextField(controller: aluminum, decoration: const InputDecoration(labelText: 'Hệ/loại nhôm')),
                const SizedBox(height: 10),
                TextField(controller: accessory, decoration: const InputDecoration(labelText: 'Phụ kiện')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Tiến độ'),
                  items: const ['Chuẩn bị','Đo đạc','Sản xuất','Lắp đặt','Nghiệm thu','Hoàn thành'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                  onChanged: (v) => setModalState(() => status = v ?? status),
                ),
                const SizedBox(height: 10),
                TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Ghi chú')),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () async {
                    if (customerId == null || name.text.trim().isEmpty) return;
                    final now = DateTime.now().toIso8601String();
                    await DatabaseService.instance.addProject({
                      'customer_id': customerId,
                      'name': name.text.trim(),
                      'address': address.text.trim(),
                      'category': category,
                      'aluminum_system': aluminum.text.trim(),
                      'accessory': accessory.text.trim(),
                      'status': status,
                      'start_date': now,
                      'install_date': '',
                      'note': note.text.trim(),
                      'created_at': now,
                      'updated_at': now,
                    });
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

    name.dispose(); address.dispose(); aluminum.dispose(); accessory.dispose(); note.dispose();
    if (saved == true) _load();
  }

  Future<void> _addQuote() async {
    final code = TextEditingController(text: 'BG-' + DateFormat('yyyyMMdd-HHmm').format(DateTime.now()));
    final amount = TextEditingController();
    final note = TextEditingController();
    int? customerId = defaultCustomerId();
    int? projectId;
    String status = 'Nháp';

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
                  const Text('Tạo báo giá', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  _CustomerPicker(customers: customers, value: customerId, locked: widget.customerId != null, onChanged: (v) => setModalState(() { customerId = v; projectId = null; })),
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
                  TextField(controller: code, decoration: const InputDecoration(labelText: 'Mã báo giá')),
                  const SizedBox(height: 10),
                  TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Giá trị báo giá')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Trạng thái'),
                    items: const ['Nháp','Đã gửi','Đang thương lượng','Đã duyệt','Từ chối'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                    onChanged: (v) => setModalState(() => status = v ?? status),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Ghi chú')),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () async {
                      if (customerId == null || code.text.trim().isEmpty) return;
                      await DatabaseService.instance.addQuote({
                        'customer_id': customerId,
                        'project_id': projectId,
                        'code': code.text.trim(),
                        'amount': double.tryParse(amount.text.replaceAll(',', '').trim()) ?? 0,
                        'status': status,
                        'valid_until': '',
                        'note': note.text.trim(),
                        'created_at': DateTime.now().toIso8601String(),
                      });
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

    code.dispose(); amount.dispose(); note.dispose();
    if (saved == true) _load();
  }

  Future<void> _addContract() async {
    final code = TextEditingController(text: 'HD-' + DateFormat('yyyyMMdd-HHmm').format(DateTime.now()));
    final value = TextEditingController();
    final warranty = TextEditingController(text: '12');
    final note = TextEditingController();
    int? customerId = defaultCustomerId();
    int? projectId;
    String status = 'Đã ký';

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
                  const Text('Tạo hợp đồng', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  _CustomerPicker(customers: customers, value: customerId, locked: widget.customerId != null, onChanged: (v) => setModalState(() { customerId = v; projectId = null; })),
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
                  TextField(controller: code, decoration: const InputDecoration(labelText: 'Mã hợp đồng')),
                  const SizedBox(height: 10),
                  TextField(controller: value, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Giá trị hợp đồng')),
                  const SizedBox(height: 10),
                  TextField(controller: warranty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bảo hành (tháng)')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Trạng thái'),
                    items: const ['Đã ký','Đang thực hiện','Chờ nghiệm thu','Hoàn thành','Hủy'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                    onChanged: (v) => setModalState(() => status = v ?? status),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Ghi chú')),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () async {
                      if (customerId == null || code.text.trim().isEmpty) return;
                      final now = DateTime.now().toIso8601String();
                      await DatabaseService.instance.addContract({
                        'customer_id': customerId,
                        'project_id': projectId,
                        'code': code.text.trim(),
                        'value': double.tryParse(value.text.replaceAll(',', '').trim()) ?? 0,
                        'signed_at': now,
                        'install_date': '',
                        'warranty_months': int.tryParse(warranty.text.trim()) ?? 12,
                        'status': status,
                        'note': note.text.trim(),
                        'created_at': now,
                      });
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

    code.dispose(); value.dispose(); warranty.dispose(); note.dispose();
    if (saved == true) _load();
  }

  Future<void> _addPayment() async {
    if (contracts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hãy tạo hợp đồng trước khi thu tiền.')));
      return;
    }
    final amount = TextEditingController();
    final note = TextEditingController();
    int? contractId = contracts.first['id'] as int?;
    String method = 'Chuyển khoản';

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
                const Text('Ghi nhận thu tiền', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
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
                TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Số tiền thu')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'Hình thức'),
                  items: const ['Chuyển khoản','Tiền mặt','Khác'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                  onChanged: (v) => setModalState(() => method = v ?? method),
                ),
                const SizedBox(height: 10),
                TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Ghi chú')),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () async {
                    if (contractId == null) return;
                    final contract = contracts.firstWhere((c) => c['id'] == contractId);
                    await DatabaseService.instance.addPayment({
                      'contract_id': contractId,
                      'customer_id': contract['customer_id'],
                      'amount': double.tryParse(amount.text.replaceAll(',', '').trim()) ?? 0,
                      'paid_at': DateTime.now().toIso8601String(),
                      'method': method,
                      'note': note.text.trim(),
                    });
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
                _ProjectList(rows: projects, customerName: customerName),
                _QuoteList(rows: quotes, customerName: customerName, projectName: projectName, money: money),
                _ContractList(rows: contracts, customerName: customerName, projectName: projectName, payments: payments, money: money),
                _PaymentList(rows: payments, customerName: customerName, contractCode: contractCode, money: money),
              ],
            ),
    );
  }
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
  const _ProjectList({required this.rows, required this.customerName});

  @override
  Widget build(BuildContext context) => _ListFrame(
        empty: 'Chưa có công trình.',
        rows: rows,
        builder: (row) => Card(
          elevation: 0,
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.home_work_outlined)),
            title: Text((row['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text([
              customerName(row['customer_id']),
              (row['category'] ?? '').toString(),
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
  const _QuoteList({required this.rows, required this.customerName, required this.projectName, required this.money});

  @override
  Widget build(BuildContext context) => _ListFrame(
        empty: 'Chưa có báo giá.',
        rows: rows,
        builder: (row) => Card(
          elevation: 0,
          child: ListTile(
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
  const _ContractList({required this.rows, required this.customerName, required this.projectName, required this.payments, required this.money});

  @override
  Widget build(BuildContext context) => _ListFrame(
        empty: 'Chưa có hợp đồng.',
        rows: rows,
        builder: (row) {
          final contractId = row['id'];
          final paid = payments.where((p) => p['contract_id'] == contractId).fold<double>(0, (sum, p) => sum + ((p['amount'] ?? 0) as num).toDouble());
          final value = ((row['value'] ?? 0) as num).toDouble();
          final debt = value - paid;
          return Card(
            elevation: 0,
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.handshake_outlined)),
              title: Text((row['code'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(customerName(row['customer_id']) + ' • ' + projectName(row['project_id']) + '\nĐã thu ' + money.format(paid) + 'đ • Còn ' + money.format(debt < 0 ? 0 : debt) + 'đ'),
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
  const _PaymentList({required this.rows, required this.customerName, required this.contractCode, required this.money});

  @override
  Widget build(BuildContext context) => _ListFrame(
        empty: 'Chưa ghi nhận khoản thu.',
        rows: rows,
        builder: (row) {
          final dt = DateTime.tryParse((row['paid_at'] ?? '').toString());
          return Card(
            elevation: 0,
            child: ListTile(
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
  const _ListFrame({required this.empty, required this.rows, required this.builder});

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: () async {},
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
