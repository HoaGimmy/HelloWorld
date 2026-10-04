import 'package:flutter/material.dart';

import '../services/theme_color_controller.dart';
import 'backup_settings_screen.dart';
import 'follow_up_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _hexController;

  static const _colors = <Color>[
    Color(0xFFC62828), Color(0xFFEF5350), Color(0xFFF4511E),
    Color(0xFFFF8F00), Color(0xFFFFB300), Color(0xFFFDD835),
    Color(0xFF9E9D24), Color(0xFF7CB342), Color(0xFF2E7D32),
    Color(0xFF00897B), Color(0xFF00A99D), Color(0xFF26A69A),
    Color(0xFF29B6F6), Color(0xFF0288D1), Color(0xFF1565C0),
    Color(0xFF283593), Color(0xFF5E35B1), Color(0xFF8E24AA),
    Color(0xFFD81B60), Color(0xFFEC407A), Color(0xFFF06292),
    Color(0xFF6D4C41), Color(0xFFB07A1B), Color(0xFF8B5E00),
    Color(0xFF8D8D8D), Color(0xFF546E7A), Color(0xFF455A64),
    Color(0xFF212121),
  ];

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController(text: _hexOf(ThemeColorController.instance.value));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  static String _hexOf(Color color) {
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return rgb.toRadixString(16).padLeft(6, '0').toUpperCase();
  }

  Future<void> _select(Color color) async {
    _hexController.text = _hexOf(color);
    await ThemeColorController.instance.setColor(color);
    if (mounted) setState(() {});
  }

  Future<void> _applyHex() async {
    var raw = _hexController.text.trim().replaceAll('#', '');
    if (raw.length == 3) {
      raw = raw.split('').map((c) => '$c$c').join();
    }
    final rgb = int.tryParse(raw, radix: 16);
    if (rgb == null || raw.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mã màu chưa đúng. Ví dụ: B07A1B')),
      );
      return;
    }
    await _select(Color(0xFF000000 | rgb));
  }

  @override
  Widget build(BuildContext context) {
    final selected = ThemeColorController.instance.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Cá nhân hoá giao diện',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('Chọn màu sắc theo sở thích. Thay đổi được áp dụng ngay cho toàn bộ MPWindows CRM và được lưu cho lần mở sau.'),
          const SizedBox(height: 18),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Màu chủ đạo', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _colors.map((color) {
                      final active = color.toARGB32() == selected.toARGB32();
                      return InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: () => _select(color),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: active ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: active ? const Icon(Icons.check, color: Colors.white) : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _hexController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Mã màu tùy chỉnh',
                      prefixText: '#',
                      hintText: 'B07A1B',
                    ),
                    onSubmitted: (_) => _applyHex(),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _applyHex,
                    icon: const Icon(Icons.palette_outlined),
                    label: const Text('Áp dụng màu'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: ListTile(
              leading: CircleAvatar(backgroundColor: selected),
              title: const Text('Khôi phục màu MPWindows'),
              subtitle: const Text('Quay về màu vàng nâu mặc định'),
              trailing: const Icon(Icons.restart_alt),
              onTap: () async {
                await ThemeColorController.instance.reset();
                _hexController.text = _hexOf(ThemeColorController.instance.value);
                if (mounted) setState(() {});
              },
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Chăm sóc khách hàng',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Quy tắc nhắc chăm sóc'),
              subtitle: const Text('Khách mới · Tư vấn · Báo giá · Đàm phán'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FollowUpSettingsScreen()),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Dữ liệu',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.cloud_sync_outlined),
              title: const Text('Sao lưu & dữ liệu'),
              subtitle: const Text('Google Drive · Xuất file · Khôi phục'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BackupSettingsScreen()),
              ),
            ),
          ),

        ],
      ),
    );
  }
}
