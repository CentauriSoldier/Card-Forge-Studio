/* Page-oriented editing. Game styles are supplied by Lua, never duplicated here. */
(() => {
    "use strict";
    const app = document.getElementById("manual-app");
    const enc = new TextEncoder(), dec = new TextDecoder();
    const hexBytes=Array.from({length:256},(_,b)=>b.toString(16).padStart(2,"0"));
    const hex = text => {const bytes=enc.encode(text),parts=[];for(let start=0;start<bytes.length;start+=8192){let part="";for(let i=start;i<Math.min(bytes.length,start+8192);i++)part+=hexBytes[bytes[i]];parts.push(part);}return parts.join("");};
    const unhex = text => dec.decode(Uint8Array.from(text.match(/../g) || [], b => parseInt(b, 16)));
    const escape = text => String(text).replace(/[&<>"']/g, c => ({"&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#39;"}[c]));
    const clone = value => JSON.parse(JSON.stringify(value));
    const presets = {letter:[215.9,279.4], legal:[215.9,355.6], a4:[210,297], a5:[148,210], "half-letter":[139.7,215.9]};
    let styles = [], gameStyles = [], model, pageIndex = 0, selected = null, range = null, zoom = 0.7, revision = 0, interfaceZoom = 1;
    let undo = [], redo = [], typingAt = 0, activeTool = "move", selectedNode = 0, masterIndex = null;
    const isText = o => o && ["text","artistic","table","ordered-list","unordered-list"].includes(o.type);
    const isImage = o => o && ["image","picture","picture-ellipse"].includes(o.type);
    const typeName = type => ({text:"Frame Text",artistic:"Artistic Text",table:"Table",'ordered-list':"Ordered List",'unordered-list':"Unordered List",toc:"Table of Contents",image:"Image",picture:"Picture Frame",'picture-ellipse':"Ellipse Picture Frame",line:"Line",curve:"Curve"}[type] || CFSShapes.names.get(type) || type);
    const options = document.getElementById("manual-options");
    const form = document.getElementById("manual-options-form");
    const styleFor = name => styles.find(s => s.name === name);
    function loadStyles() {
        gameStyles = Array.from(document.querySelectorAll("#game-style-data span"), e => ({name:e.dataset.name, tag:e.dataset.tag}));
        styles = gameStyles.concat(model?CFSManualStyles.items(model):[]).sort((a,b)=>a.name.localeCompare(b.name));
    }
    loadStyles();
    let editorTheme=(document.getElementById('editor-preferences')||{}).dataset?.theme||'dark';
    function applyTheme(name) {
        const theme=CFSManualThemes[name]||CFSManualThemes.dark;editorTheme=CFSManualThemes[name]?name:'dark';
        for(const [key,value]of Object.entries(theme.colors))document.documentElement.style.setProperty('--editor-'+key,value);
        const root=document.documentElement;root.dataset.cfsEditorTheme=editorTheme;root.dataset.cfsEditorBackground=theme.colors.toolbar;root.dataset.cfsEditorText=theme.colors.text;
    }
    applyTheme(editorTheme);
    const defaultStyle = () => (styleFor("BASE") || styles[0] || {}).name || "";
    const id = prefix => prefix + model.nextId++;
    const page = () => masterIndex == null ? model.pages[pageIndex] : model.masters[masterIndex];
    const object = () => page().objects.find(o => o.id === selected);
    const styleAttribute = name => name ? ` data-style="${escape(name)}"` : "";
    const units = () => model.settings.units === "in" ? 25.4 : 1;
    const number = v => Math.round(Number(v) * 1000) / 1000;
    const settingsDefaults = () => ({preset:"letter",units:"mm",width:215.9,height:279.4,orientation:"portrait",margin:12.7,marginInner:12.7,marginOuter:12.7,marginTop:12.7,marginBottom:12.7,bleed:0,facingPages:false,textSize:12,zoomStep:4,textStyle:defaultStyle(),pageNumbers:true,numberStyle:defaultStyle(),numberStart:1,numberFormat:"decimal",numberPosition:"center",...CFSSnapping.defaults});
    function newPage() { return {id:id("page-"),name:"Page " + (model.pages.length + 1),background:"#ffffff",backgroundImage:"",backgroundMode:"cover",objects:[]}; }
    function newObject(type, extra = {}) {
        const margin = model.settings.margin;
        return Object.assign({id:id("object-"),name:typeName(type),type,x:margin,y:margin,w:type === "text" ? 100 : 60,h:type === "text" ? 45 : 40,rotation:0,opacity:1,visible:true,locked:false,fill:type === "text" || type === "image" ? "transparent" : "#7988a1",stroke:"#263244",strokeWidth:0,radius:type === "rounded" ? 6 : 0,hue:0,style:model.settings.textStyle,fontSize:isText({type})?(model.settings.textSize||12):0,align:"left",lineHeight:1.4,spacing:null,html:"",src:"",fit:"cover",focusX:50,focusY:50,sides:5,innerRadius:45,rows:3,columns:3,nodes:[[0,100],[50,0],[100,100]],closed:false},type==='toc'?{fill:'transparent',contentsDepth:6,contentsLeader:'dots',contentsStyles:Array(6).fill(model.settings.textStyle),contentsEntries:[]}: {}, extra);
    }
    try {
        const source = unhex(document.getElementById("manual-input").dataset.source);
        const doc = new DOMParser().parseFromString(source, "text/html");
        const state = doc.getElementById("cfs-manual-state");
        if (state) {
            model = JSON.parse(unhex(state.dataset.state));
            if (model.version !== 1 || !model.settings || !Array.isArray(model.pages) || !model.pages.length) throw new Error("Unsupported visual manual document.");
            const s = model.settings;
            if (![s.width,s.height,s.margin].every(Number.isFinite) || s.width <= 0 || s.height <= 0 || s.margin < 0) throw new Error("Invalid manual page dimensions.");
        } else {
            model = {version:1,nextId:1,settings:settingsDefaults(),pages:[]};
            const sections = Array.from(doc.body.children).filter(e => e.tagName === "SECTION");
            const content = sections.length && sections.length === doc.body.children.length ? sections.map(e => e.outerHTML) : [source];
            for (const html of content) {
                const p = newPage(); model.pages.push(p);
                p.objects.push(newObject("text", {name:"Imported content",html,w:model.settings.width-2*model.settings.margin,h:model.settings.height-2*model.settings.margin}));
            }
        }
        model.masters = model.masters || [];
        CFSMasterPages.validate(model);
        document.getElementById('manual-input').remove();
    } catch (error) {
        if(window.CFSManualDiagnostics)window.CFSManualDiagnostics.report(error,'open manual');
        app.innerHTML = `<div class="manual-error"><h2>Unable to open the visual manual</h2><p>${escape(error.message)}</p><p>The saved file has not been changed.</p></div>`;
        document.documentElement.dataset.cfsError=hex(error.message);return;
    }
    Object.assign(model.settings,Object.assign({},CFSSnapping.defaults,model.settings));
    for(const key of ['marginInner','marginOuter','marginTop','marginBottom'])model.settings[key]??=model.settings.margin;model.settings.bleed??=0;
    {const s=model.settings;if(![s.marginInner,s.marginOuter,s.marginTop,s.marginBottom,s.bleed].every(n=>Number.isFinite(n)&&n>=0)||s.marginInner+s.marginOuter>=s.width||s.marginTop+s.marginBottom>=s.height)throw new Error('Invalid manual margins or bleed.');}
    for(const p of model.pages)CFSLayers.validate(p.objects);
    model.manualStyles=model.manualStyles||[];model.settings.facingPages??=false;model.settings.textSize??=12;model.settings.zoomStep??=4;loadStyles();
    CFSContents.settings(model);
    let linkFrom=null,flowTimer=null,editingObjectId=null;
    let savedState=JSON.stringify(model),lastSnapshotState,lastSnapshotRevision,dirty=false;
    const locked=o=>CFSLayers.locked(page().objects,o);
    function checkpoint() {const value=JSON.stringify(model);if(undo[undo.length-1]!==value)undo.push(value);if(undo.length>100)undo.shift();redo=[];}
    function change(fn) {checkpoint();fn();revision++;dirty=JSON.stringify(model)!==savedState;render();}
    function restore(from,to) {if(!from.length)return;to.push(JSON.stringify(model));model=JSON.parse(from.pop());pageIndex=Math.min(pageIndex,model.pages.length-1);if(masterIndex!=null&&masterIndex>=model.masters.length)masterIndex=null;selected=null;range=null;revision++;dirty=JSON.stringify(model)!==savedState;render();}
    function numeral(n) {
        if(model.settings.numberFormat==='decimal'||n<1||n>3999)return String(n);
        let text='';for(const[value,symbol]of [[1000,'M'],[900,'CM'],[500,'D'],[400,'CD'],[100,'C'],[90,'XC'],[50,'L'],[40,'XL'],[10,'X'],[9,'IX'],[5,'V'],[4,'IV'],[1,'I']])while(n>=value){text+=symbol;n-=value;}
        return model.settings.numberFormat==='roman'?text.toLowerCase():text;
    }
    function background(p) {return `background-color:${p.background};`+(p.backgroundImage?`background-image:url('${p.backgroundImage.replace(/'/g,'%27')}');background-position:center;background-size:${p.backgroundMode==='tile'?'auto':p.backgroundMode};background-repeat:${p.backgroundMode==='tile'?'repeat':'no-repeat'};`:'');}
    function objectHTML(o,editing=false,list=page().objects,offset=0,override=null) {
        if(!o.visible)return '';
        const isLocked=CFSLayers.locked(list,o),vector=CFSShapes.has(o.type),cursor=isLocked?'default':isText(o)?'default':'move';
        const outer=`pointer-events:auto;${editing?`cursor:${cursor};`:''}left:${o.x+offset}mm;top:${o.y}mm;width:${o.w}mm;height:${o.h}mm;transform:rotate(${o.rotation}deg);opacity:${o.opacity};filter:hue-rotate(${o.hue}deg);background:${vector?'transparent':o.fill};border:${vector?0:o.strokeWidth}mm solid ${o.stroke};border-radius:${o.type==='picture-ellipse'?'50%':o.radius+'mm'};`;
        let inside='';
        const textSize=o.style?.startsWith('manual:')?CFSManualStyles.resolve(model,o.style).overrides.size:null;
        const blockSize=textSize??(o.fontSize||model.settings.textSize||12),textHTML=override??(CFSLists.has(o.type)?CFSLists.render(o):CFSTextFlow.text(o));
        if(isText(o))inside=`<div class="manual-text"${styleAttribute(o.style)} ${editing?`contenteditable="${!isLocked&&['text','artistic','table','ordered-list','unordered-list'].includes(activeTool)}" spellcheck="true"`:''} style="${o.type==='artistic'?'white-space:pre;':''}text-align:${o.align};line-height:${o.lineHeight};${o.spacing==null?'':`letter-spacing:${o.spacing}pt;`}${`font-size:${blockSize}pt;`}">${textHTML}</div>`;
        if(isText(o)&&Number(o.headingLevel)>0&&Number(o.headingLevel)<=6)inside=inside.replace('class="manual-text"',`class="manual-text" role="heading" aria-level="${Number(o.headingLevel)}"`);
        if(o.type==='toc')inside=override??CFSContents.render(o,model,CFSTextFlow.entries(o,model));
        if(isImage(o))inside=o.src?`<img class="manual-image" src="${escape(o.src)}" alt="${escape(o.name)}" draggable="false" style="object-fit:${o.fit};object-position:${o.focusX}% ${o.focusY}%;border-radius:inherit;">`:CFSLayers.children(list,o.id).length?'':'<div style="height:100%;display:flex;align-items:center;justify-content:center;border:1px dashed #768ca4;background:#dfe9f1;color:#41566c;font:12px sans-serif;border-radius:inherit">Choose image in Properties</div>';
        if(isImage(o)&&o.pdfClip){const key='imported-image-clip-'+o.id;inside=`<svg width="0" height="0" style="position:absolute" aria-hidden="true"><defs><clipPath id="${escape(key)}" clipPathUnits="objectBoundingBox"><path d="${escape(o.pdfClip.path)}" clip-rule="${o.pdfClip.rule==='evenodd'?'evenodd':'nonzero'}"/></clipPath></defs></svg><div style="width:100%;height:100%;clip-path:url('#${escape(key)}')">${inside}</div>`;}
        if(vector)inside=CFSShapes.render(o);
        const handles=editing&&!isLocked&&o.id===selected?'<div class="move-handle" title="Drag to move">⋮⋮</div><div class="resize-handle" title="Shift: proportions · Ctrl: from center"></div>':'';
        const flowHandles=editing&&CFSTextFlow.supports(o)&&!isLocked?`<button type="button" class="flow-output" data-flow-link="${escape(o.id)}" title="Link to next frame${o.flowNext?' · linked':''}" aria-label="Link to next frame">${o.flowNext?'↗':'→'}</button>`:'';
        const nodes=editing&&activeTool==='node'&&o.type==='curve'&&o.id===selected&&!isLocked?o.nodes.map((p,i)=>`<button class="node-handle" data-node="${i}" title="Curve node ${i+1}" style="left:${p[0]}%;top:${p[1]}%"></button>`).join(''):'';
        const clipKey='manual-clip-'+o.id,mask=CFSShapes.clip(o,clipKey);
        return `<div class="manual-object ${editing?'editable-object':''} ${editing&&o.id===selected?'selected':''}" id="manual-object-${escape(o.id)}" data-id="${escape(o.id)}" style="${outer}">${inside}${mask}<div class="layer-children" style="position:absolute;inset:0;pointer-events:none;${CFSShapes.clips(o)?`clip-path:url('#${clipKey}');`:['picture','picture-ellipse'].includes(o.type)?'overflow:hidden;border-radius:inherit;':''}">${CFSLayers.children(list,o.id).map(n=>objectHTML(n,editing,list)).join('')}</div>${handles}${nodes}${flowHandles}</div>`;
    }
    function masterObjects(master,prefix){const copies=CFSMasterPages.objects(master,prefix);for(let i=0;i<copies.length;i++){if(master.objects[i].type==='toc')copies[i].flowEntries=CFSTextFlow.entries(master.objects[i],model);else if(CFSTextFlow.supports(master.objects[i]))copies[i].html=CFSTextFlow.clean(CFSTextFlow.text(master.objects[i]));delete copies[i].flowHTML;delete copies[i].flowNext;}return copies;}
    function pageHTML(p,index,editing=false,mode="normal") {
        const master=CFSMasterPages.find(model,p.masterId),isMaster=model.masters.includes(p),inherited=master?masterObjects(master,p.id+'-master-'):[];
        const s=model.settings,m=CFSSnapping.margins(s,index),numberHTML=s.pageNumbers?`<div class="manual-number"${styleAttribute(s.numberStyle)} style="left:${m.left}mm;right:${m.right}mm;bottom:${Math.max(1,m.bottom/3)}mm;text-align:${s.numberPosition};">${isMaster?'#':numeral(s.numberStart+index)}</div>`:'';
        let objects='';
        if(mode==='normal'){
            const roots=CFSLayers.children(p.objects),ordered=roots.flatMap((o,level)=>!o.spread||isMaster?[{level,html:objectHTML(o,editing,p.objects)}]:[]);
            if(!isMaster)for(const shared of CFSSpreads.shared(model,index)){const copy=CFSSpreads.shifted(shared.list,shared.o,shared.offset,shared.owner===index?'':p.id+'-spread-');ordered.push({level:CFSLayers.children(shared.list).indexOf(shared.o),html:objectHTML(copy.root,editing&&shared.owner===index,copy.list)});}
            objects=CFSLayers.children(inherited).map(o=>objectHTML(o,false,inherited)).join('')+ordered.sort((a,b)=>a.level-b.level).map(n=>n.html).join('');
        }
        const paper=mode==='guides'?'background:transparent;':background(master&&p.useMasterBackground!==false?master:p);
        return `<section class="manual-page ${mode==='guides'?'spread-guides':''}" data-page="${escape(p.id)}" style="width:${s.width}mm;height:${s.height}mm;${paper}">${objects}${mode==='background'?'':numberHTML}${editing&&mode!=='background'&&s.gridVisible?`<div class="grid-guide" style="position:absolute;inset:0;pointer-events:none;background-image:linear-gradient(to right,#5486ae45 1px,transparent 1px),linear-gradient(to bottom,#5486ae45 1px,transparent 1px);background-size:${s.gridX}mm ${s.gridY}mm"></div>`:''}${editing&&mode!=='background'?`<div class="margin-guide" style="inset:${m.top}mm ${m.right}mm ${m.bottom}mm ${m.left}mm"></div>`:''}</section>`;
    }
    function visiblePages(){return masterIndex==null?CFSSpreads.visible(model,pageIndex):[pageIndex];}
    function viewHTML(editing=false) {
        if(masterIndex!=null)return pageHTML(page(),pageIndex,editing);
        const indices=visiblePages(),s=model.settings;
        if(indices.length===1&&!model.settings.facingPages)return pageHTML(page(),pageIndex,editing);
        let body=indices.map((i,side)=>`<div class="spread-page" style="left:${side*s.width}mm">${pageHTML(model.pages[i],i,editing,'background')}</div>`).join('');
        indices.forEach((i,side)=>{
            const p=model.pages[i],master=CFSMasterPages.find(model,p.masterId),inherited=master?masterObjects(master,p.id+'-master-'):[];
            if(inherited.length)body+=`<div class="page-object-clip" style="left:${side*s.width}mm;width:${s.width}mm;height:${s.height}mm">${CFSLayers.children(inherited).map(o=>objectHTML(o,false,inherited)).join('')}</div>`;
            CFSLayers.children(p.objects).forEach((o,level)=>{const html=objectHTML(o,editing,p.objects,o.spread?side*s.width:0);body+=o.spread?`<div class="spread-object-slot" data-owner-page="${p.id}" style="z-index:${level+1}">${html}</div>`:`<div class="page-object-clip" data-owner-page="${p.id}" style="left:${side*s.width}mm;width:${s.width}mm;height:${s.height}mm;z-index:${level+1}">${html}</div>`;});
        });
        body+=indices.map((i,side)=>`<div class="spread-page spread-guides" style="left:${side*s.width}mm">${pageHTML(model.pages[i],i,editing,'guides')}</div>`).join('');
        return `<div class="manual-spread" style="position:relative;width:${indices.length*s.width}mm;height:${s.height}mm">${body}</div>`;
    }
    function displayedX(o){return o.x+(masterIndex==null&&model.settings.facingPages&&o.spread&&!o.parentId?Math.max(0,visiblePages().indexOf(pageIndex))*model.settings.width:0);}
    function currentCanvas(){return document.querySelector(`#page-zoom .manual-page[data-page="${page().id}"]`)||document.querySelector('#page-zoom .manual-page');}

    function fullSnapshot() {
        prepareFlow();
        lastSnapshotState=JSON.stringify(model);lastSnapshotRevision=revision;
        const s=model.settings,manualCSS=CFSManualStyles.css(model,gameStyles),content=`<style>${manualCSS}</style><template id="cfs-manual-state" data-state="${hex(lastSnapshotState)}"></template><style>@page{size:${s.width}mm ${s.height}mm;margin:0;bleed:${s.bleed||0}mm}</style><div class="cfs-pages">${model.pages.map((p,i)=>pageHTML(p,i)).join('')}</div>`;
        const root=document.documentElement;root.dataset.cfsSnapshot=hex(content);root.dataset.cfsRevision=String(revision);root.dataset.cfsPages=String(model.pages.length);
    }
    let viewRevision=0;
    function snapshot(changed=true) {
        prepareFlow();
        if(changed){revision++;dirty=JSON.stringify(model)!==savedState;}
        const root=document.documentElement;root.dataset.cfsDirty=dirty?'1':'0';root.dataset.cfsRevision=String(revision);root.dataset.cfsPreview=hex('<style>'+CFSManualStyles.css(model,gameStyles)+'</style><div class="cfs-pages">'+viewHTML()+'</div>');root.dataset.cfsView=String(++viewRevision);publishToolbar();
    }
    const icons={'ordered-list':'M7 4H19 M7 11H19 M7 18H19 M2 2V6 M1 10L3 9L3 12H1 M1 17H3V20H1','unordered-list':'M7 4H19 M7 11H19 M7 18H19 M2 4H3 M2 11H3 M2 18H3',toc:'M3 4H19 M3 9H14 M3 14H14 M3 19H19 M18 9H19 M18 14H19',move:'M3 2L18 12L11 13L8 20Z',node:'M4 4H18V18H4Z M4 4L18 18',text:'M3 4H19 M11 4V20 M7 20H15',artistic:'M3 20L11 3L19 20 M6 14H16',table:'M3 3H19V19H3Z M3 8H19 M3 13H19 M8 3V19 M13 3V19',image:'M3 3H19V19H3Z M3 17L8 11L12 15L16 8L19 12',picture:'M3 3H19V19H3Z M3 3L19 19 M19 3L3 19','picture-ellipse':'M11 2A9 9 0 1 1 10.99 2 M5 5L17 17 M17 5L5 17',line:'M3 19L19 3',curve:'M3 19Q3 3 11 11T19 3',rectangle:'M3 4H19V18H3Z',ellipse:'M11 3A8 7 0 1 1 10.99 3',rounded:'M7 3H15Q19 3 19 7V15Q19 19 15 19H7Q3 19 3 15V7Q3 3 7 3Z',up:'M4 14L11 7L18 14',down:'M4 8L11 15L18 8',duplicate:'M7 7H20V20H7Z M3 15V3H15',delete:'M4 6H18 M8 6V3H14V6 M6 6V20H16V6 M9 9V17 M13 9V17',lock:'M5 10H17V20H5Z M7 10V6A4 4 0 0 1 15 6V10',unlock:'M5 10H17V20H5Z M7 10V6A4 4 0 0 1 15 6'};
    const icon=name=>CFSShapes.has(name)?CFSShapes.render({type:name,w:22,h:22,radius:5,fill:"none",stroke:"currentColor",strokeWidth:1.5,sides:5,innerRadius:45}).replace('style="display:block;width:100%;height:100%;overflow:visible;pointer-events:none"','class="tool-icon"'):`<svg class="tool-icon" viewBox="0 0 22 22" aria-hidden="true"><path d="${icons[name]||'M11 2L20 8L17 19H5L2 8Z'}" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/></svg>`;
    const button=(action,label)=>`<button type="button" data-action="${action}">${action==='image'?icon(action):''}${label}</button>`;
        const tool = (name,label) => `<button type="button" data-tool="${name}" title="${label}" aria-label="${label}">${icon(name)}</button>`;
    app.innerHTML = `<div class="visual-layout"><nav class="tool-rail" role="toolbar" aria-label="Object tools">${tool("move","Move (V)")}${tool("node","Node (A)")}<hr>${tool("text","Frame Text (T)")}${tool("artistic","Artistic Text")}${tool("table","Table")}${tool("ordered-list","Ordered List")}${tool("unordered-list","Unordered List")}${tool("toc","Table of Contents")}<hr><button type="button" data-action="image" title="Place Image" aria-label="Place Image">${icon("image")}</button>${tool("picture","Picture Frame")}${tool("picture-ellipse","Ellipse Frame")}<hr>${tool("line","Line")}${tool("curve","Curve")}<details class="shape-menu"><summary title="Shapes (M)" aria-label="Shapes (M)">${icon("rectangle")}</summary><div class="shape-flyout" role="toolbar" aria-label="Shapes">${CFSShapes.catalog.map(([name,label])=>`<button type="button" data-tool="${name}" title="${label}" aria-label="${label}">${icon(name)}<span>${label}</span></button>`).join("")}</div></details></nav><aside class="left-sidebar"><h2>Masters</h2><div class="page-actions">${button("add-master","+")}${button("duplicate-master","Duplicate")}${button("delete-master","−")}</div><div id="master-list"></div><div class="master-apply">${button("apply-master","Apply to current page")}${button("apply-master-all","Apply to all pages")}</div><h2>Pages</h2><div class="page-actions">${button("add-page","+")}${button("delete-page","−")}${button("page-up","↑")}${button("page-down","↓")}</div><div id="page-list"></div><h2>Styles</h2><input id="style-search" placeholder="Find a style" aria-label="Find a style"><div id="style-list"></div></aside><main id="workspace"><div id="page-zoom"></div></main><aside class="right-sidebar"><div class="inspector-content"><h2>Layers</h2><div id="layer-list"></div><h2>Properties</h2><div id="properties"></div></div><div class="layer-actions" role="toolbar" aria-label="Layer actions">${[["up","Move layer up"],["down","Move layer down"],["duplicate","Duplicate (Ctrl+J)"],["delete","Delete (Delete)"],["lock","Lock (Ctrl+L)"],["unlock","Unlock (Ctrl+Shift+L)"]].map(([name,label])=>`<button type="button" data-action="${name}" title="${label}" aria-label="${label}">${icon(name)}</button>`).join("")}</div></aside></div><input type="file" id="image-file" accept="image/*" hidden><div id="editor-status" role="status"></div>`;
    const $ = id => document.getElementById(id);
    function stylesPanel() {
        const search=$('style-search').value.toLowerCase();
        $('style-list').innerHTML=styles.filter(s=>s.name.toLowerCase().includes(search)).map(s=>`<button type="button" data-style-name="${escape(s.name)}" title="${escape('<'+s.tag+'>')}">${escape(s.label||s.name)}</button>`).join("");
    }
    function layers() {
        $('layer-list').innerHTML=(masterIndex==null&&page().masterId?`<div class="inherited-master">Master: ${escape(CFSMasterPages.find(model,page().masterId).name)}<br><small>Shared objects; edit in Masters.</small></div>`:'')+'<div class="layer-root" data-drop-root>Drop here to move to page</div>'+CFSLayers.rows(page().objects).map(({o,depth})=>`<div draggable="${!locked(o)}" data-layer-row="${escape(o.id)}" class="layer-row ${o.id===selected?"active":""}" style="padding-left:${depth*14}px"><button type="button" data-layer="${escape(o.id)}">${depth?'↳ ':''}${escape(o.name)} <small>${escape(typeName(o.type))}</small></button><button type="button" data-visible="${escape(o.id)}" title="Show/hide">${o.visible?"●":"○"}</button><button type="button" data-locked="${escape(o.id)}" title="Lock/unlock">${icon(o.locked?"lock":"unlock")}</button></div>`).join("");
    }
    function reparent(value,target=null) {
        const o=page().objects.find(n=>n.id===value),p=page().objects.find(n=>n.id===target);
        if(!o||locked(o)||p&&(locked(p)||CFSLayers.chain(page().objects,p).some(n=>n.id===o.id)))return false;
        change(()=>CFSLayers.reparent(page().objects,o,p));return true;
    }
    $('layer-list').addEventListener('dragstart',e=>{const row=e.target.closest('[data-layer-row]');if(row)e.dataTransfer.setData('text/plain',row.dataset.layerRow);});
    $('layer-list').addEventListener('dragover',e=>{const row=e.target.closest('[data-layer-row],[data-drop-root]');if(row){e.preventDefault();row.classList.add('drop-target');}});
    $('layer-list').addEventListener('dragleave',e=>{const row=e.target.closest('.drop-target');if(row)row.classList.remove('drop-target');});
    $('layer-list').addEventListener('drop',e=>{e.preventDefault();const row=e.target.closest('[data-layer-row],[data-drop-root]');if(row)reparent(e.dataTransfer.getData('text/plain'),row.dataset.layerRow||null);document.querySelectorAll('.drop-target').forEach(n=>n.classList.remove('drop-target'));});
    const field = (label, key, value, type="number", extras="") => `<label>${label}<input data-property="${key}" type="${type}" value="${escape(value)}" ${type==="number" ? 'step="0.1"' : ""} ${extras}></label>`;
    const choice = (label,key,value,values) => `<label>${label}<select data-property="${key}">${values.map(([v,n])=>`<option value="${escape(v)}" ${v===value?"selected":""}>${escape(n)}</option>`).join("")}</select></label>`;
    function properties() {
        const o=object();
        if (!o) {
            $('properties').innerHTML=(masterIndex==null?choice("Master page","masterId",page().masterId||"",[["","None"],...model.masters.map(m=>[m.id,m.name])])+(page().masterId?choice("Background source","useMasterBackground",String(page().useMasterBackground!==false),[["true","Use master background"],["false","Use page background"]]):''):'')+field(masterIndex==null?"Page name":"Master name","pageName",page().name,"text")+field("Background","background",page().background,"color")+choice("Background image mode","backgroundMode",page().backgroundMode,[["cover","Fill / crop"],["contain","Fit"],["tile","Tile"]])+button("page-image","Choose background image")+button("clear-page-image","Remove background image"); return;
        }
        $('properties').innerHTML=field("Name","name",o.name,"text")+`<div class="field-pair">${field(o.parentId?"X in parent (mm)":"X (mm)","x",o.x)}${field(o.parentId?"Y in parent (mm)":"Y (mm)","y",o.y)}${field("Width (mm)","w",o.w,"number",'min="1"')}${field("Height (mm)","h",o.h,"number",'min="1"')}</div>`+field("Rotation (degrees)","rotation",o.rotation)+field("Opacity (0–1)","opacity",o.opacity,"number",'min="0" max="1"')+field("Hue shift (degrees)","hue",o.hue)+field("Fill color","fill",o.fill==="transparent"?"#ffffff":o.fill,"color")+button("clear-fill","Transparent fill")+field("Border color","stroke",o.stroke,"color")+field("Border width (mm)","strokeWidth",o.strokeWidth,"number",'min="0"')+field("Corner radius (mm)","radius",o.radius,"number",'min="0"');
        if(isText(o)) $('properties').insertAdjacentHTML("beforeend",choice("Block style","style",o.style,styles.map(s=>[s.name,s.label||s.name]))+field("Block text size (pt)","fontSize",o.fontSize,"number",'min="0"')+choice("Text alignment","align",o.align,[["left","Left"],["center","Center"],["right","Right"],["justify","Justify"]])+field("Line spacing","lineHeight",o.lineHeight,"number",'min="0.1"')+field("Letter spacing (pt; blank = style)","spacing",o.spacing == null ? "" : o.spacing)+`<div class="alignment-actions">${button("align-left","Align left")}${button("align-center","Center on page")}${button("align-right","Align right")}</div>`);
        if(o.type==='table') $('properties').insertAdjacentHTML('beforeend',field('Rows','rows',o.rows,'number','min="1" max="30"')+field('Columns','columns',o.columns,'number','min="1" max="30"'));
        if(['polygon','star','double-star'].includes(o.type)) $('properties').insertAdjacentHTML('beforeend',field('Sides / points','sides',o.sides,'number','min="3" max="32"'));
        if(o.type==='star') $('properties').insertAdjacentHTML('beforeend',field('Inner radius (%)','innerRadius',o.innerRadius,'number','min="5" max="95"'));
        if(o.type==='curve') $('properties').insertAdjacentHTML('beforeend',choice('Path','closed',String(o.closed),[['false','Open'],['true','Closed']])+button('add-node','Add node')+button('delete-node','Delete node'));
        if(isImage(o)) $('properties').insertAdjacentHTML("beforeend",choice("Image fitting","fit",o.fit,[["cover","Fill / crop"],["contain","Fit"],["fill","Stretch"]])+field("Crop focus X (%)","focusX",o.focusX,"number",'min="0" max="100"')+field("Crop focus Y (%)","focusY",o.focusY,"number",'min="0" max="100"')+button("replace-image","Replace image"));
        if(isText(o)&&!CFSLists.has(o.type))$('properties').insertAdjacentHTML('beforeend',choice('Contents heading','headingLevel',String(o.headingLevel||0),[['0','Not a heading'],...Array.from({length:6},(_,i)=>[String(i+1),'H'+(i+1)])]));
        if(CFSLists.has(o.type))$('properties').insertAdjacentHTML('beforeend',choice('List marker','listMarker',o.listMarker||(o.type==='ordered-list'?'decimal':'disc'),o.type==='ordered-list'?[['decimal','1, 2, 3'],['lower-alpha','a, b, c'],['upper-alpha','A, B, C'],['lower-roman','i, ii, iii'],['upper-roman','I, II, III']]:[['disc','Disc'],['circle','Circle'],['square','Square']])+(o.type==='ordered-list'?field('First number','listStart',o.listStart||1,'number','min="1" step="1"'):'')+field('Indent (mm)','listIndent',o.listIndent??6,'number','min="0"')+field('Item spacing (pt)','itemSpacing',o.itemSpacing??2,'number','min="0"'));
        if(isImage(o)&&!o.parentId&&masterIndex==null)$('properties').insertAdjacentHTML('beforeend',choice('Across page pair','spread',String(!!o.spread),[['false','This page only'],['true','Span both pages']]));
        if(CFSTextFlow.supports(o))$('properties').insertAdjacentHTML('beforeend',button('link-frame','Link to next frame')+(o.flowNext?button('unlink-frame','Unlink next frame'):'')+(model.pages.concat(model.masters).some(p=>p.objects.some(n=>n.flowNext===o.id))?button('unlink-previous','Unlink previous frame'):'')+`<small>${o.flowNext?'Next: '+escape(model.pages.concat(model.masters).flatMap(p=>p.objects).find(n=>n.id===o.flowNext)?.name||o.flowNext):'No next frame'}</small>`);
        if(o.type==='toc'){
            const config=CFSContents.settings(model);
            $('properties').insertAdjacentHTML('beforeend',field('Contents tiers','contentsDepth',config.contentsDepth||6,'number','min="1" max="6" step="1"')+choice('Page numbers','contentsPageNumbers',String(config.contentsPageNumbers!==false),[['true','Show'],['false','Hide']])+field('Frame text size (pt)','fontSize',o.fontSize||12,'number','min="1"')+button('update-contents','Update table of contents'));
            for(let i=0;i<6;i++)$('properties').insertAdjacentHTML('beforeend',`<h3>Tier ${i+1}</h3>`+choice('Heading source style','contentsSource'+i,config.contentsSources[i]||'',[['','None'],...styles.map(s=>[s.name,s.label||s.name])])+choice('Entry display style','contentsStyle'+i,config.contentsStyles[i]||model.settings.textStyle,styles.map(s=>[s.name,s.label||s.name]))+field('Indent (mm)','contentsIndent'+i,config.contentsIndents[i]??i*4,'number','min="0"')+choice('Leader','contentsLeader'+i,config.contentsLeaders[i]||'dots',[['none','None'],['dots','Dots'],['line','Line']])+choice('Text alignment','contentsAlignment'+i,config.contentsAlignments[i]||'left',[['left','Left'],['center','Center'],['right','Right']]));
        }
        if(locked(o)) $('properties').querySelectorAll('input,select,button').forEach(e=>e.disabled=true);
    }
    function selectObject(value) {
        if(masterIndex==null){const owner=CFSSpreads.owner(model,value);if(owner>=0&&!visiblePages().includes(owner)){pageIndex=owner;selected=value;render();return;}}
        const owner=masterIndex==null?CFSSpreads.owner(model,value):-1;if(owner>=0&&owner!==pageIndex){pageIndex=owner;layers();}
        if(selected!==value)range=null;selected=value;document.querySelectorAll('.editable-object').forEach(e=>e.classList.toggle('selected',e.dataset.id===selected));document.querySelectorAll('[data-layer-row]').forEach(e=>e.classList.toggle('active',e.dataset.layerRow===selected));properties();
        document.querySelectorAll('.editable-object .move-handle,.editable-object .resize-handle').forEach(e=>e.style.display=e.parentElement.dataset.id===selected?'':'none');
        const element=document.querySelector(`[data-id="${selected}"]`);if(element&&!locked(object())&&!Array.from(element.children).some(n=>n.classList.contains('resize-handle')))element.insertAdjacentHTML('beforeend','<div class="move-handle" title="Drag to move">⋮⋮</div><div class="resize-handle" title="Shift: proportions · Ctrl: from center"></div>');
        scaleControl();
    }
    function scaleControl() {
        document.querySelectorAll('.embedded-scale').forEach(e=>e.remove());
        const o=object(),canvas=document.querySelector('#page-zoom .manual-spread')||currentCanvas();
        if(!o||!o.parentId||locked(o)||!canvas)return;
        const center=new DOMPoint(o.w/2,o.h/2).matrixTransform(CFSLayers.matrix(page().objects,o));
        const control=document.createElement('label');control.className='embedded-scale';
        control.style.left=(center.x+(canvas.classList.contains('manual-spread')?visiblePages().indexOf(pageIndex)*model.settings.width:0))+'mm';control.style.top=center.y+'mm';
        control.innerHTML='<input type="range" min="10" max="300" value="100" aria-label="Scale embedded layer" title="Scale embedded layer, preserving proportions"><output>100%</output>';
        canvas.appendChild(control);const slider=control.querySelector('input'),initial=clone(o);
        let started=false;
        control.addEventListener('pointerdown',e=>e.stopPropagation());
        slider.addEventListener('input',()=>{
            if(!started){checkpoint();started=true;}
            const factor=Number(slider.value)/100;
            o.w=number(initial.w*factor);o.h=number(initial.h*factor);
            o.x=number(initial.x+(initial.w-o.w)/2);o.y=number(initial.y+(initial.h-o.h)/2);
            const element=document.querySelector(`[data-id="${o.id}"]`);
            element.style.width=o.w+'mm';element.style.height=o.h+'mm';element.style.left=displayedX(o)+'mm';element.style.top=o.y+'mm';
            if(CFSShapes.has(o.type))element.querySelector('svg').outerHTML=CFSShapes.render(o);
            control.querySelector('output').textContent=slider.value+'%';properties();overflow();snapshot();publishToolbar();
        });
        slider.addEventListener('change',()=>render());
    }
    function overflow() {
        let count=0;
        document.querySelectorAll('.manual-text').forEach(e=>{const bad=e.scrollHeight>e.clientHeight+1||e.scrollWidth>e.clientWidth+1||CFSTextFlow.overflow(e.parentElement.dataset.id);e.parentElement.classList.toggle('overflowing',bad);if(bad)count++;});
        document.querySelectorAll('.manual-contents').forEach(e=>{const bad=CFSTextFlow.overflow(e.parentElement.dataset.id);e.parentElement.classList.toggle('overflowing',bad);if(bad)count++;});
        document.querySelectorAll('.flow-output').forEach(b=>{const bad=CFSTextFlow.overflow(b.dataset.flowLink);b.classList.toggle('flow-overflow',bad);b.title=bad?'Text overflow · link to another frame':'Link to next frame';});
        $('editor-status').textContent=linkFrom?'Click the next text or contents frame; Escape cancels.':count?`${count} text block(s) overflow. Enlarge the block or reduce its text size.`:masterIndex!=null?`Editing master: ${page().name} · Changes update every assigned page.`:`Page ${pageIndex+1} of ${model.pages.length} · Objects use millimeters; zoom does not change print size.`;
        document.documentElement.dataset.cfsOverflow=String(count);
    }
    function prepareFlow(){
        const box=document.createElement('div');box.className='flow-measure';document.body.append(box);
        const measure=(o,html)=>{box.innerHTML=objectHTML(o,false,[o],0,html);const frame=box.firstElementChild;frame.style.left='0';frame.style.top='0';frame.style.transform='none';const text=frame.querySelector('.manual-text,.manual-contents');return !text||text.scrollHeight<=text.clientHeight+1&&text.scrollWidth<=text.clientWidth+1;};
        try{CFSTextFlow.prepare(model,measure,document.getElementById('cfs-game-styles').textContent+JSON.stringify([model.manualStyles,model.settings.textSize,model.settings.numberStart,model.settings.numberFormat]));}finally{box.remove();}
    }
    function refreshFlowText(o,element){
        CFSTextFlow.edit(model,o,element.innerHTML.replace(/\u200b/g,''));
        const selection=getSelection(),r=selection.rangeCount?selection.getRangeAt(0):null,first=CFSTextFlow.root(model,o),frames=CFSTextFlow.chain(model,first);let offset=0;
        if(r&&element.contains(r.startContainer)){const before=r.cloneRange();before.selectNodeContents(element);before.setEnd(r.startContainer,r.startOffset);offset=before.toString().length;}
        for(const frame of frames){if(frame===o)break;offset+=new DOMParser().parseFromString(CFSTextFlow.text(frame),'text/html').body.textContent.length;}
        snapshot();overflow();if(frames.length===1&&!o.flowHTML)return;
        clearTimeout(flowTimer);flowTimer=setTimeout(()=>{flowTimer=null;prepareFlow();let target=frames.at(-1),local=offset;
            for(const frame of frames){const length=new DOMParser().parseFromString(CFSTextFlow.text(frame),'text/html').body.textContent.length;if(local<=length){target=frame;break;}local-=length;}
            if(masterIndex==null){const owner=CFSSpreads.owner(model,target.id);if(owner>=0)pageIndex=owner;}selected=target.id;render();const text=document.querySelector(`[data-id="${target.id}"] .manual-text`);if(text){text.focus();const point=CFSTextFlow.point(text,local),next=document.createRange();next.setStart(...point);next.collapse(true);getSelection().removeAllRanges();getSelection().addRange(next);range=next.cloneRange();}
        },120);
    }
    function render() {
        clearTimeout(flowTimer);flowTimer=null;range=null;
        $('master-list').innerHTML=model.masters.map((m,i)=>`<button type="button" data-master-index="${i}" class="${i===masterIndex?'active':''}">${escape(m.name)}</button>`).join('');
        for(const name of ['duplicate-master','delete-master','apply-master','apply-master-all'])document.querySelector(`[data-action="${name}"]`).disabled=masterIndex==null;
        $('page-list').innerHTML=CFSSpreads.sidebar(model,i=>`<button type="button" data-page-index="${i}" class="${masterIndex==null&&i===pageIndex?'active':''}">${i+1}. ${escape(model.pages[i].name)}</button>`);
        let manualSheet=document.getElementById('cfs-manual-styles');if(!manualSheet){manualSheet=document.createElement('style');manualSheet.id='cfs-manual-styles';document.head.append(manualSheet);}loadStyles();manualSheet.textContent=CFSManualStyles.css(model,gameStyles);
        prepareFlow();$('page-zoom').innerHTML=viewHTML(true);
        applyZoom();layers();properties();stylesPanel();scaleControl();snapshot(false);publishToolbar();requestAnimationFrame(overflow);
        document.querySelectorAll("[data-tool]").forEach(b=>b.classList.toggle("active",b.dataset.tool===activeTool));document.querySelector('[data-action="image"]')?.classList.toggle('active',activeTool==='image');

    }
    function publishToolbar() {
        const root=document.documentElement;root.dataset.cfsUndo=undo.length?'1':'0';root.dataset.cfsRedo=redo.length?'1':'0';root.dataset.cfsGrid=model.settings.gridVisible?'1':'0';root.dataset.cfsSnap=model.settings.autoSnap?'1':'0';root.dataset.cfsZoom=String(Math.round(zoom*100));
        const palette=CFSManualThemes[editorTheme].colors;
        document.title='CFS Manual '+[root.dataset.cfsRevision||0,Math.round(zoom*100),undo.length?1:0,redo.length?1:0,model.settings.gridVisible?1:0,model.settings.autoSnap?1:0,hex(editorTheme),palette.toolbar.slice(1),palette.text.slice(1),saveRequest,root.dataset.cfsJsErrorCount||0,Math.round(interfaceZoom*100),viewRevision,pageIndex+1,dirty?'1':'0',model.settings.zoomStep].join('|');
    }
    function applyZoom(center=false) {
        const canvas=$('page-zoom'),workspace=$('workspace'),s=model.settings,width=visiblePages().length*s.width*96/25.4*zoom,height=s.height*96/25.4*zoom,padding=Number.parseFloat(getComputedStyle(workspace).paddingLeft)*2;
        canvas.style.setProperty('--manual-bleed',((s.bleed||0)*96/25.4*zoom)+'px');
        canvas.style.width=width+"px";canvas.style.height=height+"px";
        canvas.style.marginLeft=Math.max(0,(workspace.clientWidth-padding-width)/2)+'px';canvas.style.marginTop=Math.max(0,(workspace.clientHeight-padding-height)/2)+'px';
        canvas.firstElementChild.style.transform=`scale(${zoom})`;canvas.firstElementChild.style.transformOrigin="top left";
        if(center){workspace.scrollLeft=Math.max(0,(workspace.scrollWidth-workspace.clientWidth)/2);workspace.scrollTop=Math.max(0,(workspace.scrollHeight-workspace.clientHeight)/2);}
        publishToolbar();
    }
    function fit() { const box=$('workspace');zoom=Math.max(.1,Math.min((box.clientWidth-48)/(visiblePages().length*model.settings.width*96/25.4),(box.clientHeight-48)/(model.settings.height*96/25.4)));applyZoom(true); }
    document.addEventListener('wheel',event=>{
        if(!event.ctrlKey&&!event.altKey)return;
        event.preventDefault();if(options.open||document.querySelector('#manual-style-manager[open]'))return;
        const factor=Math.exp(-Math.max(-120,Math.min(120,event.deltaY))*.002);
        if(event.altKey&&!event.ctrlKey){interfaceZoom=Math.max(.75,Math.min(1.5,interfaceZoom*factor));document.documentElement.style.setProperty('--editor-ui-scale',interfaceZoom);publishToolbar();return;}
        if(event.ctrlKey){const canvas=$('page-zoom'),box=canvas.getBoundingClientRect(),workspace=$('workspace'),old=zoom;zoom=Math.max(.1,Math.min(4,(Math.round(zoom*100)+(event.deltaY<0?model.settings.zoomStep:event.deltaY>0?-model.settings.zoomStep:0))/100));const ratio=zoom/old,localX=event.clientX-box.left,localY=event.clientY-box.top;applyZoom();if(workspace.contains(event.target)){const next=canvas.getBoundingClientRect();workspace.scrollLeft+=next.left+localX*ratio-event.clientX;workspace.scrollTop+=next.top+localY*ratio-event.clientY;}}
    },{passive:false});
    function rememberRange() {
        const selection=getSelection();if(!selection.rangeCount)return;
        const r=selection.getRangeAt(0), node=r.commonAncestorContainer.nodeType===1?r.commonAncestorContainer:r.commonAncestorContainer.parentElement;
        const text=node.closest('.manual-text');if(text&&text.closest('.manual-page')&&text.parentElement.dataset.id===selected){range=r.cloneRange();}
    }
    document.addEventListener('selectionchange',rememberRange);
    function applyStyle(name) {
        const s=styleFor(name);if(!s)return;
        const o=object();
        if(!isText(o)) { change(()=>{const n=newObject("text",{style:name,html:""});page().objects.push(n);selected=n.id;});focusText();return; }
        if(locked(o))return;
        activeTool="text";document.querySelectorAll(".manual-text").forEach(e=>e.contentEditable="false");
        const text=document.querySelector(`[data-id="${o.id}"] .manual-text`);
        text.contentEditable="true";checkpoint();
        const r=range&&text.contains(range.commonAncestorContainer)?range.cloneRange():document.createRange();
        if(!range||!text.contains(range.commonAncestorContainer)){r.selectNodeContents(text);r.collapse(false);}
        const tag=document.createElement(s.tag);tag.dataset.inlineStyle=name;
        if(r.collapsed) tag.appendChild(document.createTextNode("\u200b"));
        else {const fragment=r.extractContents();fragment.querySelectorAll('[data-inline-style]').forEach(e=>e.replaceWith(...e.childNodes));tag.append(fragment);}
        r.insertNode(tag);text.focus();const next=document.createRange();next.selectNodeContents(tag);next.collapse(false);getSelection().removeAllRanges();getSelection().addRange(next);range=next.cloneRange();
        refreshFlowText(o,text);layers();
    }
    function focusText() { if(!['text','artistic','table','ordered-list','unordered-list'].includes(activeTool)){activeTool='text';document.querySelectorAll('[data-tool]').forEach(b=>b.classList.toggle('active',b.dataset.tool===activeTool));}if(!object()||locked(object()))return;const e=document.querySelector(`[data-id="${selected}"] .manual-text`);if(e){e.contentEditable="true";e.focus();const r=document.createRange();r.selectNodeContents(e);r.collapse(false);getSelection().removeAllRanges();getSelection().addRange(r);range=r.cloneRange();} }
    $('style-list').addEventListener('pointerdown',e=>{if(e.target.closest('button'))e.preventDefault();});
    $('style-list').addEventListener('click',e=>{const b=e.target.closest('[data-style-name]');if(b)applyStyle(b.dataset.styleName);});
    $('style-search').addEventListener('input',stylesPanel);

    $('page-list').addEventListener('click',e=>{const b=e.target.closest('[data-page-index]');if(b){pageIndex=Number(b.dataset.pageIndex);masterIndex=null;selected=null;render();}});
    $('master-list').addEventListener('click',e=>{const b=e.target.closest('[data-master-index]');if(b){masterIndex=Number(b.dataset.masterIndex);selected=null;render();}});
    $('layer-list').addEventListener('click',e=>{
        const b=e.target.closest('button');if(!b)return;
        if(b.dataset.layer){selectObject(b.dataset.layer);return;}
        const key=b.dataset.visible?'visible':'locked',target=page().objects.find(o=>o.id===(b.dataset.visible||b.dataset.locked));if(target)change(()=>target[key]=!target[key]);
    });
    $('layer-list').addEventListener('dblclick',e=>{
        const button=e.target.closest('[data-layer]');if(!button)return;const o=page().objects.find(n=>n.id===button.dataset.layer);if(!o||locked(o))return;
        e.preventDefault();const row=button.closest('[data-layer-row]'),input=document.createElement('input');input.type='text';input.value=o.name;input.setAttribute('aria-label','Layer name');row.draggable=false;button.hidden=true;row.prepend(input);let done=false;
        const finish=commit=>{if(done)return;done=true;const name=input.value.trim();if(commit&&name&&name!==o.name)change(()=>o.name=name);else layers();};
        input.addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();finish(true);}if(event.key==='Escape'){event.preventDefault();finish(false);}});input.addEventListener('blur',()=>finish(true));input.focus();input.select();
    });
    $('properties').addEventListener('change',e=>{
        const key=e.target.dataset.property;if(!key)return;
        let value=e.target.type==='number'?Number(e.target.value):e.target.value;
        if(key==='spacing'&&e.target.value==='')value=null;
        if(typeof value==='number'&&!Number.isFinite(value))return;
        if(e.target.min!==""&&typeof value==='number')value=Math.max(Number(e.target.min),value);
        if(e.target.max!==""&&typeof value==='number')value=Math.min(Number(e.target.max),value);
        if(object()?.type==='toc'&&/^contentsSource[0-5]$/.test(key)&&value){const index=Number(key.slice(-1)),sources=CFSContents.settings(model).contentsSources;if(sources.some((name,i)=>i!==index&&name===value)){$('editor-status').textContent='A heading style can belong to only one contents tier.';properties();return;}}
        change(()=>{const o=object();if(key==='pageName')page().name=value;else if(!o){page()[key]=key==='useMasterBackground'?value==='true':value;if(key==='masterId')page().useMasterBackground=true;}else if(!locked(o)){if(o.type==='toc'&&key.startsWith('contents')){const config=CFSContents.settings(model),match=key.match(/^contents(Source|Style|Indent|Leader|Alignment)([0-5])$/);if(match){const arrays={Source:'contentsSources',Style:'contentsStyles',Indent:'contentsIndents',Leader:'contentsLeaders',Alignment:'contentsAlignments'};config[arrays[match[1]]][Number(match[2])]=value;}else config[key]=key==='contentsPageNumbers'?value==='true':value;return;}o[key]=key==='headingLevel'?Number(value):['closed','contentsPageNumbers','spread'].includes(key)?value==='true':value;if(o.type==='table'&&['rows','columns'].includes(key)){o[key]=CFSTables.limit(value);o.html=CFSTables.create(o.rows,o.columns,o.html);}}});
    });
    $('workspace').addEventListener('beforeinput',e=>{if(e.target.closest('.manual-text')){if(Date.now()-typingAt>700)checkpoint();typingAt=Date.now();}});
    $('workspace').addEventListener('input',e=>{const t=e.target.closest('.manual-text');if(!t)return;const o=page().objects.find(o=>o.id===t.parentElement.dataset.id);if(o){refreshFlowText(o,t);}});
    function setTool(name) {
        editingObjectId=null;activeTool=name;range=null;render();
        document.querySelectorAll('[data-tool]').forEach(b=>b.classList.toggle('active',b.dataset.tool===name));
        $('workspace').style.cursor=['move','node'].includes(name)?'default':'crosshair';
        const menu=document.querySelector('.shape-menu');if(menu)menu.open=false;
    }
    const shapeMenu=document.querySelector('.shape-menu'),shapeFlyout=document.querySelector('.shape-flyout');
    function positionShapes() {
        if(!shapeMenu.open)return;const box=shapeMenu.querySelector('summary').getBoundingClientRect();
        shapeFlyout.style.left=Math.min(box.right+5,Math.max(0,innerWidth-200))+'px';shapeFlyout.style.top=Math.max(8,Math.min(box.top,innerHeight-280))+'px';shapeFlyout.style.maxHeight=Math.max(80,innerHeight-parseFloat(shapeFlyout.style.top)-12)+'px';
    }
    shapeMenu.addEventListener('toggle',positionShapes);window.addEventListener('resize',positionShapes);document.querySelector('.tool-rail').addEventListener('scroll',positionShapes);
    document.addEventListener('pointerdown',e=>{if(shapeMenu.open&&!shapeMenu.contains(e.target))shapeMenu.open=false;});
    $('workspace').addEventListener('dblclick' ,e=>{
        const el=e.target.closest('.editable-object');if(!el)return;
        selectObject(el.dataset.id);const o=object();if(!o||locked(o))return;e.preventDefault();
        const tool=o.type==='curve'?'node':o.type;setTool(tool);editingObjectId=o.id;
        if(isText(o)){const text=document.querySelector(`[data-id="${o.id}"] .manual-text`);text.focus();const caret=document.caretRangeFromPoint?.(e.clientX,e.clientY);if(caret&&text.contains(caret.startContainer)){getSelection().removeAllRanges();getSelection().addRange(caret);range=caret.cloneRange();}else focusText();}
        else if(isImage(o))$('properties').querySelector('[data-property="focusX"]')?.focus();

    });
    function pointerObject(e) {
        const hit=e.target.closest('.editable-object'),o=object();
        if(!o&&hit&&masterIndex==null){const owner=CFSSpreads.owner(model,hit.dataset.id);if(owner>=0)pageIndex=owner;}
        if(!o||(!['move','node'].includes(activeTool)&&!editingObjectId)||locked(o)||CFSLayers.chain(page().objects,o).some(n=>!n.visible))return hit;
        const canvas=currentCanvas(),bounds=canvas.getBoundingClientRect(),scale=25.4/(96*zoom);
        const point=new DOMPoint((e.clientX-bounds.left)*scale,(e.clientY-bounds.top)*scale).matrixTransform(CFSLayers.matrix(page().objects,o).inverse());
        const inside=(n,p)=>{
            if(p.x<0||p.y<0||p.x>n.w||p.y>n.h)return false;
            if(CFSShapes.clips(n))return CFSShapes.contains(n,p.x,p.y);
            if(n.type==='picture-ellipse')return ((p.x-n.w/2)/(n.w/2))**2+((p.y-n.h/2)/(n.h/2))**2<=1;
            return true;
        };
        if(!CFSLayers.chain(page().objects,o)[0].spread&&(e.clientX<bounds.left||e.clientX>bounds.right||e.clientY<bounds.top||e.clientY>bounds.bottom))return hit;
        if(!inside(o,point))return hit;
        for(const n of CFSLayers.chain(page().objects,o).slice(0,-1))if(CFSShapes.clips(n)||['picture','picture-ellipse'].includes(n.type)){
            const local=new DOMPoint((e.clientX-bounds.left)*scale,(e.clientY-bounds.top)*scale).matrixTransform(CFSLayers.matrix(page().objects,n).inverse());
            if(!inside(n,local))return hit;
        }
        return document.querySelector(`[data-id="${o.id}"]`)||hit;
    }
    $('workspace').addEventListener('pointerdown',e=>{
        if(options.open||document.querySelector('#manual-style-manager[open]')||e.button!==0)return;
        if(e.target.closest('.flow-output,.pane-toggle'))return;
        const hit=linkFrom?e.target.closest('.editable-object'):pointerObject(e),node=e.target.closest('[data-node]');
        if(linkFrom&&hit){e.preventDefault();const from=model.pages.concat(model.masters).flatMap(p=>p.objects).find(o=>o.id===linkFrom),to=model.pages.concat(model.masters).flatMap(p=>p.objects).find(o=>o.id===hit.dataset.id);try{change(()=>CFSTextFlow.link(model,from,to));linkFrom=null;overflow();}catch(error){$('editor-status').textContent=error.message;}return;}
        if(masterIndex==null&&!hit){const paper=e.target.closest('.manual-page');if(paper){const index=model.pages.findIndex(p=>p.id===paper.dataset.page);if(index>=0){pageIndex=index;layers();}}}
        if(node&&activeTool==='node') {
            selectObject(node.closest('.editable-object').dataset.id);const o=object();if(locked(o))return;
            e.preventDefault();checkpoint();selectedNode=Number(node.dataset.node);
            const initial=clone(o),sx=e.clientX,sy=e.clientY,scale=25.4/(96*zoom),start=initial.nodes[selectedNode],angle=Math.atan2(CFSLayers.matrix(page().objects,o).b,CFSLayers.matrix(page().objects,o).a);
            const capture=$('workspace');capture.setPointerCapture(e.pointerId);
            const move=event=>{const dx=(event.clientX-sx)*scale,dy=(event.clientY-sy)*scale;const nx=dx*Math.cos(angle)+dy*Math.sin(angle),ny=-dx*Math.sin(angle)+dy*Math.cos(angle);o.nodes[selectedNode]=[number(start[0]+nx/o.w*100),number(start[1]+ny/o.h*100)];node.style.left=o.nodes[selectedNode][0]+'%';node.style.top=o.nodes[selectedNode][1]+'%';node.closest('.editable-object').querySelector('svg').outerHTML=CFSShapes.render(o);};
            const end=()=>{capture.removeEventListener('pointermove',move);capture.removeEventListener('pointerup',end);capture.removeEventListener('pointercancel',end);if(JSON.stringify(o)!==JSON.stringify(initial)){revision++;dirty=JSON.stringify(model)!==savedState;}render();};
            capture.addEventListener('pointermove',move);capture.addEventListener('pointerup',end);capture.addEventListener('pointercancel',end);return;
        }
        if(!['move','node'].includes(activeTool)&&!(hit&&(page().objects.find(n=>n.id===hit.dataset.id)?.type===activeTool||activeTool==='text'&&isText(page().objects.find(n=>n.id===hit.dataset.id))||editingObjectId))) {
            const canvas=currentCanvas();if(!canvas.contains(e.target)&&!e.target.closest('[data-owner-page]'))return;
            e.preventDefault();checkpoint();const box=canvas.getBoundingClientRect(),scale=25.4/(96*zoom),sx=(e.clientX-box.left)*scale,sy=(e.clientY-box.top)*scale;
            const o=newObject(activeTool,{x:sx,y:sy,w:1,h:1});
            if(isText(o)){o.fill='transparent';o.html=o.type==='table'?CFSTables.create():CFSLists.has(o.type)?CFSLists.create(o.type):'';}
            if(isImage(o)){o.fill='transparent';o.strokeWidth=.3;}
            if(['line','curve','spiral'].includes(o.type)){o.fill='transparent';o.strokeWidth=.5;}
            page().objects.push(o);selected=o.id;render();const capture=$('workspace');capture.setPointerCapture(e.pointerId);
            const move=event=>{let dx=(event.clientX-box.left)*scale-sx,dy=(event.clientY-box.top)*scale-sy;if(event.shiftKey){const n=Math.max(Math.abs(dx),Math.abs(dy));dx=(dx<0?-1:1)*n;dy=(dy<0?-1:1)*n;}o.w=Math.max(1,Math.abs(dx)*(event.ctrlKey?2:1));o.h=Math.max(1,Math.abs(dy)*(event.ctrlKey?2:1));o.x=event.ctrlKey?sx-o.w/2:Math.min(sx,sx+dx);o.y=event.ctrlKey?sy-o.h/2:Math.min(sy,sy+dy);const el=document.querySelector(`[data-id="${o.id}"]`);el.style.left=o.x+'mm';el.style.top=o.y+'mm';el.style.width=o.w+'mm';el.style.height=o.h+'mm';if(CFSShapes.has(o.type))el.querySelector('svg').outerHTML=CFSShapes.render(o);properties();};
            const end=event=>{capture.removeEventListener('pointermove',move);capture.removeEventListener('pointerup',end);capture.removeEventListener('pointercancel',end);if(o.w<2&&o.h<2){o.w=isText(o)?80:40;o.h=isText(o)?30:40;}activeTool=isText(o)?'text':'move';revision++;dirty=JSON.stringify(model)!==savedState;render();if(isText(o))focusText();};
            capture.addEventListener('pointermove',move);capture.addEventListener('pointerup',end);capture.addEventListener('pointercancel',end);return;
        }

        const element=hit;
        if(!element){selectObject(null);return;}
        selectObject(element.dataset.id);const o=object();if(locked(o))return;
        const handle=e.target.closest('.resize-handle,.move-handle'),ownHandle=handle&&handle.closest('.editable-object')===element;
        const resize=!!ownHandle&&handle.classList.contains('resize-handle'),moving=!!ownHandle&&handle.classList.contains('move-handle')||!isText(o)||activeTool==='move';
        if(!resize&&!moving)return;
        e.preventDefault();checkpoint();const initial=clone(o),x=e.clientX,y=e.clientY,scale=25.4/(96*zoom);
        const artisticSize=o.type==='artistic'?parseFloat(getComputedStyle(element.querySelector(".manual-text")).fontSize)*.75:0;
        element.setPointerCapture(e.pointerId);
        const move=event=>{const [dx,dy]=CFSLayers.delta(page().objects,o,(event.clientX-x)*scale,(event.clientY-y)*scale);
            if(resize){const radians=initial.rotation*Math.PI/180,localX=dx*Math.cos(radians)+dy*Math.sin(radians),localY=-dx*Math.sin(radians)+dy*Math.cos(radians);const result=CFSShapes.resize(initial,localX,localY,event.shiftKey,event.ctrlKey,isImage(o)||o.type==='artistic');o.w=number(result.w);o.h=number(result.h);const centerX=initial.x+initial.w/2,centerY=initial.y+initial.h/2,ox=(o.w-initial.w)/2,oy=(o.h-initial.h)/2;o.x=number(event.ctrlKey?centerX-o.w/2:initial.x+ox*Math.cos(radians)-oy*Math.sin(radians)-ox);o.y=number(event.ctrlKey?centerY-o.h/2:initial.y+ox*Math.sin(radians)+oy*Math.cos(radians)-oy);element.style.width=o.w+'mm';element.style.height=o.h+'mm';element.style.left=displayedX(o)+'mm';element.style.top=o.y+'mm';if(artisticSize){o.fontSize=number(artisticSize*o.w/initial.w);element.querySelector('.manual-text').style.fontSize=o.fontSize+'pt';}}
            else{let mx=dx,my=dy;if(event.shiftKey){if(Math.abs(mx)>Math.abs(my)*2)my=0;else if(Math.abs(my)>Math.abs(mx)*2)mx=0;else{const n=Math.max(Math.abs(mx),Math.abs(my));mx=Math.sign(mx)*n;my=Math.sign(my)*n;}}o.x=number(initial.x+mx);o.y=number(initial.y+my);const guides=CFSSnapping.snap(page().objects,o,model.settings,zoom,event.altKey,masterIndex==null?pageIndex:0);showGuides(guides);element.style.left=displayedX(o)+'mm';element.style.top=o.y+'mm';}properties();overflow();};
        const end=()=>{element.removeEventListener('pointermove',move);element.removeEventListener('pointerup',end);element.removeEventListener('pointercancel',end);if(JSON.stringify(o)!==JSON.stringify(initial)){revision++;dirty=JSON.stringify(model)!==savedState;}render();};
        element.addEventListener('pointermove',move);element.addEventListener('pointerup',end);element.addEventListener('pointercancel',end);
    });
    function showGuides(values) {
        document.querySelectorAll('.snap-guide').forEach(n=>n.remove());const canvas=currentCanvas();
        values.forEach((v,i)=>{if(v===undefined)return;const n=document.createElement('div');n.className='snap-guide';n.style.cssText=`position:absolute;pointer-events:none;${i?'top:'+v+'mm;left:0;right:0;border-top':'left:'+v+'mm;top:0;bottom:0;border-left'}:1px solid #d42e91`;canvas.appendChild(n);});
    }
    const context=document.createElement('div');context.className='object-context';context.hidden=true;app.appendChild(context);
    $('workspace').addEventListener('click',e=>{const link=e.target.closest('[data-contents-page]');if(!link)return;e.preventDefault();const index=model.pages.findIndex(p=>p.id===link.dataset.contentsPage);if(index>=0){pageIndex=index;masterIndex=null;selected=link.dataset.contentsObject;render();}});
    function contextMenu(e) {
        const el=e.target.closest('[data-layer-row],.editable-object');if(!el)return;e.preventDefault();selectObject(el.dataset.layerRow||el.dataset.id);const o=object();
        context.innerHTML=`<strong>${escape(o.name)}</strong>`+button(locked(o)?'unlock':'lock',locked(o)?'Unlock':'Lock')+(locked(o)?'':button('duplicate','Duplicate (Ctrl+J)')+button('front','Bring to front')+button('back','Send to back')+(o.parentId?button('detach','Move out of parent'):'')+(isText(o)?button('edit-text','Edit text'):'')+(isImage(o)?button('replace-image','Choose image'):'')+button('delete','Delete'));
        context.hidden=false;context.style.left=Math.min(e.clientX,window.innerWidth-210)+'px';context.style.top=Math.max(0,Math.min(e.clientY,window.innerHeight-context.offsetHeight))+'px';
    }
    $('workspace').addEventListener('contextmenu',contextMenu);$('layer-list').addEventListener('contextmenu',contextMenu);
    document.addEventListener('pointerdown',e=>{if(!context.contains(e.target))context.hidden=true;});context.addEventListener('click',()=>context.hidden=true);
    let fileAction="image";
    function imageFile(action) {fileAction=action;$('image-file').value="";$('image-file').click();}
    $('image-file').addEventListener('change',e=>{const file=e.target.files[0];if(!file)return;const reader=new FileReader();reader.onload=()=>change(()=>{
        if(fileAction==='page-image'){page().backgroundImage=reader.result;return;}
        if(fileAction==='replace-image'&&object()){object().src=reader.result;return;}
        const o=newObject('image',{src:reader.result,name:file.name});page().objects.push(o);selected=o.id;
    });reader.readAsDataURL(file);});
    function action(name) {
        const o=object();
        if(name==='styles'){CFSManualStyles.open(model,gameStyles,change);return;}
        if(name==='undo'){restore(undo,redo);return;}if(name==='redo'){restore(redo,undo);return;}if(name==='fit'){fit();return;}
        if(['image','page-image','replace-image'].includes(name)){imageFile(name);return;}
        if(['text','artistic','table','ordered-list','unordered-list','toc','picture','picture-ellipse'].includes(name)||CFSShapes.has(name)){change(()=>{const n=newObject(name);if(n.type==='toc'){n.fill='transparent';n.w=150;n.h=200;n.contentsDepth=6;n.contentsLeader='dots';n.contentsStyles=Array(6).fill(model.settings.textStyle);n.contentsEntries=[];}if(isText(n)){n.fill='transparent';n.html=name==='table'?CFSTables.create():CFSLists.has(name)?CFSLists.create(name):'';}if(isImage(n)){n.fill='transparent';n.strokeWidth=.3;}if(['line','curve','spiral'].includes(name)){n.fill='transparent';n.strokeWidth=.5;}page().objects.push(n);selected=n.id;});if(isText(object()))focusText();return;}
        if(name==='add-master'){change(()=>{const m=newPage();m.id=id('master-');m.name='Master '+(model.masters.length+1);model.masters.push(m);masterIndex=model.masters.length-1;selected=null;});return;}
        if(name==='duplicate-master'&&masterIndex!=null){change(()=>{const m=clone(page());m.id=id('master-');m.name+=' copy';m.objects=CFSMasterPages.objects(m,m.id+'-');for(const n of m.objects)if(n.flowNext)n.flowNext=m.id+'-'+n.flowNext;model.masters.push(m);masterIndex=model.masters.length-1;selected=null;});return;}
        if(name==='delete-master'&&masterIndex!=null){if(!confirm('Delete this master and remove it from assigned pages?'))return;change(()=>{CFSMasterPages.remove(model,page().id);masterIndex=null;selected=null;});return;}
        if(['apply-master','apply-master-all'].includes(name)&&masterIndex!=null){change(()=>{const m=page(),targets=name==='apply-master-all'?model.pages:[model.pages[pageIndex]];for(const p of targets){p.masterId=m.id;p.useMasterBackground=true;}});return;}
        if(name==='add-page'){change(()=>{model.pages.push(newPage());pageIndex=model.pages.length-1;masterIndex=null;selected=null;});return;}
        if(name==='delete-page'){if(masterIndex!=null||model.pages.length===1)return;if(!confirm('Delete this page and its objects?'))return;change(()=>{CFSTextFlow.remove(model,new Set(page().objects.map(o=>o.id)));model.pages.splice(pageIndex,1);pageIndex=Math.max(0,pageIndex-1);selected=null;});return;}
        if(name==='page-up'||name==='page-down'){if(masterIndex!=null)return;const next=pageIndex+(name==='page-up'?-1:1);if(next<0||next>=model.pages.length)return;change(()=>{[model.pages[next],model.pages[pageIndex]]=[model.pages[pageIndex],model.pages[next]];pageIndex=next;});return;}
        if(name==='grid'||name==='snap'){change(()=>model.settings[name==='grid'?'gridVisible':'autoSnap']=!model.settings[name==='grid'?'gridVisible':'autoSnap']);return;}
        if(name==='clear-page-image'){change(()=>page().backgroundImage="");return;}
        if(!o)return;
        if(name==='link-frame'&&CFSTextFlow.supports(o)&&!locked(o)){linkFrom=o.id;overflow();return;}
        if(name==='unlink-previous'&&CFSTextFlow.supports(o)&&!locked(o)){const previous=model.pages.concat(model.masters).flatMap(p=>p.objects).find(n=>n.flowNext===o.id);if(previous){const owner=model.pages.concat(model.masters).find(p=>p.objects.includes(previous));if(CFSLayers.locked(owner.objects,previous)){$('editor-status').textContent='Unlock the previous frame before unlinking.';return;}change(()=>CFSTextFlow.unlink(model,previous));}return;}
        if(name==='unlink-frame'&&CFSTextFlow.supports(o)&&!locked(o)){change(()=>CFSTextFlow.unlink(model,o));return;}
        if(name==='update-contents'&&o.type==='toc'&&!locked(o)){change(()=>CFSContents.update(o,model,styles));return;}
        if(name==='edit-text'&&isText(o)&&!locked(o)){setTool('text');focusText();return;}
        if(name==='unlock'||name==='lock'){change(()=>o.locked=name==='lock');return;}
        if(locked(o))return;
        if(name==='add-node'&&o.type==='curve'){change(()=>o.nodes.push([75,50]));return;}
        if(name==='delete-node'&&o.type==='curve'&&o.nodes.length>2){change(()=>o.nodes.splice(Math.min(selectedNode,o.nodes.length-1),1));return;}
        if(name==='detach'){reparent(o.id);return;}
        if(name==='delete'){change(()=>{const ids=new Set(CFSLayers.descendants(page().objects,o).map(n=>n.id));CFSTextFlow.remove(model,ids);page().objects=page().objects.filter(n=>!ids.has(n.id));selected=null;});return;}
        if(name==='duplicate'){change(()=>{const originals=CFSLayers.descendants(page().objects,o),ids=new Map(originals.map(n=>[n.id,id('object-')])),copies=originals.map(n=>{const c=CFSTextFlow.copy(model,n);c.id=ids.get(n.id);if(ids.has(n.parentId))c.parentId=ids.get(n.parentId);return c;});const n=copies.find(n=>n.id===ids.get(o.id));n.name+=' copy';n.x+=5;n.y+=5;page().objects.push(...copies);selected=n.id;});return;}
        if(name==='clear-fill'){change(()=>o.fill='transparent');return;}
        if(name==='front'||name==='back'){change(()=>{page().objects=page().objects.filter(n=>n!==o);if(name==='front')page().objects.push(o);else page().objects.unshift(o);});return;}
        if(name==='up'||name==='down'){const siblings=CFSLayers.children(page().objects,o.parentId||null),at=siblings.indexOf(o),target=siblings[at+(name==='up'?1:-1)];if(!target)return;const i=page().objects.indexOf(o),n=page().objects.indexOf(target);change(()=>[page().objects[i],page().objects[n]]=[page().objects[n],page().objects[i]]);return;}
        if(name.startsWith('align-'))change(()=>o.x=name==='align-left'?model.settings.margin:name==='align-right'?model.settings.width-model.settings.margin-o.w:(model.settings.width-o.w)/2);
    }
    app.addEventListener('click',e=>{const t=e.target.closest('[data-tool]');if(t){setTool(t.dataset.tool);return;}const b=e.target.closest('[data-action]');if(b)action(b.dataset.action);});
    $('workspace').addEventListener('click',e=>{const b=e.target.closest('[data-flow-link]');if(!b)return;e.preventDefault();e.stopPropagation();selectObject(b.dataset.flowLink);action('link-frame');});
    const clipboardPrefix='CardForgeStudioManualObjects:1\n';
    function editingTarget(target) {return target&&target.nodeType===1&&(target.isContentEditable||!!target.closest('input,select,textarea'));}
    function copyObjects(e,cut=false) {
        if(editingTarget(e.target)||options.open)return;const o=object();if(!o||cut&&locked(o)||!e.clipboardData)return;
        const objects=CFSLayers.descendants(page().objects,o).map(n=>CFSTextFlow.copy(model,n)),root=objects.find(n=>n.id===o.id),matrix=CFSLayers.matrix(page().objects,o),center=new DOMPoint(o.w/2,o.h/2).matrixTransform(matrix);
        root.parentId=null;root.x=center.x-o.w/2;root.y=center.y-o.h/2;root.rotation=Math.atan2(matrix.b,matrix.a)*180/Math.PI;
        e.clipboardData.setData('text/plain',clipboardPrefix+JSON.stringify({root:o.id,objects}));e.preventDefault();if(cut)action('delete');
    }
    document.addEventListener('copy',e=>copyObjects(e));document.addEventListener('cut',e=>copyObjects(e,true));
    document.addEventListener('paste',e=>{
        if(editingTarget(e.target)||options.open||document.querySelector('#manual-style-manager[open]')||!e.clipboardData)return;const text=e.clipboardData.getData('text/plain');if(!text.startsWith(clipboardPrefix))return;
        try{
            const data=JSON.parse(text.slice(clipboardPrefix.length));if(!Array.isArray(data.objects)||!data.objects.length||!data.objects.some(n=>n.id===data.root))return;
            for(const n of data.objects)if(!n||typeof n.id!=='string'||![n.x,n.y,n.w,n.h,n.rotation].every(Number.isFinite)||n.w<=0||n.h<=0||!isText(n)&&!isImage(n)&&n.type!=='toc'&&!CFSShapes.has(n.type))return;
            const originals=clone(data.objects),root=originals.find(n=>n.id===data.root);for(const n of originals){delete n.flowNext;delete n.flowHTML;}root.parentId=null;CFSLayers.validate(originals);if(originals.some(n=>!CFSLayers.chain(originals,n).some(p=>p.id===root.id)))return;
            change(()=>{const ids=new Map(originals.map(n=>[n.id,id('object-')]));for(const n of originals){n.parentId=ids.get(n.parentId)||null;n.id=ids.get(n.id);}root.x+=5;root.y+=5;page().objects.push(...originals);selected=root.id;});e.preventDefault();
        }catch(error){$('editor-status').textContent='The clipboard does not contain valid manual objects.';}
    });
    let saveRequest=0;
    document.addEventListener('keydown',e=>{
        const editing=e.target.isContentEditable||!!e.target.closest('input,select,textarea');
        if(options.open||document.querySelector('#manual-style-manager[open]'))return;
        const ctrl=e.ctrlKey||e.metaKey,key=e.key.toLowerCase();
        if(ctrl&&key==='s'){e.preventDefault();document.documentElement.dataset.cfsSaveRequest=String(++saveRequest);publishToolbar();return;}
        if(ctrl&&key==='z'){e.preventDefault();restore(e.shiftKey?redo:undo,e.shiftKey?undo:redo);return;}
        if(ctrl&&key==='y'){e.preventDefault();restore(redo,undo);return;}
        if(editing)return;
        if(ctrl&&key==='j'){e.preventDefault();action('duplicate');return;}
        if(ctrl&&key==='l'){e.preventDefault();action(e.shiftKey?'unlock':'lock');return;}
        if(ctrl&&(key===']'||key==='[')){e.preventDefault();action(e.shiftKey?(key===']'?'front':'back'):(key===']'?'up':'down'));return;}
        if(e.key==='Delete'||e.key==='Backspace'){e.preventDefault();action('delete');return;}
        if(e.key==='Escape'){e.preventDefault();linkFrom=null;selected=null;setTool('move');return;}
        if(!ctrl&&!e.altKey&&['v','a','t','m'].includes(key)){e.preventDefault();setTool({v:'move',a:'node',t:'text',m:'rectangle'}[key]);return;}
        const o=object();if(o&&!locked(o)&&['ArrowLeft','ArrowRight','ArrowUp','ArrowDown'].includes(e.key)){e.preventDefault();const step=e.shiftKey?10:1;change(()=>{if(e.key==='ArrowLeft')o.x-=step;if(e.key==='ArrowRight')o.x+=step;if(e.key==='ArrowUp')o.y-=step;if(e.key==='ArrowDown')o.y+=step;});}
    });
    function fillSettings() {
        const s=model.settings,u=units();
        form.elements.editorTheme.innerHTML=Object.entries(CFSManualThemes).map(([key,t])=>`<option value="${escape(key)}">${escape(t.label)}</option>`).join('');form.elements.editorTheme.value=editorTheme;
        for(const key of ['textStyle','numberStyle'])form.elements[key].innerHTML=styles.map(s=>`<option>${escape(s.name)}</option>`).join('');
        for(const [key,value]of Object.entries(s)){const input=form.elements[key];if(!input)continue;if(input.type==='checkbox')input.checked=value;else input.value=['width','height','marginInner','marginOuter','marginTop','marginBottom','bleed'].includes(key)?number(value/u):value;}
    }
    function optionsDimensions() {
        const preset=presets[form.elements.preset.value];
        if(!preset){const w=Number(form.elements.width.value),h=Number(form.elements.height.value),landscape=form.elements.orientation.value==='landscape';if((landscape&&w<h)||(!landscape&&w>h)){form.elements.width.value=h;form.elements.height.value=w;}return;}
        let [w,h]=preset;if(form.elements.orientation.value==='landscape')[w,h]=[h,w];
        const u=form.elements.units.value==='in'?25.4:1;form.elements.width.value=number(w/u);form.elements.height.value=number(h/u);
    }
    form.elements.preset.addEventListener('change',optionsDimensions);form.elements.orientation.addEventListener('change',optionsDimensions);
    form.elements.units.addEventListener('change',()=>{const old=Number(form.dataset.unitScale||units()),next=form.elements.units.value==='in'?25.4:1;for(const k of ['width','height','marginInner','marginOuter','marginTop','marginBottom','bleed'])form.elements[k].value=number(Number(form.elements[k].value)*old/next);form.dataset.unitScale=next;});
    for(const key of ['width','height'])form.elements[key].addEventListener('input',()=>form.elements.preset.value='custom');
    $('cancel-options').addEventListener('click',()=>options.close());
    form.addEventListener('submit',e=>{
        e.preventDefault();const u=form.elements.units.value==='in'?25.4:1,s={};
        for(const key of Object.keys(settingsDefaults())){const input=form.elements[key];if(!input)continue;s[key]=input.type==='checkbox'?input.checked:input.type==='number'?Number(input.value):input.value;}
        for(const key of ['width','height','marginInner','marginOuter','marginTop','marginBottom','bleed'])s[key]*=u;
        s.margin=s.marginInner;
        if(![s.marginInner,s.marginOuter,s.marginTop,s.marginBottom,s.bleed].every(n=>Number.isFinite(n)&&n>=0)||s.marginInner+s.marginOuter>=s.width||s.marginTop+s.marginBottom>=s.height){$('options-error').textContent='Margins and bleed must be nonnegative; margins must fit inside the page.';return;}
        if(![s.gridX,s.gridY].every(n=>Number.isFinite(n)&&n>0)){$('options-error').textContent='Grid cell dimensions must be positive.';return;}
        if(![s.width,s.height,s.margin,s.numberStart].every(Number.isFinite)||s.width<=0||s.height<=0||s.margin<0||!Number.isInteger(s.numberStart)||s.numberStart<0){$('options-error').textContent='Choose positive page dimensions, a margin smaller than half the page, and a whole starting page number.';return;}
        if(!Number.isFinite(s.textSize)||s.textSize<=0){$('options-error').textContent='Choose a positive default text size.';return;}
        if(!Number.isInteger(s.zoomStep)||s.zoomStep<1||s.zoomStep>100){$('options-error').textContent='Choose a whole zoom step from 1 to 100 percent.';return;}
        applyTheme(form.elements.editorTheme.value);change(()=>model.settings=s);options.close();
    });
    window.CFSManual={
        openOptions(){fillSettings();form.dataset.unitScale=units();$('options-error').textContent='';options.showModal();},
        styles(css,list){document.getElementById('cfs-game-styles').textContent=unhex(css);document.getElementById('game-style-data').outerHTML=unhex(list);loadStyles();const sheet=document.getElementById('cfs-manual-styles');if(sheet)sheet.textContent=CFSManualStyles.css(model,gameStyles);render();},
        state(){return clone(model);},
        manualStyle(style){const candidate={...model,manualStyles:model.manualStyles.filter(s=>s.name!==style.name).concat(style)};const result=CFSManualStyles.resolve(candidate,'manual:'+style.name);if(!gameStyles.some(s=>s.name===result.game))throw Error('Missing game style');change(()=>model.manualStyles=candidate.manualStyles);},
        snapshot:fullSnapshot,
        saved(value){if(value===lastSnapshotRevision){savedState=lastSnapshotState;dirty=JSON.stringify(model)!==savedState;document.documentElement.dataset.cfsDirty=dirty?'1':'0';publishToolbar();}},
        action,select:selectObject,applyStyle,setTool,reparent,
        setProperty(key,value){const o=object();if(o&&!locked(o))change(()=>{if(key==='html'&&CFSTextFlow.supports(o))CFSTextFlow.edit(model,o,value);else o[key]=value;});},
        setZoom(value){if(Number.isFinite(value)&&value>=.1&&value<=4){zoom=Math.round(value*100)/100;applyZoom(true);}},
        fit
    };
    for(const [side,label]of [['left','Pages and styles'],['right','Layers and properties']]){const pane=document.querySelector('.'+side+'-sidebar'),toggle=document.createElement('button');toggle.className='pane-toggle';toggle.type='button';toggle.title='Collapse '+label;toggle.setAttribute('aria-label',toggle.title);toggle.textContent=side==='left'?'‹':'›';pane.prepend(toggle);toggle.onclick=()=>{const collapsed=pane.classList.toggle('is-collapsed');document.querySelector('.visual-layout').classList.toggle(side+'-collapsed',collapsed);toggle.textContent=side==='left'?(collapsed?'›':'‹'):(collapsed?'‹':'›');toggle.title=(collapsed?'Show ':'Collapse ')+label;toggle.setAttribute('aria-label',toggle.title);};}
    render();requestAnimationFrame(fit);new ResizeObserver(()=>{if($('page-zoom').firstElementChild)applyZoom();}).observe($('workspace'));
})();
