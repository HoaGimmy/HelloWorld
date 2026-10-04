import 'package:flutter/material.dart';

const pipelineStages = <String>['Khách mới','Đã liên hệ','Đang tư vấn','Khảo sát','Báo giá','Đàm phán','Chốt hợp đồng','Thi công','Hoàn thành','Chăm sóc sau bán','Không thành công / Mất khách'];
const leadSources = <String>['Facebook','TikTok','Zalo','Website','Giới thiệu','Khách cũ','Khác'];
const vietnamProvinces = <String>[
  'Hà Nội','Cao Bằng','Tuyên Quang','Điện Biên','Lai Châu','Sơn La','Lào Cai',
  'Thái Nguyên','Lạng Sơn','Quảng Ninh','Bắc Ninh','Phú Thọ','Hải Phòng',
  'Hưng Yên','Ninh Bình','Thanh Hóa','Nghệ An','Hà Tĩnh','Quảng Trị','Huế',
  'Đà Nẵng','Quảng Ngãi','Gia Lai','Khánh Hòa','Đắk Lắk','Lâm Đồng','Đồng Nai',
  'Thành phố Hồ Chí Minh','Tây Ninh','Đồng Tháp','Vĩnh Long','An Giang','Cần Thơ','Cà Mau',
];

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
 'Không thành công / Mất khách' => Colors.red.shade700,
 _ => theme.colorScheme.secondary,
};
