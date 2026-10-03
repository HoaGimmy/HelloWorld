import 'package:flutter_test/flutter_test.dart';
import 'package:mpwindows_crm/utils/constants.dart';

void main() {
  test('MPWindows CRM keeps the complete customer pipeline', () {
    expect(pipelineStages, isNotEmpty);
    expect(pipelineStages.first, 'Khách mới');
    expect(pipelineStages, contains('Chốt hợp đồng'));
    expect(pipelineStages, contains('Không thành công / Mất khách'));
  });
}
