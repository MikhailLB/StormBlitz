import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:storm_blitz/main.dart';
import 'package:storm_blitz/models/player_profile.dart';

void main() {
  testWidgets('App boots into the loading screen', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<PlayerProfile>.value(
        value: PlayerProfile(),
        child: const StormBlitzApp(),
      ),
    );
    expect(find.textContaining('Loading'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
  });
}
