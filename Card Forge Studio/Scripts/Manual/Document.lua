-- Native document model; the existing HTML snapshot remains readable and writable.
local Document = {};
Document.null = {};
function Document.copy(v)
    if (rawtype(v) ~= "table") then return v; end
    local r = {}; for k,x in pairs(v) do if rawtype(k)~='string' or k:sub(1,1)~='_' then r[k]=Document.copy(x);end;end; return r;
end
function Document.hex(s) return (s:gsub(".", function(c) return string.format("%02x", c:byte()); end)); end
function Document.unhex(s)
    assert(#s % 2 == 0 and not s:find("[^%x]"), "Invalid manual snapshot.");
    return (s:gsub("..", function(c) return string.char(tonumber(c, 16)); end));
end
function Document.decode(s)
    local i, n = 1, #s;
    local function skip() local _, b = s:find("^[ \r\n\t]*", i); i = (b or i - 1) + 1; end
    local value;
    local function stringValue()
        assert(s:sub(i,i) == '"', "Expected JSON string."); i = i + 1; local a = {};
        while i <= n do
            local c = s:sub(i,i); i = i + 1;
            if c == '"' then return table.concat(a); end
            if c == '\\' then
                local e = s:sub(i,i); i = i + 1;
                local escapes = {['"']='"',['\\']='\\',['/']='/',b='\b',f='\f',n='\n',r='\r',t='\t'};
                if e == 'u' then
                    local h = s:sub(i,i+3); assert(#h == 4 and not h:find('[^%x]'), 'Invalid Unicode escape.'); i=i+4;
                    local u=tonumber(h,16);
                    if u>=0xd800 and u<=0xdbff then
                        assert(s:sub(i,i+1)=='\\u','Missing Unicode surrogate.'); i=i+2;
                        local low=tonumber(s:sub(i,i+3),16); i=i+4;
                        assert(low and low>=0xdc00 and low<=0xdfff,'Invalid Unicode surrogate.'); u=0x10000+(u-0xd800)*1024+low-0xdc00;
                    else assert(u<0xdc00 or u>0xdfff,'Invalid Unicode surrogate.'); end
                    a[#a+1]=utf8.char(u);
                else assert(escapes[e], 'Invalid JSON escape.'); a[#a+1]=escapes[e]; end
            else assert(c:byte()>=32,'Invalid JSON control character.'); a[#a+1]=c; end
        end
        error('Unclosed JSON string.');
    end
    value=function(depth)
        assert(depth < 100,'Manual nesting is too deep.'); skip(); local c=s:sub(i,i);
        if c=='"' then return stringValue(); end
        if c=='{' or c=='[' then
            local object=c=='{'; local close=object and '}' or ']'; local t={}; i=i+1; skip();
            if s:sub(i,i)==close then i=i+1; return t; end
            while true do
                skip(); local k=object and stringValue() or #t+1;
                if object then skip(); assert(s:sub(i,i)==':','Expected JSON colon.'); i=i+1; end
                assert(t[k]==nil,'Duplicate JSON key.'); t[k]=value(depth+1); skip();
                local sep=s:sub(i,i); i=i+1; if sep==close then return t; end; assert(sep==',','Expected JSON comma.');
            end
        end
        for literal, result in pairs({['true']=true,['false']=false,['null']=Document.null}) do
            if s:sub(i,i+#literal-1)==literal then i=i+#literal; return result; end
        end
        local first,last=s:find('^-?%d+%.?%d*[eE]?[+-]?%d*',i); local token=first and s:sub(first,last);
        assert(token and token~='', 'Invalid JSON value at '..i); local x=tonumber(token);
        assert(x and x==x and math.abs(x)<math.huge,'Invalid JSON number.'); i=i+#token; return x;
    end
    local t=value(0); skip(); assert(i>n,'Trailing JSON data.'); return t;
end
function Document.encode(t)
    local function quote(s) return '"'..s:gsub('[%z\1-\31\\"]',function(c)
        local e={['"']='\\"',['\\']='\\\\',['\n']='\\n',['\r']='\\r',['\t']='\\t'}; return e[c] or string.format('\\u%04x',c:byte()); end)..'"'; end
    local seen={}; local function encode(v)
        local kind=rawtype(v);
        if v==Document.null then return 'null'; end
        if kind=='string' then return quote(v); end
        if kind=='number' then assert(v==v and math.abs(v)<math.huge,'Nonfinite manual number.'); return string.format('%.17g',v); end
        if kind=='boolean' then return tostring(v); end
        assert(kind=='table' and not seen[v],'Invalid or circular manual data.'); seen[v]=true;
        local count, array=0,true; for k in pairs(v) do count=count+1; if rawtype(k)~='number' or k<1 or k%1~=0 then array=false; end end
        array=array and count==#v and count>0; local a={};
        if array then for _,x in ipairs(v) do a[#a+1]=encode(x); end
        else local keys={}; for k in pairs(v) do assert(rawtype(k)=='string','Invalid manual key.'); if k:sub(1,1)~='_' then keys[#keys+1]=k; end end; table.sort(keys);
            for _,k in ipairs(keys) do a[#a+1]=quote(k)..':'..encode(v[k]); end end
        seen[v]=nil; return (array and '[' or '{')..table.concat(a,',')..(array and ']' or '}');
    end
    return encode(t);
end
function Document.defaults()
    return {preset='letter',units='mm',width=215.9,height=279.4,orientation='portrait',marginInner=17,marginOuter=17,marginTop=17,marginBottom=18,bleed=3,
        textStyle='BASE',textSize=12,pageNumbers=false,numberStyle='BASE',numberStart=1,numberFormat='decimal',numberPosition='center',gridVisible=false,gridX=5,gridY=5,
        autoSnap=false,snapGrid=true,snapPage=true,snapMargin=true,snapObjects=true,facingPages=false,firstPageAlone=true,zoomStep=4};
end
function Document.new()
    return {version=2,nextId=1,settings=Document.defaults(),pages={{id='page-1',name='Page 1',background='#ffffff',objects={}}},masters={},manualStyles={},contents={entries={},tiers={},depth=6,pageNumbers=true}};
end
function Document.id(t,prefix)
    local id; repeat id=(prefix or 'object')..'-'..t.nextId; t.nextId=t.nextId+1; until not Document.find(t,id); return id;
end
function Document.find(t,id)
    if not t._byId then local index={};for _,pages in ipairs({t.pages,t.masters}) do for _,p in ipairs(pages) do index[p.id]={p,p};for i,o in ipairs(p.objects or {}) do index[o.id]={o,p,i};end;end;end;t._byId=index;end
    local entry=t._byId[id];if entry then return table.unpack(entry);end
end
function Document.normalize(t)
    assert(rawtype(t)=='table' and rawtype(t.pages)=='table' and #t.pages>0,'Manual has no pages.');
    t.settings=t.settings or {}; for k,v in pairs(Document.defaults()) do if t.settings[k]==nil then t.settings[k]=v; end end
    t.masters=t.masters or {}; t.manualStyles=t.manualStyles or {}; t.contents=t.contents or {entries={},tiers={}}; t.nextId=t.nextId or 1;t.contents.depth=t.contents.depth or 6;for level=1,6 do t.contents.tiers[level]=t.contents.tiers[level] or {source='',style=t.settings.textStyle,indent=(level-1)*4,leader='dots',align='left'};t.contents.tiers[level].align=t.contents.tiers[level].align or 'left';end;
    local ids={};
    for _,pages in ipairs({t.pages,t.masters}) do for _,p in ipairs(pages) do
        assert(rawtype(p.id)=='string' and not ids[p.id],'Duplicate page identifier.'); ids[p.id]=true; p.objects=p.objects or {};
        for _,o in ipairs(p.objects) do
            assert(rawtype(o.id)=='string' and not ids[o.id],'Duplicate object identifier.'); ids[o.id]=true;
            for _,k in ipairs({'x','y','w','h'}) do assert(rawtype(o[k])=='number' and o[k]==o[k] and math.abs(o[k])<math.huge,'Invalid object geometry.'); end
            assert(o.w>0 and o.h>0,'Object dimensions must be positive.');
        end
        for _,o in ipairs(p.objects) do
            local seen={}; local current=o;
            while current.parentId do
                assert(not seen[current.id],'Circular layer nesting.'); seen[current.id]=true;
                local parent,parentPage=Document.find(t,current.parentId); assert(parent and parentPage==p,'Missing parent layer.'); current=parent;
            end
        end
    end end
    assert(t.settings.width>0 and t.settings.height>0,'Invalid page size.'); return t;
end
function Document.load(s)
    local h=s:match('id="cfs%-manual%-state"[^>]*data%-state="([%x]+)"');
    if h then return Document.normalize(Document.decode(Document.unhex(h))); end
    local t=Document.new(); t.pages[1].objects={{id='object-1',name='Imported content',type='text',x=17,y=17,w=182,h=244,html=s,fontSize=12,style='BASE'}}; t.nextId=2; return t;
end
return Document;
