import 'dart:convert';
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
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
  static const _scopes = <String>[
    drive.DriveApi.driveFileScope,
    sheets.SheetsApi.spreadsheetsScope,
  ];
  static const _folderName = 'MPWindows CRM Backup';
  static const _sheetName = 'MPWindows CRM Online';

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<GoogleSignInAccount> connect() async {
    try {
      final existing = await _googleSignIn.signInSilently();
      final account = existing ?? await _googleSignIn.signIn();
      if (account == null) {
        throw StateError('Đăng nhập Google đã bị hủy.');
      }
      final granted = await _googleSignIn.requestScopes(_scopes);
      if (!granted) {
        throw StateError(
          'Google chưa cấp quyền Drive. Hãy chọn Cho phép để MPWindows CRM sao lưu dữ liệu.',
        );
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

    final existing = await _googleSignIn.signInSilently();
    if (existing == null) return false;

    final now = DateTime.now();
    bool due(String? value) {
      final last = DateTime.tryParse(value ?? '')?.toLocal();
      return last == null || last.year != now.year || last.month != now.month || last.day != now.day;
    }

    var changed = false;
    final jsonLast = await DatabaseService.instance.getSetting('drive_backup_last_at');
    if (due(jsonLast)) {
      try {
        await backupToDrive();
        changed = true;
        await DatabaseService.instance.setSetting('drive_backup_last_error', '');
      } catch (error) {
        await DatabaseService.instance.setSetting('drive_backup_last_error', error.toString());
      }
    }

    final sheetsLast = await DatabaseService.instance.getSetting('sheets_backup_last_at');
    if (due(sheetsLast)) {
      try {
        await syncToGoogleSheets();
        changed = true;
        await DatabaseService.instance.setSetting('sheets_backup_last_error', '');
      } catch (error) {
        await DatabaseService.instance.setSetting('sheets_backup_last_error', error.toString());
      }
    }
    return changed;
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

  Future<String> syncToGoogleSheets() async {
    final account = await connect();
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) throw StateError('Không thể xác thực Google Sheets.');

    try {
      final driveApi = drive.DriveApi(client);
      final sheetsApi = sheets.SheetsApi(client);
      final folderId = await _findOrCreateFolder(driveApi);
      var spreadsheetId = await DatabaseService.instance.getSetting('sheets_backup_id');

      if (spreadsheetId == null || spreadsheetId.isEmpty) {
        final escaped = _sheetName.replaceAll("'", r"\\'");
        final found = await driveApi.files.list(
          q: "name = '$escaped' and mimeType = 'application/vnd.google-apps.spreadsheet' and trashed = false",
          spaces: 'drive',
          $fields: 'files(id,name)',
          pageSize: 10,
        );
        spreadsheetId = found.files?.where((f) => f.id != null).map((f) => f.id!).firstOrNull;
      }

      if (spreadsheetId == null || spreadsheetId.isEmpty) {
        final created = await driveApi.files.create(
          drive.File()
            ..name = _sheetName
            ..mimeType = 'application/vnd.google-apps.spreadsheet'
            ..parents = [folderId]
            ..description = 'Bản sao online MPWindows CRM - không chỉnh sửa để đồng bộ ngược',
          $fields: 'id',
        );
        spreadsheetId = created.id;
      }
      if (spreadsheetId == null || spreadsheetId.isEmpty) {
        throw StateError('Không thể tạo Google Sheet sao lưu.');
      }

      final snapshot = await DatabaseService.instance.exportBackupSnapshot();
      final rawTables = snapshot['tables'];
      if (rawTables is! Map) throw StateError('Dữ liệu sao lưu không hợp lệ.');

      final wanted = DatabaseService.backupTables.where((t) => t != 'app_settings').toList();
      final book = await sheetsApi.spreadsheets.get(spreadsheetId);
      final existingTitles = <String>{};
      for (final s in book.sheets ?? const <sheets.Sheet>[]) {
        final title = s.properties?.title;
        if (title != null) existingTitles.add(title);
      }
      final requests = <sheets.Request>[];
      for (final table in wanted) {
        if (!existingTitles.contains(table)) {
          requests.add(sheets.Request(addSheet: sheets.AddSheetRequest(properties: sheets.SheetProperties(title: table))));
        }
      }
      if (requests.isNotEmpty) {
        await sheetsApi.spreadsheets.batchUpdate(sheets.BatchUpdateSpreadsheetRequest(requests: requests), spreadsheetId);
      }

      for (final table in wanted) {
        final rows = (rawTables[table] as List?)?.whereType<Map>().toList() ?? const <Map>[];
        final headers = <String>[];
        for (final row in rows) {
          for (final key in row.keys.map((e) => e.toString())) {
            if (!headers.contains(key)) headers.add(key);
          }
        }
        if (headers.isEmpty) headers.add('id');
        final values = <List<Object?>>[
          headers,
          ...rows.map((row) => headers.map<Object?>((h) => row[h]?.toString() ?? '').toList()),
        ];
        final range = "'$table'!A:ZZ";
        await sheetsApi.spreadsheets.values.clear(sheets.ClearValuesRequest(), spreadsheetId, range);
        await sheetsApi.spreadsheets.values.update(
          sheets.ValueRange(values: values),
          spreadsheetId,
          "'$table'!A1",
          valueInputOption: 'RAW',
        );
      }

      final now = DateTime.now();
      await DatabaseService.instance.setSetting('sheets_backup_id', spreadsheetId);
      await DatabaseService.instance.setSetting('sheets_backup_last_at', now.toIso8601String());
      await DatabaseService.instance.setSetting('sheets_backup_email', account.email);
      return spreadsheetId;
    } finally {
      client.close();
    }
  }

  Future<Map<String, String?>> backupBothNow() async {
    Object? jsonError;
    Object? sheetsError;
    try { await backupToDrive(); } catch (e) { jsonError = e; }
    try { await syncToGoogleSheets(); } catch (e) { sheetsError = e; }
    return {
      'json': jsonError == null ? 'ok' : 'error',
      'sheets': sheetsError == null ? 'ok' : 'error',
      'jsonError': jsonError?.toString(),
      'sheetsError': sheetsError?.toString(),
    };
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

  Future<Map<String, int>> mergeFromFile(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Bản sao lưu không hợp lệ.');
    }
    return DatabaseService.instance.mergeBackupSnapshot(decoded);
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
        'sheetsLastAt': await DatabaseService.instance.getSetting('sheets_backup_last_at'),
        'sheetsId': await DatabaseService.instance.getSetting('sheets_backup_id'),
        'jsonError': await DatabaseService.instance.getSetting('drive_backup_last_error'),
        'sheetsError': await DatabaseService.instance.getSetting('sheets_backup_last_error'),
      };
}
