'use strict';
(() => {
    const tools = document.querySelector('.markdown-tools');
    if (!tools) return;
    const actions = [
        ['h1', '#'], ['h2', '##'], ['h3', '###'], ['h4', '####'], ['h5', '#####'], ['h6', '######'],
        ['numbered', 'Numbered list'], ['link', 'Link'], ['image', 'Image'],
        ['block', 'Code block'], ['rule', 'Separator'], ['table', 'Table']
    ];
    for (const [action, label] of actions) {
        const button = document.createElement('button'); button.type = 'button';
        button.className = 'btn btn-outline-light'; button.textContent = label;
        button.dataset.manualMarkdown = action; tools.append(button);
    }
    tools.addEventListener('mousedown', event => { if (event.target.closest('[data-manual-markdown]')) event.preventDefault(); });
    tools.addEventListener('click', event => {
        const button = event.target.closest('[data-manual-markdown]'); if (!button) return;
        const action = button.dataset.manualMarkdown;
        if (selectionKey() !== activeSelection) captureEditorSelection();
        let ranges = mergeEditorSelections(editorSelections.map(range => ({...range})));
        if (!ranges.length) ranges = [{start: editor.selectionStart, end: editor.selectionEnd}];
        const original = editor.value;
        let url, table;
        if (action === 'link' || action === 'image') {
            url = prompt(action === 'image' ? 'Image URL or Images/path within this manual:' : 'Link URL or #anchor:', action === 'image' ? 'Images/' : 'https://');
            if (url === null) return;
            url = url.trim(); if (!url || /[\r\n<>]/.test(url)) return;
        }
        if (action === 'table') {
            const input = prompt('Table columns and data rows (for example 3 x 4):', '3 x 3');
            if (input === null) return;
            const match = /^\s*(\d+)\s*[x×,]\s*(\d+)\s*$/.exec(input);
            if (!match || +match[1] < 1 || +match[1] > 20 || +match[2] < 1 || +match[2] > 100) { alert('Use 1–20 columns and 1–100 rows.'); return; }
            const columns = +match[1], rows = +match[2];
            const alignment = prompt('Column alignment: left, center, or right', 'left');
            if (alignment === null) return;
            const separator = {left: ':---', center: ':---:', right: '---:'}[alignment.trim().toLowerCase()];
            if (!separator) { alert('Choose left, center, or right.'); return; }
            const row = values => '| ' + values.join(' | ') + ' |';
            table = row(Array.from({length: columns}, (_, i) => 'Heading ' + (i + 1))) + '\n' + row(Array(columns).fill(separator)) + '\n' + Array(rows).fill(row(Array(columns).fill(' '))).join('\n');
        }
        if (/^h[1-6]$/.test(action) || action === 'numbered') {
            ranges = mergeEditorSelections(ranges.map(({start, end}) => ({start: original.lastIndexOf('\n', start - 1) + 1, end: original.indexOf('\n', Math.max(start, end - 1)) < 0 ? original.length : original.indexOf('\n', Math.max(start, end - 1))})));
        }
        function transform(text) {
            if (/^h[1-6]$/.test(action)) return text.split('\n').map(line => '#'.repeat(+action[1]) + ' ' + line.replace(/^#{1,6}\s+/, '')).join('\n');
            if (action === 'numbered') return text.split('\n').map((line, i) => (i + 1) + '. ' + line.replace(/^\s*(?:[-+*]|\d+[.)])\s+/, '')).join('\n');
            if (action === 'link' || action === 'image') return (action === 'image' ? '!' : '') + '[' + (text || (action === 'image' ? 'Image description' : 'Link text')) + '](<' + url + '>)';
            if (action === 'block') { const fences = text.match(/`+/g) || []; const fence = '`'.repeat(Math.max(3, ...fences.map(run => run.length + 1))); return '\n' + fence + '\n' + text + '\n' + fence + '\n'; }
            if (action === 'rule') return text + '\n\n---\n\n';
            return text + (text ? '\n\n' : '\n') + table + '\n';
        }
        const first = ranges[0].start, last = ranges[ranges.length - 1].end;
        let replacement = '', position = first;
        for (const range of ranges) { replacement += original.slice(position, range.start) + transform(original.slice(range.start, range.end)); position = range.end; }
        window.CFSManualEditing.before();
        editor.focus({preventScroll: true}); editor.setRangeText(replacement, first, last, 'end');
        editorSelections = []; selectionBase = []; activeSelection = selectionKey(); drawEditorSelections(); changed();
    });
})();
