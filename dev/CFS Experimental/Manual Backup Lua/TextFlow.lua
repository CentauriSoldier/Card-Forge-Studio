-- A chain owns one story; displayed fragments are derived, never separate copies.
local Document=require('Manual.Document'); local Text=require('Manual.Text'); local TextFlow={};
function TextFlow.previous(t,o)
    if not t._flowPrevious then local index={};for _,pages in ipairs({t.pages,t.masters}) do for _,p in ipairs(pages) do for _,v in ipairs(p.objects) do if v.flowNext then index[v.flowNext]=v;end;end;end;end;t._flowPrevious=index;end
    return t._flowPrevious[o.id];
end
function TextFlow.root(t,o)
    local seen={}; while TextFlow.previous(t,o) do assert(not seen[o.id],'Circular frame links.'); seen[o.id]=true; o=TextFlow.previous(t,o); end; return o;
end
function TextFlow.chain(t,o)
    local list,seen={},{};
    while o do assert(not seen[o.id],'Circular frame links.'); seen[o.id]=true; list[#list+1]=o; o=o.flowNext and Document.find(t,o.flowNext); end; return list;
end
function TextFlow.link(t,o,target)
    assert(o~=target and (o.type=='toc')==(target.type=='toc'),'Link matching frame types.');
    assert(not TextFlow.previous(t,target),'Target already has a previous frame.'); assert(not o.flowNext,'Unlink the current continuation first.');
    for _,v in ipairs(TextFlow.chain(t,target)) do assert(v~=o,'Circular frame links.'); end
    if o.type~='toc' then
        local root=TextFlow.root(t,o); local runs=Document.copy(Text.read(root));
        for _,r in ipairs(Text.read(target)) do runs[#runs+1]=Document.copy(r); end; Text.write(root,runs);
        for _,v in ipairs(TextFlow.chain(t,target)) do v.runs={}; v.html=''; end
    end
    o.flowNext=target.id;t._flowPrevious=nil;
end
function TextFlow.layout(t,root,context,reader)
    local Renderer=require("Manual.Renderer");
    local runs=Text.read(root); local full=Text.plain(runs); local start=0; local fragments={};
    for _,o in ipairs(TextFlow.chain(t,root)) do
        local tail=Text.slice(runs,start,Text.len(full)); local native={};
        for _,r in ipairs(tail) do native[#native+1]={text=r.text,style=Text.native(reader,t.manualStyles,o,r),list=r.list,align=r.align}; end
        local lines=Renderer.layout(context,native,o.w*96/25.4,o.lineHeight or 1.2); local used,height=0,0;
        for _,line in ipairs(lines) do
            if height+line.height>o.h*96/25.4 then break; end
            height=height+line.height; for _,r in ipairs(line.runs) do used=used+Text.len(r.text); end
            -- Explicit newlines are not represented as drawable runs.
            if Text.substring(full,start+used,start+used+1)=='\n' then used=used+1; end
        end
        if not o.flowNext then used=Text.len(full)-start; end
        fragments[o.id]={runs=Text.slice(runs,start,start+used),start=start,finish=start+used,overflow=height>=o.h*96/25.4 and start+used<Text.len(full)};
        start=start+used;
    end
    return fragments;
end
function TextFlow.unlink(t,o,fragments)
    if not o.flowNext then return; end
    local root=TextFlow.root(t,o); local next=Document.find(t,o.flowNext); local frag=assert(fragments[next.id],'Lay out the chain before unlinking.');
    local runs=Text.read(root); local n=Text.len(Text.plain(runs)); Text.write(next,Text.slice(runs,frag.start,n)); Text.write(root,Text.slice(runs,0,frag.start)); o.flowNext=nil;t._flowPrevious=nil;
end
return TextFlow;
