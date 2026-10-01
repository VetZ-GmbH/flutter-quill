# VetZ flutter_quill patch stack

`vetz/main` = upstream `e880534f` (11.6.0 release commit) + the patches below.
Each patch is one topic, prefixed `[vetz]`. Rebase the stack onto a newer upstream
tag to update; never merge upstream into it.

Base: `e880534f8750072c879fecd72ada72d0902bc5e8` — `chore(release): prepare to publish 11.6.0`, described as `v11.5.1-13-ge880534f` (no `v11.6.0` tag in this fork yet).

| # | Patch (`[vetz]` prefix dropped) | Files | Reason / ticket | Upstream status |
|---|---|---|---|---|
| 1 | fix: web focus traversal | `lib/src/editor/editor.dart` | Removes a `KeyboardListener` that added an extra Tab stop, breaking web focus traversal. | Upstream PR [#2648](https://github.com/singerdmx/flutter-quill/pull/2648) — track; drop patch once merged upstream. |
| 2 | fix: drag selection does not request focus on desktop | `lib/src/editor/raw_editor/raw_editor_state.dart` | Drag-selection on desktop did not request editor focus. | Fork-only. Ladegeraet/flutter-quill issue #1. No upstream PR yet. |
| 3 | fix: cursor delay on first focus when dirty | `lib/src/editor/raw_editor/raw_editor_state.dart` | Cursor stayed faded on first focus when the editor was already dirty; restarts the blink timer at full opacity. | Fork-only. VetZ ticket #49972. No upstream PR. |
| 4 | feat: opt-in flush list indents on DefaultListBlockStyle | `lib/src/editor/widgets/default_styles.dart`, `lib/src/editor/widgets/text/text_block.dart`, `lib/src/editor/raw_editor/builders/leading_block_builder.dart`, `test/editor/flush_list_indents_test.dart` | VetZ ticket #52640. `flushListIndents` (default `false` = upstream behavior): ul/ol gutters are measured from the actually rendered markers (carried counters, per-level alphabets, text scaling, per-line size overrides) so first-level lists sit flush-left and wide markers never clip. | Fork-only. Candidate for upstream submission. |

## Notes

- The former patch 4 (`chore: point flutter_quill_test at fork git ref`) was dropped
  in r2 via a revert commit — `flutter_quill_test` depends on hosted `flutter_quill`
  again, as upstream does. The commit pair nets to zero; it was kept through the r3 rebase and can be dropped together.
- Patches deliberately do NOT touch `CHANGELOG.md`: upstream edits it in every
  release, making it a permanent rebase-conflict magnet. Changelog entries are
  written in the upstream PR when a patch is submitted, not carried in the stack.
  (The previous private-fork pin carried one such hunk; it was dropped here — the
  only content difference vs. the old pin, docs-only.)
- r3 rebased the stack from `ae53f185` (v11.5.1 + 3) onto the 11.6.0 release commit
  `e880534f`. Patch 4 conflicted in `text_block.dart` with upstream #2733
  (`showCodeBlockLineNumbers`): the flush gutter now falls back to upstream's
  `horizontalSpacingForBlock`, and code blocks take upstream's `fontSize / 2` leading
  padding.
