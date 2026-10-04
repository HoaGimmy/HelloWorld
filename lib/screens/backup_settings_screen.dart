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

  String _lastBackup() {
    final date = DateTime.tryParse(status['lastAt'] ?? '');
    return date == null
        ? 'Chưa có bản sao lưu'
        : DateFormat('HH:mm · dd/MM/yyyy').format(date.toLocal());
  }

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
        final result = await GoogleDriveBackupService.instance.backupToDrive();
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã sao lưu: ${result.fileName}')),
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
                  Text('Lần sao lưu: ${_lastBackup()}'),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tự động sao lưu'),
                    subtitle: const Text('1 lần/ngày khi mở hoặc quay lại ứng dụng'),
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
                                  ? 'Đã bật tự động sao lưu · 1 lần/ngày khi mở hoặc quay lại ứng dụng.'
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
                        label: const Text('Sao lưu ngay'),
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
                  leading: const Icon(Icons.restore),
                  title: const Text('Khôi phục từ file'),
                  subtitle: const Text('Phục hồi toàn bộ dữ liệu CRM'),
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
