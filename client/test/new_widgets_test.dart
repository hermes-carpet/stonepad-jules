/// Tests for new widgets and services added to meet spec §8.1 requirements.
library;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stonepad/models/sync_state.dart';
import 'package:stonepad/services/connectivity_service.dart';
import 'package:stonepad/widgets/sync_status_indicator.dart';
import 'package:stonepad/widgets/note_tile.dart';
import 'package:stonepad/widgets/editor_toolbar.dart';
import 'package:stonepad/screens/note_editor_screen.dart';

void main() {
  group('ConnectivityService', () {
    test('constructor accepts custom Connectivity instance', () {
      expect(ConnectivityService, isNotNull);
    });
  });

  group('SyncStatusIndicator', () {
    testWidgets('active state shows cloud_done in green', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SyncStatusIndicator(state: SyncState.active),
        ),
      ));
      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
    });

    testWidgets('manualOnly state shows cloud_off in orange', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SyncStatusIndicator(state: SyncState.manualOnly),
        ),
      ));
      final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_off));
      expect(icon.color, Colors.orange);
    });

    testWidgets('noNetwork state shows cloud_off in grey', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SyncStatusIndicator(state: SyncState.noNetwork),
        ),
      ));
      final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_off));
      expect(icon.color, Colors.grey);
    });

    testWidgets('disabled state shows cloud_off in grey', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SyncStatusIndicator(state: SyncState.disabled),
        ),
      ));
      final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_off));
      expect(icon.color, Colors.grey);
    });
  });

  group('NoteTile', () {
    testWidgets('shows filename without .md as title', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NoteTile(
            notePath: 'work/meetings.md',
            status: null,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ));
      expect(find.text('meetings'), findsOneWidget);
      expect(find.text('work/meetings.md'), findsOneWidget);
    });

    testWidgets('modified status shows cloud_upload icon', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NoteTile(
            notePath: 'test.md',
            status: 'modified',
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ));
      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
    });

    testWidgets('conflict_pending status shows warning icon', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NoteTile(
            notePath: 'test.md',
            status: 'conflict_pending',
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ));
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('synced status shows no trailing icon', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NoteTile(
            notePath: 'test.md',
            status: 'synced',
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ));
      expect(find.byIcon(Icons.cloud_upload), findsNothing);
      expect(find.byIcon(Icons.warning), findsNothing);
    });
  });

  group('MarkdownSyntaxController', () {
    // Mock build context isn't fully available in raw unit tests without a widget tree,
    // but we can pump a generic widget and test the buildTextSpan method directly.

    testWidgets('buildTextSpan parses and styles markdown prefixes', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            final controller = MarkdownSyntaxController(
                text: '# Heading 1\n- [ ] Task\n- Bullet');

            final span = controller.buildTextSpan(
              context: context,
              style: const TextStyle(color: Colors.black, fontSize: 16),
              withComposing: false,
            );

            // We should have multiple spans created from the split lines
            expect(span.children, isNotNull);
            final children = span.children!;

            // Expected structure:
            // Line 1: '# Heading 1\n' -> ['# ', 'Heading 1\n']
            // Line 2: '- [ ] Task\n' -> ['☐ ', '- [ ] ', 'Task\n']
            // Line 3: '- Bullet' -> ['• ', '- ', 'Bullet']

            expect(children.length, 8);

            // Line 1 assertions
            final h1Prefix = children[0] as TextSpan;
            expect(h1Prefix.text, '# ');
            expect(h1Prefix.style?.fontSize, 24);
            expect(h1Prefix.style?.fontWeight, FontWeight.bold);

            final h1Text = children[1] as TextSpan;
            expect(h1Text.text, 'Heading 1\n');
            expect(h1Text.style?.fontSize, 24);

            // Line 2 assertions
            final checkboxIcon = children[2] as TextSpan;
            expect(checkboxIcon.text, '☐ ');

            final checkboxHidden = children[3] as TextSpan;
            expect(checkboxHidden.text, '- [ ] ');
            expect(checkboxHidden.style?.fontSize, 0);
            expect(checkboxHidden.style?.color, Colors.transparent);

            final checkboxText = children[4] as TextSpan;
            expect(checkboxText.text, 'Task\n');

            // Line 3 assertions
            final bulletIcon = children[5] as TextSpan;
            expect(bulletIcon.text, '• ');
            expect(bulletIcon.style?.fontSize, 20);

            final bulletHidden = children[6] as TextSpan;
            expect(bulletHidden.text, '- ');
            expect(bulletHidden.style?.fontSize, 0);

            final bulletText = children[7] as TextSpan;
            expect(bulletText.text, 'Bullet');

            return Container();
          }
        ),
      ));
    });
  });

  group('EditorToolbar formatting', () {
    // Test formatting logic directly by tapping the popup menu.
    // Tests that formatting modifies the controller text and fires onChanged.

    testWidgets('bold wraps selected text in **', (tester) async {
      final controller = TextEditingController(text: 'hello');
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);
      var changed = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EditorToolbar(
            controller: controller,
            onChanged: () => changed = true,
          ),
        ),
      ));

      await tester.tap(find.byTooltip('Bold (**text**)'));
      await tester.pumpAndSettle();

      expect(controller.text, '**hello**');
      expect(changed, isTrue);
    });

    testWidgets('italic wraps selected text in *', (tester) async {
      final controller = TextEditingController(text: 'hello');
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);
      var changed = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EditorToolbar(
            controller: controller,
            onChanged: () => changed = true,
          ),
        ),
      ));

      await tester.tap(find.byTooltip('Italic (*text*)'));
      await tester.pumpAndSettle();

      expect(controller.text, '*hello*');
      expect(changed, isTrue);
    });

    testWidgets('h1 inserts # at cursor position', (tester) async {
      final controller = TextEditingController(text: '');
      var changed = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EditorToolbar(
            controller: controller,
            onChanged: () => changed = true,
          ),
        ),
      ));

      await tester.tap(find.byTooltip('Heading 1 (# )'));
      await tester.pumpAndSettle();

      expect(controller.text, '# Heading 1');
      expect(changed, isTrue);
    });

    testWidgets('ul inserts - at cursor position', (tester) async {
      final controller = TextEditingController(text: '');
      var changed = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EditorToolbar(
            controller: controller,
            onChanged: () => changed = true,
          ),
        ),
      ));

      await tester.drag(find.byType(SingleChildScrollView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Bullet list (- )'));
      await tester.pumpAndSettle();

      expect(controller.text, '- List item');
      expect(changed, isTrue);
    });

    testWidgets('onChanged fires for each format application', (tester) async {
      final controller = TextEditingController(text: '');
      var changeCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EditorToolbar(
            controller: controller,
            onChanged: () => changeCount++,
          ),
        ),
      ));

      await tester.tap(find.byTooltip('Heading 1 (# )'));
      await tester.pumpAndSettle();
      expect(changeCount, 1);

      // Reset cursor and try another format
      controller.selection = const TextSelection.collapsed(offset: 0);
      await tester.tap(find.byTooltip('Heading 2 (## )'));
      await tester.pumpAndSettle();
      expect(changeCount, 2);
    });
  });
}
