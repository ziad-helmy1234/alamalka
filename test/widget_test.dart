// Basic Flutter widget test for StockTradingApp.

import 'package:flutter_test/flutter_test.dart';
import 'package:alamalka/main.dart';

void main() {
  testWidgets('StockTradingApp builds successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const StockTradingApp());

    // Verify that the app title or main screen elements are found.
    expect(find.byType(StockTradingApp), findsOneWidget);
  });
}
