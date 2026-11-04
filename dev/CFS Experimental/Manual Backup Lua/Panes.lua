-- Same page pairs, style buttons and nested layer rows as the preserved UI, drawn natively.
local wx=require('wx');local Themes=require('Manual.Themes');local Panes={};
local function trim(dc,text,width)local result=text;while dc:GetTextExtent(result)>width and utf8.len(result)>1 do result=result:sub(1,(utf8.offset(result,-1) or 1)-1);end;return result==text and result or result..'…';end
function Panes.create(parent,size,editor,kind,onSelect,onRename,onDrop)
    local view=Themes.role(wx.wxScrolledWindow(parent,wx.wxID_ANY,wx.wxDefaultPosition,size,wx.wxVSCROLL+(kind=='layers' and wx.wxBORDER_SIMPLE or wx.wxBORDER_NONE)),kind=='layers' and 'field' or 'panel');view:SetScrollRate(0,12);
    local pane={view=view,items={},selection=-1,buttons={},signature='',kind=kind,limit=size:GetHeight()};local dragging;
    function pane:Clear()self.items={};end
    function pane:Append(label,detail,depth,id)self.items[#self.items+1]={label=label,detail=detail,depth=depth or 0,id=id};end
    function pane:GetSelection()return self.selection;end
    function pane:GetCount()return #self.items;end
    function pane:SetSelection(index)self.selection=index;end
    function pane:Flush()
        local keys={editor.theme,tostring(editor.uiSize),tostring(editor.document.settings.facingPages),tostring(editor.document.settings.firstPageAlone)};
        for _,item in ipairs(self.items)do keys[#keys+1]=item.label..'|'..(item.detail or '')..'|'..item.depth..'|'..(item.id or '');end;local signature=table.concat(keys,'\n');
        if signature~=self.signature then
            self.signature=signature;local _,scroll=view:GetViewStart();view:Freeze();view:DestroyChildren();self.buttons={};local outer=wx.wxBoxSizer(wx.wxVERTICAL);view:SetSizer(outer);local row;local rows=0;
            for i,item in ipairs(self.items)do
                local paired=kind=='pages' and editor.document.settings.facingPages;local first=editor.document.settings.firstPageAlone and 2 or 1;
                if not paired or i<first or (i-first)%2==0 then row=wx.wxBoxSizer(wx.wxHORIZONTAL);outer:Add(row,0,wx.wxEXPAND+wx.wxBOTTOM,3);rows=rows+1;end
                local card=wx.wxPanel(view,wx.wxID_ANY,wx.wxDefaultPosition,wx.wxSize(-1,kind=='layers' and 44 or 29),wx.wxBORDER_NONE);card:SetMinSize(wx.wxSize(paired and 60 or 130,kind=='layers' and 44 or 29));card:SetToolTip(item.label);row:Add(card,1,wx.wxEXPAND);self.buttons[i]=card;local hover=false;
                card:Connect(wx.wxEVT_PAINT,function()
                    local dc=wx.wxPaintDC(card);local gc=wx.wxGraphicsContext.Create(dc);local p=Themes.palettes[editor.theme];local size=card:GetClientSize();local w,h=size:GetWidth(),size:GetHeight();local selected=(kind=='pages' or kind=='masters' or kind=='layers') and i-1==self.selection;local fill=selected and p.active or hover and p.hover or p.field;local brush=wx.wxBrush(Themes.colour(fill));local pen=wx.wxPen(Themes.colour((kind=='layers' or kind=='context') and fill or p.border),1,wx.wxPENSTYLE_SOLID);dc:SetBackground(wx.wxBrush(Themes.colour(kind=='layers' and p.field or p.panel)));dc:Clear();gc:SetBrush(brush);gc:SetPen(pen);gc:DrawRoundedRectangle(.5,.5,w-1,h-1,4);
                    local font=wx.wxFont(editor.uiSize or 9,wx.wxFONTFAMILY_DEFAULT,wx.wxFONTSTYLE_NORMAL,wx.wxFONTWEIGHT_NORMAL,false,'Segoe UI');dc:SetFont(font);dc:SetTextForeground(Themes.colour(p.text));local indent=kind=='layers' and item.depth*14 or 0;local label=(item.depth>0 and '↳ ' or '')..item.label;dc:DrawText(trim(dc,label,math.max(20,w-indent-(kind=='layers' and 51 or 14))),(kind=='shapes' and 31 or 7)+indent,kind=='layers' and 5 or 6);
                    if item.detail then local small=wx.wxFont(math.max(7,(editor.uiSize or 9)-1),wx.wxFONTFAMILY_DEFAULT,wx.wxFONTSTYLE_NORMAL,wx.wxFONTWEIGHT_NORMAL,false,'Segoe UI');dc:SetFont(small);dc:SetTextForeground(Themes.colour(p.muted));dc:DrawText(item.detail,7+indent,24);small:delete();end
                    if kind=='shapes' then gc:PushState();gc:Translate(5,4);gc:SetPen(wx.wxPen(Themes.colour(p.text),1,wx.wxPENSTYLE_SOLID));gc:SetBrush(wx.wxTRANSPARENT_BRUSH);local path=require('Manual.Shapes').path(gc,{type=item.id,radius=1,sides=5,innerRadius=45},20,20);gc:StrokePath(path);path:delete();gc:PopState();end
                    if kind=='layers' then local o=require('Manual.Document').find(editor.document,item.id);if o then gc:SetPen(wx.wxPen(Themes.colour(p.text),1,wx.wxPENSTYLE_SOLID));gc:SetBrush(wx.wxBrush(Themes.colour(o.visible~=false and p.text or p.field)));gc:DrawEllipse(w-44,19,5,5);gc:PushState();gc:Translate(w-22,12);gc:SetBrush(wx.wxTRANSPARENT_BRUSH);gc:DrawRoundedRectangle(3,8,10,9,1);local path=gc:CreatePath();path:MoveToPoint(5,8);path:AddLineToPoint(5,4);path:AddCurveToPoint(5,-1,12,-1,12,4);if o.locked then path:AddLineToPoint(12,8);end;gc:StrokePath(path);path:delete();gc:PopState();end;end
                    font:delete();gc:delete();pen:delete();brush:delete();dc:delete();
                end);
                card:Connect(wx.wxEVT_ENTER_WINDOW,function(event)hover=true;card:Refresh();event:Skip();end);card:Connect(wx.wxEVT_LEAVE_WINDOW,function(event)hover=false;card:Refresh();event:Skip();end);
                card:Connect(wx.wxEVT_LEFT_DOWN,function(event)
                    if kind=='layers' and event:GetX()>card:GetClientSize():GetWidth()-50 then local o=require('Manual.Document').find(editor.document,item.id);if o then editor.change(function()if event:GetX()>card:GetClientSize():GetWidth()-26 then o.locked=not o.locked;else o.visible=o.visible==false;end;end,o);end;return;end
                    dragging=i;self.dragging=i;self.selection=i-1;onSelect(i);event:Skip();
                end);
                card:Connect(wx.wxEVT_LEFT_UP,function(event)if onDrop and dragging and dragging~=i then onDrop(dragging,i);end;dragging=nil;self.dragging=nil;event:Skip();end);
                card:Connect(wx.wxEVT_LEFT_DCLICK,function(event)if onRename then onRename(i,card);end;event:Skip();end);
                card:Connect(wx.wxEVT_RIGHT_UP,function()if kind=='layers' then local o=require('Manual.Document').find(editor.document,item.id);if o then editor.select(o);editor.contextMenu(card,o);end;end;end);
            end
            view:SetMinSize(wx.wxSize(size:GetWidth(),math.min(self.limit,rows*(kind=='layers' and 47 or 32))));view:Show(#self.items>0);Themes.apply(view,editor.theme);view:Layout();view:FitInside();view:Scroll(0,scroll);view:Thaw();
        end
        for _,card in ipairs(self.buttons)do card:Refresh();end
    end
    return pane;
end
return Panes;
