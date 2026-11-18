'use strict';
/* PDF-only paginator and explicit local-browser print controller. No network
   service is used: the connection belongs to this disposable headless browser. */
/* The print document has no visible animation. Paged.js captures these hooks
   when it loads; timer-backed callbacks keep its queue moving even when the
   headless page is hidden behind Studio. Layout still completes before print. */
/** Schedules the next static-layout queue step without a display refresh. */
window.requestAnimationFrame = callback => window.setTimeout(() => callback(performance.now()), 0);
/** Cancels a pending static-layout queue step. */
window.cancelAnimationFrame = handle => window.clearTimeout(handle);
/** Runs pagination work without waiting indefinitely for browser idle time. */
window.requestIdleCallback = callback => window.setTimeout(() => callback({didTimeout: true, timeRemaining: () => 0}), 0);
/** Cancels pending pagination work. */
window.cancelIdleCallback = handle => window.clearTimeout(handle);
window.PagedConfig = {auto: false};
console.info('CFS_PDF_STAGE: connecting print controller');
const printPreview = new URLSearchParams(location.search).get('preview') === '1';
const printConnectionReady = new Promise(resolve => { window.CFSPrintConnect = resolve; });
const printDeliveryReady = new Promise(resolve => { window.CFSPrintDelivered = resolve; });

/** Waits for the native host to confirm that it has read the delivered file. */
function waitForPrintDelivery() {
	const script = document.createElement('script');
	script.src = 'js/PrintDelivered.js?attempt=' + Date.now();
	script.onerror = () => { script.remove(); setTimeout(waitForPrintDelivery, 100); };
	document.head.append(script);
}

/** Loads the connection file once the native host has started its own browser. */
function loadPrintConnection() {
	const script = document.createElement('script');
	script.src = 'js/PrintConnection.js?attempt=' + Date.now();
	script.onerror = () => { script.remove(); setTimeout(loadPrintConnection, 100); };
	document.head.append(script);
}

/** Opens the owned browser protocol, matching replies to their requests. */
async function openPrintControl(connection) {
	const socket = new WebSocket(connection.url);
	const pending = new Map();
	let nextId = 1;
	let downloadComplete = null;
	await new Promise((resolve, reject) => {
		const timer = setTimeout(() => reject(new Error('The PDF print connection did not open within 15 seconds.')), 15000);
		socket.onopen = () => { clearTimeout(timer); resolve(); };
		socket.onerror = () => { clearTimeout(timer); reject(new Error('Cannot connect to the local PDF print process.')); };
	});
	socket.onmessage = event => {
		const message = JSON.parse(event.data);
		if (message.id && pending.has(message.id)) {
			const item = pending.get(message.id); pending.delete(message.id); clearTimeout(item.timer);
			if (message.error) item.reject(new Error(message.error.message)); else item.resolve(message.result);
		}
		if (message.method === 'Browser.downloadProgress' && downloadComplete) {
			if (message.params.state === 'completed') { downloadComplete.resolve(); downloadComplete = null; }
			else if (message.params.state === 'canceled') { downloadComplete.reject(new Error('PDF file delivery was canceled.')); downloadComplete = null; }
		}
	};
	socket.onclose = () => { pending.forEach(item => { clearTimeout(item.timer); item.reject(new Error('The PDF print process closed.')); }); pending.clear(); if (downloadComplete) { downloadComplete.reject(new Error('The PDF print process closed during file delivery.')); downloadComplete = null; } };
	/** Sends one protocol operation to the owned browser or its print page. */
	function call(method, params = {}, sessionId) {
		return new Promise((resolve, reject) => {
			const id = nextId++;
			const timer = setTimeout(() => { pending.delete(id); reject(new Error(method + ' did not finish within 90 seconds.')); }, 90000);
			pending.set(id, {resolve, reject, timer});
			socket.send(JSON.stringify({id, method, params, ...(sessionId ? {sessionId} : {})}));
		});
	}
	await call('Browser.setDownloadBehavior', {behavior: 'allow', downloadPath: connection.directory, eventsEnabled: true});
	/** Delivers one generated file directly into the owned staging folder. */
	async function deliver(bytes, name) {
		const complete = new Promise((resolve, reject) => { downloadComplete = {resolve, reject}; });
		const url = URL.createObjectURL(new Blob([bytes], {type: name.endsWith('.pdf') ? 'application/pdf' : 'text/plain'}));
		const link = document.createElement('a'); link.hidden = true; link.href = url; link.download = name;
		document.body.append(link); link.click();
		await complete;
		link.remove(); URL.revokeObjectURL(url);
	}
	/** Closes only this disposable browser after its file delivery completes. */
	function close() { socket.send(JSON.stringify({id: nextId++, method: 'Browser.close'})); }
	return {call, deliver, close};
}

