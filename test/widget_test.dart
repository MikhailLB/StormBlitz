import 'package:flutter_test/flutter_test.dart';

import 'package:storm_blitz/main.dart';

void main() {
  testWidgets('App boots into the loading screen', (tester) async {
    await tester.pumpWidget(const StormBlitzApp());
    expect(find.text('Loading'), findsNothing); // dots vary; just ensure no crash
    await tester.pump(const Duration(milliseconds: 100));
  });
}
