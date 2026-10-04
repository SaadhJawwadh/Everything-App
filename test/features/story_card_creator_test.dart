import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_taking_app/features/story_cards/story_cards.dart';

void main() {
  Widget buildTestSheet({
    String initialText = 'Simplicity is about subtracting the obvious and adding the meaningful.',
    String noteTitle = 'Design Laws',
    String category = 'Philosophy',
    int noteColorValue = 0,
    DateTime? noteDate,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: StoryCardStudioSheet(
            initialText: initialText,
            noteTitle: noteTitle,
            category: category,
            noteColorValue: noteColorValue,
            noteDate: noteDate ?? DateTime(2026, 9, 3),
          ),
        ),
      ),
    );
  }

  testWidgets('StoryCardStudioSheet renders initial text, title, and default 9:16 Story ratio', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestSheet());
    await tester.pumpAndSettle();

    // Verify header
    expect(find.text('Story Card Studio'), findsOneWidget);

    // Verify category and formatted date are in the top header
    expect(find.text('PHILOSOPHY'), findsOneWidget);
    expect(find.text('SEP 3, 2026'), findsOneWidget);

    // Verify title and quote excerpt are rendered
    expect(find.text('DESIGN LAWS'), findsOneWidget);
    expect(
      find.text('Simplicity is about subtracting the obvious and adding the meaningful.'),
      findsOneWidget,
    );

    // Verify aspect ratio switcher has 9:16 Story selected by default
    expect(find.text('9:16 Story'), findsOneWidget);
    expect(find.text('1:1 Square'), findsOneWidget);
    expect(find.text('4:5 Portrait'), findsOneWidget);

    // Verify export buttons
    expect(find.text('Share Image'), findsOneWidget);
    expect(find.byIcon(Icons.download_rounded), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
  });

  testWidgets('StoryCardStudioSheet switches aspect ratios on segment tap', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestSheet());
    await tester.pumpAndSettle();

    // Tap 1:1 Square
    await tester.tap(find.text('1:1 Square'));
    await tester.pumpAndSettle();

    final segmentedButtonFinder = find.byType(SegmentedButton<StoryCardAspectRatio>);
    expect(segmentedButtonFinder, findsOneWidget);
    final segmentedButton = tester.widget<SegmentedButton<StoryCardAspectRatio>>(segmentedButtonFinder);
    expect(segmentedButton.selected, contains(StoryCardAspectRatio.square));

    // Tap 4:5 Portrait
    await tester.tap(find.text('4:5 Portrait'));
    await tester.pumpAndSettle();

    final segmentedButtonAfter = tester.widget<SegmentedButton<StoryCardAspectRatio>>(segmentedButtonFinder);
    expect(segmentedButtonAfter.selected, contains(StoryCardAspectRatio.portrait));
  });

  testWidgets('StoryCardStudioSheet cycles luxury theme presets', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestSheet());
    await tester.pumpAndSettle();

    // Verify Editorial is present and renders quotation mark
    expect(find.text('Editorial'), findsOneWidget);
    expect(find.text('“'), findsOneWidget);

    // Tap Obsidian Aura
    expect(find.text('Obsidian Aura'), findsOneWidget);
    await tester.tap(find.text('Obsidian Aura'));
    await tester.pumpAndSettle();

    // Tap Velvet OLED
    expect(find.text('Velvet OLED'), findsOneWidget);
    await tester.tap(find.text('Velvet OLED'));
    await tester.pumpAndSettle();

    // Tap Frosted Luxe
    expect(find.text('Frosted Luxe'), findsOneWidget);
    await tester.tap(find.text('Frosted Luxe'), warnIfMissed: false);
    await tester.pumpAndSettle();
  });

  testWidgets('StoryCardStudioSheet toggles metadata chips', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestSheet());
    await tester.pumpAndSettle();

    // Initially title is visible
    expect(find.text('DESIGN LAWS'), findsOneWidget);

    // Tap Title chip to toggle off
    await tester.tap(find.widgetWithText(FilterChip, 'Title'));
    await tester.pumpAndSettle();

    // Title should no longer be rendered
    expect(find.text('DESIGN LAWS'), findsNothing);

    // Formatted date and category MUST STILL BE VISIBLE in the top header
    expect(find.text('SEP 3, 2026'), findsOneWidget);
    expect(find.text('PHILOSOPHY'), findsOneWidget);

    // Tap Watermark chip to toggle on
    expect(find.text('Everything App'), findsNothing);
    await tester.tap(find.widgetWithText(FilterChip, 'Watermark'));
    await tester.pumpAndSettle();

    // Watermark should now be rendered
    expect(find.text('Everything App'), findsOneWidget);
  });

  testWidgets('StoryCardStudioSheet toggles text and title edit mode', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestSheet());
    await tester.pumpAndSettle();

    // Edit TextFields are initially hidden
    expect(find.byType(TextField), findsNothing);

    // Tap Edit Text button in header
    await tester.tap(find.text('Edit Text'));
    await tester.pumpAndSettle();

    // Two TextFields are now visible: Title and Quote Text
    expect(find.byType(TextField), findsNWidgets(2));

    // Enter edited title
    await tester.enterText(find.widgetWithText(TextField, 'Card Title'), 'NEW AESTHETICS');
    await tester.pumpAndSettle();

    // Verify title in live card updates
    expect(
      find.descendant(
        of: find.byType(StoryCardPreview),
        matching: find.text('NEW AESTHETICS'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('StoryCardStudioSheet renders Quote mode with ambient quotation mark and attribution', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestSheet(
      initialText: 'Design is not just what it looks like and feels like. Design is how it works.',
      noteTitle: 'Steve Jobs',
    ));
    await tester.pumpAndSettle();

    // Ambient watermark quotation mark is present
    expect(find.text('“'), findsOneWidget);

    // Title attribution is rendered below quote
    expect(find.text('STEVE JOBS'), findsOneWidget);

    // Full text is rendered without arbitrary truncation
    expect(
      find.text('Design is not just what it looks like and feels like. Design is how it works.'),
      findsOneWidget,
    );
  });

  test('StoryCardConfig guarantees structured title and Tamil detection', () {
    final configWithFirstLine = StoryCardConfig(
      title: '',
      text: 'First line of poem\nSecond line',
      date: DateTime(2026, 9, 5),
    );
    expect(configWithFirstLine.resolvedTitle, 'First line of poem');

    final blankConfig = StoryCardConfig(
      title: '   ',
      text: '   ',
      date: DateTime(2026, 9, 5),
    );
    expect(blankConfig.resolvedTitle, 'Reflection');

    // Tamil detection
    expect(StoryCardConfig.containsTamil('பிறந்தநாள் வாழ்த்துக்கள்'), isTrue);
    expect(StoryCardConfig.containsTamil('Hello world'), isFalse);
  });

  test('StoryCardLayoutMode auto-detects based on length, paragraphs, and list items', () {
    // Short quote without breaks -> quote
    expect(
      StoryCardLayoutMode.autoDetect('Simplicity is the ultimate sophistication.'),
      StoryCardLayoutMode.quote,
    );

    // Text with markdown list items -> article
    expect(
      StoryCardLayoutMode.autoDetect('Key takeaways:\n- First point\n- Second point'),
      StoryCardLayoutMode.article,
    );

    // Text with checklist items -> article
    expect(
      StoryCardLayoutMode.autoDetect('[x] Ship the release\n[ ] Update docs'),
      StoryCardLayoutMode.article,
    );

    // Text with multiple paragraphs -> article
    expect(
      StoryCardLayoutMode.autoDetect('Paragraph one.\n\nParagraph two with more details.'),
      StoryCardLayoutMode.article,
    );

    // Long text > 40 words -> article
    final longExcerpt = List.generate(45, (i) => 'word$i').join(' ');
    expect(
      StoryCardLayoutMode.autoDetect(longExcerpt),
      StoryCardLayoutMode.article,
    );
  });

  testWidgets('StoryCardStudioSheet toggles between Quote and Reader layout modes', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    const sampleNote = 'Meeting Notes:\n- Finalized roadmap\n[x] Completed review\n\nNext steps for team.';

    await tester.pumpWidget(buildTestSheet(
      initialText: sampleNote,
      noteTitle: 'Weekly Sync',
      category: 'Work',
    ));
    await tester.pumpAndSettle();

    // Verify Reader mode is auto-detected
    final segmentedButtonFinder = find.byType(SegmentedButton<StoryCardLayoutMode>);
    expect(segmentedButtonFinder, findsOneWidget);
    final segmentedButton = tester.widget<SegmentedButton<StoryCardLayoutMode>>(segmentedButtonFinder);
    expect(segmentedButton.selected, contains(StoryCardLayoutMode.article));

    // Verify checklist and bullet items are rendered
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text('Completed review'), findsOneWidget);
    expect(find.text('Finalized roadmap'), findsOneWidget);

    // Tap Quote mode
    await tester.tap(find.text('Quote'));
    await tester.pumpAndSettle();

    final segmentedButtonAfter = tester.widget<SegmentedButton<StoryCardLayoutMode>>(segmentedButtonFinder);
    expect(segmentedButtonAfter.selected, contains(StoryCardLayoutMode.quote));
  });
}

