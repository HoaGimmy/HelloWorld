import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/google_drive_backup_service.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  bool busy = false;
  Map<String, String?> status = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await GoogleDriveBackupService.instance.status();
    if (mounted) setState(() => status = value);
  }

  String _formatBackup(String key) {
    final date = DateTime.tryParse(status[key] ?? '');
    return date == null
        ? 'Chưa có bản sao lưu'
        : DateFormat('HH:mm · dd/MM/yyyy').format(date.toLocal());
  }

  String _lastBackup() => _formatBackup('lastAt');

  Future<void> _perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thực hiện được: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _backup() => _perform(() async {
        await GoogleDriveBackupService.instance.backupBothNow();
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã sao lưu JSON và đồng bộ Google Sheets thành công.')),
          );
        }
      });

  Future<void> _restore() => _perform(() async {
        final file = await GoogleDriveBackupService.instance.chooseBackupFile();
        if (file == null || !mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Khôi phục dữ liệu?'),
            content: const Text(
              'Dữ liệu hiện tại trên máy sẽ được thay bằng dữ liệu trong bản sao lưu. '
              'Nên tạo một bản sao lưu mới trước khi khôi phục.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Khôi phục'),
              ),
            ],
          ),
        );
        if (ok != true) return;
        await GoogleDriveBackupService.instance.restoreFromFile(file);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã khôi phục dữ liệu thành công.')),
          );
        }
      });

  Future<void> _mergeImport() => _perform(() async {
        final file = await GoogleDriveBackupService.instance.chooseBackupFile();
        if (file == null || !mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Nhập & gộp dữ liệu?'),
            content: const Text(
              'Dữ liệu trong file sẽ được thêm vào CRM hiện tại, không xóa dữ liệu đang có. '
              'Các liên kết khách hàng, công trình, hợp đồng và thanh toán sẽ được tự ánh xạ sang ID mới. '
              'Cài đặt Google/sao lưu trên máy sẽ được giữ nguyên.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Nhập & gộp')),
            ],
          ),
        );
        if (ok != true) return;
        final result = await GoogleDriveBackupService.instance.mergeFromFile(file);
        if (mounted) {
          final customers = result['customers'] ?? 0;
          final projects = result['projects'] ?? 0;
          final contracts = result['contracts'] ?? 0;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã gộp thành công: $customers khách · $projects công trình · $contracts hợp đồng.')),
          );
        }
      });

  @override
  Widget build(BuildContext context) {
    final email = status['email'];
    return Scaffold(
      appBar: AppBar(title: const Text('Sao lưu & dữ liệu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.cloud_outlined),
                    title: Text('Google Drive'),
                    subtitle: Text('Thư mục: MPWindows CRM Backup'),
                  ),
                  Text(email ?? 'Chưa kết nối tài khoản Google'),
                  const SizedBox(height: 4),
                  Text('JSON gần nhất: ${_lastBackup()}'),
                  const SizedBox(height: 4),
                  Text('Google Sheets gần nhất: ${_formatBackup('sheetsLastAt')}'),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tự động sao lưu'),
                    subtitle: const Text('Tự động sao lưu JSON + Google Sheets 1 lần/ngày'),
                    value: status['autoEnabled'] == '1',
                    onChanged: busy ? null : (value) => _perform(() async {
                      await GoogleDriveBackupService.instance.setAutoBackupEnabled(value);
                      await _load();
                      if (value) {
                        await GoogleDriveBackupService.instance.autoBackupIfDue();
                        await _load();
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value
                                  ? 'Đã bật tự động sao lưu 2 lớp: JSON + Google Sheets.'
                                  : 'Đã tắt tự động sao lưu.',
                            ),
                          ),
                        );
                      }
                    }),
                  ),
                  Text(
                    status['autoEnabled'] == '1'
                        ? 'Trạng thái: Đang bật · Lần gần nhất: ${_lastBackup()}'
                        : 'Trạng thái: Đang tắt',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => _perform(() async {
                                  final account = await GoogleDriveBackupService.instance.connect();
                                  await _load();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Đã kết nối Google: ${account.email}')),
                                    );
                                  }
                                }),
                        icon: const Icon(Icons.link),
                        label: const Text('Kết nối Google Drive'),
                      ),
                      FilledButton.icon(
                        onPressed: busy ? null : _backup,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Sao lưu 2 lớp ngay'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.ios_share_outlined),
                  title: const Text('Xuất bản sao lưu'),
                  subtitle: const Text('Lưu file JSON qua Files, Drive hoặc iCloud'),
                  onTap: busy
                      ? null
                      : () => _perform(
                            () => GoogleDriveBackupService.instance.exportBackupFile(),
                          ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.merge_type),
                  title: const Text('Nhập dữ liệu & gộp'),
                  subtitle: const Text('Thêm dữ liệu JSON vào CRM hiện tại, không xóa dữ liệu cũ'),
                  onTap: busy ? null : _mergeImport,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: const Text('Khôi phục từ file'),
                  subtitle: const Text('Thay thế toàn bộ dữ liệu hiện tại bằng bản sao lưu'),
                  onTap: busy ? null : _restore,
                ),
              ],
            ),
          ),
          if (busy) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}
