'use strict';
const adminApp = document.getElementById('admin-app');
const editor = document.getElementById('markdown-editor');
const notice = document.getElementById('admin-notice');
const saveStatus = document.getElementById('save-status');
let version = adminApp.dataset.version;
let dirty = false;
let savedContent = editor.value;
let glossaryDirty = false;
let previewTimer;
let previewController;

function showNotice(message, error = false) {
	notice.textContent = message;
	notice.className = 'alert ' + (error ? 'alert-danger' : 'alert-success');
}

async function post(action, values = {}, signal) {
	if (signal?.aborted) throw new DOMException('Request aborted.', 'AbortError');
	const result = await window.CFSManual.action(action, values);
	if (signal?.aborted) throw new DOMException('Request aborted.', 'AbortError');
	return result;
}

function changed(event) {
	window.CFSManualEditing?.record(event?.type === 'input');
	dirty = editor.value !== savedContent;
	saveStatus.textContent = dirty ? 'Unsaved changes' : 'Saved';
	clearTimeout(previewTimer);
	previewTimer = setTimeout(preview, 650);
}

async function preview() {
	previewController?.abort();
	previewController = new AbortController();
	try {
		const result = await post('preview', { content: editor.value }, previewController.signal);
		document.getElementById('markdown-preview').innerHTML = result.html;
	} catch (error) {
		if (error.name !== 'AbortError') showNotice(error.message, true);
	}
}

async function save() {
	const button = document.getElementById('save-content');
	button.disabled = true;
	const submitted = editor.value;
	try {
		const result = await post('save', { file: adminApp.dataset.file, content: submitted, version });
		version = result.version;
		savedContent = submitted;
		dirty = editor.value !== savedContent;
		saveStatus.textContent = dirty ? 'Unsaved changes' : 'Saved';
		showNotice(result.message);
	} catch (error) {
		showNotice(error.message, true);
	} finally {
		button.disabled = false;
	}
}

editor.addEventListener('input', changed);
editor.addEventListener('keydown', event => {
	if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 's') {
		event.preventDefault();
		save();
	}
});
document.getElementById('save-content').addEventListener('click', save);
document.getElementById('preview-content').addEventListener('click', preview);
window.addEventListener('beforeunload', event => {
	if (dirty || glossaryDirty || window.CFSManual.hasSettingsDrafts()) { event.preventDefault(); event.returnValue = ''; }
});
document.getElementById('content-file').addEventListener('change', event => {
	if ((dirty || glossaryDirty) && !confirm('Leave this file without saving your changes?')) {
		event.target.value = adminApp.dataset.file;
		return;
	}
	dirty = false;
	glossaryDirty = false;
	window.CFSManual.open(event.target.value);
});
// Adjacent-file navigation uses the dropdown's existing unsaved-change handling.
const contentFile = document.getElementById('content-file');
const previousContent = document.getElementById('previous-content');
const nextContent = document.getElementById('next-content');
function updateContentNavigation() {
	previousContent.disabled = contentFile.selectedIndex <= 0;
	nextContent.disabled = contentFile.selectedIndex < 0 || contentFile.selectedIndex >= contentFile.options.length - 1;
}
for (const [button, step] of [[previousContent, -1], [nextContent, 1]]) {
	button.addEventListener('click', () => {
		const index = contentFile.selectedIndex + step;
		if (index < 0 || index >= contentFile.options.length) return;
		contentFile.selectedIndex = index;
		contentFile.dispatchEvent(new Event('change'));
	});
}
contentFile.addEventListener('change', updateContentNavigation);
updateContentNavigation();
// Additional ranges are tag targets; native typing edits only the active range.
const selectionHighlights = document.getElementById('markdown-selections');
const selectionStatus = document.getElementById('selection-status');
let editorSelections = [];
let selectionBase = [];
let selectingWithPointer = false;
let activeSelection = '';

function selectionKey() {
	return editor.selectionStart + ':' + editor.selectionEnd;
}

function mergeEditorSelections(ranges) {
	const sorted = ranges.filter(range => range.end > range.start)
		.map(range => ({ start: range.start, end: range.end }))
		.sort((a, b) => a.start - b.start || a.end - b.end);
	const merged = [];
	sorted.forEach(range => {
		const previous = merged[merged.length - 1];
		if (previous && range.start < previous.end) previous.end = Math.max(previous.end, range.end);
		else merged.push(range);
	});
	return merged;
}

