-- Native vector paths are shared by drawing, clipping and hit testing.
local wx=require('wx'); local Shapes={};
Shapes.catalog={{'rectangle','Rectangle'},{'rounded','Rounded Rectangle'},{'ellipse','Ellipse'},{'triangle','Triangle'},{'diamond','Diamond'},{'trapezoid','Trapezoid'},
    {'polygon','Polygon'},{'star','Star'},{'double-star','Double Star'},{'square-star','Square Star'},{'arrow','Arrow'},{'donut','Donut'},{'pie','Pie'},{'segment','Segment'},
    {'crescent','Crescent'},{'cog','Cog'},{'cloud','Cloud'},{'callout','Rounded Callout'},{'ellipse-callout','Ellipse Callout'},{'tear','Tear'},{'heart','Heart'},{'spiral','Spiral'}};
function Shapes.path(gc,o,w,h)
    local p=gc:CreatePath(); local kind=o.type; local function point(x,y) return x*w/100,y*h/100; end
    local function move(x,y) p:MoveToPoint(point(x,y)); end; local function line(x,y) p:AddLineToPoint(point(x,y)); end
    local function curve(a,b,c,d,e,f) p:AddCurveToPoint(a*w/100,b*h/100,c*w/100,d*h/100,e*w/100,f*h/100); end
    local function poly(points) for i,v in ipairs(points) do if i==1 then move(v[1],v[2]); else line(v[1],v[2]); end end; p:CloseSubpath(); end
    local function radial(count,inner)
        local a={}; for i=0,count-1 do local angle=-math.pi/2+i*math.pi*2/count; local r=i%2==1 and inner or 1; a[#a+1]={50+50*math.cos(angle)*r,50+50*math.sin(angle)*r}; end; poly(a);
    end
    if kind=='ellipse' or kind=='picture-ellipse' then p:AddEllipse(0,0,w,h);
    elseif kind=='rounded' then p:AddRoundedRectangle(0,0,w,h,math.min(w/2,h/2,(o.radius or 4)*96/25.4));
    elseif kind=='triangle' then poly({{50,0},{100,100},{0,100}});
    elseif kind=='diamond' then poly({{50,0},{100,50},{50,100},{0,50}});
    elseif kind=='trapezoid' then poly({{25,0},{75,0},{100,100},{0,100}});
    elseif kind=='polygon' then radial(math.max(3,o.sides or 5),1);
    elseif kind=='star' then radial(math.max(3,o.sides or 5)*2,(o.innerRadius or 45)/100);
    elseif kind=='double-star' then radial(math.max(3,o.sides or 5)*4,.6);
    elseif kind=='square-star' then radial(8,.45);
    elseif kind=='arrow' then poly({{0,30},{60,30},{60,0},{100,50},{60,100},{60,70},{0,70}});
    elseif kind=='donut' then p:AddEllipse(0,0,w,h); p:AddEllipse(w/4,h/4,w/2,h/2);
    elseif kind=='cog' then radial(32,.82);
    elseif kind=='pie' or kind=='segment' then
        if kind=='pie' then move(50,50); line(50,0); else move(0,50); end
        local first=kind=='pie' and -math.pi/2 or math.pi;
        local last=kind=='pie' and math.pi*2 or math.pi*2;
        for i=0,60 do local a=first+(last-first)*i/60; line(50+50*math.cos(a),50+50*math.sin(a)); end; p:CloseSubpath();
    elseif kind=='crescent' then move(75,0);curve(-15,0,-15,100,75,100);curve(20,75,20,25,75,0);p:CloseSubpath();
    elseif kind=='cloud' then move(20,85);curve(-10,85,-10,40,18,38);curve(15,0,65,-5,70,25);curve(100,10,115,70,87,85);p:CloseSubpath();
    elseif kind=='callout' then poly({{0,0},{100,0},{100,75},{45,75},{20,100},{25,75},{0,75}});
    elseif kind=='ellipse-callout' then move(25,72);curve(-20,55,0,0,50,0);curve(115,0,115,75,50,80);line(15,100);p:CloseSubpath();
    elseif kind=='tear' then move(50,0);curve(45,30,0,45,0,70);curve(0,110,100,110,100,70);curve(100,45,55,30,50,0);p:CloseSubpath();
    elseif kind=='heart' then move(50,100);curve(-20,50,-10,-15,50,20);curve(110,-15,120,50,50,100);p:CloseSubpath();
    elseif kind=='spiral' then for i=0,180 do local t=i/180; local a=t*math.pi*6; local x,y=50+math.cos(a)*t*48,50+math.sin(a)*t*48; if i==0 then move(x,y); else line(x,y); end end
    elseif kind=='line' then move(0,0);line(100,100);
    elseif kind=='curve' then
        local nodes=o.nodes or {{0,100},{50,0},{100,100}};
        if #nodes==3 and not o.closed then local a,b,c=nodes[1],nodes[2],nodes[3];move(a[1],a[2]);curve(a[1]+2*(b[1]-a[1])/3,a[2]+2*(b[2]-a[2])/3,c[1]+2*(b[1]-c[1])/3,c[2]+2*(b[2]-c[2])/3,c[1],c[2]);
        else for i,v in ipairs(nodes) do if i==1 then move(v[1],v[2]); else line(v[1],v[2]); end end;end;if o.closed then p:CloseSubpath();end
    else p:AddRectangle(0,0,w,h); end
    return p;
end
function Shapes.clips(o) return o.type~='line' and o.type~='spiral' and (o.type~='curve' or o.closed); end
function Shapes.region(path,w,h)
    local width,height=math.max(1,math.ceil(w)),math.max(1,math.ceil(h));
    local bitmap=wx.wxBitmap(width,height,24);local dc=wx.wxMemoryDC();dc:SelectObject(bitmap);dc:SetBackground(wx.wxBrush(wx.wxWHITE));dc:Clear();
    local gc=wx.wxGraphicsContext.Create(dc);gc:SetPen(wx.wxTRANSPARENT_PEN);gc:SetBrush(wx.wxBrush(wx.wxBLACK));gc:DrawPath(path,wx.wxODDEVEN_RULE);gc:delete();
    dc:SelectObject(wx.wxNullBitmap);dc:delete();local image=bitmap:ConvertToImage();local data=image:GetData();image:delete();bitmap:delete();
    local region=wx.wxRegion();
    for y=0,height-1 do local start;
        for x=0,width do local inside=x<width and data:byte((y*width+x)*3+1)<128;
            if inside and not start then start=x;elseif not inside and start then region:Union(start,y,x-start,1);start=nil;end
        end
    end;return region;
end
function Shapes.svgPath(gc,s,w,h)
    local p=gc:CreatePath();
    local i=1; local command; local x,y=0,0; local sx,sy=0,0;
    local function space() local _,b=s:find('^[%s,]*',i); i=(b or i-1)+1; end
    local function number() space(); local a,b=s:find('^[+-]?%d*%.?%d+[eE]?[+-]?%d*',i); assert(a,'Invalid image clipping path.'); i=b+1; return assert(tonumber(s:sub(a,b))); end
    while i<=#s do
        space(); if i>#s then break; end
        local c=s:sub(i,i); if c:match('%a') then command=c; i=i+1; end; assert(command,'Invalid clipping path.');
        local upper=command:upper(); local relative=command~=upper;
        local function xy() local a,b=number(),number(); if relative then a,b=a+x,b+y; end; return a,b; end
        if upper=='M' then x,y=xy();p:MoveToPoint(x*w,y*h);sx,sy=x,y;command=relative and 'l' or 'L';
        elseif upper=='L' then x,y=xy();p:AddLineToPoint(x*w,y*h);
        elseif upper=='C' then local a,b=xy();local c,d=xy();local e,f=xy();p:AddCurveToPoint(a*w,b*h,c*w,d*h,e*w,f*h);x,y=e,f;
        elseif upper=='Q' then local a,b=xy();local e,f=xy();p:AddCurveToPoint((x+2*(a-x)/3)*w,(y+2*(b-y)/3)*h,(e+2*(a-e)/3)*w,(f+2*(b-f)/3)*h,e*w,f*h);x,y=e,f;
        elseif upper=='H' then local a=number();x=relative and x+a or a;p:AddLineToPoint(x*w,y*h);
        elseif upper=='V' then local b=number();y=relative and y+b or b;p:AddLineToPoint(x*w,y*h);
        elseif upper=='Z' then p:CloseSubpath();x,y=sx,sy;command=nil;
        else error('Unsupported clipping command: '..upper); end
    end; return p;
end
function Shapes.svg(o)
    local commands={};local path={};local function add(s)commands[#commands+1]=s;end
    function path:MoveToPoint(x,y)add('M'..x..' '..y);end
    function path:AddLineToPoint(x,y)add('L'..x..' '..y);end
    function path:AddCurveToPoint(a,b,c,d,e,f)add('C'..a..' '..b..' '..c..' '..d..' '..e..' '..f);end
    function path:CloseSubpath()add('Z');end
    function path:AddRectangle(x,y,w,h)add('M'..x..' '..y..'h'..w..'v'..h..'h'..(-w)..'Z');end
    function path:AddEllipse(x,y,w,h)local rx,ry=w/2,h/2;add('M'..x..' '..(y+ry)..'a'..rx..' '..ry..' 0 1 0 '..w..' 0a'..rx..' '..ry..' 0 1 0 '..(-w)..' 0Z');end
    function path:AddRoundedRectangle(x,y,w,h,r)add('M'..(x+r)..' '..y..'H'..(x+w-r)..'a'..r..' '..r..' 0 0 1 '..r..' '..r..'V'..(y+h-r)..'a'..r..' '..r..' 0 0 1 '..(-r)..' '..r..'H'..(x+r)..'a'..r..' '..r..' 0 0 1 '..(-r)..' '..(-r)..'V'..(y+r)..'a'..r..' '..r..' 0 0 1 '..r..' '..(-r)..'Z');end
    local P=96/25.4;Shapes.path({CreatePath=function()return path;end},o,o.w*P,o.h*P);return table.concat(commands,' '),o.w*P,o.h*P;
end
function Shapes.strokeHit(o,x,y,tolerance)
    if o.type~='line' and o.type~='spiral' and (o.type~='curve' or o.closed) then return false;end
    local points={};if o.type=='line' then points={{0,0},{o.w,o.h}};
    elseif o.type=='spiral' then for i=0,180 do local t=i/180;local a=t*math.pi*6;points[#points+1]={(50+math.cos(a)*t*48)*o.w/100,(50+math.sin(a)*t*48)*o.h/100};end
    else local nodes=o.nodes or {};if #nodes==3 then for i=0,40 do local t=i/40;local a,b,c=nodes[1],nodes[2],nodes[3];points[#points+1]={((1-t)^2*a[1]+2*(1-t)*t*b[1]+t*t*c[1])*o.w/100,((1-t)^2*a[2]+2*(1-t)*t*b[2]+t*t*c[2])*o.h/100};end;else for _,v in ipairs(nodes) do points[#points+1]={v[1]*o.w/100,v[2]*o.h/100};end;end;end
    for i=2,#points do local a,b=points[i-1],points[i];local dx,dy=b[1]-a[1],b[2]-a[2];local length=dx*dx+dy*dy;local t=length>0 and math.max(0,math.min(1,((x-a[1])*dx+(y-a[2])*dy)/length)) or 0;if (x-a[1]-t*dx)^2+(y-a[2]-t*dy)^2<tolerance^2 then return true;end;end;return false;
end
return Shapes;
