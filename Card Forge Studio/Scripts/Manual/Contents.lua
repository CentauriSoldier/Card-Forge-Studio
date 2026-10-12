-- Contents is one shared, explicitly updated document list.
local Document=require('Manual.Document'); local Text=require('Manual.Text'); local Pages=require('Manual.Pages'); local Contents={};
function Contents.update(t)
    local entries={}; local tiers=t.contents.tiers or {};
    for pageIndex,page in ipairs(t.pages) do
        local objects={}; for _,o in ipairs(page.objects) do if o.type=='text' or o.type=='artistic' then objects[#objects+1]=o; end end
        table.sort(objects,function(a,b) return a.y==b.y and a.x<b.x or a.y<b.y; end);
        for _,o in ipairs(objects) do
            local text=Text.plain(Text.read(o)):gsub('^%s+',''):gsub('%s+$',''); local matched={};
            for level,tier in ipairs(tiers) do
                if level<=6 and tier.source and tier.source~='' then
                    if o.style==tier.source then matched[level]=text;
                    else local parts={}; for _,r in ipairs(Text.read(o)) do if r.style==tier.source then parts[#parts+1]=r.text; end end; if #parts>0 then matched[level]=table.concat(parts); end end
                end
            end
            for level,s in pairs(matched) do if s~='' then entries[#entries+1]={text=s,level=level,page=page.id,number=Pages.number(t,pageIndex),source=o.id}; end end
        end
    end
    t.contents.entries=entries; return #entries;
end
function Contents.fragments(t,chain,context,reader)
    local Renderer=require('Manual.Renderer'); local at=1; local result={};
    for _,o in ipairs(chain) do
        local rows,height={},0;
        while at<=#t.contents.entries do
            local entry=t.contents.entries[at];if entry.level>(t.contents.depth or 6) then at=at+1;else local tier=t.contents.tiers[entry.level] or {};
            local style=reader.resolve(tier.style or t.settings.textStyle,t.manualStyles,tier.size or o.fontSize or 12);
            local lines=Renderer.layout(context,{{text=entry.text,style=style}},math.max(1,(o.w-(tier.indent or (entry.level-1)*4)-(t.contents.pageNumbers==false and 0 or 12))*96/25.4),1.2);
            local h=0; for _,line in ipairs(lines) do h=h+line.height; end
            if height+h>o.h*96/25.4 and #rows>0 then break; end
            if height+h>o.h*96/25.4 then break; end
            rows[#rows+1]={entry=entry,tier=tier,style=style,y=height,lines=lines,height=h}; height=height+h; at=at+1;end
        end
        result[o.id]={rows=rows,overflow=at<=#t.contents.entries};
    end; return result;
end
return Contents;
