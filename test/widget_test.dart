import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epc_app/core/store.dart';
import 'package:epc_app/main.dart';

void main() {
  testWidgets('شاشة الدخول تظهر عند عدم وجود جلسة', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await MemberStore.instance.init();
    await tester.pumpWidget(const EpcApp());
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الدخول'), findsWidgets);
    expect(find.text('نادي رواد الاقتصاد'), findsWidgets);
  });
}