function drawEditorSelections() {
	const fragment = document.createDocumentFragment();
	let position = 0;
	editorSelections.forEach(range => {
		fragment.append(document.createTextNode(editor.value.slice(position, range.start)));
		const mark = document.createElement('mark');
		mark.textContent = editor.value.slice(range.start, range.end);
		fragment.append(mark);
		position = range.end;
	});
	fragment.append(document.createTextNode(editor.value.slice(position) + '\n'));
	selectionHighlights.replaceChildren(fragment);
	selectionHighlights.style.width = editor.clientWidth + 'px';
	selectionHighlights.style.height = editor.clientHeight + 'px';
	selectionHighlights.scrollTop = editor.scrollTop;
	selectionHighlights.scrollLeft = editor.scrollLeft;
	selectionStatus.textContent = editorSelections.length > 1 ? editorSelections.length + ' selections' : '';
}

function captureEditorSelection(base = [], trim = false) {
	const start = editor.selectionStart;
	let end = editor.selectionEnd;
	const direction = editor.selectionDirection;
	if (trim && start < end) {
		while (end > start && /[ \t]/.test(editor.value[end - 1])) end--;
		if (end === start) end = editor.selectionEnd;
		if (end !== editor.selectionEnd) editor.setSelectionRange(start, end, direction);
	}
	editorSelections = mergeEditorSelections([...base, { start, end }]);
	activeSelection = selectionKey();
	drawEditorSelections();
}

editor.addEventListener('pointerdown', event => {
	if (event.button !== 0) return;
	if (selectionKey() !== activeSelection) captureEditorSelection();
	selectionBase = event.ctrlKey || event.metaKey ? editorSelections.slice() : [];
	selectingWithPointer = true;
	editorSelections = selectionBase.slice();
	drawEditorSelections();
});
document.addEventListener('pointerup', () => {
	if (!selectingWithPointer) return;
	selectingWithPointer = false;
	captureEditorSelection(selectionBase, true);
});
document.addEventListener('pointercancel', () => {
	if (!selectingWithPointer) return;
	selectingWithPointer = false;
	captureEditorSelection();
});
editor.addEventListener('dblclick', () => captureEditorSelection(selectionBase, true));
editor.addEventListener('keyup', event => {
	if (['Control', 'Meta', 'Shift', 'Alt'].includes(event.key)) return;
	if (selectionKey() !== activeSelection || event.key === 'Escape') captureEditorSelection();
});
editor.addEventListener('input', () => {
	selectionBase = [];
	captureEditorSelection();
});
editor.addEventListener('scroll', () => {
	selectionHighlights.scrollTop = editor.scrollTop;
	selectionHighlights.scrollLeft = editor.scrollLeft;
});
new ResizeObserver(drawEditorSelections).observe(editor);

