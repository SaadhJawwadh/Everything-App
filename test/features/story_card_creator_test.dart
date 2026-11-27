import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_taking_app/features/story_cards/story_cards.dart';

class _FakeStoryCardRenderService extends StoryCardRenderService {
  int captureCount = 0;
  bool shouldReturnNull = false;
  bool shouldThrow = false;

  _FakeStoryCardRenderService();

  @override
  Future<Uint8List?> capturePng(
    GlobalKey repaintKey, {
    double pixelRatio = 3.5,
  }) async {
    captureCount++;
    if (shouldThrow) {
      throw StateError('Simulated render failure');
    }
    if (shouldReturnNull) return null;
    // Minimal non-empty PNG header + payload bytes for test verification
    return Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, captureCount]);
  }
}

class _FakeStoryCardMediaService extends StoryCardMediaService {
  List<File> sharedFiles = const [];
  List<int> savedFileSizes = const [];
  String? lastSharedTitle;
  bool shareShouldSucceed = true;
  int? saveCountOverride;

  _FakeStoryCardMediaService();

  @override
  Future<bool> shareMultipleImageFiles(
    List<File> files, {
    required String title,
  }) async {
    sharedFiles = List<File>.from(files);
    lastSharedTitle = title;
    return shareShouldSucceed;
  }

