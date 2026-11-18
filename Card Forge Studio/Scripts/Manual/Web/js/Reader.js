'use strict';
/* Static counterpart of the original chapter selector and manual.js controls.
   All content is already local; chapter changes require no server or fetch. */
(() => {
	const data = JSON.parse(document.getElementById('reader-data').textContent);
	const chapters = [...document.querySelectorAll('.connected-sections [data-chapter]')];
	const home = data.groups.find(group => group.id === 'intro') || data.groups[0];

	const accordion = document.getElementById('reader-accordion');
	const accordionKey = 'cfs.manual.navigation.autoCollapse';
	try { accordion.checked = localStorage.getItem(accordionKey) !== 'false'; } catch (_) {}

	/** Maintains the expandable contents plates and optional accordion behavior. */
	function expand(group, value) {
		if (value && accordion.checked) {
			document.querySelectorAll('[data-toc-group]').forEach(other => { if (other !== group) expand(other, false); });
		}
		const button = group.querySelector('[data-group-toggle]');
		button.setAttribute('aria-expanded', String(value));
		document.getElementById(button.getAttribute('aria-controls')).hidden = !value;
	}
	/** Chooses one chapter, updates footer links and preserves anchor navigation. */
	function select() {
		let id;
		try { id = decodeURIComponent(location.hash.slice(1)); } catch (_) { id = ''; }
		const sheet = data.sheets.find(sheet => id === 'sheet-' + sheet.id);
		const quick = id === 'view-quicksheets' || !!sheet;
		const target = document.getElementById(id);
		const chapter = target?.closest('[data-chapter]') || chapters.find(node => node.dataset.chapter === home.id);
		chapters.forEach(node => { node.hidden = quick || node !== chapter; });
		document.getElementById('reader-quicksheets').hidden = !quick || !!sheet;
		document.getElementById('reader-chapter-toc').hidden = quick;
		document.getElementById('reader-sheet-toc').hidden = !quick;
		document.querySelectorAll('[data-reader-sheet]').forEach(node => { node.hidden = !sheet || node.dataset.readerSheet !== sheet.id; });
		for (const [id, active] of [['full-rulebook', !quick], ['quicksheet-view', quick]]) {
			const link = document.getElementById(id); link.classList.toggle('active', active); link.classList.toggle('btn-warning', active); link.classList.toggle('btn-outline-light', !active);
		}
		const index = data.groups.findIndex(group => group.id === chapter?.dataset.chapter);
		document.getElementById('reader-chapter-title').textContent = sheet ? sheet.title : quick ? 'Quicksheets' : data.groups[index]?.title || '';
		for (const [name, offset, arrow] of [['previous', -1, '← '], ['next', 1, ' →']]) {
			const link = document.getElementById('reader-' + name); const group = data.groups[index + offset]; link.hidden = quick || !group;
			if (group) { link.href = '#' + group.id; link.textContent = offset < 0 ? arrow + group.title : group.title + arrow; }
		}
		document.querySelectorAll('[data-toc-link]').forEach(link => { const current = link.dataset.tocSection === (id || home.id); link.classList.toggle('is-current', current); if (current) link.setAttribute('aria-current', 'location'); else link.removeAttribute('aria-current'); });
		document.querySelectorAll('[data-toc-group]').forEach(group => { const active = group.dataset.tocGroup === chapter?.dataset.chapter; group.classList.toggle('has-current', active); if (active && !quick) expand(group, true); });
		if (target && !quick) target.scrollIntoView();
	}
	document.querySelectorAll('[data-toc-group]').forEach(group => group.querySelector('[data-group-toggle]').addEventListener('click', () => expand(group, group.querySelector('[data-group-toggle]').getAttribute('aria-expanded') !== 'true')));
	accordion.addEventListener('change', () => {
		try { localStorage.setItem(accordionKey, String(accordion.checked)); } catch (_) {}
		if (accordion.checked) {
			const open = [...document.querySelectorAll('[data-toc-group]')].filter(group => group.querySelector('[data-group-toggle]').getAttribute('aria-expanded') === 'true');
			const keep = open.find(group => group.classList.contains('has-current')) || open[0];
			if (keep) expand(keep, true);
		}
	});
	document.querySelector('.brand-link').href = '#' + home.id;
	document.getElementById('full-rulebook').href = '#' + home.id;
	window.addEventListener('hashchange', select);
	select();
})();
