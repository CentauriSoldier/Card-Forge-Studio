'use strict';
/* One document history for typing and all content toolbar mutations. */
(() => {
    const toolbar = document.createElement('div'); toolbar.className = 'manual-edit-commands'; toolbar.setAttribute('role', 'toolbar'); toolbar.setAttribute('aria-label', 'Edit document');
    const buttons = {};
    for (const [id, title] of [['undo', 'Undo'], ['redo', 'Redo'], ['cut', 'Cut'], ['copy', 'Copy'], ['paste', 'Paste'], ['all', 'Select all'], ['find', 'Find / Replace']]) {
        const button = document.createElement('button'); button.type = 'button'; button.className = 'btn btn-sm btn-outline-light'; button.textContent = title; button.dataset.editCommand = id; toolbar.append(button); buttons[id] = button;
    }
    buttons.undo.title = 'Undo (Ctrl+Z)'; buttons.redo.title = 'Redo (Ctrl+Y or Ctrl+Shift+Z)'; buttons.find.title = 'Find (Ctrl+F) / Replace (Ctrl+H)';
    document.querySelector('.editor-tools-bar').before(toolbar);
    const panel = document.createElement('div'); panel.className = 'manual-find-panel'; panel.hidden = true;
    panel.innerHTML = '<label>Find <input type="text" data-find aria-label="Find text"></label><label>Replace <input type="text" data-replace aria-label="Replacement text"></label><label><input type="checkbox" data-case> Match case</label><button type="button" data-action="previous">Previous</button><button type="button" data-action="next">Next</button><button type="button" data-action="replace">Replace</button><button type="button" data-action="replace-all">Replace all</button><button type="button" data-action="close" aria-label="Close find and replace">Close</button><span role="status" aria-live="polite"></span>';
    toolbar.after(panel);
    const findField = panel.querySelector('[data-find]'), replaceField = panel.querySelector('[data-replace]'), matchCase = panel.querySelector('[data-case]'), status = panel.querySelector('[role="status"]');
    let entries = [], position = 0, restoring = false;
    const snapshot = (nativeInput = false) => ({text: editor.value, start: editor.selectionStart, end: editor.selectionEnd, direction: editor.selectionDirection, top: editor.scrollTop, left: editor.scrollLeft, ranges: nativeInput ? [] : editorSelections.map(range => ({...range}))});
    function update() { buttons.undo.disabled = position === 0; buttons.redo.disabled = position === entries.length - 1; }
    function reset() { entries = [snapshot()]; position = 0; update(); }
    function before() { if (!restoring && entries[position]?.text === editor.value) entries[position] = snapshot(); }
    function record(nativeInput = false) {
        if (restoring || entries[position]?.text === editor.value) return;
        entries.splice(position + 1); entries.push(snapshot(nativeInput)); position++;
        // Keep a bounded history without losing the saved-content comparison.
        if (entries.length > 200) { entries.shift(); position--; }
        update();
    }
    function travel(delta) {
        const target = position + delta; if (target < 0 || target >= entries.length) return;
        before(); position = target; const state = entries[position]; restoring = true;
        try {
            editor.value = state.text; editor.focus({preventScroll: true}); editor.setSelectionRange(state.start, state.end, state.direction);
            editor.dispatchEvent(new Event('input', {bubbles: true}));
            editorSelections = state.ranges.map(range => ({...range})); selectionBase = []; activeSelection = selectionKey(); drawEditorSelections();
            editor.scrollTop = state.top; editor.scrollLeft = state.left;
        } finally { restoring = false; update(); }
    }
    function replace(text, start = editor.selectionStart, end = editor.selectionEnd) {
        before(); editor.setRangeText(text, start, end, 'select'); editor.focus({preventScroll: true});
        editor.dispatchEvent(new Event('input', {bubbles: true}));
    }
    function openFind() {
        panel.hidden = false;
        if (editor.selectionEnd > editor.selectionStart) findField.value = editor.value.slice(editor.selectionStart, editor.selectionEnd);
        findField.focus(); findField.select();
    }
    function matches() {
        if (!findField.value) return [];
        const expression = new RegExp(findField.value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), matchCase.checked ? 'g' : 'gi');
        return [...editor.value.matchAll(expression)].map(match => ({start: match.index, end: match.index + match[0].length}));
    }
    function find(backward = false) {
        const found = matches();
        if (!found.length) { status.textContent = findField.value ? 'No matches' : 'Enter text to find'; return; }
        const target = backward ? found.slice().reverse().find(item => item.start < editor.selectionStart) || found[found.length - 1] : found.find(item => item.start >= editor.selectionEnd && (item.start !== editor.selectionStart || item.end !== editor.selectionEnd)) || found[0];
        editor.focus({preventScroll: true}); editor.setSelectionRange(target.start, target.end); captureEditorSelection();
        // Approximate vertical placement; the selection remains the exact match.
        const rows = editor.value.slice(0, target.start).split('\n').length - 1;
        const lineHeight = parseFloat(getComputedStyle(editor).lineHeight) || 20; editor.scrollTop = Math.max(0, rows * lineHeight - editor.clientHeight / 2);
        status.textContent = (found.indexOf(target) + 1) + ' of ' + found.length;
    }
    panel.addEventListener('click', event => {
        const action = event.target.dataset.action;
        if (action === 'close') { panel.hidden = true; editor.focus(); }
        if (action === 'next' || action === 'previous') find(action === 'previous');
        if (action === 'replace') {
            const selected = matches().find(item => item.start === editor.selectionStart && item.end === editor.selectionEnd);
            if (selected) replace(replaceField.value, selected.start, selected.end);
            find();
        }
        if (action === 'replace-all') {
            const found = matches(); if (!found.length) { status.textContent = 'No matches'; return; }
            let text = editor.value;
            for (const item of found.slice().reverse()) text = text.slice(0, item.start) + replaceField.value + text.slice(item.end);
            replace(text, 0, editor.value.length); status.textContent = 'Replaced ' + found.length + ' matches';
        }
    });
    panel.addEventListener('keydown', event => {
        if (event.key === 'Escape') { event.preventDefault(); panel.hidden = true; editor.focus(); }
        if (event.key === 'Enter') { event.preventDefault(); find(event.shiftKey); }
    });
    toolbar.addEventListener('mousedown', event => { if (event.target.closest('button')) event.preventDefault(); });
    toolbar.addEventListener('click', async event => {
        const action = event.target.dataset.editCommand; if (!action) return;
        if (action === 'undo') return travel(-1); if (action === 'redo') return travel(1);
        if (action === 'find') return openFind();
        if (action === 'all') { editor.focus(); editor.select(); captureEditorSelection(); return; }
        const start = editor.selectionStart, end = editor.selectionEnd, original = editor.value;
        try {
            if (action === 'paste') {
                const text = await navigator.clipboard.readText();
                if (editor.value !== original || editor.selectionStart !== start || editor.selectionEnd !== end) throw new Error('Selection changed while reading the clipboard. Paste again.');
                replace(text, start, end);
            } else if (start !== end) {
                await navigator.clipboard.writeText(original.slice(start, end));
                if (action === 'cut') {
                    if (editor.value !== original || editor.selectionStart !== start || editor.selectionEnd !== end) throw new Error('Selection changed while copying. Cut again.');
                    replace('', start, end);
                }
            }
        } catch (error) { showNotice('Clipboard action unavailable: ' + error.message + ' Use Ctrl+X, Ctrl+C, or Ctrl+V in the editor.', true); editor.focus(); }
    });
    editor.addEventListener('beforeinput', event => {
        if (event.inputType === 'historyUndo' || event.inputType === 'historyRedo') { event.preventDefault(); travel(event.inputType === 'historyUndo' ? -1 : 1); }
        else before();
    });
    editor.addEventListener('keydown', event => {
        if (!(event.ctrlKey || event.metaKey) || event.altKey) return;
        const key = event.key.toLowerCase();
        if (key === 'z' || key === 'y') { event.preventDefault(); travel(key === 'y' || event.shiftKey ? 1 : -1); }
        if (key === 'f' || key === 'h') { event.preventDefault(); openFind(); if (key === 'h') replaceField.focus(); }
    });
    window.CFSManualEditing = {before, record, reset}; reset();
})();
