'use strict';
/* Ports the original PHP LoadManual/BuildNavigation/page.php structure into
   the installed editor. Content and styles still come from the active game. */
window.CFSManualExport = (() => {
	/** Parses the original stable section markers, retaining source order. */
	function sections(data) {
		const result = [];
		const ids = new Set();
		for (const stem of data.order) {
			const path = Object.keys(data.snapshot.files).find(path => /^Content\/.*\.md$/i.test(path) && path.slice(8, -3) === stem);
			if (!path) continue;
			const source = data.snapshot.files[path].text;
			const matches = [...source.matchAll(/<!-- section: ([a-z0-9-]+)(?:; quicksheet: ([a-z0-9-]+))?; source: ([0-9]+) -->\r?\n(#{2,6}) ([^\r\n]+)(?:\r?\n|$)/g)];
			if (!matches.length) {
				result.push({id: 'document-' + encodeURIComponent(stem).replace(/%/g, '-'), level: 2, title: stem, markdown: source, sheet: ''});
				continue;
			}
			matches.forEach((match, index) => {
				if (ids.has(match[1])) throw new Error('Duplicate manual section ID: ' + match[1]);
				ids.add(match[1]);
				result.push({id: match[1], sheet: match[2] || '', level: match[4].length, title: match[5].replace(/\\([\\`*_\[\]<>|])/g, '$1'), markdown: source.slice(match.index + match[0].length, matches[index + 1]?.index ?? source.length)});
			});
		}
		return result;
	}

	/** Decorates rendered Markdown with the exact reader table/image classes. */
	function body(data, markdown, pdf) {
		const container = document.createElement('div');
		const imageBase = new URL('Images/', data.snapshot.context.manualURL.replace(/\/?$/, '/')).href;
		container.innerHTML = data.render(markdown).split(imageBase).join('content-images/');
		container.querySelectorAll('img').forEach(image => { image.classList.add('img-fluid', 'source-figure'); image.loading = pdf ? 'eager' : 'lazy'; if (!image.alt) image.alt = 'Rulebook illustration'; });
		container.querySelectorAll('table').forEach(table => {
			table.classList.add('table', 'table-striped', 'table-bordered', 'align-middle');
			const wrapper = document.createElement('div'); wrapper.className = 'table-responsive'; table.replaceWith(wrapper); wrapper.append(table);
		});
		return container.innerHTML;
	}

	/** Restores the PHP reader's nested section and heading assemblies. */
	function nested(data, items, pdf, prefix = '') {
		const open = [];
		let html = '';
		for (const item of items) {
			while (open.length && open[open.length - 1] >= item.level) { html += '</section>'; open.pop(); }
			const heading = !pdf && item.level === 2 ? 1 : item.level;
			const classes = item.level <= 3 ? 'manual-section metal-panel section-level-' + item.level : 'manual-section inset-section section-level-' + item.level;
			html += '<section class="' + classes + '" id="' + data.escape(prefix + item.id) + '" data-section="' + data.escape(prefix + item.id) + '"' + (item.level === 2 ? ' data-chapter="' + data.escape(prefix + item.id) + '"' : '') + '><div class="section-heading"><span class="heading-anchor" aria-hidden="true"></span><h' + heading + '>' + data.escape(item.title) + '</h' + heading + '></div><div class="section-copy">' + body(data, item.markdown, pdf) + '</div>';
			open.push(item.level);
		}
		return html + '</section>'.repeat(open.length);
	}

	/** Builds Web reader or PDF-only content from the same canonical sections. */
	function build(data, kind) {
		const pdf = kind === 'pdf';
		const items = sections(data);
		if (!items.length) throw new Error('The manual has no content to export.');
		const groups = [];
		for (const item of items) { if (item.level === 2) groups.push({section: item, children: []}); else if (groups.length) groups[groups.length - 1].children.push(item); }
		const sheets = items.filter(item => item.sheet).map(item => { const start = items.indexOf(item); let end = start + 1; while (end < items.length && items[end].level > item.level) end++; return {id: item.sheet, title: item.title, sections: items.slice(start, end)}; });
		const title = data.escape(data.snapshot.context.gameName);
		const css = ['bootstrap.min.css', 'intro-preview.css', 'Reader.css', 'Components.css', 'font-styles.css', 'glossary.css', ...(pdf ? ['Print.css'] : [])].map(name => '<link rel="stylesheet" href="css/' + name + '">').join('');
		const head = '<!doctype html><html lang="en" data-bs-theme="dark"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>' + title + '</title>' + css;
		if (pdf) {
			const p = data.pdf;
			const b = p.bleed;
			const page = '@page{size:' + (p.width + 2 * b) + 'in ' + (p.height + 2 * b) + 'in;margin:' + (p.marginTop + b) + 'in ' + (p.marginOutside + b) + 'in ' + (p.marginBottom + b) + 'in ' + (p.marginInside + b) + 'in;@top-center{content:element(pdfHeader)}@bottom-right{content:counter(page);color:#e6e3da;font:8pt "Control Freak"}}@page:left{margin-left:' + (p.marginOutside + b) + 'in;margin-right:' + (p.marginInside + b) + 'in}@page:right{margin-left:' + (p.marginInside + b) + 'in;margin-right:' + (p.marginOutside + b) + 'in}:root{--pdf-bleed:' + b + 'in;--pdf-header-width:' + (p.width - p.marginInside - p.marginOutside) + 'in;--pdf-figure-height:' + Math.max(.1, p.height - p.marginTop - p.marginBottom - 70 / 72) + 'in}';
			const quick = sheets.map(sheet => nested(data, sheet.sections.map((section, index) => index ? section : {...section, level: 2, title: 'Quicksheet: ' + section.title}), true, 'quick-' + sheet.id + '-')).join('');
			const toc = sheets.map(sheet => '<li><a href="#quick-' + data.escape(sheet.id + '-' + sheet.sections[0].id) + '">Quicksheet: ' + data.escape(sheet.title) + '</a></li>').join('') + items.slice(1).map(item => '<li data-level="' + item.level + '"><a href="#' + data.escape(item.id) + '">' + data.escape(item.title) + '</a></li>').join('');
			const pdfData = JSON.stringify({title: data.snapshot.context.gameName}).replace(/</g, '\\u003c');
			return head.replace('<title>' + title + '</title>', '<title>PDF export incomplete</title>') + '<style>' + page + '</style><script src="js/Print.js" defer></script><script src="vendor/pagedjs/paged.polyfill.js" defer></script></head><body><div class="title-assembly pdf-page-header">' + title + ' / RULEBOOK</div><main class="manual-shell"><div class="pdf-cover section-copy">' + body(data, items[0].markdown, true) + '</div><section class="pdf-contents"><div class="section-heading"><h2>Contents</h2></div><ol class="pdf-toc">' + toc + '</ol></section>' + quick + nested(data, items.slice(1), true) + '</main><script id="pdf-document-data" type="application/json">' + pdfData + '</script></body></html>';
		}
		const toc = groups.map(group => {
			const item = group.section;
			const link = section => '<a data-toc-link data-toc-section="' + data.escape(section.id) + '" href="#' + data.escape(section.id) + '">' + data.escape(section.title) + '</a>';
			return group.children.length ? '<li data-toc-group="' + data.escape(item.id) + '"><div class="toc-group-header"><a data-group-link href="#' + data.escape(item.id) + '">' + data.escape(item.title) + '</a><button type="button" class="toc-group-toggle" data-group-toggle aria-label="Expand or collapse ' + data.escape(item.title) + '" aria-expanded="false" aria-controls="toc-' + data.escape(item.id) + '"><span aria-hidden="true">▸</span></button></div><ul class="list-unstyled" id="toc-' + data.escape(item.id) + '" hidden><li>' + link(item) + '</li>' + group.children.map(child => '<li class="toc-depth-' + child.level + '">' + link(child) + '</li>').join('') + '</ul></li>' : '<li>' + link(item) + '</li>';
		}).join('');
		const sheetTOC = sheets.map(sheet => '<li><a href="#sheet-' + data.escape(sheet.id) + '">' + data.escape(sheet.title) + '</a></li>').join('');
		const quickContent = sheets.map(sheet => '<div data-reader-sheet="' + data.escape(sheet.id) + '" hidden>' + nested(data, sheet.sections, false, 'sheet-' + sheet.id + '-') + '</div>').join('');
		const metadata = JSON.stringify({groups: groups.map(group => ({id: group.section.id, title: group.section.title})), sheets: sheets.map(sheet => ({id: sheet.id, title: sheet.title, target: sheet.sections[0].id}))}).replace(/</g, '\\u003c');
		return head + '<script src="js/glossary.js" defer></script><script src="js/bootstrap.bundle.min.js" defer></script><script src="js/Reader.js" defer></script></head><body><a class="visually-hidden-focusable skip-link" href="#main">Skip to content</a><div class="container-xxl manual-shell"><header class="command-header"><div class="title-assembly"><a href="#intro" class="brand-link web-game-title">' + title + '</a><p class="series-label web-manual-subtitle">RULEBOOK</p></div></header><div class="row g-4 g-xl-5 align-items-start"><aside class="col-lg-3"><div class="navigation-assembly metal-panel"><nav class="manual-view-buttons" aria-label="Manual views"><a class="btn btn-sm btn-warning active" id="full-rulebook" href="#intro">Full rulebook</a><a class="btn btn-sm btn-outline-light" id="quicksheet-view" href="#view-quicksheets">Quicksheets</a></nav><button class="navigation-toggle" type="button" data-bs-toggle="collapse" data-bs-target="#manual-contents" aria-expanded="true" aria-controls="manual-contents"><span class="status-light" aria-hidden="true"></span><span>CONTENTS</span><span class="toggle-symbol" aria-hidden="true">⌄</span></button><nav class="collapse show" id="manual-contents" aria-label="Table of contents"><ul class="toc list-unstyled" id="reader-chapter-toc">' + toc + '</ul><ul class="toc list-unstyled" id="reader-sheet-toc" hidden>' + sheetTOC + '</ul></nav></div></aside><main class="col-lg-9" id="main"><div class="chapter-strip"><span>THE RULEBOOK</span><span id="reader-chapter-title"></span></div><div class="connected-sections">' + nested(data, items, false) + '</div><section id="reader-quicksheets" class="manual-section metal-panel section-level-2" hidden><div class="section-heading"><h1>Quicksheets</h1></div><div class="row g-3">' + sheets.map(sheet => '<div class="col-md-6"><article class="quicksheet-card"><h2><a href="#' + data.escape('sheet-' + sheet.id) + '">' + data.escape(sheet.title) + '</a></h2></article></div>').join('') + '</div></section>' + quickContent + '<footer class="chapter-footer"><span>' + title + '</span><nav aria-label="Chapter navigation"><a id="reader-previous"></a><a id="reader-next"></a></nav></footer></main></div></div><script type="application/json" id="reader-data">' + metadata + '</script></body></html>';
	}
	return {build};
})();
