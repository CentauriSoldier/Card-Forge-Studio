'use strict';
/* Export settings belong to the active game. Supplier templates are read-only
   defaults; editing a field never modifies the shared preset catalog. */
(() => {
	const api = window.CFSManual;
	const path = 'Config/export-settings.json';
	const form = document.getElementById('pdf-settings');
	const picker = document.getElementById('pdf-preset');
	const status = document.getElementById('export-settings-status');
	const notes = document.getElementById('pdf-preset-notes');
	const profiles = api.snapshot().pdfPresets.profiles;
	let settings = api.config(path);
	let revision = 0;
	let savePromise = null;
	let savedRevision = 0;
	let exporting = false;
	let timer;

	/** Populates a preset or the exact settings last saved for this game. */
	function display() {
		picker.value = profiles.some(profile => profile.id === settings.pdf.preset) ? settings.pdf.preset : 'custom';
		form.querySelectorAll('[data-pdf-field]').forEach(input => { input.value = settings.pdf[input.dataset.pdfField]; });
		const profile = profiles.find(profile => profile.id === picker.value);
		notes.textContent = profile ? profile.minPages + '–' + profile.maxPages + ' pages, in multiples of ' + profile.pageMultiple + '. Supplier upload: ' + profile.uploadPixels + ' pixels. ' + profile.notes : 'Custom dimensions. Margins are measured inward from the trim edge. Bleed is added outside each edge; inside and outside margins mirror on even pages.';
	}

	/** Captures valid dimensions and rejects impossible content areas before saving. */
	function capture() {
		if (!form.checkValidity()) throw new Error('Enter valid numbers in every PDF field.');
		const values = {preset: picker.value, units: 'in'};
		form.querySelectorAll('[data-pdf-field]').forEach(input => { values[input.dataset.pdfField] = input.valueAsNumber; });
		if (Object.values(values).some(value => typeof value === 'number' && !Number.isFinite(value))) throw new Error('PDF fields must contain finite numbers.');
		if (values.marginInside + values.marginOutside >= values.width || values.marginTop + values.marginBottom >= values.height) throw new Error('Margins must leave a positive content area.');
		if (!Number.isInteger(values.dpi)) throw new Error('DPI must be a whole number.');
		return {...settings, pdf: values};
	}

	/** Coalesces edits while serializing saves through the existing conflict-aware bridge. */
	function persist() {
		clearTimeout(timer);
		if (savePromise) return savePromise;
		if (savedRevision === revision) return Promise.resolve(true);
		savePromise = (async () => {
		try {
			let submitted;
			do {
				submitted = revision;
				const draft = capture();
				status.textContent = 'Saving…';
				await api.write({[path]: JSON.stringify(draft, null, '\t') + '\n'});
				settings = draft;
			} while (submitted !== revision);
			status.textContent = 'Saved';
			savedRevision = submitted;
			api.setSettingsDirty('export', false);
			return true;
		} catch (error) { status.textContent = 'Not saved: ' + error.message; return false; }
		})().finally(() => { savePromise = null; });
		return savePromise;
	}

	/** Marks pending settings so closing Studio cannot silently discard them. */
	function changed() {
		revision++;
		api.setSettingsDirty('export', true);
		status.textContent = 'Unsaved changes';
		clearTimeout(timer);
		timer = setTimeout(persist, 350);
	}

	for (const profile of profiles) {
		const option = document.createElement('option');
		option.value = profile.id;
		option.textContent = profile.name;
		picker.append(option);
	}
	picker.addEventListener('change', () => {
		const profile = profiles.find(profile => profile.id === picker.value);
		if (profile) settings = {...settings, pdf: {...profile.values, preset: profile.id}};
		else { try { settings = capture(); } catch (_) { settings.pdf.preset = 'custom'; } }
		display();
		changed();
		persist();
	});
	form.querySelectorAll('[data-pdf-field]').forEach(input => {
		input.addEventListener('input', changed);
		input.addEventListener('change', persist);
	});
	form.addEventListener('submit', event => { event.preventDefault(); persist(); });
	/** Runs a game-bound export only after every authoring/settings draft is saved. */
	document.querySelectorAll('[data-export]').forEach(button => button.addEventListener('click', async () => {
		if (exporting) return;
		exporting = true;
		const kind = button.dataset.export;
		const progress = document.getElementById(kind + '-export-progress');
		const stage = document.getElementById(kind + '-export-stage');
		const output = document.getElementById('manual-export-status');
		progress.hidden = false;
		stage.textContent = 'Saving settings…';
		const controls = [...document.querySelectorAll('#pdf-settings input, #pdf-settings select, [data-export]')];
		const states = controls.map(control => control.disabled);
		document.querySelectorAll('[data-export]').forEach(control => { control.disabled = true; });
		try {
			if (!await persist()) throw new Error(status.textContent);
			stage.textContent = 'Preparing manual…';
			const html = api.exportHTML(kind);
			const versions = Object.fromEntries(Object.entries(api.snapshot().files).map(([name, record]) => [name, record.version]));
			controls.forEach(control => { control.disabled = true; });
			output.textContent = 'Exporting ' + (kind === 'pdf' ? 'PDF. The print process may take a moment…' : 'Web…');
			stage.textContent = 'Sending manual to Studio…';
			const result = await api.request({action: 'export', kind, html, versions});
			output.textContent = result.message;
			showNotice(result.message);
		} catch (error) { output.textContent = 'Export failed: ' + error.message; showNotice(output.textContent, true); }
		finally { progress.hidden = true; stage.textContent = ''; exporting = false; controls.forEach((control, index) => { control.disabled = states[index]; }); }
	}));
	/** Shows generation only after the final request chunk is sent to Lua. */
	document.addEventListener('manual-export-phase', event => {
		const stage = document.getElementById(event.detail.kind + '-export-stage');
		if (exporting && stage) stage.textContent = event.detail.kind === 'pdf' ? 'Paginating and generating PDF…' : 'Writing website files…';
	});
	bootstrap.Popover.getOrCreateInstance(document.getElementById('export-help'), {trigger: 'hover focus', container: 'body'});
	if (location.hash === '#tools-tab') bootstrap.Tab.getOrCreateInstance(document.querySelector('[data-bs-target="#tools-tab"]')).show();
	display();
})();
