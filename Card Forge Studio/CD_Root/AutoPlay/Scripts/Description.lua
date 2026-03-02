local _bHasInit         = false;
local _sDescription     = "";
local _pTempFile        = "";
local _hLiteXT          = -1;


return class("Description",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --Description = function(this, sAuthCode) end, --static constructor (runs after class object creation)\
        EditOLD = function()
            --write a temp file with the current content
            local sFile = string.uuid().."_tmp.lua";
            _pTempFile = _TempFolder.."\\"..sFile;
            TextFile.WriteFromString(_pTempFile, base64.dec(_sDescription), false);
            --TODO FINISH check for write

            --open the portable editor and edit the file
            File.Run(_Bin.."\\lite-xl\\lite-xl.exe", _pTempFile, _TempFolder, SW_SHOWNORMAL, true);

            --read the file back in and set the new text
            local sNewText = TextFile.ReadToString(_pTempFile);
            Paragraph.SetText("par description", sNewText);



        end,
        Get = function()
            return _sDescription;
        end,
        OnClose = function()
            --Description.Set(base64.enc(Paragraph.GetText("par description")));

            --delete the temp file
            --if (File.DoesExist(_pTempFile)) then
            --    File.Delete(_pTempFile, false, false, true, nil);
            --end
            --System.TerminateProcess(_hLiteXT);

        end,
        --[[!
            @fqxn Card Forge.Classes.Description.Methods.OnSelect
            @desc Fires when either an event or ability is selected from the appropriate listbox. It populates the description fields with relevant data for the item selected.
            @scope static public
            @param string sObject The name of the listbox object.
            @param string sType The type (either ability or event) that is being selected.
        !]]
        OnSelect = function(sObject, sType)
        	local tSelected = ListBox.GetSelected(sObject);

        	if (type(tSelected) == "table" and #tSelected > 0) then
        		local sItem = ListBox.GetItemText(sObject, tSelected[1]);

        		local tTable = CFG[sType][sItem];

        		if not (tTable) then
        			--TODO THROW ERROR
        		end

        		Paragraph.SetText("par name", sItem);
        		Paragraph.SetText("par args", tTable.Args or "");
        		Paragraph.SetText("par deploy cost", tostring(tTable.DeployCost));
        		Paragraph.SetText("par cp cost", tostring(tTable.CPCost));
        		Paragraph.SetText("par item description", tTable.Description);

        	end

        end,
        --[[!
            @fqxn Card Forge.Classes.Description.Methods.OnShow
            @scope static public
            @desc Fires when the DialogEx is opened. Initially populates the listboxes.
        !]]
        OnShow = function()

            local tLists = {
            	Ability = "lst abilities",
            	Event 	= "lst events",
            };

        	--clear and populate the boxes
            if not (_bHasInit) then

                for sType, sObject in pairs(tLists) do
            		ListBox.DeleteItem(sObject, -1);

            		for sItem, tTable in pairs(CFG[sType]) do
            			ListBox.AddItem(sObject, sItem, "");
            		end

            	end

                _bHasInit = true;
            end


            --embed the editor
            --load the script editor
            local tParts = String.SplitPath(_pScratch);
            --base64.dec(Description.Get())
            local sWindowTitle = "~\\AppData\\Local\\Card Forge\\Games\\".._pGame.."\\Temp\\Scratch.lua - Lite XL";

            result = File.Run(_Bin.."\\lite-xl\\lite-xl.exe", '"'.._pScratch..'"', _pScratch:gsub("\\Scratch.lua", ""), SW_SHOWNORMAL, false);
            Application.Sleep(1200);

            for hWnd, sTitle in pairs(Window.EnumerateTitles(true)) do

                if sTitle:find("Scratch.lua - Lite XL", 1, true) then
                    _hLiteXT = hWnd;
                    break;
                end

            end

            local tPos  = Input.GetPos("description");
            local tSize = Input.GetSize("description");
            local hWnd  = DialogEx.GetWndHandle();
            local host  = WindowWizard.GetChildByRect(hWnd, tPos.X, tPos.Y, tSize.Width, tSize.Height, 20);
            local ok    = WindowWizard.EmbedWindow(_hLiteXT, host);






            -- Replace these with the real Input1 coordinates/sizes you pull from AMS:



            --print("ok", ok);


            --load the cell's content
            --Paragraph.SetText("par description", base64.dec(Description.Get()));
        end,
        Set = function(sText)

            if (rawtype(sText) == "string") then
                _sDescription = sText;
            end

        end
    },
    {--PRIVATE
        Description = function(this, cdat) end,
    },
    {--PROTECTED

    },
    {--PUBLIC

    },
    nil,   --extending class
    false, --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);
