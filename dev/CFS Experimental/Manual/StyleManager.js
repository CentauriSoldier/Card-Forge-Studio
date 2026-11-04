/* Manual variants store references and four overrides; game definitions stay read-only. */
window.CFSManualStyles = (() => {
    const escape=text=>String(text).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
    const tag=name=>'m-'+Array.from(new TextEncoder().encode(name),b=>b.toString(16).padStart(2,'0')).join('');
    function resolve(model,name,seen=new Set()) {
        if(!name.startsWith('manual:'))return {game:name,overrides:{}};
        if(seen.has(name))throw Error('Manual style inheritance is circular.');seen.add(name);
        const style=(model.manualStyles||[]).find(s=>'manual:'+s.name===name);if(!style)throw Error('Missing manual style: '+name.slice(7));
        if(style.size!=null&&(!Number.isFinite(style.size)||style.size<=0))throw Error('Manual font size must be positive.');for(const key of ['bold','italic','underline'])if(style[key]!=null&&typeof style[key]!=='boolean')throw Error('Invalid manual style override: '+key);
        const parent=resolve(model,style.parent,seen),overrides={...parent.overrides};
        for(const key of ['size','bold','italic','underline'])if(style[key]!=null)overrides[key]=style[key];
        return {game:parent.game,overrides};
    }
    function items(model) {return (model.manualStyles||[]).map(s=>({name:'manual:'+s.name,label:s.name+' (manual)',tag:tag(s.name)}));}
    function css(model,gameItems) {
        const sheet=document.getElementById('cfs-game-styles').sheet,rules=Array.from(sheet?.cssRules||[]),result=[];
        for(const item of items(model)){
            const resolved=resolve(model,item.name),probe=document.createElement('span');probe.dataset.style=resolved.game;
            if(!gameItems.some(s=>s.name===resolved.game))throw Error('Missing game style: '+resolved.game);
            const rule=rules.find(r=>r.selectorText&&probe.matches(r.selectorText));if(!rule)throw Error('Cannot resolve game style: '+resolved.game);
            const declaration=document.createElement('span').style;declaration.cssText=rule.style.cssText;declaration.fontSize='inherit';
            const o=resolved.overrides;if(o.size!=null)declaration.fontSize=o.size+'pt';if(o.bold!=null)declaration.fontWeight=o.bold?'bold':'normal';if(o.italic!=null)declaration.fontStyle=o.italic?'italic':'normal';
            if(o.underline!=null){const decorations=declaration.textDecorationLine.split(' ').filter(s=>s&&s!=='none'&&s!=='underline');if(o.underline)decorations.push('underline');declaration.textDecoration=decorations.join(' ')||'none';}
            result.push(item.tag+', [data-style="'+CSS.escape(item.name)+'"]{'+declaration.cssText+'}');
        }
        return result.join('\n');
    }
    function open(model,gameItems,commit) {
        let dialog=document.getElementById('manual-style-manager');if(dialog)dialog.remove();dialog=document.createElement('dialog');dialog.id='manual-style-manager';
        dialog.innerHTML='<form method="dialog"><h2>Manual Styles</h2><div class="style-manager-columns"><section><h3>Game styles · read-only</h3><select size="12" id="style-game-list">'+gameItems.map(s=>'<option>'+escape(s.name)+'</option>').join('')+'</select><h3>Manual styles</h3><select size="6" id="style-manual-list"></select><div class="style-manager-actions"><button type="button" id="style-new">New</button><button type="button" id="style-delete">Delete</button></div></section><section><label>Name<input id="style-name" required></label><label>Inherit from<select id="style-parent"></select></label><label>Font size (pt; blank = inherit)<input id="style-size" type="number" min="0.1" step="0.1"></label>'+['bold','italic','underline'].map(k=>'<label>'+k[0].toUpperCase()+k.slice(1)+'<select id="style-'+k+'"><option value="">Inherit</option><option value="true">On</option><option value="false">Off</option></select></label>').join('')+'<p>Game sizes inherit the text block. A fixed manual size overrides that size. Other style properties stay in the game.</p><p id="style-error" role="alert"></p><button type="button" id="style-apply">Save manual style</button></section></div><div class="dialog-actions"><button formnovalidate>Close</button></div></form>';
        document.body.append(dialog);let editing=null;const get=id=>dialog.querySelector('#'+id),all=()=>[...gameItems.map(s=>({name:s.name,label:s.name})),...items(model)];
        function refresh(){get('style-manual-list').innerHTML=(model.manualStyles||[]).map(s=>'<option>'+escape(s.name)+'</option>').join('');get('style-parent').innerHTML=all().filter(s=>s.name!=='manual:'+editing).map(s=>'<option value="'+escape(s.name)+'">'+escape(s.label||s.name)+'</option>').join('');}
        function fill(style){editing=style?.name||null;refresh();get('style-name').value=style?.name||'';get('style-parent').value=style?.parent||get('style-game-list').value||get('style-parent').options[0]?.value||'';get('style-size').value=style?.size??'';for(const k of ['bold','italic','underline'])get('style-'+k).value=style?.[k]==null?'':String(style[k]);get('style-error').textContent='';}
        get('style-new').onclick=()=>fill();get('style-manual-list').onchange=()=>fill(model.manualStyles.find(s=>s.name===get('style-manual-list').value));
        get('style-delete').onclick=()=>{if(!editing)return;const key='manual:'+editing;if(model.settings.textStyle===key||model.settings.numberStyle===key||model.manualStyles.some(s=>s.parent===key)||model.pages.concat(model.masters).some(p=>p.objects.some(o=>o.style===key||(o.contentsStyles||[]).includes(key)||(o.html||'').includes(tag(editing))))) {get('style-error').textContent='This style is still referenced. Change those references before deleting it.';return;}commit(()=>model.manualStyles=model.manualStyles.filter(s=>s.name!==editing));fill();};
        get('style-apply').onclick=()=>{
            try{const name=get('style-name').value.trim();if(!name)throw Error('Enter a style name.');if(editing&&name!==editing)throw Error('Keep the existing name; create a new variant to use another name.');if(!editing&&model.manualStyles.some(s=>s.name===name))throw Error('That manual style already exists.');
                const style={name,parent:get('style-parent').value},size=get('style-size').value;if(size!==''){style.size=Number(size);if(!Number.isFinite(style.size)||style.size<=0)throw Error('Choose a positive font size.');}for(const k of ['bold','italic','underline']){const value=get('style-'+k).value;if(value!=='')style[k]=value==='true';}
                const candidate={...model,manualStyles:model.manualStyles.filter(s=>s.name!==editing).concat(style)};const resolved=resolve(candidate,'manual:'+name);if(!gameItems.some(s=>s.name===resolved.game))throw Error('Choose an existing game style as the inheritance root.');commit(()=>model.manualStyles=candidate.manualStyles);fill(style);
            }catch(e){get('style-error').textContent=e.message;}
        };
        fill();dialog.showModal();
    }
    return {resolve,items,css,open,tag};
})();
