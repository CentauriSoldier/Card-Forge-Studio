/* Hierarchy and coordinate transforms; objects retain stable IDs in each page. */
(() => {
    "use strict";
    const parent=(list,o)=>list.find(n=>n.id===o.parentId);
    const children=(list,id=null)=>list.filter(o=>(o.parentId||null)===id);
    function chain(list,o) {const result=[],seen=new Set();while(o){if(seen.has(o.id))throw new Error("Circular layer hierarchy.");seen.add(o.id);result.unshift(o);o=parent(list,o);}return result;}
    function matrix(list,o) {
        let m=new DOMMatrix();for(const n of chain(list,o)){m=m.translate(n.x+n.w/2,n.y+n.h/2).rotate(n.rotation).translate(-n.w/2,-n.h/2);if(n!==o&&!CFSShapes.has(n.type))m=m.translate(n.strokeWidth||0,n.strokeWidth||0);}return m;
    }
    function locked(list,o) {return chain(list,o).some(n=>n.locked);}
    function descendants(list,o) {return list.filter(n=>chain(list,n).some(p=>p.id===o.id));}
    function reparent(list,o,target) {
        if(!o||locked(list,o)||target&&(locked(list,target)||chain(list,target).some(n=>n.id===o.id)))return false;
        const old=matrix(list,o), base=target?matrix(list,target).translate(CFSShapes.has(target.type)?0:target.strokeWidth||0,CFSShapes.has(target.type)?0:target.strokeWidth||0):new DOMMatrix(),local=base.inverse().multiply(old);
        const center=new DOMPoint(o.w/2,o.h/2).matrixTransform(local);
        o.x=center.x-o.w/2;o.y=center.y-o.h/2;o.rotation=Math.atan2(local.b,local.a)*180/Math.PI;
        o.parentId=target?target.id:null;return true;
    }
    function validate(list) {const ids=new Set(list.map(o=>o.id));if(ids.size!==list.length)throw new Error("Duplicate layer IDs.");for(const o of list){if(o.parentId&&!ids.has(o.parentId))throw new Error("Missing parent layer.");chain(list,o);}}
    function rows(list,id=null,depth=0) {return children(list,id).reverse().flatMap(o=>[{o,depth},...rows(list,o.id,depth+1)]);}
    function delta(list,o,x,y,own=false) {const m=own?matrix(list,o):parent(list,o)?matrix(list,parent(list,o)):new DOMMatrix(),angle=Math.atan2(m.b,m.a);return [x*Math.cos(angle)+y*Math.sin(angle),-x*Math.sin(angle)+y*Math.cos(angle)];}
    window.CFSLayers={parent,children,chain,matrix,locked,descendants,reparent,validate,rows,delta};
})();
