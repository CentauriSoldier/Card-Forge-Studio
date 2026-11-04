local Snapping={};
function Snapping.move(t,page,o,x,y,temporary)
    local s=t.settings; if not s.autoSnap and not temporary then return x,y; end
    local xs,ys={},{}; local threshold=2;
    if s.snapGrid then xs[#xs+1]=math.floor(x/s.gridX+.5)*s.gridX; ys[#ys+1]=math.floor(y/s.gridY+.5)*s.gridY; end
    if s.snapPage then for _,v in ipairs({0,s.width,s.width/2}) do xs[#xs+1]=v; end; for _,v in ipairs({0,s.height,s.height/2}) do ys[#ys+1]=v; end end
    if s.snapMargin then xs[#xs+1]=s.marginInner; xs[#xs+1]=s.width-s.marginOuter; ys[#ys+1]=s.marginTop; ys[#ys+1]=s.height-s.marginBottom; end
    if s.snapObjects then for _,v in ipairs(page.objects) do if v~=o and not v.parentId then for _,n in ipairs({v.x,v.x+v.w,v.x+v.w/2}) do xs[#xs+1]=n; end; for _,n in ipairs({v.y,v.y+v.h,v.y+v.h/2}) do ys[#ys+1]=n; end end end end
    local function snap(pos,size,list)
        local best,dist=pos,threshold; for _,target in ipairs(list) do for _,offset in ipairs({0,size,size/2}) do local delta=target-pos-offset; if math.abs(delta)<dist then best=pos+delta; dist=math.abs(delta); end end end; return best;
    end
    return snap(x,o.w,xs),snap(y,o.h,ys);
end
return Snapping;
