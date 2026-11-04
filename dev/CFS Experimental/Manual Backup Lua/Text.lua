-- Text is stored as styled runs. Lists are paragraph attributes, not objects.
local Document=require('Manual.Document'); local Text={};
local function packed(s) local c=require('Manual.Themes').colour(s); local n=(c:Red()<<24)|(c:Green()<<16)|(c:Blue()<<8)|c:Alpha();c:delete();return n;end
function Text.escape(s) return (s:gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;'):gsub('"','&quot;')); end
function Text.entities(s)
    local named={amp='&',lt='<',gt='>',quot='"',apos="'",nbsp=' '};
    return (s:gsub('&(#?[%w]+);',function(k)
        if named[k] then return named[k]; end
        local n=k:match('^#x(%x+)$'); n=n and tonumber(n,16) or tonumber(k:match('^#(%d+)$'));
        if n and n<=0x10ffff and not (n>=0xd800 and n<=0xdfff) then return utf8.char(n); end; return '&'..k..';';
    end));
end
function Text.len(s) return assert(utf8.len(s),'Invalid UTF-8 text.'); end
function Text.substring(s,a,b)
    local n=Text.len(s); a=math.max(0,math.min(n,a)); b=math.max(a,math.min(n,b or n));
    return s:sub(utf8.offset(s,a+1) or #s+1,(utf8.offset(s,b+1) or #s+1)-1);
end
function Text.parse(html,base)
    local runs,stack={},{{style=base or ''}}; local pos=1; local list;
    local function append(s)
        s=Text.entities(s); if s=='' then return; end; local r=Document.copy(stack[#stack]); r.text=s; runs[#runs+1]=r;
    end
    while pos<=#html do
        local a,b,tag=html:find('<([^>]+)>',pos); if not a then append(html:sub(pos)); break; end
        append(html:sub(pos,a-1)); local close,name=tag:match('^%s*(/?)%s*([%w%-]+)'); name=name and name:lower();
        if name then
            if name=='br' then append('\n');
            elseif close=='/' then
                if name=='p' or name=='div' or name=='li' or name:match('^h[1-6]$') then append('\n'); end
                if name=='ol' or name=='ul' then list=nil; elseif #stack>1 then table.remove(stack); end
            else
                if name=='ol' or name=='ul' then list=name;
                else
                    local r=Document.copy(stack[#stack]);
                    local attributes={}; for k,q,v in tag:gmatch('([%w%-]+)%s*=%s*(["\'])(.-)%2') do attributes[k:lower()]=Text.entities(v); end
                    if name:sub(1,2)=='s-' then r.style=name:sub(3):upper(); end
                    r.style=attributes['data-manual-style'] and 'manual:'..attributes['data-manual-style'] or attributes['data-style'] or r.style;
                    if name=='b' or name=='strong' then r.Bold=true; elseif name=='i' or name=='em' then r.Italic=true; elseif name=='u' then r.Underline=true; end
                    for k,v in (attributes.style or ''):gmatch('([%w%-]+)%s*:%s*([^;]+)') do
                        k=k:lower(); v=v:match('^%s*(.-)%s*$');
                        if k=='font-size' then r.size=tonumber(v:match('([%d%.]+)')); elseif k=='font-family' then r.fontFamily=v:gsub('^["\']',''):gsub('["\']$','');
                        elseif k=='color' then r.colorCSS=v; elseif k=='font-weight' then r.Bold=v=='bold' or (tonumber(v) or 0)>=600;
                        elseif k=='font-style' then r.Italic=v=='italic'; elseif k=='text-decoration' then r.Underline=v:find('underline',1,true)~=nil;
                        elseif k=='-webkit-text-stroke' then r.outlineSize=tonumber(v:match('([%d%.]+)')); r.outlineColor=v:match('(#[%x]+)');
                        elseif k=='text-align' then r.align=v; end
                    end
                    if name=='li' then r.list=list or 'ul'; end
                    stack[#stack+1]=r;
                end
            end
        end
        pos=b+1;
    end
    return runs;
end
function Text.read(o)
    if o.runs then return o.runs; end
    local source=o.flowHTML or o.html;if o._textSource~=source then o._textSource=source; o._textRuns=Text.parse(source or '',o.style);for _,r in ipairs(o._textRuns) do if r.size and math.abs(r.size-(o.fontSize or 12))<.0001 then r.size=nil;end;end; end
    return o._textRuns or {};
end
function Text.plain(runs) local a={}; for _,r in ipairs(runs) do a[#a+1]=r.text; end; return table.concat(a); end
function Text.slice(runs,a,b)
    local result={}; local at=0;
    for _,r in ipairs(runs) do local n=Text.len(r.text); local first,last=math.max(a-at,0),math.min(b-at,n);
        if last>first then local copy=Document.copy(r); copy.text=Text.substring(r.text,first,last); result[#result+1]=copy; end; at=at+n;
    end; return result;
end
function Text.write(o,runs)
    local merged={};local previousKey;
    for _,run in ipairs(runs) do local attributes=Document.copy(run);attributes.text=nil;local key=Document.encode(attributes);
        if key==previousKey then merged[#merged].text=merged[#merged].text..run.text;else merged[#merged+1]=Document.copy(run);previousKey=key;end
    end;runs=merged;
    o.runs=runs;o.flowHTML=nil; o._textRuns=nil; o._textSource=nil; o.html=Text.html(runs);
end
function Text.html(runs)
    local a={}; local currentList;
    for _,r in ipairs(runs) do
        if r.list~=currentList then if currentList then a[#a+1]='</li></'..currentList..'>'; end; currentList=r.list; if currentList then a[#a+1]='<'..currentList..'><li>'; end end
        local attributes={}; if r.style and r.style~='' then attributes[#attributes+1]='data-style="'..Text.escape(r.style)..'"'; end
        local css={}; if r.size then css[#css+1]='font-size:'..r.size..'pt'; end
        if r.fontFamily then css[#css+1]='font-family:'..r.fontFamily; end; if r.colorCSS then css[#css+1]='color:'..r.colorCSS; end
        for _,flag in ipairs({{'Bold','font-weight','bold','normal'},{'Italic','font-style','italic','normal'},{'Underline','text-decoration','underline','none'}}) do
            if r[flag[1]]~=nil then css[#css+1]=flag[2]..':'..(r[flag[1]] and flag[3] or flag[4]); end end
        if #css>0 then attributes[#attributes+1]='style="'..Text.escape(table.concat(css,';'))..'"'; end
        local s=Text.escape(r.text):gsub('\n',currentList and '</li><li>' or '<br>'); a[#a+1]='<span '..table.concat(attributes,' ')..'>'..s..'</span>';
    end
    if currentList then a[#a+1]='</li></'..currentList..'>'; end; return table.concat(a);
end
function Text.replace(o,a,b,s,typing)
    local runs=Text.read(o); local n=Text.len(Text.plain(runs)); local result=Text.slice(runs,0,a);
    if s~='' then local r=Document.copy(typing or runs[1] or {style=o.style}); r.text=s; result[#result+1]=r; end
    for _,r in ipairs(Text.slice(runs,b,n)) do result[#result+1]=r; end; Text.write(o,result);
end
function Text.format(o,a,b,values)
    local runs=Text.read(o); local n=Text.len(Text.plain(runs)); local result=Text.slice(runs,0,a);
    for _,r in ipairs(Text.slice(runs,a,b)) do if values.style then r.fontFamily=nil;r.colorCSS=nil;r.outlineSize=nil;r.outlineColor=nil;r.size=nil;r.Bold=nil;r.Italic=nil;r.Underline=nil;end;for k,v in pairs(values) do r[k]=v;end;if values.size then r.sizePinned=true;end; result[#result+1]=r; end
    for _,r in ipairs(Text.slice(runs,b,n)) do result[#result+1]=r; end; Text.write(o,result);
end
function Text.native(reader,manual,o,r)
    local name=r.style and r.style~='' and r.style or o.style and o.style~='' and o.style or 'BASE';
    local size=r.size or (o.fontSize and o.fontSize>0 and o.fontSize) or 12;
    local style=reader.resolve(name,manual,size,r);
    local explicit=(r.style and r.style~='') or (o.style and o.style~='');
    if not explicit and (r.fontFamily or r.colorCSS or r.outlineSize) then
        for _,key in ipairs({'BackgroundEnabled','ShadowEnabled','D3Enabled','GlowEnabled','GlowGradientEnabled','OutlineEnabled'})do style.parsed[key]=false;end;
        style.parsed.FontSize=size;style.scale=1;style.parsed.LetterSpacing=0;
    end

    if r.colorCSS then style.parsed.FontColor=packed(r.colorCSS); end
    if r.outlineSize then
        if not explicit then style.importOutline={radius=r.outlineSize*96/72,color=packed(r.outlineColor or '#000000')};
        else style.parsed.OutlineEnabled=true;style.parsed.OutlineThickness=r.outlineSize*96/72/style.scale;style.parsed.OutlineColor=packed(r.outlineColor or '#000000');end;
    end
    return style;
end
function Text.setBlockSize(o,size)
    local runs=Document.copy(Text.read(o));local old=o.fontSize or 12;for _,r in ipairs(runs) do if r.size and not r.sizePinned and math.abs(r.size-old)<.0001 then r.size=nil;end;end;Text.write(o,runs);o.fontSize=size;
end
return Text;
