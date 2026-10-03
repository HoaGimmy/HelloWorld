import 'package:flutter_test/flutter_test.dart';
import 'package:mpwindows_crm/main.dart';

void main() {
  testWidgets('MPWindows CRM renders branded splash screen', (tester) async {
    await tester.pumpWidget(const MPWindowsCRMApp());

    expect(find.text('Trung thực dẫn đầu - cửa sáng bền lâu.'), findsOneWidget);
  });
}
