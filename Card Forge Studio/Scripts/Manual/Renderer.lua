-- Editor and clean preview share the existing native FontStyle drawing path.
local wx = require("wx");
local FontStyle = require("FontStyle");
local StyleEditor = require("Windows.StyleEditor");
local Renderer = {};
Renderer.drawing = StyleEditor.drawing;

function Renderer.context(oGC, oDC)
    return {gc = oGC, dc = oDC, drawing = StyleEditor.drawing(oGC, oDC), fonts = {}};
end

local function signature(tStyle)
    local tParts = {};
    for sKey, vValue in pairs(tStyle.parsed) do
        if (rawtype(vValue) ~= "table") then tParts[#tParts + 1] = sKey..":"..tostring(vValue); end
    end
    for sKey, vValue in pairs(tStyle.parsed.FontOptions) do tParts[#tParts + 1] = sKey..":"..tostring(vValue); end
    if tStyle.importOutline then tParts[#tParts+1]="ImportOutline:"..tStyle.importOutline.radius..":"..tStyle.importOutline.color;end;
    table.sort(tParts); return table.concat(tParts, "|");
end

local function font(tContext, tStyle)
    local sKey = signature(tStyle);
    if (not tContext.fonts[sKey]) then tContext.fonts[sKey] = FontStyle("MANUAL_TEXT", tStyle.parsed); end
    return tContext.fonts[sKey];
end

function Renderer.measure(tContext, tStyle, sText)
    local oStyle = font(tContext, tStyle);
    local nWidth, nHeight, nMinX, nMinY = oStyle.Prep(tContext.drawing, sText);
    local nAdvance, nCount, nSpacing = 0, 0, tStyle.parsed.LetterSpacing or 0;
    if (nSpacing == 0) then nAdvance = tContext.drawing.GetTextWidth(sText);
    else
        for _, nCode in utf8.codes(sText) do nAdvance = nAdvance + tContext.drawing.GetTextWidth(utf8.char(nCode)); nCount = nCount + 1; end
        nAdvance = nAdvance + math.max(0, nCount - 1) * nSpacing;
    end
    local _,normalHeight,descent=tContext.gc:GetTextExtent(sText);
    return nAdvance * tStyle.scale, normalHeight * tStyle.scale,
        nWidth * tStyle.scale, nHeight * tStyle.scale, nMinX * tStyle.scale, nMinY * tStyle.scale,(normalHeight-descent)*tStyle.scale,descent*tStyle.scale;
end

-- Imported fractional strokes need an alpha ring; offset glyphs alone would fill transparent lettering.
local function importedOutline(context,style,text)
    local cache=context.fonts._importMasks or {};context.fonts._importMasks=cache;local key=signature(style)..'|'..text;local result=cache[key];if result then return result;end
    local outline=style.importOutline;local width,height=Renderer.measure(context,style,text);local pad=math.ceil(outline.radius)+2;local w,h=math.ceil(width)+pad*2,math.ceil(height)+pad*2;
    local parsed={};for k,v in pairs(style.parsed)do parsed[k]=v;end;parsed.FontColor=0x000000ff;local maskStyle={parsed=parsed,size=style.size,scale=1};
    local function mask(expand)
        local bitmap=wx.wxBitmap(w,h,32);local dc=wx.wxMemoryDC();dc:SelectObject(bitmap);dc:SetBackground(wx.wxBrush(wx.wxWHITE));dc:Clear();local gc=wx.wxGraphicsContext.Create(dc);local c=Renderer.context(gc,dc);local native=font(c,maskStyle);
        if expand then for i=0,15 do local angle=i*math.pi/8;native.Draw('Imported outline mask',c.drawing,dc,pad+math.cos(angle)*outline.radius,pad+math.sin(angle)*outline.radius,text);end;end;
        native.Draw('Imported outline mask',c.drawing,dc,pad,pad,text);gc:delete();dc:SelectObject(wx.wxNullBitmap);dc:delete();local image=bitmap:ConvertToImage();local data=image:GetData();image:delete();bitmap:delete();return data;
    end
    local original,expanded=mask(false),mask(true);local top=0;for y=0,h-1 do local found=false;for x=0,w-1 do if original:byte((y*w+x)*3+1)<128 then found=true;break;end;end;if found then top=y-pad;break;end;end;local alpha={};local opacity=outline.color&255;
    for i=1,w*h do local position=(i-1)*3+1;alpha[i]=string.char(math.floor(math.max(0,original:byte(position)-expanded:byte(position))*opacity/255+.5));end
    local image=wx.wxImage(w,h);image:SetData(string.rep(string.char((outline.color>>24)&255,(outline.color>>16)&255,(outline.color>>8)&255),w*h));image:SetAlpha(table.concat(alpha));local bitmap=wx.wxBitmap(image);image:delete();result={bitmap=bitmap,w=w,h=h,pad=pad,top=top};cache[key]=result;return result;
end

function Renderer.run(tContext, tStyle, sText, nX, nY)
    local oGC = tContext.gc;
    oGC:PushState();
    local bOK, sError = xpcall(function()
        oGC:Translate(nX, nY); oGC:Scale(tStyle.scale, tStyle.scale);
        local native=font(tContext,tStyle);local textY=0;
        if tStyle.importOutline and tStyle.importOutline.radius>0 then
            local outline=importedOutline(tContext,tStyle,sText);textY=-outline.top;oGC:DrawBitmap(outline.bitmap,-outline.pad,-outline.pad+textY,outline.w,outline.h);
        end
        native.Draw("Manual text", tContext.drawing, tContext.dc, 0, textY, sText);
    end, debug.traceback);
    oGC:PopState(); assert(bOK, sError);
end

-- Layout uses native font measurements. Adjacent equal-style runs stay together for shaping.
function Renderer.layout(tContext, tRuns, nWidth, nLineSpacing)
    local currentList,currentAlign,listIndex=nil,nil,0;local paragraphStart=true;
    local tLines, tLine, tLastStyle = {}, {runs = {}, width = 0, height = 0}, tRuns[1] and tRuns[1].style;
    local function line(paragraphEnd)
        if (tLine.height == 0 and tLastStyle) then local _, nH = Renderer.measure(tContext, tLastStyle, "M"); tLine.height = nH * (nLineSpacing or 1.4); end
        tLine.list=currentList;tLine.align=currentAlign;if currentList and paragraphStart then listIndex=listIndex+1;tLine.marker=currentList=='ol' and listIndex..'.' or utf8.char(0x2022);end;paragraphStart=paragraphEnd==true;
        tLines[#tLines + 1] = tLine; tLine = {runs = {}, width = 0, height = 0};
    end
    local function append(tStyle, sText)
        local nW,nH,_,_,_,_,ascent,descent=Renderer.measure(tContext,tStyle,sText);
        local tLast = tLine.runs[#tLine.runs]; local sKey = signature(tStyle)..":"..tStyle.size;
        local nAdded = nW;
        if (tLast and tLast.key == sKey) then nAdded = Renderer.measure(tContext, tStyle, tLast.text..sText) - tLast.width; end
        if (tLine.width > 0 and tLine.width + nAdded > nWidth - (currentList and 20 or 0) + 0.01) then line(); tLast = nil; nAdded = nW; end
        if (nW > nWidth and utf8.len(sText) > 1) then
            for _, nCode in utf8.codes(sText) do append(tStyle, utf8.char(nCode)); end
            return;
        end
        if (tLast and tLast.key == sKey) then tLast.text = tLast.text..sText; tLast.width = tLast.width + nAdded;
        else tLine.runs[#tLine.runs + 1] = {style = tStyle, text = sText, width=nW,key=sKey,ascent=ascent,descent=descent}; end
        tLine.ascent=math.max(tLine.ascent or 0,ascent);tLine.descent=math.max(tLine.descent or 0,descent);
        tLine.width = tLine.width + nAdded; tLine.height = math.max(tLine.height, nH * (nLineSpacing or 1.4));
    end
    for _, tRun in ipairs(tRuns) do
        if tRun.list~=currentList then listIndex=0;end;currentList=tRun.list or nil;currentAlign=tRun.align;
        tLastStyle = tRun.style;
        local nStart = 1;
        while (nStart <= #tRun.text) do
            local sTail = tRun.text:sub(nStart);
            local sToken = sTail:match("^[^%s]+") or sTail:match("^[ \t]+") or sTail:sub(1, 1);
            if (sToken == "\n" or sToken == "\r") then line(true); else append(tRun.style, sToken); end
            nStart = nStart + #sToken;
        end
    end
    if (#tLine.runs > 0 or #tLines == 0) then line(); end
    return tLines;
end

function Renderer.textBox(tContext, tRuns, nX, nY, nWidth, nHeight, tOptions)
    tOptions = tOptions or {};
    local tLines = Renderer.layout(tContext, tRuns, nWidth, tOptions.lineSpacing);
    local nTop = 0; local bOverflow = false;
    local oGC = tContext.gc; oGC:PushState(); oGC:Clip(nX, nY, nWidth, nHeight);
    local bOK, sError = xpcall(function()
        for _, tLine in ipairs(tLines) do
            if (nTop + tLine.height > nHeight + 0.01 or tLine.width > nWidth + 0.01) then bOverflow = true; end
            local alignment=tLine.align or tOptions.align;local indent=tLine.list and 20 or 0;
            if tLine.marker and tLine.runs[1] then Renderer.run(tContext,tLine.runs[1].style,tLine.marker,nX,nY+nTop);end
            local nLeft = alignment == "right" and nWidth - tLine.width or alignment == "center" and (nWidth - tLine.width) / 2 or indent;
            for _, tRun in ipairs(tLine.runs) do Renderer.run(tContext, tRun.style, tRun.text, nX + nLeft, nY+nTop+(tLine.ascent or 0)-(tRun.ascent or 0)); nLeft = nLeft + tRun.width; end
            nTop = nTop + tLine.height;
        end
    end, debug.traceback);
    oGC:PopState(); assert(bOK, sError);
    return {lines = tLines, height = nTop, overflow = bOverflow};
end


Renderer.pixelsPerMM = 96 / 25.4;
function Renderer.pen(c,w,style) return wx.wxPen(c,math.max(1,math.floor(w+.5)),style or wx.wxPENSTYLE_SOLID); end
local Themes = require('Manual.Themes');
local Shapes = require('Manual.Shapes');
local Text = require('Manual.Text');
local Layers = require('Manual.Layers');
local TextFlow = require('Manual.TextFlow');
local Document = require('Manual.Document');
local function colour(s) return Themes.colour(s); end
function Renderer.nativeRuns(editor,o,runs)
    local a={}; for _,r in ipairs(runs or Text.read(o)) do a[#a+1]={text=r.text,style=Text.native(editor.styles,editor.document.manualStyles,o,r),list=r.list,align=r.align}; end; return a;
end
function Renderer.clip(context,o,path,w,h,cache)
    local key=o.id..':'..(o.pdfClip and o.pdfClip.path or o.type)..':'..w..':'..h..':'..(o.radius or 0)..':'..(o.sides or 0)..':'..(o.innerRadius or 0)..':'..(o.nodes and Document.encode(o.nodes) or '');
    local region=cache[key]; if not region then region=Shapes.region(path,w,h);cache[key]=region;end; context.gc:Clip(region);
end
function Renderer.image(context,editor,o,w,h)
    if not o.src or o.src=='' then return; end
    local bitmap=editor.images.get(o.src,o.hue); if not bitmap then return; end
    local iw,ih=bitmap:GetWidth(),bitmap:GetHeight();local dw,dh=w,h;
    if o.fit=='contain' or o.fit=='cover' then local scale=o.fit=='contain' and math.min(w/iw,h/ih) or math.max(w/iw,h/ih);dw,dh=iw*scale,ih*scale;end
    context.gc:DrawBitmap(bitmap,(w-dw)*(o.focusX or 50)/100,(h-dh)*(o.focusY or 50)/100,dw,dh);
end
function Renderer.object(context,editor,page,o,clean)
    if o.visible==false then return; end
    local gc=context.gc;local P=Renderer.pixelsPerMM;local w,h=o.w*P,o.h*P;
    gc:PushState();gc:Translate(o.x*P+w/2,o.y*P+h/2);gc:Rotate(math.rad(o.rotation or 0));gc:Translate(-w/2,-h/2);
    local layered=(o.opacity or 1)<1; if layered then gc:BeginLayer(math.max(0,o.opacity));end
    local ok,err=xpcall(function()
        local path=Shapes.path(gc,o,w,h);
        if o.type=='text' or o.type=='artistic' or o.type=='toc' then gc:SetPen((o.strokeWidth or 0)>0 and Renderer.pen(colour(o.stroke or '#000000'),o.strokeWidth*P) or wx.wxTRANSPARENT_PEN);gc:SetBrush(wx.wxBrush(colour(o.fill or 'transparent')));gc:DrawRectangle(0,0,w,h);end
        if o.type=='text' or o.type=='artistic' then
            local root=TextFlow.root(editor.document,o);local fragments=editor.flowCache[root.id];
            if not fragments then fragments=TextFlow.layout(editor.document,root,context,editor.styles);editor.flowCache[root.id]=fragments;end
            local fragment=fragments[o.id];local runs=fragment and fragment.runs or Text.read(o);
            local result=Renderer.textBox(context,Renderer.nativeRuns(editor,o,runs),0,0,w,h,{align=o.align,lineSpacing=o.lineHeight or 1.2});
            editor.textLayouts[o.id]={lines=result.lines,runs=runs,start=fragment and fragment.start or 0,overflow=result.overflow};
            if not clean and result.overflow then gc:SetPen(Renderer.pen(wx.wxColour(230,80,70),1));gc:SetBrush(wx.wxTRANSPARENT_BRUSH);gc:DrawRectangle(w-10,h-10,9,9);end
        elseif o.type=='toc' then
            local root=TextFlow.root(editor.document,o);local fragments=editor.contentsCache[root.id];
            if not fragments then fragments=require('Manual.Contents').fragments(editor.document,TextFlow.chain(editor.document,root),context,editor.styles);editor.contentsCache[root.id]=fragments;end
            local fragment=fragments[o.id];gc:PushState();gc:Clip(0,0,w,h);
            for _,row in ipairs(fragment.rows) do
                local indent=(row.tier.indent or (row.entry.level-1)*4)*P;local y=row.y;
                for _,line in ipairs(row.lines) do local available=w-indent-(editor.document.contents.pageNumbers==false and 0 or 12*P);local x=indent+(row.tier.align=='center' and (available-line.width)/2 or row.tier.align=='right' and available-line.width or 0);for _,run in ipairs(line.runs) do Renderer.run(context,run.style,run.text,x,y);x=x+run.width;end;y=y+line.height;end
                local showNumbers=editor.document.contents.pageNumbers~=false;local nw=showNumbers and Renderer.measure(context,row.style,row.entry.number) or 0;if showNumbers then Renderer.run(context,row.style,row.entry.number,w-nw,row.y);end;
                local tw=Renderer.measure(context,row.style,row.entry.text);local left=indent+tw+5;local right=w-nw-5;
                if showNumbers and right>left and row.tier.leader~='none' then
                    gc:SetPen(Renderer.pen(colour(row.tier.colour or '#777777'),1,row.tier.leader=='line' and wx.wxPENSTYLE_SOLID or wx.wxPENSTYLE_DOT));gc:StrokeLine(left,row.y+row.height*.7,right,row.y+row.height*.7);
                end
            end;gc:PopState();editor.textLayouts[o.id]={overflow=fragment.overflow};
        elseif o.type=='table' then
            local cells=require('Manual.Tables').cells(o);local rows,columns=o.rows or 3,o.columns or 3;gc:SetPen(Renderer.pen(colour(o.stroke or '#888888'),math.max(1,math.floor((o.strokeWidth or .2)*P+.5))));gc:SetBrush(wx.wxBrush(colour(o.fill or '#ffffff')));gc:DrawRectangle(0,0,w,h);
            for r=1,rows do for c=1,columns do local x,y=(c-1)*w/columns,(r-1)*h/rows;gc:StrokeLine(x,0,x,h);gc:StrokeLine(0,y,w,y);Renderer.textBox(context,Renderer.nativeRuns(editor,o,Text.read(cells[r][c])),x+3,y+3,w/columns-6,h/rows-6,{lineSpacing=1.2});end end
        elseif o.type=='image' or o.type=='picture' or o.type=='picture-ellipse' then
            gc:PushState();
            if o.pdfClip then local clip=Shapes.svgPath(gc,o.pdfClip.path,w,h);Renderer.clip(context,o,clip,w,h,editor.clipCache);clip:delete();else Renderer.clip(context,o,path,w,h,editor.clipCache);end
            Renderer.image(context,editor,o,w,h);gc:PopState();
            if not clean and (not o.src or o.src=='') and #Layers.children(page,o.id)==0 then gc:SetPen(Renderer.pen(colour('#8899aa'),1));gc:SetBrush(wx.wxBrush(colour('#dce6ef')));gc:DrawPath(path,wx.wxODDEVEN_RULE);end
        else
            gc:SetPen((o.strokeWidth or 0)>0 and Renderer.pen(colour(o.stroke or '#000000'),math.max(1,math.floor(o.strokeWidth*P+.5))) or wx.wxTRANSPARENT_PEN);
            gc:SetBrush(wx.wxBrush(colour(o.fill or 'transparent')));gc:DrawPath(path,wx.wxODDEVEN_RULE);
        end
        local children=Layers.children(page,o.id);
        if #children>0 then
            gc:PushState(); if Shapes.clips(o) then Renderer.clip(context,o,path,w,h,editor.clipCache);end
            for _,child in ipairs(children) do Renderer.object(context,editor,page,child,clean);end;gc:PopState();
        end
        path:delete();
    end,debug.traceback);
    if layered then gc:EndLayer();end;gc:PopState();assert(ok,err);
end
function Renderer.page(context,editor,page,index,clean,phase)
    local gc=context.gc;local s=editor.document.settings;local P=Renderer.pixelsPerMM;local w,h=s.width*P,s.height*P;
    local edge=phase=='print-bleed' and s.bleed*P or 0;local master=require('Manual.MasterPages').get(editor.document,page);
    local function backgroundImage(source)
        if not source.backgroundImage or source.backgroundImage=='' then return;end;gc:PushState();gc:Clip(0,0,w,h);
        if source.backgroundMode=='tile' then local b=editor.images.get(source.backgroundImage);if b then for y=0,h,b:GetHeight() do for x=0,w,b:GetWidth() do gc:DrawBitmap(b,x,y,b:GetWidth(),b:GetHeight());end end end
        else Renderer.image(context,editor,{src=source.backgroundImage,fit=source.backgroundMode or 'cover'},w,h);end;gc:PopState();
    end
    if phase~='content' and phase~='spread-content' then
        local source=master and page.useMasterBackground~=false and master or page;gc:SetPen(wx.wxTRANSPARENT_PEN);gc:SetBrush(wx.wxBrush(colour(source.background or '#ffffff')));gc:DrawRectangle(-edge,-edge,w+2*edge,h+2*edge);backgroundImage(source);
        if phase=='background' then return;end
    end
    local function draw(o,owner)
        if o.parentId then return;end;gc:PushState();if not o.acrossSpread or phase~='spread-content' then gc:Clip(-edge,-edge,w+2*edge,h+2*edge);end;Renderer.object(context,editor,owner,o,clean);gc:PopState();
    end
    if index and s.facingPages and phase~='spread-content' then
        local pair=require('Manual.Spreads').indices(editor.document,index);
        if #pair==2 then local other=index==pair[1] and pair[2] or pair[1];local previous=editor.document.pages[other];for _,o in ipairs(previous.objects) do
            if o.acrossSpread and not o.parentId then gc:PushState();gc:Clip(0,0,w,h);gc:Translate(index==pair[1] and w or -w,0);Renderer.object(context,editor,previous,o,clean);gc:PopState();end
        end end
    end
    if master then for _,o in ipairs(master.objects) do draw(o,master);end end
    for _,o in ipairs(page.objects) do draw(o,page);end
    if s.pageNumbers and index then
        local number=require('Manual.Pages').number(editor.document,index);local style=editor.styles.resolve(s.numberStyle,editor.document.manualStyles,10);local width,height=Renderer.measure(context,style,number);
        local x=s.numberPosition=='left' and s.marginInner*P or s.numberPosition=='right' and w-s.marginOuter*P-width or (w-width)/2;Renderer.run(context,style,number,x,h-s.marginBottom*P+height/2);
    end
    if not clean then
        if s.gridVisible then gc:SetPen(Renderer.pen(colour('#92b5d0'),1));for x=0,w,s.gridX*P do gc:StrokeLine(x,0,x,h);end;for y=0,h,s.gridY*P do gc:StrokeLine(0,y,w,y);end;end
        local left,right=s.marginInner,s.marginOuter;if s.facingPages and index and index%2==0 then left,right=right,left;end
        gc:SetPen(Renderer.pen(colour('#dc6772'),1,wx.wxPENSTYLE_DOT));gc:SetBrush(wx.wxTRANSPARENT_BRUSH);gc:DrawRectangle(left*P,s.marginTop*P,w-(left+right)*P,h-(s.marginTop+s.marginBottom)*P);
        gc:SetPen(Renderer.pen(colour('#7297b4'),1,wx.wxPENSTYLE_DOT));gc:DrawRectangle(-s.bleed*P,-s.bleed*P,w+2*s.bleed*P,h+2*s.bleed*P);
    end
end
return Renderer;
