import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epc_app/main.dart';

void main() {
  testWidgets('EPC app loads login screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const EpcApp());
    await tester.pumpAndSettle();
    expect(find.text('نادي رواد الاقتصاد'), findsWidgets);
    expect(find.text('تسجيل الدخول'), findsWidgets);
  });
}
