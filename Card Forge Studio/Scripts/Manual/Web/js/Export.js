'use strict';
/* The editor only opens the native export window. Saved manual files are read
   directly by Lua; no rendered document or export settings cross this bridge. */
(() => {
	/** Opens the shared native window after checking local authoring drafts. */
	document.getElementById('open-manual-export').addEventListener('click', () => {
		if (window.CFSManual.hasDrafts()) {
			showNotice('Save your manual-editor changes before opening Manual Export.', true);
			return;
		}
		window.location.href = 'cfsmanual://export';
	});
})();
