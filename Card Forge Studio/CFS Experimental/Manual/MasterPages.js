/* Masters share the manual's physical page settings and existing game styles. */
window.CFSMasterPages = (() => {
    const find=(model,id)=>model.masters.find(m=>m.id===id);
    function objects(master,prefix) {
        const list=JSON.parse(JSON.stringify(master.objects)),ids=new Map(list.map(o=>[o.id,prefix+o.id]));
        for(const o of list){o.id=ids.get(o.id);o.parentId=ids.get(o.parentId)||null;}
        return list;
    }
    function remove(model,id) {model.masters=model.masters.filter(m=>m.id!==id);for(const p of model.pages)if(p.masterId===id){p.masterId=null;p.useMasterBackground=false;}}
    function validate(model) {
        if(!Array.isArray(model.masters))throw new Error('Invalid master page list.');
        const ids=new Set();for(const m of model.masters){if(ids.has(m.id)||!Array.isArray(m.objects))throw new Error('Invalid master page.');ids.add(m.id);CFSLayers.validate(m.objects);}
        for(const p of model.pages)if(p.masterId&&!ids.has(p.masterId))throw new Error('A page refers to a missing master.');
    }
    return {find,objects,remove,validate};
})();
