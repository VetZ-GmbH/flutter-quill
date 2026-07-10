import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart';
// TextLine is internal; import the src file directly (same convention as
// editor_test.dart importing src/l10n/...). Its render box left edge marks
// where the list body text starts (== the computed gutter).
import 'package:flutter_quill/src/editor/widgets/text/text_line.dart';
import 'package:flutter_test/flutter_test.dart';

/// Paragraph font size used by [DefaultStyles.getInstance] (`baseStyle`).
const double _fontSize = 16;

/// One list item: text run + a block-attribute newline.
List<Map<String, dynamic>> _item(
  String text, {
  required String list,
  int? indent,
  String? size,
}) {
  final textOp = <String, dynamic>{'insert': text};
  if (size != null) {
    textOp['attributes'] = <String, dynamic>{'size': size};
  }
  final attrs = <String, dynamic>{'list': list};
  if (indent != null) attrs['indent'] = indent;
  return [
    textOp,
    {'insert': '\n', 'attributes': attrs},
  ];
}

/// Pumps a read-only editor rendering [delta]. When [flush] the default `lists`
/// style is copied with `flushListIndents: true`; everything else stays default.
Future<void> _pumpEditor(
  WidgetTester tester, {
  required List<Map<String, dynamic>> delta,
  required bool flush,
  double textScale = 1.0,
}) async {
  final controller = QuillController(
    document: Document.fromJson(delta),
    selection: const TextSelection.collapsed(offset: 0),
    readOnly: true,
  );
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            final custom = flush
                ? DefaultStyles(
                    lists: DefaultStyles.getInstance(
                      context,
                    ).lists!.copyWith(flushListIndents: true),
                  )
                : null;
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: SizedBox(
                width: 600,
                height: 600,
                child: QuillEditor.basic(
                  controller: controller,
                  config: QuillEditorConfig(customStyles: custom),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps the flush editor with STANDALONE leading/list styles (no letterSpacing,
/// as app themes commonly supply) under an ambient [DefaultTextStyle]
/// that adds `letterSpacing`. `Text.build` merges that ambient spacing into every
/// marker, so a gutter measured from the leading style alone under-sizes the box
/// and wraps the widest label's trailing dot into the clipped one-line box
/// (#52640, `10.` → `10`). The fix must measure the marker as it renders.
Future<void> _pumpAmbientDrift(
  WidgetTester tester, {
  required List<Map<String, dynamic>> delta,
  double letterSpacing = 4,
}) async {
  final controller = QuillController(
    document: Document.fromJson(delta),
    selection: const TextSelection.collapsed(offset: 0),
    readOnly: true,
  );
  addTearDown(controller.dispose);

  const standalone = TextStyle(fontSize: _fontSize);
  const custom = DefaultStyles(
    paragraph: DefaultTextBlockStyle(
      TextStyle(fontSize: _fontSize, height: 1.15),
      HorizontalSpacing(0, 0),
      VerticalSpacing(6, 0),
      VerticalSpacing.zero,
      null,
    ),
    leading: DefaultTextBlockStyle(
      standalone,
      HorizontalSpacing(0, 0),
      VerticalSpacing.zero,
      VerticalSpacing.zero,
      null,
    ),
    lists: DefaultListBlockStyle(
      standalone,
      HorizontalSpacing(0, 0),
      VerticalSpacing(6, 0),
      VerticalSpacing.zero,
      null,
      null,
      flushListIndents: true,
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DefaultTextStyle.merge(
          style: TextStyle(letterSpacing: letterSpacing),
          child: SizedBox(
            width: 600,
            height: 600,
            child: QuillEditor.basic(
              controller: controller,
              config: const QuillEditorConfig(customStyles: custom),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// No-clip oracle: every default list marker's RenderParagraph must be at least
/// as wide as its minimum-intrinsic (un-wrapped) width — otherwise the label is
/// visually clipped inside its tight leading box.
void _expectNoClip(WidgetTester tester) {
  for (final points in [
    find.byType(QuillNumberPoint),
    find.byType(QuillBulletPoint),
  ]) {
    final count = tester.widgetList(points).length;
    for (var i = 0; i < count; i++) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: points.at(i), matching: find.byType(RichText)),
      );
      final minWidth = paragraph.getMinIntrinsicWidth(double.infinity);
      expect(
        minWidth,
        lessThanOrEqualTo(paragraph.size.width + 0.01),
        reason:
            'marker clipped: minIntrinsic=$minWidth > box=${paragraph.size.width}',
      );
    }
  }
}

/// Global left x of every rendered body line, in document order.
List<double> _bodyLefts(WidgetTester tester) => [
  for (var i = 0; i < tester.widgetList(find.byType(TextLine)).length; i++)
    tester.getTopLeft(find.byType(TextLine).at(i)).dx,
];

/// Content left of the block = left edge of a leading widget (laid out at x=0
/// of the line). Same for every line.
double _contentLeft(WidgetTester tester) {
  final leading = find.byType(QuillNumberPoint).evaluate().isNotEmpty
      ? find.byType(QuillNumberPoint)
      : find.byType(QuillBulletPoint);
  return tester.getTopLeft(leading.first).dx;
}

void main() {
  group('flushListIndents', () {
    // 1. Default-off pin — locks today's exact fontSize*2 geometry.
    testWidgets('case 1: default-off pins today exact gutters', (tester) async {
      await _pumpEditor(
        tester,
        flush: false,
        delta: [
          ..._item('A', list: 'ordered'),
          ..._item('B', list: 'ordered'),
          ..._item('C', list: 'ordered', indent: 1),
          ..._item('D', list: 'bullet'),
        ],
      );

      final left = _contentLeft(tester);
      final body = _bodyLefts(tester);
      // ol l0 count=2 -> numberPointWidthBuilder(16,2) = 32.
      expect(body[0] - left, closeTo(_fontSize * 2, 0.5)); // A
      expect(body[1] - left, closeTo(_fontSize * 2, 0.5)); // B
      // ol l1 count=1 -> 32 + fontSize*1 = 48.
      expect(body[2] - left, closeTo(_fontSize * 3, 0.5)); // C
      // ul l0 -> numberPointWidthBuilder(16,1) = 32.
      expect(body[3] - left, closeTo(_fontSize * 2, 0.5)); // D
      // No oracle here: with the wide test font the DEFAULT em-gutters already
      // clip 2-char labels — that is the very bug the flush feature fixes.
    });

    // 2. Flush ul level 0: bullet flush-left, body far left of old 32.
    testWidgets('case 2: flush ul level 0 sits flush-left', (tester) async {
      await _pumpEditor(tester, flush: true, delta: _item('X', list: 'bullet'));

      final left = _contentLeft(tester);
      final bullet = find.text('•');
      final bodyStart = _bodyLefts(tester).single;

      // Flush contract (font-independent): the marker starts at content x~0 and
      // the body follows exactly one end-gap after the marker's right edge.
      expect(
        tester.getTopLeft(bullet).dx - left,
        closeTo(0, 1.0),
        reason: 'bullet must start flush at content x~0',
      );
      expect(
        bodyStart - tester.getTopRight(bullet).dx,
        closeTo(_fontSize / 2, 1.0),
        reason: 'body starts one end-gap after the bullet',
      );
      _expectNoClip(tester);
    });

    // 3. Flush ol level 0: widest label flush-left, ending at gutter-gap.
    testWidgets('case 3: flush ol level 0 right-aligns markers', (
      tester,
    ) async {
      await _pumpEditor(
        tester,
        flush: true,
        delta: [
          ..._item('one', list: 'ordered'),
          ..._item('two', list: 'ordered'),
          ..._item('three', list: 'ordered'),
        ],
      );

      final left = _contentLeft(tester);
      final first = find.text('1.');
      final bodyStart = _bodyLefts(tester).first;
      // All labels are single-digit and equally wide -> each is a widest label,
      // so it starts flush at content x~0 and the body follows one end-gap on.
      expect(
        tester.getTopLeft(first).dx - left,
        closeTo(0, 1.0),
        reason: 'widest label starts flush at content x~0',
      );
      expect(
        bodyStart - tester.getTopRight(first).dx,
        closeTo(_fontSize / 2, 1.0),
        reason: 'body starts one end-gap after the marker',
      );
      _expectNoClip(tester);
    });

    // 4. Nested step == fontSize; nested marker right of parent (AC2).
    testWidgets('case 4: nested step equals fontSize', (tester) async {
      await _pumpEditor(
        tester,
        flush: true,
        delta: [
          ..._item('P', list: 'ordered'),
          ..._item('Q', list: 'ordered', indent: 1),
        ],
      );

      final body = _bodyLefts(tester);
      expect(
        body[1] - body[0],
        closeTo(_fontSize, 0.5),
        reason: 'level-1 body start is exactly one fontSize right of level 0',
      );

      final parentMarker = tester.getTopLeft(find.text('1.')).dx;
      final nestedMarker = tester.getTopLeft(find.text('a.')).dx;
      expect(
        nestedMarker,
        greaterThan(parentMarker + _fontSize * 0.5),
        reason: 'nested marker clearly right of parent',
      );
      _expectNoClip(tester);
    });

    // 5. Carry repro: 9 ol l0, 1 ol l1, 2 ol l0 -> third block renders 10., 11.
    testWidgets('case 5: carried counters render 10. and 11.', (tester) async {
      await _pumpEditor(
        tester,
        flush: true,
        delta: [
          for (var i = 1; i <= 9; i++) ..._item('n$i', list: 'ordered'),
          ..._item('nested', list: 'ordered', indent: 1),
          ..._item('ten', list: 'ordered'),
          ..._item('eleven', list: 'ordered'),
        ],
      );

      expect(find.text('10.'), findsOneWidget);
      expect(find.text('11.'), findsOneWidget);
      _expectNoClip(tester);
    });

    // 6. Alphabet repro: 1 ol l0 + 38 ol l2 -> roman up to xxxviii.
    testWidgets('case 6: level-2 roman labels reach xxxviii.', (tester) async {
      await _pumpEditor(
        tester,
        flush: true,
        delta: [
          ..._item('root', list: 'ordered'),
          for (var i = 1; i <= 38; i++)
            ..._item('r$i', list: 'ordered', indent: 2),
        ],
      );

      expect(find.text('xxxviii.'), findsOneWidget);
      _expectNoClip(tester);
    });

    // 7. Text scaling: bullets + numbers never clip.
    for (final scale in [1.3, 2.0]) {
      testWidgets('case 7: no clip at textScale $scale', (tester) async {
        await _pumpEditor(
          tester,
          flush: true,
          textScale: scale,
          delta: [
            ..._item('bullet', list: 'bullet'),
            for (var i = 1; i <= 12; i++) ..._item('num$i', list: 'ordered'),
          ],
        );
        _expectNoClip(tester);
      });
    }

    // 8. Per-line size override widens the (per-block) gutter, no clip.
    testWidgets('case 8: per-line size override grows gutter', (tester) async {
      // Gutter is computed once per block, so both lines share it — compare the
      // measured gutter of a plain block against one carrying a huge line.
      await _pumpEditor(
        tester,
        flush: true,
        delta: [
          ..._item('a', list: 'ordered'),
          ..._item('b', list: 'ordered'),
        ],
      );
      final plainGutter = _bodyLefts(tester).first - _contentLeft(tester);
      _expectNoClip(tester);

      await _pumpEditor(
        tester,
        flush: true,
        delta: [
          ..._item('a', list: 'ordered'),
          ..._item('b', list: 'ordered', size: 'huge'),
        ],
      );
      final hugeGutter = _bodyLefts(tester).first - _contentLeft(tester);

      expect(
        hugeGutter,
        greaterThan(plainGutter),
        reason: 'an oversized line must widen the block gutter',
      );
      _expectNoClip(tester);
    });

    // 9. Checklists + code blocks unchanged with the flag on.
    testWidgets('case 9: checklists + code blocks identical on/off', (
      tester,
    ) async {
      final delta = [
        ..._item('todo', list: 'unchecked'),
        ..._item('done', list: 'checked'),
        {'insert': 'code line'},
        {
          'insert': '\n',
          'attributes': {'code-block': true},
        },
      ];

      await _pumpEditor(tester, flush: false, delta: delta);
      final offLeft = _contentLeft(tester);
      final offBody = _bodyLefts(tester);

      await _pumpEditor(tester, flush: true, delta: delta);
      final onLeft = _contentLeft(tester);
      final onBody = _bodyLefts(tester);

      expect(onLeft, closeTo(offLeft, 0.01));
      expect(onBody.length, offBody.length);
      for (var i = 0; i < offBody.length; i++) {
        expect(
          onBody[i],
          closeTo(offBody[i], 0.01),
          reason: 'non ul/ol line $i moved with the flag on',
        );
      }
    });

    // 10. Non-list formatting untouched (AC3).
    testWidgets('case 10: non-list formatting identical on/off', (
      tester,
    ) async {
      final delta = [
        {
          'insert': 'bold',
          'attributes': {'bold': true},
        },
        {'insert': '\n'},
        {
          'insert': 'italic',
          'attributes': {'italic': true},
        },
        {'insert': '\n'},
        {
          'insert': 'underline',
          'attributes': {'underline': true},
        },
        {'insert': '\n'},
        {'insert': 'heading'},
        {
          'insert': '\n',
          'attributes': {'header': 1},
        },
      ];

      await _pumpEditor(tester, flush: false, delta: delta);
      final offBody = _bodyLefts(tester);

      await _pumpEditor(tester, flush: true, delta: delta);
      final onBody = _bodyLefts(tester);

      expect(onBody.length, offBody.length);
      for (var i = 0; i < offBody.length; i++) {
        expect(
          onBody[i],
          closeTo(offBody[i], 0.01),
          reason: 'formatted line $i moved with the flag on',
        );
      }
    });

    // 11. Field bug (#52640): a standalone leading style (no letterSpacing) under
    // an ambient DefaultTextStyle that adds letterSpacing. The rendered markers
    // are wider than a naive leading-style measurement, so the gutter must resolve
    // the ambient style just like Text does — otherwise `10.` clips to `10`.
    testWidgets('case 11: ambient letterSpacing does not clip 10.', (
      tester,
    ) async {
      await _pumpAmbientDrift(
        tester,
        delta: [for (var i = 1; i <= 10; i++) ..._item('i$i', list: 'ordered')],
      );
      expect(find.text('10.'), findsOneWidget);
      _expectNoClip(tester);
    });

    // 12. Same ambient drift on the ul path — the shared style resolution must
    // size the bullet gutter from the rendered (widened) marker too.
    testWidgets('case 12: ambient letterSpacing does not clip bullets', (
      tester,
    ) async {
      await _pumpAmbientDrift(
        tester,
        delta: [for (var i = 1; i <= 5; i++) ..._item('b$i', list: 'bullet')],
      );
      _expectNoClip(tester);
    });
  });
}
