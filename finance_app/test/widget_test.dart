import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_app/app.dart';

void main() {
  testWidgets('App renders login screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: FinanceApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('FinanceApp'), findsOneWidget);
  });
}
