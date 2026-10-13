-- Portable RGB raster PDF export through the same native page renderer.
-- It preserves physical geometry and bleed; this is not a CMYK or searchable-text PDF.
local wx=require('wx');local Renderer=require('Manual.Renderer');local PDF={};
function PDF.write(editor,path,dpi,bleed)
    assert(dpi>=72 and dpi<=600,'PDF resolution must be between 72 and 600 DPI.');local s=editor.document.settings;local edge=bleed and s.bleed or 0;local widthMM,heightMM=s.width+2*edge,s.height+2*edge;local width,height=math.ceil(widthMM*dpi/25.4),math.ceil(heightMM*dpi/25.4);
    local file=assert(io.open(path,'wb'));local offsets={};local nextId=3;local pages={};
    local function object(id,body)offsets[id]=file:seek();assert(file:write(id..' 0 obj\n'..body..'\nendobj\n'));end
    local function stream(id,dict,data)object(id,dict..' /Length '..#data..' >>\nstream\n'..data..'\nendstream');end
    file:write('%PDF-1.4\n%\226\227\207\211\n');
    local ok,err=xpcall(function()
        for index,page in ipairs(editor.document.pages) do
            local bitmap=wx.wxBitmap(width,height,24);local dc=wx.wxMemoryDC();dc:SelectObject(bitmap);dc:SetBackground(wx.wxBrush(wx.wxWHITE));dc:Clear();local gc=wx.wxGraphicsContext.Create(dc);gc:Scale(dpi/96,dpi/96);gc:Translate(edge*Renderer.pixelsPerMM,edge*Renderer.pixelsPerMM);local context=Renderer.context(gc,dc);context.fonts=editor.fonts;Renderer.page(context,editor,page,index,true,bleed and 'print-bleed' or nil);gc:delete();dc:SelectObject(wx.wxNullBitmap);dc:delete();
            local tempFile=wx.wxFile();local temp=wx.wxFileName.CreateTempFileName('cfs-native-pdf-',tempFile);tempFile:Close();tempFile:delete();assert(bitmap:SaveFile(temp,wx.wxBITMAP_TYPE_PNG));bitmap:delete();local pngFile=assert(io.open(temp,'rb'));local png=pngFile:read('a');pngFile:close();wx.wxRemoveFile(temp);
            local chunks={};local at=9;while at<=#png do local len=string.unpack('>I4',png,at);local kind=png:sub(at+4,at+7);local data=png:sub(at+8,at+7+len);if kind=='IHDR' then assert(data:byte(9)==8 and data:byte(10)==2,'Native PNG is not 8-bit RGB.');elseif kind=='IDAT' then chunks[#chunks+1]=data;end;at=at+len+12;end
            local pageId,imageId,contentId=nextId,nextId+1,nextId+2;nextId=nextId+3;pages[#pages+1]=pageId..' 0 R';local wp,hp=widthMM*72/25.4,heightMM*72/25.4;local bp=edge*72/25.4;
            stream(imageId,'<< /Type /XObject /Subtype /Image /Width '..width..' /Height '..height..' /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode /DecodeParms << /Predictor 15 /Colors 3 /BitsPerComponent 8 /Columns '..width..' >>',table.concat(chunks));
            local content=string.format('q %.6f 0 0 %.6f 0 0 cm /Im0 Do Q',wp,hp);stream(contentId,'<<',content);
            object(pageId,string.format('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %.6f %.6f] /TrimBox [%.6f %.6f %.6f %.6f] /BleedBox [0 0 %.6f %.6f] /Resources << /XObject << /Im0 %d 0 R >> >> /Contents %d 0 R >>',wp,hp,bp,bp,wp-bp,hp-bp,wp,hp,imageId,contentId));
            if editor.onExportProgress then editor.onExportProgress(index,#editor.document.pages);end
        end
        object(1,'<< /Type /Catalog /Pages 2 0 R >>');object(2,'<< /Type /Pages /Count '..#pages..' /Kids ['..table.concat(pages,' ')..'] >>');local start=file:seek();file:write('xref\n0 '..nextId..'\n0000000000 65535 f \n');for id=1,nextId-1 do file:write(string.format('%010d 00000 n \n',assert(offsets[id])));end;file:write('trailer\n<< /Size '..nextId..' /Root 1 0 R >>\nstartxref\n'..start..'\n%%EOF\n');
    end,debug.traceback);file:close();assert(ok,err);return true;
end
return PDF;
