'use strict';

// Delegation also covers content previews replaced after an edit.
(() => {
	const popup = document.createElement('aside');
	popup.id = 'glossary-popup';
	popup.className = 'glossary-popup';
	popup.setAttribute('role', 'tooltip');
	popup.hidden = true;
	document.body.append(popup);
	let target = null;
	let timer;
	let focused = null;
	function position(link) {
		const box = link.getBoundingClientRect();
		const width = popup.offsetWidth;
		const height = popup.offsetHeight;
		const left = Math.max(8, Math.min(box.left, window.innerWidth - width - 8));
		const top = box.bottom + height + 8 <= window.innerHeight ? box.bottom + 6 : Math.max(8, box.top - height - 6);
		popup.style.setProperty('left', left + 'px');
		popup.style.setProperty('top', top + 'px');
	}
	function hide() {
		clearTimeout(timer);
		if (target) {
			const description = (target.getAttribute('aria-describedby') || '').split(/\s+/).filter(id => id && id !== popup.id).join(' ');
			if (description) target.setAttribute('aria-describedby', description); else target.removeAttribute('aria-describedby');
		}
		popup.hidden = true;
		target = null;
	}
	function show(link) {
		if (!link.isConnected) return;
		target = link;
		const title = document.createElement('strong');
		title.textContent = link.dataset.glossaryTitle;
		const definition = document.createElement('div');
		definition.className = 'glossary-popup-content';
		// This HTML comes only from the server's shared safe-mode Markdown renderer.
		if (link.dataset.glossaryHtml) definition.innerHTML = link.dataset.glossaryHtml;
		else definition.textContent = link.dataset.glossaryDefinition;
		popup.replaceChildren(title, definition);
		popup.hidden = false;
		link.setAttribute('aria-describedby', [...new Set((link.getAttribute('aria-describedby') || '').split(/\s+/).filter(Boolean).concat(popup.id))].join(' '));
		position(link);
		popup.querySelectorAll('img').forEach(image => image.addEventListener('load', () => { if (target === link && !popup.hidden) position(link); }, {once: true}));
	}
	function schedule(link) {
		hide();
		target = link;
		timer = setTimeout(() => show(link), Number(link.dataset.glossaryDelay));
	}
	document.addEventListener('pointerover', event => {
		if (popup.contains(event.target)) { clearTimeout(timer); return; }
		const link = event.target.closest?.('a[data-glossary-title]');
		if (link && !link.contains(event.relatedTarget)) schedule(link);
	});
	document.addEventListener('pointerout', event => {
		if (target?.contains(event.relatedTarget) || popup.contains(event.relatedTarget)) return;
		if (target?.contains(event.target) || popup.contains(event.target)) {
			clearTimeout(timer);
			if (focused === target && !popup.hidden) return;
			timer = setTimeout(hide, 100);
		}
	});
	document.addEventListener('focusin', event => {
		if (popup.contains(event.target)) { clearTimeout(timer); return; }
		const link = event.target.closest?.('a[data-glossary-title]');
		if (link) { focused = link; schedule(link); }
	});
	document.addEventListener('focusout', event => {
		if (popup.contains(event.relatedTarget)) { focused = null; return; }
		if (event.target === focused || popup.contains(event.target)) { focused = null; hide(); }
	});
	document.addEventListener('keydown', event => { if (event.key === 'Escape') hide(); });
	document.addEventListener('scroll', event => { if (!popup.contains(event.target)) hide(); }, true);
	window.addEventListener('resize', hide);
})();
