import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'database_service.dart';

class ExportService {
  static Future<String> exportAll() async {
    final database = await DatabaseService.instance.db;
    final customers = await database.query('customers', orderBy: 'updated_at DESC');
    final activities = await database.query('activities', orderBy: 'created_at DESC');
    final tasks = await database.query('tasks', orderBy: 'due_date ASC');
    final appointments = await database.query('appointments', orderBy: 'starts_at ASC');
    final projects = await database.query('projects', orderBy: 'updated_at DESC');
    final quotes = await database.query('quotes', orderBy: 'created_at DESC');
    final contracts = await database.query('contracts', orderBy: 'created_at DESC');
    final payments = await database.query('payments', orderBy: 'paid_at DESC');

    final excel = Excel.createExcel();
    final customersSheet = excel['KhachHang'];
    final activitiesSheet = excel['Timeline'];
    final tasksSheet = excel['CongViec'];
    final appointmentsSheet = excel['LichHen'];
    final projectsSheet = excel['CongTrinh'];
    final quotesSheet = excel['BaoGia'];
    final contractsSheet = excel['HopDong'];
    final commissionSheet = excel['HoaHong'];
    final paymentsSheet = excel['ThuTien'];

    customersSheet.appendRow([
      TextCellValue('ID'), TextCellValue('Họ tên'), TextCellValue('Điện thoại'),
      TextCellValue('Zalo'), TextCellValue('Địa chỉ'), TextCellValue('Nguồn'),
      TextCellValue('Trạng thái'), TextCellValue('Nhu cầu'), TextCellValue('Ngân sách'),
      TextCellValue('Ghi chú'), TextCellValue('Ngày tạo'),
    ]);
    for (final row in customers) {
      customersSheet.appendRow([
        TextCellValue(row['id'].toString()),
        TextCellValue((row['name'] ?? '').toString()),
        TextCellValue((row['phone'] ?? '').toString()),
        TextCellValue((row['zalo'] ?? '').toString()),
        TextCellValue((row['address'] ?? '').toString()),
        TextCellValue((row['source'] ?? '').toString()),
        TextCellValue((row['stage'] ?? '').toString()),
        TextCellValue((row['need'] ?? '').toString()),
        TextCellValue((row['budget'] ?? '').toString()),
        TextCellValue((row['note'] ?? '').toString()),
        TextCellValue((row['created_at'] ?? '').toString()),
      ]);
    }

    activitiesSheet.appendRow([
      TextCellValue('ID'), TextCellValue('Customer ID'), TextCellValue('Loại'),
      TextCellValue('Tiêu đề'), TextCellValue('Nội dung'), TextCellValue('Thời gian'),
    ]);
    for (final row in activities) {
      activitiesSheet.appendRow([
        TextCellValue(row['id'].toString()),
        TextCellValue(row['customer_id'].toString()),
        TextCellValue((row['type'] ?? '').toString()),
        TextCellValue((row['title'] ?? '').toString()),
        TextCellValue((row['content'] ?? '').toString()),
        TextCellValue((row['created_at'] ?? '').toString()),
      ]);
    }

    tasksSheet.appendRow([
      TextCellValue('ID'), TextCellValue('Customer ID'), TextCellValue('Công việc'),
      TextCellValue('Deadline'), TextCellValue('Ưu tiên'), TextCellValue('Hoàn thành'),
      TextCellValue('Ghi chú'),
    ]);
    for (final row in tasks) {
      tasksSheet.appendRow([
        TextCellValue(row['id'].toString()),
        TextCellValue(row['customer_id'].toString()),
        TextCellValue((row['title'] ?? '').toString()),
        TextCellValue((row['due_date'] ?? '').toString()),
        TextCellValue((row['priority'] ?? '').toString()),
        TextCellValue(row['completed'].toString()),
        TextCellValue((row['note'] ?? '').toString()),
      ]);
    }

    appointmentsSheet.appendRow([
      TextCellValue('ID'), TextCellValue('Customer ID'), TextCellValue('Lịch hẹn'),
      TextCellValue('Bắt đầu'), TextCellValue('Phút'), TextCellValue('Địa điểm'),
      TextCellValue('Ghi chú'),
    ]);
    for (final row in appointments) {
      appointmentsSheet.appendRow([
        TextCellValue(row['id'].toString()),
        TextCellValue(row['customer_id'].toString()),
        TextCellValue((row['title'] ?? '').toString()),
        TextCellValue((row['starts_at'] ?? '').toString()),
        TextCellValue((row['duration_minutes'] ?? '').toString()),
        TextCellValue((row['location'] ?? '').toString()),
        TextCellValue((row['note'] ?? '').toString()),
      ]);
    }


    projectsSheet.appendRow([
      TextCellValue('ID'), TextCellValue('Customer ID'), TextCellValue('Tên công trình'),
      TextCellValue('Địa chỉ'), TextCellValue('Hạng mục'), TextCellValue('Hãng nhôm'),
      TextCellValue('Loại nhôm'), TextCellValue('Hệ nhôm'), TextCellValue('Phụ kiện'), TextCellValue('Kích thước'),
      TextCellValue('Số lượng'), TextCellValue('Ngày sản xuất'), TextCellValue('Ngày lắp đặt'),
      TextCellValue('Hình ảnh'), TextCellValue('Tiến độ'), TextCellValue('Ghi chú'),
    ]);
    for (final row in projects) {
      projectsSheet.appendRow([
        TextCellValue(row['id'].toString()),
        TextCellValue(row['customer_id'].toString()),
        TextCellValue((row['name'] ?? '').toString()),
        TextCellValue((row['address'] ?? '').toString()),
        TextCellValue((row['category'] ?? '').toString()),
        TextCellValue((row['aluminum_brand'] ?? '').toString()),
        TextCellValue((row['aluminum_type'] ?? '').toString()),
        TextCellValue((row['aluminum_system'] ?? '').toString()),
        TextCellValue((row['accessory'] ?? '').toString()),
        TextCellValue((row['dimensions'] ?? '').toString()),
        TextCellValue((row['quantity'] ?? '').toString()),
        TextCellValue((row['production_date'] ?? '').toString()),
        TextCellValue((row['install_date'] ?? '').toString()),
        TextCellValue((row['photo_paths'] ?? '').toString()),
        TextCellValue((row['status'] ?? '').toString()),
        TextCellValue((row['note'] ?? '').toString()),
      ]);
    }

    quotesSheet.appendRow([
      TextCellValue('ID'), TextCellValue('Customer ID'), TextCellValue('Project ID'),
      TextCellValue('Mã báo giá'), TextCellValue('Giá trị'), TextCellValue('Trạng thái'),
      TextCellValue('File báo giá'), TextCellValue('Ghi chú'), TextCellValue('Ngày tạo'),
    ]);
    for (final row in quotes) {
      quotesSheet.appendRow([
        TextCellValue(row['id'].toString()),
        TextCellValue(row['customer_id'].toString()),
        TextCellValue(row['project_id'].toString()),
        TextCellValue((row['code'] ?? '').toString()),
        TextCellValue((row['amount'] ?? '').toString()),
        TextCellValue((row['status'] ?? '').toString()),
        TextCellValue((row['file_path'] ?? '').toString()),
        TextCellValue((row['note'] ?? '').toString()),
        TextCellValue((row['created_at'] ?? '').toString()),
      ]);
    }

    contractsSheet.appendRow([
      TextCellValue('ID'), TextCellValue('Customer ID'), TextCellValue('Project ID'),
      TextCellValue('Mã hợp đồng'), TextCellValue('Giá trị'), TextCellValue('Ngày ký'),
      TextCellValue('Ngày lắp đặt'), TextCellValue('Bảo hành tháng'), TextCellValue('Trạng thái'),
      TextCellValue('Lợi nhuận %'), TextCellValue('Chi phí CT %'), TextCellValue('Tỷ lệ hưởng %'),
      TextCellValue('Hoa hồng đã nhận'), TextCellValue('Ngày nhận hoa hồng'),
      TextCellValue('File hợp đồng'), TextCellValue('Ghi chú'),
    ]);
    for (final row in contracts) {
      contractsSheet.appendRow([
        TextCellValue(row['id'].toString()),
        TextCellValue(row['customer_id'].toString()),
        TextCellValue(row['project_id'].toString()),
        TextCellValue((row['code'] ?? '').toString()),
        TextCellValue((row['value'] ?? '').toString()),
        TextCellValue((row['signed_at'] ?? '').toString()),
        TextCellValue((row['install_date'] ?? '').toString()),
        TextCellValue((row['warranty_months'] ?? '').toString()),
        TextCellValue((row['status'] ?? '').toString()),
        TextCellValue((row['profit_percent'] ?? 0).toString()),
        TextCellValue((row['company_cost_percent'] ?? 8).toString()),
        TextCellValue((row['commission_share_percent'] ?? 40).toString()),
        TextCellValue((row['commission_received'] ?? 0).toString()),
        TextCellValue((row['commission_received_at'] ?? '').toString()),
        TextCellValue((row['file_path'] ?? '').toString()),
        TextCellValue((row['note'] ?? '').toString()),
      ]);
    }

    commissionSheet.appendRow([
      TextCellValue('Mã hợp đồng'), TextCellValue('Khách hàng'), TextCellValue('Giá trị HĐ'),
      TextCellValue('Lợi nhuận %'), TextCellValue('Chi phí CT %'), TextCellValue('LN tính hoa hồng'),
      TextCellValue('Tỷ lệ hưởng %'), TextCellValue('Hoa hồng dự kiến'), TextCellValue('Đã nhận'),
      TextCellValue('Còn chưa nhận'), TextCellValue('Ngày nhận'), TextCellValue('Ngày ký'),
    ]);
    for (final row in contracts) {
      final value = ((row['value'] ?? 0) as num).toDouble();
      final profitPercent = ((row['profit_percent'] ?? 0) as num).toDouble();
      final companyPercent = ((row['company_cost_percent'] ?? 8) as num).toDouble();
      final sharePercent = ((row['commission_share_percent'] ?? 40) as num).toDouble();
      final basePercent = (profitPercent - companyPercent).clamp(0, 100).toDouble();
      final commissionBase = value * basePercent / 100;
      final commission = commissionBase * sharePercent / 100;
      final received = ((row['commission_received'] ?? 0) as num).toDouble();
      final remaining = (commission - received).clamp(0, double.infinity).toDouble();
      final customer = customers.where((c) => c['id'] == row['customer_id']).firstOrNull;
      commissionSheet.appendRow([
        TextCellValue((row['code'] ?? '').toString()),
        TextCellValue((customer?['name'] ?? '').toString()),
        DoubleCellValue(value),
        DoubleCellValue(profitPercent),
        DoubleCellValue(companyPercent),
        DoubleCellValue(commissionBase),
        DoubleCellValue(sharePercent),
        DoubleCellValue(commission),
        DoubleCellValue(received),
        DoubleCellValue(remaining),
        TextCellValue((row['commission_received_at'] ?? '').toString()),
        TextCellValue((row['signed_at'] ?? '').toString()),
      ]);
    }

    paymentsSheet.appendRow([
      TextCellValue('ID'), TextCellValue('Contract ID'), TextCellValue('Customer ID'),
      TextCellValue('Số tiền'), TextCellValue('Ngày thu'), TextCellValue('Hình thức'),
      TextCellValue('Ghi chú'),
    ]);
    for (final row in payments) {
      paymentsSheet.appendRow([
        TextCellValue(row['id'].toString()),
        TextCellValue(row['contract_id'].toString()),
        TextCellValue(row['customer_id'].toString()),
        TextCellValue((row['amount'] ?? '').toString()),
        TextCellValue((row['paid_at'] ?? '').toString()),
        TextCellValue((row['method'] ?? '').toString()),
        TextCellValue((row['note'] ?? '').toString()),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null) throw StateError('Không tạo được file Excel.');

    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final path = dir.path + '/MPWindows_CRM_' + stamp + '.xlsx';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  static Future<ShareResult> exportAndShare() async {
    final path = await exportAll();
    return SharePlus.instance.share(
      ShareParams(
        title: 'Xuất dữ liệu MPWindows CRM',
        text: 'File dữ liệu MPWindows CRM',
        files: [XFile(path)],
        fileNameOverrides: ['MPWindows_CRM.xlsx'],
      ),
    );
  }
}
