-- Native page canvas: selection, live text, gestures and zoom share one renderer.
local wx=require('wx');local Renderer=require('Manual.Renderer');local Layers=require('Manual.Layers');local Shapes=require('Manual.Shapes');local Text=require('Manual.Text');local Document=require('Manual.Document');local Spreads=require('Manual.Spreads');local Themes=require('Manual.Themes');local Canvas={};
function Canvas.create(parent,editor,clean)
    local view=wx.wxScrolledWindow(parent,wx.wxID_ANY,wx.wxDefaultPosition,wx.wxDefaultSize,wx.wxHSCROLL+wx.wxVSCROLL+wx.wxBORDER_NONE);view:SetScrollRate(1,1);view:SetBackgroundStyle(wx.wxBG_STYLE_PAINT);
    local canvas={view=view,zoomValue=70,clean=clean};local drag;local P=Renderer.pixelsPerMM;local scaleSlider;
    if not clean then scaleSlider=wx.wxSlider(view,wx.wxID_ANY,100,10,400,wx.wxDefaultPosition,wx.wxSize(110,24),wx.wxSL_HORIZONTAL);canvas.scaleSlider=scaleSlider;scaleSlider:SetToolTip('Scale selected embedded layer, preserving its center');scaleSlider:Hide();end
    local function indices() if editor.master then return {editor.master};end;return Spreads.indices(editor.document,editor.pageIndex);end
    function canvas.metrics()
        local size=view:GetClientSize();local s=editor.document.settings;local z=canvas.zoomValue/100;local list=indices();local width=s.width*P*z*#list;local height=s.height*P*z;
        return {z=z,width=width,height=height,x=math.max(24,(size:GetWidth()-width)/2),y=math.max(24,(size:GetHeight()-height)/2),indices=list};
    end
    function canvas.refresh()
        local m=canvas.metrics();view:SetVirtualSize(wx.wxSize(math.ceil(m.width+48),math.ceil(m.height+48)));view:Refresh(false);
        if scaleSlider then
            local o=editor.selected();if o and o.parentId and not Layers.locked(editor.document,o) and not editor.textObject and not (editor.editingObject and o and o.id==editor.editingObject) then
                local x,y=Layers.worldPoint(editor.document,o,o.w/2,o.h/2);local offset=editor.master and 0 or Spreads.offset(editor.document,editor.pageIndex,editor.ownerIndex(o));
                local sx,sy=view:GetViewStart();scaleSlider:SetPosition(wx.wxPoint(math.floor(m.x+((offset or 0)+x)*P*m.z-sx-55),math.floor(m.y+y*P*m.z-sy-12)));scaleSlider:Show();
            else scaleSlider:Hide();end
        end
    end
    function canvas.zoom(value,center,anchor)
        local old=canvas.metrics();local sx,sy=view:GetViewStart();local ax,ay=anchor and anchor.x or 0,anchor and anchor.y or 0;local px,py=(ax+sx-old.x)/old.z,(ay+sy-old.y)/old.z;
        canvas.zoomValue=math.floor(math.max(10,math.min(400,value)));canvas.refresh();local m=canvas.metrics();
        if anchor then view:Scroll(math.max(0,math.floor(m.x+px*m.z-ax)),math.max(0,math.floor(m.y+py*m.z-ay)));
        elseif center then local size=view:GetClientSize();view:Scroll(math.max(0,math.floor((m.width+48-size:GetWidth())/2)),math.max(0,math.floor((m.height+48-size:GetHeight())/2)));end
        if editor.zoomChanged then editor.zoomChanged(canvas.zoomValue);end
    end
    function canvas.fit()
        local s=editor.document.settings;local size=view:GetClientSize();canvas.zoom(math.floor(math.min((size:GetWidth()-48)/(s.width*P*#indices()),(size:GetHeight()-48)/(s.height*P))*100),true);
    end
    local function point(event)
        local m=canvas.metrics();local sx,sy=view:GetViewStart();return (event:GetX()+sx-m.x)/(P*m.z),(event:GetY()+sy-m.y)/(P*m.z),m;
    end
    local function temporaryContext(callback)
        local b=wx.wxBitmap(2,2,32);local dc=wx.wxMemoryDC();dc:SelectObject(b);local gc=wx.wxGraphicsContext.Create(dc);local context=Renderer.context(gc,dc);local result={callback(context)};gc:delete();dc:SelectObject(wx.wxNullBitmap);dc:delete();b:delete();return table.unpack(result);
    end
    local function pageOffset(o)
        return editor.master and 0 or Spreads.offset(editor.document,editor.pageIndex,editor.ownerIndex(o));
    end
    local function inside(o,x,y,context)
        local offset=pageOffset(o);if offset==nil then return false;end;local a,b=Layers.localPoint(editor.document,o,x-offset,y);
        if a<0 or b<0 or a>o.w or b>o.h then return false;end
        local p=Shapes.path(context.gc,o,o.w*P,o.h*P);local yes=Shapes.strokeHit(o,a,b,2/canvas.metrics().z) or p:Contains(a*P,b*P,wx.wxODDEVEN_RULE);p:delete();
        local parent=o.parentId and Document.find(editor.document,o.parentId);if yes and parent then yes=inside(parent,x,y,context);end;return yes;
    end
    function canvas.hit(x,y,prefer)
        return temporaryContext(function(context)
            local selected=editor.selected();if prefer and selected and inside(selected,x,y,context) then return selected;end
            local list=indices();for pi=#list,1,-1 do local page=rawtype(list[pi])=='table' and list[pi] or editor.document.pages[list[pi]];
                for i=#page.objects,1,-1 do local o=page.objects[i];if o.visible~=false and inside(o,x,y,context) then return o;end end
            end
        end);
    end
    local function textGeometry(o)
        local layout=editor.textLayouts[o.id];if not layout then return;end
        local lines={};local position=layout.start or 0;local full=Text.plain(layout.runs or {});local localPosition=0;
        for _,line in ipairs(layout.lines or {}) do
            local copy={runs=line.runs,width=line.width,height=line.height,start=position,list=line.list,align=line.align};local count=0;for _,r in ipairs(line.runs) do count=count+Text.len(r.text);end
            position=position+count;localPosition=localPosition+count;copy.finish=position;lines[#lines+1]=copy;
            if Text.substring(full,localPosition,localPosition+1)=='\n' then position=position+1;localPosition=localPosition+1;end
        end;return lines;
    end
    function canvas.textPoint(o,x,y)
        return temporaryContext(function(context)
            local offset=pageOffset(o) or 0;local lx,ly=Layers.localPoint(editor.document,o,x-offset,y);lx,ly=lx*P,ly*P;local lines=textGeometry(o) or {};local top=0;
            for _,line in ipairs(lines) do
                if ly<=top+line.height or line==lines[#lines] then
                    local left=o.align=='center' and (o.w*P-line.width)/2 or o.align=='right' and o.w*P-line.width or (line.list and 20 or 0);local pos=line.start;
                    for _,r in ipairs(line.runs) do
                        if lx<=left+r.width then local n=Text.len(r.text);local low,high=0,n;
                            while low<high do local mid=math.floor((low+high)/2);local width=Renderer.measure(context,r.style,Text.substring(r.text,0,mid));if left+width<lx then low=mid+1;else high=mid;end end
                            return pos+low;
                        end;left=left+r.width;pos=pos+Text.len(r.text);
                    end;return line.finish;
                end;top=top+line.height;
            end;return 0;
        end);
    end
    local function selection(context,o)
        local gc=context.gc;local offset=pageOffset(o) or 0;gc:PushState();gc:Translate(offset*P,0);local chain={};local current=o;while current do table.insert(chain,1,current);current=current.parentId and Document.find(editor.document,current.parentId);end;for _,v in ipairs(chain) do gc:Translate((v.x+v.w/2)*P,(v.y+v.h/2)*P);gc:Rotate(math.rad(v.rotation or 0));gc:Translate(-v.w*P/2,-v.h*P/2);end;
        gc:SetPen(Renderer.pen(Themes.colour('#55b8ff'),1));gc:SetBrush(wx.wxTRANSPARENT_BRUSH);gc:DrawRectangle(0,0,o.w*P,o.h*P);
        if editor.textObject==o then
            local lines=textGeometry(o) or {};local top=0;local a,b=math.min(editor.caret,editor.anchor),math.max(editor.caret,editor.anchor);
            for _,line in ipairs(lines) do
                local left=o.align=='center' and (o.w*P-line.width)/2 or o.align=='right' and o.w*P-line.width or (line.list and 20 or 0);local pos=line.start;
                for _,r in ipairs(line.runs) do
                    local n=Text.len(r.text);local sa,sb=math.max(0,a-pos),math.min(n,b-pos);
                    if sb>sa then local start=Renderer.measure(context,r.style,Text.substring(r.text,0,sa));local width=Renderer.measure(context,r.style,Text.substring(r.text,sa,sb));gc:SetBrush(wx.wxBrush(wx.wxColour(70,145,220,70)));gc:DrawRectangle(left+start,top,width,line.height);end
                    if editor.caret>=pos and editor.caret<=pos+n then local cx=left+Renderer.measure(context,r.style,Text.substring(r.text,0,editor.caret-pos));gc:StrokeLine(cx,top,cx,top+line.height);end
                    left=left+r.width;pos=pos+n;
                end;top=top+line.height;
            end
        else
            gc:SetBrush(wx.wxBrush(Themes.colour('#55b8ff')));local handle=6/canvas.metrics().z;
            for _,v in ipairs({{0,0},{o.w*P,0},{o.w*P,o.h*P},{0,o.h*P}}) do gc:DrawRectangle(v[1]-handle/2,v[2]-handle/2,handle,handle);end
            gc:StrokeLine(o.w*P/2,0,o.w*P/2,-18/canvas.metrics().z);gc:DrawEllipse(o.w*P/2-3/canvas.metrics().z,-21/canvas.metrics().z,6/canvas.metrics().z,6/canvas.metrics().z);
            if editor.tool=='node' and o.nodes then for _,v in ipairs(o.nodes) do gc:DrawEllipse(v[1]*o.w*P/100-3,v[2]*o.h*P/100-3,6,6);end;end
            if o.type=='text' or o.type=='artistic' or o.type=='toc' then gc:DrawRectangle(o.w*P-10/canvas.metrics().z,o.h*P/2,10/canvas.metrics().z,10/canvas.metrics().z);end
        end;gc:PopState();
    end
    view:Connect(wx.wxEVT_PAINT,function()
        local dc=wx.wxPaintDC(view);dc:SetBackground(wx.wxBrush(Themes.colour(Themes.palettes[editor.theme].canvas)));dc:Clear();view:PrepareDC(dc);local gc=wx.wxGraphicsContext.Create(dc);local context=Renderer.context(gc,dc);context.fonts=editor.fonts;
        local ok,err=xpcall(function()
            if editor.closed then return;end;local m=canvas.metrics();gc:Translate(m.x,m.y);gc:Scale(m.z,m.z);
            for _,phase in ipairs({'background','spread-content'}) do for i,n in ipairs(m.indices) do local page=rawtype(n)=='table' and n or editor.document.pages[n];gc:PushState();gc:Translate((i-1)*editor.document.settings.width*P,0);Renderer.page(context,editor,page,rawtype(n)=='number' and n or nil,clean,phase);gc:PopState();end;end
            local o=not clean and editor.selected();if o then selection(context,o);end
        end,debug.traceback);gc:delete();dc:delete();if not ok then editor.report(err);end
    end);
    view:Connect(wx.wxEVT_SIZE,function(event)canvas.refresh();event:Skip();end);
    view:Connect(wx.wxEVT_MOUSEWHEEL,function(event)
        if event:ControlDown() then local step=editor.document.settings.zoomStep;canvas.zoom(canvas.zoomValue+(event:GetWheelRotation()>0 and step or -step),false,{x=event:GetX(),y=event:GetY()});
        elseif event:AltDown() then editor.interfaceScale(event:GetWheelRotation()>0 and 1 or -1);
        elseif event:ShiftDown() then local x,y=view:GetViewStart();view:Scroll(math.max(0,x-(event:GetWheelRotation()>0 and 50 or -50)),y);
        else event:Skip();end
    end);
    if not clean then
        view:Connect(wx.wxEVT_LEFT_DOWN,function(event)
            view:SetFocus();local x,y=point(event);local o=canvas.hit(x,y,true);local selected=editor.selected();if selected then local lx,ly=Layers.localPoint(editor.document,selected,x-(pageOffset(selected) or 0),y);local tolerance=3/canvas.metrics().z;if math.abs(lx-selected.w/2)<tolerance and math.abs(ly+18/(P*canvas.metrics().z))<tolerance then o=selected;elseif editor.tool=='node' and selected.nodes then for _,node in ipairs(selected.nodes) do if math.abs(lx-node[1]*selected.w/100)<tolerance and math.abs(ly-node[2]*selected.h/100)<tolerance then o=selected;break;end;end;end;end
            if editor.linking then if o then editor.linkTarget(o);end;return;end
            if editor.tool~='move' and editor.tool~='node' and not editor.textObject and not (editor.editingObject and o and o.id==editor.editingObject) then
                local page=editor.page();local offset=editor.master and 0 or Spreads.offset(editor.document,editor.pageIndex,editor.pageIndex) or 0;
                local before=editor.history.begin();o=editor.newObject(editor.tool,x-offset,y);page.objects[#page.objects+1]=o;editor.select(o);drag={kind='create',o=o,startX=x,startY=y,before=before,base=Document.copy(o)};
            elseif o then
                if editor.textObject==o then editor.caret=canvas.textPoint(o,x,y);if not event:ShiftDown() then editor.anchor=editor.caret;end;drag={kind='text',o=o};canvas.refresh();return;end
                editor.select(o);if Layers.locked(editor.document,o) then return;end
                local lx,ly=Layers.localPoint(editor.document,o,x-(pageOffset(o) or 0),y);local tolerance=3/canvas.metrics().z;local kind='move';local handle;
                for _,v in ipairs({{0,0,'nw'},{o.w,0,'ne'},{o.w,o.h,'se'},{0,o.h,'sw'}}) do if math.abs(lx-v[1])<tolerance and math.abs(ly-v[2])<tolerance then kind='resize';handle=v[3];end end
                if math.abs(lx-o.w/2)<tolerance and math.abs(ly+18/(P*canvas.metrics().z))<tolerance then kind='rotate';end
                if editor.tool=='node' and o.nodes then for i,v in ipairs(o.nodes) do if math.abs(lx-v[1]*o.w/100)<tolerance and math.abs(ly-v[2]*o.h/100)<tolerance then kind='node';handle=i;break;end end end
                if (o.type=='text' or o.type=='artistic' or o.type=='toc') and math.abs(lx-o.w)<tolerance and math.abs(ly-o.h/2)<tolerance then editor.linking=o;editor.status('Click the next text or contents frame.');return;end
                drag={kind=kind,handle=handle,o=o,startX=x,startY=y,base=Document.copy(o),before=editor.history.begin(o)};
            else editor.select(nil);end
            if drag and not view:HasCapture() then view:CaptureMouse();end
        end);
        view:Connect(wx.wxEVT_MOTION,function(event)
            local x,y=point(event);
            if drag and event:LeftIsDown() then
                if drag.kind=='text' then editor.caret=canvas.textPoint(drag.o,x,y);canvas.refresh();return;end
                local o,b=drag.o,drag.base;local dx,dy=x-drag.startX,y-drag.startY;
                if o.parentId then local parent=Document.find(editor.document,o.parentId);local a,bx=Layers.localPoint(editor.document,parent,x-(pageOffset(o) or 0),y);local c,d=Layers.localPoint(editor.document,parent,drag.startX-(pageOffset(o) or 0),drag.startY);dx,dy=a-c,bx-d;end
                if drag.kind=='move' then o.x,o.y=require('Manual.Snapping').move(editor.document,editor.page(),o,b.x+dx,b.y+dy,event:AltDown());
                elseif drag.kind=='create' then o.x=b.x+math.min(0,dx);o.y=b.y+math.min(0,dy);o.w=math.max(1,math.abs(dx));o.h=math.max(1,math.abs(dy));if event:ShiftDown() then o.h=o.w;end
                elseif drag.kind=='resize' then
                    local signX=drag.handle:find('w') and -1 or 1;local signY=drag.handle:find('n') and -1 or 1;local mult=event:ControlDown() and 2 or 1;local w,h=math.max(1,b.w+dx*signX*mult),math.max(1,b.h+dy*signY*mult);
                    if event:ShiftDown() then local ratio=math.abs(w/b.w-1)>math.abs(h/b.h-1) and w/b.w or h/b.h;w,h=b.w*ratio,b.h*ratio;end
                    o.w,o.h=w,h;o.x=event:ControlDown() and b.x+(b.w-w)/2 or signX==-1 and b.x+b.w-w or b.x;o.y=event:ControlDown() and b.y+(b.h-h)/2 or signY==-1 and b.y+b.h-h or b.y;
                elseif drag.kind=='rotate' then local cx,cy=Layers.worldPoint(editor.document,o,o.w/2,o.h/2);local parent=o.parentId and Document.find(editor.document,o.parentId);o.rotation=math.deg(math.atan(y-cy,x-(pageOffset(o) or 0)-cx))+90-(parent and Layers.angle(editor.document,parent) or 0);if event:ShiftDown() then o.rotation=math.floor(o.rotation/15+.5)*15;end
                elseif drag.kind=='node' then local lx,ly=Layers.localPoint(editor.document,o,x-(pageOffset(o) or 0),y);o.nodes[drag.handle]={lx/o.w*100,ly/o.h*100};end
                editor.invalidate();canvas.refresh();if editor.preview then editor.preview.refresh();end
            else view:SetCursor(wx.wxCursor(editor.textObject and wx.wxCURSOR_IBEAM or editor.tool=='move' and wx.wxCURSOR_ARROW or wx.wxCURSOR_CROSS));end
        end);
        view:Connect(wx.wxEVT_LEFT_UP,function()
            if view:HasCapture() then view:ReleaseMouse();end
            if drag and drag.before then editor.history.commit(drag.before);end;drag=nil;canvas.refresh();
        end);
        view:Connect(wx.wxEVT_MOUSE_CAPTURE_LOST,function()if drag and drag.before then editor.history.commit(drag.before);end;drag=nil;end);
        view:Connect(wx.wxEVT_LEFT_DCLICK,function(event)local x,y=point(event);local o=canvas.hit(x,y,true);if o then editor.editObject(o,x,y);end;end);
        view:Connect(wx.wxEVT_RIGHT_UP,function(event)local x,y=point(event);local o=canvas.hit(x,y,true);if o then editor.select(o);editor.contextMenu(view,o);end;end);
        view:Connect(wx.wxEVT_KEY_DOWN,function(event)if not editor.key(event) then event:Skip();end;end);
        view:Connect(wx.wxEVT_CHAR,function(event)local code=event:GetUnicodeKey();if editor.textObject and not event:ControlDown() and code and code>=32 and code<=0x10ffff then editor.insert(utf8.char(code));else event:Skip();end;end);
        local scaleBefore,scaleBase;
        scaleSlider:Connect(wx.wxEVT_SCROLL_THUMBTRACK,function()
            local o=editor.selected();if not o then return;end;if not scaleBefore then scaleBefore=editor.history.begin(o);scaleBase=Document.copy(o);end
            local factor=scaleSlider:GetValue()/100;o.w=math.max(1,scaleBase.w*factor);o.h=math.max(1,scaleBase.h*factor);o.x=scaleBase.x+(scaleBase.w-o.w)/2;o.y=scaleBase.y+(scaleBase.h-o.h)/2;editor.invalidate();canvas.refresh();
        end);
        scaleSlider:Connect(wx.wxEVT_SCROLL_CHANGED,function()if scaleBefore then editor.history.commit(scaleBefore);scaleBefore=nil;scaleBase=nil;scaleSlider:SetValue(100);end;end);
    end
    canvas.refresh();return canvas;
end
return Canvas;
