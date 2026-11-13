import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_taking_app/data/changelog_data.dart';
import 'package:note_taking_app/screens/changelog_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loadFullChangelogHistory returns kLatestChangelog followed by JSON history', () async {
    final full = await loadFullChangelogHistory();

    expect(full.length, greaterThan(10));
    expect(full.first.version, equals(kLatestChangelog.version));
    expect(full.first.isLatest, isTrue);
    expect(full[1].version, equals('v3.4.0'));
    expect(full.last.categories, isNotEmpty);
  });

  testWidgets('ChangelogScreen renders latest release immediately and loads history', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChangelogScreen(),
      ),
    );

    expect(find.text(kLatestChangelog.version), findsOneWidget);

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('v3.4.0'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('v3.4.0'), findsOneWidget);
  });
}
