-- Local copied assets are resolved relative to the game's manual folder.
local wx=require('wx'); local Images={};
function Images.create(root)
    local cache={};local tick,total=0,0;local images={};
    function images.get(src,hue)
        local path=src:match('^[A-Za-z]:') and src or root..'/'..src; local key=path..':'..(hue or 0);
        tick=tick+1;if cache[key] then cache[key].tick=tick;return cache[key].bitmap;end
        local image=wx.wxImage(path); if not image:IsOk() then image:delete(); return nil; end
        if hue and hue~=0 then
            local angle=math.rad(hue); local c,s=math.cos(angle),math.sin(angle);
            for y=0,image:GetHeight()-1 do for x=0,image:GetWidth()-1 do
                local r,g,b=image:GetRed(x,y),image:GetGreen(x,y),image:GetBlue(x,y);
                local function byte(v) return math.floor(math.max(0,math.min(255,v))+.5); end
                image:SetRGB(x,y,byte((.213+.787*c-.213*s)*r+(.715-.715*c-.715*s)*g+(.072-.072*c+.928*s)*b),
                    byte((.213-.213*c+.143*s)*r+(.715+.285*c+.140*s)*g+(.072-.072*c-.283*s)*b),
                    byte((.213-.213*c-.787*s)*r+(.715-.715*c+.715*s)*g+(.072+.928*c+.072*s)*b));
            end end
        end
        local bitmap=wx.wxBitmap(image); image:delete(); cache[key]={bitmap=bitmap,tick=tick,bytes=bitmap:GetWidth()*bitmap:GetHeight()*4};total=total+cache[key].bytes;
        while total>64*1024*1024 do local oldest;for name,item in pairs(cache) do if name~=key and (not oldest or item.tick<cache[oldest].tick) then oldest=name;end;end;if not oldest then break;end;total=total-cache[oldest].bytes;cache[oldest].bitmap:delete();cache[oldest]=nil;end;return bitmap;
    end
    function images.choose(parent)
        local dialog=wx.wxFileDialog(parent,'Copy image into manual', '', '', 'Images|*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.tif;*.tiff',wx.wxFD_OPEN+wx.wxFD_FILE_MUST_EXIST);
        local path; if dialog:ShowModal()==wx.wxID_OK then path=dialog:GetPath(); end; dialog:Destroy(); if not path then return; end
        local file=wx.wxFileName(path); local name=file:GetFullName();file:delete();
        local directory=root..'/Images'; assert(wx.wxDirExists(directory) or wx.wxFileName.Mkdir(directory,511,wx.wxPATH_MKDIR_FULL),'Cannot create asset folder.');
        local target=directory..'/'..name; local i=1;
        while wx.wxFileExists(target) do target=directory..'/'..i..'-'..name;i=i+1;end
        assert(wx.wxCopyFile(path,target,false),'Cannot copy image.');return 'Images/'..target:match('[^/]+$');
    end
    function images.close() for _,item in pairs(cache) do item.bitmap:delete();end;cache={};total=0;end
    return images;
end
return Images;
