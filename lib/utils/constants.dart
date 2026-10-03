import 'package:flutter/material.dart';

const pipelineStages = <String>['Khách mới','Đã liên hệ','Đang tư vấn','Khảo sát','Báo giá','Đàm phán','Chốt hợp đồng','Thi công','Hoàn thành','Chăm sóc sau bán'];
const leadSources = <String>['Facebook','TikTok','Zalo','Website','Giới thiệu','Khách cũ','Khác'];
const aluminumBrands = <String>[
  'Xingfa Việt Nam',
  'Xingfa Quảng Đông',
  'Xingfa Class A',
  'Hopo',
  'Maxpro',
  'Romadio',
  'Civro',
  'Gand Luxury',
  'PMI',
];

Color stageColor(String stage, ThemeData theme) => switch(stage) {
 'Khách mới' => theme.colorScheme.primary,
 'Đã liên hệ' => Colors.indigo,
 'Đang tư vấn' => Colors.deepPurple,
 'Khảo sát' => Colors.orange,
 'Báo giá' => Colors.amber.shade800,
 'Đàm phán' => Colors.blue,
 'Chốt hợp đồng' => Colors.green,
 'Thi công' => Colors.teal,
 'Hoàn thành' => Colors.green.shade900,
 'Chăm sóc sau bán' => Colors.pink,
 _ => theme.colorScheme.secondary,
};
