import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class AttachmentService {
  static Future<Directory> _attachmentDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/attachments');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _safeName(String name) =>
      name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

  static Future<String> _copyToApp(String sourcePath, String preferredName) async {
    final dir = await _attachmentDir();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final target = File('${dir.path}/${stamp}_${_safeName(preferredName)}');
    await File(sourcePath).copy(target.path);
    return target.path;
  }

  static Future<List<String>> pickProjectImages() async {
    final images = await ImagePicker().pickMultiImage(imageQuality: 88);
    final paths = <String>[];
    for (final image in images) {
      paths.add(await _copyToApp(image.path, image.name));
    }
    return paths;
  }

  static Future<String?> pickBusinessDocument() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'xlsx', 'xls', 'doc', 'docx'],
    );
    if (picked == null) return null;
    final path = picked.path;
    if (path == null || path.isEmpty) return null;
    return _copyToApp(path, picked.name);
  }

  static String fileName(String path) =>
      path.split(Platform.pathSeparator).last;
}
