import 'package:flutter_test/flutter_test.dart';
import 'package:epc_app/main.dart';

void main() {
  testWidgets('EPC app loads login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const EpcApp());
    expect(find.text('تسجيل الدخول'), findsWidgets);
  });
}
