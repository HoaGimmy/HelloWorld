import 'package:flutter/material.dart';

import '../services/follow_up_service.dart';
import '../services/ios_native_service.dart';

class FollowUpSettingsScreen extends StatefulWidget {
  const FollowUpSettingsScreen({super.key});
  @override
  State<FollowUpSettingsScreen> createState() => _FollowUpSettingsScreenState();
}

class _FollowUpSettingsScreenState extends State<FollowUpSettingsScreen> {
  Map<String, int> rules = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await FollowUpService.instance.getRules();
    if (!mounted) return;
    setState(() {
      rules = data;
      loading = false;
    });
  }

  Future<void> _change(String stage, int days) async {
    setState(() => rules[stage] = days);
    await FollowUpService.instance.setRule(stage, days);
    await IOSNativeService.instance.syncAll();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Quy tắc chăm sóc khách')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'MPWindows CRM tự nhắc khi khách không có tương tác mới sau số ngày bạn đặt.',
                  ),
                  const SizedBox(height: 14),
                  ...FollowUpService.defaultDays.keys.map((stage) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(stage, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(_description(stage)),
                          trailing: DropdownButton<int>(
                            value: rules[stage] ?? FollowUpService.defaultDays[stage]!,
                            items: const [1, 2, 3, 4, 5, 7, 10, 14]
                                .map((d) => DropdownMenuItem(value: d, child: Text('$d ngày')))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) _change(stage, value);
                            },
                          ),
                        ),
                      )),
                  const SizedBox(height: 6),
                  Text(
                    'Các trạng thái Chốt hợp đồng, Thi công, Hoàn thành và Mất khách không tạo cảnh báo bỏ quên.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
      );

  String _description(String stage) => switch (stage) {
        'Khách mới' => 'Chưa có cuộc gọi/tin nhắn chăm sóc',
        'Báo giá' => 'Đã báo giá nhưng chưa có phản hồi mới',
        'Đàm phán' => 'Đang đàm phán nhưng chưa có tương tác mới',
        _ => 'Không có tương tác mới với khách',
      };
}
