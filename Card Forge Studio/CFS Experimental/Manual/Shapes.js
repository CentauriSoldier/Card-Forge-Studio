/* Vector geometry for manual objects. No application or game styles are copied. */
window.CFSShapes = (() => {
    const catalog = [
        ['rectangle','Rectangle'],['rounded','Rounded Rectangle'],['ellipse','Ellipse'],
        ['triangle','Triangle'],['diamond','Diamond'],['trapezoid','Trapezoid'],['polygon','Polygon'],
        ['star','Star'],['double-star','Double Star'],['square-star','Square Star'],['arrow','Arrow'],
        ['donut','Donut'],['pie','Pie'],['segment','Segment'],['crescent','Crescent'],['cog','Cog'],
        ['cloud','Cloud'],['callout','Rounded Callout'],['ellipse-callout','Ellipse Callout'],
        ['tear','Tear'],['heart','Heart'],['spiral','Spiral']
    ];
    const names = new Map(catalog);
    const escape = text => String(text).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
    function render(o) {
        const w=o.w,h=o.h,sw=Math.max(0,Number(o.strokeWidth)||0),pad=sw/2;
        const x=pad,y=pad,a=Math.max(.01,w-sw),b=Math.max(.01,h-sw),cx=w/2,cy=h/2;
        const point=(px,py)=>`${x+px*a/100},${y+py*b/100}`;
        const poly=points=>`<polygon points="${points.map(p=>point(...p)).join(' ')}"/>`;
        const path=d=>`<path d="${d}"/>`;
        const p=(px,py)=>point(px,py).replace(',',' ');
        const sides=Math.max(3,Math.min(32,Math.round(Number(o.sides)||5)));
        const radial=(count,inner=1)=>Array.from({length:count},(_,i)=>{
            const angle=-Math.PI/2+i*Math.PI*2/count,r=i%2?inner:1;
            return [50+50*Math.cos(angle)*r,50+50*Math.sin(angle)*r];
        });
        let markup='',fill=o.fill;
        switch(o.type) {
            case 'rectangle': markup=`<rect x="${x}" y="${y}" width="${a}" height="${b}"/>`;break;
            case 'rounded': markup=`<rect x="${x}" y="${y}" width="${a}" height="${b}" rx="${Math.min(a/2,b/2,o.radius||0)}"/>`;break;
            case 'ellipse': markup=`<ellipse cx="${cx}" cy="${cy}" rx="${a/2}" ry="${b/2}"/>`;break;
            case 'triangle':markup=poly([[50,0],[100,100],[0,100]]);break;
            case 'diamond':markup=poly([[50,0],[100,50],[50,100],[0,50]]);break;
            case 'trapezoid':markup=poly([[25,0],[75,0],[100,100],[0,100]]);break;
            case 'polygon':markup=poly(radial(sides));break;
            case 'star':markup=poly(radial(sides*2,Math.max(.05,Math.min(.95,(o.innerRadius||45)/100))));break;
            case 'double-star':markup=poly(radial(sides*4,.6));break;
            case 'square-star':markup=poly(radial(8,.45));break;
            case 'arrow':markup=poly([[0,30],[60,30],[60,0],[100,50],[60,100],[60,70],[0,70]]);break;
            case 'donut':markup=`<path fill-rule="evenodd" d="M ${p(50,0)} A ${a/2} ${b/2} 0 1 1 ${p(49.99,0)} Z M ${p(50,25)} A ${a/4} ${b/4} 0 1 1 ${p(49.99,25)} Z"/>`;break;
            case 'pie':markup=path(`M ${p(50,50)} L ${p(50,0)} A ${a/2} ${b/2} 0 1 1 ${p(100,50)} Z`);break;
            case 'segment':markup=path(`M ${p(0,50)} A ${a/2} ${b/2} 0 0 1 ${p(100,50)} Z`);break;
            case 'crescent':markup=path(`M ${p(75,0)} C ${p(-15,0)} ${p(-15,100)} ${p(75,100)} C ${p(20,75)} ${p(20,25)} ${p(75,0)} Z`);break;
            case 'cog':markup=poly(radial(32,.82));break;
            case 'cloud':markup=path(`M ${p(20,85)} C ${p(-10,85)} ${p(-10,40)} ${p(18,38)} C ${p(15,0)} ${p(65,-5)} ${p(70,25)} C ${p(100,10)} ${p(115,70)} ${p(87,85)} Z`);break;
            case 'callout':markup=path(`M ${p(10,0)} H ${x+a*.9} Q ${p(100,0)} ${p(100,10)} V ${y+b*.65} Q ${p(100,75)} ${p(90,75)} H ${x+a*.45} L ${p(20,100)} L ${p(25,75)} H ${x+a*.1} Q ${p(0,75)} ${p(0,65)} V ${y+b*.1} Q ${p(0,0)} ${p(10,0)} Z`);break;
            case 'ellipse-callout':markup=path(`M ${p(25,72)} C ${p(-20,55)} ${p(0,0)} ${p(50,0)} C ${p(115,0)} ${p(115,75)} ${p(50,80)} L ${p(15,100)} Z`);break;
            case 'tear':markup=path(`M ${p(50,0)} C ${p(45,30)} ${p(0,45)} ${p(0,70)} C ${p(0,110)} ${p(100,110)} ${p(100,70)} C ${p(100,45)} ${p(55,30)} ${p(50,0)} Z`);break;
            case 'heart':markup=path(`M ${p(50,100)} C ${p(-20,50)} ${p(-10,-15)} ${p(50,20)} C ${p(110,-15)} ${p(120,50)} ${p(50,100)} Z`);break;
            case 'spiral':{const points=Array.from({length:181},(_,i)=>{const t=i/180,r=t*48,ang=t*Math.PI*6;return [50+Math.cos(ang)*r,50+Math.sin(ang)*r];});markup=`<polyline points="${points.map(v=>point(...v)).join(' ')}"/>`;fill='none';break;}
            case 'line':markup=`<line x1="${x}" y1="${y}" x2="${w-pad}" y2="${h-pad}"/>`;fill='none';break;
            case 'curve':{const nodes=o.nodes||[[0,100],[50,0],[100,100]];let d=`M ${p(...nodes[0])}`;if(nodes.length>=3)d+=` Q ${p(...nodes[1])} ${p(...nodes[2])}`;else d+=` L ${p(...nodes[1])}`;for(let i=3;i<nodes.length;i++)d+=` L ${p(...nodes[i])}`;if(o.closed)d+=' Z';else fill='none';markup=path(d);break;}
        }
        const stroke=['line','curve','spiral'].includes(o.type)?Math.max(.2,sw):sw;
        return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" preserveAspectRatio="none" aria-label="${escape(names.get(o.type)||o.type)}" style="display:block;width:100%;height:100%;overflow:visible;pointer-events:none" fill="${escape(fill)}" stroke="${escape(o.stroke)}" stroke-width="${stroke}" stroke-linejoin="round" stroke-linecap="round">${markup}</svg>`;
    }
    const clips=o=>names.has(o.type)&&o.type!=='spiral'||o.type==='curve'&&o.closed;
    function geometry(o) {
        const svg=new DOMParser().parseFromString(render(o),'image/svg+xml').documentElement;
        for(const n of svg.children){n.setAttribute('clip-rule',n.getAttribute('fill-rule')||'nonzero');}
        return svg;
    }
    function clip(o,key) {
        if(!clips(o))return '';
        const svg=geometry(o),markup=Array.from(svg.children,n=>{n.setAttribute('transform',`scale(${1/o.w} ${1/o.h})`);return new XMLSerializer().serializeToString(n);}).join('');
        return `<svg aria-hidden="true" style="position:absolute;width:0;height:0;pointer-events:none"><defs><clipPath id="${escape(key)}" clipPathUnits="objectBoundingBox">${markup}</clipPath></defs></svg>`;
    }
    function contains(o,x,y) {
        if(!clips(o))return true;
        const svg=geometry(o);svg.style.cssText='position:fixed;left:-10000px;top:0;width:1px;height:1px;pointer-events:none';document.body.appendChild(svg);
        try{return Array.from(svg.children).some(n=>typeof n.isPointInFill==='function'&&n.isPointInFill(new DOMPoint(x,y)));}finally{svg.remove();}
    }
    function resize(initial,dx,dy,shift,center,constrain=false) {
        const multiplier=center?2:1;
        let w=Math.max(1,initial.w+dx*multiplier),h=Math.max(1,initial.h+dy*multiplier);
        if(Boolean(constrain)!==Boolean(shift)) {
            const factor=Math.abs(w/initial.w-1)>=Math.abs(h/initial.h-1)?w/initial.w:h/initial.h;
            const scale=Math.max(factor,1/initial.w,1/initial.h);w=initial.w*scale;h=initial.h*scale;
        }
        return {w,h,x:center?initial.x+(initial.w-w)/2:initial.x,y:center?initial.y+(initial.h-h)/2:initial.y};
    }
    return {catalog,names,render,resize,clips,clip,contains,has:type=>names.has(type)||['line','curve'].includes(type)};
})();
