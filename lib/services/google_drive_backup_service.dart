import 'dart:convert';
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'database_service.dart';

class BackupResult {
  final String fileName;
  final DateTime createdAt;
  final int customerCount;
  final int projectCount;

  const BackupResult({
    required this.fileName,
    required this.createdAt,
    required this.customerCount,
    required this.projectCount,
  });
}

class GoogleDriveBackupService {
  GoogleDriveBackupService._();

  static final instance = GoogleDriveBackupService._();
  static const _scope = drive.DriveApi.driveFileScope;
  static const _folderName = 'MPWindows CRM Backup';

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: [_scope]);

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<GoogleSignInAccount> connect() async {
    try {
      final existing = await _googleSignIn.signInSilently();
      final account = existing ?? await _googleSignIn.signIn();
      if (account == null) {
        throw StateError('Đăng nhập Google đã bị hủy.');
      }
      await DatabaseService.instance.setSetting('drive_backup_email', account.email);
      return account;
    } catch (error) {
      throw StateError('Google Sign-In lỗi: $error');
    }
  }

  Future<void> disconnect() => _googleSignIn.disconnect();

  Future<bool> get autoBackupEnabled async =>
      (await DatabaseService.instance.getSetting('drive_auto_backup_enabled')) == '1';

  Future<void> setAutoBackupEnabled(bool enabled) async {
    await DatabaseService.instance.setSetting(
      'drive_auto_backup_enabled',
      enabled ? '1' : '0',
    );
  }

  Future<bool> autoBackupIfDue() async {
    if (!await autoBackupEnabled) return false;

    final email = await DatabaseService.instance.getSetting('drive_backup_email');
    if (email == null || email.isEmpty) return false;

    final lastValue =
        await DatabaseService.instance.getSetting('drive_backup_last_at');
    final last = DateTime.tryParse(lastValue ?? '')?.toLocal();
    final now = DateTime.now();
    if (last != null &&
        last.year == now.year &&
        last.month == now.month &&
        last.day == now.day) {
      return false;
    }

    final existing = await _googleSignIn.signInSilently();
    if (existing == null) return false;
    await backupToDrive();
    return true;
  }

  Future<File> createLocalBackup() async {
    final snapshot = await DatabaseService.instance.exportBackupSnapshot();
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${dir.path}/backups');
    await backupDir.create(recursive: true);
    final stamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final file = File('${backupDir.path}/MPWindows_CRM_Backup_$stamp.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshot),
      flush: true,
    );
    return file;
  }

  Future<BackupResult> backupToDrive() async {
    final account = await connect();
    if (account == null) {
      throw StateError('Bạn chưa kết nối tài khoản Google Drive.');
    }

    final client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      throw StateError('Không thể xác thực Google Drive.');
    }

    try {
      final api = drive.DriveApi(client);
      final folderId = await _findOrCreateFolder(api);
      final file = await createLocalBackup();
      final created = await api.files.create(
        drive.File()
          ..name = file.uri.pathSegments.last
          ..parents = [folderId]
          ..description = 'Bản sao lưu dữ liệu MPWindows CRM',
        uploadMedia: drive.Media(file.openRead(), await file.length()),
        $fields: 'id,name,createdTime',
      );

      final counts = await DatabaseService.instance.getBackupCounts();
      final now = created.createdTime ?? DateTime.now();
      await DatabaseService.instance.setSetting(
        'drive_backup_last_at',
        now.toIso8601String(),
      );
      await DatabaseService.instance.setSetting(
        'drive_backup_last_file',
        created.name ?? file.uri.pathSegments.last,
      );
      await DatabaseService.instance.setSetting(
        'drive_backup_email',
        account.email,
      );

      return BackupResult(
        fileName: created.name ?? file.uri.pathSegments.last,
        createdAt: now,
        customerCount: counts['customers'] ?? 0,
        projectCount: counts['projects'] ?? 0,
      );
    } finally {
      client.close();
    }
  }

  Future<String> _findOrCreateFolder(drive.DriveApi api) async {
    final escaped = _folderName.replaceAll("'", r"\'");
    final list = await api.files.list(
      q: "name = '$escaped' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id,name)',
      pageSize: 10,
    );
    drive.File? existing;
    for (final item in list.files ?? const <drive.File>[]) {
      if (item.id != null) {
        existing = item;
        break;
      }
    }
    if (existing?.id != null) return existing!.id!;

    final created = await api.files.create(
      drive.File()
        ..name = _folderName
        ..mimeType = 'application/vnd.google-apps.folder',
      $fields: 'id',
    );
    if (created.id == null) {
      throw StateError('Không thể tạo thư mục sao lưu trên Google Drive.');
    }
    return created.id!;
  }

  Future<void> exportBackupFile() async {
    final file = await createLocalBackup();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'MPWindows CRM Backup',
        text: 'Bản sao lưu toàn bộ dữ liệu MPWindows CRM.',
      ),
    );
  }

  Future<File?> chooseBackupFile() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = picked.isEmpty ? null : picked.single.path;
    return path == null ? null : File(path);
  }

  Future<void> restoreFromFile(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Bản sao lưu không hợp lệ.');
    }
    await DatabaseService.instance.restoreBackupSnapshot(decoded);
  }

  Future<Map<String, String?>> status() async => {
        'lastAt': await DatabaseService.instance.getSetting('drive_backup_last_at'),
        'lastFile': await DatabaseService.instance.getSetting('drive_backup_last_file'),
        'email': await DatabaseService.instance.getSetting('drive_backup_email'),
        'autoEnabled': await autoBackupEnabled ? '1' : '0',
      };
}
