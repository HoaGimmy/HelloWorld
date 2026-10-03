import 'package:flutter_test/flutter_test.dart';
import 'package:mpwindows_crm/utils/constants.dart';

void main() {
  test('CRM pipeline contains the full sales journey', () {
    expect(pipelineStages.length, 10);
    expect(pipelineStages.first, 'Khách mới');
    expect(pipelineStages.last, 'Chăm sóc sau bán');
  });

  test('MPWindows aluminum brands are configured', () {
    expect(aluminumBrands.length, 9);
    expect(aluminumBrands, contains('Xingfa Quảng Đông'));
    expect(aluminumBrands, contains('Hopo'));
    expect(aluminumBrands, contains('PMI'));
  });
}