// Delegation keeps saved favorite references on the same selection/wrapping path.
document.addEventListener('mousedown', event => {
	if (event.target.closest('[data-wrap-style], [data-wrap-markdown]')) event.preventDefault();
});
document.addEventListener('click', event => {
		const button = event.target.closest('[data-wrap-style], [data-wrap-markdown]');
		if (!button) return;
		if (selectionKey() !== activeSelection) captureEditorSelection();
		const style = button.dataset.wrapStyle;
		const delimiters = {bold: ['**', '**'], italic: ['*', '*'], code: ['`', '`'], strike: ['~~', '~~'], heading: ['## ', ''], bullet: ['- ', ''], quote: ['> ', '']};
		const pair = delimiters[button.dataset.wrapMarkdown];
		if (!style && !pair) return;
		const prefix = !button.hasAttribute('data-glossary-tag') && ['sup', 'g'].includes(style?.toLowerCase()) ? ':' : '';
		const open = style ? '<' + prefix + style + '>' : pair[0];
		const close = style ? '</' + prefix + style + '>' : pair[1];
		const ranges = mergeEditorSelections(editorSelections.map(range => {
			let { start, end } = range;
			while (start < end && /\s/.test(editor.value[start])) start++;
			while (end > start && /\s/.test(editor.value[end - 1])) end--;
			return { start, end };
		}));
		// Keep empty-caret insertion, but leave whitespace-only selections alone.
		if (!ranges.length && editor.selectionStart !== editor.selectionEnd) return;
		if (!ranges.length) ranges.push({ start: editor.selectionStart, end: editor.selectionEnd });
		const original = editor.value;
		const updatedSelections = [];
		let offset = 0;
		ranges.forEach(range => {
			updatedSelections.push({ start: range.start + offset + open.length, end: range.end + offset + open.length });
			offset += open.length + close.length;
		});
		// One replacement preserves all gaps and prevents shifting later targets.
		const first = ranges[0].start;
		const last = ranges[ranges.length - 1].end;
		let replacement = '';
		let position = first;
		ranges.forEach(range => {
			replacement += original.slice(position, range.start) + open + original.slice(range.start, range.end) + close;
			position = range.end;
		});
		window.CFSManualEditing?.before();
		editor.setRangeText(replacement, first, last, 'end');
		editor.focus({ preventScroll: true });
		const active = updatedSelections[updatedSelections.length - 1];
		editor.setSelectionRange(active.start, active.end);
		editorSelections = updatedSelections.filter(range => range.end > range.start);
		activeSelection = selectionKey();
		selectionBase = [];
		drawEditorSelections();
		changed();
});
// Compare the actual styled text against both reference-button surfaces.
function updateStylePreviewBackgrounds() {
	const dark = [16, 23, 29];
	const light = [230, 227, 218];
	function luminance(channels) {
		const linear = channels.map(channel => {
			const value = channel / 255;
			return value <= .04045 ? value / 12.92 : ((value + .055) / 1.055) ** 2.4;
		});
		return linear[0] * .2126 + linear[1] * .7152 + linear[2] * .0722;
	}
	document.querySelectorAll('.tag-grid [data-wrap-style]').forEach(button => {
		const label = button.querySelector('[data-inline]');
		if (!label) return;
		const values = getComputedStyle(label).color.match(/[\d.]+/g)?.map(Number);
		if (!values || values.length < 3) return;
		const alpha = values[3] ?? 1;
		function contrast(background) {
			const text = luminance(values.slice(0, 3).map((channel, index) => channel * alpha + background[index] * (1 - alpha)));
			const surface = luminance(background);
			return (Math.max(text, surface) + .05) / (Math.min(text, surface) + .05);
		}
		const useLight = contrast(light) > contrast(dark);
		button.classList.toggle('style-preview-light', useLight);
		button.classList.toggle('style-preview-dark', !useLight);
	});
}
updateStylePreviewBackgrounds();

document.getElementById('tag-search').addEventListener('input', event => {
	const search = event.target.value.toLowerCase();
	document.querySelectorAll('.tag-grid [data-wrap-style]').forEach(button => {
		button.hidden = !button.dataset.wrapStyle.toLowerCase().includes(search);
	});
});

function element(tag, text, className) {
	const node = document.createElement(tag);
	if (text !== undefined) node.textContent = text;
	if (className) node.className = className;
	return node;
}