  @override
  Future<int> saveMultipleImageFilesToGallery(List<File> files) async {
    savedFileSizes = [
      for (final f in files) f.lengthSync(),
    ];
    return saveCountOverride ?? files.length;
  }
}

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

  testWidgets('StoryCardStudioSheet renders sentence-case metadata, monumental quote, and streamlined CTA', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestSheet());
    await tester.pumpAndSettle();

    // Verify header and sentence-case section labels
    expect(find.text('Story Card Studio'), findsOneWidget);
    expect(find.text('Typography style'), findsOneWidget);
    expect(find.text('Visual theme'), findsOneWidget);
    expect(find.text('TYPOGRAPHY STYLE'), findsNothing);
    expect(find.text('VISUAL THEME'), findsNothing);

    // Verify clean typographic metadata (no ALL CAPS kickers)
    expect(find.text('Philosophy'), findsOneWidget);
    expect(find.text('Sep 3, 2026'), findsOneWidget);
    expect(find.text('PHILOSOPHY'), findsNothing);
    expect(find.text('SEP 3, 2026'), findsNothing);

    // Verify title attribution and quote excerpt are rendered in natural case
    expect(find.text('Design Laws'), findsOneWidget);
    expect(find.text('DESIGN LAWS'), findsNothing);
    expect(
      find.text('Simplicity is about subtracting the obvious and adding the meaningful.'),
      findsOneWidget,
    );

    // Verify aspect ratio switcher has 9:16 Story selected by default
    expect(find.text('9:16 Story'), findsOneWidget);
    expect(find.text('1:1 Square'), findsOneWidget);
    expect(find.text('4:5 Portrait'), findsOneWidget);

    // Verify single primary CTA ('Share') + compact secondary Save & Copy icon actions >= 48x48dp
    expect(find.text('Share'), findsOneWidget);
    final saveButton = find.byIcon(Icons.download_rounded);
    final copyButton = find.byIcon(Icons.copy_rounded);
    expect(saveButton, findsOneWidget);
    expect(copyButton, findsOneWidget);
    expect(tester.getSize(saveButton).width, greaterThanOrEqualTo(20.0));
    final saveBox = tester.getSize(find.byTooltip('Save to Gallery (Pictures/EverythingApp)'));
    final copyBox = tester.getSize(find.byTooltip('Copy Image to Clipboard'));
    expect(saveBox.width, greaterThanOrEqualTo(48.0));
    expect(saveBox.height, greaterThanOrEqualTo(48.0));
    expect(copyBox.width, greaterThanOrEqualTo(48.0));
    expect(copyBox.height, greaterThanOrEqualTo(48.0));
  });

  testWidgets('StoryCardStudioSheet switches aspect ratios on segment tap', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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

  testWidgets('StoryCardStudioSheet cycles art-directed poster themes without cliché glow/dots', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestSheet());
    await tester.pumpAndSettle();

    // Verify Gallery (editorial) is present and renders quotation mark
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('“'), findsOneWidget);

    // Tap Forest
    expect(find.text('Forest'), findsOneWidget);
    await tester.tap(find.text('Forest'));
    await tester.pumpAndSettle();

    // Tap Cobalt
    expect(find.text('Cobalt'), findsOneWidget);
    await tester.tap(find.text('Cobalt'));
    await tester.pumpAndSettle();

    // Tap Silver
    expect(find.text('Silver'), findsOneWidget);
    await tester.tap(find.text('Silver'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Verify Terminal theme has no fake macOS traffic light dots
    expect(find.text('Terminal'), findsOneWidget);
    await tester.ensureVisible(find.text('Terminal'));
    await tester.tap(find.text('Terminal'));
    await tester.pumpAndSettle();

    final previewFinder = find.byType(StoryCardPreview);
    final containers = tester.widgetList<Container>(
      find.descendant(of: previewFinder, matching: find.byType(Container)),
    );
    for (final c in containers) {
      final dec = c.decoration;
      if (dec is BoxDecoration) {
        expect(dec.color, isNot(const Color(0xFFFF5F56)));
        expect(dec.color, isNot(const Color(0xFFFFBD2E)));
        expect(dec.color, isNot(const Color(0xFF27C93F)));
        expect(dec.gradient, isNull);
      }
    }
  });

  testWidgets('StoryCardStudioSheet toggles metadata chips', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestSheet());
    await tester.pumpAndSettle();

    // Initially title is visible
    expect(find.text('Design Laws'), findsOneWidget);

    // Tap Title chip to toggle off
    await tester.tap(find.widgetWithText(FilterChip, 'Title'));
    await tester.pumpAndSettle();

    // Title should no longer be rendered
    expect(find.text('Design Laws'), findsNothing);

    // Formatted date and category MUST STILL BE VISIBLE in the top header
    expect(find.text('Sep 3, 2026'), findsOneWidget);
    expect(find.text('Philosophy'), findsOneWidget);

    // Tap Watermark chip to toggle on
    expect(find.text('Everything App'), findsNothing);
    await tester.tap(find.widgetWithText(FilterChip, 'Watermark'));
    await tester.pumpAndSettle();

    // Watermark should now be rendered as plain typographic footer
    expect(find.text('Everything App'), findsOneWidget);
  });

  testWidgets('StoryCardStudioSheet toggles text and title edit mode', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
    await tester.enterText(find.widgetWithText(TextField, 'Card Title'), 'New Aesthetics');
    await tester.pumpAndSettle();

    // Verify title in live card updates
    expect(
      find.descendant(
        of: find.byType(StoryCardPreview),
        matching: find.text('New Aesthetics'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('StoryCardStudioSheet renders Quote mode with monumental poster display scaling', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const shortQuote = 'Make it simple, make it true.';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StoryCardPreview(
              config: StoryCardConfig(
                title: 'Dieter Rams',
                text: shortQuote,
                category: 'Design',
                date: DateTime(2026, 9, 3),
                themePreset: StoryCardThemePreset.velvetOled,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final quoteWidget = tester.widget<Text>(find.text(shortQuote));
    final style = quoteWidget.style!;
    expect(style.fontSize, inInclusiveRange(36.0, 46.0));
    expect(style.height, inInclusiveRange(0.95, 1.05));
    expect(style.letterSpacing! / style.fontSize!, closeTo(-0.03, 0.002));
    expect(find.text('Dieter Rams'), findsOneWidget);
  });

  testWidgets('StoryCardPreview enforces readability floor for long quotes on compact canvases', (tester) async {
    final longQuote = List.generate(48, (i) => 'architecture$i').join(' ');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StoryCardPreview(
              config: StoryCardConfig(
                title: 'Essay',
                text: longQuote,
                category: 'Notes',
                date: DateTime(2026, 9, 3),
                aspectRatio: StoryCardAspectRatio.square,
                layoutMode: StoryCardLayoutMode.quote,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final quoteWidget = tester.widget<Text>(find.text(longQuote));
    expect(quoteWidget.style!.fontSize, greaterThanOrEqualTo(14.0));
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
    expect(
      StoryCardLayoutMode.autoDetect('Simplicity is the ultimate sophistication.'),
      StoryCardLayoutMode.quote,
    );

    expect(
      StoryCardLayoutMode.autoDetect('Key takeaways:\n- First point\n- Second point'),
      StoryCardLayoutMode.article,
    );

    expect(
      StoryCardLayoutMode.autoDetect('[x] Ship the release\n[ ] Update docs'),
      StoryCardLayoutMode.article,
    );

    expect(
      StoryCardLayoutMode.autoDetect('Paragraph one.\n\nParagraph two with more details.'),
      StoryCardLayoutMode.article,
    );

    final longExcerpt = List.generate(45, (i) => 'word$i').join(' ');
    expect(
      StoryCardLayoutMode.autoDetect(longExcerpt),
      StoryCardLayoutMode.article,
    );
  });

  testWidgets('StoryCardStudioSheet toggles between Quote and Reader layout modes', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const sampleNote = 'Meeting Notes:\n- Finalized roadmap\n[x] Completed review\n\nNext steps for team.';

    await tester.pumpWidget(buildTestSheet(
      initialText: sampleNote,
      noteTitle: 'Weekly Sync',
      category: 'Work',
    ));
    await tester.pumpAndSettle();

    final segmentedButtonFinder = find.byType(SegmentedButton<StoryCardLayoutMode>);
    expect(segmentedButtonFinder, findsOneWidget);
    final segmentedButton = tester.widget<SegmentedButton<StoryCardLayoutMode>>(segmentedButtonFinder);
    expect(segmentedButton.selected, contains(StoryCardLayoutMode.article));

    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text('Completed review'), findsOneWidget);
    expect(find.text('Finalized roadmap'), findsOneWidget);

    await tester.tap(find.text('Quote'));
    await tester.pumpAndSettle();

    final segmentedButtonAfter = tester.widget<SegmentedButton<StoryCardLayoutMode>>(segmentedButtonFinder);
    expect(segmentedButtonAfter.selected, contains(StoryCardLayoutMode.quote));
  });

  test('StoryCardConfig.cleanMarkdownForCard formats checklists, headings, and bold text', () {
    const raw = '# Sprint Goals\n- [x] Ship **release**\n- [ ] Update docs\n  * [X] Subtask done';
    final cleaned = StoryCardConfig.cleanMarkdownForCard(raw);
    expect(
      cleaned,
      'Sprint Goals\n☑ Ship release\n☐ Update docs\n  ☑ Subtask done',
    );
  });

  test('StoryCardConfig.slides paginates long notes across multiple slides', () {
    final longQuoteText = List.generate(130, (i) => 'word$i').join(' ');
    final quoteConfig = StoryCardConfig(
      title: 'Long Quote',
      text: longQuoteText,
      date: DateTime(2026, 9, 5),
      layoutMode: StoryCardLayoutMode.quote,
    );
    expect(quoteConfig.slides.length, greaterThan(1));
    expect(quoteConfig.currentSlideText, quoteConfig.slides.first);

    final longArticleText = [
      List.generate(60, (i) => 'paraOne$i').join(' '),
      List.generate(60, (i) => 'paraTwo$i').join(' '),
      List.generate(60, (i) => 'paraThree$i').join(' '),
    ].join('\n\n');
    final articleConfig = StoryCardConfig(
      title: 'Long Article',
      text: longArticleText,
      date: DateTime(2026, 9, 5),
      layoutMode: StoryCardLayoutMode.article,
    );
    expect(articleConfig.slides.length, greaterThan(1));
    final secondSlideConfig = articleConfig.copyWith(currentSlideIndex: 1);
    expect(secondSlideConfig.currentSlideText, articleConfig.slides[1]);
  });

  testWidgets('StoryCardStudioSheet collapses multi-slide export to single primary CTA + compact icon actions', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final longNote = [
      List.generate(70, (i) => 'alpha$i').join(' '),
      List.generate(70, (i) => 'beta$i').join(' '),
    ].join('\n\n');

    await tester.pumpWidget(buildTestSheet(
      initialText: longNote,
      noteTitle: 'Long Essay',
    ));
    await tester.pumpAndSettle();

    expect(find.text('Slide 1 of 2'), findsOneWidget);
    expect(find.byTooltip('Next slide'), findsOneWidget);

    // Single primary CTA ('Share All (2)') + icon buttons for Save All & Copy
    expect(find.text('Share All (2)'), findsOneWidget);
    expect(find.text('Share'), findsNothing);
    expect(find.text('Save All (2)'), findsNothing);
    expect(find.byTooltip('Save all 2 slides to gallery'), findsOneWidget);
    expect(find.byTooltip('Copy Image to Clipboard'), findsOneWidget);

    await tester.tap(find.byTooltip('Next slide'));
    await tester.pumpAndSettle();

    expect(find.text('Slide 2 of 2'), findsOneWidget);
  });

  test('StoryCardThemeStyle resolves bold chromatic, forest, cobalt, silver, gallery, and deep ink palettes', () {
    final lightTheme = ThemeData.light();
    final gallery = StoryCardThemeStyle.resolve(
      preset: StoryCardThemePreset.editorial,
      appTheme: lightTheme,
    );
    final forest = StoryCardThemeStyle.resolve(
      preset: StoryCardThemePreset.obsidianAura,
      appTheme: lightTheme,
    );
    final cobalt = StoryCardThemeStyle.resolve(
      preset: StoryCardThemePreset.velvetOled,
      appTheme: lightTheme,
    );
    final silver = StoryCardThemeStyle.resolve(
      preset: StoryCardThemePreset.frostedGlassLuxe,
      appTheme: lightTheme,
    );
    final terminal = StoryCardThemeStyle.resolve(
      preset: StoryCardThemePreset.terminal,
      appTheme: lightTheme,
    );

    expect(gallery.background.computeLuminance(), greaterThan(0.85));
    expect(forest.background, const Color(0xFF0A2219));
    expect(cobalt.background, const Color(0xFF1239D6));
    expect(silver.background, const Color(0xFFE1E4E9));
    expect(terminal.background, const Color(0xFF0B0D12));
    expect(terminal.isTerminal, isTrue);
  });

  Future<void> pumpExportAndSettle(WidgetTester tester) async {
    for (int i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    await tester.pumpAndSettle();
  }

  testWidgets('StoryCardStudioSheet Share All captures every slide cleanly and restores slide index', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    final tempDir = Directory.systemTemp.createTempSync('story_share_test_');
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final fakeRender = _FakeStoryCardRenderService();
    final fakeMedia = _FakeStoryCardMediaService();
    final longNote = [
      List.generate(70, (i) => 'alpha$i').join(' '),
      List.generate(70, (i) => 'beta$i').join(' '),
    ].join('\n\n');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoryCardStudioSheet(
            initialText: longNote,
            noteTitle: 'Multi Slide Share',
            noteDate: DateTime(2026, 9, 3),
            renderService: fakeRender,
            mediaService: fakeMedia,
            tempDirProvider: () async => tempDir,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Advance to Slide 2 of 2 before sharing all
    await tester.tap(find.byTooltip('Next slide'));
    await tester.pumpAndSettle();
    expect(find.text('Slide 2 of 2'), findsOneWidget);

    await tester.tap(find.text('Share All (2)'));
    await pumpExportAndSettle(tester);

    expect(fakeRender.captureCount, 2);
    expect(fakeMedia.sharedFiles.length, 2);
    expect(fakeMedia.lastSharedTitle, 'Multi Slide Share');
    for (final file in fakeMedia.sharedFiles) {
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));
    }
    // Restores original slide index after export
    expect(find.text('Slide 2 of 2'), findsOneWidget);
  });

  testWidgets('StoryCardStudioSheet Save All captures every slide, saves to gallery, and shows in-sheet success banner', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    final tempDir = Directory.systemTemp.createTempSync('story_save_test_');
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final fakeRender = _FakeStoryCardRenderService();
    final fakeMedia = _FakeStoryCardMediaService();
    final longNote = [
      List.generate(70, (i) => 'gamma$i').join(' '),
      List.generate(70, (i) => 'delta$i').join(' '),
    ].join('\n\n');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoryCardStudioSheet(
            initialText: longNote,
            noteTitle: 'Multi Slide Save',
            noteDate: DateTime(2026, 9, 3),
            renderService: fakeRender,
            mediaService: fakeMedia,
            tempDirProvider: () async => tempDir,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save all 2 slides to gallery'));
    await pumpExportAndSettle(tester);

    expect(fakeRender.captureCount, 2);
    expect(fakeMedia.savedFileSizes.length, 2);
    expect(fakeMedia.savedFileSizes, everyElement(greaterThan(0)));
    expect(
      find.descendant(
        of: find.byType(StoryCardStudioSheet),
        matching: find.text('Saved 2 slides to Gallery'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(StoryCardStudioSheet),
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('StoryCardStudioSheet shows in-sheet error banner visibly when export fails', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    final tempDir = Directory.systemTemp.createTempSync('story_err_test_');
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final fakeRender = _FakeStoryCardRenderService()..shouldThrow = true;
    final fakeMedia = _FakeStoryCardMediaService();
    final longNote = [
      List.generate(70, (i) => 'errA$i').join(' '),
      List.generate(70, (i) => 'errB$i').join(' '),
    ].join('\n\n');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoryCardStudioSheet(
            initialText: longNote,
            noteTitle: 'Error Banner Test',
            noteDate: DateTime(2026, 9, 3),
            renderService: fakeRender,
            mediaService: fakeMedia,
            tempDirProvider: () async => tempDir,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Share All (2)'));
    await pumpExportAndSettle(tester);

    expect(
      find.descendant(
        of: find.byType(StoryCardStudioSheet),
        matching: find.textContaining('Sharing slides failed:'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(StoryCardStudioSheet),
        matching: find.byIcon(Icons.error_outline_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('StoryCardStudioSheet modal keeps 9:16 preview unclipped and Share All visible simultaneously', (tester) async {
    const viewportSize = Size(412, 915);
    tester.view.physicalSize = viewportSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final longNote = [
      List.generate(70, (i) => 'omega$i').join(' '),
      List.generate(70, (i) => 'sigma$i').join(' '),
    ].join('\n\n');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => StoryCardStudioSheet.show(
                context: context,
                initialText: longNote,
                noteTitle: 'Office or Park?',
                category: 'Brutally Honest',
                noteDate: DateTime(2026, 9, 3),
              ),
              child: const Text('Open Studio'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Studio'));
    await tester.pumpAndSettle();

    void assertPreviewAndCtaVisible() {
      final previewRect = tester.getRect(find.byType(StoryCardPreview));
      final shareRect = tester.getRect(find.text('Share All (2)'));
      expect(previewRect.top, greaterThanOrEqualTo(0.0));
      expect(previewRect.bottom, lessThanOrEqualTo(viewportSize.height));
      expect(previewRect.left, greaterThanOrEqualTo(0.0));
      expect(previewRect.right, lessThanOrEqualTo(viewportSize.width));
      expect(shareRect.top, greaterThanOrEqualTo(previewRect.bottom));
      expect(shareRect.bottom, lessThanOrEqualTo(viewportSize.height));
    }

    // 9:16 Story (default)
    assertPreviewAndCtaVisible();

    // 1:1 Square
    await tester.tap(find.text('1:1 Square'));
    await tester.pumpAndSettle();
    assertPreviewAndCtaVisible();

    // 4:5 Portrait
    await tester.tap(find.text('4:5 Portrait'));
    await tester.pumpAndSettle();
    assertPreviewAndCtaVisible();
  });
}
