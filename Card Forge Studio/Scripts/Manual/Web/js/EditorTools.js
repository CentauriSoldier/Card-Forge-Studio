'use strict';
/* Content tools retain the original editor selection path. Favorite buttons are
   references cloned from the current palette, never separate style definitions. */
(() => {
	const api = window.CFSManual;
	const path = 'Config/editor-settings.json';
	const palette = document.querySelector('.tag-grid');
	const favorites = document.getElementById('favorite-tags');
	const status = document.getElementById('favorite-status');
	let draft = api.config(path);
	let saving = false;
	let revision = 0;
	let drag = null;

	const editor = document.getElementById('markdown-editor');
	const stack = editor.closest('.markdown-editor-stack');
	const gutter = document.createElement('div');
	const numbers = document.createElement('div');
	const mirror = document.createElement('div');
	gutter.className = 'manual-line-gutter';
	mirror.className = 'manual-line-mirror';
	gutter.setAttribute('aria-hidden', 'true');
	mirror.setAttribute('aria-hidden', 'true');
	gutter.append(numbers);
	stack.append(gutter, mirror);
	gutter.hidden = mirror.hidden = true;
	let lineFrame = 0;
	let readingOptions = false;
	let optionsRevision = 0;

    let lineRows = [], lineText = null, lineMetrics = '';
    /** Retains unchanged rows and measures only edited lines unless wrapping metrics change. */
    function drawLineNumbers() {
        lineFrame = 0;
        if (gutter.hidden || !editor.clientWidth) return;
        const style = getComputedStyle(editor);
        const metrics = [editor.clientWidth, style.font, style.lineHeight, style.letterSpacing, style.tabSize, style.padding, style.wordBreak, style.overflowWrap].join('|');
        const text = editor.value;
        if (text === lineText && metrics === lineMetrics) return;
        const remeasure = metrics !== lineMetrics;
        mirror.style.width = editor.clientWidth + 'px';
        const lines = text.split('\n');
        let first = 0, tail = 0;
        while (first < lines.length && first < lineRows.length && lines[first] === lineRows[first].text) first++;
        while (tail < lines.length - first && tail < lineRows.length - first && lines[lines.length - 1 - tail] === lineRows[lineRows.length - 1 - tail].text) tail++;
        const oldEnd = lineRows.length - tail;
        const retained = lineRows.slice(oldEnd);
        for (const entry of lineRows.slice(first, oldEnd)) { entry.row.remove(); entry.label.remove(); }
        const rows = document.createDocumentFragment(), labels = document.createDocumentFragment(), added = [];
        for (let index = first; index < lines.length - tail; index++) {
            const row = document.createElement('div'), label = document.createElement('div');
            row.textContent = lines[index] || '\u200b'; label.textContent = index + 1;
            rows.append(row); labels.append(label); added.push({text: lines[index], row, label});
        }
        mirror.insertBefore(rows, retained[0]?.row || null); numbers.insertBefore(labels, retained[0]?.label || null);
        lineRows = [...lineRows.slice(0, first), ...added, ...retained];
        for (let index = first + added.length; index < lineRows.length; index++) {
            const value = String(index + 1); if (lineRows[index].label.textContent !== value) lineRows[index].label.textContent = value;
        }
        const changed = remeasure ? lineRows : added;
        const heights = changed.map(entry => entry.row.getBoundingClientRect().height);
        changed.forEach((entry, index) => { entry.label.style.height = heights[index] + 'px'; });
        lineText = text; lineMetrics = metrics;
        numbers.style.transform = 'translateY(' + -editor.scrollTop + 'px)';
    }
	function queueLineNumbers() {
		if (!lineFrame) lineFrame = requestAnimationFrame(drawLineNumbers);
	}
	function applyEditorOptions(settings) {
		const top = editor.scrollTop;
		const left = editor.scrollLeft;
		gutter.hidden = mirror.hidden = !settings.lineNumbers;
		stack.classList.toggle('has-line-numbers', settings.lineNumbers);
		editor.scrollTop = top;
		editor.scrollLeft = left;
		queueLineNumbers();
	}
	document.addEventListener('manual-editor-options', event => {
		if (event.detail.revision <= optionsRevision) return;
		optionsRevision = event.detail.revision;
		applyEditorOptions(event.detail);
	});
	async function readEditorOptions() {
		if (readingOptions) return;
		readingOptions = true;
		try {
			const result = await api.request({action: 'editor-options'});
			if (!optionsRevision) applyEditorOptions(result);
		} catch (error) {
			document.getElementById('admin-notice').textContent = error.message;
		} finally { readingOptions = false; }
	}
	editor.addEventListener('input', queueLineNumbers);
	editor.addEventListener('scroll', () => { numbers.style.transform = 'translateY(' + -editor.scrollTop + 'px)'; });
	new ResizeObserver(queueLineNumbers).observe(editor);
	new MutationObserver(queueLineNumbers).observe(document.getElementById('markdown-selections'), {childList: true});
	readEditorOptions();
    document.fonts?.addEventListener('loadingdone', () => { lineMetrics = ''; queueLineNumbers(); });


	/** Rebuilds references using the exact styled buttons currently in the palette. */
	function display() {
		favorites.replaceChildren();
		const originals = [...palette.querySelectorAll('[data-wrap-style]')];
		for (const name of draft.favorites) {
			const source = originals.find(button => button.dataset.wrapStyle.toLowerCase() === name.toLowerCase());
			if (!source) continue;
			const button = source.cloneNode(true);
			button.hidden = false;
			button.draggable = true;
			button.title = 'Drag back into the style list to remove from Favorites';
			favorites.append(button);
		}
		originals.forEach(button => { button.draggable = true; });
	}

	/** Serializes changed references and retains unsaved data if a native save fails. */
	async function persist() {
		if (saving) return;
		saving = true;
		try {
			let submitted;
			do {
				submitted = revision;
				status.textContent = 'Saving…';
				await api.write({[path]: JSON.stringify(draft, null, '\t') + '\n'});
			} while (submitted !== revision);
			status.textContent = 'Saved';
			api.setSettingsDirty('favorites', false);
		} catch (error) { status.textContent = error.message; }
		finally { saving = false; }
	}

	/** Changes the reference collection and immediately queues its per-game save. */
	function change(name, remove) {
		const existing = draft.favorites.findIndex(value => value.toLowerCase() === name.toLowerCase());
		if (remove && existing >= 0) draft.favorites.splice(existing, 1);
		else if (!remove && existing < 0) draft.favorites.push(name);
		else return;
		revision++;
		api.setSettingsDirty('favorites', true);
		display();
		persist();
	}

	/** Starts a local style-reference drag; foreign drag data is never interpreted. */
	document.addEventListener('dragstart', event => {
		const button = event.target.closest('[data-wrap-style]');
		if (!button || !button.closest('.tag-grid, #favorite-tags')) return;
		drag = {name: button.dataset.wrapStyle, favorite: favorites.contains(button)};
		event.dataTransfer.setData('text/plain', drag.name);
		event.dataTransfer.effectAllowed = 'copyMove';
	});
	for (const zone of [palette, favorites]) {
		zone.addEventListener('dragover', event => {
			if (!drag || zone === palette && !drag.favorite) return;
			event.preventDefault();
			event.dataTransfer.dropEffect = zone === palette ? 'move' : 'copy';
			zone.classList.add('is-drop-target');
		});
		zone.addEventListener('dragleave', event => { if (!zone.contains(event.relatedTarget)) zone.classList.remove('is-drop-target'); });
		zone.addEventListener('drop', event => {
			zone.classList.remove('is-drop-target');
			if (!drag || zone === palette && !drag.favorite) return;
			event.preventDefault();
			change(drag.name, zone === palette);
			drag = null;
		});
	}
	document.addEventListener('dragend', () => { drag = null; palette.classList.remove('is-drop-target'); favorites.classList.remove('is-drop-target'); });

	/** Inserts one editor change through the original input/preview/dirty handlers. */
	function insert(text) {
		const editor = document.getElementById('markdown-editor');
		window.CFSManualEditing?.before();
		editor.setRangeText(text, editor.selectionStart, editor.selectionEnd, 'end');
		editor.focus({preventScroll: true});
		editor.dispatchEvent(new Event('input', {bubbles: true}));
	}

	/** Collects stable, actually rendered targets across the current game's content. */
	function targets() {
		const result = [];
		for (const [file, record] of Object.entries(api.snapshot().files)) {
			if (!/^Content\/.*\.md$/i.test(file)) continue;
			const source = file.slice(8) === document.getElementById('admin-app').dataset.file ? document.getElementById('markdown-editor').value : record.text;
			const container = document.createElement('div');
			container.innerHTML = api.render(source, false);
			container.querySelectorAll('[id]').forEach(node => result.push({file: file.slice(8), id: node.id}));
		}
		return result;
	}

	/** Creates an explicit stable target, rejecting duplicate IDs across documents. */
	document.getElementById('insert-anchor').addEventListener('click', () => {
		const id = prompt('Anchor name (start with a letter; letters, numbers, hyphens and underscores):');
		if (id === null) return;
		if (!/^[A-Za-z][A-Za-z0-9_-]*$/.test(id)) { alert('Use a letter first, then letters, numbers, hyphens or underscores.'); return; }
		if (document.getElementById(id) || targets().some(target => target.id === id)) { alert('That anchor already exists or is reserved by the editor. Choose a unique name.'); return; }
		const editor = document.getElementById('markdown-editor');
		const selected = editor.value.slice(editor.selectionStart, editor.selectionEnd);
		insert('<a id="' + id + '"></a>' + selected);
	});

	/** Offers existing manual targets rather than requiring hand-typed destination IDs. */
	document.getElementById('insert-anchor-link').addEventListener('click', () => {
		const items = targets();
		if (!items.length) { alert('Create an anchor first, or use a section that already has a stable marker.'); return; }
		const dialog = document.createElement('div');
		dialog.className = 'modal fade';
		dialog.tabIndex = -1;
		dialog.innerHTML = '<div class="modal-dialog"><form class="modal-content"><div class="modal-header"><h2 class="modal-title">Link to anchor</h2><button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cancel"></button></div><div class="modal-body"><label class="form-label">Destination<select class="form-select" name="target"></select></label><label class="form-label d-block mt-3">Link text<input class="form-control" name="label" required></label></div><div class="modal-footer"><button type="button" class="btn btn-outline-light" data-bs-dismiss="modal">Cancel</button><button type="submit" class="btn btn-warning">Insert link</button></div></form></div>';
		const select = dialog.querySelector('select');
		items.forEach((target, index) => { const option = document.createElement('option'); option.value = index; option.textContent = target.file + ' — ' + target.id; select.append(option); });
		const editor = document.getElementById('markdown-editor');
		dialog.querySelector('input').value = editor.value.slice(editor.selectionStart, editor.selectionEnd);
		dialog.querySelector('form').addEventListener('submit', event => {
			event.preventDefault();
			const target = items[Number(select.value)];
			const label = dialog.querySelector('input').value.replace(/[\\\[\]]/g, '\\$&');
			insert('[' + label + '](' + encodeURIComponent(target.file) + '#' + target.id + ')');
			bootstrap.Modal.getInstance(dialog).hide();
		});
		dialog.addEventListener('hidden.bs.modal', () => { bootstrap.Modal.getInstance(dialog).dispose(); dialog.remove(); });
		document.body.append(dialog);
		bootstrap.Modal.getOrCreateInstance(dialog).show();
	});
	bootstrap.Popover.getOrCreateInstance(document.getElementById('selection-help'), {trigger: 'hover focus', container: 'body'});
	display();
})();
