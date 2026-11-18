# Studio Manual Editor

Adapter.lua hosts the original admin HTML/CSS/JavaScript in Studio's Edge WebView. All runtime UI files are installed under this folder. The old PHP prototype is not a runtime dependency and no PHP server is started.

## Organization

- Adapter.lua: native window, explicit Edge backend, temporary .html document, game binding, close protection and shared WindowState persistence.
- Bridge.lua: bounded authoring requests through document-title events, with asynchronously published reply files. Export does not use this transport.
- Services.lua: active-game snapshots and whitelisted filesystem transactions.
- Documents.lua: staged saves, conflict checks, content-file create/rename/delete and order maintenance.
- FontCSS.lua: existing Studio FontStyle.Parse and INI reader APIs translated to web font classes; no font loading, scanning or management.
- Export.lua: native export coordinator; reads saved manual sources directly from disk, validates settings and prepares Web/PDF jobs.
- Document.lua and Markdown.lua: Lua document assembly and manual Markdown rendering, including styles, glossary definitions, section order, navigation and quicksheets.
- Exporter.lua: staged assets/output replacement and the isolated PDF browser worker. PDF preview inputs remain private to the native window.
- ../Windows/ManualExport.lua: shared native Web/PDF export window, supplier settings, native actions/progress and bounded browser preview.
- Lib/dkjson.lua: vendored JSON codec, with its upstream license in the source.
- Web/Editor.html: original admin markup converted from PHP data placeholders to game snapshots.
- Web/css and Web/js: original visual styles and admin behavior, with Studio transport and file-origin adaptations.
- Web/vendor/markdown-it: pinned browser Markdown parser and upstream license.
- Web/images/components: original interface frame artwork used by the original CSS.

The rejected native-widget editor, its private skin and its ordering page have been removed. There is no separate manual Card Preview tab or card rendering worker; Studio's existing card viewer remains unchanged.

## Game ownership

Manual sources stay under FS.Game.Manual: Content, Config, Styles and Images. Exports is its sibling; generated manuals live in Exports/Manual/Web and Exports/Manual/PDF. Studio Docs/Templates/Manual provides missing intro, glossary, order, settings, alternatives, generated CSS placeholder and web override files through the existing FS creation/preparation flow. Existing files are retained. There is no Manual/Fonts collection; editor fonts use OS lookup.

The HTML runtime document is uniquely named in the system temporary directory, has an .html suffix and is removed on close. The native window uses the same WindowState position, size and maximized-state service as Studio's other windows.

Edge document-title callbacks enqueue bridge requests without navigating the page; navigation callbacks handle chapter-open operations and retain the legacy message receiver. A native one-shot timer dispatches them after the browser callback returns: this backend explicitly forbids synchronous RunScript inside its event callbacks. Dispatch is guarded against nested execution, and native close waits for an in-flight dispatch before destroying the browser.

## Connected authoring features

Content editing, multi-selection tag application, previews, content-file management, drag-and-drop/arrows for document order, per-entry glossary editing, alternatives, global delay and rich hover definitions are connected. File renames/deletes maintain order. Deletion requires a warning. Lua rejects stale saves and paths outside the supported manual files.

Named text styles come exclusively from the game's Styles.ini through Studio's existing parser. Edit them with the native game Style Editor. There is no separate manual style-definition editor or CSS override file. The editor's Export tab only opens the native Manual Export window. Game > Manual Export opens or raises the same game-bound window, directly below Manual Editor. Export Old is an informational tab; its old controls no longer run. Native Web/PDF actions stage a complete replacement and install only the requested output folder. Failures before installation preserve the previous output.

