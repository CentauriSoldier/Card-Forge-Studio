/* Facing-page display and shared image placement keep physical pages independent. */
window.CFSSpreads = (() => {
    function pair(model,index) {if(index===0)return [0];const left=index%2?index:index-1;return [left,left+1].filter(i=>i<model.pages.length);}
    const visible=(model,index)=>model.settings.facingPages?pair(model,index):[index];
    function owner(model,id) {return model.pages.findIndex(p=>p.objects.some(o=>o.id===id));}
    function roots(p) {return CFSLayers.children(p.objects);}
    function shifted(list,o,offset,prefix='') {
        const copies=JSON.parse(JSON.stringify(CFSLayers.descendants(list,o))),ids=new Map(copies.map(n=>[n.id,prefix+n.id]));
        for(const n of copies){n.id=ids.get(n.id);n.parentId=ids.get(n.parentId)||null;}const root=copies.find(n=>n.id===ids.get(o.id));root.x+=offset;return {root,list:copies};
    }
    function shared(model,index) {
        const indices=pair(model,index),target=indices.indexOf(index),width=model.settings.width;
        return indices.flatMap((i,side)=>roots(model.pages[i]).filter(o=>o.spread).map(o=>({o,list:model.pages[i].objects,offset:(side-target)*width,owner:i})));
    }
    function sidebar(model,render) {let html='';for(let i=0;i<model.pages.length;){const indices=visible(model,i);html+='<div class="page-pair">'+indices.map(render).join('')+'</div>';i=indices.at(-1)+1;}return html;}
    return {pair,visible,owner,roots,shifted,shared,sidebar};
})();
