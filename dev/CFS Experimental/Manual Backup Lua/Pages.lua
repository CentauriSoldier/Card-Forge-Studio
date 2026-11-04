local Document=require('Manual.Document'); local Pages={};
function Pages.add(t,master)
    local p={id=Document.id(t,master and 'master' or 'page'),name=(master and 'Master ' or 'Page ')..(#(master and t.masters or t.pages)+1),background='#ffffff',objects={}};
    local list=master and t.masters or t.pages; list[#list+1]=p;t._byId=nil;return p;
end
function Pages.duplicate(t,p)
    local copy=Document.copy(p); local map={}; copy.id=Document.id(t,p.id:match('^master') and 'master' or 'page'); copy.name=p.name..' copy';
    for _,o in ipairs(copy.objects) do local old=o.id; o.id=Document.id(t); map[old]=o.id; end
    for _,o in ipairs(copy.objects) do o.parentId=map[o.parentId]; o.flowNext=map[o.flowNext]; end
    local list=p.id:match('^master') and t.masters or t.pages; list[#list+1]=copy;t._byId=nil;return copy;
end
function Pages.remove(t,p)
    local list=p.id:match('^master') and t.masters or t.pages; assert(list~=t.pages or #list>1,'Keep at least one page.');
    for i,v in ipairs(list) do if v==p then table.remove(list,i); break; end end
    t._byId=nil;t._flowPrevious=nil;for _,page in ipairs(t.pages) do if page.masterId==p.id then page.masterId=nil;end;end
end
function Pages.move(t,p,delta)
    local list=p.id:match('^master') and t.masters or t.pages;
    for i,v in ipairs(list) do if v==p then local j=math.max(1,math.min(#list,i+delta)); table.remove(list,i); table.insert(list,j,p); return; end end
end
function Pages.number(t,index)
    local n=(t.settings.numberStart or 1)+index-1;
    if t.settings.numberFormat=='roman' or t.settings.numberFormat=='ROMAN' then
        local a={}; for _,v in ipairs({{1000,'M'},{900,'CM'},{500,'D'},{400,'CD'},{100,'C'},{90,'XC'},{50,'L'},{40,'XL'},{10,'X'},{9,'IX'},{5,'V'},{4,'IV'},{1,'I'}}) do
            while n>=v[1] do a[#a+1]=v[2]; n=n-v[1]; end end; return t.settings.numberFormat=='ROMAN' and table.concat(a) or table.concat(a):lower();
    end
    return tostring(n);
end
return Pages;
