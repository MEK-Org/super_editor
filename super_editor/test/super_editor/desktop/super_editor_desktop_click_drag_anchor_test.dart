import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group("Super Editor > desktop > click and drag anchoring >", () {
    testWidgetsOnDesktop("drag anchors at the caret a click at mouse-down would place", (tester) async {
      await _pumpWrappingParagraph(tester);
      final mouseDown = _globalOffsetInCharacter(0, 0.4);

      final clickCaret = await _clickAndReadCaret(tester, mouseDown);
      expect(clickCaret, const TextNodePosition(offset: 0));

      // A browser delivers the first pointermove after mouse-down wherever the
      // pointer already is, which is commonly past the middle of a narrow
      // first character.
      final gesture = await tester.startGesture(mouseDown, kind: PointerDeviceKind.mouse);
      await tester.pump();
      await gesture.moveTo(_globalOffsetInCharacter(1, 0.6));
      await tester.pump();
      await gesture.moveTo(_globalOffsetInCharacter(3, 0.2));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(_selectedOffsets(), (base: clickCaret.offset, extent: 3));
    });

    testWidgetsOnDesktop("drag anchors at mouse-down when dragging upstream", (tester) async {
      await _pumpWrappingParagraph(tester);
      final mouseDown = _globalOffsetInCharacter(3, 0.4);

      final gesture = await tester.startGesture(mouseDown, kind: PointerDeviceKind.mouse);
      await tester.pump();
      await gesture.moveTo(_globalOffsetInCharacter(2, 0.4));
      await tester.pump();
      await gesture.moveTo(_globalOffsetInCharacter(0, 0.1));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(_selectedOffsets(), (base: 3, extent: 0));
    });

    testWidgetsOnDesktop("click places caret before a line's first character within 65% of its width", (tester) async {
      await _pumpWrappingParagraph(tester);

      expect(await _clickAndReadCaret(tester, _globalOffsetInCharacter(0, 0.6)), const TextNodePosition(offset: 0));
      expect(await _clickAndReadCaret(tester, _globalOffsetInCharacter(0, 0.7)), const TextNodePosition(offset: 1));
    });

    testWidgetsOnDesktop("click keeps the nearest boundary for characters after the first", (tester) async {
      await _pumpWrappingParagraph(tester);

      expect(await _clickAndReadCaret(tester, _globalOffsetInCharacter(1, 0.4)), const TextNodePosition(offset: 1));
      expect(await _clickAndReadCaret(tester, _globalOffsetInCharacter(1, 0.6)), const TextNodePosition(offset: 2));
    });

    testWidgetsOnDesktop("click biases toward the first character of a wrapped line", (tester) async {
      await _pumpWrappingParagraph(tester);
      final secondLineStart = _findSecondLineStart();

      expect(
        await _clickAndReadCaret(tester, _globalOffsetInCharacter(secondLineStart, 0.6)),
        TextNodePosition(offset: secondLineStart),
      );
      expect(
        await _clickAndReadCaret(tester, _globalOffsetInCharacter(secondLineStart, 0.7)),
        TextNodePosition(offset: secondLineStart + 1),
      );
    });

    testWidgetsOnDesktop("drag from within 65% of the first character selects it", (tester) async {
      await _pumpWrappingParagraph(tester);
      final mouseDown = _globalOffsetInCharacter(0, 0.6);

      final gesture = await tester.startGesture(mouseDown, kind: PointerDeviceKind.mouse);
      await tester.pump();
      await gesture.moveTo(_globalOffsetInCharacter(0, 0.95));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(_selectedOffsets(), (base: 0, extent: 1));
    });

    testWidgetsOnDesktop("treats a multi-code-unit first grapheme as one character", (tester) async {
      await tester //
          .createDocument()
          .withCustomContent(MutableDocument(nodes: [
            ParagraphNode(id: _nodeId, text: AttributedText("🐢urtles all the way down")),
          ]))
          .withEditorSize(const Size(400, 400))
          .pump();

      // The turtle occupies text offsets 0 and 1.
      expect(await _clickAndReadCaret(tester, _globalOffsetInCharacter(0, 0.6, length: 2)),
          const TextNodePosition(offset: 0));
      expect(await _clickAndReadCaret(tester, _globalOffsetInCharacter(0, 0.9, length: 2)),
          const TextNodePosition(offset: 2));
    });

    testWidgetsOnDesktop("shift-drag still expands from the existing selection base", (tester) async {
      await _pumpWrappingParagraph(tester);
      await tester.placeCaretInParagraph(_nodeId, 6);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      final gesture = await tester.startGesture(_globalOffsetInCharacter(0, 0.6), kind: PointerDeviceKind.mouse);
      await tester.pump();
      await gesture.moveTo(_globalOffsetInCharacter(1, 0.6));
      await tester.pump();
      await gesture.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pumpAndSettle();

      expect(_selectedOffsets(), (base: 6, extent: 2));
    });
  });
}

const _nodeId = "1";

Future<void> _pumpWrappingParagraph(WidgetTester tester) async {
  await tester //
      .createDocument()
      .withSingleParagraph()
      .withEditorSize(const Size(400, 600))
      .pump();
}

/// Returns the text offsets of the current selection, ignoring affinity.
({int base, int extent}) _selectedOffsets() {
  final selection = SuperEditorInspector.findDocumentSelection()!;
  return (
    base: (selection.base.nodePosition as TextNodePosition).offset,
    extent: (selection.extent.nodePosition as TextNodePosition).offset,
  );
}

/// Returns the global offset at [fraction] of the width of the character
/// that starts at [textOffset] and spans [length] code units, vertically
/// centered on its line.
Offset _globalOffsetInCharacter(int textOffset, double fraction, {int length = 1}) {
  final layout = SuperEditorInspector.findDocumentLayout();
  final rect = layout.getRectForSelection(
    DocumentPosition(nodeId: _nodeId, nodePosition: TextNodePosition(offset: textOffset)),
    DocumentPosition(nodeId: _nodeId, nodePosition: TextNodePosition(offset: textOffset + length)),
  )!;
  return layout.getGlobalOffsetFromDocumentOffset(Offset(rect.left + rect.width * fraction, rect.center.dy));
}

int _findSecondLineStart() {
  final layout = SuperEditorInspector.findDocumentLayout();
  Rect rectAt(int offset) => layout.getRectForPosition(
        DocumentPosition(nodeId: _nodeId, nodePosition: TextNodePosition(offset: offset)),
      )!;
  final firstLineTop = rectAt(0).top;
  var offset = 1;
  while (rectAt(offset).top == firstLineTop) {
    offset += 1;
  }
  return offset;
}

Future<TextNodePosition> _clickAndReadCaret(WidgetTester tester, Offset globalOffset) async {
  final gesture = await tester.startGesture(globalOffset, kind: PointerDeviceKind.mouse);
  await gesture.up();
  // Wait out the double-tap window so the next click isn't a double-click.
  await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 1));

  final selection = SuperEditorInspector.findDocumentSelection()!;
  expect(selection.isCollapsed, isTrue);
  final position = selection.extent.nodePosition as TextNodePosition;
  return TextNodePosition(offset: position.offset);
}
