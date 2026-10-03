import 'dart:io';

import 'package:cross_file/cross_file.dart';
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

    final excel = Excel.createExcel();
    final customersSheet = excel['KhachHang'];
    final activitiesSheet = excel['Timeline'];
    final tasksSheet = excel['CongViec'];
    final appointmentsSheet = excel['LichHen'];

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
        files: [XFile.fileSystem(path: path)],
        fileNameOverrides: ['MPWindows_CRM.xlsx'],
      ),
    );
  }
}
