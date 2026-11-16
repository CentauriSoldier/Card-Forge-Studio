# Studio Manual Editor

Adapter.lua hosts the original admin HTML/CSS/JavaScript in Studio's Edge WebView. All runtime UI files are installed under this folder. The old PHP prototype is not a runtime dependency and no PHP server is started.

## Organization

- Adapter.lua: native window, explicit Edge backend, temporary .html document, game binding, close protection and shared WindowState persistence.
- Bridge.lua: bounded chunked JSON requests through document-title events, with RunScript responses.
- Services.lua: active-game snapshots and whitelisted filesystem transactions.
- Documents.lua: staged saves, conflict checks, content-file create/rename/delete and order maintenance.
- FontCSS.lua: existing Studio FontStyle.Parse and INI reader APIs translated to web font classes; no font loading, scanning or management.
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

Content editing, multi-selection tag application, previews, content-file management, drag-and-drop/arrows for document order, web-only style form and CSS saves, per-entry glossary editing, alternatives, global delay and rich hover definitions are connected. File renames/deletes maintain order. Deletion requires a warning. Lua rejects stale saves and paths outside the supported manual files.

Game font CSS is generated automatically through Studio's existing parser; web-only overrides remain separate. The Export tab replaces prototype script/version controls with PDF and Web sections. Both buttons call the game-bound Exporter.lua service. It stages a complete replacement, installs only the requested Web or PDF folder, then removes the old folder. Failures before installation preserve the previous output.

Web/js/EditorTools.js supplies the compact selection-help popover, Markdown toolbar, favorite style references and anchor tools. Favorites autosave to Config/editor-settings.json. Favorite buttons clone the current palette rendering. Web-style renames and deletes update favorite references in the same filesystem batch. Explicit anchors use the restricted <a id="unique-name"></a> syntax; the destination picker inserts ordinary [text](chapter.md#unique-name) links. Code examples remain literal and arbitrary HTML stays disabled. Existing section markers remain valid targets. Renaming/deleting a content file can still break hand-authored links, as the existing delete warning explains.

Internal bridge messages do not navigate, reload or unload the editor. Requests wait for DOMContentLoaded, use 2048-character encoded chunks (below Chromium's 4096-character native title limit), validate each received chunk length, use sequential acknowledgments, and report a timeout rather than waiting silently forever. Export results/errors appear in the top message bar, and native export attempts are recorded through the existing application logger.

Web/js/Export.js loads the supplier catalog from Docs/Templates/Manual/PDF Export/The Game Crafter/Profiles.json through Lua snapshots. It autosaves each game's preset and numeric fields to Config/export-settings.json, validates the content area and retains failed or invalid drafts under close protection. The catalog contains eleven products with separate 20/40-page booklet variants (seventeen presets). Reference artwork and provenance live beside the catalog. No template or font data is copied into a second game collection.

## Verification and review

Nonvisual checks cover template/script initialization using Skystrike's actual read-only snapshot, authoring actions in an isolated DOM/filesystem mock, staged Lua saves, version/path rejection, chunked Unicode transport and source compilation. No live browser clicks or visual comparison have been verified by the agent; the user performs visual verification.

Restart Studio after installing these modules: an existing process can retain the old Manual.Adapter module and window in Lua's module cache.

## Export generation

Exporter.lua copies shared CSS/artwork, game Manual/Images (as content-images), generated game CSS and web-only CSS. ExportDocument.js reuses the safe Markdown/style/glossary renderer but ports the original PHP LoadManual, BuildNavigation and page.php reader assemblies instead of reusing preview boxes. Reader.js selects one chapter at a time, defaults to Intro, and supports expandable contents, previous/next links and quicksheet views. Reader.css maps the prototype font-file aliases to actual OS families (Suggested 3D and Calibri). Assets use relative URLs. Web opens directly from index.html without PHP or Studio. It uses fonts installed on the reader's OS; it does not bundle fonts or manage installation.

PDF staging HTML, CSS, scripts and images are deleted after the PDF is verified; the published PDF directory contains only Manual.pdf. Print.css overrides the prototype white browser-print fallback with the original renderer's dark paper, heading colors, body metrics, table styling, cover/contents structure and repeating decoration. The browser engine still has different pagination from the original ReportLab renderer, and the linked contents currently has no generated destination-page numbers. Exact visual parity is not claimed.

PDF generation requires installed Chrome, Chromium or Edge; an executable in another location can be selected with CFS_MANUAL_PDF_BROWSER. Windows, common Linux and macOS locations are recognized. The browser runs headless with its own temporary profile and no PHP. The guarded native dispatcher waits for completion; the editor is unavailable during this print step. PDF page dimensions include the configured bleed; mirrored inside/outside margins are applied from trim edges. PDF preserves ordinary links; hover behavior remains Web-only. This is not a supplier cover/spine generator or raster-page exporter. DPI is retained for future raster output. No PDF TrimBox or BleedBox postprocessing is currently performed.

Isolated Windows checks generated real Web output and a two-page PDF, verified page dimensions, text and internal link annotations, and verified same-type replacement without altering unrelated exports. Cross-platform browser execution and final visual/print layout remain user verification tasks.
