import 'package:flutter_test/flutter_test.dart';
import 'package:still_alive/main.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const StillAliveApp());
    await tester.pump();
    
    expect(find.text('Still Alive'), findsAny);
  });
}