/** Lays out the complete book before requesting PDF generation and delivery. */
async function paginateManual() {
	let control;
	try {
		if (!printPreview) {
			const connection = await printConnectionReady;
			control = await openPrintControl(connection);
		}
		const settings = JSON.parse(document.getElementById('pdf-document-data').textContent);
		console.info('CFS_PDF_STAGE: loading fonts and images');
		document.documentElement.dataset.pdfStage = 'fonts';
		await document.fonts.ready;
		await Promise.all([...document.images].map(image => image.decode()));
		console.info('CFS_PDF_STAGE: paginating manual');
		class ExportProgress extends window.Paged.Handler {
			afterPageLayout(element, page) {
				console.info('CFS_PDF_STAGE: paginating page ' + (page.position + 1));
			}
		}
		window.Paged.registerHandlers(ExportProgress);
		document.documentElement.dataset.pdfStage = 'layout';
		const flow = await window.PagedPolyfill.preview();
		if (!flow.total) throw new Error('Pagination produced no pages.');
		for (const page of document.querySelectorAll('.pagedjs_page')) {
			const header = page.querySelector('.pdf-page-header');
			const area = page.querySelector('.pagedjs_area');
			if (!header || !area) throw new Error('A PDF page is missing its header or content area.');
			const h = header.getBoundingClientRect(); const a = area.getBoundingClientRect();
			if (h.width < 1 || h.height < 1 || h.bottom > a.top + 1) throw new Error('The shared header component does not fit above the PDF content area.');
		}
		document.documentElement.dataset.pdfReady = String(flow.total);
		if (printPreview) { document.title = 'CFS_PDF_READY:' + flow.total; return; }
		document.title = settings.title;
		console.info('CFS_PDF_STAGE: printing ' + flow.total + ' pages');
		const targets = await control.call('Target.getTargets');
		const target = targets.targetInfos.find(target => target.type === 'page' && target.url === location.href);
		if (!target) throw new Error('Cannot identify the owned PDF document.');
		const session = await control.call('Target.attachToTarget', {targetId: target.targetId, flatten: true});
		const result = await control.call('Page.printToPDF', {printBackground: true, preferCSSPageSize: true, displayHeaderFooter: false, generateDocumentOutline: true}, session.sessionId);
		const binary = atob(result.data);
		const bytes = Uint8Array.from(binary, char => char.charCodeAt(0));
		console.info('CFS_PDF_STAGE: delivering PDF');
		await control.deliver(bytes, 'Manual.pdf');
		waitForPrintDelivery(); await printDeliveryReady;
		control.close();
	} catch (error) {
		console.error('CFS_PDF_STAGE: failed: ' + error.message);
		document.documentElement.dataset.pdfError = error.message;
		if (printPreview) { document.title = 'CFS_PDF_ERROR:' + error.message; return; }
		if (control) { try { await control.deliver(error.message, 'Print-error.txt'); waitForPrintDelivery(); await printDeliveryReady; } finally { control.close(); } }
	}
}
if (!printPreview) loadPrintConnection();
document.addEventListener('DOMContentLoaded', paginateManual, {once: true});