const documentOrderList = document.getElementById('document-order-list');
let documentOrderState = JSON.parse(document.getElementById('document-order-data').textContent);
let draggedDocument = null;
let savingDocumentOrder = false;
if (location.hash === '#document-order-tab') bootstrap.Tab.getOrCreateInstance(document.querySelector('[data-bs-target="#document-order-tab"]')).show();
function canChangeDocumentOrder() {
	if (dirty || glossaryDirty) { showNotice('Save your drafts before changing document order.', true); return false; }
	return !savingDocumentOrder;
}
async function saveDocumentOrder() {
	if (savingDocumentOrder) return;
	const names = Array.from(documentOrderList.children).map(item => item.dataset.document);
	if (JSON.stringify(names) === JSON.stringify(documentOrderState.names)) return;
	savingDocumentOrder = true; documentOrderList.classList.add('is-saving');
	document.getElementById('document-order-status').textContent = 'Saving…';
	try {
		await post('order-save', { names: JSON.stringify(names), version: documentOrderState.version });
		location.hash = 'document-order-tab'; location.reload();
	} catch (error) {
		showNotice(error.message, true);
		documentOrderState.names.forEach(name => documentOrderList.append(Array.from(documentOrderList.children).find(item => item.dataset.document === name)));
		document.getElementById('document-order-status').textContent = 'Order not saved';
		savingDocumentOrder = false; documentOrderList.classList.remove('is-saving');
	}
}
documentOrderList.addEventListener('dragstart', event => {
	if (!canChangeDocumentOrder()) { event.preventDefault(); return; }
	draggedDocument = event.target.closest('li[data-document]');
	if (!draggedDocument) return;
	draggedDocument.classList.add('is-dragging'); event.dataTransfer.effectAllowed = 'move';
	event.dataTransfer.setData('text/plain', draggedDocument.dataset.document);
});
documentOrderList.addEventListener('dragover', event => {
	if (!draggedDocument) return;
	event.preventDefault();
	const target = event.target.closest('li[data-document]');
	if (!target || target === draggedDocument) return;
	const box = target.getBoundingClientRect();
	documentOrderList.insertBefore(draggedDocument, event.clientY > box.top + box.height / 2 ? target.nextSibling : target);
});
documentOrderList.addEventListener('drop', event => {
	if (!draggedDocument) return;
	event.preventDefault(); draggedDocument.classList.remove('is-dragging'); draggedDocument = null;
	saveDocumentOrder();
});
documentOrderList.addEventListener('dragend', () => {
	if (!draggedDocument) return;
	draggedDocument.classList.remove('is-dragging'); draggedDocument = null;
	documentOrderState.names.forEach(name => documentOrderList.append(Array.from(documentOrderList.children).find(item => item.dataset.document === name)));
});
documentOrderList.addEventListener('click', event => {
	const button = event.target.closest('[data-order-up], [data-order-down]');
	if (!button || !canChangeDocumentOrder()) return;
	const item = button.closest('li');
	if (button.hasAttribute('data-order-up') && item.previousElementSibling) documentOrderList.insertBefore(item, item.previousElementSibling);
	if (button.hasAttribute('data-order-down') && item.nextElementSibling) documentOrderList.insertBefore(item.nextElementSibling, item);
	saveDocumentOrder();
});

