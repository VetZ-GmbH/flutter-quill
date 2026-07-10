# VetZ flutter_quill patch stack

`vetz/main` = upstream `ae53f185` (v11.5.1 + 3 upstream commits) + the patches below.
Each patch is one topic, prefixed `[vetz]`. Rebase the stack onto a newer upstream
tag to update; never merge upstream into it.

Base: `ae53f1854262ee50b12186c7fdb7aff78e21da1b` — `fix: normalize list point spacing when toggling RTL formatting (#2745)`, described as `v11.5.1-3-gae53f185`.

| # | Patch (`[vetz]` prefix dropped) | Files | Reason / ticket | Upstream status |
|---|---|---|---|---|
| 1 | fix: web focus traversal | `lib/src/editor/editor.dart` | Removes a `KeyboardListener` that added an extra Tab stop, breaking web focus traversal. | Upstream PR [#2648](https://github.com/singerdmx/flutter-quill/pull/2648) — track; drop patch once merged upstream. |
| 2 | fix: drag selection does not request focus on desktop | `lib/src/editor/raw_editor/raw_editor_state.dart` | Drag-selection on desktop did not request editor focus. | Fork-only. Ladegeraet/flutter-quill issue #1. No upstream PR yet. |
| 3 | fix: cursor delay on first focus when dirty | `lib/src/editor/raw_editor/raw_editor_state.dart` | Cursor stayed faded on first focus when the editor was already dirty; restarts the blink timer at full opacity. | Fork-only. VetZ ticket #49972. No upstream PR. |
| 4 | chore: point flutter_quill_test at fork git ref | `flutter_quill_test/pubspec.yaml` | Repoints the in-repo `flutter_quill_test` sub-package's `flutter_quill` dep from `^11.0.0` to the fork git ref. Test/dev plumbing only. | Fork-only, **not consumed by One.frontend**. Candidate for deletion — see note. |

## Notes

- Patch 4 is not a product fix; it only rewires the `flutter_quill_test` sub-package's
  own `flutter_quill` dependency to a fork git ref. One.frontend does consume
  `flutter_quill_test` from this repo, but overrides `flutter_quill` workspace-wide,
  so this patch is inert for production. Kept so the migration stays code-identical
  to the previous pin. Candidate to drop in r2.
- Patches deliberately do NOT touch `CHANGELOG.md`: upstream edits it in every
  release, making it a permanent rebase-conflict magnet. Changelog entries are
  written in the upstream PR when a patch is submitted, not carried in the stack.
  (The previous private-fork pin carried one such hunk; it was dropped here — the
  only content difference vs. the old pin, docs-only.)
- Base is 3 upstream commits past the `v11.5.1` tag (Dart 3.12 migration, format,
  RTL list-spacing fix). Those are genuine upstream commits, so `vetz/main` starts at
  `ae53f185`, not at the tag. A future rebase onto the next release tag will absorb them.
