local Document=require('Manual.Document'); local Layers={};
function Layers.children(page,id)
    local a={}; for _,o in ipairs(page.objects) do if o.parentId==id then a[#a+1]=o; end end; return a;
end
function Layers.locked(t,o)
    while o do if o.locked then return true; end; o=o.parentId and Document.find(t,o.parentId) or nil; end; return false;
end
function Layers.subtree(page,o)
    local a={o}; for _,c in ipairs(Layers.children(page,o.id)) do for _,v in ipairs(Layers.subtree(page,c)) do a[#a+1]=v; end end; return a;
end
function Layers.world(t,o)
    local x,y=o.x,o.y; local parent=o.parentId and Document.find(t,o.parentId);
    while parent do
        local a=math.rad(parent.rotation or 0); local cx,cy=parent.w/2,parent.h/2;
        local dx,dy=x-cx,y-cy; x=parent.x+cx+dx*math.cos(a)-dy*math.sin(a); y=parent.y+cy+dx*math.sin(a)+dy*math.cos(a);
        parent=parent.parentId and Document.find(t,parent.parentId);
    end; return x,y;
end
function Layers.localPoint(t,o,x,y)
    local chain={}; local p=o;
    while p do table.insert(chain,1,p); p=p.parentId and Document.find(t,p.parentId); end
    for _,v in ipairs(chain) do
        x,y=x-v.x-v.w/2,y-v.y-v.h/2; local a=math.rad(-(v.rotation or 0)); local xx=x*math.cos(a)-y*math.sin(a); y=x*math.sin(a)+y*math.cos(a)+v.h/2; x=xx+v.w/2;
    end
    return x,y;
end
function Layers.worldPoint(t,o,x,y)
    while o do local dx,dy=x-o.w/2,y-o.h/2;local a=math.rad(o.rotation or 0);x=o.x+o.w/2+dx*math.cos(a)-dy*math.sin(a);y=o.y+o.h/2+dx*math.sin(a)+dy*math.cos(a);o=o.parentId and Document.find(t,o.parentId);end;return x,y;
end
function Layers.angle(t,o)local a=0;while o do a=a+(o.rotation or 0);o=o.parentId and Document.find(t,o.parentId);end;return a;end
function Layers.nest(t,page,o,parent)
    assert(o~=parent,'A layer cannot contain itself.');for _,v in ipairs(Layers.subtree(page,o)) do assert(v~=parent,'Circular layer nesting.');end
    local x,y=Layers.worldPoint(t,o,o.w/2,o.h/2);local angle=Layers.angle(t,o);
    if parent then x,y=Layers.localPoint(t,parent,x,y);end
    o.parentId=parent and parent.id or nil;o.x=x-o.w/2;o.y=y-o.h/2;o.rotation=angle-(parent and Layers.angle(t,parent) or 0);
end
function Layers.remove(page,o)
    local ids={}; for _,v in ipairs(Layers.subtree(page,o)) do ids[v.id]=true; end
    for i=#page.objects,1,-1 do if ids[page.objects[i].id] then table.remove(page.objects,i); end end
    for _,v in ipairs(page.objects) do if ids[v.flowNext] then v.flowNext=nil; end end
end
function Layers.duplicate(t,page,o)
    local map,a={},{};
    for _,v in ipairs(Layers.subtree(page,o)) do local c=Document.copy(v); map[v.id]=Document.id(t); c.id=map[v.id]; a[#a+1]=c; end
    for _,c in ipairs(a) do c.parentId=map[c.parentId] or c.parentId; c.flowNext=map[c.flowNext]; page.objects[#page.objects+1]=c; end
    a[1].x=a[1].x+5; a[1].y=a[1].y+5; return a[1];
end
function Layers.order(page,o,delta)
    local siblings=Layers.children(page,o.parentId); local target;
    for i,v in ipairs(siblings) do if v==o then target=siblings[math.max(1,math.min(#siblings,i+delta))]; break; end end
    if target~=o then local oi,ti; for i,v in ipairs(page.objects) do if v==o then oi=i; elseif v==target then ti=i; end end; table.remove(page.objects,oi);table.insert(page.objects,ti,o); end
end
return Layers;
