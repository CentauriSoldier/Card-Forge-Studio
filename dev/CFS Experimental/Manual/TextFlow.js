/* Linked frames retain one editable story; layout fragments are derived and cached. */
window.CFSTextFlow = (() => {
    let fragments=new Map(),cache=new Map(),overflowing=new Set();
    const all=model=>model.pages.concat(model.masters||[]).flatMap(p=>p.objects);
    const supports=o=>o&&['text','artistic','toc'].includes(o.type);
    function walk(byId,o){const seen=new Set(),result=[];while(o&&!seen.has(o.id)){seen.add(o.id);result.push(o);if(!o.flowNext)break;o=byId.get(o.flowNext);}return result;}
    function chain(model,o){return walk(new Map(all(model).map(n=>[n.id,n])),o);}
    function root(model,o){const objects=all(model),seen=new Set();while(o&&!seen.has(o.id)){seen.add(o.id);const previous=objects.find(n=>n.flowNext===o.id);if(!previous)return o;o=previous;}throw Error('Frame links are circular.');}
    function marked(html){const body=document.createElement('div');body.innerHTML=html;let n=0;body.querySelectorAll('*').forEach(e=>e.dataset.flowNode=String(++n));return body;}
    function clean(html){const body=document.createElement('div');body.innerHTML=html;body.querySelectorAll('[data-flow-node]').forEach(e=>e.removeAttribute('data-flow-node'));return body.innerHTML;}
    function length(body){return body.textContent.length;}
    function point(body,index){const walk=document.createTreeWalker(body,NodeFilter.SHOW_TEXT);let node,last;while(node=walk.nextNode()){last=node;if(index<=node.length)return[node,index];index-=node.length;}return last?[last,last.length]:[body,body.childNodes.length];}
    function slice(body,start,end){if(start===0&&end===length(body))return body.innerHTML;const r=document.createRange(),a=point(body,start),b=point(body,end);r.setStart(...a);r.setEnd(...b);const box=document.createElement('div');box.append(r.cloneContents());let parent=r.commonAncestorContainer;if(parent.nodeType===Node.TEXT_NODE)parent=parent.parentNode;while(parent&&parent!==body){const wrapper=parent.cloneNode(false);while(box.firstChild)wrapper.append(box.firstChild);box.append(wrapper);parent=parent.parentNode;}return box.innerHTML;}
    function join(parts){const body=document.createElement('div');for(const html of parts){const box=document.createElement('div');box.innerHTML=html;merge(body,box);}return clean(body.innerHTML);}
    function merge(left,right){const a=left.lastChild,b=right.firstChild;if(a?.nodeType===1&&b?.nodeType===1&&a.dataset.flowNode&&a.dataset.flowNode===b.dataset.flowNode&&a.cloneNode(false).outerHTML===b.cloneNode(false).outerHTML){merge(a,b);b.remove();}while(right.firstChild)left.append(right.firstChild);}
    function split(source,frames,measure){const body=marked(source),total=length(body),result=[];let start=0;
        for(let i=0;i<frames.length;i++){const o=frames[i];if(i===frames.length-1){const html=slice(body,start,total);result.push(html);if(!measure(o,html))overflowing.add(o.id);break;}
            const boundaries=[0];let position=0;for(const character of body.textContent){position+=character.length;boundaries.push(position);}const candidates=boundaries.filter(n=>n>=start);let low=0,high=candidates.length-1;while(low<high){const mid=Math.ceil((low+high)/2),html=slice(body,start,candidates[mid]);if(measure(o,html))low=mid;else high=mid-1;}
            let end=candidates[low];if(end<total&&end>start){const text=body.textContent;let boundary=end;while(boundary>start&&!/\s/.test(text[boundary-1]))boundary--;if(boundary>start)end=boundary;}
            result.push(slice(body,start,end));start=end;
        }return result;
    }
    function prepare(model,measure,styleKey){fragments=new Map();overflowing=new Set();const objects=all(model),ids=new Set(objects.map(o=>o.id)),next=new Set(objects.map(o=>o.flowNext).filter(id=>ids.has(id))),byId=new Map(objects.map(o=>[o.id,o]));
        for(const id of cache.keys())if(!ids.has(id)||next.has(id))cache.delete(id);
        for(const o of objects){if(!supports(o)||next.has(o.id))continue;const frames=walk(byId,o);if(o.type==='toc'){
                const entries=model.contents?.contentsEntries||o.contentsEntries||[],key=JSON.stringify([entries,model.contents,frames.map(n=>[n.id,n.w,n.h,n.fontSize]),styleKey]);let saved=cache.get(o.id);
                if(!saved||saved.key!==key){let start=0;const parts=frames.map((n,index)=>{if(index===frames.length-1){const rest=entries.slice(start);return rest;}let low=start,high=entries.length;while(low<high){const mid=Math.ceil((low+high)/2);if(measure(n,CFSContents.render(n,model,entries.slice(start,mid))))low=mid;else high=mid-1;}const portion=entries.slice(start,low);start=low;return portion;});saved={key,parts,overflow:!measure(frames.at(-1),CFSContents.render(frames.at(-1),model,parts.at(-1)))};cache.set(o.id,saved);}
                frames.forEach((n,i)=>{fragments.set(n.id,{entries:saved.parts[i]});if(i===frames.length-1&&saved.overflow)overflowing.add(n.id);});continue;
            }
            if(frames.length===1&&!o.flowHTML)continue;const source=o.flowHTML??o.html??'',key=JSON.stringify([source,frames.map(n=>[n.id,n.w,n.h,n.style,n.fontSize,n.lineHeight,n.spacing,n.align,n.strokeWidth]),styleKey]);let saved=cache.get(o.id);
            if(!saved||saved.key!==key){const parts=split(source,frames,measure);saved={key,parts,overflow:!measure(frames.at(-1),parts.at(-1))};cache.set(o.id,saved);}
            frames.forEach((n,i)=>fragments.set(n.id,{html:saved.parts[i]}));const last=frames.at(-1);if(saved.overflow)overflowing.add(last.id);
        }
    }
    function text(o){return fragments.get(o.id)?.html??o.flowHTML??o.html??'';}
    function entries(o,model){return fragments.get(o.id)?.entries??o.flowEntries??model.contents?.contentsEntries??o.contentsEntries??[];}
    function edit(model,o,html){const first=root(model,o),frames=chain(model,first);if(frames.length===1&&!first.flowHTML){o.html=clean(html);return;}const parts=frames.map(n=>n===o?html:text(n));first.flowHTML=join(parts);first.html=first.flowHTML;cache.delete(first.id);}
    function link(model,from,to){if(!supports(from)||!supports(to)||(from.type==='toc')!==(to.type==='toc'))throw Error('Link text to text, or contents to contents.');if(from===to||chain(model,to).includes(from))throw Error('A frame cannot link to itself or form a loop.');if(from.flowNext)throw Error('Unlink this frame before choosing another next frame.');if(all(model).some(n=>n.flowNext===to.id))throw Error('The target already has a previous frame.');const owner=o=>model.pages.concat(model.masters||[]).find(p=>p.objects.includes(o)),a=owner(from),b=owner(to);if(CFSLayers.locked(a.objects,from)||CFSLayers.locked(b.objects,to))throw Error('Unlock both frames before linking.');if((model.masters||[]).includes(a)!==(model.masters||[]).includes(b)||((model.masters||[]).includes(a)&&a!==b))throw Error('Keep master-frame links within the same master.');const first=root(model,from);if(from.type!=='toc'){const source=first.flowHTML??first.html??'',target=to.flowHTML??to.html??'';first.flowHTML=source+target;first.html=first.flowHTML;delete to.flowHTML;}from.flowNext=to.id;cache.clear();}
    function unlink(model,o){if(!o.flowNext)return;const owner=model.pages.concat(model.masters||[]).find(p=>p.objects.includes(o));if(CFSLayers.locked(owner.objects,o))throw Error('Unlock the frame before unlinking.');const first=root(model,o),frames=chain(model,first),at=frames.indexOf(o),following=frames[at+1];if(o.type!=='toc'){const before=join(frames.slice(0,at+1).map(text)),after=join(frames.slice(at+1).map(text));first.flowHTML=first.html=before;following.flowHTML=following.html=after;}delete o.flowNext;cache.clear();}
    function remove(model,ids){for(const o of all(model).filter(n=>supports(n)&&!all(model).some(p=>p.flowNext===n.id))){const frames=chain(model,o),remaining=frames.filter(n=>!ids.has(n.id));if(!remaining.length||remaining.length===frames.length)continue;const source=o.flowHTML??o.html??'';if(o.type!=='toc')remaining[0].flowHTML=remaining[0].html=source;remaining.forEach((n,i)=>{if(remaining[i+1])n.flowNext=remaining[i+1].id;else delete n.flowNext;});}cache.clear();}
    function copy(model,o){const result=JSON.parse(JSON.stringify(o));if(supports(o)&&o.type!=='toc')result.html=clean(text(o));delete result.flowNext;delete result.flowHTML;return result;}
    return {supports,prepare,text,entries,edit,link,unlink,remove,copy,chain,root,clean,point,overflow:id=>overflowing.has(id)};
})();
