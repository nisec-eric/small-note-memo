import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:check_in_memo/app.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await Hive.initFlutter();
    await tester.pumpWidget(
      const ProviderScope(child: CheckInApp()),
    );
    await tester.pumpAndSettle();

    // 应该能看到底部导航栏
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('统计'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
