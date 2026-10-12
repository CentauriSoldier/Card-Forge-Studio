/* Snap distances are measured in screen pixels; the stored grid uses millimeters. */
(() => {
    "use strict";
    const defaults={gridVisible:false,gridX:5,gridY:5,autoSnap:false,snapGrid:true,snapPage:true,snapMargin:true,snapObjects:true};
    function margins(s,index=0) {return {left:(index%2?s.marginOuter:s.marginInner)??s.margin,right:(index%2?s.marginInner:s.marginOuter)??s.margin,top:s.marginTop??s.margin,bottom:s.marginBottom??s.margin};}
    function snap(list,o,settings,zoom,temporary=false,index=0) {
        if(!settings.autoSnap&&!temporary)return [];
        const excluded=new Set(CFSLayers.descendants(list,o).map(n=>n.id)),m=CFSLayers.matrix(list,o);
        const corners=[[0,0],[o.w,0],[0,o.h],[o.w,o.h]].map(([x,y])=>new DOMPoint(x,y).matrixTransform(m));
        const xs=corners.map(p=>p.x),ys=corners.map(p=>p.y),left=Math.min(...xs),right=Math.max(...xs),top=Math.min(...ys),bottom=Math.max(...ys);
        const source=[[left,(left+right)/2,right],[top,(top+bottom)/2,bottom]],targets=[[],[]];
        if(settings.snapPage){targets[0].push(0,settings.width/2,settings.width);targets[1].push(0,settings.height/2,settings.height);}
        if(settings.snapMargin){const m=margins(settings,index);targets[0].push(m.left,settings.width-m.right);targets[1].push(m.top,settings.height-m.bottom);}
        if(settings.snapObjects)for(const n of list){if(excluded.has(n.id)||CFSLayers.chain(list,n).some(p=>!p.visible)||CFSLayers.chain(list,o).some(p=>p.id===n.id))continue;const nm=CFSLayers.matrix(list,n),p=[[0,0],[n.w,0],[0,n.h],[n.w,n.h]].map(([x,y])=>new DOMPoint(x,y).matrixTransform(nm));for(const [axis,key]of [[0,'x'],[1,'y']]){const a=Math.min(...p.map(v=>v[key])),b=Math.max(...p.map(v=>v[key]));targets[axis].push(a,(a+b)/2,b);}}
        const tolerance=6*25.4/(96*zoom),shift=[0,0],guides=[];
        for(let axis=0;axis<2;axis++){let best=tolerance;for(const value of source[axis]){const candidates=targets[axis].slice();if(settings.snapGrid){const cell=axis?settings.gridY:settings.gridX;if(cell>0)candidates.push(Math.round(value/cell)*cell);}for(const target of candidates){const distance=target-value;if(Math.abs(distance)<best){best=Math.abs(distance);shift[axis]=distance;guides[axis]=target;}}}}
        const [dx,dy]=CFSLayers.delta(list,o,...shift);o.x+=dx;o.y+=dy;return guides;
    }
    window.CFSSnapping={defaults,snap,margins};
})();