// Glossary page content and alternatives share their existing source files.
let glossaryState = JSON.parse(document.getElementById('glossary-data').textContent);
const glossaryForm = document.getElementById('glossary-form');
const glossaryEntry = document.getElementById('glossary-entry');
const glossaryAlternatives = document.getElementById('glossary-alternatives');
const glossaryDelay = document.getElementById('glossary-delay');
const glossaryAutoLink = document.getElementById('glossary-auto-link');
const glossarySaveStatus = document.getElementById('glossary-save-status');
const glossaryDocument = document.getElementById('glossary-document');
const glossaryDocumentPreview = document.getElementById('glossary-document-preview');
const glossaryDocumentStatus = document.getElementById('glossary-document-status');
const glossaryTitle = document.getElementById('glossary-definition-title');
let glossaryDocumentVersion = '';
let glossaryDocumentBaseline = '';
let glossaryTitleBaseline = '';
let glossaryDelaySaving = false;
let glossaryDelayBaseline = String(glossaryState.hover_delay_ms);
let glossaryAutoLinkBaseline = glossaryState.auto_link_terms === true;
glossaryDelay.value = glossaryDelayBaseline;
glossaryAutoLink.checked = glossaryAutoLinkBaseline;
let glossaryPreviewTimer;
let glossaryPreviewController;
let glossaryHasPreview = false;
let glossarySelected = null;
let glossaryBaseline = '';
function glossaryFingerprint() {
	return JSON.stringify([glossaryAlternatives.value]);
}
function updateGlossaryDirty() {
	glossaryDirty = glossaryFingerprint() !== glossaryBaseline || glossaryDocument.value !== glossaryDocumentBaseline || glossaryTitle.value !== glossaryTitleBaseline || glossaryDelayChanged();
	document.getElementById('save-glossary-delay').disabled = glossaryDelaySaving || !glossaryDelayChanged();
}
function glossaryDelayChanged() { return glossaryDelay.value === '' || Number(glossaryDelay.value) !== Number(glossaryDelayBaseline) || glossaryAutoLink.checked !== glossaryAutoLinkBaseline; }
function loadGlossaryEntry(id, preserveContent = false) {
	glossarySelected = id;
	glossaryEntry.value = id || '';
	glossaryAlternatives.value = (glossaryState.alternatives[id] || []).join('\n');
	if (!preserveContent) {
		glossaryTitle.value = glossaryState.entries[id]?.title || '';
		glossaryTitleBaseline = glossaryTitle.value;
		glossaryDocument.value = glossaryState.entries[id]?.markdown || '';
		glossaryDocumentBaseline = glossaryDocument.value;
		glossaryDocumentVersion = glossaryState.entries[id]?.version || glossaryState.document.version;
		glossaryDocumentStatus.textContent = 'Saved';
		glossaryHasPreview = false;
		previewGlossaryDocument();
	}
	document.getElementById('save-glossary').disabled = !id;
	document.getElementById('save-glossary-document').disabled = !id;
	document.getElementById('glossary-delete').disabled = !id;
	glossaryBaseline = glossaryFingerprint();
	updateGlossaryDirty();
	glossarySaveStatus.textContent = 'Saved';
}
Object.entries(glossaryState.entries).forEach(([id, entry]) => {
	const option = element('option', entry.title);
	option.value = id;
	glossaryEntry.append(option);
});
loadGlossaryEntry(Object.keys(glossaryState.entries)[0] || null);
glossaryEntry.addEventListener('change', () => {
	if ((glossaryFingerprint() !== glossaryBaseline || glossaryDocument.value !== glossaryDocumentBaseline || glossaryTitle.value !== glossaryTitleBaseline) && !confirm('Discard the unsaved changes for this entry?')) { glossaryEntry.value = glossarySelected; return; }
	loadGlossaryEntry(glossaryEntry.value);
});
glossaryForm.addEventListener('input', event => {
	if (event.target === glossaryEntry) return;
	updateGlossaryDirty();
	glossarySaveStatus.textContent = glossaryFingerprint() !== glossaryBaseline ? 'Unsaved changes' : 'Saved';
});
glossaryForm.addEventListener('submit', async event => {
	event.preventDefault();
	if (!glossaryForm.reportValidity() || !glossarySelected) return;
	const selected = glossarySelected;
	const submitted = glossaryFingerprint();
	const button = document.getElementById('save-glossary');
	button.disabled = true;
	glossaryEntry.disabled = true;
	try {
		const result = await post('glossary-save', {entry: selected, alternatives: glossaryAlternatives.value, hover_delay_ms: glossaryState.hover_delay_ms, version: glossaryState.version});
		glossaryState = result.glossary;
		if (submitted === glossaryFingerprint()) loadGlossaryEntry(selected, true);
		else { glossaryBaseline = submitted; updateGlossaryDirty(); glossarySaveStatus.textContent = 'Unsaved changes'; }
		document.querySelectorAll('[data-glossary-delay]').forEach(link => { link.dataset.glossaryDelay = glossaryState.hover_delay_ms; });
		showNotice(result.message);
		await Promise.all([preview(), previewGlossaryDocument()]);
	} catch (error) { showNotice(error.message, true); }
	finally { button.disabled = false; glossaryEntry.disabled = false; }
});
async function previewGlossaryDocument() {
	glossaryPreviewController?.abort();
	glossaryPreviewController = new AbortController();
	try {
		const result = await post('preview', {content: glossaryDocument.value, glossary_entry: glossarySelected}, glossaryPreviewController.signal);
		glossaryDocumentPreview.innerHTML = result.html;
		glossaryHasPreview = true;
	} catch (error) { if (error.name !== 'AbortError') showNotice(error.message, true); }
}
function glossaryDocumentChanged() {
	updateGlossaryDirty();
	glossaryDocumentStatus.textContent = glossaryDocument.value !== glossaryDocumentBaseline || glossaryTitle.value !== glossaryTitleBaseline ? 'Unsaved changes' : 'Saved';
	clearTimeout(glossaryPreviewTimer);
	glossaryPreviewTimer = setTimeout(previewGlossaryDocument, 650);
}
glossaryDocument.addEventListener('input', glossaryDocumentChanged);
glossaryTitle.addEventListener('input', glossaryDocumentChanged);
document.getElementById('preview-glossary-document').addEventListener('click', previewGlossaryDocument);
async function saveGlossaryDocument() {
	if (!glossaryTitle.reportValidity()) return;
	if (glossaryFingerprint() !== glossaryBaseline) { showNotice('Save your alternative strings before saving the definition.', true); return; }
	if (dirty && adminApp.dataset.file === glossaryState.document.file) { showNotice('Save the glossary draft in Content Editor first, so the two editors cannot overwrite each other.', true); return; }
	const button = document.getElementById('save-glossary-document');
	const submitted = glossaryDocument.value;
	const submittedTitle = glossaryTitle.value;
	const selected = glossarySelected;
	button.disabled = true;
	glossaryEntry.disabled = true;
	glossaryAlternatives.disabled = true;
	try {
		const result = await post('glossary-content-save', {entry: selected || '', title: submittedTitle, content: submitted, version: glossaryDocumentVersion});
		glossaryDocumentVersion = result.version;
		glossaryDocumentBaseline = submitted;
		glossaryTitleBaseline = submittedTitle;
		glossaryState = result.glossary;
		glossaryEntry.replaceChildren();
		Object.entries(glossaryState.entries).forEach(([id, entry]) => { const option = element('option', entry.title); option.value = id; glossaryEntry.append(option); });
		loadGlossaryEntry(result.entry_id, true);
		glossaryDocumentStatus.textContent = glossaryDocument.value !== submitted || glossaryTitle.value !== submittedTitle ? 'Unsaved changes' : 'Saved';
		if (adminApp.dataset.file === glossaryState.document.file && !dirty) {
			editor.value = result.source_content; savedContent = editor.value; version = result.version; captureEditorSelection(); window.CFSManualEditing?.reset();
			await preview();
		}
		showNotice(result.message);
		await previewGlossaryDocument();
	} catch (error) { showNotice(error.message, true); }
	finally { button.disabled = false; glossaryEntry.disabled = false; glossaryAlternatives.disabled = false; }
}
document.getElementById('save-glossary-document').addEventListener('click', saveGlossaryDocument);
glossaryDocument.addEventListener('keydown', event => {
	if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 's') { event.preventDefault(); saveGlossaryDocument(); }
});
document.getElementById('glossary-apply-style').addEventListener('click', () => {
	let start = glossaryDocument.selectionStart; let end = glossaryDocument.selectionEnd;
	while (start < end && /\s/.test(glossaryDocument.value[start])) start++;
	while (end > start && /\s/.test(glossaryDocument.value[end - 1])) end--;
	const style = document.getElementById('glossary-document-style').value;
	const prefix = ['sup', 'g'].includes(style.toLowerCase()) ? ':' : '';
	const open = '<' + prefix + style + '>';
	const selected = glossaryDocument.value.slice(start, end);
	glossaryDocument.setRangeText(open + selected + '</' + prefix + style + '>', start, end, 'end');
	glossaryDocument.focus(); glossaryDocument.setSelectionRange(start + open.length, start + open.length + selected.length);
	glossaryDocumentChanged();
});
document.getElementById('glossary-insert-image').addEventListener('click', () => {
	const source = prompt('Image address or path relative to the website (for example, images/example.png):');
	if (!source?.trim()) return;
	const description = prompt('Image description:', '') ?? '';
	const path = source.trim().replace(/\s/g, encodeURIComponent).replace(/\(/g, '%28').replace(/\)/g, '%29');
	glossaryDocument.setRangeText('![' + description.replace(/\]/g, '\\]') + '](' + path + ')', glossaryDocument.selectionStart, glossaryDocument.selectionEnd, 'end');
	glossaryDocument.focus(); glossaryDocumentChanged();
});
document.querySelector('[data-bs-target="#glossary-tab"]').addEventListener('shown.bs.tab', () => { if (!glossaryHasPreview) previewGlossaryDocument(); });
document.getElementById('glossary-filter').addEventListener('input', event => {
	const query = event.target.value.toLocaleLowerCase();
	Array.from(glossaryEntry.options).forEach(option => { option.hidden = option.value !== glossarySelected && !option.textContent.toLocaleLowerCase().includes(query); });
});
document.getElementById('glossary-global-form').addEventListener('input', () => {
	updateGlossaryDirty();
	document.getElementById('glossary-global-status').textContent = glossaryDelayChanged() ? 'Unsaved changes' : 'Saved';
});
document.getElementById('glossary-global-form').addEventListener('submit', async event => {
	event.preventDefault();
	if (!event.target.reportValidity() || !glossaryDelayChanged()) return;
	const button = document.getElementById('save-glossary-delay');
	const submitted = glossaryDelay.value;
	const submittedAutoLink = glossaryAutoLink.checked;
	glossaryDelaySaving = true;
	button.disabled = true;
	try {
		const result = await post('glossary-delay-save', {hover_delay_ms: submitted, auto_link_terms: submittedAutoLink, version: glossaryState.version});
		glossaryState = result.glossary;
		glossaryDelayBaseline = String(glossaryState.hover_delay_ms);
		glossaryAutoLinkBaseline = glossaryState.auto_link_terms === true;
		updateGlossaryDirty();
		document.getElementById('glossary-global-status').textContent = glossaryDelayChanged() ? 'Unsaved changes' : 'Saved';
		document.querySelectorAll('[data-glossary-delay]').forEach(link => { link.dataset.glossaryDelay = glossaryState.hover_delay_ms; });
		showNotice(result.message);
		await Promise.all([preview(), previewGlossaryDocument()]);
	} catch (error) { showNotice(error.message, true); }
	finally { glossaryDelaySaving = false; updateGlossaryDirty(); }
});
document.getElementById('glossary-new').addEventListener('click', () => {
	if ((glossaryFingerprint() !== glossaryBaseline || glossaryDocument.value !== glossaryDocumentBaseline || glossaryTitle.value !== glossaryTitleBaseline) && !confirm('Discard this entry draft and create a new entry?')) return;
	Array.from(glossaryEntry.options).filter(option => option.value === '').forEach(option => option.remove());
	const option = element('option', 'New entry'); option.value = ''; glossaryEntry.append(option);
	loadGlossaryEntry('');
	document.getElementById('save-glossary-document').disabled = false;
	glossaryTitle.focus();
});
document.getElementById('glossary-delete').addEventListener('click', async () => {
	if (!glossarySelected) return;
	if (dirty && adminApp.dataset.file === glossaryState.document.file) { showNotice('Save the glossary draft in Content Editor before deleting entries.', true); return; }
	if (!confirm('Delete “' + glossaryState.entries[glossarySelected].title + '” and its alternatives? Text using this entry will keep its style but lose its glossary link. Unsaved entry changes will be discarded.')) return;
	const button = document.getElementById('glossary-delete'); button.disabled = true;
	glossaryEntry.disabled = true;
	try {
		const result = await post('glossary-delete', {entry: glossarySelected, version: glossaryDocumentVersion, settings_version: glossaryState.version});
		glossaryState = result.glossary;
		glossaryEntry.replaceChildren();
		Object.entries(glossaryState.entries).forEach(([id, entry]) => { const option = element('option', entry.title); option.value = id; glossaryEntry.append(option); });
		loadGlossaryEntry(Object.keys(glossaryState.entries)[0] || null);
		if (adminApp.dataset.file === glossaryState.document.file && !dirty) { editor.value = result.source_content; savedContent = editor.value; version = result.version; captureEditorSelection(); window.CFSManualEditing?.reset(); await preview(); }
		showNotice('Glossary entry deleted. Previous content and alternatives were backed up.');
	} catch (error) { showNotice(error.message, true); }
	finally { button.disabled = !glossarySelected; glossaryEntry.disabled = false; }
});
document.querySelectorAll('[data-glossary-help]').forEach(button => bootstrap.Popover.getOrCreateInstance(button, {trigger: 'hover focus', container: 'body'}));
if (location.hash === '#glossary-tab') bootstrap.Tab.getOrCreateInstance(document.querySelector('[data-bs-target="#glossary-tab"]')).show();

// Native close protection observes the same draft flags as the original page.
window.CFSManual.bindDirty(() => dirty || glossaryDirty);
window.CFSManual.reportDirty();
