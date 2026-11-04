-- HTML is an export and compatibility format; the editor itself is entirely native.
local Document=require('Manual.Document');local Text=require('Manual.Text');local HTML={};
local function colour(n) return string.format('rgba(%d,%d,%d,%.5f)',(n>>24)&255,(n>>16)&255,(n>>8)&255,(n&255)/255);end
function HTML.style(style)
    local p=style.parsed;local css={'font-family:"'..p.FontFamily:gsub('"','')..'"','font-size:'..style.size..'pt','color:'..colour(p.FontColor),p.FontOptions.Bold and 'font-weight:bold' or 'font-weight:normal',p.FontOptions.Italic and 'font-style:italic' or 'font-style:normal',p.FontOptions.Underline and 'text-decoration:underline' or 'text-decoration:none'};
    if p.OutlineEnabled then css[#css+1]='-webkit-text-stroke:'..(p.OutlineThickness or 0)*style.scale..'px '..colour(p.OutlineColor);end
    local shadows={};if p.ShadowEnabled then shadows[#shadows+1]=(p.ShadowX or 0)*style.scale..'px '..(p.ShadowY or 0)*style.scale..'px 0 '..colour(p.ShadowColor);end
    if p.GlowEnabled then shadows[#shadows+1]='0 0 '..(p.GlowRadius or 0)*style.scale..'px '..colour(p.GlowColor);end
    if #shadows>0 then css[#css+1]='text-shadow:'..table.concat(shadows,',');end;return table.concat(css,';');
end
function HTML.render(document,reader)
    local wx=require('wx');local Renderer=require('Manual.Renderer');local Layers=require('Manual.Layers');local TextFlow=require('Manual.TextFlow');local Shapes=require('Manual.Shapes');
    local bitmap=wx.wxBitmap(2,2,32);local dc=wx.wxMemoryDC();dc:SelectObject(bitmap);local gc=wx.wxGraphicsContext.Create(dc);local context=Renderer.context(gc,dc);local flow,contents={},{};
    local function rich(o,runs)
        local a={};local list;
        for _,r in ipairs(runs) do
            if r.list~=list then if list then a[#a+1]='</li></'..list..'>';end;list=r.list;if list then a[#a+1]='<'..list..' style="margin:0;padding-left:20px"><li>';end;end
            a[#a+1]='<span style="'..Text.escape(HTML.style(Text.native(reader,document.manualStyles,o,r)))..'">'..Text.escape(r.text):gsub('\n',list and '</li><li>' or '<br>')..'</span>';
        end;if list then a[#a+1]='</li></'..list..'>';end;return table.concat(a);
    end
    local a={'<!doctype html><html><head><meta charset="utf-8"><title>Game Manual</title><style>body{margin:0;background:#999}.page{position:relative;margin:12px auto;overflow:hidden;break-after:page}.object{position:absolute;box-sizing:border-box;transform-origin:center}.children{position:absolute;inset:0}.text{white-space:pre-wrap;overflow:hidden;width:100%;height:100%} @page{size:'..document.settings.width..'mm '..document.settings.height..'mm;margin:0}@media print{body{background:white}.page{margin:0}}</style></head><body>'};
    local function object(o,page,offset)
        if o.visible==false then return;end
        a[#a+1]='<div class="object" style="left:'..(o.x+(offset or 0))..'mm;top:'..o.y..'mm;width:'..o.w..'mm;height:'..o.h..'mm;opacity:'..(o.opacity or 1)..';transform:rotate('..(o.rotation or 0)..'deg)">';
        local path,w,h=Shapes.svg(o);local clip='shape-'..o.id;
        a[#a+1]='<svg aria-hidden="true" style="position:absolute;width:0;height:0"><defs><clipPath id="'..clip..'" clipPathUnits="objectBoundingBox"><path d="'..Text.escape(path)..'" transform="scale('..1/w..' '..1/h..')" clip-rule="evenodd"/></clipPath></defs></svg>';
        if o.src and o.src~='' then
            if o.pdfClip then a[#a+1]='<svg width="100%" height="100%" viewBox="0 0 1 1" preserveAspectRatio="none"><defs><clipPath id="pdf-'..o.id..'"><path d="'..Text.escape(o.pdfClip.path)..'" clip-rule="evenodd"/></clipPath></defs><image width="1" height="1" preserveAspectRatio="none" href="'..Text.escape(o.src)..'" clip-path="url(#pdf-'..o.id..')"/></svg>';
            else a[#a+1]='<img src="'..Text.escape(o.src)..'" style="display:block;width:100%;height:100%;object-fit:'..(o.fit=='fill' and 'fill' or o.fit=='contain' and 'contain' or 'cover')..';object-position:'..(o.focusX or 50)..'% '..(o.focusY or 50)..'%;clip-path:url(#'..clip..')">';end
        elseif o.type=='text' or o.type=='artistic' then
            local root=TextFlow.root(document,o);if not flow[root.id] then flow[root.id]=TextFlow.layout(document,root,context,reader);end;local fragment=flow[root.id][o.id];
            a[#a+1]='<div class="text" style="font-size:'..(o.fontSize or document.settings.textSize)..'pt;line-height:'..(o.lineHeight or 1.2)..';text-align:'..(o.align or 'left')..'">'..rich(o,fragment and fragment.runs or Text.read(o))..'</div>';
        elseif o.type=='table' then
            local cells=require('Manual.Tables').cells(o);a[#a+1]='<table style="table-layout:fixed;border-collapse:collapse;width:100%;height:100%;background:'..(o.fill or 'white')..'">';
            for r=1,o.rows or 3 do a[#a+1]='<tr>';for c=1,o.columns or 3 do a[#a+1]='<td style="border:'..(o.strokeWidth or .2)..'mm solid '..(o.stroke or '#777777')..'">'..rich(o,Text.read(cells[r][c]))..'</td>';end;a[#a+1]='</tr>';end;a[#a+1]='</table>';
        elseif o.type=='toc' then
            local root=TextFlow.root(document,o);if not contents[root.id] then contents[root.id]=require('Manual.Contents').fragments(document,TextFlow.chain(document,root),context,reader);end
            for _,row in ipairs(contents[root.id][o.id].rows) do
                local border=row.tier.leader=='none' and 'none' or row.tier.leader=='line' and '1px solid' or '1px dotted';
                local numbers=document.contents.pageNumbers~=false;a[#a+1]='<div style="display:flex;padding-left:'..(row.tier.indent or 0)..'mm;'..Text.escape(HTML.style(row.style))..'"><span style="text-align:'..(row.tier.align or 'left')..';'..(numbers and '' or 'flex:1')..'">'..Text.escape(row.entry.text)..'</span>'..(numbers and '<span style="flex:1;border-bottom:'..border..';margin:0 4px"></span><span>'..row.entry.number..'</span>' or '')..'</div>';
            end
        else a[#a+1]='<svg width="100%" height="100%" viewBox="0 0 '..w..' '..h..'" preserveAspectRatio="none"><path d="'..Text.escape(path)..'" fill="'..(o.fill or 'transparent')..'" fill-rule="evenodd" stroke="'..(o.stroke or 'transparent')..'" stroke-width="'..((o.strokeWidth or 0)*96/25.4)..'"/></svg>';
        end
        local children=Layers.children(page,o.id);if #children>0 then a[#a+1]='<div class="children" style="clip-path:url(#'..clip..')">';for _,child in ipairs(children) do object(child,page);end;a[#a+1]='</div>';end;a[#a+1]='</div>';
    end
    local function backgroundImage(p)
        if p.backgroundImage and p.backgroundImage~='' then a[#a+1]='<div style="position:absolute;inset:0;background-image:url(&quot;'..Text.escape(p.backgroundImage)..'&quot;);background-size:'..(p.backgroundMode=='tile' and 'auto' or p.backgroundMode=='fill' and '100% 100%' or p.backgroundMode=='contain' and 'contain' or 'cover')..';background-repeat:'..(p.backgroundMode=='tile' and 'repeat' or 'no-repeat')..';background-position:center"></div>';end
    end
    local ok,err=xpcall(function()
        for index,page in ipairs(document.pages) do
            local master=require('Manual.MasterPages').get(document,page);local background=master and page.useMasterBackground~=false and master or page;a[#a+1]='<section class="page" style="width:'..document.settings.width..'mm;height:'..document.settings.height..'mm;background:'..(background.background or '#ffffff')..'">';backgroundImage(background);
            if document.settings.facingPages then local pair=require('Manual.Spreads').indices(document,index);if #pair==2 then local other=index==pair[1] and pair[2] or pair[1];for _,o in ipairs(document.pages[other].objects) do if o.acrossSpread and not o.parentId then object(o,document.pages[other],index==pair[1] and document.settings.width or -document.settings.width);end end end end
            if master then for _,o in ipairs(master.objects) do if not o.parentId then object(o,master);end end end
            for _,o in ipairs(page.objects) do if not o.parentId then object(o,page);end end
            if document.settings.pageNumbers then local number=require('Manual.Pages').number(document,index);a[#a+1]='<div style="position:absolute;bottom:5mm;left:5mm;right:5mm;text-align:'..document.settings.numberPosition..';'..Text.escape(HTML.style(reader.resolve(document.settings.numberStyle,document.manualStyles,10)))..'">'..number..'</div>';end
            a[#a+1]='</section>';
        end
    end,debug.traceback);gc:delete();dc:SelectObject(wx.wxNullBitmap);dc:delete();bitmap:delete();assert(ok,err);
    a[#a+1]='<template id="cfs-manual-state" data-state="'..Document.hex(Document.encode(document))..'"></template></body></html>';return table.concat(a);
end
return HTML;
