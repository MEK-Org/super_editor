import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group('SuperEditor > Markdown Table >', () {
    test(
      'preserves smaller natural columns before sharing remaining width',
      () {
        expect(calculateAdaptiveTableColumnWidths([60, 120, 900], 600), [
          60,
          120,
          420,
        ]);
      },
    );

    test('keeps a naturally narrow table narrow', () {
      expect(calculateAdaptiveTableColumnWidths([60, 120], 600), [60, 120]);
    });

    testWidgetsOnAllPlatforms(
      'lays out read-only cell text without table-wide scaling',
      (tester) async {
        await _pumpTestApp(tester);

        // Tables must assign usable widths to cells and wrap there. A FittedBox
        // transforms the whole table instead, which shrinks its font and makes
        // native text selection inaccurate.
        expect(find.byType(FittedBox), findsNothing);
        expect(find.byType(SelectionArea), findsOneWidget);
      },
    );

    testWidgetsOnAllPlatforms('copies cell text in table reading order', (
      tester,
    ) async {
      Map<String, dynamic>? clipboard;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboard = Map<String, dynamic>.from(call.arguments as Map);
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await _pumpTestApp(tester);

      final selectionArea = tester.state<SelectionAreaState>(
        find.byType(SelectionArea),
      );
      selectionArea.selectableRegion.selectAll();
      final copy = selectionArea.selectableRegion.contextMenuButtonItems
          .firstWhere((item) => item.type == ContextMenuButtonType.copy);
      copy.onPressed!.call();
      await tester.pump();

      expect(clipboard!['text'], 'Header 1Header 2Cell 1Cell 2Cell 3Cell 4');
    });

    group('gestures >', () {
      testWidgetsOnAllPlatforms(
        'places caret at left edge when tapping at the left side',
        (tester) async {
          await _pumpTestApp(tester, enableCellTextSelection: false);

          // Tap close to the left edge of the table to place the caret
          // upstream on the table.
          await tester.tapAt(
            tester.getTopLeft(find.byType(MarkdownTableComponent)) +
                const Offset(20, 20),
          );
          await tester.pump();

          // Ensure the caret is placed at the upstream side of the table.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: SuperEditorInspector.findDocument()!.first.id,
                nodePosition: const UpstreamDownstreamNodePosition.upstream(),
              ),
            ),
          );

          // Allow the long press timer to resolve.
          await tester.pumpAndSettle();
        },
      );

      testWidgetsOnAllPlatforms(
        'places caret at right edge when tapping at the right side',
        (tester) async {
          await _pumpTestApp(tester, enableCellTextSelection: false);

          // Tap close to the right edge of the table to place the caret
          // downstream on the table.
          await tester.tapAt(
            tester.getTopRight(find.byType(MarkdownTableComponent)) +
                const Offset(-20, 20),
          );
          await tester.pump();

          // Ensure the caret is placed at the downstream side of the table.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: SuperEditorInspector.findDocument()!.first.id,
                nodePosition: const UpstreamDownstreamNodePosition.downstream(),
              ),
            ),
          );

          // Allow the long press timer to resolve.
          await tester.pumpAndSettle();
        },
      );

      testWidgetsOnAllPlatforms(
        'places an expanded selection when double tapping',
        (tester) async {
          await _pumpTestApp(tester, enableCellTextSelection: false);

          // Double tap in the middle of the table to select the entire table.
          await tester.tapAt(
            tester.getCenter(find.byType(MarkdownTableComponent)),
          );
          await tester.pump(kTapMinTime);
          await tester.tapAt(
            tester.getCenter(find.byType(MarkdownTableComponent)),
          );
          await tester.pump(kTapMinTime);

          // The entire table should be selected.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            DocumentSelection(
              base: DocumentPosition(
                nodeId: SuperEditorInspector.findDocument()!.first.id,
                nodePosition: const UpstreamDownstreamNodePosition.upstream(),
              ),
              extent: DocumentPosition(
                nodeId: SuperEditorInspector.findDocument()!.first.id,
                nodePosition: const UpstreamDownstreamNodePosition.downstream(),
              ),
            ),
          );
        },
      );
    });
  });
}

Future<void> _pumpTestApp(
  WidgetTester tester, {
  bool enableCellTextSelection = true,
}) async {
  await tester //
      .createDocument()
      .fromMarkdown('''
| Header 1 | Header 2 |
|---|---|
| Cell 1 | Cell 2 |
| Cell 3 | Cell 4 |''') //
      .withAddedComponents([
        MarkdownTableComponentBuilder(
          fit: TableComponentFit.adaptive,
          enableCellTextSelection: enableCellTextSelection,
        ),
      ]) //
      .pump();
}
