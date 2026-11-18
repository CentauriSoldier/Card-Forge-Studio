'use strict';
/* The original admin owns the interface. This module supplies Studio transport,
   game data, and the processing formerly performed by its PHP endpoints. */
(() => {
	let snapshot = JSON.parse(document.getElementById('studio-bootstrap').textContent);
	let nextId = 1;
	let active = null;
	let transportReady = document.readyState === 'complete';
	const queue = [];
	const md = window.markdownit({html: false, linkify: false, breaks: false});
	const validateLink = md.validateLink;
	// Only this exact, attribute-restricted anchor syntax creates an HTML target.
	// Markdown's code rules run first, so examples inside code remain literal.
	md.inline.ruler.before('html_inline', 'manual_anchor', (state, silent) => {
		const match = /^<a id="([A-Za-z][A-Za-z0-9_-]*)"><\/a>/.exec(state.src.slice(state.pos));
		if (!match) return false;
		if (!silent) { const token = state.push('html_inline', '', 0); token.content = '<a class="manual-anchor" id="' + match[1] + '"></a>'; }
		state.pos += match[0].length;
		return true;
	});
	md.validateLink = url => !/^cfsmanual:/i.test(url) && validateLink(url);
	md.renderer.rules.heading_open = (tokens, index, options, environment, renderer) => {
		const id = environment.headingIds?.get(tokens[index].map?.[0]);
		if (id) tokens[index].attrSet('id', id);
		return renderer.renderToken(tokens, index, options);
	};
	let dirtyReader = () => false;
	const settingsDrafts = new Set();

	/** Escapes plain text for generated HTML and attributes. */
	function escape(value) { return String(value).replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char])); }
	/** Returns a required game-owned snapshot record. */
	function record(path) { const value = snapshot.files[path]; if (!value) throw new Error('Required manual file is missing: ' + path); return value; }
	/** Queues one JSON request; only one title-message exchange is in flight at a time. */
	function request(value) {
		return new Promise((resolve, reject) => {
			const encoded = encodeURIComponent(JSON.stringify(value));
			// Chromium truncates native title updates at 4096 characters. Leave
			// ample room for the protocol header as well as the encoded payload.
			const chunks = encoded.match(/.{1,2048}/g) || [''];
			queue.push({id: nextId++, chunks, index: 0, resolve, reject, operation: value.action, kind: value.kind, retries: 0, timeout: null});
			pump();
		});
	}
	/** Starts the next queued native operation. */
	function pump() { if (transportReady && !active && queue.length) { active = queue.shift(); send(); } }
	// Keep native callbacks queued until every deferred script is initialized.
	document.addEventListener('DOMContentLoaded', () => {
		transportReady = true;
		setTimeout(pump, 0);
		pollReply();
	}, {once: true});
	/** Polls only this runtime page's native-owned response file without blocking Lua. */
	function pollReply() {
		const script = document.createElement('script');
		script.src = snapshot.context.bridgeReplyURL + '?poll=' + Date.now();
		script.onload = script.onerror = () => {
			script.remove();
			setTimeout(pollReply, active ? 25 : 100);
		};
		document.head.append(script);
	}
	/** Sends a bounded title event without navigating or unloading the editor. */
	function send() {
		const item = active;
		clearTimeout(item.timeout);
		item.timeout = setTimeout(() => {
			if (active !== item) return;
			if (item.retries < 2) { item.retries++; send(); return; }
			active = null;
			document.title = 'Manual Editor';
			item.reject(new Error('Studio did not acknowledge ' + item.operation + ' request ' + item.id + ', chunk ' + (item.index + 1) + '/' + item.chunks.length + ' after 3 attempts. Completion is unconfirmed.'));
			pump();
		}, item.operation === 'export' && item.index === item.chunks.length - 1 ? 300000 : 15000);
		const chunk = item.chunks[item.index];
		if (item.operation === 'export' && item.index === item.chunks.length - 1) document.dispatchEvent(new CustomEvent('manual-export-phase', {detail: {kind: item.kind}}));
		document.title = 'cfsmanual://bridge/' + item.id + '/' + (item.index + 1) + '/' + item.chunks.length + '?attempt=' + item.retries + '&length=' + chunk.length + '&data=' + chunk;
	}
	/** Receives a chunk acknowledgment and schedules the next title message. */
	function ack(id, part) { if (!active || active.id !== id || part !== active.index + 1) return; clearTimeout(active.timeout); active.index++; active.retries = 0; setTimeout(send, 0); }
	/** Resolves a Lua result and advances the queue after its reply script completes. */
	function receive(id, json) {
		if (!active || active.id !== id) return;
		const item = active; active = null;
		clearTimeout(item.timeout);
		document.title = 'Manual Editor';
		try { const result = JSON.parse(json); if (!result.ok) throw new Error(result.message || 'Studio operation failed.'); if (result.snapshot) snapshot = result.snapshot;
            if (result.delta) {
                const {files, removed, ...metadata} = result.delta;
                const merged = {...snapshot.files, ...files};
                for (const path of removed || []) delete merged[path];
                snapshot = {...snapshot, ...metadata, files: merged};
            }
            item.resolve(result); }
		catch (error) { item.reject(error); }
		setTimeout(pump, 0);
	}
	/** Writes one validated batch against the snapshot versions held by Lua. */
	async function write(files) { return request({action: 'write-batch', files: Object.entries(files).map(([path, text]) => ({path, text, version: record(path).version}))}); }
	/** Reports current editor draft flags to the native close handler. */
	let lastDirty;
	let dirtyTicket = 0;
	function reportDirty() {
		const dirty = !!dirtyReader() || settingsDrafts.size > 0;
		if (dirty === lastDirty) return;
		lastDirty = dirty; const ticket = ++dirtyTicket;
		request({action: 'draft-state', dirty}).catch(() => { if (ticket === dirtyTicket) lastDirty = undefined; });
	}
	/** Includes pending or failed settings saves in Studio's close protection. */
	function setSettingsDirty(name, dirty) { if (dirty) settingsDrafts.add(name); else settingsDrafts.delete(name); reportDirty(); }
	/** Opens a chapter through the host so it rebuilds the original template. */
	function open(file) {
		if (settingsDrafts.size) {
			document.getElementById('content-file').value = document.getElementById('admin-app').dataset.file;
			document.getElementById('admin-notice').textContent = 'Let settings finish saving, or correct their save error, before opening another document.';
			return;
		}
		window.location.href = 'cfsmanual://open?file=' + encodeURIComponent(file);
	}
	/** Returns a parsed JSON configuration from its current snapshot. */
	function config(path) { return JSON.parse(record(path).text); }
	/** Resolves ordered filename stems, appending existing unlisted chapters. */
	function orderState() {
		const files = Object.keys(snapshot.files).filter(path => /^Content\/[^/]+\.md$/i.test(path)).map(path => path.slice(8));
		const byStem = new Map(files.map(name => [name.slice(0,-3).toLowerCase(), name]));
		const used = new Set();
		const names = [];
		for (const line of record('Content/_ORDER_.txt').text.split(/\r?\n/)) { const name = byStem.get(line.trim().toLowerCase()); if (name && !used.has(name)) { names.push(name.slice(0,-3)); used.add(name); } }
		for (const name of files.sort((a,b) => a.localeCompare(b))) if (!used.has(name)) names.push(name.slice(0,-3));
		return {names, version: record('Content/_ORDER_.txt').version};
	}
	/** Converts safely rendered heading text to its plain glossary matching string. */
	function plain(text) { const node = document.createElement('div'); node.innerHTML = md.renderInline(text.replace(/<\/?:?[A-Za-z_][A-Za-z0-9_-]*>/g,'')); return node.textContent; }
	/** Parses the existing stable glossary markers into individually editable blocks. */
	function glossaryParts(text) {
		const pattern = /<!-- section: ([a-z0-9-]+)(?:; quicksheet: [a-z0-9-]+)?; source: [0-9]+ -->\r?\n(#{2,6}) ([^\r\n]+)(?:\r?\n|$)/g;
		const matches = [...text.matchAll(pattern)];
		if (!matches.length || matches[0][1] !== 'glossary') throw new Error('The glossary needs its stable Glossary chapter marker.');
		const entries = {};
		matches.slice(1).forEach((match,index) => {
			if (match[2] !== '###') throw new Error('Glossary entries must use level-three headings.');
			entries[match[1]] = {title: plain(match[3]), header: match[0], markdown: text.slice(match.index + match[0].length, matches[index+2]?.index ?? text.length).replace(/^(?:\r?\n)+|(?:\r?\n)+$/g,'')};
		});
		return {prefix: text.slice(0,matches[1]?.index ?? text.length), entries, newline: text.includes('\r\n') ? '\r\n' : '\n'};
	}
	/** Locates the glossary by its stable chapter marker, including after file rename. */
	function glossaryPath() { const path = Object.keys(snapshot.files).find(path => /^Content\/.*\.md$/i.test(path) && /<!-- section: glossary;/.test(snapshot.files[path].text)); if (!path) throw new Error('The manual has no marked glossary chapter.'); return path; }
	/** Rejects aliases or titles matching more than one entry, including Unicode case variants. */
	function validateGlossary(entries, alternatives) {
		const index = new Map();
		for (const [id, strings] of Object.entries(alternatives)) if (!entries[id] || !Array.isArray(strings)) throw new Error('Alternatives refer to an unknown glossary entry.');
		for (const [id, entry] of Object.entries(entries)) for (const term of [entry.title, ...(alternatives[id] || [])]) {
			if (typeof term !== 'string' || !term.trim() || /[\x00-\x1f\x7f]/.test(term)) throw new Error('Use nonempty complete alternative strings, one per line.');
			const key = term.toLowerCase();
			if (index.has(key) && index.get(key) !== id) throw new Error('Glossary match belongs to more than one entry: ' + term);
			index.set(key,id);
		}
		return index;
	}
	/** Builds the original per-entry Glossary editor's state. */
	function glossaryState() {
		let path;
		try { path = glossaryPath(); } catch (_) { return {entries:{},alternatives:{},hover_delay_ms:config('Config/glossary-settings.json').hover_delay_ms,version:record('Config/glossary-alternatives.json').version+':'+record('Config/glossary-settings.json').version,document:{file:'glossary.md',version:''},missing:true}; }
		const source = record(path);
		const parts = glossaryParts(source.text);
		const entries = {};
		const alternatives = config('Config/glossary-alternatives.json');
		for (const [id,entry] of Object.entries(parts.entries).sort(([,a],[,b]) => a.title.localeCompare(b.title,undefined,{sensitivity:'base',numeric:true}))) entries[id] = {...entry, id, href:'#'+id, version:source.version};
		validateGlossary(entries, alternatives);
		return {entries, alternatives, hover_delay_ms: config('Config/glossary-settings.json').hover_delay_ms, version: record('Config/glossary-alternatives.json').version + ':' + record('Config/glossary-settings.json').version, document:{file:path.slice(8),version:source.version}};
	}
	/** Reassembles the glossary in alphabetical order while preserving stable entry IDs. */
	function composeGlossary(parts) { const blocks = Object.values(parts.entries).sort((a,b) => a.title.localeCompare(b.title,undefined,{sensitivity:'base',numeric:true})); return (parts.prefix.replace(/\r\n/g,'\n').replace(/\n+$/,'')+'\n\n'+blocks.map(entry => entry.header.replace(/\r\n/g,'\n').trimEnd()+'\n\n'+entry.markdown.replace(/\r\n/g,'\n').replace(/^\n+|\n+$/g,'')+'\n\n').join('')).replace(/\n/g,parts.newline); }
    let previewGlossarySnapshot, previewGlossary;
    function glossaryForPreview() {
        if (previewGlossarySnapshot !== snapshot) {
            const state = glossaryState();
            previewGlossary = {state, index: validateGlossary(state.entries, state.alternatives)};
            previewGlossarySnapshot = snapshot;
        }
        return previewGlossary;
    }
	/** Renders safe Markdown plus the existing style/glossary wrappers, including rich definitions. */
	function render(source, linkGlossary = true) {
		const aliases = new Map();
		for (const match of (snapshot.files['Styles/font-styles.css']?.text || '').matchAll(/\/\*\s*alias:\s*([\w-]+)\s*=\s*([\w-]+)\s*\*\//g)) aliases.set(match[1].toLowerCase(), match[2].toLowerCase());
		const namedStyles = new Set([...styleNames().map(name => name.toLowerCase()), ...aliases.keys()]);
		const styles = new Set([...namedStyles, 'g', 'sup']);
		const marker = 'CFSSTYLE'+Math.random().toString(36).slice(2)+'TOKEN';
		const tags = [];
		const headingIds = new Map();
		for (const match of source.matchAll(/<!-- section: ([a-z0-9-]+)(?:; quicksheet: [a-z0-9-]+)?; source: [0-9]+ -->\r?\n#+ /g)) headingIds.set(source.slice(0,match.index).split('\n').length,match[1]);
		let text = source.replace(/<!-- section:[\s\S]*?-->/g, match => match.replace(/[^\n]/g,''));
		text = text.replace(/(?<!\\)<(\/?)(:?)([A-Za-z_][A-Za-z0-9_-]*)>/g, (whole,slash,prefix,name) => { if (!(prefix ? namedStyles : styles).has(name.toLowerCase())) return whole; const index=tags.push(escape(whole))-1; return marker+index+'END'; });
		let html = md.render(text, {headingIds});
		tags.forEach((tag,index) => { html=html.split(marker+index+'END').join(tag); });
		const protectedCode=[];
		html=html.replace(/<pre\b[\s\S]*?<\/pre>|<code\b[\s\S]*?<\/code>/g, code => marker+'CODE'+(protectedCode.push(code)-1)+'END');
		let glossary = null;
		let index = null;
        const definitions = new Map();
		if (linkGlossary) { try { const cached = glossaryForPreview(); glossary=cached.state; index=cached.index; } catch (_) { /* Missing glossary must not prevent ordinary Markdown preview. */ } }
		for (let pass=0;pass<20;pass++) {
			let replaced=false;
			html=html.replace(/&lt;(:?)([A-Za-z_][A-Za-z0-9_-]*)&gt;((?:(?!&lt;\/?:?[A-Za-z_][A-Za-z0-9_-]*&gt;)[\s\S])*?)&lt;\/\1\2&gt;/gi,(whole,prefix,name,inside) => {
				const tag=name.toLowerCase(); if (!(prefix ? namedStyles : styles).has(tag)) return whole; replaced=true;
				const builtin=!prefix && ['g','sup'].includes(tag);
				const key=builtin ? tag : (aliases.get(tag) || tag);
				const styled=builtin&&tag==='sup'?'<sup>'+inside+'</sup>':builtin&&tag==='g'?inside:'<span class="font-'+key+'" data-font-style="'+escape(key)+'" data-inline>'+inside+'</span>';
				if (!index || !((builtin && tag === 'g') || (!builtin && key === 'keyword')) || inside.includes('data-glossary-title')) return styled;
				const node=document.createElement('div');node.innerHTML=inside;const id=index.get(node.textContent.toLowerCase());if(!id)return styled;
				const entry=glossary.entries[id];
                if (!definitions.has(id)) definitions.set(id, {html: render(entry.markdown,false), plain: plain(entry.markdown)});
                const definition=definitions.get(id);
				return '<a class="glossary-link" href="#'+escape(id)+'" data-glossary-title="'+escape(entry.title)+'" data-glossary-definition="'+escape(definition.plain)+'" data-glossary-html="'+escape(definition.html)+'" data-glossary-delay="'+glossary.hover_delay_ms+'">'+styled+'</a>';
			});
			if(!replaced)break;
		}
		protectedCode.forEach((code,index) => { html=html.split(marker+'CODE'+index+'END').join(code); });
		const container=document.createElement('div');container.innerHTML=html;
		container.querySelectorAll('a[href]').forEach(link => {
			const match = /^([^/#?]+\.md)#([A-Za-z][A-Za-z0-9_-]*)$/i.exec(link.getAttribute('href'));
			let filename;
			try { filename = match && decodeURIComponent(match[1]); } catch (_) { return; }
			if (match && Object.hasOwn(snapshot.files, 'Content/' + filename)) {
				link.setAttribute('href', '#' + match[2]);
				link.dataset.manualAnchor = '';
			}
		});
		container.querySelectorAll('img').forEach(image => { const raw=image.getAttribute('src')||'';if(/^images\//i.test(raw)){const base=snapshot.context.manualURL.replace(/\/$/,'')+'/Images/';const resolved=new URL(raw.slice(7),base);if(resolved.href.startsWith(base))image.src=resolved.href;else image.removeAttribute('src');} });
		if (linkGlossary && window.CFSManualAppearance) window.CFSManualAppearance.sections(container);
		return container.innerHTML;
	}
	/** Lists names from CFS-generated style declarations only. */
	function styleNames() {
		const names = new Map();
		for (const match of (snapshot.files['Styles/font-styles.css']?.text || '').matchAll(/\/\*\s*style:\s*([A-Za-z_][A-Za-z0-9_-]*)\s*\*\//g)) names.set(match[1].toLowerCase(), match[1]);
		return [...names.values()].sort((a, b) => a.localeCompare(b));
	}
	/** Implements the original endpoint actions using game snapshots and Lua filesystem transactions. */
	async function action(name, values={}) {
		let result;
		if(name==='preview')return {ok:true,html:render(values.content)};
		if(name==='save') {
			const path='Content/'+values.file;if(record(path).version!==values.version)throw new Error('Content version changed; reload before saving.');
			await write({[path]:values.content});result={ok:true,version:record(path).version,message:'Content saved.'};
		} else if(name==='order-save') {
			if(record('Content/_ORDER_.txt').version!==values.version)throw new Error('Document order changed; reload first.');
			const names=JSON.parse(values.names);const current=orderState().names;
			if(names.length!==current.length||new Set(names).size!==names.length||names.some(item=>!current.includes(item)))throw new Error('The document list changed; reload first.');
			const newline=record('Content/_ORDER_.txt').text.includes('\r\n')?'\r\n':'\n';await write({'Content/_ORDER_.txt':names.join(newline)+newline});result={ok:true,message:'Document order saved.'};
		} else if(name.startsWith('glossary-')) {
			let state=glossaryState();
			if(state.missing && name==='glossary-content-save' && !values.entry){await request({action:'documents',operation:'create',name:'glossary.md'});state=glossaryState();values={...values,version:state.document.version};}
			if(state.missing)throw new Error('Create a glossary entry before editing glossary settings.');
			const path=glossaryPath();const parts=glossaryParts(record(path).text);const alternatives=structuredClone(state.alternatives);const files={};let selected=values.entry;
			if(name==='glossary-delay-save'||name==='glossary-save') {
				if(values.version!==state.version)throw new Error('Glossary settings changed; reload first.');
				if(name==='glossary-save'){if(!parts.entries[selected])throw new Error('Choose an existing entry.');alternatives[selected]=[...new Set(values.alternatives.split(/\r?\n/).map(value=>value.trim()).filter(Boolean))];validateGlossary(parts.entries,alternatives);files['Config/glossary-alternatives.json']=JSON.stringify(alternatives,null,4)+'\n';}
				else {const delay=Number(values.hover_delay_ms);if(!Number.isInteger(delay)||delay<0||delay>10000)throw new Error('Delay must be between 0 and 10000 milliseconds.');files['Config/glossary-settings.json']=JSON.stringify({hover_delay_ms:delay},null,4)+'\n';}
			} else {
				if(values.version!==record(path).version)throw new Error('The glossary changed; reload before saving.');
				if(name==='glossary-delete'){if(values.settings_version!==state.version)throw new Error('Glossary alternatives changed; reload first.');if(!parts.entries[selected])throw new Error('Choose an existing entry.');delete parts.entries[selected];delete alternatives[selected];files['Config/glossary-alternatives.json']=JSON.stringify(alternatives,null,4)+'\n';}
				else {const title=String(values.title).trim();if(!title||/[<>\x00-\x1f\x7f]/.test(title))throw new Error('Enter a plain-text entry name.');if(!selected){const base='glossary-'+(title.normalize('NFKD').replace(/\p{M}/gu,'').toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'')||'entry');selected=base;let number=2;while(parts.entries[selected])selected=base+'-'+number++;}else if(!parts.entries[selected])throw new Error('Choose an existing entry.');const previous=parts.entries[selected];const header=previous?previous.header.replace(/(\r?\n)### [^\r\n]*(\r?\n|$)/,(_,before,after)=>before+'### '+title+after):'<!-- section: '+selected+'; source: 0 -->\n### '+title+'\n';parts.entries[selected]={title,markdown:values.content,header};}
				validateGlossary(parts.entries,alternatives);files[path]=composeGlossary(parts);
			}
			await write(files);result={ok:true,message:'Glossary saved.',glossary:glossaryState(),entry_id:selected,version:record(path).version,source_content:record(path).text};
		} else if(name==='run') throw new Error('PDF export is not connected to the Studio editor yet.');
		else throw new Error('This operation is not connected yet: '+name);
		setTimeout(reportDirty,0);return result;
	}
	/** Populates the original template's dynamic fields before its original admin script executes. */
	function initialize() {
		document.getElementById('manual-appearance-styles').textContent = snapshot.appearanceCSS || '';
		document.getElementById('markdown-preview').classList.add('manual-appearance');
		const app=document.getElementById('admin-app');const order=orderState();const files=Object.keys(snapshot.files).filter(path=>/^Content\/[^/]+\.md$/i.test(path));
		const selected=files.includes('Content/'+snapshot.selected)?snapshot.selected:files[0]?.slice(8);
		app.dataset.file=selected||'';app.dataset.version=selected?record('Content/'+selected).version:'';
		document.getElementById('markdown-editor').value=selected?record('Content/'+selected).text:'';
		for(const id of ['save-content','rename-content','delete-content'])document.getElementById(id).disabled=!selected;
		document.getElementById('game-font-styles').textContent=(snapshot.files['Styles/font-styles.css']?.text||'').replace(/@font-face\s*\{[^{}]*\}/g,'');
		const select=document.getElementById('content-file');
		for(const [index,stem]of order.names.entries()){const path=files.find(path=>path.slice(8,-3)===stem);if(!path)continue;const option=document.createElement('option');option.value=path.slice(8);option.textContent=(index+1)+'. '+stem;option.selected=option.value===selected;select.append(option);}
		const tags=document.querySelector('.tag-grid');const styleSelect=document.getElementById('glossary-document-style');
		for(const name of styleNames()){tags.insertAdjacentHTML('beforeend','<button type="button" class="btn btn-sm btn-outline-secondary" data-wrap-style="'+escape(name)+'"><span class="font-'+name.toLowerCase()+'" data-inline>'+escape(name)+'</span></button>');const option=document.createElement('option');option.value=name;option.textContent=name;styleSelect.append(option);}
		document.getElementById('document-order-data').textContent=JSON.stringify(order);
		document.getElementById('glossary-data').textContent=JSON.stringify(glossaryState());
		const list=document.getElementById('document-order-list');for(const [index,name]of order.names.entries())list.insertAdjacentHTML('beforeend','<li draggable="true" data-document="'+escape(name)+'"><span class="document-position">'+(index+1)+'</span><span class="document-name">'+escape(name)+'</span><button type="button" class="btn btn-sm btn-outline-light" data-order-up aria-label="Move '+escape(name)+' up">↑</button><button type="button" class="btn btn-sm btn-outline-light" data-order-down aria-label="Move '+escape(name)+' down">↓</button></li>');
		document.getElementById('markdown-preview').innerHTML=selected?render(record('Content/'+selected).text):'';
		document.getElementById('admin-notice').textContent=snapshot.context.gameName;document.getElementById('admin-notice').className='alert alert-secondary';
	}
	/** Handles new/rename/delete using the existing toolbar styling and Lua document service. */
	async function manage(operation) {
		if (settingsDrafts.size) { alert('Let settings finish saving, or correct their save error, before managing files.'); return; }
		if(dirtyReader()&&!confirm('Discard unsaved changes before managing content files?'))return;
		const file=document.getElementById('admin-app').dataset.file;let name=file;let newName;
		if(operation==='delete'){if(!confirm('Delete '+file+'? This removes its document-order entry and may break links or glossary references. This cannot be undone here.'))return;}
		else {const entered=prompt(operation==='create'?'New Markdown filename:':'Rename Markdown file:',operation==='create'?'':file);if(entered===null)return;if(operation==='create')name=entered;else newName=entered;}
		try{const result=await request({action:'documents',operation,name,newName,version:file?record('Content/'+file).version:undefined});open(result.selected||Object.keys(snapshot.files).find(path=>/^Content\/.*\.md$/i.test(path))?.slice(8)||'intro.md');}
		catch(error){document.getElementById('admin-notice').textContent=error.message;document.getElementById('admin-notice').className='alert alert-danger';}
	}
	window.CFSManual={request,ack,receive,action,render,open,write,config,styles:styleNames,snapshot:()=>snapshot,setSettingsDirty,hasSettingsDrafts:()=>settingsDrafts.size>0,hasDrafts:()=>!!dirtyReader()||settingsDrafts.size>0,bindDirty(reader){dirtyReader=reader;},reportDirty};
	initialize();
	/** Displays the current game manual using the same renderer as editor and glossary previews. */
	function showReader(target) {
		let dialog=document.getElementById('studio-reader');
		if(!dialog){dialog=document.createElement('div');dialog.id='studio-reader';dialog.className='modal fade';dialog.tabIndex=-1;dialog.innerHTML='<div class="modal-dialog modal-fullscreen"><div class="modal-content"><div class="modal-header"><h2 class="modal-title"></h2><button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Back to editor"></button></div><div class="modal-body"></div></div></div>';document.body.append(dialog);}
		dialog.querySelector('.modal-title').textContent=snapshot.context.gameName;
		const files=Object.keys(snapshot.files).filter(path=>/^Content\/.*\.md$/i.test(path));
		dialog.querySelector('.modal-body').innerHTML=orderState().names.map(stem=>{const path=files.find(path=>path.slice(8,-3)===stem);return path?'<article class="manual-section section-level-2 metal-panel">'+render(record(path).text)+'</article>':'';}).join('');
		bootstrap.Modal.getOrCreateInstance(dialog).show();
		if(target)setTimeout(()=>Array.from(dialog.querySelectorAll('[id]')).find(node=>node.id===target)?.scrollIntoView(),200);
	}
	document.getElementById('back-to-manual').addEventListener('click',event=>{event.preventDefault();showReader();});
	document.addEventListener('click', event => {
		const link = event.target.closest?.('a[href^="#"]');
		if (!link || !link.closest('.markdown-preview, .glossary-document-preview, #studio-reader')) return;
		const id = link.getAttribute('href').slice(1);
		if (!id || link.id === 'back-to-manual') return;
		event.preventDefault();
		if (!link.closest('#studio-reader')) showReader(id);
		else Array.from(document.getElementById('studio-reader').querySelectorAll('[id]')).find(node => node.id === id)?.scrollIntoView();
	});
	document.getElementById('new-content').addEventListener('click',()=>manage('create'));
	document.getElementById('rename-content').addEventListener('click',()=>manage('rename'));
	document.getElementById('delete-content').addEventListener('click',()=>manage('delete'));
	document.addEventListener('input',()=>setTimeout(reportDirty,0));document.addEventListener('change',()=>setTimeout(reportDirty,0));
})();