Web/js/EditorTools.js supplies the compact selection-help popover, Markdown toolbar, favorite style references and anchor tools. Favorites autosave to Config/editor-settings.json. Favorite buttons clone the current palette rendering. Explicit anchors use the restricted <a id="unique-name"></a> syntax; the destination picker inserts ordinary [text](chapter.md#unique-name) links. Code examples remain literal and arbitrary HTML stays disabled. Existing section markers remain valid targets. Renaming/deleting a content file can still break hand-authored links, as the existing delete warning explains.

Authoring bridge messages do not navigate, reload or unload the editor. Authoring requests retain their existing bounded chunk protocol and draft protection. The export shortcut is a small native navigation action, carrying no document HTML or export settings. Native export results/errors appear in the export window and existing application log.

The native PDF tab reads the supplier catalog from Docs/Templates/Manual/PDF Export/The Game Crafter/Profiles.json. It autosaves each game's preset and numeric fields to Config/export-settings.json through the existing conflict-aware save service. Invalid/conflicting drafts remain protected on close. The catalog contains eleven products with separate 20/40-page booklet variants (seventeen presets). Reference artwork and provenance stay beside the catalog. The native Options button invokes Studio's existing Options action with its current context.

## Verification and review

Current nonvisual checks cover the real saved manual, Lua rendering, standalone Web navigation/glossary behavior, hidden native controls and preview, editor-to-native shortcut, settings validation/conflicts, cancellation and PDF structure. These isolated checks do not establish visual acceptance or behavior inside the user's running Studio session. The user performs visual verification.

Restart Studio after installing these modules: an existing process can retain the old Manual.Adapter module and window in Lua's module cache.

## Export generation

Export.lua reads saved Content, order, styles and glossary configuration directly from disk. Document.lua and Markdown.lua build complete Web/print HTML in Lua. The editor's existing markdown-it renderer remains unchanged for authoring; the Lua renderer supports the manual's headings, paragraphs, nested lists, tables, inline formatting, code, links, images, known styles and restricted explicit anchors. It is not claimed to implement every CommonMark edge case. ExportDocument.js is retained as an unloaded historical reference.

Exporter.lua copies shared CSS/artwork, game Manual/Images (as content-images), in-memory generated game CSS and the game-owned appearance stylesheet. Reader.js selects one chapter at a time, defaults to Intro, and supports expandable contents, previous/next links and quicksheets. Assets use relative URLs. Web output opens directly from index.html without PHP or Studio and uses fonts installed on the reader's OS.

The PDF tab has native supplier/dimension controls and Refresh Preview, Export PDF and View Export actions outside its embedded browser. Refresh Preview prepares local print inputs in Lua; Print.js/Paged.js paginates those files in preview mode without opening a print-control connection. Settings edits mark the preview stale. Preview inputs are owned by that window and released on close.

Export PDF prepares a fresh saved-file snapshot and runs the existing isolated Chromium-family worker. Paged.js completes layout before JavaScript requests PDF creation and delivers the file into the owned staging folder. The published PDF directory contains only Manual.pdf; verified print inputs/browser data are removed. Contents destination-page numbers and document outlines are generated by the print pipeline. Layout still differs from the original ReportLab renderer; exact visual parity is not claimed.

PDF generation requires installed Chrome, Chromium or Edge; an executable in another location can be selected with CFS_MANUAL_PDF_BROWSER. Windows, common Linux and macOS locations are recognized. The browser runs headless with its own temporary profile and no PHP. Native export actions are guarded against overlapping jobs and keep processing native events while waiting. Closing/shutdown can cancel the owned job; prior published output is preserved on cancellation. PDF dimensions include configured bleed and mirrored margins. Ordinary links remain in PDF; hover behavior remains Web-only. Supplier cover/spine generation, raster-page export and PDF TrimBox/BleedBox postprocessing are not implemented. DPI is retained for future raster output.

The resumed Windows checks generated the current full 212-page PDF, verified saved page dimensions, contents page numbers, outline entries and link annotations, and exercised Web output replacement and PDF cancellation in isolated fixtures. Linux/macOS execution and final live visual/print layout remain unverified.

## Historical handoff — 2026-11-16 — interrupted implementation

This records the earlier interruption. The user subsequently authorized resuming in the same chat; the current result is recorded in the resumed handoff below. Historical test results and limitations here describe the interrupted state only.

### Agreed design and permissions

- Keep the existing website/editor authoring experience.
- One shared native Manual Export window, reachable from the editor Export tab and from Game > Manual Export immediately below Manual Editor.
- Native Web and PDF tabs, with settings and actions outside a bounded PDF browser preview. Include Export, View Export and the existing application Options action.
- Lua reads saved manual files directly and builds complete Web/print inputs on disk. No rendered manual or export settings are transferred through the editor's chunked bridge.
- Latest approved PDF approach: embedded browser preview plus the existing isolated Chromium-family print worker using JavaScript/Paged.js on prepared local files. Earlier discussion of replacing the PDF writer with a native library was superseded by this approved approach.
- The user approved creating Windows/ManualExport.lua, Manual/Export.lua, Manual/Document.lua and Manual/Markdown.lua; editing Windows/Main.lua, Manual/Adapter.lua, Manual/Exporter.lua, Manual/Services.lua, Manual/README.md, Manual/Web/Editor.html, Manual/Web/js/Export.js, Manual/Web/js/host.js and Manual/Web/js/Print.js. Paths are relative to Card Forge Studio/Scripts.
- Standing rules require file-specific permission, preservation of existing work, no scope expansion and no agents. The user performs visual review.

### Current working changes — not a completed feature

Created:
- Windows/ManualExport.lua: native Web/PDF notebook, PDF settings/presets, bounded browser preview, native export/preview/view/options actions, autosave/conflict handling, close/cancellation handling and WindowState integration.
- Manual/Export.lua: reads sources and settings from disk, validates/saves settings, calls document builder and staging/print service.
- Manual/Document.lua: Lua port of Web/print document assembly, canonical sections, contents, quicksheets, styles and glossary data.
- Manual/Markdown.lua: new Lua Markdown renderer. It needs substantial parity/edge-case verification against the editor's markdown-it renderer; no complete Markdown compatibility claim is justified.

Modified:
- Windows/Main.lua: shared Manual Export window action/menu entry, editor callback and close handling on game transitions/shutdown.
- Manual/Adapter.lua: editor shortcut queues cfsmanual://export to the native action; exposes existing reported draft state.
- Manual/Services.lua: removed export dispatch and export settings/preset payloads from editor services.
- Manual/Web/Editor.html: Export tab now has Open Manual Export; Export Old remains as an informational tab; no active ExportDocument.js script reference.
- Manual/Web/js/Export.js: reduced to the native-window shortcut with local draft protection.
- Manual/Web/js/host.js: removed export HTML assembly entry point; exposed local draft query.
- Manual/Web/js/Print.js: added preview URL mode that paginates without opening the worker protocol and reports ready/error through document title; normal worker path remains.
- Manual/Exporter.lua: added retained PDF preview staging/cleanup and support for CSS from the Lua snapshot; existing staged replacement and isolated browser worker retained.

The previously approved Open Options button test was confirmed working by the user before this larger migration. That confirmation does NOT verify these subsequent changes.

### Verification actually performed

- Lua source compilation passed for the new Markdown, Document, Export and ManualExport modules and modified Exporter, Services, Adapter and Main modules at the time of the check.
- JavaScript syntax checks passed for modified Export.js, host.js and Print.js.
- An isolated test read the real Skystrike manual sources without writing to them: 32 documents, 409 canonical sections.
- A few inline smoke assertions passed before staging: bold formatting, known nested styles, code isolation, explicit anchor continuation and rejection of executable links/image traversal.
- Lua generated a Web HTML document and a JSON snapshot in the temporary test folder below.
- Full Web staging FAILED at Manual/Exporter.lua's wx.wxFileName.Mkdir export-root assertion. Consequently no successful new end-to-end Web export, PDF preview, PDF generation, native window interaction or visual verification was established.
- A later isolated probe showed wx.wxMkdir could create that same temporary Manual folder and io.open could write a probe file. This suggests an API/argument/path distinction worth investigating, but no cause or fix was proved.

### Exact stop point / outstanding work

- Last diagnostic attempted to compare wx.wxFileName.Mkdir with default arguments, explicit 511 permissions and wxPATH_MKDIR_FULL, including an already-existing directory. The tool call did not return a completed result before the user stopped work. Its functions execution cell (48) was terminated. Do not claim the underlying native process is confirmed exited; it was not independently checked.
- Temporary test root: C:/Users/CS/AppData/Local/Temp/cfs-native-manual-1c3ef55576774fce8f3e2137ee15372b. Contains check.lua, lua-web.html, snapshot.json and later diagnostic material. These are scratch evidence, not published game outputs.
- Tests must run with Studio Bin as the working directory for reliable wx DLL dependency resolution. One root-directory probe failed to load wx and did not diagnose the staging issue.
- Resolve the staging API failure within the already approved file scope only after authorization to resume.
- Review all changes carefully, especially Markdown rendering fidelity, styles/glossary lookup, PDF preview/worker behavior, settings conflicts, cancellation, window lifecycle and preservation of unrelated Web/PDF outputs.
- Run isolated end-to-end tests before calling the feature complete. Current changes are unfinished and should not be presented as ready for user testing.
- No game source files or live game exports were intentionally written by the completed test commands. No commits or pushes were made by this task.

## Resumed handoff — 2026-11-16 — implementation installed; isolated Windows checks passed

The user authorized resuming the interrupted work in this chat. The earlier interrupted-state limitations above are historical. This task is now stopping after implementation and the checks below; no additional work, commits, deployment or unrelated changes were requested.

### Result

- Game > Manual Export is directly below Manual Editor. It and the editor's Open Manual Export shortcut use the same game-bound window reference.
- The native window has Web and PDF tabs. PDF settings are beside a bounded embedded browser; Refresh Preview, Export PDF and View Export are native controls outside it. Web has native Export Web/View Export actions. Options invokes the existing application Options action.
- Lua reads saved sources, order, styles, images and glossary configuration directly from disk and assembles the documents. The editor retains its existing authoring renderer and draft handling. No manual HTML or export settings are sent through its chunked bridge.
- The PDF preview paginates local prepared files. PDF export uses fresh Lua-prepared inputs and the existing isolated Chromium/Paged.js worker. This is the user's latest approved design; no new native PDF library or binding was introduced.
- Native settings autosave uses existing conflict-aware saves. Invalid/conflicting drafts are protected. Unsaved authoring drafts block generation. Closing a running export can cancel the owned job, preserving the prior published output.
- Published Web/PDF outputs remain separate. PDF publication contains only Manual.pdf. Preview inputs are private and cleaned up on window close.

### Fixes completed during resume

- Replaced recursive creation through all filesystem ancestors with direct creation under the existing export/staging directories. In the sandbox, wx reported AppData absent while child folders were accessible; that caused the original recursive staging failure.
- Accepted wx's actual Windows temporary staging basename (.PD...) in preview cleanup. Preview cleanup was exercised successfully.
- Corrected glossary-entry discovery to follow the marked Glossary chapter instead of assuming a glossary- ID prefix. Glossary popups now pass the Web check.
- Protected against a settings edit making an in-progress preview appear current, and reset shutdown intent when a close request is declined.
- Kept code-span/fence tabs literal in the Lua Markdown renderer.
- Updated the active README architecture. The unloaded ExportDocument.js remains as a historical reference; it is not part of the new export path.

### Verification evidence

- All eight new/changed Lua modules compiled; all three changed JavaScript files passed syntax checks. Scoped git diff --check passed.
- The saved Skystrike manual yielded 32 documents and 409 canonical sections. Across all 32 documents, Lua and the editor's markdown-it output matched normalized text and the checked paragraph/list/table/heading/code/emphasis element counts. This is current-manual coverage, not complete CommonMark conformance.
- Standalone Web checks passed: default Intro, chapter navigation, quicksheet chooser/selection, return to rulebook, all generated image sources loading, glossary hover definitions, unique generated IDs and no page errors.
- Hidden native fixture passed: Web/PDF notebook, native Web action, existing Options callback, valid settings saves, invalid settings rejection, stale/conflicting saves, authoring-draft guard, three-page embedded PDF preview and clean close.
- The actual editor template/host initialized in a hidden Adapter fixture; Open Manual Export reached its native callback without an export bridge request.
- Native cancellation check passed: the owned window closed after cancelling its worker, and a temporary pre-existing PDF retained its exact bytes.
- Final full-manual PDF generation passed after the glossary correction: 212 pages, 414 x 630 points (matching saved trim plus bleed), title Skystrike Protocol, 80 outline entries and 962 annotations. Contents destination numbers and final credits were present. The published PDF fixture contained only Manual.pdf.
- The final literal-tab change was separately checked; the current manual snapshot contained zero tabs, so that change does not alter the full-manual output checked above.
- Browser/native tests used isolated fixture data outside the execution sandbox after sandboxed Edge failed with access denied/GPU-process startup errors. No live game files or published game exports were written by those fixtures.

### Remaining verification / operating notes

- Restart Studio to load the changed Lua modules and editor assets; an existing process can retain cached modules.
- The real running Studio session and final visual layout were not tested or accepted. Main menu/single-window ownership wiring was source-reviewed; actual hidden editor shortcut and native window paths were exercised separately.
- Linux/macOS runtime execution was not tested. The preview uses the platform WebView backend and PDF generation still requires installed Chrome/Chromium/Edge (or CFS_MANUAL_PDF_BROWSER).
- The Lua Markdown renderer has current-manual and targeted formatting coverage; complete markdown-it/CommonMark equivalence is not claimed. Supplier cover/spine generation, raster output, TrimBox/BleedBox postprocessing and supplier production approval are not added by this task.
- Completed fixture processes were checked: no owned Lua/Edge test process remained before cleanup. Temporary fixture files/outputs were removed after recording these results. Unrelated checkout changes were preserved; no staging, commits or pushes were performed.

## Manual appearance and native styles

Options > Manual Editor edits Manual/Config/Appearance.lua. Blank appearance properties inherit Manual/Styles/Appearance Base.css; artwork stays under Manual/Images/Appearance. Appearance changes update the open preview on Apply. See Docs/Manual Appearance.md for fields and default assets.

SP's six former manual-only styles are now ManualHardLimit, Keyword, ManualNumber, ManualPhase, ManualTitle and ManualValueLimit in Styles.ini. Keyword has alias K; manual content uses K and retains glossary linking. Native CFS definitions control font effects. Banner/quicksheet layout remains in the game appearance files.

These appearance and style-migration changes received source/reference review only. No application or runtime tests were run; the user performs testing. Restart Studio to discard cached modules and regenerate the manual's game-font CSS. Existing published exports are replaced only on the next export.

Explicit named-style syntax is `<:Name>text</:Name>`. It selects a CFS style even when the name matches a built-in tag: `<sup>` is superscript; `<:sup>` is the named style. Content and glossary style buttons use ordinary <Name> tags by default, adding the colon only for reserved names (sup and G). Built-in tags take precedence for those unprefixed names. Unknown explicit names still fail preflight; code examples remain literal.

Web/js/Editing.js supplies content Undo/Redo (up to 200 states), clipboard buttons, Select all and literal Find/Replace. Typing and toolbar mutations share history; external source refresh resets it. Dirty status compares text with the last saved content. No runtime tests were run for these additions.

## Manual performance changes (2026-11-18)

- Options revisions dispatch once per editor page; unchanged appearance CSS is not reapplied by the reply poll.
- Dirty-state messages are sent only on state transitions. A failed request permits a later retry; close protection remains native-owned.
- Successful batch saves send changed record versions and deleted paths. The browser merges these before resolving the save promise. Full snapshots remain for navigation. Source rereads, byte-based conflict checks, staged writes, rollback and external-change detection remain in place.
- Snapshots and exports pass their generated game CSS to appearance rendering. Options reuse one exact-source cache, invalidated by the manual path, Styles.ini, CFG.lua or prior generated CSS bytes.
- Preview glossary state is reused until the authoritative snapshot changes. Repeated occurrences share one rendered definition within each preview.
- Line numbers retain unchanged DOM rows. Edited rows are measured; width, font and wrapping-metric changes invalidate their measurements.
- Undo stores reversible changed spans and selection/scroll metadata instead of a full document per state. The 200-state boundary and save-status comparison remain unchanged.

Verification for this change was source/reference inspection and diff whitespace checks only. No app launch, runtime tests, benchmarks or measured speedup claims were made; user testing remains outstanding.

## Native style aliases (2026-11-18)

- Each Styles.ini section may define `Aliases=K,OtherName`. Aliases resolve case-insensitively to that section, without additional style objects or CSS declarations. Duplicate aliases and collisions with any style name are rejected.
- Style Editor exposes Aliases under Font / Names. Draft editing, Save, import/export and create/rename validate ownership. Duplicate omits aliases; rename retains them. Alias metadata is not inherited. Property inheritance still names canonical sections.
- Native `FontStyle.Get`, `Has`, `Parse`, and `STYLE[name]` accept aliases. `GetNames()` continues to list canonical styles only. Reader adapters without section enumeration retain their existing canonical-only contract.
- Generated CSS carries alias metadata. Web preflight, Lua Markdown, browser preview and manual appearance resolve aliases to canonical classes. Reserved G/sup keep their built-in meanings unless escaped (`<:G>`, `<:sup>`). Aliases resolving to Keyword retain automatic glossary linking.
- Skystrike: renamed ManualKeyword to Keyword without changing its formatting, added Aliases=K, and replaced 2,250 opening/closing tags across 22 manual Markdown files. Updated the saved generated CSS to match. No new K style was created.

Verification: source inspection and diff whitespace checks only. No application launch or runtime tests; user verification remains outstanding.
